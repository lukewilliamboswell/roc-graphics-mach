app "rocLovesZig"
    packages { 
        pf: "../platform/main.roc",
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/v0.3.0/y2bZ-J_3aq28q0NpZPjw0NC6wghUYFooJpH03XzJ3Ls.tar.br",
    }
    imports [
        json.Core.{json},
        Encode,
    ]
    provides [main] to pf

main = \_ -> 
    Encode.toBytes init json |> Str.fromUtf8 |> Result.withDefault "UTF8 ERROR"

Init : {
    displayMode : Str, # "borderless" | "windowed" | "fullscreen"
    border: Bool,
    title: Str,
    width: U32,
    height: U32,
}

init : Init
init = {
    displayMode: "windowed",
    border: Bool.true,
    title: "Roc Loves Graphics",
    width: 800,
    height: 600,
}

# render : Str
# render = "RENDER"


    
    
