const std = @import("std");
const builtin = @import("builtin");
const list = @import("builtins/bitcode/src/glue.zig").list;
const str = @import("builtins/bitcode/src/glue.zig").str;
const core = @import("mach-core");
const tvg = @import("tinyvg");
const zigimg = @import("zigimg");
const RocList = list.RocList;
const RocStr = str.RocStr;
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expect = testing.expect;
const Align = 2 * @alignOf(usize);
const DEBUG: bool = false;

extern fn malloc(size: usize) callconv(.C) ?*align(Align) anyopaque;
extern fn realloc(c_ptr: [*]align(Align) u8, size: usize) callconv(.C) ?*anyopaque;
extern fn free(c_ptr: [*]align(Align) u8) callconv(.C) void;
extern fn memcpy(dst: [*]u8, src: [*]u8, size: usize) callconv(.C) void;
extern fn memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void;

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

export fn roc_panic(msg: *RocStr, tag_id: u32) callconv(.C) void {
    const stderr = std.io.getStdErr().writer();
    // const msg = @as([*:0]const u8, @ptrCast(c_ptr));
    stderr.print("\n\nRoc crashed with the following error;\nMSG:{s}\nTAG:{d}\n\nShutting down\n", .{ msg.asSlice(), tag_id }) catch unreachable;
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

extern fn roc__mainForHost_1_exposed_generic(*RocList, *RocList) void;

pub fn roc_init(allocator: std.mem.Allocator) !core.Options {
    // Create a host interface to send to Roc and convert it to a RocList
    const toRocInterface = try HostInterface.fromSlice("{\"action\":\"INIT\",\"model\":\"\",\"command\":\"\"}", allocator);
    const toRocList = try HostInterface.toList(toRocInterface, allocator);

    // Call into Roc
    const callresult = RocList.empty();
    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&toRocList));

    // Parse the callresult into a host interface
    const fromRocInterface = try HostInterface.fromList(@constCast(&callresult), allocator);

    // DEBUG STUFF
    std.debug.assert(mem.eql(u8, fromRocInterface.action, "INIT"));
    // std.debug.print("ROC GIVES-----\n{any}\n--------\n", .{fromRocInterface});

    // Parse the AppInitOptions from a JSON string
    const parsedData = try std.json.parseFromSlice(AppInitOptions, allocator, fromRocInterface.command, .{});
    defer parsedData.deinit();

    // DEBUG STUFF
    // std.debug.print("JSON PARSED------\n{any}\n--------\n", .{parsedData.value});

    // Set the display mode
    var display_mode: core.DisplayMode =
        if (mem.eql(u8, parsedData.value.displayMode, "borderless"))
        core.DisplayMode.borderless
    else if (mem.eql(u8, parsedData.value.displayMode, "fullscreen"))
        core.DisplayMode.fullscreen
    else
        core.DisplayMode.windowed;

    // Create options to configure mach-core library
    const options = core.Options{
        .display_mode = display_mode,
        .border = parsedData.value.border,
        .title = try addNullTermination(parsedData.value.title),
        .size = core.Size{ .width = parsedData.value.width, .height = parsedData.value.height },
    };

    return options;
}

pub fn roc_render(allocator: std.mem.Allocator) !tvg.rendering.Image {

    // Create a host interface to send to Roc and convert it to a RocList
    const toRocInterface = try HostInterface.fromSlice("{\"action\":\"REDRAW\",\"model\":\"\",\"command\":\"\"}", allocator);
    const toRocList = try HostInterface.toList(toRocInterface, allocator);

    // Call into Roc
    const callresult = RocList.empty();
    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&toRocList));

    // Parse the callresult into a host interface
    const fromRocInterface = try HostInterface.fromList(@constCast(&callresult), allocator);

    // DEBUG STUFF
    std.debug.assert(mem.eql(u8, fromRocInterface.action, "REDRAW"));

    // Parse the TVG text format bytes into a TVG binary format
    var intermediary_tvg = std.ArrayList(u8).init(allocator);
    defer intermediary_tvg.deinit();
    try tvg.text.parse(allocator, fromRocInterface.model, intermediary_tvg.writer());

    // Render TVG binary format into a framebuffer
    var stream = std.io.fixedBufferStream(intermediary_tvg.items);
    // TODO let the user set these parameters
    var image = try tvg.rendering.renderStream(
        allocator,
        allocator,
        .inherit,
        // ^^ Can also specify a size here which improves the quality of the rendering at the cost of speed
        // tvg.rendering.SizeHint{ .size = tvg.rendering.Size{ .width = (1920 / 2), .height = (1080 / 2) } },
        .x1,
        // ^^ Can specify other anti aliasing modes .x4, .x9, .x16, .x25
        stream.reader(),
    );

    // Return the framebuffer
    return image;
}

pub const UpdateEvent = enum {
    KeyPressSpace,
    KeyPressEscape,
    KeyPressEnter,
};

pub const UpdateOp = enum {
    NoOp,
    Exit,
    Redraw,

    fn fromSlice(source: []const u8) UpdateOp {
        if (mem.eql(u8, source, "REDRAW")) {
            return UpdateOp.Redraw;
        } else if (mem.eql(u8, source, "EXIT")) {
            return UpdateOp.Exit;
        } else {
            return UpdateOp.NoOp;
        }
    }
};

pub fn roc_update(event: UpdateEvent, allocator: std.mem.Allocator) !UpdateOp {
    const toRocBytes: []const u8 = switch (event) {
        .KeyPressSpace => "{\"action\":\"UPDATE\",\"model\":[],\"command\":\"KEYPRESS:SPACE\"}",
        .KeyPressEscape => "{\"action\":\"UPDATE\",\"model\":[],\"command\":\"KEYPRESS:ESCAPE\"}",
        .KeyPressEnter => "{\"action\":\"UPDATE\",\"model\":[],\"command\":\"KEYPRESS:ENTER\"}",
    };

    // Create a host interface to send to Roc and convert it to a RocList
    const toRocInterface: HostInterface = try HostInterface.fromSlice(toRocBytes, allocator);
    const toRocList = try HostInterface.toList(toRocInterface, allocator);

    // Call into Roc
    const callresult = RocList.empty();
    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&toRocList));

    // Parse the callresult into a host interface
    const fromRocInterface = try HostInterface.fromList(@constCast(&callresult), allocator);

    // DEBUG STUFF
    std.debug.assert(mem.eql(u8, fromRocInterface.action, "UPDATE"));

    return UpdateOp.fromSlice(fromRocInterface.command);
}

fn addNullTermination(slice: []const u8) ![:0]const u8 {
    var allocator = std.heap.page_allocator;
    var size = slice.len + 1;
    var result = try allocator.alloc(u8, size);
    @memcpy(result.ptr, slice);
    result[slice.len] = 0; // Add null termination
    return result[0..slice.len :0];
}

const AppInitOptions = struct {
    displayMode: []const u8, // 20 windowed, 21 fullscreen, 22 borderless
    border: bool = true,
    title: []const u8,
    width: u32 = 800,
    height: u32 = 600,
};

const HostInterface = struct {
    action: []const u8,
    command: []const u8,
    model: []const u8,

    fn toList(hs: HostInterface, allocator: std.mem.Allocator) !RocList {
        const interfaceBytes = try std.json.stringifyAlloc(allocator, hs, .{});

        // DEBUG STUFF
        // std.debug.print("\nFROM HOST INTERFACE TO ROC LIST {s}\n", .{interfaceBytes});

        const hostInterfaceRocList = RocList.fromSlice(u8, interfaceBytes);

        return hostInterfaceRocList;
    }

    fn fromList(interfaceRocList: *RocList, allocator: std.mem.Allocator) !HostInterface {
        const interfaceBytes: []u8 = if (interfaceRocList.bytes) |bytes| bytes[0..interfaceRocList.length] else unreachable;
        const parsed = try std.json.parseFromSlice(HostInterface, allocator, interfaceBytes, .{});

        return parsed.value;
    }

    fn fromSlice(bytes: []const u8, allocator: std.mem.Allocator) !HostInterface {
        const parsed = try std.json.parseFromSlice(HostInterface, allocator, bytes, .{});
        return parsed.value;
    }
};
