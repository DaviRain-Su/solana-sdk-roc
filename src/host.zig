//! Solana Host Implementation for Roc Programs
//!
//! This module bridges Roc programs to the Solana runtime by:
//! 1. Providing Roc runtime functions (roc_alloc, roc_panic, etc.)
//! 2. Using solana-program-sdk-zig for allocator and logging
//! 3. Defining the entrypoint that calls Roc's main function

const std = @import("std");
const builtin = @import("builtin");

const is_bpf = builtin.cpu.arch == .bpfel and builtin.os.tag == .freestanding;
const is_test = builtin.is_test;

const sdk = @import("solana_sdk");
const sdk_allocator = sdk.allocator;
const sdk_log = sdk.log;

const SMALL_STRING_SIZE = @sizeOf(RocStr);
const MASK_ISIZE: isize = std.math.minInt(isize);
const SEAMLESS_SLICE_BIT: usize = @as(usize, @bitCast(MASK_ISIZE));

pub const RocStr = extern struct {
    bytes: ?[*]u8,
    length: usize,
    capacity_or_alloc_ptr: usize,

    pub fn empty() RocStr {
        return RocStr{
            .bytes = null,
            .length = 0,
            .capacity_or_alloc_ptr = SEAMLESS_SLICE_BIT,
        };
    }

    pub fn isSmallStr(self: RocStr) bool {
        return @as(isize, @bitCast(self.capacity_or_alloc_ptr)) < 0;
    }

    pub fn len(self: *const RocStr) usize {
        if (self.isSmallStr()) {
            return self.asArray()[SMALL_STRING_SIZE - 1] ^ 0b1000_0000;
        } else {
            return self.length & (~SEAMLESS_SLICE_BIT);
        }
    }

    fn asArray(self: RocStr) [SMALL_STRING_SIZE]u8 {
        return @as([*]const u8, @ptrCast(&self))[0..SMALL_STRING_SIZE].*;
    }

    pub fn asSlice(self: *const RocStr) []const u8 {
        return self.asU8ptr()[0..self.len()];
    }

    pub fn asU8ptr(self: *const RocStr) [*]const u8 {
        if (self.isSmallStr()) {
            return @as([*]const u8, @ptrCast(self));
        } else {
            return @as([*]const u8, @ptrCast(self.bytes));
        }
    }

    pub fn decref(self: *RocStr) void {
        _ = self;
    }
};

fn getTestAllocator() std.mem.Allocator {
    return std.heap.page_allocator;
}

export fn roc_alloc(size: usize, alignment: u32) callconv(.c) ?*anyopaque {
    if (is_test) {
        const alloc = getTestAllocator();
        const align_val = std.mem.Alignment.fromByteUnits(alignment);
        const result = alloc.rawAlloc(size, align_val, @returnAddress());
        return if (result) |ptr| @ptrCast(ptr) else null;
    } else {
        const alloc = sdk_allocator.allocator;
        const align_val = std.mem.Alignment.fromByteUnits(alignment);
        const result = alloc.rawAlloc(size, align_val, @returnAddress());
        return if (result) |ptr| @ptrCast(ptr) else null;
    }
}

export fn roc_realloc(c_ptr: *anyopaque, new_size: usize, old_size: usize, alignment: u32) callconv(.c) ?*anyopaque {
    const copy_size = @min(old_size, new_size);
    const new_ptr = roc_alloc(new_size, alignment);
    if (new_ptr) |ptr| {
        const new_bytes: [*]u8 = @ptrCast(ptr);
        const old_bytes: [*]const u8 = @ptrCast(c_ptr);
        @memcpy(new_bytes[0..copy_size], old_bytes[0..copy_size]);
    }
    return new_ptr;
}

export fn roc_dealloc(c_ptr: *anyopaque, alignment: u32) callconv(.c) void {
    _ = c_ptr;
    _ = alignment;
}

export fn roc_panic(msg: *RocStr, tag_id: u32) callconv(.c) void {
    _ = tag_id;
    sdk_log.log(msg.asSlice());
}

export fn roc_dbg(loc: *RocStr, msg: *RocStr, src: *RocStr) callconv(.c) void {
    _ = loc;
    _ = src;
    sdk_log.log(msg.asSlice());
}

export fn roc_memset(dst: [*]u8, value: i32, size: usize) callconv(.c) void {
    @memset(dst[0..size], @as(u8, @intCast(value)));
}

export fn roc_memcpy(dst: [*]u8, src: [*]const u8, size: usize) callconv(.c) void {
    @memcpy(dst[0..size], src[0..size]);
}

export fn entrypoint(input: [*]u8) callconv(.c) u64 {
    _ = input;

    const msg = "Hello Roc on Solana!";
    sdk_log.log(msg);

    return 0;
}

test "RocStr: empty string" {
    const str = RocStr.empty();
    try std.testing.expectEqual(@as(usize, 0), str.len());
}

test "RocStr: small string" {
    var str = RocStr.empty();
    const msg = "Hello!";
    const str_bytes = @as([*]u8, @ptrCast(&str));
    @memcpy(str_bytes[0..msg.len], msg);
    str_bytes[SMALL_STRING_SIZE - 1] = @as(u8, @intCast(msg.len)) | 0b1000_0000;

    try std.testing.expectEqual(@as(usize, msg.len), str.len());
    try std.testing.expectEqualStrings(msg, str.asSlice());
}

test "roc_alloc: basic allocation" {
    const ptr = roc_alloc(100, 8);
    try std.testing.expect(ptr != null);
}

test "entrypoint: basic execution" {
    var dummy_input: [1]u8 = .{0};
    const result = entrypoint(&dummy_input);
    try std.testing.expectEqual(@as(u64, 0), result);
}
