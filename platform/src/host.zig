const std = @import("std");
const core = @import("mach-core");

const Unit = extern struct {};

// Forward "app" declarations into our namespace, such that @import("root").foo works as expected.
pub usingnamespace @import("app");
const App = @import("app").App;

pub const GPUInterface = if (@hasDecl(App, "GPUInterface")) App.GPUInterface else core.gpu.dawn.Interface;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    core.allocator = gpa.allocator();

    // Run from the directory where the executable is located so relative assets can be found.
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    std.os.chdir(path) catch {};

    // Initialize GPU implementation
    core.gpu.Impl.init();

    var app: App = undefined;
    try app.init();
    defer app.deinit();
    while (!try core.update(&app)) {}
}
