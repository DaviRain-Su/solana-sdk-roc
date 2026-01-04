const std = @import("std");

pub fn build(b: *std.Build) void {
    const sbf_target: std.Target.Query = .{
        .cpu_arch = .sbf,
        .os_tag = .solana,
    };
    const target = b.resolveTargetQuery(sbf_target);

    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const root_mod = b.createModule(.{
        .root_source_file = b.path("platform/host/main.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    root_mod.addImport("solana_program_sdk", solana_mod);
    root_mod.sanitize_c = .off;
    root_mod.pic = true;

    const lib = b.addLibrary(.{
        .name = "program",
        .root_module = root_mod,
        .linkage = .dynamic,
    });

    // Link Roc compiled SBF object file
    if (b.option([]const u8, "roc-obj", "Roc object file")) |roc_obj| {
        lib.addObjectFile(.{ .cwd_relative = roc_obj });
    }

    // Linker configuration for Solana
    linkSolanaProgram(b, lib);

    b.installArtifact(lib);
}

fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const write_file_step = b.addWriteFiles();
    const linker_script = write_file_step.add("bpf.ld",
        \\PHDRS
        \\{
        \\text PT_LOAD  ;
        \\rodata PT_LOAD ;
        \\data PT_LOAD ;
        \\dynamic PT_DYNAMIC ;
        \\}
        \\
        \\SECTIONS
        \\{
        \\. = SIZEOF_HEADERS;
        \\.text : { *(.text*) } :text
        \\.rodata : { *(.rodata*) } :rodata
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\.dynsym : { *(.dynsym) } :data
        \\.dynstr : { *(.dynstr) } :data
        \\.rel.dyn : { *(.rel.dyn) } :data
        \\/DISCARD/ : {
        \\*(.eh_frame*)
        \\*(.gnu.hash*)
        \\*(.hash*)
        \\}
        \\}
    );

    lib.step.dependOn(&write_file_step.step);

    lib.setLinkerScript(linker_script);
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
}
