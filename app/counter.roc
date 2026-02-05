app [main_for_host] { pf: platform "../platform/main.roc" }

# A3-simple: Roc business logic for a stateful counter contract.
#
# Instruction data (bytes):
# - [] or [0]         => init (set counter=0)
# - [1]               => increment by 1
# - [2, <u64-le>]     => add amount
#
# Return value encoding (u64):
# - success: new_counter (high bit 0)
# - error:   0x8000_0000_0000_0000 | errCode (errCode in low 32 bits)

main_for_host : Str
main_for_host = "roc-counter"

ERR_FLAG : U64
ERR_FLAG = 0x8000_0000_0000_0000

err : U64 -> U64
err code = ERR_FLAG | code

is_err : U64 -> Bool
is_err x = (x & ERR_FLAG) != 0

# Decode little-endian u64 from bytes starting at idx.
# Returns error code if not enough bytes.
read_u64_le : List U8, U64 -> U64
read_u64_le bytes idx =
  if (List.length bytes) < (idx + 8) then
    err 5
  else
    let
      b0 = bytes |> List.get idx |> U8.to_u64
      b1 = bytes |> List.get (idx + 1) |> U8.to_u64
      b2 = bytes |> List.get (idx + 2) |> U8.to_u64
      b3 = bytes |> List.get (idx + 3) |> U8.to_u64
      b4 = bytes |> List.get (idx + 4) |> U8.to_u64
      b5 = bytes |> List.get (idx + 5) |> U8.to_u64
      b6 = bytes |> List.get (idx + 6) |> U8.to_u64
      b7 = bytes |> List.get (idx + 7) |> U8.to_u64
    in
    b0
    | (b1 << 8)
    | (b2 << 16)
    | (b3 << 24)
    | (b4 << 32)
    | (b5 << 40)
    | (b6 << 48)
    | (b7 << 56)

handle_counter : U64, List U8 -> U64
handle_counter old bytes =
  let
    tag =
      when bytes is
        [] -> 0
        [x, ..] -> x
  in
  if tag == 0 then
    0
  else if tag == 1 then
    old + 1
  else if tag == 2 then
    let amt = read_u64_le bytes 1
    in
    if is_err amt then
      amt
    else
      old + amt
  else
    err 6
