platform "roc-graphics"
    requires {} { main : Program a }
    exposes []
    packages {}
    imports [
        Json.{ json },
        Types.{ Program, HostInterface, Key, Init, Event, Command, ToHostInit },
        Encode.{Encoding}, 
        Decode.{Decoding},
    ]
    provides [mainForHost]

runProgram : HostInterface, Program a -> List U8
runProgram = \fromHost, program ->
    when fromHost.action is
        "INIT" -> 
            (initOptions, initModel) = defaultInit |> program.init 

            toHost : ToHostInit
            toHost = {
                action: "INIT",
                command: initOptions,
                model: program.encodeModel initModel,
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
        "KEYPRESS:UP" -> Ok (KeyPress Up)
        "KEYPRESS:DOWN" -> Ok (KeyPress Down)
        "KEYPRESS:LEFT" -> Ok (KeyPress Left)
        "KEYPRESS:RIGHT" -> Ok (KeyPress Right)
        "TICK" -> Ok Tick
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
