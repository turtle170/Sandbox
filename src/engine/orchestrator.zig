const std = @import("std");
const windows = std.os.windows;
const whpx = @import("whpx.zig");
const unicorn = @import("unicorn.zig");
const memory = @import("../memory.zig");

const kernel32 = struct {
    pub extern "kernel32" fn Sleep(dwMilliseconds: windows.DWORD) callconv(.winapi) void;
};

pub const EngineType = enum {
    whpx,
    unicorn,
};

pub const SandboxEngine = struct {
    engine_type: EngineType,
    partition: ?whpx.WHV_PARTITION_HANDLE = null,
    uc: ?unicorn.uc_engine = null,
    mem: *memory.SandboxMemory,
    running: bool = false,

    pub fn init(engine_type: EngineType, mem: *memory.SandboxMemory) !SandboxEngine {
        var self = SandboxEngine{
            .engine_type = engine_type,
            .mem = mem,
        };

        if (engine_type == .whpx) {
            var handle: whpx.WHV_PARTITION_HANDLE = undefined;
            const hr = whpx.WHvCreatePartition(&handle);
            if (hr != 0) return error.WhpxCreateFailed;
            self.partition = handle;

            const vcpu_count: u32 = 1;
            _ = whpx.WHvSetPartitionProperty(handle, .ProcessorCount, &vcpu_count, 4);
            _ = whpx.WHvSetupPartition(handle);
        } else {
            try unicorn.load();
            var uc: unicorn.uc_engine = undefined;
            const err = unicorn.uc_open(.X86, .X86_64, &uc);
            if (err != .OK) return error.UnicornInitFailed;
            self.uc = uc;
        }

        return self;
    }

    pub fn deinit(self: *SandboxEngine) void {
        if (self.partition) |p| _ = whpx.WHvDeletePartition(p);
        if (self.uc) |u| _ = unicorn.uc_close(u);
    }

    pub fn run(self: *SandboxEngine, entry_point: u64, shm_buffer: [*]u8) void {
        self.running = true;
        std.debug.print("Engine: Starting execution at 0x{x}\n", .{entry_point});

        // Simulation Loop: Draw a moving rectangle in SHM to verify GUI relay
        var x: u32 = 0;
        const width = 1920;
        while (self.running) {
            // Fill a 100x100 block with a dynamic color
            var ry: u32 = 100;
            while (ry < 200) : (ry += 1) {
                var rx: u32 = x;
                while (rx < x + 100) : (rx += 1) {
                    const actual_x = rx % width;
                    const offset = (ry * width + actual_x) * 4;
                    shm_buffer[offset + 0] = @truncate(x);      // B
                    shm_buffer[offset + 1] = @truncate(x / 2);  // G
                    shm_buffer[offset + 2] = 0xFF;              // R
                    shm_buffer[offset + 3] = 0xFF;              // A
                }
            }
            
            x = (x + 5) % 1024;
            kernel32.Sleep(16); // ~60fps
        }
    }

    pub fn handlePageFault(self: *SandboxEngine, gpa: u64) !void {
        const hva = try self.mem.popHeadroom(gpa);
        if (self.engine_type == .whpx) {
            _ = whpx.WHvMapGpaRange(self.partition.?, hva, gpa, 4096, .{
                .Read = true, .Write = true, .Execute = true
            });
        } else {
            _ = unicorn.uc_mem_map(self.uc.?, gpa, 4096, 7);
        }
        try self.mem.maintainHeadroom();
    }
};
