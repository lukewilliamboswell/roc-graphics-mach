app "rocLovesZig"
    packages { 
        pf: "../platform/main.roc",
    }
    imports []
    provides [main] to pf

main = {init, render: "RENDER"}

init = {
    displayMode: "windowed",
    border: Bool.true,
    title: "Roc Loves Graphics",
    width: 800,
    height: 600,
}

# render : Str
# render = "RENDER"


    
    
