
# Roc 💜 Zig + Mach 🟰 Graphics 🎉

An experiment to build a minimal graphics platform for Roc using [hexops/mach-core](https://github.com/hexops/mach-core).

## Setup 

1. Roc cli built using the `zig-11-llvm-16` branch 
2. Zig version `0.12.0-dev.294+4d1432299`

> **WARNING** Upgrading Zig versions requires careful coordination with mach-core dependencies and can be really difficult for now. Mach is still under heavy development and is stabilising. I am still learning the Zig build system, and unfortunaetly I wasn't able to get zig v0.11 to work with Mach and Roc.

## Build Platform

Run an example using `bash run.sh examples/rocLovesGraphics.roc`. 

This builds the Roc app into a dynamic library, and then build the Zig app.

> **NOTE** normally a platform is pre-built into an object and then Roc will link the app into that; however in this case we are doing things in reverse to simplify the build process.

## Run without rebuilding the platform

Once you have the (platform) executable built, you can skip rebuilding it every time you make a change. 

You can rebuild your roc app into another dylib using e.g. `roc build --lib examples/rocLovesGraphics.roc`, and restart the executable `./zig-out/bin/myapp` to see your changes.

