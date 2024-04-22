const std = @import("std");
const builtin = @import("builtin");
const Config = @import("main.zig").Config;
const State = @import("state.zig");
const log = @import("main.zig").log;

const Channel = enum {
    master,
    stable,
    all,
};

pub fn init(a: std.mem.Allocator, config: Config, state: *State, args: [][:0]const u8) !void {
    if (args.len == 0) {
        const stderr = std.io.getStdErr();
        try help();
        try stderr.writeAll("\x1B[38;5;9merror: A version is required");
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.SemanticVersion.parse(args[0]) catch null) |_| {
        try remove(a, config, state, args[0]);
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
        \\Versions:
        \\  <zig-semver>    Removes a specific version of Zig, and its version of ZLS
        \\
        \\Options: 
        \\  -h, --help      Print command-specific usage
        \\
        \\
        \\Examples:
        \\  zup remove 0.11.0
        \\  zup remove 0.12.0-dev.2990+31763d28c
        \\
        \\
    );
}

fn remove(a: std.mem.Allocator, config: Config, state: *State, version: [:0]const u8) !void {
    log.info("Removing Zig {s}", .{version});

    if (state.active) |active| {
        if (std.mem.eql(u8, active, version)) {
            log.err("Refusing to remove active version {s}", .{version});
            return;
        }
    }

    var root = try std.fs.openDirAbsolute(config.root_path, .{});
    defer root.close();

    var stateVersions: ?State.Versions = null;
    for (state.versions.items) |v| {
        if (std.mem.eql(u8, v.zig, version)) {
            stateVersions = v;
            break;
        }
    }

    if (stateVersions) |v| {
        const zig_path = try std.fs.path.join(a, &.{ "versions", "zig", v.zig });
        try root.deleteTree(zig_path);

        const zls_path = try std.fs.path.join(a, &.{ "versions", "zls", v.zls });
        try root.deleteTree(zls_path);
    }
}
