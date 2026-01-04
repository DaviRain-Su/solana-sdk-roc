app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 10
    result = fib n
    "Fib(10) = $(Num.to_str result)"

fib : U64 -> U64
fib = \num ->
    if num <= 1 then
        num
    else
        fib (num - 1) + fib (num - 2)
