const std = @import("std");
const core = @import("mach-core");
const tvg = @import("tinyvg");
const zigimg = @import("zigimg");
const roc = @import("roc.zig");

title_timer: core.Timer,
tick_timer: core.Timer,
fullscreen_quad_pipeline: *core.gpu.RenderPipeline,
texture: *core.gpu.Texture,
texture_data_layout: core.gpu.Texture.DataLayout,
show_result_bind_group: *core.gpu.BindGroup,
img_size: core.gpu.Extent3D,

var model: []const u8 = undefined;

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn init(app: *App) !void {

    // Call Roc to get initial parameters from Init
    const initResult = try roc.roc_init(allocator);

    // std.log.info("INIT RESULT: {any}\n", .{initResult});

    model = initResult.model;

    // Initialize the mach-core library
    try core.init(initResult.options);

    // Call Roc to get the TVG text bytes from Render
    var framebuffer = try roc.roc_render(allocator, model);
    const image_pixels: []tvg.rendering.Color8 = framebuffer.pixels;
    const image_width: u32 = @intCast(framebuffer.width);
    const image_height: u32 = @intCast(framebuffer.height);
    defer _ = &framebuffer.deinit(allocator);

    // Start doing WGPU and Graphics stuff ------------------

    // Create a Vertex shader
    const fullscreen_quad_vs_module = core.device.createShaderModuleWGSL(
        "fullscreen_textured_quad.wgsl",
        @embedFile("fullscreen_textured_quad.wgsl"),
    );

    // Create a Fragment shader
    const fullscreen_quad_fs_module = core.device.createShaderModuleWGSL(
        "fullscreen_textured_quad.wgsl",
        @embedFile("fullscreen_textured_quad.wgsl"),
    );

    // Setup Blend and Color states
    const blend = core.gpu.BlendState{};
    const color_target = core.gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = core.gpu.ColorWriteMaskFlags.all,
    };

    // Fragment initialisation
    const fragment_state = core.gpu.FragmentState.init(.{
        .module = fullscreen_quad_fs_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    // Describe render pipeline
    const fullscreen_quad_pipeline_descriptor = core.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment_state,
        .vertex = .{
            .module = fullscreen_quad_vs_module,
            .entry_point = "vert_main",
        },
    };

    // Create our pipeline
    const fullscreen_quad_pipeline = core.device.createRenderPipeline(&fullscreen_quad_pipeline_descriptor);

    // Create a sampler
    const sampler = core.device.createSampler(&.{
        .mag_filter = .linear,
        .min_filter = .linear,
    });

    // Create a texture
    const img_size = core.gpu.Extent3D{ .width = image_width, .height = image_height };
    const texture = core.device.createTexture(&.{
        .size = img_size,
        .format = .rgba8_unorm,
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
            .render_attachment = true,
        },
    });

    // Describe the texture layout
    const texture_data_layout = core.gpu.Texture.DataLayout{
        .bytes_per_row = image_width * 4,
        .rows_per_image = image_height,
    };

    // Queue command to copy the bytes into the texture
    core.queue.writeTexture(&.{ .texture = texture }, &texture_data_layout, &img_size, image_pixels);

    // Setup bind group for the shader to access sampler and texture
    const show_result_bind_group = core.device.createBindGroup(&core.gpu.BindGroup.Descriptor.init(.{
        .layout = fullscreen_quad_pipeline.getBindGroupLayout(0),
        .entries = &.{
            core.gpu.BindGroup.Entry.sampler(0, sampler),
            core.gpu.BindGroup.Entry.textureView(1, texture.createView(&core.gpu.TextureView.Descriptor{})),
        },
    }));

    app.title_timer = try core.Timer.start();
    app.tick_timer = try core.Timer.start();
    app.fullscreen_quad_pipeline = fullscreen_quad_pipeline;
    app.texture = texture;
    app.texture_data_layout = texture_data_layout;
    app.show_result_bind_group = show_result_bind_group;
    app.img_size = img_size;
}

pub fn deinit(app: *App) void {
    _ = app;

    // Dont forget to free the current model when exiting
    allocator.free(model);

    defer _ = gpa.deinit();
    defer core.deinit();
}

pub fn update(app: *App) !bool {

    // HANDLE EVENTS
    var redraw = false;
    var iter = core.pollEvents();
    while (iter.next()) |event| {

        // std.debug.print("HANDLE EVENT: {any}, Model: {any}\n", .{ event, model });

        switch (event) {
            .key_press => |ev| {
                switch (ev.key) {
                    .space => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressSpace, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .enter => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressEnter, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .escape => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressEscape, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .left => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressLeft, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .right => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressRight, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .up => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressUp, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    .down => {
                        const updateResult = try roc.roc_update(roc.UpdateEvent.KeyPressDown, model, allocator);

                        // Copy the model bytes into the model buffer
                        allocator.free(model);
                        model = updateResult.model;

                        switch (updateResult.op) {
                            roc.UpdateOp.NoOp => {},
                            roc.UpdateOp.Exit => return true,
                            roc.UpdateOp.Redraw => redraw = true,
                        }
                    },
                    else => {},
                }
            },
            .key_release => |ev| {
                switch (ev.key) {
                    // .left => app.direction[0] -= 1,
                    // .right => app.direction[0] += 1,
                    // .up => app.direction[1] -= 1,
                    // .down => app.direction[1] += 1,
                    else => {},
                }
            },
            .close => return true,
            else => {},
        }
    }

    // Check for Tick Event
    if (app.tick_timer.readPrecise() >= 1_000_000_000) {
        app.tick_timer.reset();

        const updateResult = try roc.roc_update(roc.UpdateEvent.Tick, model, allocator);

        // Copy the model bytes into the model buffer
        allocator.free(model);
        model = updateResult.model;

        switch (updateResult.op) {
            roc.UpdateOp.NoOp => {},
            roc.UpdateOp.Exit => return true,
            roc.UpdateOp.Redraw => redraw = true,
        }
    }

    if (redraw) {
        // std.log.info("REDRAW Model: {any}\n", .{model});

        // Call Roc to get the TVG text bytes from Render
        var framebuffer = try roc.roc_render(allocator, model);
        const image_pixels: []tvg.rendering.Color8 = framebuffer.pixels;
        const image_width: u32 = @intCast(framebuffer.width);
        const image_height: u32 = @intCast(framebuffer.height);
        defer _ = &framebuffer.deinit(allocator);

        const img_size = core.gpu.Extent3D{ .width = image_width, .height = image_height };
        core.queue.writeTexture(&.{ .texture = app.texture }, &app.texture_data_layout, &img_size, image_pixels);
    }

    // Get the current view
    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    // Create a GPUCommandEncoder
    // https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder
    const gpu_command_encoder = core.device.createCommandEncoder(null);

    // Create a Color attachment for the current view
    const color_attachment = core.gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = std.mem.zeroes(core.gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    // Create a render pass descriptor for the Color attachment
    const render_pass_descriptor = core.gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    // Queue render pass commands
    const render_pass = gpu_command_encoder.beginRenderPass(&render_pass_descriptor);
    render_pass.setPipeline(app.fullscreen_quad_pipeline);
    render_pass.setBindGroup(0, app.show_result_bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);
    render_pass.end();

    // Complete recording command sequence on GPUCommandEncoder,
    // return corresponding GPUCommandBuffer
    var gpu_command_buffer = gpu_command_encoder.finish(null);
    gpu_command_encoder.release();

    // A GPUCommandBuffer is created via the GPUCommandEncoder.finish() method;
    // the GPU commands recorded within are submitted for execution by passing
    // the GPUCommandBuffer into the parameter of a GPUQueue.submit() call.
    // https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandBuffer
    const queue = core.queue;

    queue.submit(&[_]*core.gpu.CommandBuffer{gpu_command_buffer});
    gpu_command_buffer.release();

    core.swap_chain.present();
    back_buffer_view.release();

    // Log framerate and input rate information
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        // TODO improve logging without using window title or debug print
        // try core.printTitle("[ {d}fps ] [ Input {d}hz ]", .{
        //     core.frameRate(),
        //     core.inputRate(),
        // });
        std.debug.print("[ {d}fps ] [ Input {d}hz ]\n", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}

const Framebuffer = struct {
    const Self = @This();
    const gamma = 2.2;

    // private API
    slice: []tvg.Color,
    stride: usize,

    // public API
    width: usize,
    height: usize,

    pub fn setPixel(self: *const Self, x: isize, y: isize, src_color: tvg.Color) void {
        if (x < 0 or y < 0)
            return;
        if (x >= self.width or y >= self.height)
            return;
        const offset = (std.math.cast(usize, y) orelse return) * self.stride + (std.math.cast(usize, x) orelse return);

        const destination_pixel = &self.slice[offset];

        const dst_color = destination_pixel.*;

        if (src_color.a == 0) {
            return;
        }
        if (src_color.a == 255) {
            destination_pixel.* = src_color;
            return;
        }

        // src over dst
        //   a over b

        const src_alpha = src_color.a;
        const dst_alpha = dst_color.a;

        const fin_alpha = src_alpha + (1.0 - src_alpha) * dst_alpha;

        destination_pixel.* = tvg.Color{
            .r = lerpColor(src_color.r, dst_color.r, src_alpha, dst_alpha, fin_alpha),
            .g = lerpColor(src_color.g, dst_color.g, src_alpha, dst_alpha, fin_alpha),
            .b = lerpColor(src_color.b, dst_color.b, src_alpha, dst_alpha, fin_alpha),
            .a = fin_alpha,
        };
    }

    fn lerpColor(src: f32, dst: f32, src_alpha: f32, dst_alpha: f32, fin_alpha: f32) f32 {
        const src_val = mapToLinear(src);
        const dst_val = mapToLinear(dst);

        const value = (1.0 / fin_alpha) * (src_alpha * src_val + (1.0 - src_alpha) * dst_alpha * dst_val);

        return mapToGamma(value);
    }

    fn mapToLinear(val: f32) f32 {
        return std.math.pow(f32, val, gamma);
    }

    fn mapToGamma(val: f32) f32 {
        return std.math.pow(f32, val, 1.0 / gamma);
    }

    fn mapToGamma8(val: f32) u8 {
        return @intFromFloat(255.0 * mapToGamma(val));
    }
};
