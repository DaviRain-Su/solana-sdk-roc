const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseSmall;

    // Solana SDK dependency
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = b.graph.host,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    // Host module for tests
    const host_mod = b.addModule("roc_solana_host", .{
        .root_source_file = b.path("src/host.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    host_mod.addImport("solana_sdk", solana_mod);

    // Unit tests (run on host, not BPF)
    const host_tests = b.addTest(.{
        .root_module = host_mod,
    });
    const run_host_tests = b.addRunArtifact(host_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_host_tests.step);

    // ============================================
    // Solana BPF Build Pipeline (zignocchio style)
    // ============================================

    const ir_path = "zig-out/lib/host.ll";
    const bc_path = "zig-out/lib/host.bc";
    const host_obj_path = "zig-out/lib/host.o";
    const roc_obj_path = "zig-out/lib/roc.o";
    const so_path = "zig-out/lib/roc-hello.so";

    const sdk_path = solana_dep.path("src/root.zig");

    // Ensure output directory exists
    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/lib" });

    // Step 1: Generate LLVM IR from Zig host
    std.debug.print("Step 1: Generating LLVM IR from src/host.zig\n", .{});
    const gen_ir = b.addSystemCommand(&.{
        "zig",
        "build-lib",
        "-target",
        "bpfel-freestanding",
        "-O",
        "ReleaseSmall",
        "-femit-llvm-ir=" ++ ir_path,
        "-fno-emit-bin",
        "--dep",
        "solana_sdk",
        "-Mroot=src/host.zig",
    });
    gen_ir.addPrefixedFileArg("-Msolana_sdk=", sdk_path);
    gen_ir.step.dependOn(&mkdir.step);

    // Step 2: Compile IR to bitcode using clang
    std.debug.print("Step 2: Compiling IR to bitcode with clang\n", .{});
    const compile_bc = b.addSystemCommand(&.{
        "clang",
        "-target",
        "bpf",
        "-c",
        "-fembed-bitcode",
        "-emit-llvm",
        "-o",
        bc_path,
        ir_path,
    });
    compile_bc.step.dependOn(&gen_ir.step);

    // Step 3: Compile bitcode to object with llc
    std.debug.print("Step 3: Compiling bitcode to object with llc\n", .{});
    const compile_host_obj = b.addSystemCommand(&.{
        "llc",
        "-march=sbf",
        "-mcpu=v3",
        "-filetype=obj",
        bc_path,
        "-o",
        host_obj_path,
    });
    compile_host_obj.step.dependOn(&compile_bc.step);

    // Step 4: Compile Roc IR to object (using our minimal roc_bpf.ll)
    std.debug.print("Step 4: Compiling Roc IR to object\n", .{});
    const compile_roc = b.addSystemCommand(&.{
        "llc",
        "-march=sbf",
        "-mcpu=v3",
        "-filetype=obj",
        "zig-out/lib/roc_bpf.ll",
        "-o",
        roc_obj_path,
    });
    compile_roc.step.dependOn(&mkdir.step);

    // Step 5: Link with sbpf-lld
    std.debug.print("Step 5: Linking with sbpf-lld\n", .{});
    const link_program = b.addSystemCommand(&.{
        "sbpf-lld",
        host_obj_path,
        roc_obj_path,
        so_path,
    });
    link_program.step.dependOn(&compile_host_obj.step);
    link_program.step.dependOn(&compile_roc.step);

    // Build step
    const build_step = b.step("solana", "Build Solana program (.so)");
    build_step.dependOn(&link_program.step);

    // Default step
    b.default_step.dependOn(&link_program.step);
}
