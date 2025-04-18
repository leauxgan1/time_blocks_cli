list: std.ArrayListUnmanaged(ScheduleNode),
timer: u64 = 0,
prev_time: u64 = 0,
curr_topic: usize = 0, // Index representing current topic
break_time: TimeFormat = .{},

const Schedule = @This();
const ScheduleNode = struct {
    topic: []const u8,
    duration: TimeFormat,
};

pub const Status = enum {
    InProgress,
    Done,
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
            if (self.break_time.toSeconds() > 0 and i < args.len - 2) {
                try self.list.append(allocator, .{
                    .topic = "Break time...",
                    .duration = self.break_time,
                });
            }
            continue;
        };
        const second_time = TimeFormat.parse(second) catch {
            try self.list.append(allocator, .{
                .topic = second,
                .duration = first_time,
            });
            if (self.break_time.toSeconds() > 0 and i < args.len - 2) {
                try self.list.append(allocator, .{
                    .topic = "Break time...",
                    .duration = self.break_time,
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

pub fn step(self: *Schedule, delta: u64, io: IOHandle, audio_player: AudioPlayer) !Status {
    self.timer += delta;
    const current_topic = self.getTopicIndex();
    if (current_topic) |curr_topic| { // Schedule is continuing, print information about current topic
        if (curr_topic == self.curr_topic + 1) { // Found just entered new topic
            audio_player.play();
            self.curr_topic = curr_topic;
            self.prev_time += self.timer;
            self.timer = 0;
        }
        const current_schedule_item = self.list.items[curr_topic];
        const time_remaining = current_schedule_item.duration.toSeconds() - self.timer / std.time.ns_per_s;
        try io.out.print("\rWaiting in topic {s} for {d} seconds        ", .{ current_schedule_item.topic, time_remaining });
        return .InProgress;
    } else { // Schedule is over, print ending message
        try io.out.print("\rFinished time blocks : >                    \n", .{});
        audio_player.play();
        return .Done;
    }
}
pub fn set_break(self: *Schedule, duration: TimeFormat) void {
    self.break_time = duration;
}

const std = @import("std");
const TimeFormat = @import("TimeFormat.zig");
const AudioPlayer = @import("AudioPlayer.zig");
const IOHandle = @import("main.zig").IOHandle;
