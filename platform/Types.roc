interface Types
    exposes [
        Program,
        Key,
        HostInterface,
        Init,
        Event,
        Command,
    ]
    imports [
        Encode.{Encoding}, 
        Decode.{Decoding},
    ]

Program a : { 
    init : Init -> (Init, a), 
    update : Event, a -> (Command, a), 
    render : a -> List U8,
    encodeModel : a -> List U8,
    decodeModel : List U8 -> a,
} where a implements Encoding & Decoding

HostInterface : {
    action : Str,
    command : List U8, 
    model : List U8,
}

Event : [KeyPress Key]

Command : [NoOp, Exit, Redraw]

Init : {
    displayMode : Str, # "borderless" | "windowed" | "fullscreen"
    border: Bool,
    title: Str,
    width: U32,
    height: U32,
}

Key : [
    Escape,
    Space,
    Enter,
]