app "rocLovesZig"
    packages { pf: "../platform/main.roc" }
    imports []
    provides [main] to pf

main : Str -> Str
main = \str -> "Hi, \(str)!!"
