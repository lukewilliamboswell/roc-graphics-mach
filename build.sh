cd platform/
zig build

cd ..
cp platform/zig-out/lib/libhost.a platform/macos-arm64.o

echo "done"
