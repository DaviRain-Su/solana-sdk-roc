app "hello"
    provides [main] to pf
    imports [pf.Stdout]

main : Str
main = "Hello from Roc on Solana!"
