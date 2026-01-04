//! Solana Host for Roc Programs
//! Provides the entrypoint, memory management, and syscalls for Solana programs

const std = @import("std");
const builtin = @import("builtin");

const is_sbf = builtin.cpu.arch == .sbf and builtin.os.tag == .solana;
const is_bpf = builtin.cpu.arch == .bpfel and builtin.os.tag == .freestanding;
const is_test = builtin.is_test;
const is_solana = is_sbf or is_bpf;

const sdk = @import("solana_program_sdk");
const sdk_allocator = sdk.allocator;
const sdk_log = sdk.log;

// Roc functions provided by external object file (roc_app.o)
// Only declared when not testing (tests don't link with roc_app.o)
const roc__mainForHost_1_exposed_generic = if (is_test)
    struct {
        fn call(_: *RocStr) void {}
    }.call
else
    @extern(*const fn (*RocStr) callconv(.c) void, .{ .name = "roc__mainForHost_1_exposed_generic" }).*;

const roc__mainForHost_1_exposed_size = if (is_test)
    struct {
        fn call() i64 {
            return 24;
        }
    }.call
else
    @extern(*const fn () callconv(.c) i64, .{ .name = "roc__mainForHost_1_exposed_size" }).*;

// RocStr matches Roc's 64-bit string representation with Small String Optimization (SSO)
// For small strings (<= 23 bytes), bytes are stored inline in the struct
// High bit of capacity indicates SSO: if set, string is stored inline
pub const RocStr = extern struct {
    first_8_bytes: u64,
    second_8_bytes: u64,
    third_8_bytes: u64,

    const SMALL_STRING_FLAG: u64 = 0x8000000000000000;
    const LENGTH_MASK: u64 = 0x7F00000000000000;
    const LENGTH_SHIFT: u6 = 56;

    pub fn isSmallStr(self: *const RocStr) bool {
        return (self.third_8_bytes & SMALL_STRING_FLAG) != 0;
    }

    pub fn len(self: *const RocStr) usize {
        if (self.isSmallStr()) {
            return @intCast((self.third_8_bytes & LENGTH_MASK) >> LENGTH_SHIFT);
        } else {
            return @intCast(self.second_8_bytes);
        }
    }

    pub fn asSlice(self: *const RocStr) []const u8 {
        const length = self.len();
        if (length == 0) return &[_]u8{};

        if (self.isSmallStr()) {
            const self_ptr: [*]const u8 = @ptrCast(self);
            return self_ptr[0..length];
        } else {
            const ptr: [*]const u8 = @ptrFromInt(self.first_8_bytes);
            return ptr[0..length];
        }
    }
};

// ============================================
// Solana Program Entrypoint
// ============================================

pub export fn entrypoint(_: [*]u8) callconv(.c) u64 {
    // Call Roc's main function to get the string to log
    var result: RocStr = .{ .first_8_bytes = 0, .second_8_bytes = 0, .third_8_bytes = 0 };
    roc__mainForHost_1_exposed_generic(&result);

    // Log the result using Small String Optimization aware decoding
    const slice = result.asSlice();
    sdk_log.log(slice);

    // Return success
    return 0;
}

// ============================================
// Roc Runtime Functions (Memory Management)
// ============================================

pub export fn roc_alloc(size: usize, alignment: u32) callconv(.c) ?[*]u8 {
    const align_val = if (alignment == 0) 1 else @as(usize, alignment);
    const aligned_log2 = std.math.log2(@as(usize, align_val));
    const aligned: std.mem.Alignment = @enumFromInt(aligned_log2);
    return sdk_allocator.allocator.rawAlloc(size, aligned, @returnAddress());
}

pub export fn roc_realloc(ptr: [*]u8, new_size: usize, old_size: usize, alignment: u32) callconv(.c) ?[*]u8 {
    _ = ptr;
    _ = old_size;
    return roc_alloc(new_size, alignment);
}

pub export fn roc_dealloc(ptr: [*]u8, alignment: u32) callconv(.c) void {
    _ = ptr;
    _ = alignment;
}

pub export fn roc_panic(msg: [*:0]const u8, tag_id: u32) callconv(.c) noreturn {
    _ = tag_id;
    sdk_log.log(std.mem.span(msg));
    @panic("Roc panic");
}

pub export fn roc_dbg(loc: [*:0]const u8, msg: [*:0]const u8) callconv(.c) void {
    sdk_log.log(std.mem.span(loc));
    sdk_log.log(std.mem.span(msg));
}

pub export fn roc_memset(ptr: [*]u8, val: i32, count: usize) callconv(.c) [*]u8 {
    @memset(ptr[0..count], @intCast(val));
    return ptr;
}

pub export fn roc_memcpy(dest: [*]u8, src: [*]const u8, count: usize) callconv(.c) [*]u8 {
    @memcpy(dest[0..count], src[0..count]);
    return dest;
}

pub export fn memcpy_c(dest: [*]u8, src: [*]const u8, count: usize) callconv(.c) [*]u8 {
    @memcpy(dest[0..count], src[0..count]);
    return dest;
}

pub export fn memset_c(dest: [*]u8, val: i32, count: usize) callconv(.c) [*]u8 {
    @memset(dest[0..count], @intCast(val));
    return dest;
}

// ============================================
// Tests
// ============================================

test "RocStr heap string" {
    // Test heap-allocated string (non-SSO)
    const hello = "hello";
    const str = RocStr{
        .first_8_bytes = @intFromPtr(hello.ptr),
        .second_8_bytes = hello.len,
        .third_8_bytes = hello.len, // capacity without SSO flag
    };
    try std.testing.expect(!str.isSmallStr());
    try std.testing.expectEqual(@as(usize, 5), str.len());
    try std.testing.expectEqualStrings("hello", str.asSlice());
}

test "RocStr small string optimization" {
    // Test SSO: "Hello Solana!" (13 bytes) stored inline
    // Layout (little endian):
    //   first_8_bytes:  "Hello So" = 0x6f53206f6c6c6548
    //   second_8_bytes: "lana!\0\0\0" = 0x0000000021616e616c
    //   third_8_bytes:  high bit (SSO flag) | length in bits 56-62
    //                   = 0x8d00000000000000 (0x80 = SSO, 0x0d = 13)
    const str = RocStr{
        .first_8_bytes = 0x6f53206f6c6c6548, // "Hello So"
        .second_8_bytes = 0x0000000021616e616c, // "lana!"
        .third_8_bytes = 0x8d00000000000000, // SSO flag + length 13
    };
    try std.testing.expect(str.isSmallStr());
    try std.testing.expectEqual(@as(usize, 13), str.len());
    try std.testing.expectEqualStrings("Hello Solana!", str.asSlice());
}

test "RocStr empty string" {
    const str = RocStr{ .first_8_bytes = 0, .second_8_bytes = 0, .third_8_bytes = 0 };
    try std.testing.expect(!str.isSmallStr());
    try std.testing.expectEqual(@as(usize, 0), str.len());
    try std.testing.expectEqualStrings("", str.asSlice());
}
