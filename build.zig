const std = @import("std");
const mach_core = @import("mach_core");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const tinyvg_sdk_dep = b.dependency("tinyvg_sdk", .{
        .target = target,
        .optimize = optimize,
    }).module("tvg");

    const zig_img_dep = b.dependency("zig_img", .{
        .target = target,
        .optimize = optimize,
    }).module("zigimg");

    const roc_app_dylib_path = if (b.args) |args| args[0] else "rocLovesGraphics.dylib";

    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "myapp",
        .src = "platform/src/main.zig",
        .target = target,
        .optimize = optimize,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "tinyvg", .module = tinyvg_sdk_dep },
            .{ .name = "zigimg", .module = zig_img_dep },
        },
        .custom_entrypoint = "platform/src/host.zig",
        .roc_app_dylib_path = roc_app_dylib_path,
    });
    if (b.args) |args| app.run.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&app.run.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
