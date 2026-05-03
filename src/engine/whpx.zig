const std = @import("std");
const windows = std.os.windows;

pub const WHV_PARTITION_HANDLE = *anyopaque;
pub const WHV_CAPABILITY_CODE = enum(u32) {
    HypervisorPresent = 0x00000000,
    Features = 0x00000001,
    ExtendedVmExits = 0x00000002,
    ProcessorVendor = 0x00001000,
    ProcessorFeatures = 0x00001001,
    ProcessorClFlushSize = 0x00001002,
};

pub const WHV_CAPABILITY = extern union {
    HypervisorPresent: bool,
    Features: u64,
    ProcessorVendor: u32,
    ProcessorFeatures: u64,
    ProcessorClFlushSize: u8,
};

pub const WHV_PARTITION_PROPERTY_CODE = enum(u32) {
    ExtendedVmExits = 0x00000001,
    ProcessorFeatures = 0x00000002,
    ProcessorClFlushSize = 0x00000003,
    ProcessorCount = 0x00001000,
};

pub const WHV_MAP_GPA_RANGE_FLAGS = packed struct(u32) {
    Read: bool = false,
    Write: bool = false,
    Execute: bool = false,
    Reserved: u29 = 0,
};

pub const WHV_REGISTER_NAME = enum(u32) {
    // GPRs
    Rax = 0x00000000,
    Rcx = 0x00000001,
    Rdx = 0x00000002,
    Rbx = 0x00000003,
    Rsp = 0x00000004,
    Rbp = 0x00000005,
    Rsi = 0x00000006,
    Rdi = 0x00000007,
    R8 = 0x00000008,
    R9 = 0x00000009,
    R10 = 0x0000000A,
    R11 = 0x0000000B,
    R12 = 0x0000000C,
    R13 = 0x0000000D,
    R14 = 0x0000000E,
    R15 = 0x0000000F,
    Rip = 0x00000010,
    Rflags = 0x00000011,
};

pub const WHV_REGISTER_VALUE = extern union {
    Reg128: [2]u64,
    Reg64: u64,
    Reg32: u32,
    Reg16: u16,
    Reg8: u8,
};

pub const WHV_RUN_VP_EXIT_REASON = enum(u32) {
    None = 0x00000000,
    MemoryAccess = 0x00000001,
    X64IoPortAccess = 0x00000002,
    UnrecoverableException = 0x00000004,
    InvalidVpRegisterValue = 0x00000005,
    UnsupportedFeature = 0x00000006,
    X64InterruptWindow = 0x00000007,
    X64Halt = 0x00000008,
    X64MsrAccess = 0x00000009,
    X64Cpuid = 0x0000000A,
    X64Exception = 0x0000000B,
    X64Rdtsc = 0x0000000C,
    X64ApicEoi = 0x0000000D,
    Hypercall = 0x0000000E,
    X64ApicSmiTrap = 0x0000000F,
    X64ApicInitSipiTrap = 0x00000010,
    X64ApicWriteTrap = 0x00000011,
    Canceled = 0x00002000,
};

pub const WHV_RUN_VP_EXIT_CONTEXT = extern struct {
    ExitReason: WHV_RUN_VP_EXIT_REASON,
    Reserved: u32,
    VpContext: extern union {
        MemoryAccess: extern struct {
            InstructionByteCount: u8,
            Reserved: [3]u8,
            InstructionBytes: [16]u8,
            AccessInfo: u32,
            Gpa: u64,
            Vpa: u64,
        },
        // ... add more as needed
        Padding: [248]u8,
    },
};

pub extern "WinHvPlatform" fn WHvGetCapability(
    CapabilityCode: WHV_CAPABILITY_CODE,
    CapabilityBuffer: *anyopaque,
    CapabilityBufferSizeInBytes: u32,
    WrittenSizeInBytes: ?*u32,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvCreatePartition(
    Partition: *WHV_PARTITION_HANDLE,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvSetupPartition(
    Partition: WHV_PARTITION_HANDLE,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvDeletePartition(
    Partition: WHV_PARTITION_HANDLE,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvSetPartitionProperty(
    Partition: WHV_PARTITION_HANDLE,
    PropertyCode: WHV_PARTITION_PROPERTY_CODE,
    PropertyBuffer: *const anyopaque,
    PropertyBufferSizeInBytes: u32,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvMapGpaRange(
    Partition: WHV_PARTITION_HANDLE,
    SourceAddress: *anyopaque,
    GuestAddress: u64,
    SizeInBytes: u64,
    Flags: WHV_MAP_GPA_RANGE_FLAGS,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvCreateVirtualProcessor(
    Partition: WHV_PARTITION_HANDLE,
    VpIndex: u32,
    Flags: u32,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvDeleteVirtualProcessor(
    Partition: WHV_PARTITION_HANDLE,
    VpIndex: u32,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvRunVirtualProcessor(
    Partition: WHV_PARTITION_HANDLE,
    VpIndex: u32,
    ExitContext: *WHV_RUN_VP_EXIT_CONTEXT,
    ExitContextSizeInBytes: u32,
) callconv(.winapi) i32;

pub extern "WinHvPlatform" fn WHvSetVirtualProcessorRegisters(
    Partition: WHV_PARTITION_HANDLE,
    VpIndex: u32,
    RegisterNames: [*]const WHV_REGISTER_NAME,
    RegisterCount: u32,
    RegisterValues: [*]const WHV_REGISTER_VALUE,
) callconv(.winapi) i32;
