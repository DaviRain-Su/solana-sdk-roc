//! Stub implementation for Roc main function
//! This provides a placeholder until Roc supports native SBF code generation
//!
//! The stub message is distinct from app.roc content so you can tell which is running:
//! - Stub: "[STUB] Awaiting Roc native SBF codegen"
//! - Actual Roc: Whatever is in your app.roc main function

const RocStr = extern struct {
    bytes: ?[*]const u8,
    length: u32,
    capacity: u32,
};

// Stub message - clearly different from any app.roc content
const stub_message = "[STUB] Awaiting Roc native SBF codegen";

/// Stub implementation of the Roc main function
/// This will be replaced when Roc supports native SBF code generation
pub export fn roc__main_for_host_1_exposed_generic(output: *RocStr) callconv(.c) void {
    output.* = RocStr{
        .bytes = stub_message.ptr,
        .length = @intCast(stub_message.len),
        .capacity = @intCast(stub_message.len),
    };
}

pub export fn roc__main_for_host_1_exposed_size() callconv(.c) i64 {
    return @sizeOf(RocStr);
}
