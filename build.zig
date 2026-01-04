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
    host_mod.addImport("solana_program_sdk", solana_mod);

    const host_tests = b.addTest(.{
        .root_module = host_mod,
    });
    const run_host_tests = b.addRunArtifact(host_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_host_tests.step);

    // ============================================
    // Solana SBF 构建 (使用 Solana SDK 的链接配置)
    // ============================================

    buildSolanaProgram(b);

    // ============================================
    // Roc 平台静态库构建 (用于 Roc 编译器链接)
    // ============================================

    buildPlatformLib(b);
}

fn buildSolanaProgram(b: *std.Build) void {
    const name = "roc-hello";

    // SBF 目标配置
    const sbf_target: std.Target.Query = .{
        .cpu_arch = .sbf,
        .os_tag = .solana,
    };
    const target = b.resolveTargetQuery(sbf_target);

    // 获取 Solana SDK 依赖
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    // 创建主模块
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/host.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    // 添加 Solana SDK 导入
    root_mod.addImport("solana_program_sdk", solana_mod);

    // 关键：禁用 sanitizer 以生成 PIC 兼容代码
    root_mod.sanitize_c = .off;

    // 添加 stub 模块 (提供 roc__main_for_host_1_exposed_generic)
    const stub_mod = b.createModule(.{
        .root_source_file = b.path("src/stub.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    root_mod.addImport("stub", stub_mod);

    // 创建库
    const lib = b.addLibrary(.{
        .name = name,
        .root_module = root_mod,
        .linkage = .dynamic,
    });

    // 应用 SBF 程序链接配置 (基于 vendor SDK 的模式)
    linkSolanaProgram(b, lib);

    // Install the library
    b.installArtifact(lib);
}

/// Build static library for Roc platform
/// This creates libhost.a with PIC for use by Roc's linker
fn buildPlatformLib(b: *std.Build) void {
    // SBF 目标配置
    const sbf_target: std.Target.Query = .{
        .cpu_arch = .sbf,
        .os_tag = .solana,
    };
    const target = b.resolveTargetQuery(sbf_target);

    // 获取 Solana SDK 依赖
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    // 创建模块 (静态库使用)
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/host.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    // 添加 Solana SDK 导入
    root_mod.addImport("solana_program_sdk", solana_mod);

    // 关键配置：启用 PIC 以兼容 Roc 的链接
    root_mod.pic = true;
    root_mod.sanitize_c = .off;
    root_mod.strip = true;

    // 创建静态库
    const lib = b.addLibrary(.{
        .name = "host",
        .root_module = root_mod,
        .linkage = .static,
    });

    // 安装到 platform/targets/sbfsolana/
    const install_lib = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "../platform/targets/sbfsolana" } },
    });

    const platform_step = b.step("platform", "Build static library for Roc platform");
    platform_step.dependOn(&install_lib.step);
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
