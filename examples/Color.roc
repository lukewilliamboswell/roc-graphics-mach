interface Color
    exposes [
        Color,
        ColorEncoding,
        toTgvt,
        Basic,
        fromBasic,
        basicToStr,
        basicFromStr,
        rocPurple,
    ]
    imports []

Color := [RGBA8888 U8 U8 U8 U8] implements [Eq { isEq: isEq }]

isEq : Color, Color -> Bool
isEq = \@Color first, @Color second -> first == second

ColorEncoding : [RGBA8888]

toTgvt : Color, ColorEncoding -> Str
toTgvt = \@Color c, _ -> 
    # TODO use ColorEncoding
    when c is 
        RGBA8888 r g b a -> "(\(u8ToTvgt r) \(u8ToTvgt g) \(u8ToTvgt b) \(u8ToTvgt a))"

u8ToTvgt : U8 -> Str
u8ToTvgt = \u8 ->
    u8
    |> Num.toFrac
    |> Num.divChecked 255 
    |> Result.withDefault 0.0 
    |> Num.toStr
    # Truncate the Str to reduce the number of decimal places, and saves us bytes
    # to be transferred 
    # 
    # TODO remove when if/when we can send floats to zig
    |> truncateFrac 

truncateFrac : Str -> Str
truncateFrac = \frac ->
    fracBytes = frac |> Str.toUtf8

    # Walk the bytes and take at most 2 digits after the decimal
    List.walkUntil fracBytes (Integer 0) \state, elem ->
        when state is
            Integer count ->
                if elem == '.' then 
                    Continue (Decimal (count + 1))
                else 
                    Continue (Integer (count + 1))
            Decimal count -> 
                Continue (FirstDecimal (count + 1))
            FirstDecimal count ->
                Break (FirstDecimal (count + 1))
    |> \state -> 
        len = when state is
            Integer count -> count
            Decimal count -> count
            FirstDecimal count -> count
        
        List.sublist fracBytes { start: 0, len }
    |> Str.fromUtf8
    |> Result.withDefault frac # unreachable

expect truncateFrac "0.498039215686274509" == "0.49"

expect (@Color (RGBA8888 0 255 0 255)) |> toTgvt RGBA8888 == "(0.0 1.0 0.0 1.0)"

Basic : [
    Red,
    Orange,
    Yellow,
    Lime,
    Green,
    Sea,
    Cyan,
    Sky,
    Blue,
    Purple,
    Magenta,
    Pink,
    White,
    Black,
    Gray,
]

rocPurple : Color
rocPurple = @Color (RGBA8888 124 56 245 255) # #7c38f5

expect rocPurple == (@Color (RGBA8888 124 56 245 255))

fromBasic : Basic -> Color
fromBasic = \b ->
    when b is
        Red -> @Color (RGBA8888 255 0 0 255) # #FF0000
        Orange -> @Color (RGBA8888 255 128 0 255) # #FF8000
        Yellow -> @Color (RGBA8888 255 255 0 255) # #FFFF00
        Lime -> @Color (RGBA8888 128 255 0 255) # #80FF00
        Green -> @Color (RGBA8888 0 255 0 255) # #00FF00
        Sea -> @Color (RGBA8888 0 255 128 255) # #00FF80
        Cyan -> @Color (RGBA8888 0 255 255 255) # #00FFFF
        Sky -> @Color (RGBA8888 0 128 255 255) # #0080FF
        Blue -> @Color (RGBA8888 0 0 255 255) # #0000FF
        Purple -> @Color (RGBA8888 127 0 255 255) # #7F00FF
        Magenta -> @Color (RGBA8888 255 0 255 255) # #FF00FF
        Pink -> @Color (RGBA8888 255 0 127 255) # #FF007F
        White -> @Color (RGBA8888 255 255 255 255) # #FFFFFF
        Black -> @Color (RGBA8888 0 0 0 255) # #000000
        Gray -> @Color (RGBA8888 128 128 128 255) # #808080

basicToStr : Basic -> Str
basicToStr = \b ->
    when b is
        Red -> "Red"
        Orange -> "Orange"
        Yellow -> "Yellow"
        Lime -> "Lime"
        Green -> "Green"
        Sea -> "Sea"
        Cyan -> "Cyan"
        Sky -> "Sky"
        Blue -> "Blue"
        Purple -> "Purple"
        Magenta -> "Magenta"
        Pink -> "Pink"
        White -> "White"
        Black -> "Black"
        Gray -> "Gray"

basicFromStr : Str -> Result Basic [InvalidBasicColor]
basicFromStr = \s ->
    when s is
        "Red" -> Ok Red
        "Orange" -> Ok Orange
        "Yellow" -> Ok Yellow
        "Lime" -> Ok Lime
        "Green" -> Ok Green
        "Sea" -> Ok Sea
        "Cyan" -> Ok Cyan
        "Sky" -> Ok Sky
        "Blue" -> Ok Blue
        "Purple" -> Ok Purple
        "Magenta" -> Ok Magenta
        "Pink" -> Ok Pink
        "White" -> Ok White
        "Black" -> Ok Black
        "Gray" -> Ok Gray
        _ -> Err InvalidBasicColor