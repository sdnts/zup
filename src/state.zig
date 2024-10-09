/// Our CLI will only ever run one command per execution. As such, there's no
/// point in abstracting away the State behind private members and functions.
/// We'll let the rest of our program mutate it freely, and only provide utilities
/// for serializing / deserializing the state to a file for convenience.
const std = @import("std");
const Config = @import("main.zig").Config;
const log = @import("main.zig").log;
const Self = @This();

pub const Version = std.ArrayListUnmanaged(u8);

pub const Versions = struct {
    zig: Version,
    zls: Version,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{{ .zig = {s}, .zls = {s} }}", .{ self.zig.items, self.zls.items });
    }
};

// The currently active version of the toolchain
active: ?Version,

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
    var reader = std.json.reader(a, br.reader());

    var state = try std.json.parseFromTokenSource(@This(), a, &reader, .{ .ignore_unknown_fields = true });
    if (state.value.versions.items.len == 0) {
        // Maybe I'm misunderstanding things, but when `versions` is an empty
        // list in the state file, `parseFromTokenSource` does not seem to initialize
        // an empty ArrayList, instead it leaves state.versions uninitialized.
        // This later causes problems when we try to interact with it, because
        // accessing uninitialized memory throws SIGSEVs.
        // To avoid this, we'll manually initialize `versions`.
        state.value.versions = try std.ArrayListUnmanaged(Versions).initCapacity(a, 1);
    }

    log.debug("Parsed state file: {{ .active = {s}, .versions = {s} }}", .{ if (state.value.active == null) "null" else state.value.active.?.items, state.value.versions.items });
    return state.value;
}

pub fn save(self: *Self, a: std.mem.Allocator, config: Config) !void {
    log.debug("Committing state .{{ .active = {s}, .versions = {s} }}", .{ if (self.active == null) "null" else self.active.?.items, self.versions.items });
    const path = try std.fs.path.join(a, &.{ config.root_path, "state" });
    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    var bw = std.io.bufferedWriter(file.writer());

    const writer = bw.writer().any();
    try std.json.stringify(self, .{}, writer);

    try bw.flush();
}
