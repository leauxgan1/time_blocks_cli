var should_exit = false;
var audio_file = "assets/beep.wav";

// CONSIDER ADDING A MODE THAT REQUIRES CONFIRMATION TO MOVE ON TO THE NEXT TASK
// EX. --confirm=T/F

const Writer = std.io.GenericWriter(
    std.fs.File,
    std.fs.File.WriteError,
    std.fs.File.write,
);

const Reader = std.io.GenericReader(
    std.fs.File,
    std.fs.File.ReadError,
    std.fs.File.read,
);

pub const IOHandle = struct {
    out: Writer,
    err: Writer,
};

pub fn main() !void {
    const stdout_writer = std.io.getStdOut().writer();
    const err_writer = std.io.getStdErr().writer();

    const io = IOHandle{
        .out = stdout_writer,
        .err = err_writer,
    };

    var da: std.heap.DebugAllocator(.{}) = .{};
    defer _ = da.deinit();
    const allocator = da.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const collected_args = try utils.collect(allocator, []const u8, &args);
    defer allocator.free(collected_args);
    const action = std.os.linux.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };

    _ = std.os.linux.sigaction(std.os.linux.SIG.INT, &action, null);

    if (collected_args.len < 2) {
        printHelp();
        return;
    }

    var schedule: Schedule = .{
        .list = .{},
    };

    // Process args
    var schedule_nodes: [][]const u8 = undefined;
    for (collected_args, 0..) |arg, idx| {
        if (arg[0] == '-' and arg[1] == '-') {
            const command = std.meta.stringToEnum(Command, arg) orelse Command.invalid;
            switch (command) {
                .@"--set" => {
                    var end: usize = idx + 1;
                    while (end < collected_args.len and (collected_args[end][0] != '-' or collected_args[end][1] != '-')) {
                        end += 1;
                    }
                    schedule_nodes = collected_args[idx + 1 .. end];
                },
                .@"--break" => {
                    const next = collected_args[idx + 1];
                    const break_time: TimeFormat = TimeFormat.parse(next) catch .{ .time = .{ 0, 0, 0 } };
                    schedule.set_break(break_time);
                },
                .@"--sound" => {
                    // set sound path to this file
                },
                else => {},
            }
        }
    }
    try schedule.create(allocator, schedule_nodes);
    defer schedule.list.deinit(allocator);

    var audio_player = try AudioPlayer.init(audio_file);
    defer audio_player.deinit();

    var timer = std.time.Timer{
        .previous = try std.time.Instant.now(),
        .started = try std.time.Instant.now(),
    };
    // Event loop
    while (true) {
        std.Thread.sleep(std.time.ns_per_s);
        const delta = timer.lap();
        // std.debug.print("Amount of time passed in ms: {d}\n", .{delta});
        if (should_exit) {
            return;
        } else {
            const res = try schedule.step(delta, io, &audio_player);
            if (res == Schedule.Status.Done) {
                should_exit = true;
            }
        }
    }
    try io.out.writeAll("\r");
    std.Thread.sleep(std.time.ns_per_s);
}

fn printHelp() void {
    const help_menu = "time_blocks --set [topic] [duration] --break [break_time] --sound [path_to_sound_file]\n";
    std.log.info(help_menu, .{});
}

fn handleSigint(sig: c_int) callconv(.C) void {
    _ = sig;
    should_exit = true;
    std.process.cleanExit();
}

const Command = enum {
    @"--set",
    @"--break",
    @"--sound",
    invalid,
};

const std = @import("std");
const utils = @import("utils.zig");
// const AudioPlayer = @import("AudioPlayer.zig");
const Schedule = @import("Schedule.zig");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
