const std = @import("std");
const Zup = @import("zup.zig");
const Install = @import("install.zig");
const List = @import("list.zig");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    const a = GPA.allocator();
    defer std.debug.assert(GPA.deinit() == std.heap.Check.ok);

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();

    if (std.mem.eql(u8, args[1], "install")) {
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
        try stdout.writeAll("Unknown command: ");
        try stderr.writeAll(args[1]);
    }
}

test "test" {
    std.testing.refAllDecls(@This());
}
