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

            init = 
                when command |> Encode.toBytes json |> Str.fromUtf8 is 
                    Ok a -> a
                    Err _ -> crash "UNREACHABLE; INVALID UTF8 ENCODING INIT"
                
            toHost : HostInterface
            toHost = {
                action: "INIT",
                command: init,
                model: program.encodeModel initialModel,
            }

            Encode.toBytes toHost json

        "UPDATE" -> 

            event = when toEventFromStr fromHost.command is 
                Err UnsupportedCommmand -> crash "UNSUPPORTED COMMAND FROM HOST"
                Ok e -> e

            model = program.decodeModel fromHost.model

            (command, updatedModel) = program.update event model
            
            toHost : HostInterface
            toHost = {
                action: "UPDATE",
                command: toStrFromCommand command,
                model: program.encodeModel updatedModel,
            }

            Encode.toBytes toHost json

        "REDRAW" -> 

            model = program.decodeModel fromHost.model

            tvgtBytes = program.render model
        
            toHost : HostInterface
            toHost = {
                action: "REDRAW",
                command: "",
                model: tvgtBytes,
            }

            Encode.toBytes toHost json
            
        _ -> crash "UNRECOGNISED ACTION FROM HOST"

mainForHost : List U8 -> List U8
mainForHost = \fromHostBytes ->
    # DEBUG FROM HOST CALL
    # crash (Str.fromUtf8 fromHostBytes |> Result.withDefault "BAD UTF8 FROM HOST")

    decoded : Result HostInterface [Leftover (List U8), TooShort]
    decoded = Decode.fromBytes fromHostBytes json

    when decoded is
        Err _ -> crash "ERROR DECODING FROM HOST"
        Ok fromHost -> runProgram fromHost main

toEventFromStr : Str -> Result Event [UnsupportedCommmand]
toEventFromStr = \cmd ->
    when cmd is
        "KEYPRESS:ESCAPE" -> Ok (KeyPress Escape)
        "KEYPRESS:SPACE" -> Ok (KeyPress Space)
        "KEYPRESS:ENTER" -> Ok (KeyPress Enter)
        _ -> Err UnsupportedCommmand

toStrFromCommand : Command -> Str
toStrFromCommand = \cmd -> 
    when cmd is
        Redraw -> "REDRAW"
        Exit -> "EXIT"
        NoOp -> "NOOP"

defaultInit : Init
defaultInit = {
    displayMode: "windowed",
    border: Bool.true,
    title: "Roc 💜 Graphics",
    width: 200,
    height: 200,
}
