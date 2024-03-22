const std = @import("std");
const builtin = @import("builtin");
const State = @import("state.zig");
const Zup = @import("zup.zig");
const Install = @import("install.zig");
const List = @import("list.zig");
const Remove = @import("remove.zig");

pub const log = std.log.scoped(.zup);
pub const std_options = .{
    .log_level = if (builtin.mode == .Debug) .debug else .info,
};

pub const Config = struct {
    root_path: []const u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const config = Config{
        .root_path = std.os.getenv("ZUP_PREFIX") orelse try std.fs.path.join(a, &.{
            switch (builtin.os.tag) {
                .macos => std.os.getenv("HOME").?,
                .linux => std.os.getenv("HOME").?,
                else => @compileError("unimplemented"),
            },
            ".zup",
        }),
    };
    log.debug("Resolved config {s}", .{config.root_path});

    var state = try State.load(a, config);

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stderr = std.io.getStdErr();
    const stdout = std.io.getStdOut();

    if (args.len == 1) {
        try Zup.help();
        try stderr.writeAll("\x1B[38;5;9merror: Missing command\x1B[38;5;0m\n\n");
    } else if (std.mem.eql(u8, args[1], "install")) {
        try Install.init(a, config, args[2..]);
    } else if (std.mem.eql(u8, args[1], "list")) {
        try List.init(a, config, args[2..]);
    } else if (std.mem.eql(u8, args[1], "remove") or std.mem.eql(u8, args[1], "uninstall")) {
        try Remove.init(a, config, &state, args[2..]);
    } else if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-v")) {
        try Zup.version();
    } else if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        try stdout.writeAll("Zup is a Zig toolchain manager\n\n");
        try Zup.help();
    } else {
        try Zup.help();
        try stderr.writeAll("\x1B[38;5;9merror: Unknown command: ");
        try stderr.writeAll(args[1]);
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    }

    try state.save(a, config);
}
