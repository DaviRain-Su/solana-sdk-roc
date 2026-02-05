const std = @import("std");

/// Roc on Solana 构建配置
///
/// **重要**: 必须使用 solana-zig 运行此构建脚本
///
/// 构建命令:
///   ./solana-zig/zig build              - 构建 Solana 程序 (使用已有的 roc_app.o)
///   ./solana-zig/zig build roc          - 完整流程: Roc -> SBF bitcode -> SBF object -> .so
///   ./solana-zig/zig build test         - 运行测试
///   ./solana-zig/zig build platform     - 构建 Roc 平台静态库
///   ./solana-zig/zig build deploy       - 部署到 Solana
///
/// 完整 Roc 编译流程:
///   1. Roc 编译器生成 SBF LLVM bitcode (roc build --target sbf --no-link)
///   2. solana-zig 将 bitcode 编译为 SBF object (zig build-obj)
///   3. 链接生成 Solana 程序 (zig build)
///
pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // ============================================
    // 配置选项
    // ============================================

    const roc_app = b.option([]const u8, "roc-app", "Roc application file path") orelse "test-roc/simple.roc";
    const roc_compiler = b.option([]const u8, "roc-compiler", "Path to Roc compiler") orelse "./roc-source/target/release/roc";

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
    // 完整 Roc 编译流程 (使用修改后的 Roc 编译器)
    // ============================================

    const with_roc = b.option(bool, "with-roc", "Run Roc compiler to rebuild roc_app.o") orelse false;

    const roc_available = blk: {
        // If roc_compiler doesn't exist, skip Roc compilation pipeline.
        std.fs.cwd().access(roc_compiler, .{}) catch break :blk false;
        break :blk true;
    };

    // Optional: full Roc compilation pipeline (Roc -> LLVM bitcode -> SBF object)
    const compile_bc_step = if (with_roc and roc_available) blk: {
        // Step 1: 调用 Roc 编译器生成 SBF LLVM bitcode
        const roc_build_step = b.addSystemCommand(&.{
            roc_compiler,
            "build",
            "--target",
            "sbf",
            "--no-link",
        });
        roc_build_step.addArg(roc_app);
        roc_build_step.setName("roc-compile-sbf");

        // Step 2: 复制 .o (bitcode) 为 .bc 以便 zig 识别
        const copy_bc_step = b.addSystemCommand(&.{ "cp" });

        // 从 roc_app 路径推导输出文件名
        // 例如: test-roc/simple.roc -> test-roc/simple.o -> test-roc/simple.bc
        const app_base = std.fs.path.stem(roc_app);
        const app_dir = std.fs.path.dirname(roc_app) orelse ".";
        const roc_output_o = b.fmt("{s}/{s}.o", .{ app_dir, app_base });
        const roc_output_bc = b.fmt("{s}/{s}.bc", .{ app_dir, app_base });

        copy_bc_step.addArg(roc_output_o);
        copy_bc_step.addArg(roc_output_bc);
        copy_bc_step.step.dependOn(&roc_build_step.step);
        copy_bc_step.setName("copy-to-bc");

        // Step 3: 使用 solana-zig 将 bitcode 编译为 SBF object
        const compile_step = b.addSystemCommand(&.{
            "./solana-zig/zig",
            "build-obj",
        });
        compile_step.addArg(roc_output_bc);
        compile_step.addArgs(&.{
            "-target",
            "sbf-solana",
            "-O",
            "ReleaseSmall",
            "-femit-bin=roc_app.o",
        });
        compile_step.step.dependOn(&copy_bc_step.step);
        compile_step.setName("compile-bc-to-sbf");

        break :blk compile_step;
    } else null;

    // ============================================
    // Solana SBF 构建
    // ============================================

    const build_result = buildSolanaProgram(b);

    // If enabled, run the Roc compilation pipeline before linking.
    if (compile_bc_step) |s| {
        build_result.lib.step.dependOn(&s.step);
    }

    const roc_step = b.step("roc", "Full Roc compilation: Roc -> SBF bitcode -> SBF object -> .so");
    roc_step.dependOn(build_result.install_step);

    // 默认构建步骤 (使用已存在的 roc_app.o)
    b.default_step.dependOn(build_result.install_step);

    // ============================================
    // Roc 平台静态库构建
    // ============================================

    buildPlatformLib(b);

    // ============================================
    // 部署步骤
    // ============================================

    const deploy_step = b.addSystemCommand(&.{
        "solana",
        "program",
        "deploy",
        "zig-out/lib/roc-hello.so",
    });
    deploy_step.step.dependOn(build_result.install_step);

    const deploy = b.step("deploy", "Deploy program to Solana");
    deploy.dependOn(&deploy_step.step);
}

const BuildResult = struct {
    lib: *std.Build.Step.Compile,
    install_step: *std.Build.Step,
};

fn buildSolanaProgram(b: *std.Build) BuildResult {
    const name = "roc-hello";

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
        .root_source_file = b.path("src/host.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    root_mod.addImport("solana_program_sdk", solana_mod);
    root_mod.sanitize_c = .off;

    const lib = b.addLibrary(.{
        .name = name,
        .root_module = root_mod,
        .linkage = .dynamic,
    });

    // 链接 Roc 编译的 SBF 对象文件
    lib.addObjectFile(b.path("roc_app.o"));

    linkSolanaProgram(b, lib);

    const install_artifact = b.addInstallArtifact(lib, .{});

    return .{
        .lib = lib,
        .install_step = &install_artifact.step,
    };
}

fn buildPlatformLib(b: *std.Build) void {
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
        .root_source_file = b.path("src/host.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    root_mod.addImport("solana_program_sdk", solana_mod);
    root_mod.pic = true;
    root_mod.sanitize_c = .off;
    root_mod.strip = true;

    const lib = b.addLibrary(.{
        .name = "host",
        .root_module = root_mod,
        .linkage = .static,
    });

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
