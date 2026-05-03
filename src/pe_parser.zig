const std = @import("std");
const windows = std.os.windows;
const ntdll = windows.ntdll;

pub const Arch = enum {
    x86,
    x86_64,
    arm,
    arm64,
    unknown,
};

pub const PEInfo = struct {
    arch: Arch,
};

pub fn parse(path: []const u8) !PEInfo {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const path_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, path);

    var nt_path: windows.UNICODE_STRING = undefined;
    if (ntdll.RtlDosPathNameToNtPathName_U(path_w.ptr, &nt_path, null, null) == .FALSE) {
        return error.InvalidPath;
    }

    var obj_attr: windows.OBJECT.ATTRIBUTES = .{
        .Length = @sizeOf(windows.OBJECT.ATTRIBUTES),
        .ObjectName = &nt_path,
        .Attributes = .{ .CASE_INSENSITIVE = true },
    };

    var io_status: windows.IO_STATUS_BLOCK = undefined;
    var handle: windows.HANDLE = undefined;

    const open_status = ntdll.NtOpenFile(
        &handle,
        .{ .SPECIFIC = .{ .FILE = .{ .READ_DATA = true } }, .STANDARD = .{ .SYNCHRONIZE = true } },
        &obj_attr,
        &io_status,
        .{ .READ = true },
        .{ .IO = .SYNCHRONOUS_NONALERT },
    );

    if (open_status != .SUCCESS) return error.OpenFileFailed;
    defer _ = ntdll.NtClose(handle);

    // Read DOS header and PE offset
    var buffer: [4096]u8 = undefined;
    var read_io_status: windows.IO_STATUS_BLOCK = undefined;
    
    // Read first 64 bytes for DOS header
    var status = ntdll.NtReadFile(
        handle,
        null,
        null,
        null,
        &read_io_status,
        &buffer,
        64,
        null,
        null,
    );
    if (status != .SUCCESS) return error.ReadFileFailed;

    if (!std.mem.eql(u8, buffer[0..2], "MZ")) return error.InvalidExecutable;

    const pe_offset = std.mem.readInt(u32, buffer[0x3C..][0..4], .little);

    // Read PE Header
    var offset_li: windows.LARGE_INTEGER = @intCast(pe_offset);
    status = ntdll.NtReadFile(
        handle,
        null,
        null,
        null,
        &read_io_status,
        &buffer,
        24, // PE Sig (4) + COFF Header (20)
        &offset_li,
        null,
    );
    if (status != .SUCCESS) return error.ReadFileFailed;

    if (!std.mem.eql(u8, buffer[0..4], "PE\x00\x00")) return error.InvalidExecutable;

    const machine = std.mem.readInt(u16, buffer[4..6], .little);

    const arch: Arch = switch (machine) {
        0x014c => .x86,
        0x8664 => .x86_64,
        0x01c0, 0x01c2, 0x01c4 => .arm,
        0xaa64 => .arm64,
        else => .unknown,
    };

    return PEInfo{ .arch = arch };
}
