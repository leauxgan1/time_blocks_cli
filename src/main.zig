var should_exit = false;
var paused = false;
const audio_file_default = "assets/beep.wav";

pub const output_buffer_size = 100;
pub const center_format_string = std.fmt.comptimePrint("{{s: ^{d}}}", .{output_buffer_size});

pub const IOHandle = struct {
    out: PanicWriter,
    err: PanicWriter,
};

const Command = enum {
    @"--set",
    @"--break",
    @"--sound",
    @"--help",
    @"--repeat",
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

// Cleanly exit the program upon receiving CTRL+C
fn handleSigint(sig: c_int) callconv(.C) void {
    _ = sig;
    std.io.getStdOut().writer().print("\x1B[0GExiting schedule early...                              \n", .{}) catch unreachable;
    should_exit = true;
    std.process.cleanExit();
}

// Pause the timer and display a paused message upon receiving CTRL+Z
fn handleSigtstp(sig: c_int) callconv(.C) void {
    _ = sig;
    std.io.getStdOut().writer().print("\x1B[0GPaused for now... (CTRL+Z to resume)                      \x1B[0G", .{}) catch unreachable;
    paused = !paused;
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
    const int_action = std.os.linux.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };
    const tstp_action = std.os.linux.Sigaction{ // Custom behavior overriding default pause
        .handler = .{ .handler = handleSigtstp },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };

    _ = std.os.linux.sigaction(std.os.linux.SIG.INT, &int_action, null);
    _ = std.os.linux.sigaction(std.os.linux.SIG.TSTP, &tstp_action, null);

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
                    schedule.setBreak(break_time);
                },
                .@"--sound" => {
                    const sound_path = collected_args[idx + 1];
                    audio_file = @as([*:0]const u8, @ptrCast(sound_path));
                },
                .@"--repeat" => {
                    const next = collected_args[idx + 1];
                    const repetitions = std.fmt.parseInt(u32, next, 10) catch 0;
                    if (repetitions > 0) { // Next argument is a valid count of repetitions
                        schedule.setRepetitions(repetitions);
                    } else {
                        schedule.setRepetitions(null); // Set to infinitely repeat until sigint
                    }
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
        if (should_exit) {
            return;
        } else if (schedule.options.paused) {
            std.Thread.sleep(std.time.ns_per_ms * 100);
            if (!paused) {
                schedule.setPaused(false);
                std.io.getStdOut().writer().print("\x1B[0GUnpaused!                                             \x1B[0G", .{}) catch unreachable;
                _ = timer.lap();
            }
        } else {
            std.Thread.sleep(std.time.ns_per_s);
            const delta = std.time.ns_per_s * 1;
            if (paused) {
                schedule.setPaused(true);
                continue;
            }
            const res = try schedule.step(delta, &io, &audio_player);
            if (res == Schedule.Status.Done) {
                should_exit = true;
            }
        }
    }
    io.out.writeAll("\r");
    std.Thread.sleep(std.time.ns_per_s);
}

test "Formatting strings to exact width" {
    const short_text = "Hi";
    const perfect_text = "I am the perfect string :)";
    const too_long_text = "I am too long cut me off  here oh no where did I go";

    var io = IOHandle{
        .out = .{ .file = std.io.getStdOut() },
        .err = .{ .file = std.io.getStdErr() },
    };
    io.out.print("|", .{});
    io.printFixedOut(center_format_string, .{short_text});
    io.out.print("|\n", .{});

    io.out.print("|", .{});
    io.printFixedOut(center_format_string, .{perfect_text});
    io.out.print("|\n", .{});

    io.out.print("|", .{});
    io.printFixedOut(center_format_string, .{too_long_text});
    io.out.print("|\n", .{});
}

const std = @import("std");
const utils = @import("utils.zig");
const Schedule = @import("Schedule.zig");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
const PanicWriter = @import("PanicWriter.zig");
