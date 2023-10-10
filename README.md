
# Roc 💜 Mach 🟰 Graphics

An experiment to combine mach graphics and Roc lang

## Setup 

Requires roc to be built from source using the `zig-11-llvm-16` branch, and so the symlink below points to the correct version of builtins for zig.

Link to the roc builtins `ln -s /REPLACE-WITH-PATH-TO-ROC/crates/compiler/builtins ./platform/src/builtins`. This should not be needed in future when Zig glue generation is supported by Roc cli. 

> Note none of this setup will be required when that branch lands, and Zig glue generates the roc_std library types.

## Run an example

Build and run using `bash run.sh path/to/roc/file.roc`. 

For example use `bash run.sh examples/rocLovesGraphics.roc`.
