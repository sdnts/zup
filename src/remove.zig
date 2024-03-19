const std = @import("std");
const builtin = @import("builtin");
const Config = @import("main.zig").Config;
const log = @import("main.zig").log;

const Channel = enum {
    master,
    stable,
    all,
};

pub fn init(a: std.mem.Allocator, config: Config, args: [][:0]const u8) !void {
    if (args.len == 0) {
        const stderr = std.io.getStdErr();
        try help();
        try stderr.writeAll("\x1B[38;5;9merror: A version is required");
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.SemanticVersion.parse(args[0]) catch null) |_| {
        try remove(a, config, args[0]);
    } else {
        const stderr = std.io.getStdErr();
        try help();
        try stderr.writeAll("\x1B[38;5;9merror: Unknown version: ");
        try stderr.writeAll(args[0]);
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    }
}

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Usage:
        \\  zup remove [version]
        \\
        \\Options: 
        \\  -h, --help
        \\
        \\Examples:
        \\  zup remove 0.11.0
        \\  zup remove 0.12.0-dev.2990+31763d28c
        \\
        \\
    );
}

fn remove(a: std.mem.Allocator, config: Config, version: [:0]const u8) !void {
    log.info("Removing Zig v{s}", .{version});

    var root = try std.fs.openDirAbsolute(config.root_path, .{});
    defer root.close();

    // TODO: check if active
    // TODO: check which version of ZLS was installed and remove it as well

    const path = try std.fs.path.join(a, &.{ "versions", "zig", version });
    try root.deleteTree(path);
}
