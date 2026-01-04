platform "solana"
    requires {} { main : Str }
    exposes []
    packages {}
    provides { main_for_host: "main" }
    targets: {
        files: "targets/",
        exe: {
            sbfsolana: ["libhost.a", app],
        }
    }

## This platform allows Roc applications to run on Solana blockchain.
##
## The main value is a string that will be logged to the Solana program log.
##
## Usage:
## ```roc
## app "hello"
##     provides [main] to pf
##     imports [pf.Stdout]
##
## main : Str
## main = "Hello from Roc on Solana!"
## ```
##
## The platform will:
## 1. Call the Roc `main` function
## 2. Pass the returned string to the Solana log via the Zig host
## 3. Return success (0) to the Solana runtime

main_for_host : Str
main_for_host = main
