const std = @import("std");
const builtin = @import("builtin");
const log = @import("main.zig").log;

const Channel = enum {
    master,
    stable,
    all,
};

pub fn init(a: std.mem.Allocator, args: [][:0]const u8) !void {
    if (args.len == 0) {
        try list(a, .all);
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.mem.eql(u8, args[0], "--master")) {
        try list(a, .master);
    } else if (std.mem.eql(u8, args[0], "--stable")) {
        try list(a, .stable);
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
        \\  --master    List all downloaded master versions
        \\  --stable    List all downloaded stable versions
        \\
        \\Examples:
        \\  zig list
        \\  zig list --stable
        \\
        \\
    );
}

fn list(a: std.mem.Allocator, channel: Channel) !void {
    log.debug("Listing downloaded versions for channel {s}", .{@tagName(channel)});

    const home = switch (builtin.os.tag) {
        .macos => std.os.getenv("HOME").?,
        .linux => std.os.getenv("HOME").?,
        else => @compileError("unimplemented"),
    };

    const root_path = std.os.getenv("ZUP_PREFIX") orelse try std.fs.path.join(a, &.{ home, ".zup" });
    var root = try std.fs.openDirAbsolute(root_path, .{});
    defer root.close();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    var stdout = bw.writer();

    {
        const path = try std.fs.path.join(a, &.{ "versions", "zig" });
        const dir = try root.makeOpenPath(path, .{});
        var iter = dir.iterate();

        try stdout.print("Zig:\n", .{});
        while (try iter.next()) |e| {
            const version = std.SemanticVersion.parse(e.name) catch continue;
            try stdout.print("\t{any}\n", .{version});
        }
        try stdout.print("\n", .{});
    }
    {
        const path = try std.fs.path.join(a, &.{ "versions", "zls" });
        const dir = try root.makeOpenPath(path, .{});
        var iter = dir.iterate();

        try stdout.print("ZLS:\n", .{});
        while (try iter.next()) |e| {
            const version = std.SemanticVersion.parse(e.name) catch continue;
            try stdout.print("\t{any}\n", .{version});
        }
        try stdout.print("\n", .{});
    }

    try bw.flush();
}
