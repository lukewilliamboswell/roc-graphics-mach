const std = @import("std");
const core = @import("mach-core");
const tvg = @import("tinyvg");
const zigimg = @import("zigimg");
const shield8 = @embedFile("shield8.tvgt");

title_timer: core.Timer,
fullscreen_quad_pipeline: *core.gpu.RenderPipeline,
tvg_rendered_texture: *core.gpu.Texture,
// texture: *core.gpu.Texture,
show_result_bind_group: *core.gpu.BindGroup,
img_size: core.gpu.Extent3D,

pub const App = @This();

// Constants from the blur.wgsl shader
const tile_dimension: u32 = 128;
const batch: [2]u32 = .{ 4, 4 };

// Currently hardcoded
const filter_size: u32 = 15;
const iterations: u32 = 2;
var block_dimension: u32 = tile_dimension - (filter_size - 1);
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn init(app: *App) !void {
    try core.init(.{});
    const allocator = gpa.allocator();

    // Parse TVG text bytes
    var intermediary_tvg = std.ArrayList(u8).init(allocator);
    defer intermediary_tvg.deinit();
    try tvg.text.parse(allocator, shield8, intermediary_tvg.writer());

    // Render TVG into an image
    var stream = std.io.fixedBufferStream(intermediary_tvg.items);
    var image = try tvg.rendering.renderStream(
        allocator,
        allocator,
        // .inherit,
        // Can also specify a size here...
        tvg.rendering.SizeHint{ .size = tvg.rendering.Size{ .width = 240, .height = 240 } },
        .x1,
        stream.reader(),
    );
    defer image.deinit(allocator);

    // Start doing WGPU stuff

    const fullscreen_quad_vs_module = core.device.createShaderModuleWGSL(
        "fullscreen_textured_quad.wgsl",
        @embedFile("fullscreen_textured_quad.wgsl"),
    );

    const fullscreen_quad_fs_module = core.device.createShaderModuleWGSL(
        "fullscreen_textured_quad.wgsl",
        @embedFile("fullscreen_textured_quad.wgsl"),
    );

    const blend = core.gpu.BlendState{};
    const color_target = core.gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = core.gpu.ColorWriteMaskFlags.all,
    };

    const fragment_state = core.gpu.FragmentState.init(.{
        .module = fullscreen_quad_fs_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const fullscreen_quad_pipeline_descriptor = core.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment_state,
        .vertex = .{
            .module = fullscreen_quad_vs_module,
            .entry_point = "vert_main",
        },
    };

    const fullscreen_quad_pipeline = core.device.createRenderPipeline(&fullscreen_quad_pipeline_descriptor);

    const sampler = core.device.createSampler(&.{
        .mag_filter = .linear,
        .min_filter = .linear,
    });

    const img_size = core.gpu.Extent3D{ .width = @as(u32, @intCast(image.width)), .height = @as(u32, @intCast(image.height)) };

    const tvg_rendered_texture = core.device.createTexture(&.{
        .size = img_size,
        .format = .rgba8_unorm,
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
            .render_attachment = true,
        },
    });

    const data_layout = core.gpu.Texture.DataLayout{
        .bytes_per_row = @as(u32, @intCast(image.width * 4)),
        .rows_per_image = @as(u32, @intCast(image.height)),
    };

    core.queue.writeTexture(&.{ .texture = tvg_rendered_texture }, &data_layout, &img_size, image.pixels);

    const show_result_bind_group = core.device.createBindGroup(&core.gpu.BindGroup.Descriptor.init(.{
        .layout = fullscreen_quad_pipeline.getBindGroupLayout(0),
        .entries = &.{
            core.gpu.BindGroup.Entry.sampler(0, sampler),
            core.gpu.BindGroup.Entry.textureView(1, tvg_rendered_texture.createView(&core.gpu.TextureView.Descriptor{})),
        },
    }));

    app.title_timer = try core.Timer.start();
    app.fullscreen_quad_pipeline = fullscreen_quad_pipeline;
    app.tvg_rendered_texture = tvg_rendered_texture;
    app.show_result_bind_group = show_result_bind_group;
    app.img_size = img_size;
}

pub fn deinit(app: *App) void {
    _ = app;
    defer _ = gpa.deinit();
    defer core.deinit();
}

pub fn update(app: *App) !bool {

    // HANDLE EVENTS
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        if (event == .close) return true;
    }

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const encoder = core.device.createCommandEncoder(null);
    const color_attachment = core.gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = std.mem.zeroes(core.gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    const render_pass_descriptor = core.gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    const render_pass = encoder.beginRenderPass(&render_pass_descriptor);
    render_pass.setPipeline(app.fullscreen_quad_pipeline);
    render_pass.setBindGroup(0, app.show_result_bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);
    render_pass.end();

    var command = encoder.finish(null);
    encoder.release();
    const queue = core.queue;
    queue.submit(&[_]*core.gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Image Blur [ {d}fps ] [ Input {d}hz ]", .{
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
