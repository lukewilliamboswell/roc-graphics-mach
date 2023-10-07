const std = @import("std");
const builtin = @import("builtin");
const str = @import("builtins/bitcode/src/glue.zig").str;
const core = @import("mach-core");
const RocStr = str.RocStr;
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expect = testing.expect;
const DEBUG: bool = false;
const Align = 2 * @alignOf(usize);

extern fn malloc(size: usize) callconv(.C) ?*align(Align) anyopaque;
extern fn realloc(c_ptr: [*]align(Align) u8, size: usize) callconv(.C) ?*anyopaque;
extern fn free(c_ptr: [*]align(Align) u8) callconv(.C) void;
extern fn memcpy(dst: [*]u8, src: [*]u8, size: usize) callconv(.C) void;
extern fn memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void;

// Forward "app" declarations into our namespace, such that @import("root").foo works as expected.
pub usingnamespace @import("app");
const App = @import("app").App;

pub const GPUInterface = if (@hasDecl(App, "GPUInterface")) App.GPUInterface else core.gpu.dawn.Interface;

export fn roc_alloc(size: usize, alignment: u32) callconv(.C) ?*anyopaque {
    if (DEBUG) {
        var ptr = malloc(size);
        const stdout = std.io.getStdOut().writer();
        stdout.print("alloc:   {d} (alignment {d}, size {d})\n", .{ ptr, alignment, size }) catch unreachable;
        return ptr;
    } else {
        return malloc(size);
    }
}

export fn roc_realloc(c_ptr: *anyopaque, new_size: usize, old_size: usize, alignment: u32) callconv(.C) ?*anyopaque {
    if (DEBUG) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("realloc: {d} (alignment {d}, old_size {d})\n", .{ c_ptr, alignment, old_size }) catch unreachable;
    }

    return realloc(@as([*]align(Align) u8, @alignCast(@ptrCast(c_ptr))), new_size);
}

export fn roc_dealloc(c_ptr: *anyopaque, alignment: u32) callconv(.C) void {
    if (DEBUG) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("dealloc: {d} (alignment {d})\n", .{ c_ptr, alignment }) catch unreachable;
    }

    free(@as([*]align(Align) u8, @alignCast(@ptrCast(c_ptr))));
}

export fn roc_panic(c_ptr: *anyopaque, tag_id: u32) callconv(.C) void {
    _ = tag_id;

    const stderr = std.io.getStdErr().writer();
    const msg = @as([*:0]const u8, @ptrCast(c_ptr));
    stderr.print("Roc application crashed with message\n\n    {s}\n\nShutting down\n", .{msg}) catch unreachable;
    std.process.exit(0);
}

export fn roc_memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void {
    return memset(dst, value, size);
}

extern fn kill(pid: c_int, sig: c_int) c_int;
extern fn shm_open(name: *const i8, oflag: c_int, mode: c_uint) c_int;
extern fn mmap(addr: ?*anyopaque, length: c_uint, prot: c_int, flags: c_int, fd: c_int, offset: c_uint) *anyopaque;
extern fn getppid() c_int;

fn roc_getppid() callconv(.C) c_int {
    return getppid();
}

fn roc_getppid_windows_stub() callconv(.C) c_int {
    return 0;
}

fn roc_shm_open(name: *const i8, oflag: c_int, mode: c_uint) callconv(.C) c_int {
    return shm_open(name, oflag, mode);
}
fn roc_mmap(addr: ?*anyopaque, length: c_uint, prot: c_int, flags: c_int, fd: c_int, offset: c_uint) callconv(.C) *anyopaque {
    return mmap(addr, length, prot, flags, fd, offset);
}

comptime {
    if (builtin.os.tag == .macos or builtin.os.tag == .linux) {
        @export(roc_getppid, .{ .name = "roc_getppid", .linkage = .Strong });
        @export(roc_mmap, .{ .name = "roc_mmap", .linkage = .Strong });
        @export(roc_shm_open, .{ .name = "roc_shm_open", .linkage = .Strong });
    }

    if (builtin.os.tag == .windows) {
        @export(roc_getppid_windows_stub, .{ .name = "roc_getppid", .linkage = .Strong });
    }
}

const mem = std.mem;
const Allocator = mem.Allocator;

extern fn roc__mainForHost_1_exposed_generic(*RocStr, *RocStr) void;

const Unit = extern struct {};

const AppInitOptions = struct {
    displayMode: []const u8, // 20 windowed, 21 fullscreen, 22 borderless
    border: bool = true,
    title: []const u8,
    width: u32 = 800,
    height: u32 = 600,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    core.allocator = gpa.allocator();

    // const stdout = std.io.getStdOut().writer();
    // _ = stdout;
    // const stderr = std.io.getStdErr().writer();
    // _ = stderr;

    // var timer = std.time.Timer.start() catch unreachable;

    // const nanos = timer.read();
    // const seconds = (@as(f64, @floatFromInt(nanos)) / 1_000_000_000.0);
    // _ = seconds;

    // DEBUG print the result
    // try stdout.print("{s}", .{callresult.asSlice()});

    // DEBUG print the time
    // try stderr.print("runtime: {d:.3}ms\n", .{seconds * 1000});

    // Run from the directory where the executable is located so relative assets can be found.
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    std.os.chdir(path) catch {};

    // Initialize GPU implementation
    core.gpu.Impl.init();

    // Use the result from Roc as the shader code
    // const shader: [*:0]const u8 = try addNullTermination(callresult.asSlice());

    const options = try roc_init(core.allocator);

    var app: App = undefined;
    try app.init(options);
    defer app.deinit();
    while (!try core.update(&app)) {}
}

fn addNullTermination(slice: []const u8) ![:0]const u8 {
    var allocator = std.heap.page_allocator;
    var size = slice.len + 1;
    var result = try allocator.alloc(u8, size);
    @memcpy(result.ptr, slice);
    result[slice.len] = 0; // Add null termination
    return result[0..slice.len :0];
}

fn roc_init(allocator: std.mem.Allocator) !core.Options {
    var argument = RocStr.fromSlice("INIT");
    var callresult = RocStr.empty();
    defer callresult.decref();
    defer argument.decref();

    roc__mainForHost_1_exposed_generic(&callresult, &argument);

    // DEBUG PRINT ROC CALL RESULT
    // try stdout.print("ROC GIVES-----\n{s}\n--------\n", .{callresult.asSlice()});

    const parsedData = try std.json.parseFromSlice(AppInitOptions, allocator, callresult.asSlice(), .{});
    defer parsedData.deinit();

    // DEBUG PRINT PARSED DATA
    // try stdout.print("JSON PARSED------\n{any}\n--------\n", .{parsedData.value});

    // Display mode
    var display_mode: core.DisplayMode =
        if (mem.eql(u8, parsedData.value.displayMode, "borderless"))
        core.DisplayMode.borderless
    else if (mem.eql(u8, parsedData.value.displayMode, "fullscreen"))
        core.DisplayMode.fullscreen
    else
        core.DisplayMode.windowed;

    const options = core.Options{
        .display_mode = display_mode,
        .border = parsedData.value.border,
        .title = try addNullTermination(parsedData.value.title),
        .size = core.Size{ .width = parsedData.value.width, .height = parsedData.value.height },
    };

    return options;
}
