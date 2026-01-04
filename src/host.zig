//! Solana Host for Roc Programs
//! Provides the entrypoint, memory management, and syscalls for Solana programs

const std = @import("std");
const builtin = @import("builtin");

const is_bpf = builtin.cpu.arch == .bpfel and builtin.os.tag == .freestanding;
const is_test = builtin.is_test;

const sdk = @import("solana_program_sdk");
const sdk_allocator = sdk.allocator;
const sdk_log = sdk.log;

// Configuration: Set to true when linking with actual Roc-compiled code
const use_external_roc = true;

// When using external Roc, declare extern functions
// When not using external Roc, we'll provide Zig implementations
const roc_fns = if (use_external_roc) struct {
    extern fn roc__main_for_host_1_exposed_generic(output: *RocStr) callconv(.c) void;
    extern fn roc__main_for_host_1_exposed_size() callconv(.c) i64;
} else struct {
    // Embedded string: "Hello from Roc on Solana!"
    const hello_str = "Hello from Roc on Solana!";

    fn roc__main_for_host_1_exposed_generic(output: *RocStr) callconv(.c) void {
        output.* = RocStr{
            .bytes = hello_str.ptr,
            .length = hello_str.len,
            .capacity = hello_str.len,
        };
    }

    fn roc__main_for_host_1_exposed_size() callconv(.c) i64 {
        return @sizeOf(RocStr);
    }
};

/// RocStr - Roc's string type ABI
/// Layout matches Roc's x86_64 ABI: { ptr, i32 length, i32 capacity }
/// Total size: 16 bytes on 64-bit platforms
///
/// Note: This is a simplified version that doesn't support small string optimization.
/// Roc's actual RocStr has more complex semantics, but for Solana's limited environment,
/// we only need to read heap-allocated strings from Roc.
pub const RocStr = extern struct {
    bytes: ?[*]const u8,
    length: u32,
    capacity: u32,

    pub fn empty() RocStr {
        return RocStr{
            .bytes = null,
            .length = 0,
            .capacity = 0,
        };
    }

    pub fn len(self: *const RocStr) usize {
        return @as(usize, self.length);
    }

    pub fn asSlice(self: *const RocStr) []const u8 {
        if (self.bytes) |ptr| {
            return ptr[0..self.len()];
        }
        return &[_]u8{};
    }

    pub fn decref(self: *RocStr) void {
        _ = self;
        // Solana uses bump allocator, no need to free
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

/// Solana program entrypoint
/// Calls Roc's main_for_host and logs the returned string
export fn entrypoint(input: [*]u8) callconv(.c) u64 {
    _ = input;

    // Call Roc's main function
    var roc_result: RocStr = RocStr.empty();

    if (is_bpf) {
        // In BPF mode, call the Roc function (extern or embedded)
        roc_fns.roc__main_for_host_1_exposed_generic(&roc_result);
        sdk_log.log(roc_result.asSlice());
    } else {
        // In test mode, use a placeholder
        const msg = "Hello Roc on Solana! (test mode)";
        sdk_log.log(msg);
    }

    return 0;
}

test "RocStr: empty string" {
    const str = RocStr.empty();
    try std.testing.expectEqual(@as(usize, 0), str.len());
}

test "RocStr: heap string" {
    const msg = "Hello!";
    const str = RocStr{
        .bytes = msg.ptr,
        .length = @intCast(msg.len),
        .capacity = @intCast(msg.len),
    };

    try std.testing.expectEqual(@as(usize, msg.len), str.len());
    try std.testing.expectEqualStrings(msg, str.asSlice());
}

test "RocStr: size is 16 bytes" {
    // Verify ABI compatibility with Roc
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(RocStr));
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
