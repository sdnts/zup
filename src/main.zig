const std = @import("std");
const builtin = @import("builtin");
const Palette = @import("palette.zig");
const State = @import("state.zig");
const Zup = @import("zup.zig");
const List = @import("list.zig");
const Install = @import("install.zig");
const Remove = @import("remove.zig");
const Prune = @import("prune.zig");

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
        .root_path = std.posix.getenv("ZUP_PREFIX") orelse try std.fs.path.join(a, &.{
            switch (builtin.os.tag) {
                .macos => std.posix.getenv("HOME").?,
                .linux => std.posix.getenv("HOME").?,
                else => @compileError("unimplemented"),
            },
            ".zup",
        }),
    };
    log.debug("Config root path: {s}", .{config.root_path});

    var state = try State.load(a, config);

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();

    if (args.len == 1) {
        try Zup.help();
        try Palette.red(stderr, "error: Missing command\n\n");
    } else if (std.mem.eql(u8, args[1], "list")) {
        try List.init(config, &state, args[2..]);
    } else if (std.mem.eql(u8, args[1], "install")) {
        try Install.init(a, config, &state, args[2..]);
    } else if (std.mem.eql(u8, args[1], "remove") or std.mem.eql(u8, args[1], "uninstall")) {
        try Remove.init(a, config, &state, args[2..]);
    } else if (std.mem.eql(u8, args[1], "prune")) {
        try Prune.init(a, config, &state, args[2..]);
    } else if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-v")) {
        try Zup.version();
    } else if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        try stdout.writeAll("Zup is a Zig toolchain manager\n\n");
        try Zup.help();
    } else {
        try Zup.help();
        try Palette.red(stderr, "error: Unknown command: ");
        try Palette.red(stderr, args[1]);
        try Palette.red(stderr, "\n\n");
    }

    try state.save(a, config);
}
