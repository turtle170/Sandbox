const std = @import("std");
const windows = std.os.windows;
const whpx = @import("whpx.zig");
const unicorn = @import("unicorn.zig");
const memory = @import("../memory.zig");

pub const EngineType = enum {
    whpx,
    unicorn,
};

pub const SandboxEngine = struct {
    engine_type: EngineType,
    partition: ?whpx.WHV_PARTITION_HANDLE = null,
    uc: ?unicorn.uc_engine = null,
    mem: *memory.SandboxMemory,

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

            // Setup 1 VCPU
            const vcpu_count: u32 = 1;
            _ = whpx.WHvSetPartitionProperty(handle, .ProcessorCount, &vcpu_count, 4);
            _ = whpx.WHvSetupPartition(handle);
        } else {
            // Setup Unicorn for x86_64 by default for now
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

    pub fn handlePageFault(self: *SandboxEngine, gpa: u64) !void {
        const hva = try self.mem.popHeadroom(gpa);
        
        if (self.engine_type == .whpx) {
            _ = whpx.WHvMapGpaRange(self.partition.?, hva, gpa, 4096, .{
                .Read = true, .Write = true, .Execute = true
            });
        } else {
            _ = unicorn.uc_mem_map(self.uc.?, gpa, 4096, 7); // Read | Write | Exec
        }
        
        // Asynchronously maintain headroom
        try self.mem.maintainHeadroom();
    }
};
