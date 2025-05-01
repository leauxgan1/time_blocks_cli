var should_exit = false;
const audio_file_default = "assets/beep.wav";

pub const IOHandle = struct {
    out: PanicWriter,
    err: PanicWriter,
};

const Command = enum {
    @"--set",
    @"--break",
    @"--sound",
    @"--help",
    invalid,
};

fn printHelp(io: IOHandle) void {
    const help_menu =
        \\usage: tblocks --set [topic,duration]... --break [break_time] --sound [path_to_sound_file]\n
        \\  --set: Initialize a schedule with a list of pairs of topic and durations (HH:MM:SS) in the order in which they should be prioritized 
        \\  --break: Set a break time (HH:MM:SS) between each task
        \\  --sound: Set an alternate sound via a path to play as a notification for the end of each task
        \\  --help: Print this menu
    ;
    io.out.print(help_menu, .{});
}

fn handleSigint(sig: c_int) callconv(.C) void {
    _ = sig;
    should_exit = true;
    std.process.cleanExit();
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const err_file = std.io.getStdErr();

    var io = IOHandle{
        .out = .{ .file = stdout },
        .err = .{ .file = err_file },
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
        printHelp(io);
        return;
    }

    var schedule: Schedule = .{
        .list = .{},
    };

    var audio_file: [*:0]const u8 = audio_file_default;

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
                    const sound_path = collected_args[idx + 1];
                    audio_file = @as([*:0]const u8, @ptrCast(sound_path));
                },
                .@"--help" => {
                    printHelp(io);
                    return;
                },
                else => {},
            }
        }
    }
    try schedule.create(allocator, schedule_nodes);
    defer schedule.list.deinit(allocator);

    var audio_player = AudioPlayer.init(&io) catch |err| switch (err) {
        error.AudioInitializationFailed => {
            io.err.print("Audio player failed to initialize, exiting...\n", .{});
            return;
        },
    };
    try audio_player.loadSound(audio_file);
    defer audio_player.deinit();

    var timer = std.time.Timer{
        .previous = try std.time.Instant.now(),
        .started = try std.time.Instant.now(),
    };
    // Event loop
    while (true) {
        std.Thread.sleep(std.time.ns_per_s);
        const delta = timer.lap();
        if (should_exit) {
            return;
        } else {
            const res = try schedule.step(delta, io, &audio_player);
            if (res == Schedule.Status.Done) {
                should_exit = true;
            }
        }
    }
    io.out.writeAll("\r");
    std.Thread.sleep(std.time.ns_per_s);
}

const std = @import("std");
const utils = @import("utils.zig");
const Schedule = @import("Schedule.zig");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
const PanicWriter = @import("PanicWriter.zig");
