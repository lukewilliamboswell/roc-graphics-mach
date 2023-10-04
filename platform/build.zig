const std = @import("std");
const glfw = @import("mach_glfw");
const gpu = @import("mach_gpu");

var _module: ?*std.build.Module = null;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "host",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const mach_core_builder = mach_core_dep.builder;

    try glfw.link(mach_core_builder.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    }).builder, lib);

    const mach_gpu_dep = mach_core_builder.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    });

    try gpu.link(mach_gpu_dep.builder, lib, .{});

    lib.addModule("mach-core", mach_core_dep.module("mach-core"));
    lib.addModule("mach-gpu", mach_gpu_dep.module("mach-gpu"));

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
