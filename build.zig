const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSmall;
    const exe = b.addExecutable(.{
        .name = "tblocks",
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        } },
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile(.{
        .file = .{ .src_path = .{ .owner = b, .sub_path = "include/miniaudio.c" } },
        .flags = &[_][]const u8{"-std=c99"},
    });
    exe.addIncludePath(.{ .src_path = .{
        .owner = b,
        .sub_path = "include/",
    } });
    exe.linkLibC();
    // exe.linkSystemLibrary("SDL2");

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");

    run_step.dependOn(&run_cmd.step);
    const test_step = b.step("test", "Run all tests in all files");

    for (test_targets) |t| {
        const main_tests = b.addTest(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(t),
        });
        const audio_tests = b.addTest(.{
            .root_source_file = b.path("src/AudioPlayer.zig"),
            .target = b.resolveTargetQuery(t),
            .link_libc = true,
        });
        audio_tests.linkLibC();
        audio_tests.addIncludePath(.{
            .src_path = .{
                .owner = b,
                .sub_path = "include",
            },
        });
        audio_tests.addCSourceFile(.{
            .file = .{
                .src_path = .{
                    .owner = b,
                    .sub_path = "include/miniaudio.c",
                },
            },
            .flags = &.{},
        });
        if (target.result.os.tag == .windows) {
            audio_tests.linkSystemLibrary("ole32");
            audio_tests.linkSystemLibrary("kernel32");
            audio_tests.linkSystemLibrary("user32");
        } else if (target.result.os.tag == .macos) {
            audio_tests.linkFramework("CoreAudio");
            audio_tests.linkFramework("CoreFoundation");
            audio_tests.linkFramework("AudioToolbox");
        }
        test_step.dependOn(&main_tests.step);
        test_step.dependOn(&audio_tests.step);
    }
}

const test_targets = [_]std.Target.Query{
    .{}, // native
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    },
};
