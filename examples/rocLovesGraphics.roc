app "rocLovesGraphics"
    packages {
        pf: "../platform/main.roc",
    }
    imports [
        pf.Types.{ Program, Init, Key, Event, Command },
        Color.{ Color, Basic },
        TinyVG,
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

# MODEL

Model : Basic

encodeModel : Model -> Str
encodeModel = \basic -> basic |> Color.basicToStr

decodeModel : Str -> Model
decodeModel = \str -> str |> Color.basicFromStr |> Result.withDefault Purple

# Let's cycle through all the basic colors 🎉
nextModel : Model -> Model
nextModel = \current ->
    when current is
        Red -> Gray
        Orange -> Red
        Yellow -> Orange
        Lime -> Yellow
        Green -> Lime
        Sea -> Green
        Cyan -> Sea
        Sky -> Cyan
        Blue -> Sky
        Purple -> Blue
        Magenta -> Purple
        Pink -> Magenta
        White -> Pink
        Black -> White
        Gray -> Black

# INIT

init : Init -> (Init, Model)
init = \default -> 
    ({ default & title: "Roc 💜 Graphics", width: 200, height: 200 }, Purple)

# UPDATE 

update : Event, Model -> (Command, Model)
update = \event, model ->
    when event is
        KeyPress Escape -> (Exit, nextModel model)
        KeyPress Space -> (Redraw, nextModel model)
        KeyPress Enter -> (NoOp, nextModel model)

# RENDER

render : Model -> Str
render = \model ->
    TinyVG.graphic {}
    |> TinyVG.addColor (Color.fromBasic White)
    |> TinyVG.addColor (Color.fromBasic model)
    |> TinyVG.toStr 
        """

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
        """

