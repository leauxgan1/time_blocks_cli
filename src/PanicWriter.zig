file: std.fs.File,

pub fn writeAll(self: PanicWriter, bytes: []const u8) error{}!void {
    self.file.writeAll(bytes) catch |err| {
        std.process.fatal("write failed: {s}", .{@errorName(err)});
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
        std.process.fatal("fmt failed: {s}", .{@errorName(err)});
    };
}

// Required for `std.fmt.format` to work (implements `std.io.Writer`)
pub const Error = error{};
pub fn write(self: PanicWriter, bytes: []const u8) Error!usize {
    try self.writeAll(bytes);
    return bytes.len;
}

const std = @import("std");
const PanicWriter = @This();
