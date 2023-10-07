platform "roc-graphics"
    requires {} { main : { init : Init, render : Str} }
    exposes []
    packages {}
    imports [
        Json.{json},
        Encode,
    ]
    provides [mainForHost]

mainForHost : Str -> Str
mainForHost = \fromHost ->
    when fromHost is 
        "INIT" -> 
            Encode.toBytes main.init json |> Str.fromUtf8 |> Result.withDefault "UTF8 ERROR"

        "RENDER" -> 
            main.render
        
        _ -> 
            crash "unsupported input from host"

Init : {
    displayMode : Str, # "borderless" | "windowed" | "fullscreen"
    border: Bool,
    title: Str,
    width: U32,
    height: U32,
}