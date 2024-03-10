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
        try list(a, config, .all);
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.mem.eql(u8, args[0], "--master")) {
        try list(a, config, .master);
    } else if (std.mem.eql(u8, args[0], "--stable")) {
        try list(a, config, .stable);
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
        \\  zup list [options]
        \\
        \\Options: 
        \\  all (default)   List all downloaded master versions
        \\  master          List all downloaded master versions
        \\  stable          List all downloaded stable versions
        \\
        \\Examples:
        \\  zig list
        \\  zig list stable
        \\
        \\
    );
}

fn list(a: std.mem.Allocator, config: Config, channel: Channel) !void {
    log.debug("Listing downloaded versions for channel {s}", .{@tagName(channel)});

    var root = try std.fs.openDirAbsolute(config.root_path, .{});
    defer root.close();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stdout = bw.writer().any();

    {
        const path = try std.fs.path.join(a, &.{ "versions", "zig" });
        const dir = try root.makeOpenPath(path, .{});
        try stdout.print("Zig:\n", .{});
        try versions(a, stdout, dir);
    }
    {
        const path = try std.fs.path.join(a, &.{ "versions", "zls" });
        const dir = try root.makeOpenPath(path, .{});
        try stdout.print("ZLS:\n", .{});
        try versions(a, stdout, dir);
    }
    try bw.flush();
}

fn versions(a: std.mem.Allocator, writer: std.io.AnyWriter, dir: std.fs.Dir) !void {
    var dir_entries = std.ArrayList(std.SemanticVersion).init(a);

    var iter = dir.iterate();
    while (try iter.next()) |e| {
        const version = std.SemanticVersion.parse(e.name) catch continue;
        try dir_entries.append(version);
    }

    const entries = try dir_entries.toOwnedSlice();
    std.mem.sort(std.SemanticVersion, entries, .{}, sematicVersionLessThanFn);

    for (entries) |e| try writer.print("\t{any}\n", .{e});
    try writer.print("\n", .{});
}

fn sematicVersionLessThanFn(_: @TypeOf(.{}), lhs: std.SemanticVersion, rhs: std.SemanticVersion) bool {
    const order = std.SemanticVersion.order(lhs, rhs);
    return order.compare(.gte);
}
