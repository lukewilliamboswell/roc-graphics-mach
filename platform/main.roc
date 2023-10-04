platform "echo-in-zig"
    requires {} { main : Str -> Str }
    exposes []
    packages {}
    imports [TotallyNotJson]
    provides [mainForHost]

mainForHost : Str -> Str
mainForHost = \str -> main str
