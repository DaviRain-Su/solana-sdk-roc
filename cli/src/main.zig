const std = @import("std");
const builtin = @import("builtin");

const version = "0.2.0";

const Config = struct {
    roc_sbf_version: []const u8 = "sbf-v0.1.0",
    solana_zig_version: []const u8 = "solana-v1.52.0",
    cache_dir: []const u8 = ".roc-solana",
};

const config = Config{};

pub fn main() !void {
    // Use Arena allocator for simplified memory management
    // All allocations are freed at once when arena is deinitialized
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "init")) {
        try cmdInit(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "build")) {
        try cmdBuild(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "deploy")) {
        try cmdDeploy(allocator);
    } else if (std.mem.eql(u8, command, "test")) {
        try cmdTest(allocator);
    } else if (std.mem.eql(u8, command, "toolchain")) {
        try cmdToolchain(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "version")) {
        printVersion();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    const usage =
        \\roc-solana - Build Solana programs with Roc or Zig
        \\
        \\Usage: roc-solana <command> [options]
        \\
        \\Commands:
        \\  init <name>           Create a new Roc Solana project (default)
        \\  init <name> --zig     Create a new Zig Solana project
        \\  build [app.roc]       Compile to Solana program (.so)
        \\  deploy                Deploy to Solana network
        \\  test                  Call the deployed program
        \\  toolchain install     Install all dependencies
        \\  toolchain info        Show installed versions
        \\  version               Show version info
        \\  help                  Show this help
        \\
        \\Examples:
        \\  roc-solana init my-roc-app           # Roc project
        \\  roc-solana init my-zig-app --zig     # Zig project
        \\  cd my-app
        \\  roc-solana build
        \\  roc-solana deploy
        \\  roc-solana test
        \\
    ;
    std.debug.print("{s}", .{usage});
}

fn printVersion() void {
    std.debug.print("roc-solana {s}\n", .{version});
    std.debug.print("roc-sbf: {s}\n", .{config.roc_sbf_version});
    std.debug.print("solana-zig: {s}\n", .{config.solana_zig_version});
}

fn cmdInit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    var name: []const u8 = "my-solana-app";
    var use_zig = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--zig")) {
            use_zig = true;
        } else if (arg[0] != '-') {
            name = arg;
        }
    }

    const project_type = if (use_zig) "Zig" else "Roc";
    std.debug.print("Creating {s} project: {s}\n", .{ project_type, name });

    std.fs.cwd().makeDir(name) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var dir = try std.fs.cwd().openDir(name, .{});
    defer dir.close();

    const package_json = @embedFile("templates/scripts/package.json");
    const test_mjs = @embedFile("templates/scripts/test.mjs");
    const gitignore = @embedFile("templates/gitignore");

    if (use_zig) {
        const zig_main = @embedFile("templates/zig/main.zig");
        const zig_build = @embedFile("templates/zig/build.zig");
        const zig_build_zon = @embedFile("templates/zig/build.zig.zon");

        try writeFile(dir, "src/main.zig", zig_main);
        try writeFile(dir, "build.zig", zig_build);
        try writeFile(dir, "build.zig.zon", zig_build_zon);
    } else {
        const app_main_roc = @embedFile("templates/roc/main.roc");
        const platform_roc = @embedFile("templates/roc/platform.roc");
        const host_roc = @embedFile("templates/roc/Host.roc");
        const host_zig = @embedFile("templates/roc/host.zig");
        const build_zig = @embedFile("templates/roc/build.zig");
        const build_zon = @embedFile("templates/roc/build.zig.zon");

        try writeFile(dir, "app/main.roc", app_main_roc);
        try writeFile(dir, "platform/main.roc", platform_roc);
        try writeFile(dir, "platform/Host.roc", host_roc);
        try writeFile(dir, "platform/host/main.zig", host_zig);
        try writeFile(dir, "build.zig", build_zig);
        try writeFile(dir, "build.zig.zon", build_zon);
    }

    try writeFile(dir, "package.json", package_json);
    try writeFile(dir, "scripts/test.mjs", test_mjs);
    try writeFile(dir, ".gitignore", gitignore);

    std.debug.print("\n✓ Project created: {s}/\n", .{name});
    std.debug.print("\nNext steps:\n", .{});
    std.debug.print("  cd {s}\n", .{name});
    std.debug.print("  roc-solana build\n", .{});
    std.debug.print("  roc-solana deploy\n", .{});
}

fn cmdBuild(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const is_roc_project = blk: {
        std.fs.cwd().access("app/main.roc", .{}) catch break :blk false;
        break :blk true;
    };

    if (is_roc_project) {
        try cmdBuildRoc(allocator, args);
    } else {
        try cmdBuildZig(allocator);
    }
}

fn cmdBuildZig(allocator: std.mem.Allocator) !void {
    std.debug.print("Building Zig project...\n", .{});

    const toolchain = try ensureToolchain(allocator);

    std.debug.print("  [1/1] Compiling Solana program...\n", .{});
    const zig_result = try runProcess(allocator, &.{
        toolchain.zig_path,
        "build",
    });

    if (zig_result.term.Exited != 0) {
        std.debug.print("Zig build failed\n", .{});
        if (zig_result.stderr.len > 0) {
            std.debug.print("{s}\n", .{zig_result.stderr});
        }
        return error.ZigBuildFailed;
    }

    std.debug.print("✓ Build complete: zig-out/lib/program.so\n", .{});
}

fn cmdBuildRoc(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const app_file = if (args.len > 0) args[0] else "app/main.roc";

    std.debug.print("Building: {s}\n", .{app_file});

    const toolchain = try ensureToolchain(allocator);

    std.fs.cwd().makeDir(".roc-solana") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    std.debug.print("  [1/2] Compiling Roc...\n", .{});
    const roc_result = try runProcess(allocator, &.{
        toolchain.roc_path,
        "build",
        "--target",
        "sbf",
        "--no-link",
        "--output",
        ".roc-solana/app",
        app_file,
    });

    const roc_output_exists = blk: {
        std.fs.cwd().access(".roc-solana/app", .{}) catch break :blk false;
        break :blk true;
    };

    if (roc_result.stderr.len > 0) {
        std.debug.print("{s}", .{roc_result.stderr});
    }

    if (!roc_output_exists) {
        std.debug.print("Roc compilation failed - no output file\n", .{});
        return error.RocCompilationFailed;
    }

    std.fs.cwd().rename(".roc-solana/app", ".roc-solana/app.o") catch |err| {
        std.debug.print("Failed to rename roc output: {}\n", .{err});
        return error.RocCompilationFailed;
    };

    std.debug.print("  [2/2] Building Solana program...\n", .{});
    const zig_result = try runProcess(allocator, &.{
        toolchain.zig_path,
        "build",
        "-Droc-obj=.roc-solana/app.o",
    });

    if (zig_result.term.Exited != 0) {
        std.debug.print("Zig build failed\n", .{});
        if (zig_result.stderr.len > 0) {
            std.debug.print("{s}\n", .{zig_result.stderr});
        }
        return error.ZigBuildFailed;
    }

    std.debug.print("✓ Build complete: zig-out/lib/program.so\n", .{});
}

fn cmdDeploy(allocator: std.mem.Allocator) !void {
    std.debug.print("Deploying program...\n", .{});

    const result = try runProcess(allocator, &.{
        "solana",
        "program",
        "deploy",
        "zig-out/lib/program.so",
    });

    if (result.term.Exited != 0) {
        std.debug.print("Deploy failed. Is solana-test-validator running?\n", .{});
        if (result.stderr.len > 0) {
            std.debug.print("{s}\n", .{result.stderr});
        }
        return error.DeployFailed;
    }

    // Print deploy output (contains program ID)
    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});

        // Parse and save program ID to .program-id file
        // Output format: "Program Id: <base58>\n\nSignature: ..."
        if (std.mem.indexOf(u8, result.stdout, "Program Id: ")) |start| {
            const id_start = start + "Program Id: ".len;
            if (std.mem.indexOfPos(u8, result.stdout, id_start, "\n")) |end| {
                const program_id = result.stdout[id_start..end];
                const file = std.fs.cwd().createFile(".program-id", .{}) catch |err| {
                    std.debug.print("Warning: failed to save program ID: {}\n", .{err});
                    return;
                };
                defer file.close();
                file.writeAll(program_id) catch {};
                file.writeAll("\n") catch {};
            }
        }
    }

    std.debug.print("✓ Deployed successfully\n", .{});
}

fn cmdTest(allocator: std.mem.Allocator) !void {
    std.debug.print("Testing program...\n", .{});

    const pkg_exists = blk: {
        std.fs.cwd().access("package.json", .{}) catch break :blk false;
        break :blk true;
    };

    if (!pkg_exists) {
        std.debug.print("Error: package.json not found. Are you in a project directory?\n", .{});
        return error.NotInProject;
    }

    const deps_exists = blk: {
        std.fs.cwd().access("node_modules", .{}) catch break :blk false;
        break :blk true;
    };

    if (!deps_exists) {
        std.debug.print("Installing dependencies...\n", .{});
        _ = try runProcess(allocator, &.{ "bun", "install" });
    }

    const result = try runProcess(allocator, &.{ "bun", "run", "test" });
    if (result.term.Exited != 0) {
        std.debug.print("Test failed\n", .{});
        return error.TestFailed;
    }

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
}

fn cmdToolchain(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "info";

    if (std.mem.eql(u8, subcmd, "install")) {
        try installAllTools(allocator);
    } else if (std.mem.eql(u8, subcmd, "info")) {
        try showToolchainInfo(allocator);
    } else {
        std.debug.print("Usage: roc-solana toolchain <install|info>\n", .{});
    }
}

fn installAllTools(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════╗\n", .{});
    std.debug.print("║   Roc Solana Toolchain Installer      ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // 1. Install Bun
    std.debug.print("[1/4] Checking Bun...\n", .{});
    const bun_ok = checkCommand(allocator, "bun", &.{"--version"});
    if (bun_ok) {
        std.debug.print("  ✓ Bun already installed\n", .{});
    } else {
        std.debug.print("  Installing Bun...\n", .{});
        _ = try runProcess(allocator, &.{ "sh", "-c", "curl -fsSL https://bun.sh/install | bash" });
        std.debug.print("  ✓ Bun installed\n", .{});
    }

    // 2. Install Solana CLI
    std.debug.print("\n[2/4] Checking Solana CLI...\n", .{});
    const solana_ok = checkCommand(allocator, "solana", &.{"--version"});
    if (solana_ok) {
        std.debug.print("  ✓ Solana CLI already installed\n", .{});
    } else {
        std.debug.print("  Installing Solana CLI...\n", .{});
        _ = try runProcess(allocator, &.{ "sh", "-c", "sh -c \"$(curl -sSfL https://release.anza.xyz/stable/install)\"" });
        std.debug.print("  ✓ Solana CLI installed\n", .{});
    }

    // 3. Install solana-zig
    std.debug.print("\n[3/4] Checking solana-zig...\n", .{});
    _ = try ensureToolchain(allocator);
    std.debug.print("  ✓ solana-zig ready\n", .{});

    // 4. Install roc-sbf
    std.debug.print("\n[4/4] Checking Roc (SBF)...\n", .{});
    std.debug.print("  ✓ Roc (SBF) ready\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("✓ All tools installed!\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  roc-solana init my-program\n", .{});
    std.debug.print("  cd my-program\n", .{});
    std.debug.print("  roc-solana build\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
}

fn showToolchainInfo(allocator: std.mem.Allocator) !void {
    const home = std.posix.getenv("HOME") orelse ".";
    const cache_dir = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, config.cache_dir });

    std.debug.print("\nToolchain Info:\n", .{});
    std.debug.print("───────────────────────────────────────\n", .{});
    std.debug.print("Cache directory: {s}\n", .{cache_dir});
    std.debug.print("\n", .{});

    // Bun
    std.debug.print("Bun:        ", .{});
    if (checkCommand(allocator, "bun", &.{"--version"})) {
        const result = try runProcess(allocator, &.{ "bun", "--version" });
        std.debug.print("v{s}", .{std.mem.trim(u8, result.stdout, "\n ")});
    } else {
        std.debug.print("not installed", .{});
    }
    std.debug.print("\n", .{});

    // Solana
    std.debug.print("Solana CLI: ", .{});
    if (checkCommand(allocator, "solana", &.{"--version"})) {
        const result = try runProcess(allocator, &.{ "solana", "--version" });
        const out = std.mem.trim(u8, result.stdout, "\n ");
        if (std.mem.indexOf(u8, out, " ")) |idx| {
            std.debug.print("{s}", .{out[0..idx]});
        } else {
            std.debug.print("{s}", .{out});
        }
    } else {
        std.debug.print("not installed", .{});
    }
    std.debug.print("\n", .{});

    // solana-zig
    const zig_path = try std.fmt.allocPrint(allocator, "{s}/solana-zig/zig", .{cache_dir});
    std.debug.print("solana-zig: ", .{});
    if (std.fs.cwd().access(zig_path, .{})) |_| {
        std.debug.print("{s} ✓", .{config.solana_zig_version});
    } else |_| {
        std.debug.print("not installed", .{});
    }
    std.debug.print("\n", .{});

    // roc-sbf
    const roc_path = try std.fmt.allocPrint(allocator, "{s}/roc-sbf/roc", .{cache_dir});
    std.debug.print("Roc (SBF):  ", .{});
    if (std.fs.cwd().access(roc_path, .{})) |_| {
        std.debug.print("{s} ✓", .{config.roc_sbf_version});
    } else |_| {
        std.debug.print("not installed", .{});
    }
    std.debug.print("\n", .{});

    std.debug.print("───────────────────────────────────────\n", .{});
}

fn checkCommand(allocator: std.mem.Allocator, cmd: []const u8, args: []const []const u8) bool {
    var argv_buf: [16][]const u8 = undefined;
    argv_buf[0] = cmd;
    for (args, 0..) |arg, i| {
        argv_buf[i + 1] = arg;
    }
    const argv = argv_buf[0 .. args.len + 1];

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    }) catch return false;
    return result.term.Exited == 0;
}

const Toolchain = struct {
    roc_path: []const u8,
    zig_path: []const u8,
};

fn ensureToolchain(allocator: std.mem.Allocator) !Toolchain {
    const home = std.posix.getenv("HOME") orelse ".";
    const cache_dir = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, config.cache_dir });

    std.fs.cwd().makeDir(cache_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const roc_path = try std.fmt.allocPrint(allocator, "{s}/roc-sbf/roc", .{cache_dir});
    const zig_path = try std.fmt.allocPrint(allocator, "{s}/solana-zig/zig", .{cache_dir});

    const roc_exists = blk: {
        std.fs.cwd().access(roc_path, .{}) catch break :blk false;
        break :blk true;
    };

    const zig_exists = blk: {
        std.fs.cwd().access(zig_path, .{}) catch break :blk false;
        break :blk true;
    };

    if (!roc_exists) {
        std.debug.print("Downloading Roc (SBF)...\n", .{});
        try downloadRoc(allocator, cache_dir);
    }

    if (!zig_exists) {
        std.debug.print("Downloading solana-zig...\n", .{});
        try downloadSolanaZig(allocator, cache_dir);
    }

    return Toolchain{
        .roc_path = roc_path,
        .zig_path = zig_path,
    };
}

fn downloadRoc(allocator: std.mem.Allocator, cache_dir: []const u8) !void {
    const arch = @tagName(builtin.cpu.arch);
    const os = @tagName(builtin.os.tag);

    // Filename format: roc-sbf-linux-x86_64-sbf-v0.1.0.tar.gz
    const filename = try std.fmt.allocPrint(allocator, "roc-sbf-{s}-{s}-{s}.tar.gz", .{ os, arch, config.roc_sbf_version });
    const url = try std.fmt.allocPrint(allocator, "https://github.com/DaviRain-Su/roc/releases/download/{s}/{s}", .{ config.roc_sbf_version, filename });

    const tar_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{filename});
    const dest_dir = try std.fmt.allocPrint(allocator, "{s}/roc-sbf", .{cache_dir});

    _ = try runProcess(allocator, &.{ "curl", "-fsSL", "-o", tar_path, url });
    std.fs.cwd().makeDir(dest_dir) catch {};
    // Use --strip-components=1 to extract contents directly into dest_dir
    _ = try runProcess(allocator, &.{ "tar", "-xzf", tar_path, "-C", dest_dir, "--strip-components=1" });
    std.fs.cwd().deleteFile(tar_path) catch {};
}

fn downloadSolanaZig(allocator: std.mem.Allocator, cache_dir: []const u8) !void {
    const arch = @tagName(builtin.cpu.arch);
    const os = if (builtin.os.tag == .linux) "linux-musl" else @tagName(builtin.os.tag);

    const filename = try std.fmt.allocPrint(allocator, "zig-{s}-{s}.tar.bz2", .{ arch, os });
    const url = try std.fmt.allocPrint(allocator, "https://github.com/joncinque/solana-zig-bootstrap/releases/download/{s}/{s}", .{ config.solana_zig_version, filename });

    const tar_path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{filename});
    const dest_dir = try std.fmt.allocPrint(allocator, "{s}/solana-zig", .{cache_dir});

    _ = try runProcess(allocator, &.{ "curl", "-fsSL", "-o", tar_path, url });
    std.fs.cwd().makeDir(dest_dir) catch {};
    _ = try runProcess(allocator, &.{ "tar", "-xjf", tar_path, "-C", dest_dir, "--strip-components=1" });
    std.fs.cwd().deleteFile(tar_path) catch {};
}

fn runProcess(allocator: std.mem.Allocator, argv: []const []const u8) !std.process.Child.RunResult {
    return std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });
}

fn writeFile(dir: std.fs.Dir, path: []const u8, content: []const u8) !void {
    if (std.mem.indexOf(u8, path, "/")) |_| {
        const dirname = std.fs.path.dirname(path) orelse return error.InvalidPath;
        dir.makeDir(dirname) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
    const file = try dir.createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}
