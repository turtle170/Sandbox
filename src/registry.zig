const std = @import("std");
const windows = std.os.windows;
const advapi32 = struct {
    pub extern "advapi32" fn RegCreateKeyExW(
        hKey: windows.HKEY,
        lpSubKey: windows.PCWSTR,
        Reserved: windows.DWORD,
        lpClass: ?windows.LPWSTR,
        dwOptions: windows.DWORD,
        samDesired: windows.DWORD,
        lpSecurityAttributes: ?*anyopaque,
        phkResult: *windows.HKEY,
        lpdwDisposition: ?*windows.DWORD,
    ) callconv(.winapi) windows.LSTATUS;

    pub extern "advapi32" fn RegSetValueExW(
        hKey: windows.HKEY,
        lpValueName: ?windows.PCWSTR,
        Reserved: windows.DWORD,
        dwType: windows.DWORD,
        lpData: [*]const u8,
        cbData: windows.DWORD,
    ) callconv(.winapi) windows.LSTATUS;

    pub extern "advapi32" fn RegDeleteKeyW(
        hKey: windows.HKEY,
        lpSubKey: windows.LPCWSTR,
    ) callconv(.winapi) windows.LSTATUS;

    pub extern "advapi32" fn RegCloseKey(
        hKey: windows.HKEY,
    ) callconv(.winapi) windows.LSTATUS;
};

// Access Mask constants for Registry
const KEY_SET_VALUE = 0x0002;
const KEY_CREATE_SUB_KEY = 0x0004;

pub fn setKeyString(hKey: windows.HKEY, subKey: []const u8, valueName: []const u8, data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const subKeyW = try std.unicode.utf8ToUtf16LeAllocZ(allocator, subKey);
    const valueNameW = if (valueName.len > 0) try std.unicode.utf8ToUtf16LeAllocZ(allocator, valueName) else null;
    const dataW = try std.unicode.utf8ToUtf16LeAllocZ(allocator, data);

    var hResult: windows.HKEY = undefined;
    const createStatus = advapi32.RegCreateKeyExW(
        hKey,
        subKeyW.ptr,
        0,
        null,
        0,
        KEY_SET_VALUE | KEY_CREATE_SUB_KEY,
        null,
        &hResult,
        null,
    );

    if (createStatus != 0) return error.RegistryKeyCreationFailed;
    defer _ = advapi32.RegCloseKey(hResult);

    const setStatus = advapi32.RegSetValueExW(
        hResult,
        if (valueNameW) |v| v.ptr else null,
        0,
        1, // REG_SZ
        @ptrCast(dataW.ptr),
        @as(u32, @intCast(dataW.len * 2 + 2)), // Include null terminator
    );

    if (setStatus != 0) return error.RegistryValueUpdateFailed;
}

pub fn deleteKey(hKey: windows.HKEY, subKey: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const subKeyW = try std.unicode.utf8ToUtf16LeAllocZ(allocator, subKey);
    const status = advapi32.RegDeleteKeyW(hKey, subKeyW.ptr);
    if (status != 0) return error.RegistryKeyDeletionFailed;
}
