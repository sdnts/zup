const std = @import("std");
const builtin = @import("builtin");
const Palette = @import("palette.zig");
const Config = @import("main.zig").Config;
const State = @import("state.zig");
const log = @import("main.zig").log;

const Channel = enum {
    master,
    stable,
    all,
};

pub fn init(a: std.mem.Allocator, config: Config, state: *State, args: [][:0]u8) !void {
    if (args.len == 0) {
        const stderr = std.io.getStdErr();
        try Palette.red(stderr, "\nerror: A version is required\n\n");
        try help();
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.SemanticVersion.parse(args[0]) catch null) |v| {
        try remove(a, config, state, v);
    } else {
        const stderr = std.io.getStdErr();
        try Palette.red(stderr, "\nerror: Unknown version: ");
        try Palette.red(stderr, args[0]);
        try Palette.red(stderr, "\n\n");
        try help();
    }
}

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Delete a specific Zig and ZLS version
        \\
        \\Usage:
        \\  zup uninstall [version]
        \\
        \\Versions:
        \\  <zig-semver>    Removes a specific version of Zig, and its version of ZLS
        \\
        \\Options: 
        \\  -h, --help      Print command-specific usage
        \\
        \\
        \\Examples:
        \\  zup uninstall 0.11.0
        \\  zup uninstall 0.12.0-dev.2990+31763d28c
        \\
        \\
    );
}

fn remove(a: std.mem.Allocator, config: Config, state: *State, semver: std.SemanticVersion) !void {
    var version = try State.Version.initCapacity(a, 25);
    try version.writer(a).print("{}", .{semver});

    log.info("Removing Zig {s}", .{version.items});

    if (state.active) |active| {
        if (std.mem.eql(u8, active.items, version.items)) {
            log.err("Refusing to uninstall active version {s}", .{version.items});
            return;
        }
    }

    var stateVersions: ?State.Versions = null;
    var stateVersionIndex: ?usize = null;
    for (state.versions.items, 0..) |v, i| {
        if (std.mem.eql(u8, v.zig.items, version.items)) {
            stateVersions = v;
            stateVersionIndex = i;
            break;
        }
    }

    if (stateVersions) |v| {
        var root = try std.fs.openDirAbsolute(config.root_path, .{});
        defer root.close();

        const zig_path = try std.fs.path.join(a, &.{ "versions", "zig", v.zig.items });
        try root.deleteTree(zig_path);

        const zls_path = try std.fs.path.join(a, &.{ "versions", "zls", v.zls.items });
        try root.deleteTree(zls_path);

        _ = state.versions.swapRemove(stateVersionIndex.?);
    }
}
