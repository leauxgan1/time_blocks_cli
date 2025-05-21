// pub fn p(out_buf: anytype, comptime msg: []const u8, args: anytype) !void {
//     try out_buf.writer().print(msg, args);
//     try out_buf.flush();
// }

pub fn collect(allocator: std.mem.Allocator, comptime T: type, iterator: anytype) ![]T {
    var list = std.ArrayListUnmanaged(T){};
    while (iterator.next()) |val| {
        try list.append(allocator, val);
    }
    return list.toOwnedSlice(allocator);
}

pub fn inhibitSleep(allocator: std.mem.Allocator) !void {
    if (builtin.os.tag == .windows) {
        _ = SetThreadExecutionState(.{
            .ES_CONTINUOUS = true,
            .ES_DISPLAY_REQUIRED = true,
        });
    } else {
        const argv = if (builtin.os.tag == .macos) {
            &[_][]const u8{ "caffeinate", "-d" };
        } else if (builtin.os.tag == .linux) {
            &[_][]const u8{ "xdg-screensaver", "reset" };
        } else {
            &[_][]const u8{ "echo", "Unsupported operating system detected" };
        };
        var child = std.process.Child.init(argv, allocator);
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        try child.spawn();
        _ = try child.wait();
    }
}

const std = @import("std");
const builtin = @import("builtin");

// Windows API declarations
const WINAPI = std.os.windows.WINAPI;
const DWORD = std.os.windows.DWORD;
const EXECUTION_STATE = enum(DWORD) {
    ES_CONTINUOUS = 0x80000000,
    ES_SYSTEM_REQUIRED = 0x00000001,
    ES_DISPLAY_REQUIRED = 0x00000002,
    // Add other flags if needed
};

extern "kernel32" fn SetThreadExecutionState(esFlags: EXECUTION_STATE) callconv(WINAPI) EXECUTION_STATE;
