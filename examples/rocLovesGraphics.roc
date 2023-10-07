app "rocLovesGraphics"
    packages { 
        pf: "../platform/main.roc",
    }
    imports []
    provides [main] to pf

main = {init, render}

init = {
    displayMode: "windowed",
    border: Bool.true,
    title: "Roc 💜 Graphics",
    width: 800,
    height: 600,
}

render : Str
render = 
    """
    (tvg 1
    (24 24 1/4 u8888 reduced)
    (
        (0.161 0.178 1.000)
        (1.000 0.645 0.910)
    )
    (
        (
        fill_path
        (flat 0)
        (
            (12 1)
            (
            (line - 3 5)
            (vert - 11)
            (bezier - (3 16.5) (6.75 21.75) (12 23))
            (bezier - (17.25 21.75) (21 16.5) (21 11))
            (vert - 5)
            )
            (17.25 17)
            (
            (bezier - (16 18.75) (14 20.25) (12 21))
            (bezier - (10 20.25) (8 18.75) (6.75 17))
            (bezier - (6.5 16.5) (6.25 16) (6 15.5))
            (bezier - (6 13.75) (8.75 12.5) (12 12.5))
            (bezier - (15.25 12.5) (18 13.75) (18 15.5))
            (bezier - (17.75 16) (17.5 16.5) (17.25 17))
            )
            (12 5)
            (
            (bezier - (13.5 5) (15 6.25) (15 8))
            (bezier - (15 9.5) (13.75 11) (12 11))
            (bezier - (10.5 11) (9 9.75) (9 8))
            (bezier - (9 6.5) (10.25 5) (12 5))
            )
        )
        )
    )
    )
    """


    
    
