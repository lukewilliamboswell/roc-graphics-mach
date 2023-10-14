interface TinyVG
    exposes [
        Graphic,
        graphic,
        toStr,
        colors,
        addColor,
    ]
    imports [
        Color.{Color, ColorEncoding},
    ]

# Each Unit takes up 8/16/32 bits
Precision : [Default, Reduced, Enhanced]

Graphic := {
    width : U16,
    height : U16,
    scale : U8,
    format : ColorEncoding,
    precision : Precision,
    colorTable : List Color,
}

graphic : {
    width ? U16,
    height ? U16,
    scale ? U8,
    format ? ColorEncoding,
    precision ? Precision,
} -> Graphic
graphic = \{width ? 100, height ? 100, scale ? 1, format ? RGBA8888, precision ? Default} ->
    @Graphic {width, height, scale, format, precision, colorTable: []}

addColor : Graphic, Color -> Graphic
addColor = \@Graphic data, color ->
    @Graphic {data & colorTable: List.append data.colorTable color}

colors : Graphic -> List Color
colors = \@Graphic {colorTable} -> colorTable

toStr : Graphic, Str -> Str
toStr = \g, others ->
    headerStr = headerToStr g
    colorTableStr = colorTableToStr g

    "(tvg 1 \(headerStr)\(colorTableStr)\(others))"

headerToStr : Graphic -> Str
headerToStr = \@Graphic {width, height, scale, format, precision} ->

    # TODO support other scales
    scaleToStr =
        when scale is 
            _ -> "1/1" 
    
    # TODO support other formats
    formatToStr =
        when format is 
            _ -> "u8888" 

    # TODO support other precisions
    precisionToStr =
        when precision is 
            _ -> "default" 

    [
        "(",
        Num.toStr width,
        " ",
        Num.toStr height,
        " ",
        scaleToStr,
        " ",
        formatToStr,
        " ",
        precisionToStr,
        ")",
    ]
    |> Str.joinWith ""

# Test header is correct for default values 
expect headerToStr (graphic {}) == "(100 100 1/1 u8888 default)"

colorTableToStr : Graphic -> Str
colorTableToStr = \@Graphic data ->
    
    tvgtColors = 
        data.colorTable 
        |> List.map \c -> Color.toTvgt c data.format
        |> Str.joinWith ""

    "(\(tvgtColors))"

expect 
    graphic {} 
    |> addColor (Color.fromBasic White)
    |> addColor (Color.fromBasic Purple)
    |> colorTableToStr
    == "((1.0 1.0 1.0 1.0)(0.49 0.0 1.0 1.0))"
