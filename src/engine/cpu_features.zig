const std = @import("std");
const builtin = @import("builtin");

pub const CpuFeatures = struct {
    avx: bool = false,
    avx2: bool = false,
    avx2_vnni: bool = false,
    avx512f: bool = false,
    avx512vnni: bool = false,
    avx10_1: bool = false,

    pub fn detect() CpuFeatures {
        var features = CpuFeatures{};

        if (builtin.cpu.arch != .x86_64 and builtin.cpu.arch != .x86) {
            return features;
        }

        // CPUID helper
        const cpuid = struct {
            fn call(leaf: u32, subleaf: u32) [4]u32 {
                var eax: u32 = undefined;
                var ebx: u32 = undefined;
                var ecx: u32 = undefined;
                var edx: u32 = undefined;
                asm volatile ("cpuid"
                    : [eax] "={eax}" (eax),
                      [ebx] "={ebx}" (ebx),
                      [ecx] "={ecx}" (ecx),
                      [edx] "={edx}" (edx),
                    : [leaf] "{eax}" (leaf),
                      [subleaf] "{ecx}" (subleaf),
                );
                return .{ eax, ebx, ecx, edx };
            }
        };

        // Leaf 1: AVX
        const leaf1 = cpuid.call(1, 0);
        features.avx = (leaf1[2] & (1 << 28)) != 0;

        // Leaf 7, Subleaf 0: AVX2, AVX512F
        const leaf7_0 = cpuid.call(7, 0);
        features.avx2 = (leaf7_0[1] & (1 << 5)) != 0;
        features.avx512f = (leaf7_0[1] & (1 << 16)) != 0;
        features.avx512vnni = (leaf7_0[2] & (1 << 11)) != 0;

        // Leaf 7, Subleaf 1: AVX2-VNNI, AVX10
        const leaf7_1 = cpuid.call(7, 1);
        features.avx2_vnni = (leaf7_1[0] & (1 << 4)) != 0;
        features.avx10_1 = (leaf7_1[1] & (1 << 19)) != 0;

        return features;
    }

    pub fn log(self: CpuFeatures) void {
        std.debug.print("CPU Capabilities Detected:\n", .{});
        std.debug.print("  AVX:         {s}\n", .{if (self.avx) "Yes" else "No"});
        std.debug.print("  AVX2:        {s}\n", .{if (self.avx2) "Yes" else "No"});
        std.debug.print("  AVX2-VNNI:   {s}\n", .{if (self.avx2_vnni) "Yes" else "No"});
        std.debug.print("  AVX-512F:    {s}\n", .{if (self.avx512f) "Yes" else "No"});
        std.debug.print("  AVX-512VNNI: {s}\n", .{if (self.avx512vnni) "Yes" else "No"});
        std.debug.print("  AVX-10.1:    {s}\n", .{if (self.avx10_1) "Yes" else "No"});
    }
};
