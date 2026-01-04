platform "solana"
    requires {} { main : Str }
    exposes [Host]
    packages {}
    imports []
    provides [mainForHost]

mainForHost : Str
mainForHost = main
