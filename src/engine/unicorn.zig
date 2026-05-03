const std = @import("std");
const windows = std.os.windows;

pub const uc_engine = *anyopaque;
pub const uc_err = enum(u32) {
    OK = 0,
    NOMEM,
    ARCH,
    HANDLE,
    MODE,
    VERSION,
    READ_UNMAPPED,
    WRITE_UNMAPPED,
    FETCH_UNMAPPED,
    HOOK_EXIST,
    RESOURCE,
    UNALIGNED,
};

pub const uc_arch = enum(u32) {
    ARM = 1,
    ARM64,
    MIPS,
    X86,
    PPC,
    SPARC,
    M68K,
};

pub const uc_mode = enum(u32) {
    LITTLE_ENDIAN = 0,
    BIG_ENDIAN = 1 << 31,
    X86_16 = 1 << 1,
    X86_32 = 1 << 2,
    X86_64 = 1 << 3,
    ARM = 1 << 0,
    THUMB = 1 << 4,
    MCLASS = 1 << 5,
    V8 = 1 << 6,
};

var unicorn_lib: ?windows.HANDLE = null;

const UcOpenFn = *const fn (arch: uc_arch, mode: uc_mode, engine: *uc_engine) callconv(.winapi) uc_err;
const UcCloseFn = *const fn (engine: uc_engine) callconv(.winapi) uc_err;
const UcMemMapFn = *const fn (engine: uc_engine, address: u64, size: usize, perms: u32) callconv(.winapi) uc_err;

var uc_open_ptr: ?UcOpenFn = null;
var uc_close_ptr: ?UcCloseFn = null;
var uc_mem_map_ptr: ?UcMemMapFn = null;

const kernel32 = struct {
    pub extern "kernel32" fn LoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) ?windows.HANDLE;
    pub extern "kernel32" fn GetProcAddress(hModule: windows.HANDLE, lpProcName: windows.LPCSTR) callconv(.winapi) ?windows.FARPROC;
};

pub fn load() !void {
    if (unicorn_lib != null) return;
    
    const lib_name = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "unicorn.dll");
    defer std.heap.page_allocator.free(lib_name);

    const lib = kernel32.LoadLibraryW(lib_name.ptr) orelse return error.LibraryNotFound;
    unicorn_lib = lib;

    uc_open_ptr = @ptrCast(kernel32.GetProcAddress(lib, "uc_open"));
    uc_close_ptr = @ptrCast(kernel32.GetProcAddress(lib, "uc_close"));
    uc_mem_map_ptr = @ptrCast(kernel32.GetProcAddress(lib, "uc_mem_map"));
}

pub fn uc_open(arch: uc_arch, mode: uc_mode, engine: *uc_engine) uc_err {
    return uc_open_ptr.?(arch, mode, engine);
}

pub fn uc_close(engine: uc_engine) uc_err {
    return uc_close_ptr.?(engine);
}

pub fn uc_mem_map(engine: uc_engine, address: u64, size: usize, perms: u32) uc_err {
    return uc_mem_map_ptr.?(engine, address, size, perms);
}

// Stub for remaining functions if needed
pub fn uc_mem_write(_: uc_engine, _: u64, _: [*]const u8, _: usize) uc_err { return .OK; }
pub fn uc_mem_read(_: uc_engine, _: u64, _: [*]u8, _: usize) uc_err { return .OK; }
pub fn uc_emu_start(_: uc_engine, _: u64, _: u64, _: u64, _: usize) uc_err { return .OK; }
pub fn uc_reg_write(_: uc_engine, _: c_int, _: *const anyopaque) uc_err { return .OK; }
pub fn uc_reg_read(_: uc_engine, _: c_int, _: *anyopaque) uc_err { return .OK; }
