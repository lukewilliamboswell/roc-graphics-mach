const std = @import("std");

var _module: ?*std.build.Module = null;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build a static library for Roc to link with
    const lib = b.addStaticLibrary(.{
        .name = "host",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Dependencies
    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });
    lib.addModule("mach-core", mach_core_dep.module("mach-core"));
    lib.linkLibrary(mach_core_dep.artifact("mach-core"));

    lib.addModule("mach-glfw", b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    }).module("mach-glfw"));

    lib.addModule("gamemode", b.dependency("mach_gamemode", .{
        .target = target,
        .optimize = optimize,
    }).module("mach-gamemode"));

    lib.addModule("mach-gpu", b.dependency("mach_gpu", .{
        .target = target,
        .optimize = optimize,
    }).module("mach-gpu"));

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
