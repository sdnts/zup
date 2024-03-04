const std = @import("std");
const builtin = @import("builtin");
const log = @import("main.zig").log;

pub fn init(a: std.mem.Allocator, args: [][:0]const u8) !void {
    if (args.len == 0) {
        try install(a, .master);
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.mem.eql(u8, args[0], "--master")) {
        try install(a, .master);
    } else if (std.mem.eql(u8, args[0], "--stable")) {
        try install(a, .stable);
    }
}

fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Usage:
        \\  zup install [version] [options]
        \\
        \\Options: 
        \\  --master (default)    Download and install latest compatible master versions of Zig and ZLS
        \\  --stable              Download and install latest compatible stable versions of Zig and ZLS
        \\  --latest              Download and install latest versions of Zig and ZLS (skipping compatibility checks)
        \\
        \\Examples:
        \\  zup install
        \\  zup install --stable
        \\  zup install 0.12.0-dev.2990+31763d28c
        \\
        \\
    );
}

const Channel = enum {
    master,
    stable,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .master => try writer.writeAll("master"),
            .stable => try writer.writeAll("stable"),
        }
    }
};

fn install(a: std.mem.Allocator, channel: Channel) !void {
    log.info("Checking for updates on {any}", .{channel});

    const home = switch (builtin.os.tag) {
        .macos => std.os.getenv("HOME").?,
        .linux => std.os.getenv("HOME").?,
        else => @compileError("unimplemented"),
    };

    const root_path = try std.fs.path.join(a, &.{ home, ".zup" });
    // const root_path = try std.fs.getAppDataDir(a, "zup");
    log.debug("Install directory: {s}", .{root_path});
    var root = try std.fs.openDirAbsolute(root_path, .{});
    defer root.close();

    const version = try resolveVersion(a);

    const zig = blk: {
        log.info("Installing Zig v{s}", .{version.zig});
        const path = try std.fs.path.join(a, &.{ "versions", "zig", version.zig });
        const dir = try root.makeOpenPath(path, .{});

        break :blk try std.Thread.spawn(.{}, downloadZig, .{ a, version.zig, dir });
    };

    const zls = blk: {
        log.info("Installing ZLS v{s}", .{version.zls});
        const path = try std.fs.path.join(a, &.{ "versions", "zls", version.zls });
        const dir = try root.makeOpenPath(path, .{});

        break :blk try std.Thread.spawn(.{}, downloadZls, .{ a, version.zls, dir });
    };

    zig.join();
    zls.join();

    _ = try root.makePath("bin");

    {
        const path = try std.fs.path.joinZ(a, &.{ root_path, "bin", "zig" });
        _ = std.c.unlink(path);

        try root.symLink(
            try std.fs.path.join(a, &.{ "versions", "zig", version.zig, "zig" }),
            try std.fs.path.join(a, &.{ "bin", "zig" }),
            .{},
        );
    }
    {
        const path = try std.fs.path.joinZ(a, &.{ root_path, "bin", "zls" });
        _ = std.c.unlink(path);

        try root.symLink(
            // Absolute path needed
            try std.fs.path.join(a, &.{ "versions", "zls", version.zls, "zls" }),
            try std.fs.path.join(a, &.{ "bin", "zls" }),
            .{},
        );
    }
}

const ResolvedVersion = struct {
    zig: []const u8,
    zls: []const u8,
};
fn resolveVersion(a: std.mem.Allocator) !ResolvedVersion {
    var client = std.http.Client{ .allocator = a };
    defer client.deinit();

    var body = std.ArrayList(u8).init(a);

    const result = try client.fetch(.{
        .method = .GET,
        // .location = .{ .url = "https://zigtools-releases.nyc3.digitaloceanspaces.com/zls/index.json" },
        .location = .{ .url = "http://localhost:3000/zls/index.json" },
        .response_storage = .{ .dynamic = &body },
    });

    if (result.status != .ok) return error.UnhealthyUpstream;

    const versions = std.json.parseFromSliceLeaky(
        std.json.Value,
        a,
        try body.toOwnedSlice(),
        .{ .ignore_unknown_fields = true },
    ) catch return error.MalformedPayload;

    const zls = versions.object.get("latest").?.string;
    const zig = versions.object.get("versions").?.object.get(zls).?.object.get("builtWithZigVersion").?.string;
    return ResolvedVersion{ .zig = zig, .zls = zls };
}

fn downloadZls(a: std.mem.Allocator, version: []const u8, dir: std.fs.Dir) !void {
    _ = version;

    var client = std.http.Client{ .allocator = a };
    defer client.deinit();

    const url = try std.Uri.parse("http://localhost:3000/zls");
    const headers = try a.alloc(u8, 4096);
    var request = try client.open(.GET, url, .{
        .version = .@"HTTP/1.1",
        .server_header_buffer = headers,
    });
    defer request.deinit();

    log.debug("Making network request to {s}", .{request.uri});
    try request.send(.{});
    try request.finish();

    try request.wait();
    if (request.response.status != .ok) return error.UnhealthyUpstream;

    const file = try dir.createFile("zls", .{ .truncate = true });
    defer file.close();

    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();
    const reader = request.reader();

    const buf = try a.alloc(u8, 4096);

    while (true) {
        const n = try reader.read(buf);
        if (n == 0) break;

        _ = try writer.write(buf[0..n]);
    }

    try bw.flush();
    try file.chmod(0o0755);
}

fn downloadZig(a: std.mem.Allocator, version: []const u8, dir: std.fs.Dir) !void {
    _ = version;

    var client = std.http.Client{ .allocator = a };
    defer client.deinit();

    const url = try std.Uri.parse("http://localhost:3000/zig");
    const headers = try a.alloc(u8, 4096);
    var request = try client.open(.GET, url, .{
        .version = .@"HTTP/1.1",
        .server_header_buffer = headers,
    });
    defer request.deinit();

    log.debug("Making network request to {s}", .{request.uri});
    try request.send(.{});
    try request.finish();

    try request.wait();
    if (request.response.status != .ok) return error.UnhealthyUpstream;

    // TODO: I hate this implementation. Downloading the archive, then spawning
    // a system command to decompress and extract it is just *yuck*. Zig's tar
    // + xz implementation is quite slow at the moment, so I cannot use that
    // either. Look into implementing the tar + xz spec yourself.

    const file = try dir.createFile("zig.tar.xz", .{ .truncate = true });
    defer file.close();

    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();
    const reader = request.reader();

    const buf = try a.alloc(u8, 4096);

    while (true) {
        const n = try reader.read(buf);
        if (n == 0) break;

        _ = try writer.write(buf[0..n]);
    }

    try bw.flush();

    _ = try std.ChildProcess.run(.{
        .allocator = a,
        .argv = &[_][]const u8{ "tar", "-xf", "zig.tar.xz", "--strip-components=1" },
        .cwd_dir = dir,
        .max_output_bytes = 0,
    });

    try dir.deleteFile("zig.tar.xz");
}
