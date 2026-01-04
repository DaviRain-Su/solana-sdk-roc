app [main] { pf: platform "platform/main.roc" }

main : Str
main =
    n = 15
    result = fib n
    "Fib($(Num.to_str n)) = $(Num.to_str result)"

fib : U64 -> U64
fib = \n ->
    if n <= 1 then
        n
    else
        fib (n - 1) + fib (n - 2)
