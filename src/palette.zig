const std = @import("std");

pub fn red(stream: std.fs.File, str: []const u8) !void {
    const w = stream.writer();
    try w.print("\x1B[38;5;9m{s}\x1B[38;5;255m", .{str});
}

pub fn white(stream: std.fs.File, str: []const u8) !void {
    const w = stream.writer();
    try w.print("\x1B[38;5;255m{s}", .{str});
}
