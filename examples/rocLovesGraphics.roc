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
    width: 100,
    height: 100,
}

render : Str
render = 
    """
    (tvg 1
    (100 100 1/1 u8888 default)
    (
        (0.486 0.220 0.961 1.000)
    )
    (
        (
        fill_path
        (flat 0)
        (
            (24.75 23.5)
            (
            (line - 48.633 26.711)
            (line - 61.994 42.51)
            (line - 70.716 40.132)
            (line - 75.25 45.5)
            (line - 69.75 45.5)
            (line - 68.782 49.869)
            (line - 51.217 62.842)
            (line - 52.203 68.713)
            (line - 42.405 76.5)
            (line - 48.425 46.209)
            (close -)
            )
        )
        )
    )
    )

    """


    
    
