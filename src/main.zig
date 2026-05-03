const std = @import("std");
const shell = @import("shell_integration.zig");
const pe_parser = @import("pe_parser.zig");

pub fn main(init: std.process.Init) !void {
    var it = try init.minimal.args.iterateAllocator(init.gpa);
    defer it.deinit();

    // Skip the first argument (the executable path)
    _ = it.skip();

    const first_arg = it.next() orelse {
        printUsage();
        return;
    };

    if (std.mem.eql(u8, first_arg, "install")) {
        try shell.install();
    } else if (std.mem.eql(u8, first_arg, "uninstall")) {
        try shell.uninstall();
    } else {
        // Assume first_arg is a path to an executable to sandbox
        try runSandbox(first_arg, init);
    }
}

const memory = @import("memory.zig");
const orchestrator = @import("engine/orchestrator.zig");
const loader = @import("subsystem/loader.zig");
const network = @import("network.zig");
const gui_manager = @import("gui/manager.zig");
const cpu_features = @import("engine/cpu_features.zig");

fn runSandbox(path: []const u8, init: std.process.Init) !void {
    const info = try pe_parser.parse(path);
    std.debug.print("Detected Architecture: {s}\n", .{@tagName(info.arch)});
    
    const cpu_caps = cpu_features.CpuFeatures.detect();
    cpu_caps.log();

    // Check environment variable for architecture override
    var target_arch = info.arch;
    if (init.environ_map.get("ZIG_SANDBOX_ARCH")) |a| {
        std.debug.print("Architecture override via env: {s}\n", .{a});
        if (std.mem.eql(u8, a, "x86")) target_arch = .x86;
        if (std.mem.eql(u8, a, "x86_64")) target_arch = .x86_64;
        if (std.mem.eql(u8, a, "arm")) target_arch = .arm;
        if (std.mem.eql(u8, a, "arm64")) target_arch = .arm64;
    }

    std.debug.print("Initializing Sandbox for: {s}...\n", .{path});

    // 1. Initialize Memory Manager
    var mem_manager = memory.SandboxMemory.init(init.gpa);
    defer mem_manager.deinit();
    try mem_manager.maintainHeadroom();

    // 2. Initialize Engine
    const engine_type: orchestrator.EngineType = if (target_arch == .x86_64) .whpx else .unicorn;
    var engine = try orchestrator.SandboxEngine.init(engine_type, &mem_manager);
    defer engine.deinit();

    // 3. Initialize Network
    var net = network.Network.init();
    net.log();

    // 4. Initialize GUI
    var gui = try gui_manager.Gui.init(1920, 1080);
    defer gui.deinit();
    std.debug.print("GUI: Shared Memory Backbuffer initialized.\n", .{});

    // 5. Load Executable
    var exe_loader = loader.Loader.init(init.gpa, &mem_manager);
    const entry_point = try exe_loader.loadExecutable(path, init.io);
    std.debug.print("Sandbox ready. Entry Point: 0x{x}\n", .{entry_point});
    
    std.debug.print("Sandbox running... (Passive mode active)\n", .{});
}

fn printUsage() void {
    std.debug.print(
        \\Zig Sandbox
        \\Usage:
        \\  sandbox.exe install          - Registers context menu
        \\  sandbox.exe uninstall        - Unregisters context menu
        \\  sandbox.exe <path_to_exe>    - Runs executable in sandbox
        \\
    , .{});
}
