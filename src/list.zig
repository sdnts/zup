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

pub fn init(config: Config, state: *State, args: [][:0]const u8) !void {
    if (args.len == 0) {
        try list(config, state, .all);
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.mem.eql(u8, args[0], "master")) {
        try list(config, state, .master);
    } else if (std.mem.eql(u8, args[0], "stable")) {
        try list(config, state, .stable);
    } else {
        const stderr = std.io.getStdErr();
        try help();
        try stderr.writeAll("\x1B[38;5;9mUnknown option: ");
        try stderr.writeAll(args[0]);
        try stderr.writeAll("\x1B[38;5;0m\n\n");
    }
}

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Usage:
        \\  zup list [channel]
        \\
        \\Channels: 
        \\  all (default)   List all downloaded master versions
        \\  master          List all downloaded master versions
        \\  stable          List all downloaded stable versions
        \\
        \\Options: 
        \\  -h, --help      Print command-specific usage
        \\
        \\Examples:
        \\  zup list
        \\  zup list stable
        \\
        \\
    );
}

fn list(config: Config, state: *State, channel: Channel) !void {
    log.debug("Listing downloaded versions for channel {s}", .{@tagName(channel)});
    log.info("Install location: {s}\n", .{config.root_path});

    var root = try std.fs.openDirAbsolute(config.root_path, .{});
    defer root.close();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stdout = bw.writer().any();

    if (state.versions.items.len == 0) {
        try stdout.writeAll("No installed versions");
    }

    std.mem.sort(State.Versions, state.versions.items, .{}, versionOrderFn);
    for (state.versions.items) |v| {
        try stdout.print("{s}\n", .{v.zig});
        try stdout.print("  └─ Zig: {s}\n", .{v.zig});
        try stdout.print("  └─ ZLS: {s}\n", .{v.zls});
    }
    try stdout.writeAll("\n");

    try bw.flush();
}

fn versionOrderFn(_: @TypeOf(.{}), lhs: State.Versions, rhs: State.Versions) bool {
    const order = std.SemanticVersion.order(
        std.SemanticVersion.parse(lhs.zig) catch unreachable,
        std.SemanticVersion.parse(rhs.zig) catch unreachable,
    );
    return order.compare(.lt);
}
