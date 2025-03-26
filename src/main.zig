var should_exit = std.atomic.Atomic(bool).init(false); // Add input checker to exit the program

const Logger = struct {
    out: std.io.GenericWriter(
        std.fs.File,
        std.fs.File.WriteError,
        std.fs.File.write,
    ),
    err: std.io.GenericWriter(
        std.fs.File,
        std.fs.File.WriteError,
        std.fs.File.write,
    ),
};

const TimeFormat = struct {
    hours: u32 = 0,
    minutes: u32 = 0,
    seconds: u32 = 0,

    /// Input must consist of only numbers and colon symbols
    /// Any other symbols invalidate this parsing step and result in an error
    pub fn parse(allocator: std.mem.Allocator, s: []const u8) !TimeFormat {
        // Assumes valid format for time format
        var iter = std.mem.splitScalar(u8, s, ':');
        const time_vals = try utils.collect(allocator, []const u8, &iter);
        defer allocator.free(time_vals);
        if (time_vals.len < 1 or time_vals.len > 3) {
            std.log.err("Invalid format for duration of time block", .{});
            return error.InvalidTimeFormat;
        }
        // Receive the time format in reverse order and fill in seconds, then minutes, then hours
        // Err if number of args is greater than 3 or less than 1

        var formatted = TimeFormat{};
        setTimeFormat: switch (time_vals.len) {
            1 => {
                const seconds_int = try std.fmt.parseInt(u32, time_vals[0], 10);
                formatted.seconds = seconds_int;
            },
            2 => {
                const minutes_int = try std.fmt.parseInt(u32, time_vals[0], 10);
                formatted.minutes = minutes_int;
                continue :setTimeFormat 1;
            },
            3 => {
                const hours_int = try std.fmt.parseInt(u32, time_vals[0], 10);
                formatted.hours = hours_int;
                continue :setTimeFormat 2;
            },
            else => {},
        }

        return formatted;
    }
    fn toNanoseconds(self: TimeFormat) u64 {
        return std.time.ns_per_hour * self.hours + std.time.ns_per_min * self.minutes + std.time.ns_per_s * self.seconds;
    }
    fn toSeconds(self: TimeFormat) u64 {
        return std.time.s_per_hour * self.hours + std.time.s_per_min * self.minutes + self.seconds;
    }
    pub fn format(
        self: TimeFormat,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}:{d}:{d}", .{ self.hours, self.minutes, self.seconds });
    }
};
const Schedule = struct {
    list: std.ArrayListUnmanaged(ScheduleNode),
    const ScheduleNode = struct {
        topic: []const u8,
        duration: TimeFormat,
    };
    const Command = enum {
        set,
        start,
        invalid,
    };

    fn createSchedule(self: *Schedule, allocator: std.mem.Allocator, args: [][]const u8) !void {
        // Time format: HH:MM:SS
        // h - hours, M - minutes, S - seconds
        const command = std.meta.stringToEnum(Command, args[1]) orelse Command.invalid;
        switch (command) {
            Command.set => {
                var i_offset: usize = 1;
                if (args.len < 4) { // if at least two additional arguments are not provided
                    std.log.err("Received insufficient arguments for set command\n, received {d} arguments", .{args.len - 2});
                }
                while (i_offset < args.len - 2) : (i_offset += 2) { // Continually collect pairs of topics and details, ensuring only one is numeric
                    const first = args[i_offset + 1];
                    const second = args[i_offset + 2];

                    const first_time = TimeFormat.parse(allocator, first) catch {
                        const second_time = TimeFormat.parse(allocator, second) catch {
                            std.log.err("Error Creating Schedule - Received two non-times\n", .{});
                            break;
                        };
                        try self.list.append(allocator, .{
                            .topic = first,
                            .duration = second_time,
                        });
                        continue;
                    };
                    const second_time = TimeFormat.parse(allocator, second) catch {
                        try self.list.append(allocator, .{
                            .topic = second,
                            .duration = first_time,
                        });
                        continue;
                    };
                    std.log.err("Error Creating Schedule - Received two times: {any}, {any}\n", .{ first_time, second_time });
                    break;
                }
            },
            Command.start => {},
            Command.invalid => {},
        }
    }
    fn runSchedule(self: *Schedule, logger: Logger, audio_player: AudioPlayer) !void {
        var time_s: u64 = 0; // Fix for this to be accurate to miliseconds not seconds
        const delta: u64 = 1;
        for (self.list.items) |item| {
            const total_seconds = item.duration.toSeconds();
            for (0..total_seconds) |i| {
                try logger.out.print("\rWaiting for {d} in topic {s}     ", .{ total_seconds - i * delta, item.topic });
                try logger.out.print("\n", .{});
                try logger.out.print("\x1b[1A", .{});
                std.Thread.sleep(1 * std.time.ns_per_s);
                time_s += delta;
            }
            audio_player.play();
        }
        try logger.out.print("Finished time blocks : >     \r\n", .{});
        std.Thread.sleep(audio_player.get_duration_ms() * std.time.ns_per_ms);
    }
};

fn handleDefault(schedule: Schedule) !void {
    try schedule.runSchedule();
}

pub fn main() !void {
    const stdout_writer = std.io.getStdOut().writer();
    const err_writer = std.io.getStdErr().writer();

    const logger = Logger{
        .out = stdout_writer,
        .err = err_writer,
    };
    try logger.out.print("{s}\n", .{"Testing"});

    var da: std.heap.DebugAllocator(.{}) = .{};
    defer _ = da.deinit();
    const allocator = da.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const collected_args = try utils.collect(allocator, []const u8, &args);
    defer allocator.free(collected_args);

    if (collected_args.len < 2) {
        printHelp();
        return;
    }

    var schedule: Schedule = .{
        .list = .{},
    };
    try schedule.createSchedule(allocator, collected_args);
    defer schedule.list.deinit(allocator);

    var audio_player = try AudioPlayer.init();
    try audio_player.load("beep.wav");
    defer audio_player.deinit();

    try schedule.runSchedule(logger, audio_player);
}

fn printHelp() void {
    std.log.info("HELP MENU\n", .{});
}

const std = @import("std");
const utils = @import("utils.zig");
const AudioPlayer = @import("AudioPlayer.zig");
