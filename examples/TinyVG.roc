interface TinyVG
    exposes []
    imports []


# Each Unit takes up 8/16/32 bits
Precision : [Default, Reduced, Enhanced]

ColorEncoding : [RGBA8888, RGB565, RGBAF32]

Color : [RGBA8888 U8 U8 U8 U8]

Graphic := {
    width : U16,
    height : U16,
    scale : U8,
    format : ColorEncoding,
    precision : Precision,
    colorTable : List Color,
}

new : {
    width ? U16,
    height ? U16,
    scale ? U8,
    format ? ColorEncoding,
    precision ? Precision,
} -> Graphic
new = \{width ? 100, height ? 100, scale ? 1, format ? RGBA8888, precision ? Default} ->
    @Graphic {width, height, scale, format, precision}

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
expect headerToStr (new {}) == "(100 100 1/1 u8888 default)"

# toStr : Graphic -> Str
# toStr = \@Graphic {state} ->

#     "100 100 1/1 u8888 default"

colorTableToStr : Graphic -> Str
colorTableToStr \ @Graphic {colorTable} ->
    colorTable
    |> List.map Color.toStr
    |> Str.joinWith " "