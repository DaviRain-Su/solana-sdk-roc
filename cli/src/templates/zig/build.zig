const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.sbf_target);

    const program = b.addLibrary(.{
        .name = "program",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    _ = solana.buildProgram(b, program, target, optimize);
    b.installArtifact(program);
}
