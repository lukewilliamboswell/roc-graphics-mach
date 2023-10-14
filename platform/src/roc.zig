const std = @import("std");
const builtin = @import("builtin");
const list = @import("list.zig");
const str = @import("str.zig");
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

const AppInitOptions = struct {
    displayMode: []const u8, // 20 windowed, 21 fullscreen, 22 borderless
    border: bool = true,
    title: []const u8,
    width: u32 = 800,
    height: u32 = 600,
};

const InitFromRoc = struct {
    action: []const u8,
    command: AppInitOptions,
    model: []const u8,
};

const InitResult = struct {
    options: core.Options,
    model: []const u8,
};

pub fn roc_init(allocator: std.mem.Allocator) !InitResult {
    var heap_arena_allocator = std.heap.ArenaAllocator.init(allocator);
    const heap_allocator = heap_arena_allocator.allocator();
    defer heap_arena_allocator.deinit();

    // Create a host interface to send to Roc and convert it to a RocList
    var argument: RocList = RocList.fromSlice(u8, "{\"action\":\"INIT\",\"model\":\"\",\"command\":\"\"}");

    // Call into Roc
    var callresult: RocList = RocList.empty();
    defer callresult.decref(0);

    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&argument));

    // Parse the callresult into a host interface
    const callresultBytes: []u8 = if (callresult.bytes) |bytes| bytes[0..callresult.length] else unreachable;

    // std.log.info("INIT CALL RESULT:{s}\n", .{callresultBytes});

    var fromRocInterface = try std.json.parseFromSlice(InitFromRoc, heap_allocator, callresultBytes, .{});
    defer fromRocInterface.deinit();

    std.debug.assert(mem.eql(u8, fromRocInterface.value.action, "INIT"));

    // Set the display mode
    var display_mode: core.DisplayMode =
        if (mem.eql(u8, fromRocInterface.value.command.displayMode, "borderless"))
        core.DisplayMode.borderless
    else if (mem.eql(u8, fromRocInterface.value.command.displayMode, "fullscreen"))
        core.DisplayMode.fullscreen
    else
        core.DisplayMode.windowed;

    // Create options to configure mach-core library
    const options = core.Options{
        .display_mode = display_mode,
        .border = fromRocInterface.value.command.border,
        .title = try addNullTermination(fromRocInterface.value.command.title),
        .size = core.Size{ .width = fromRocInterface.value.command.width, .height = fromRocInterface.value.command.height },
    };

    // Allocate and copy the model bytes to keep these bytes alive
    const model = try allocator.alloc(u8, fromRocInterface.value.model.len);
    @memcpy(model.ptr, fromRocInterface.value.model);

    return InitResult{ .options = options, .model = model };
}

const RenderFromRoc = struct {
    action: []const u8,
    command: []const u8,
    model: []const u8,
};

pub fn roc_render(allocator: std.mem.Allocator, model: []const u8) !tvg.rendering.Image {
    var heap_arena_allocator = std.heap.ArenaAllocator.init(allocator);
    const heap_allocator = heap_arena_allocator.allocator();
    defer heap_arena_allocator.deinit();

    const argBytes = try std.fmt.allocPrint(heap_allocator, "{s}{s}{s}", .{
        "{\"action\":\"REDRAW\",\"model\":\"",
        model,
        "\",\"command\":\"\"}",
    });

    // std.log.info("RENDER ARG BYTES {s}", .{argBytes});

    // Create a host interface to send to Roc and convert it to a RocList
    var argument: RocList = RocList.fromSlice(u8, argBytes);

    // Call into Roc
    var callresult: RocList = RocList.empty();
    defer callresult.decref(0);

    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&argument));

    // Parse the callresult into a host interface
    const callresultBytes: []u8 = if (callresult.bytes) |bytes| bytes[0..callresult.length] else unreachable;

    // std.log.info("RENDER CALL RESULT:{s}\n", .{callresultBytes});

    var fromRocInterface = try std.json.parseFromSlice(RenderFromRoc, heap_allocator, callresultBytes, .{});
    defer fromRocInterface.deinit();

    std.debug.assert(mem.eql(u8, fromRocInterface.value.action, "REDRAW"));

    // Parse the TVG text format bytes into a TVG binary format
    var intermediary_tvg = std.ArrayList(u8).init(heap_allocator);
    defer intermediary_tvg.deinit();
    try tvg.text.parse(heap_allocator, fromRocInterface.value.model, intermediary_tvg.writer());

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

const UpdateFromRoc = struct {
    action: []const u8,
    command: []const u8,
    model: []const u8,
};

const UpdateResult = struct {
    op: UpdateOp,
    model: []const u8,
};

pub fn roc_update(event: UpdateEvent, model: []const u8, allocator: std.mem.Allocator) !UpdateResult {
    var heap_arena_allocator = std.heap.ArenaAllocator.init(allocator);
    const heap_allocator = heap_arena_allocator.allocator();
    defer heap_arena_allocator.deinit();

    const commandBytes = switch (event) {
        .KeyPressSpace => "\",\"command\":\"KEYPRESS:SPACE\"}",
        .KeyPressEscape => "\",\"command\":\"KEYPRESS:ESCAPE\"}",
        .KeyPressEnter => "\",\"command\":\"KEYPRESS:ENTER\"}",
    };

    const argBytes = try std.fmt.allocPrint(heap_allocator, "{s}{s}{s}", .{
        "{\"action\":\"UPDATE\",\"model\":\"",
        model,
        commandBytes,
    });

    // std.log.info("UPDATE ARG BYTES {s}", .{argBytes});

    // Create a host interface to send to Roc and convert it to a RocList
    var argument: RocList = RocList.fromSlice(u8, argBytes);

    // Call into Roc
    var callresult: RocList = RocList.empty();
    defer callresult.decref(0);

    roc__mainForHost_1_exposed_generic(@constCast(&callresult), @constCast(&argument));

    // Parse the callresult into a host interface
    const callresultBytes: []u8 = if (callresult.bytes) |bytes| bytes[0..callresult.length] else unreachable;
    var fromRocInterface = try std.json.parseFromSlice(UpdateFromRoc, heap_allocator, callresultBytes, .{});
    defer fromRocInterface.deinit();

    std.debug.assert(mem.eql(u8, fromRocInterface.value.action, "UPDATE"));

    // Allocate and copy the model bytes to keep these bytes alive
    const updatedModel = try allocator.alloc(u8, fromRocInterface.value.model.len);
    @memcpy(updatedModel.ptr, fromRocInterface.value.model);

    return UpdateResult{
        .op = UpdateOp.fromSlice(fromRocInterface.value.command),
        .model = updatedModel,
    };
}

fn addNullTermination(slice: []const u8) ![:0]const u8 {
    var allocator = std.heap.page_allocator;
    var size = slice.len + 1;
    var result = try allocator.alloc(u8, size);
    @memcpy(result.ptr, slice);
    result[slice.len] = 0; // Add null termination
    return result[0..slice.len :0];
}
