
# Build the Roc app into a library
roc build --lib examples/rocLovesZig.roc

# Copy to the root directory
cp examples/rocLovesZig.dylib rocLovesZig.dylib

# Build the Zig app
zig build run

# Clean up the library files
rm -f examples/rocLovesZig.dylib rocLovesZig.dylib