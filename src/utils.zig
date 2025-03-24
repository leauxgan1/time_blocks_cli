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

const std = @import("std");
