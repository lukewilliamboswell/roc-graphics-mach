app "rocLovesGraphics"
    packages {
        pf: "../platform/main.roc",
        # json: "https://github.com/lukewilliamboswell/roc-json/releases/download/v0.3.0/y2bZ-J_3aq28q0NpZPjw0NC6wghUYFooJpH03XzJ3Ls.tar.br",
    }
    imports [
        pf.Types.{ Program, Init, Key, Event, Command },
        # json.Core.{ json },
        # Encode.{Encoding}, 
        # Decode.{Decoding},
    ]
    provides [main] to pf

main : Program Model
main = 
    { 
        init, 
        update, 
        render, 
        encodeModel,
        decodeModel,  
    }

init : Init -> (Init, Model)
init = \default -> 
    ({ default & title: "Roc 💜 Graphics", width: 200, height: 200 }, Purple)

Model : [Purple, Green, Blue]

encodeModel : Model -> Str
encodeModel = \model -> 
    when model is 
        Purple -> "Purple"
        Green -> "Green"
        Blue -> "Blue"

decodeModel : Str -> Model
decodeModel = \encoded -> 
    when encoded is 
        "Purple" -> Purple
        "Green" -> Green
        "Blue" -> Blue
        _ -> crash "UNABLE TO DECODE MODEL, GOT:\(encoded)"

nextModel : Model -> Model
nextModel = \current ->
    when current is
        Purple -> Green
        Green -> Blue
        Blue -> Purple
    
update : Event, Model -> (Command, Model)
update = \event, model ->
    when event is
        KeyPress Escape -> (Exit, nextModel model)
        KeyPress Space -> (Redraw, nextModel model)
        KeyPress Enter -> (NoOp, nextModel model)

render : Model -> Str
render = \_ ->
    """
    (tvg 1
    (100 100 1/1 u8888 default)
    (
        (1.000 1.000 1.000 1.000)
        (0.486 0.220 0.961 1.000)
    )
    (
        (
        fill_path
        (flat 0)
        (
            (0 0)
            (
            (line - 100 0)
            (line - 100 100)
            (line - 0 100)
            (close -)
            )
        )
        )
        (
        fill_path
        (flat 1)
        (
            (24.75 23.5)
            (
            (line - 48.633 26.711)
            (line - 61.994 42.51)
            (line - 70.716 40.132)
            (line - 75.25 45.5)
            (line - 69.75 45.5)
            (line - 68.782 49.869)
            (line - 51.217 62.842)
            (line - 52.203 68.713)
            (line - 42.405 76.5)
            (line - 48.425 46.209)
            (close -)
            )
        )
        )
    )
    )
    """

