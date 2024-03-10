const std = @import("std");
const builtin = @import("builtin");
const log = @import("main.zig").log;

const hosts = .{
    .zig = if (builtin.mode == .Debug) "http://localhost:8000" else "https://ziglang.org",
    .zls = if (builtin.mode == .Debug) "http://localhost:9000" else "https://zigtools-releases.nyc3.digitaloceanspaces.com",
};

const VersionSpec = union(enum) {
    master: void,
    stable: void,
    semver: std.SemanticVersion,
};

pub fn init(a: std.mem.Allocator, args: [][]const u8) !void {
    if (args.len == 0) {
        try install(a, .{ .master = {} });
    } else if (std.mem.eql(u8, args[0], "-h") or std.mem.eql(u8, args[0], "--help")) {
        try help();
    } else if (std.mem.eql(u8, args[0], "master")) {
        try install(a, .{ .master = {} });
    } else if (std.mem.eql(u8, args[0], "stable")) {
        try install(a, .{ .stable = {} });
    } else if (std.SemanticVersion.parse(args[0]) catch null) |v| {
        try install(a, .{ .semver = v });
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
        \\Download and install a compatible set of Zig and ZLS.
        \\
        \\Usage:
        \\  zup install [version] [options]
        \\
        \\Versions:
        \\  master (default)      Install latest compatible master versions of Zig and ZLS
        \\  stable                Install latest compatible stable versions of Zig and ZLS
        \\  <zig-semver>          Install a specific version of Zig, and a compatible version of ZLS
        \\
        \\Options: 
        \\  -h, --help
        \\
        \\Examples:
        \\  zup install
        \\  zup install stable
        \\  zup install 0.12.0-dev.2990+31763d28c
        \\
        \\
    );
}

fn install(a: std.mem.Allocator, version: VersionSpec) !void {
    switch (version) {
        .semver => {},
        else => log.info("Checking for updates on {s}", .{@tagName(version)}),
    }

    log.debug("Resolving versions: {any}", .{version});

    const versions = blk: {
        const zig = try Zig.resolve(a, version);
        var v_zig = try std.ArrayList(u8).initCapacity(a, 25);
        try zig.format("", .{}, v_zig.writer());

        const zls = try Zls.resolve(a, zig);
        var v_zls = try std.ArrayList(u8).initCapacity(a, 25);
        try zls.format("", .{}, v_zls.writer());

        break :blk .{
            .zig = try v_zig.toOwnedSlice(),
            .zls = try v_zls.toOwnedSlice(),
        };
    };
    log.debug("Resolved versions:\n\tZig: {s}\n\tZLS: {s}", .{ versions.zig, versions.zls });

    const home = switch (builtin.os.tag) {
        .macos => std.os.getenv("HOME").?,
        .linux => std.os.getenv("HOME").?,
        else => @compileError("unimplemented"),
    };

    const root_path = std.os.getenv("ZUP_PREFIX") orelse try std.fs.path.join(a, &.{ home, ".zup" });
    var root = try std.fs.openDirAbsolute(root_path, .{});
    defer root.close();

    log.debug("Install directory: {s}", .{root_path});

    const zig = blk: {
        log.info("Installing Zig v{s}", .{versions.zig});
        const path = try std.fs.path.join(a, &.{ "versions", "zig", versions.zig });
        const dir = try root.makeOpenPath(path, .{});
        break :blk try std.Thread.spawn(.{}, Zig.download, .{ a, versions.zig, dir });
    };

    const zls = blk: {
        log.info("Installing ZLS v{s}", .{versions.zls});
        const path = try std.fs.path.join(a, &.{ "versions", "zls", versions.zls });
        const dir = try root.makeOpenPath(path, .{});
        break :blk try std.Thread.spawn(.{}, Zls.download, .{ a, versions.zls, dir });
    };

    zig.join();
    zls.join();

    try root.makePath("bin");

    {
        const path = try std.fs.path.joinZ(a, &.{ root_path, "bin", "zig" });
        _ = std.c.unlink(path);

        try root.symLink(
            try std.fs.path.join(a, &.{ root_path, "versions", "zig", versions.zig, "zig" }),
            try std.fs.path.join(a, &.{ "bin", "zig" }),
            .{},
        );
    }
    {
        const path = try std.fs.path.joinZ(a, &.{ root_path, "bin", "zls" });
        _ = std.c.unlink(path);

        try root.symLink(
            try std.fs.path.join(a, &.{ root_path, "versions", "zls", versions.zls, "zls" }),
            try std.fs.path.join(a, &.{ "bin", "zls" }),
            .{},
        );
    }
}

const Zig = struct {
    fn resolve(a: std.mem.Allocator, spec: VersionSpec) !std.SemanticVersion {
        switch (spec) {
            .semver => |s| return s,
            else => {},
        }

        var client = std.http.Client{ .allocator = a };
        defer client.deinit();

        log.debug("Fetching Zig versions", .{});

        var body = std.ArrayList(u8).init(a);
        const response = try client.fetch(.{
            .method = .GET,
            .location = .{ .url = hosts.zig ++ "/download/index.json" },
            .response_storage = .{ .dynamic = &body },
        });

        if (response.status != .ok) return error.UnhealthyZigIndexUpstream;

        const versions = std.json.parseFromSliceLeaky(
            std.json.Value,
            a,
            try body.toOwnedSlice(),
            .{},
        ) catch return error.MalformedZigIndexPayload;

        switch (versions) {
            .object => {},
            else => return error.MalformedZigIndexPayload,
        }

        switch (spec) {
            .semver => unreachable,
            .master => {
                const master = versions.object.get("master") orelse return error.MalformedZigIndexPayload;
                switch (master) {
                    .object => {},
                    else => return error.MalformedZigIndexPayload,
                }

                const version = master.object.get("version") orelse return error.MalformedZigIndexPayload;
                switch (version) {
                    .string => {},
                    else => return error.MalformedZigIndexPayload,
                }

                return std.SemanticVersion.parse(version.string);
            },
            .stable => {
                // Looping over the array ourselves instead of using std.sort.max
                // allows us to minimize the number of `.parse`s and allocations
                var vmax: ?std.SemanticVersion = null;
                for (versions.object.keys()) |v| {
                    if (std.mem.eql(u8, v, "master")) continue;

                    const semver = std.SemanticVersion.parse(v) catch return error.MalformedZigSemVer;
                    if (vmax == null or semver.order(vmax.?) == .gt) vmax = semver;
                }
                return vmax orelse error.NoZigVersionMatch;
            },
        }
    }

    fn download(a: std.mem.Allocator, version: []const u8, dir: std.fs.Dir) !void {
        var client = std.http.Client{ .allocator = a };
        defer client.deinit();

        const url = try std.Uri.parse(try std.mem.concat(a, u8, &.{
            hosts.zig,
            "/builds/zig-",
            @tagName(builtin.os.tag),
            "-",
            @tagName(builtin.cpu.arch),
            "-",
            version,
            ".tar.xz",
        }));
        const headers = try a.alloc(u8, 1024);
        var request = try client.open(.GET, url, .{
            .version = .@"HTTP/1.1",
            .server_header_buffer = headers,
        });
        defer request.deinit();

        log.debug("Sending request to {s} {s}", .{ request.uri.host.?, request.uri.path });
        try request.send(.{});
        try request.finish();

        try request.wait();
        if (request.response.status != .ok) return error.UnhealthyUpstream;

        var br = std.io.bufferedReader(request.reader());
        const reader = br.reader();

        // TODO: I hate this implementation. Downloading the archive, then spawning
        // a system command to decompress and extract it is just *yuck*. Zig's tar
        // + xz implementation is quite slow at the moment, so I cannot use that
        // either. Look into implementing the tar + xz spec yourself.

        const file = try dir.createFile("zig.tar.xz", .{ .truncate = true });
        defer file.close();
        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();

        const buf = try a.alloc(u8, 4096);
        while (true) {
            const n = try reader.read(buf);
            if (n == 0) break;
            try writer.writeAll(buf[0..n]);
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
};

const Zls = struct {
    fn resolve(a: std.mem.Allocator, zig: std.SemanticVersion) !std.SemanticVersion {
        var client = std.http.Client{ .allocator = a };
        defer client.deinit();

        log.debug("Fetching ZLS versions", .{});

        var body = std.ArrayList(u8).init(a);
        const response = try client.fetch(.{
            .method = .GET,
            .location = .{ .url = hosts.zls ++ "/zls/index.json" },
            .response_storage = .{ .dynamic = &body },
        });

        if (response.status != .ok) return error.UnhealthyZlsIndexUpstream;

        const parsed = std.json.parseFromSliceLeaky(
            std.json.Value,
            a,
            try body.toOwnedSlice(),
            .{},
        ) catch return error.MalformedZlsPayload;

        switch (parsed) {
            .object => {},
            else => return error.MalformedZlsIndexPayload,
        }

        const versions = parsed.object.get("versions") orelse return error.MalformedZlsIndexPayload;
        switch (versions) {
            .object => {},
            else => return error.MalformedZlsIndexPayload,
        }

        // Looping over the array ourselves instead of using std.sort.max
        // allows us to minimize the number of `.parse`s and allocations
        var vmax: ?std.SemanticVersion = null;
        for (versions.object.values()) |v| {
            // Remember that we intend to find the highest ZLS version with a "minimum
            // required Zig version" < provided Zig version
            switch (v) {
                .object => {},
                else => return error.MalformedZlsIndexPayload,
            }

            const min_zig = v.object.get("zlsMinimumBuildVersion") orelse return error.MalformedZlsIndexPayload;
            switch (min_zig) {
                .string => {},
                else => return error.MalformedZlsIndexPayload,
            }
            const min_zig_semver = std.SemanticVersion.parse(min_zig.string) catch return error.MalformedZlsVersion;
            if (min_zig_semver.order(zig) == .gt) continue;

            const zls = v.object.get("zlsVersion") orelse return error.MalformedZlsIndexPayload;
            switch (zls) {
                .string => {},
                else => return error.MalformedZlsIndexPayload,
            }
            const zls_semver = std.SemanticVersion.parse(zls.string) catch return error.MalformedZlsVersion;
            if (vmax == null or zls_semver.order(vmax.?) == .gt) vmax = zls_semver;
        }

        return vmax orelse error.NoZlsVersionMatch;
    }

    fn download(a: std.mem.Allocator, version: []const u8, dir: std.fs.Dir) !void {
        var client = std.http.Client{ .allocator = a };
        defer client.deinit();

        const url = try std.Uri.parse(
            try std.mem.concat(a, u8, &.{
                hosts.zls,
                "/zls/",
                version,
                "/",
                @tagName(builtin.cpu.arch),
                "-",
                @tagName(builtin.os.tag),
                "/zls",
            }),
        );
        const headers = try a.alloc(u8, 1024);
        var request = try client.open(.GET, url, .{
            .version = .@"HTTP/1.1",
            .server_header_buffer = headers,
        });
        defer request.deinit();

        log.debug("Sending request to {s} {s}", .{ request.uri.host.?, request.uri.path });
        try request.send(.{});
        try request.finish();

        try request.wait();
        if (request.response.status != .ok) return error.UnhealthyUpstream;

        var br = std.io.bufferedReader(request.reader());
        const reader = br.reader();

        const file = try dir.createFile("zls", .{ .truncate = true });
        defer file.close();
        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();

        const buf = try a.alloc(u8, 4096);
        while (true) {
            const n = try reader.read(buf);
            if (n == 0) break;
            try writer.writeAll(buf[0..n]);
        }

        try bw.flush();
        try file.chmod(0o0755);
    }
};
