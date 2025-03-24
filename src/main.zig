const ScheduleNode = struct {
    topic: []const u8,
    duration: u64,
};

const Schedule = struct {
    list: std.ArrayListUnmanaged(ScheduleNode),

    const Command = enum {
        set,
        start,
        invalid,
    };

    fn createSchedule(self: *Schedule, allocator: std.mem.Allocator, args: [][]const u8) !void {
        for (1..args.len) |i| {
            const command = std.meta.stringToEnum(Command, args[i]) orelse Command.invalid;
            switch (command) {
                Command.set => {
                    var i_offset: usize = 0;
                    while (true) { // Continually collect pairs of topics and details, ensuring only one is numeric
                        if (i + i_offset >= args.len - 1) {
                            break;
                        }
                        const first = args[i + 1];
                        const second = args[i + 2];

                        const first_int = std.fmt.parseInt(u64, first, 10);
                        if (first_int == error.InvalidCharacter) {
                            const second_int = std.fmt.parseInt(u64, second, 10);
                            if (second_int == error.InvalidCharcter) {
                                std.debug.print("Error Creating Schedule - Received two non-integers\n", .{});
                                break;
                            }
                            try self.list.append(allocator, .{
                                .topic = first,
                                .duration = try second_int,
                            });
                            i_offset += 2;
                        } else {
                            const second_int = std.fmt.parseInt(u64, second, 10);
                            if (second_int == error.InvalidCharcter) {
                                try self.list.append(allocator, .{
                                    .topic = second,
                                    .duration = try first_int,
                                });
                                i_offset += 2;
                            } else {
                                std.debug.print("Error Creating Schedule - Received two integers\n", .{});
                                break;
                            }
                        }
                    }
                },
                Command.start => {},
                Command.invalid => {},
            }
        }
    }
    fn runSchedule(self: *Schedule, audio_player: AudioPlayer) !void {
        var time: u64 = 0;
        for (self.list.items, 0..) |item, idx| {
            for (0..item.duration) |i| {
                std.debug.print("Waiting for {d} in topic {s}\r", .{ item.duration - i, item.topic });
                std.Thread.sleep(1 * std.time.ns_per_s);
                time += 1;
            }
            audio_player.play(idx == self.list.items.len - 1);
        }
    }
};

fn handleDefault(schedule: Schedule) !void {
    try schedule.runSchedule();
}

pub fn main() !void {
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const out_writer = bw.writer();
    //
    // const err_file = std.io.getStdErr().writer();
    // var ew = std.io.bufferedWriter(err_file);
    // var err_writer = ew.writer();

    // const logger = Logger{
    //     .out_buf = &bw,
    //     .out_writer = &out_writer,
    //     .err_buf = &ew,
    //     .err_writer = &err_writer,
    // };

    var da: std.heap.DebugAllocator(.{}) = .{};
    defer _ = da.deinit();
    const allocator = da.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const collected_args = try utils.collect(allocator, []const u8, &args);
    defer allocator.free(collected_args);

    var schedule: Schedule = .{
        .list = .{},
    };
    try schedule.createSchedule(allocator, collected_args);
    defer schedule.list.deinit(allocator);

    var audio_player: AudioPlayer = try .init();
    try audio_player.load("beep.wav");
    defer audio_player.deinit();

    try schedule.runSchedule(audio_player);
}

const std = @import("std");
const utils = @import("utils.zig");
const AudioPlayer = @import("AudioPlayer.zig");
