const std = @import("std");
const windows = std.os.windows;
const ntdll = windows.ntdll;

pub const Gui = struct {
    shm_handle: windows.HANDLE,
    shm_buffer: [*]u8,
    host_window: windows.HWND = undefined,

    pub fn init(width: u32, height: u32) !Gui {
        const size: i64 = @intCast(width * height * 4);
        var handle: windows.HANDLE = undefined;
        var max_size: windows.LARGE_INTEGER = size;

        const status = ntdll.NtCreateSection(
            &handle,
            .{ .STANDARD = .{ .RIGHTS = .REQUIRED, .SYNCHRONIZE = true }, .SPECIFIC = .{ .bits = 0xF } }, // SECTION_ALL_ACCESS
            null,
            &max_size,
            .{ .READWRITE = true },
            .{ .COMMIT = true },
            null,
        );

        if (status != .SUCCESS) return error.ShmCreationFailed;

        var base_addr: ?windows.PVOID = null;
        var view_size: usize = 0;
        const map_status = ntdll.NtMapViewOfSection(
            handle,
            @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))), // current process
            @ptrCast(&base_addr),
            null,
            0,
            null,
            &view_size,
            @enumFromInt(1), // ViewShare
            .{ .RESERVE = false },
            .{ .READWRITE = true },
        );

        if (map_status != .SUCCESS) {
            _ = ntdll.NtClose(handle);
            return error.MapViewFailed;
        }

        return .{
            .shm_handle = handle,
            .shm_buffer = @ptrCast(base_addr.?),
        };
    }

    pub fn deinit(self: *Gui) void {
        _ = ntdll.NtUnmapViewOfSection(
            @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))),
            self.shm_buffer,
        );
        _ = ntdll.NtClose(self.shm_handle);
    }
};
