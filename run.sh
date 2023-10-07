#!/bin/bash

# Ensure that the user has provided a path to the Roc app
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 rovLovesGraphics.roc"
    exit 1
fi

# Save the path to the Roc app
roc_app_path="$1"
roc_app_suffix="${roc_app_path##*.}"

# Check the roc file exists
if [[ -f "$roc_app_path" && "$roc_app_suffix" == "roc" ]]; then 
    echo "Building Roc app: $roc_app_path"
else
    echo "Expected a .roc file to be provided; $roc_app_path not found or is not a .roc file!"
    exit 1
fi

# Determine the suffix based on the operating system
case "$OSTYPE" in
  linux*)   dylib_suffix=".o" ;;
  darwin*)  dylib_suffix=".dylib" ;; 
  msys*)    dylib_suffix=".obj" ;; 
  *)        dylib_suffix=".o" ;;
esac

# Build the Roc app into a library
roc build --lib $roc_app_path

# Extract the suffix from the file path and remove the .roc suffix from the 
# file path and add dylib suffix for the current OS 
#
# TODO this is only needed until Roc cli enables you to specify output name 
# from command line and it doesn't use the app module header value.
dylib_path="${roc_app_path%.*}${dylib_suffix}"

# Build the Zig app and link in the Roc dynamic library
zig build run -- $dylib_path

# Clean up the dynamic library file
rm -f $dylib_path