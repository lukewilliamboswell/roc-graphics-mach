app "rocLovesZig"
    packages { pf: "../platform/main.roc" }
    imports []
    provides [main] to pf

main : Str -> Str
main = \_ ->
    
    # Let's pick the color of our triangle! Yay!!
    red = Num.toStr (130/255)
    green = Num.toStr (87/255)
    blue = Num.toStr (229/255)

    """
    @vertex fn vertex_main(
        @builtin(vertex_index) VertexIndex : u32
    ) -> @builtin(position) vec4<f32> {
        var pos = array<vec2<f32>, 3>(
            vec2<f32>( 0.0,  0.5),
            vec2<f32>(-0.5, -0.5),
            vec2<f32>( 0.5, -0.5)
        );
        return vec4<f32>(pos[VertexIndex], 0.0, 1.0);
    }

    @fragment fn frag_main() -> @location(0) vec4<f32> {
        return vec4<f32>(\(red), \(green), \(blue), 1.0);
    }
    """
