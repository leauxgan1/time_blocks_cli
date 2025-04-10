time: @Vector(3, u64) = .{ 0, 0, 0 }, // Organized as hours,minutes,and then seconds

const TimeFormat = @This();
/// Input must consist of only numbers and colon symbols
/// Any other symbols invalidate this parsing step and result in an error
pub fn parse(s: []const u8) !TimeFormat {
    const BUFFER_MAX_SIZE = 3;
    // Assumes valid format for time format
    var iter = std.mem.splitScalar(u8, s, ':');
    var arg_buffer: [BUFFER_MAX_SIZE][]const u8 = undefined;
    var num_args: usize = 0;
    for (0..3) |_| {
        const next = iter.next();
        if (next) |val| {
            arg_buffer[num_args] = val;
            num_args += 1;
        } else {
            break;
        }
    }
    if (iter.next() != null) {
        std.log.err("Invalid number of arguments for duration of time block", .{});
        return error.InvalidTimeFormat;
    }
    var formatted = TimeFormat{};
    switch (num_args) {
        1 => { // Only have seconds
            const seconds_int = try std.fmt.parseInt(u32, arg_buffer[0], 10);
            formatted.time[2] = seconds_int;
        },
        2 => { // Have minutes and seconds
            const minutes_int = try std.fmt.parseInt(u32, arg_buffer[0], 10);
            formatted.time[1] = minutes_int;
            const seconds_int = try std.fmt.parseInt(u32, arg_buffer[1], 10);
            formatted.time[2] = seconds_int;
        },
        3 => { // Have hours, minutes, and seconds
            const hours_int = try std.fmt.parseInt(u32, arg_buffer[0], 10);
            formatted.time[0] = hours_int;
            const minutes_int = try std.fmt.parseInt(u32, arg_buffer[1], 10);
            formatted.time[1] = minutes_int;
            const seconds_int = try std.fmt.parseInt(u32, arg_buffer[2], 10);
            formatted.time[2] = seconds_int;
        },
        else => {},
    }

    return formatted;
}
pub inline fn hours(self: TimeFormat) u64 {
    return self.time[0];
}
pub inline fn minutes(self: TimeFormat) u64 {
    return self.time[1];
}
pub inline fn seconds(self: TimeFormat) u64 {
    return self.time[2];
}
pub inline fn toNanoseconds(self: TimeFormat) u64 {
    return std.time.ns_per_hour * self.hours() + std.time.ns_per_min * self.minutes() + std.time.ns_per_s * self.seconds();
}
pub inline fn toSeconds(self: TimeFormat) u64 {
    return std.time.s_per_hour * self.hours() + std.time.s_per_min * self.minutes() + self.seconds();
}
pub fn format(
    self: TimeFormat,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    try writer.print("{d}:{d}:{d}", .{ self.time[0], self.time[1], self.time[2] });
}

test "Correct conversion of TimeFormat" {
    const myFormat = TimeFormat{
        .time = .{ 3, 5, 11 },
    };
    try std.testing.expectEqual(myFormat.toSeconds(), 11111);
    // std.debug.assert(myFormat.toNanoseconds() == 300000000000);
}
test "Parsing time format from string" {
    const myFormat: TimeFormat = try TimeFormat.parse("03:05:11");
    std.log.debug("format parsed: {any}\n", .{myFormat});
    const expected = TimeFormat{
        .time = .{ 3, 5, 11 },
    };
    try std.testing.expectEqual(expected.hours, myFormat.hours);
    try std.testing.expectEqual(expected.minutes, myFormat.minutes);
    try std.testing.expectEqual(expected.seconds, myFormat.seconds);
}

const std = @import("std");
