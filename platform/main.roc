platform "roc-graphics"
    requires {} { main : { init : Init, render : Str} }
    exposes [
        Init,
    ]
    packages {}
    imports [
        Json.{json},
        Encode,
    ]
    provides [mainForHost]

mainForHost : Str -> Str
mainForHost = \_ ->
    Encode.toBytes main.init json |> Str.fromUtf8 |> Result.withDefault "UTF8 ERROR"

Init : {
    displayMode : Str, # "borderless" | "windowed" | "fullscreen"
    border: Bool,
    title: Str,
    width: U32,
    height: U32,
}