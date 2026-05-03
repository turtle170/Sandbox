const std = @import("std");
const windows = std.os.windows;
const pe_parser = @import("../pe_parser.zig");
const memory = @import("../memory.zig");

pub const Loader = struct {
    allocator: std.mem.Allocator,
    mem_manager: *memory.SandboxMemory,

    pub const Section = struct {
        name: [8]u8,
        virtual_address: u64,
        size: u32,
        characteristics: u32,
    };

    pub fn init(allocator: std.mem.Allocator, mem_manager: *memory.SandboxMemory) Loader {
        return .{
            .allocator = allocator,
            .mem_manager = mem_manager,
        };
    }

    pub fn loadExecutable(self: *Loader, path: []const u8, io: std.Io) !u64 {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer io.vtable.fileClose(io.userdata, &.{file});

        var buffer: [4096]u8 = undefined;
        // Manual seek and read using VTable for extreme surgical precision in 0.16.0
        
        // 1. Seek to 0x3C to find PE header offset
        try io.vtable.fileSeekTo(io.userdata, file, 0x3C);
        
        // 2. Read PE offset
        const slice_3c: []u8 = buffer[0..4];
        const data_3c: []const []u8 = &.{slice_3c};
        _ = try io.vtable.fileReadPositional(io.userdata, file, data_3c, 0x3C);
        const pe_offset = std.mem.readInt(u32, buffer[0..4], .little);

        // 3. Read COFF Header (4 bytes after signature)
        try io.vtable.fileSeekTo(io.userdata, file, pe_offset + 4);
        const slice_coff: []u8 = buffer[0..20];
        const data_coff: []const []u8 = &.{slice_coff};
        _ = try io.vtable.fileReadPositional(io.userdata, file, data_coff, pe_offset + 4);
        
        const num_sections = std.mem.readInt(u16, buffer[2..4], .little);
        const size_opt_header = std.mem.readInt(u16, buffer[16..18], .little);

        // 4. Read Optional Header Magic
        const opt_header_offset = pe_offset + 24;
        try io.vtable.fileSeekTo(io.userdata, file, opt_header_offset);
        const slice_magic: []u8 = buffer[0..2];
        const data_magic: []const []u8 = &.{slice_magic};
        _ = try io.vtable.fileReadPositional(io.userdata, file, data_magic, opt_header_offset);
        const magic = std.mem.readInt(u16, buffer[0..2], .little);

        var entry_point: u32 = 0;
        var image_base: u64 = 0;

        if (magic == 0x10b) { // PE32
            const slice_pe32: []u8 = buffer[0..32];
            const data_pe32: []const []u8 = &.{slice_pe32};
            _ = try io.vtable.fileReadPositional(io.userdata, file, data_pe32, opt_header_offset);
            entry_point = std.mem.readInt(u32, buffer[16..20], .little);
            image_base = std.mem.readInt(u32, buffer[28..32], .little);
        } else if (magic == 0x20b) { // PE32+
            const slice_pe32p: []u8 = buffer[0..40];
            const data_pe32p: []const []u8 = &.{slice_pe32p};
            _ = try io.vtable.fileReadPositional(io.userdata, file, data_pe32p, opt_header_offset);
            entry_point = std.mem.readInt(u32, buffer[16..20], .little);
            image_base = std.mem.readInt(u64, buffer[24..32], .little);
        }

        // 5. Read Sections
        const section_header_offset = opt_header_offset + size_opt_header;
        var i: usize = 0;
        while (i < num_sections) : (i += 1) {
            const offset = section_header_offset + (i * 40);
            const slice_sec: []u8 = buffer[0..40];
            const data_sec: []const []u8 = &.{slice_sec};
            _ = try io.vtable.fileReadPositional(io.userdata, file, data_sec, offset);
            
            const name = buffer[0..8];
            const virtual_address = std.mem.readInt(u32, buffer[12..16], .little);
            const size_of_raw_data = std.mem.readInt(u32, buffer[16..20], .little);

            if (size_of_raw_data > 0) {
                std.debug.print("Mapping section {s} at 0x{x}\n", .{name, image_base + virtual_address});
                _ = self.mem_manager; 
            }
        }

        return image_base + entry_point;
    }
};
