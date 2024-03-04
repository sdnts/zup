const std = @import("std");
const Zup = @import("zup.zig");
const Install = @import("install.zig");
const List = @import("list.zig");

pub const log = std.log.scoped(.zup);
pub const std_options = .{
    .log_level = if (std.builtin.Mode.Debug) .debug else .info,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    defer arena.deinit();

    const a = arena.allocator();

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();

    if (args.len == 1) {
        try Install.init(a, &.{});
    } else if (std.mem.eql(u8, args[1], "install")) {
        try Install.init(a, args[2..]);
    } else if (std.mem.eql(u8, args[1], "list")) {
        try List.init(args[2..]);
    } else if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-v")) {
        try Zup.version();
    } else if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        try stdout.writeAll("Zup is a Zig toolchain manager\n\n");
        try Zup.help();
    } else {
        try Zup.help();
        try stderr.writeAll("\x1B[38;5;9mUnknown command: ");
        try stderr.writeAll(args[1]);
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    }
}
