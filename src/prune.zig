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

pub fn init(a: std.mem.Allocator, config: Config, state: *State, args: [][:0]const u8) !void {
    if (args.len == 0) {
        try prune(a, config, state);
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else {
        const stderr = std.io.getStdErr();
        try Palette.red(stderr, "\nerror: Unknown option: ");
        try Palette.red(stderr, args[0]);
        try Palette.red(stderr, "\n\n");
        try help();
    }
}

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Delete all non-active versions of Zig and ZLS
        \\
        \\Usage:
        \\  zup prune
        \\
        \\Options: 
        \\  -h, --help      Print command-specific usage
        \\
        \\
        \\Examples:
        \\  zup prune
        \\
        \\
    );
}

fn prune(a: std.mem.Allocator, config: Config, state: *State) !void {
    var root = try std.fs.openDirAbsolute(config.root_path, .{});
    defer root.close();

    var versions = try std.ArrayListUnmanaged(State.Versions).initCapacity(a, 1);
    defer {
        state.versions.deinit(a);
        state.versions = versions;
    }

    if (state.active == null) {
        log.info("No active version, pruning all versions", .{});

        const versions_path = try std.fs.path.join(a, &.{"versions"});
        try root.deleteTree(versions_path);

        return;
    }

    const active = state.active.?;
    for (state.versions.items) |v| {
        log.info("Checking Zig {s} {d}", .{ v.zig, v.zig.len });
        if (std.mem.eql(u8, active, v.zig)) {
            try versions.append(a, v);
            continue;
        }

        log.info("Deleting Zig {s}", .{v});

        const zig_path = try std.fs.path.join(a, &.{ "versions", "zig", v.zig });
        try root.deleteTree(zig_path);

        const zls_path = try std.fs.path.join(a, &.{ "versions", "zls", v.zls });
        try root.deleteTree(zls_path);
    }
}
