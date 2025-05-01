var should_exit = false;
const audio_file_default = "assets/beep.wav";

fn writePanic(fd: std.fs.File, bytes: []const u8) error{}!usize {
    return fd.write(bytes) catch |err| {
        std.debug.panic("write failed with error: {s}", .{@errorName(err)});
    };
}
const PanicWriter = struct {
    file: std.fs.File,

    pub fn writeAll(self: PanicWriter, bytes: []const u8) error{}!void {
        self.file.writeAll(bytes) catch |err| {
            std.debug.panic("write failed: {s}", .{@errorName(err)});
        };
    }
    pub fn writeBytesNTimes(self: PanicWriter, bytes: []const u8, n: usize) error{}!void {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            _ = try self.write(bytes);
        }
    }

    pub fn print(self: PanicWriter, comptime format: []const u8, args: anytype) void {
        std.fmt.format(self, format, args) catch |err| {
            std.debug.panic("fmt failed: {s}", .{@errorName(err)});
        };
    }

    // Required for `std.fmt.format` to work (implements `std.io.Writer`)
    pub const Error = error{};
    pub fn write(self: PanicWriter, bytes: []const u8) Error!usize {
        try self.writeAll(bytes);
        return bytes.len;
    }
};

pub const IOHandle = struct {
    out: PanicWriter,
    err: PanicWriter,
};

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

fn printHelp(io: IOHandle) void {
    const help_menu =
        \\usage: tblocks --set [topic,duration]... --break [break_time] --sound [path_to_sound_file]\n
        \\  --set 
        \\  --break
        \\  --sound
        \\  --help: Print this menu
    ;
    io.out.print(help_menu, .{});
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
    @"--help",
    invalid,
};

const std = @import("std");
const utils = @import("utils.zig");
const Schedule = @import("Schedule.zig");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
