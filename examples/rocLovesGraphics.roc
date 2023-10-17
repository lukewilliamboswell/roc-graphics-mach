app "rocLovesGraphics"
    packages {
        pf: "../platform/main.roc",
        tvg: "https://github.com/lukewilliamboswell/roc-tinvyvg/releases/download/0.2/ZyZBFnr3PEd5fWq70Z6w2ASK7bSxarh8Wj2Xq7o7IUE.tar.br",
    }
    imports [
        pf.Types.{ Program, Init, Key, Event, Command },
        tvg.Color.{ Color, Basic },
        tvg.Graphic.{ Graphic },
        tvg.Color,
        tvg.Style,
        tvg.Command,
        tvg.PathNode,
    ]
    provides [main] to pf

main : Program Model
main = { init, update, render, encodeModel, decodeModel }

# MODEL

Model : {
    x : Dec,
    y : Dec,
    background : Basic,
    bird : Basic,
}

encodeModel : Model -> Str
encodeModel = \{ x, y, background, bird } ->
    "\(Num.toStr x)|\(Num.toStr y)|\(Color.basicToStr background)|\(Color.basicToStr bird)"

decodeModel : Str -> Model
decodeModel = \str ->
    parts = Str.split str "|"
    when parts is
        [xStr, yStr, bgStr, birdStr] ->
            x = xStr |> Str.toDec |> Result.withDefault 0
            y = yStr |> Str.toDec |> Result.withDefault 0
            background = Color.basicFromStr bgStr |> Result.withDefault Purple
            bird = Color.basicFromStr birdStr |> Result.withDefault Purple

            { x, y, background, bird }

        _ -> crash "UNABLE TO DECODE MODEL"

# Let's cycle through all the basic colors 🎉
nextColor : Basic -> Basic
nextColor = \basic ->
    when basic is
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

move : Model, [Up, Down, Left, Right] -> Model
move = \model, direction ->
    when direction is
        Up -> { model & y: model.y - 10 }
        Down -> { model & y: model.y + 10 }
        Left -> { model & x: model.x - 10 }
        Right -> { model & x: model.x + 10 }

changeColor : Model, [Bird, Background] -> Model
changeColor = \model, color ->
    when color is
        Bird -> { model & bird: nextColor model.bird }
        Background -> { model & background: nextColor model.background }

# INIT

init : Init -> (Init, Model)
init = \default ->
    (
        { default & title: "Roc 💜 Graphics", width: 200, height: 200 },
        { x: 0, y: 0, background: White, bird: Purple },
    )

# UPDATE

update : Event, Model -> (Command, Model)
update = \event, model ->
    when event is
        KeyPress Escape -> (Exit, model)
        KeyPress Space -> (Redraw, model |> changeColor Bird)
        KeyPress Up -> (Redraw, model |> move Up)
        KeyPress Down -> (Redraw, model |> move Down)
        KeyPress Left -> (Redraw, model |> move Left)
        KeyPress Right -> (Redraw, model |> move Right)
        Tick -> (Redraw, model |> changeColor Background)
        _ -> (NoOp, model)

# RENDER

render : Model -> Str
render = \model ->
    graphic : Graphic
    graphic =
        g1, bgColor <- Graphic.applyColor (Graphic.graphic {}) (Color.fromBasic model.background)
        g2, birdColor <- Graphic.applyColor g1 (Color.fromBasic model.bird)

        # Draws the white square background
        whiteSquare = Command.fillPath (Style.flat bgColor) { x: 0, y: 0 } [
            PathNode.line { x: 100, y: 0 },
            PathNode.line { x: 100, y: 100 },
            PathNode.line { x: 0, y: 100 },
            PathNode.close {},
        ]

        # Draws the roc-lang bird logo
        rocBird = Command.fillPath (Style.flat birdColor) { x: 24.75 + model.x, y: 23.5 + model.y } [
            PathNode.line { x: 48.633 + model.x, y: 26.711 + model.y },
            PathNode.line { x: 61.994 + model.x, y: 42.51 + model.y },
            PathNode.line { x: 70.716 + model.x, y: 40.132 + model.y },
            PathNode.line { x: 75.25 + model.x, y: 45.5 + model.y },
            PathNode.line { x: 69.75 + model.x, y: 45.5 + model.y },
            PathNode.line { x: 68.782 + model.x, y: 49.869 + model.y },
            PathNode.line { x: 51.217 + model.x, y: 62.842 + model.y },
            PathNode.line { x: 52.203 + model.x, y: 68.713 + model.y },
            PathNode.line { x: 42.405 + model.x, y: 76.5 + model.y },
            PathNode.line { x: 48.425 + model.x, y: 46.209 + model.y },
            PathNode.close {},
        ]

        g2
        |> Graphic.addCommand whiteSquare
        |> Graphic.addCommand rocBird

    graphic |> Graphic.toText
