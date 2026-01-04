platform "solana"
    requires {} { main : Str }
    exposes []
    packages {}
    provides [main_for_host]

main_for_host : Str
main_for_host = main
