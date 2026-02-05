# Roc Contract ABI (A3-simple)

This doc defines the minimal ABI for writing Solana program business logic in **Roc** while keeping the Zig host responsible for:

- decoding Solana accounts + instruction bytes
- enforcing basic safety checks (writable, owner == program id)
- reading/writing account data

## Why this ABI

- Stable, easy to FFI
- No pointers passed into Roc
- Roc code is pure logic: `(old_state, instruction_bytes) -> new_state | error`

## Instruction bytes

We represent instruction data as `List U8` in Roc.

## Return encoding

Roc returns a `U64` where:

- **Success**: `new_state` (high bit is 0)
- **Error**: `0x8000_0000_0000_0000 | errCode`

`errCode` is stored in the low 32 bits.

Zig host interprets this and returns `ProgramError.custom(errCode)`.

## Example: Counter contract

See `app/counter.roc`.

- `[]` or `[0]` => init (set counter=0)
- `[1]` => increment
- `[2, <u64 little-endian>]` => add

Recommended error codes:

- `1` missing counter account
- `2` account not writable
- `3` account not owned by program
- `4` account data too small
- `5` invalid instruction data (missing bytes)
- `6` unknown instruction tag
