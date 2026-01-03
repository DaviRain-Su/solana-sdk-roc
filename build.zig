const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");

    const host_mod = b.addModule("roc_solana_host", .{
        .root_source_file = b.path("src/host.zig"),
        .target = target,
        .optimize = optimize,
    });
    host_mod.addImport("solana_sdk", solana_mod);
    host_mod.addImport("base58", base58_mod);

    const host_tests = b.addTest(.{
        .root_module = host_mod,
    });
    const run_host_tests = b.addRunArtifact(host_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_host_tests.step);

    const program = addSolanaProgram(b, solana_dep, base58_dep, .{
        .name = "roc-hello",
        .host_source_file = b.path("src/host.zig"),
        .roc_app_path = "examples/hello-world/app.roc",
        .optimize = .ReleaseSmall,
    });

    const build_step = b.step("solana", "Build Solana program (.so)");
    build_step.dependOn(program.getInstallStep());

    b.default_step.dependOn(program.getInstallStep());
}

pub const ProgramOptions = struct {
    name: []const u8,
    host_source_file: std.Build.LazyPath,
    roc_app_path: []const u8,
    optimize: std.builtin.OptimizeMode = .ReleaseSmall,
};

pub const SolanaProgram = struct {
    roc_step: *std.Build.Step.Run,
    host_step: *std.Build.Step.Run,
    link_step: *std.Build.Step.Run,
    install_step: *std.Build.Step,

    pub fn getInstallStep(self: SolanaProgram) *std.Build.Step {
        return self.install_step;
    }
};

pub fn addSolanaProgram(
    b: *std.Build,
    solana_dep: *std.Build.Dependency,
    base58_dep: *std.Build.Dependency,
    options: ProgramOptions,
) SolanaProgram {
    const name = options.name;
    const opt = options.optimize;

    const sdk_path = solana_dep.path("src/root.zig");
    const base58_path = base58_dep.path("src/root.zig");

    const host_bc = b.fmt("{s}_host.bc", .{name});
    const roc_obj = b.fmt("{s}_roc.o", .{name});
    const so_filename = b.fmt("{s}.so", .{name});

    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/lib" });

    const compile_roc = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt(
            "scripts/compile-roc.sh {s} zig-out/lib/{s}",
            .{ options.roc_app_path, roc_obj },
        ),
    });
    compile_roc.step.dependOn(&mkdir.step);

    const gen_host_bc = b.addSystemCommand(&.{
        "zig",
        "build-obj",
        "-target",
        "bpfel-freestanding",
        "-O",
        @tagName(opt),
        "-fPIC",
        "-fno-emit-bin",
        b.fmt("-femit-llvm-bc=zig-out/lib/{s}", .{host_bc}),
        "--dep",
        "solana_sdk",
    });
    gen_host_bc.addPrefixedFileArg("-Mroot=", options.host_source_file);
    gen_host_bc.addArg("--dep");
    gen_host_bc.addArg("base58");
    gen_host_bc.addPrefixedFileArg("-Msolana_sdk=", sdk_path);
    gen_host_bc.addPrefixedFileArg("-Mbase58=", base58_path);
    gen_host_bc.step.dependOn(&mkdir.step);

    const link_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt(
            "LD_LIBRARY_PATH=/usr/lib/llvm-18/lib sbpf-linker " ++
                "--cpu v2 " ++
                "--llvm-args=-bpf-stack-size=4096 " ++
                "--export entrypoint " ++
                "-o zig-out/lib/{s} " ++
                "zig-out/lib/{s} " ++
                "zig-out/lib/{s} " ++
                "2>&1 || echo 'sbpf-linker failed'",
            .{ so_filename, host_bc, roc_obj },
        ),
    });
    link_cmd.step.dependOn(&gen_host_bc.step);
    link_cmd.step.dependOn(&compile_roc.step);

    const install_step = b.allocator.create(std.Build.Step) catch @panic("OOM");
    install_step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = b.fmt("install {s}", .{name}),
        .owner = b,
    });
    install_step.dependOn(&link_cmd.step);

    return .{
        .roc_step = compile_roc,
        .host_step = gen_host_bc,
        .link_step = link_cmd,
        .install_step = install_step,
    };
}
