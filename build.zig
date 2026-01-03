const std = @import("std");

/// Roc on Solana 构建配置
///
/// **重要**: 必须使用 solana-zig 运行此构建脚本
///
/// 构建命令:
///   ./solana-zig/zig build          - 构建 Solana 程序
///   ./solana-zig/zig build test     - 运行测试
///   ./solana-zig/zig build solana   - 构建 Solana 程序
///
/// 参考: https://github.com/joncinque/solana-program-sdk-zig/blob/main/build.zig
pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // ============================================
    // 测试配置 (在主机上运行)
    // ============================================

    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = b.graph.host,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const host_mod = b.addModule("roc_solana_host", .{
        .root_source_file = b.path("src/host.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    host_mod.addImport("solana_sdk", solana_mod);

    const host_tests = b.addTest(.{
        .root_module = host_mod,
    });
    const run_host_tests = b.addRunArtifact(host_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_host_tests.step);

    // ============================================
    // Solana SBF 构建
    // ============================================

    // SBF 目标 (只有 solana-zig 支持)
    const sbf_target = b.resolveTargetQuery(sbf_target_query);

    // Solana SDK for SBF target
    const solana_sbf_dep = b.dependency("solana_program_sdk", .{
        .target = sbf_target,
        .optimize = .ReleaseSmall,
    });
    const solana_sbf_mod = solana_sbf_dep.module("solana_program_sdk");

    // 创建 SBF 模块
    const sbf_mod = b.createModule(.{
        .root_source_file = b.path("src/host.zig"),
        .target = sbf_target,
        .optimize = .ReleaseSmall,
    });
    sbf_mod.addImport("solana_sdk", solana_sbf_mod);

    // 构建 Solana 程序 (动态库)
    const program = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "roc-hello",
        .root_module = sbf_mod,
    });

    // 应用 Solana 程序链接配置
    linkSolanaProgram(b, program);

    // 安装
    const install_artifact = b.addInstallArtifact(program, .{
        .dest_dir = .{ .override = .{ .custom = "lib" } },
    });

    const build_step = b.step("solana", "Build Solana program (.so)");
    build_step.dependOn(&install_artifact.step);

    // 默认步骤
    b.default_step.dependOn(&install_artifact.step);

    // ============================================
    // Roc 宿主静态库 (用于 Roc 平台集成)
    // ============================================

    // 创建宿主静态库模块
    const host_lib_mod = b.createModule(.{
        .root_source_file = b.path("src/host.zig"),
        .target = sbf_target,
        .optimize = .ReleaseSmall,
    });
    host_lib_mod.addImport("solana_sdk", solana_sbf_mod);

    // 构建静态库
    const host_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "host",
        .root_module = host_lib_mod,
    });

    // 安装到 platform/targets/sbfsolana/
    const install_host_lib = b.addInstallArtifact(host_lib, .{
        .dest_dir = .{ .override = .{ .custom = "../platform/targets/sbfsolana" } },
    });

    const host_step = b.step("host", "Build Roc host library for SBF");
    host_step.dependOn(&install_host_lib.step);
}

// ============================================
// SBF 目标定义 (需要 solana-zig)
// ============================================

pub const sbf_target_query: std.Target.Query = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
};

pub const sbfv2_target_query: std.Target.Query = .{
    .cpu_arch = .sbf,
    .cpu_model = .{
        .explicit = &std.Target.sbf.cpu.sbfv2,
    },
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.cpu.sbfv2.features,
};

// ============================================
// Solana 程序链接配置
// ============================================

/// 应用 Solana 程序所需的链接配置
/// 参考: https://github.com/joncinque/solana-program-sdk-zig/blob/main/build.zig
pub fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
    // 创建 BPF 链接脚本
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

    // 应用链接配置
    lib.setLinkerScript(linker_script);
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
}
