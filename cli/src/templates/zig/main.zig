const sol = @import("solana_program_sdk");

fn processInstruction(program_id: *sol.PublicKey, accounts: []sol.Account, data: []const u8) sol.ProgramResult {
    _ = accounts;
    _ = data;
    sol.print("Hello from Zig on Solana! Program: {f}", .{program_id});
    return .ok;
}

comptime {
    sol.entrypoint(&processInstruction);
}
