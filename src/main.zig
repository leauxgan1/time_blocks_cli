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
    hours: u32,
    minutes: u32,
    seconds: u32,

    /// Input must consist of only numbers and colon symbols
    /// Any other symbols invalidate this parsing step and result in an error
    pub fn parse(s: []const u8) !TimeFormat {
        // Assumes valid format for time format
        var time_iter = std.mem.splitScalar(u8, s, ':');
        var time_count: u32 = 0;

        var tmp: [3]u32 = .{ 0, 0, 0 };

        while (time_iter.next()) |time_val| {
            const time_int = try std.fmt.parseInt(u32, time_val, 10);
            tmp[time_count] = time_int;
            time_count += 1;
        }

        const formatted = TimeFormat{
            .hours = tmp[0],
            .minutes = tmp[1],
            .seconds = tmp[2],
        };

        return formatted;
    }
    fn toNanoseconds(self: TimeFormat) u64 {
        return std.time.ns_per_hour * self.hours + std.time.ns_per_min * self.minutes + std.time.ns_per_s * self.seconds;
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

                    const first_time = TimeFormat.parse(first) catch {
                        const second_time = TimeFormat.parse(second) catch {
                            std.log.err("Error Creating Schedule - Received two non-times\n", .{});
                            break;
                        };
                        try self.list.append(allocator, .{
                            .topic = first,
                            .duration = second_time,
                        });
                        continue;
                    };
                    const second_time = TimeFormat.parse(second) catch {
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
            for (0..item.duration.seconds / delta) |i| {
                try logger.out.print("Waiting for {d} in topic {s}     \r ", .{ item.duration.seconds - i * delta, item.topic });
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
