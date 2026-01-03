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
        .root_source_file = b.path("src/host.zig"),
        .optimize = .ReleaseSmall,
    });

    const build_step = b.step("solana", "Build Solana program (.so)");
    build_step.dependOn(program.getInstallStep());

    b.default_step.dependOn(program.getInstallStep());
}

pub const ProgramOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode = .ReleaseSmall,
};

pub const SolanaProgram = struct {
    bitcode_step: *std.Build.Step.Run,
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

    const bc_filename = b.fmt("{s}.bc", .{name});
    const so_filename = b.fmt("{s}.so", .{name});

    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/lib" });

    const gen_bitcode = b.addSystemCommand(&.{
        "zig",
        "build-obj",
        "-target",
        "bpfel-freestanding",
        "-O",
        @tagName(opt),
        "-fPIC",
        "-fno-emit-bin",
        b.fmt("-femit-llvm-bc=zig-out/lib/{s}", .{bc_filename}),
        "--dep",
        "solana_sdk",
    });
    gen_bitcode.addPrefixedFileArg("-Mroot=", options.root_source_file);
    gen_bitcode.addArg("--dep");
    gen_bitcode.addArg("base58");
    gen_bitcode.addPrefixedFileArg("-Msolana_sdk=", sdk_path);
    gen_bitcode.addPrefixedFileArg("-Mbase58=", base58_path);
    gen_bitcode.step.dependOn(&mkdir.step);

    const link_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt(
            "LD_LIBRARY_PATH=/usr/lib/llvm-18/lib sbpf-linker --cpu v2 --llvm-args=-bpf-stack-size=4096 --export entrypoint -o zig-out/lib/{s} zig-out/lib/{s} 2>/dev/null || echo 'sbpf-linker failed or not installed'",
            .{ so_filename, bc_filename },
        ),
    });
    link_cmd.step.dependOn(&gen_bitcode.step);

    const install_step = b.allocator.create(std.Build.Step) catch @panic("OOM");
    install_step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = b.fmt("install {s}", .{name}),
        .owner = b,
    });
    install_step.dependOn(&link_cmd.step);

    return .{
        .bitcode_step = gen_bitcode,
        .link_step = link_cmd,
        .install_step = install_step,
    };
}
