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
## The main value is a string that will be logged to the Solana program log.

main_for_host : Str
main_for_host = main
