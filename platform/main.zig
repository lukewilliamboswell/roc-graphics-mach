const std = @import("std");
const builtin = @import("builtin");

const core = @import("mach-core");
// const gpu = core.gpu;
const str = @import("builtins/bitcode/src/glue.zig").str;
const RocStr = str.RocStr;
// const testing = std.testing;
// const expectEqual = testing.expectEqual;
// const expect = testing.expect;

const Align = 2 * @alignOf(usize);

extern fn malloc(size: usize) callconv(.C) ?*align(Align) anyopaque;
extern fn realloc(c_ptr: [*]align(Align) u8, size: usize) callconv(.C) ?*anyopaque;
extern fn free(c_ptr: [*]align(Align) u8) callconv(.C) void;
extern fn memcpy(dst: [*]u8, src: [*]u8, size: usize) callconv(.C) void;
extern fn memset(dst: [*]u8, value: i32, size: usize) callconv(.C) void;

const DEBUG: bool = false;

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
    stderr.print("Application crashed with message\n\n    {s}\n\nShutting down\n", .{msg}) catch unreachable;
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

extern fn roc__mainForHost_1_exposed_generic(*RocStr, *RocStr) void;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var timer = try std.time.Timer.start();

    // actually call roc to populate the callresult
    var argument = RocStr.fromSlice("Luke");
    var callresult = RocStr.empty();
    roc__mainForHost_1_exposed_generic(&callresult, &argument);

    const nanos = timer.read();
    const seconds = (@as(f64, @floatFromInt(nanos)) / 1_000_000_000.0);

    // print the result to stdout
    stdout.print("{s}", .{callresult.asSlice()}) catch unreachable;

    callresult.decref();

    try stderr.print("\nruntime: {d:.3}ms\n", .{seconds * 1000});

    // Run from the directory where the executable is located so relative assets can be found.
    // var buffer: [1024]u8 = undefined;
    // const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    // std.os.chdir(path) catch {};

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // core.allocator = gpa.allocator();

    // // Initialize GPU implementation
    // if (comptime core.options.use_wgpu) try core.wgpu.Impl.init(core.allocator, .{});
    // if (comptime core.options.use_dgpu) try core.dusk.Impl.init(core.allocator, .{});

    // var app: App = undefined;
    // try app.init();
    // defer app.deinit();
    // while (!try core.update(&app)) {}
}

const App = struct {
    title_timer: core.Timer,
    pipeline: *core.gpu.RenderPipeline,

    // pub const GPUInterface = core.wgpu.dawn.Interface;
    // pub const DGPUInterface = core.dusk.Impl;

    pub fn init(app: *App) !void {
        try core.init(.{});

        const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
        defer shader_module.release();

        // Fragment state
        const blend = core.gpu.BlendState{};
        const color_target = core.gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = core.gpu.ColorWriteMaskFlags.all,
        };
        const fragment = core.gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "frag_main",
            .targets = &.{color_target},
        });
        const pipeline_descriptor = core.gpu.RenderPipeline.Descriptor{
            .fragment = &fragment,
            .vertex = core.gpu.VertexState{
                .module = shader_module,
                .entry_point = "vertex_main",
            },
        };
        const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

        app.* = .{ .title_timer = try core.Timer.start(), .pipeline = pipeline };
    }

    pub fn deinit(app: *App) void {
        defer core.deinit();
        app.pipeline.release();
    }

    pub fn update(app: *App) !bool {
        var iter = core.pollEvents();
        while (iter.next()) |event| {
            switch (event) {
                .close => return true,
                else => {},
            }
        }

        const queue = core.queue;
        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
        const color_attachment = core.gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(core.gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        };

        const encoder = core.device.createCommandEncoder(null);
        const render_pass_info = core.gpu.RenderPassDescriptor.init(.{
            .color_attachments = &.{color_attachment},
        });
        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(app.pipeline);
        pass.draw(3, 1, 0, 0);
        pass.end();
        pass.release();

        var command = encoder.finish(null);
        encoder.release();

        queue.submit(&[_]*core.gpu.CommandBuffer{command});
        command.release();
        core.swap_chain.present();
        back_buffer_view.release();

        // update the window title every second
        if (app.title_timer.read() >= 1.0) {
            app.title_timer.reset();
            try core.printTitle("Triangle [ {d}fps ] [ Input {d}hz ]", .{
                core.frameRate(),
                core.inputRate(),
            });
        }

        return false;
    }
};
