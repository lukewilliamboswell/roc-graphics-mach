interface TinyVG.Style
    exposes [
        Style,
        flat,
        linear, 
        radial,
        toTvgt,
    ]
    imports [
        TinyVG.ColorIndex.{ColorIndex}
    ]

Style := 
    [
        Flat ColorIndex,
        Linear (U32,U32) (U32,U32) ColorIndex ColorIndex,
        Radial (U32,U32) (U32,U32) ColorIndex ColorIndex,
    ]

# flat <color>
flat : ColorIndex -> Style 
flat = \idx -> @Style (Flat idx)

# linear (<x1> <y1>) (<x2> <y2>) <color_1> <color_2> 
linear : (U32,U32), (U32,U32), ColorIndex, ColorIndex -> Style
linear = \p1, p2, id1, id2 ->
    @Style (Linear p1 p2 id1 id2)

# radial (<x1> <y1>) (<x2> <y2>) <color_1> <color_2> 
radial : (U32,U32), (U32,U32), ColorIndex, ColorIndex -> Style
radial = \p1, p2, id1, id2 ->
    @Style (Radial p1 p2 id1 id2)

toTvgt : Style -> Str
toTvgt = \@Style style ->
    when style is 
        Flat idx -> "(flat \(ColorIndex.toStr idx))"
        Linear p1 p2 id1 id2 -> "(linear \(xyToStr p1) \(xyToStr p2) \(ColorIndex.toStr id1) \(ColorIndex.toStr id2))"
        Radial p1 p2 id1 id2 -> "(radial \(xyToStr p1) \(xyToStr p2) \(ColorIndex.toStr id1) \(ColorIndex.toStr id2))"

testId1 = ColorIndex.fromU32 1
testId2 = ColorIndex.fromU32 32

expect flat testId1 |> toTvgt == "(flat 1)"
expect linear (0,12) (234,567) testId1 testId2 |> toTvgt == "(linear (0 12) (234 567) 1 32)"
expect radial (0,12) (234,567) testId1 testId2 |> toTvgt == "(radial (0 12) (234 567) 1 32)"

xyToStr : (U32,U32) -> Str
xyToStr = \(x,y) -> "(\(Num.toStr x) \(Num.toStr y))"

expect xyToStr (123456, 0) == "(123456 0)"
