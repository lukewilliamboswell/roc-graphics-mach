platform "roc-graphics"
    requires {} { main : Program a }
    exposes []
    packages {}
    imports [
        Json.{ json },
        Types.{ Program, HostInterface, Key, Init, Event, Command },
        Encode.{Encoding}, 
        Decode.{Decoding},
    ]
    provides [mainForHost]

runProgram : HostInterface, Program a -> List U8
runProgram = \fromHost, program ->
    when fromHost.action is
        "INIT" -> 
            (command, initialModel) = defaultInit |> program.init 

            toHost : HostInterface
            toHost = {
                action: "INIT",
                command: Encode.toBytes command json,
                model: program.encodeModel initialModel,
            }

            Encode.toBytes toHost json

        "UPDATE" -> 

            event = when toEventFromHost fromHost.command is 
                Err InvalidUtf8 -> crash "INVALID UTF8 EVENT FROM HOST"
                Err UnsupportedCommmand -> crash "UNSUPPORTED COMMAND FROM HOST"
                Ok e -> e

            model = program.decodeModel fromHost.model

            (command, updatedModel) = program.update event model
            
            toHost : HostInterface
            toHost = {
                action: "UPDATE",
                command: toBytesFromCommand command,
                model: program.encodeModel updatedModel,
            }

            Encode.toBytes toHost json

        "REDRAW" -> 

            model = program.decodeModel fromHost.model

            tvgtBytes = program.render model
        
            toHost : HostInterface
            toHost = {
                action: "REDRAW",
                command: [],
                model: tvgtBytes,
            }

            Encode.toBytes toHost json
            
        _ -> crash "UNRECOGNISED ACTION FROM HOST"

mainForHost : List U8 -> List U8
mainForHost = \fromHostBytes ->

    decoded : Result HostInterface [Leftover (List U8), TooShort]
    decoded = Decode.fromBytes fromHostBytes json

    when decoded is
        Err _ -> crash "ERROR DECODING FROM HOST"
        Ok fromHost -> runProgram fromHost main

toEventFromHost : List U8 -> Result Event [InvalidUtf8, UnsupportedCommmand]
toEventFromHost = \cmdBytes ->
    cmdBytes
    |> Str.fromUtf8
    |> Result.mapErr \_ -> InvalidUtf8
    |> Result.try \cmd -> 
        when cmd is
            "KEYPRESS:ESCAPE" -> Ok (KeyPress Escape)
            "KEYPRESS:SPACE" -> Ok (KeyPress Space)
            "KEYPRESS:ENTER" -> Ok (KeyPress Enter)
            _ -> Err UnsupportedCommmand

toBytesFromCommand : Command -> List U8
toBytesFromCommand = \cmd -> 
    when cmd is
        Redraw -> "REDRAW" |> Str.toUtf8
        Exit -> "EXIT" |> Str.toUtf8
        NoOp -> "NOOP" |> Str.toUtf8

defaultInit : Init
defaultInit = {
    displayMode: "windowed",
    border: Bool.true,
    title: "Roc 💜 Graphics",
    width: 200,
    height: 200,
}
