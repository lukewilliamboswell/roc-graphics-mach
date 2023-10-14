interface TinyVG.ColorIndex
    exposes [
        ColorIndex,
        fromU32,
        toU32,
        toStr
    ]
    imports []

ColorIndex := U32

fromU32 = @ColorIndex

toU32 = \@ColorIndex u32 -> u32

toStr = \@ColorIndex u32 -> Num.toStr u32