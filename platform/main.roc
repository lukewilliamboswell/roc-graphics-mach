platform "roc-graphics"
    requires {} { main : { init : Init -> Init, update : _, render : Str} }
    exposes [
        Event,
    ]
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
            defaultInit
            |> main.init  
            |> Encode.toBytes json 
            |> Str.fromUtf8 
            |> Result.withDefault "UTF8 ERROR"

        "RENDER" -> 
            main.render

        "UPDATE:KEYPRESS:ESCAPE" ->
            main.update (KeyPress Escape) |> updateOpToStr

        "UPDATE:KEYPRESS:SPACE" ->
            main.update (KeyPress Space) |> updateOpToStr

        "UPDATE:KEYPRESS:ENTER" ->
            main.update (KeyPress Enter) |> updateOpToStr
        
        _ -> 
            crash "unsupported input from host"

updateOpToStr : [NoOp, Exit, Redraw] -> Str
updateOpToStr = \op ->
    when op is
        NoOp -> "NOOP"
        Exit -> "EXIT"
        Redraw -> "REDRAW"

Init : {
    displayMode : Str, # "borderless" | "windowed" | "fullscreen"
    border: Bool,
    title: Str,
    width: U32,
    height: U32,
}

defaultInit : Init
defaultInit = 
    {
        displayMode: "windowed",
        border: Bool.true,
        title: "Roc 💜 Graphics",
        width: 200,
        height: 200,
    }
