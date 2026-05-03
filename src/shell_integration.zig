const std = @import("std");
const windows = std.os.windows;
const registry = @import("registry.zig");

pub fn install() !void {
    const peb = windows.peb();
    const image_path_w = peb.ProcessParameters.ImagePathName.slice();
    const exe_path = try std.unicode.utf16LeToUtf8Alloc(std.heap.page_allocator, image_path_w);
    defer std.heap.page_allocator.free(exe_path);

    const command = try std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\" \"%1\"", .{exe_path});
    defer std.heap.page_allocator.free(command);

    // Register "Run in Sandbox" for .exe files (Current User only)
    try registry.setKeyString(
        windows.HKEY_CURRENT_USER,
        "Software\\Classes\\exefile\\shell\\RunInSandbox",
        "",
        "Run in Sandbox"
    );

    try registry.setKeyString(
        windows.HKEY_CURRENT_USER,
        "Software\\Classes\\exefile\\shell\\RunInSandbox\\command",
        "",
        command
    );

    std.debug.print("Successfully registered 'Run in Sandbox' context menu.\n", .{});
}

pub fn uninstall() !void {
    // Basic uninstallation logic
    _ = registry.deleteKey(windows.HKEY_CURRENT_USER, "Software\\Classes\\exefile\\shell\\RunInSandbox\\command") catch {};
    _ = registry.deleteKey(windows.HKEY_CURRENT_USER, "Software\\Classes\\exefile\\shell\\RunInSandbox") catch {};
    
    std.debug.print("Successfully unregistered 'Run in Sandbox' context menu.\n", .{});
}
