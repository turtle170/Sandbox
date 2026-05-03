const std = @import("std");
const windows = std.os.windows;
const whpx = @import("engine/whpx.zig");
const unicorn = @import("engine/unicorn.zig");

pub const MemoryPage = struct {
    gpa: u64,
    hva: *anyopaque,
};

pub const SandboxMemory = struct {
    allocator: std.mem.Allocator,
    pages: std.array_list.Managed(MemoryPage),
    headroom_pages: std.array_list.Managed(MemoryPage),
    
    pub fn init(allocator: std.mem.Allocator) SandboxMemory {
        return .{
            .allocator = allocator,
            .pages = std.array_list.Managed(MemoryPage).init(allocator),
            .headroom_pages = std.array_list.Managed(MemoryPage).init(allocator),
        };
    }

    pub fn deinit(self: *SandboxMemory) void {
        for (self.pages.items) |page| {
            var region_size: usize = 0;
            var base_addr: windows.PVOID = page.hva;
            _ = windows.ntdll.NtFreeVirtualMemory(
                @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))), // current process
                &base_addr,
                &region_size,
                .{ .RELEASE = true },
            );
        }
        for (self.headroom_pages.items) |page| {
            var region_size: usize = 0;
            var base_addr: windows.PVOID = page.hva;
            _ = windows.ntdll.NtFreeVirtualMemory(
                @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))), // current process
                &base_addr,
                &region_size,
                .{ .RELEASE = true },
            );
        }
        self.pages.deinit();
        self.headroom_pages.deinit();
    }

    /// Allocates a single page (4KB) and returns the HVA.
    pub fn allocatePage(self: *SandboxMemory, gpa: u64) !*anyopaque {
        var base_addr: ?windows.PVOID = null;
        var region_size: usize = 4096;
        const status = windows.ntdll.NtAllocateVirtualMemory(
            @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))), // current process
            @ptrCast(&base_addr),
            0,
            &region_size,
            .{ .COMMIT = true, .RESERVE = true },
            .{ .READWRITE = true },
        );

        if (status != .SUCCESS) return error.OutOfMemory;

        try self.pages.append(.{ .gpa = gpa, .hva = base_addr.? });
        return base_addr.?;
    }

    /// Maintains the 1MB headroom (256 pages).
    pub fn maintainHeadroom(self: *SandboxMemory) !void {
        while (self.headroom_pages.items.len < 256) {
            var base_addr: ?windows.PVOID = null;
            var region_size: usize = 4096;
            const status = windows.ntdll.NtAllocateVirtualMemory(
                @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))), // current process
                @ptrCast(&base_addr),
                0,
                &region_size,
                .{ .COMMIT = true, .RESERVE = true },
                .{ .READWRITE = true },
            );

            if (status != .SUCCESS) return error.OutOfMemory;
            
            try self.headroom_pages.append(.{ .gpa = 0, .hva = base_addr.? });
        }
    }

    /// Pops a page from headroom to be used for a real GPA mapping.
    pub fn popHeadroom(self: *SandboxMemory, gpa: u64) !*anyopaque {
        if (self.headroom_pages.items.len == 0) {
            return try self.allocatePage(gpa);
        }
        var page = self.headroom_pages.pop();
        page.gpa = gpa;
        try self.pages.append(page);
        return page.hva;
    }
};
