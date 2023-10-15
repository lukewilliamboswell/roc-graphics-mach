app "rocLovesGraphics"
    packages {
        pf: "../platform/main.roc",
        tvg: "https://github.com/lukewilliamboswell/roc-tinvyvg/releases/download/testing/-P6_oNEDWFP8Cz4yyutR4oERy-qE8x4i4Xe2TdMD1a0.tar.br",
    }
    imports [
        pf.Types.{ Program, Init, Key, Event, Command },
        tvg.Color.{ Color, Basic },
        tvg.Graphic.{Graphic},
        tvg.Color,
        tvg.Style,
        tvg.Command,
        tvg.PathNode,
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
    ({ default & title: "Roc 💜 Graphics", width: 200, height: 200 }, White)

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
    graphic : Graphic
    graphic = 
        g1, white <- Graphic.addColor (Graphic.graphic {}) (Color.fromBasic model)
        g2, purple <- Graphic.addColor g1 (Color.rocPurple)

        # Draws the white square background
        whiteSquare = Command.fillPath (Style.flat white) {x : 0, y : 0 } [
            PathNode.line { x: 100, y: 0 },
            PathNode.line { x: 100, y: 100 },
            PathNode.line { x: 0, y: 100 },
            PathNode.close {},
        ]

        # Draws the roc-lang bird logo
        rocBird = Command.fillPath (Style.flat purple) {x : 24.75, y : 23.5 } [
            PathNode.line { x: 48.633, y: 26.711 },
            PathNode.line { x: 61.994, y: 42.51 },
            PathNode.line { x: 70.716, y: 40.132 },
            PathNode.line { x: 75.25, y: 45.5 },
            PathNode.line { x: 69.75, y: 45.5 },
            PathNode.line { x: 68.782, y: 49.869 },
            PathNode.line { x: 51.217, y: 62.842 },
            PathNode.line { x: 52.203, y: 68.713 },
            PathNode.line { x: 42.405, y: 76.5 },
            PathNode.line { x: 48.425, y: 46.209 },
            PathNode.close {},
        ]
        
        g2
        |> Graphic.addCommand whiteSquare
        |> Graphic.addCommand rocBird
    
    graphic |> Graphic.toStr
