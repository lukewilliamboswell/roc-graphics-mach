platform "roc-graphics"
    requires {} { main : Str -> Str }
    exposes []
    packages {}
    imports []
    provides [mainForHost]

mainForHost : Str -> Str
mainForHost = \fromHost -> main fromHost