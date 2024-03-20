const std = @import("std");
const Config = @import("main.zig").Config;
const log = @import("main.zig").log;
const Self = @This();

pub const Versions = struct {
    zig: []const u8,
    zls: []const u8,
};

/// Our CLI will only ever run one command per execution. As such, there's no
/// point in abstracting away the State behind private members and functions.
/// We'll let the rest of our program mutate it freely, and only provide utilities
/// for serializing / deserializing the state to a file for convenience.

// The currently active version of the toolchain
active: ?[]const u8,

// Currently installed versions of the toolchain
versions: std.ArrayListUnmanaged(Versions),

pub fn load(a: std.mem.Allocator, config: Config) !Self {
    log.debug("Loading state file", .{});
    const file = std.fs.openFileAbsolute(
        try std.fs.path.join(a, &.{ config.root_path, "state" }),
        .{ .mode = .read_only },
    ) catch |e| switch (e) {
        error.FileNotFound => {
            const versions = try std.ArrayListUnmanaged(Versions).initCapacity(a, 1);
            return Self{ .active = null, .versions = versions };
        },
        else => return e,
    };
    defer file.close();

    var br = std.io.bufferedReader(file.reader());
    const reader = br.reader().any();

    const active = try a.create([26:0]u8); // 25 bytes is the minimum we need to represent a semver.
    var n = try reader.readAll(active);
    if (n < 26) return error.CorruptStatefile; // Maybe "correct" it by resetting the statefile?

    // TODO: This is probably horribly inefficient
    var versions = try std.ArrayListUnmanaged(Versions).initCapacity(a, 5);
    while (true) {
        const zig = try a.create([26:0]u8);
        n = try reader.readAll(zig);
        if (n == 0) break;
        if (n < 26) return error.CorruptStatefile;

        const zls = try a.create([26:0]u8);
        n = try reader.readAll(zls);
        if (n == 0) break;
        if (n < 26) return error.CorruptStatefile;

        try versions.append(a, Versions{ .zig = zig.*[0..25], .zls = zls.*[0..25] });
    }

    return Self{
        .active = if (active.len == 0) null else active.*[0..25],
        .versions = versions,
    };
}

pub fn save(self: *Self, a: std.mem.Allocator, config: Config) !void {
    log.debug("Commiting state .{{ .active = {?s}, .versions = {} }}", .{ self.active, self.versions });
    const path = try std.fs.path.join(a, &.{ config.root_path, "state" });
    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer().any();

    if (self.active) |active| try writeSemver(writer, active) else try writer.writeByteNTimes(0, 26);

    for (self.versions.items) |v| {
        try writeSemver(writer, v.zig);
        try writeSemver(writer, v.zls);
    }
    try bw.flush();
}

fn writeSemver(writer: std.io.AnyWriter, semver: []const u8) !void {
    try writer.writeAll(semver);
    if (semver.len < 25) try writer.writeByteNTimes(0, 25 - semver.len);
    try writer.writeByte(0);
}
