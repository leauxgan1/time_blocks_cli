list: std.ArrayListUnmanaged(ScheduleNode),
timer: u64 = 0,
prev_time: u64 = 0,
curr_topic: usize = 0, // Index representing current topic
progress_size: usize = DEFAULT_PROGRESS_SIZE,
options: ScheduleOptions = .{},

const DEFAULT_PROGRESS_SIZE = 50;

const Schedule = @This();
const ScheduleNode = struct {
    topic: []const u8,
    duration: TimeFormat,
};

const ScheduleOptions = struct {
    break_time: TimeFormat = .{},
    repeating: RepeatingState = .NonRepeating,
    paused: bool = false,
};

const RepeatingState = union(enum) {
    NonRepeating,
    ReapeatingInfinitely,
    RepeatingCount: u32,
};

pub const Status = enum {
    InProgress,
    Done,
    Paused,
};

pub fn create(self: *Schedule, allocator: std.mem.Allocator, args: [][]const u8) !void {
    // Time format: HH:MM:SS
    // h - hours, M - minutes, S - seconds
    var i: usize = 0;
    while (i < args.len - 1) : (i += 2) { // Continually collect pairs of topics and details, ensuring only one is numeric
        const first = args[i];
        const second = args[i + 1];

        const first_time = TimeFormat.parse(first) catch {
            const second_time = TimeFormat.parse(second) catch {
                std.log.err("Error Creating Schedule - Received two non-times\n", .{});
                break;
            };
            try self.list.append(allocator, .{
                .topic = first,
                .duration = second_time,
            });
            if (self.options.break_time.toSeconds() > 0 and i < args.len - 2) {
                try self.list.append(allocator, .{
                    .topic = "Break time! Get some tea or coffee",
                    .duration = self.options.break_time,
                });
            }
            continue;
        };
        const second_time = TimeFormat.parse(second) catch {
            try self.list.append(allocator, .{
                .topic = second,
                .duration = first_time,
            });
            if (self.options.break_time.toSeconds() > 0 and i < args.len - 2) {
                try self.list.append(allocator, .{
                    .topic = "Break time...",
                    .duration = self.options.break_time,
                });
            }
            continue;
        };
        std.log.err("Error Creating Schedule - Received two times: {any}, {any}\n", .{ first_time, second_time });
        break;
    }
}
fn getTopicIndex(self: Schedule) ?usize {
    var total_len: u64 = 0;
    for (self.list.items, 0..) |schedule_item, i| {
        total_len += schedule_item.duration.toNanoseconds();
        if (self.timer + self.prev_time < total_len) {
            return i;
        }
    }
    return null;
}

fn printProgressBar(io: *IOHandle, current_time: u64, end_time: u64, len: usize) void {
    // Creates a string of size len that is filled with █ and ▒ characters to signify how close the time block is to completion
    const filled_ratio = @as(f64, @floatFromInt(current_time)) / @as(f64, @floatFromInt(end_time)); // 10 / 100 -> 0.1
    const num_filled = @as(usize, @intFromFloat(filled_ratio * @as(f64, @floatFromInt(len)))); // 0.1 * 10 = 1
    for (0..num_filled) |_| {
        io.out.print("█", .{});
    }
    for (num_filled..len) |_| {
        io.out.print("▒", .{});
    }
    io.out.print("\n", .{});
}

pub fn step(self: *Schedule, delta: u64, io: *IOHandle, audio_player: *AudioPlayer) !Status {
    if (self.options.paused) {
        return .InProgress;
    }
    self.timer += delta;
    const current_topic = self.getTopicIndex();
    if (current_topic) |curr_topic| { // Schedule is continuing, print information about current topic
        if (curr_topic == self.curr_topic + 1) { // Just entered new topic
            io.out.printBuffer("Waiting in topic {s} for 0... (CTRL+Z to pause)", .{self.list.items[curr_topic - 1].topic});
            io.out.print("\n", .{});
            printProgressBar(io, 0, 1, self.progress_size);

            io.out.print("\x1b[2A", .{}); // Reset cursor after printing

            try audio_player.play();
            self.curr_topic = curr_topic;
            self.prev_time += self.timer;
            self.timer = 0;
        }
        const current_schedule_item = self.list.items[curr_topic];
        const time_total = current_schedule_item.duration.toSeconds();
        const time_remaining = time_total - self.timer / std.time.ns_per_s;
        io.out.printBuffer("Waiting in topic {s} for {d}... (CTRL+Z to pause)", .{ current_schedule_item.topic, time_remaining });
        io.out.print("\n", .{});
        printProgressBar(io, self.timer / std.time.ns_per_s, time_total, self.progress_size);
        io.out.print("\x1b[2A", .{}); // Reset cursor after printing
        return .InProgress;
    } else { // Schedule is over, print ending message
        repeat: switch (self.options.repeating) {
            .ReapeatingInfinitely => {
                self.resetSchedule();
                io.out.printBuffer("Repeating schedule infinitely...", .{});
                io.out.print("\n", .{});
                printProgressBar(io, 1, 1, self.progress_size);
                io.out.print("\x1b[2A", .{}); // Reset cursor after printing
                try audio_player.play();
                return .InProgress;
            },
            .RepeatingCount => {
                self.resetSchedule();
                self.options.repeating.RepeatingCount -= 1;
                if (self.options.repeating.RepeatingCount < 1) {
                    continue :repeat .NonRepeating;
                }
                io.out.printBuffer("Repeating schedule {d} more times...     ", .{self.options.repeating.RepeatingCount});
                io.out.print("\n", .{});
                printProgressBar(io, 1, 1, self.progress_size);
                io.out.print("\x1b[2A", .{}); // Reset cursor after printing
                try audio_player.play();
                return .InProgress;
            },
            .NonRepeating => {
                io.out.printBuffer("Finished time blocks : >", .{});
                io.out.print("\n", .{});
                printProgressBar(io, 1, 1, self.progress_size);
                try audio_player.play();
                return .Done;
            },
        }
    }
}
pub fn setBreak(self: *Schedule, duration: TimeFormat) void {
    self.options.break_time = duration;
}
pub fn setRepetitions(self: *Schedule, repetitions: ?u32) void {
    if (repetitions) |r| {
        self.options.repeating = .{ .RepeatingCount = r };
    } else {
        self.options.repeating = .ReapeatingInfinitely;
    }
}

pub fn setPaused(self: *Schedule, is_paused: bool) void {
    self.options.paused = is_paused;
}

fn resetSchedule(self: *Schedule) void {
    self.timer = 0;
    self.prev_time = 0;
    self.curr_topic = 0;
}

test "Formatting of progress bar" {
    const allocator = std.testing.allocator;
    var s: Schedule = .{ .list = .{} };
    defer s.list.deinit(allocator);
    const stdout = std.io.getStdOut();
    const err_file = std.io.getStdErr();

    const io = IOHandle{
        .out = .{ .file = stdout },
        .err = .{ .file = err_file },
    };

    var args: [4][]const u8 = .{
        "Workout",
        "15",
        "30",
        "Study",
    };

    try s.create(allocator, &args);
    std.debug.print("Creating a half completed progress bar: \n", .{});
    printProgressBar(io, 5, 10, 20);
}

const std = @import("std");
const PanicWriter = @import("PanicWriter.zig");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
const IOHandle = @import("main.zig").IOHandle;
const output_formatter = @import("main.zig").center_format_string;
const output_width = @import("main.zig").output_buffer_size;
