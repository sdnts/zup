const std = @import("std");

pub fn help() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Usage:
        \\  zup [command] [options]
        \\
        \\Commands:
        \\  install         Download and install Zig and ZLS versions
        \\  list            List all downloaded Zig and ZLS versions
        \\  uninstall       Delete a specific Zig and ZLS version
        \\  prune           Delete all non-active versions of Zig and ZLS
        \\
        \\Options:
        \\  -v, --version    Print version of Zup
        \\  -h, --help       Print command-specific usage
        \\
        \\
    );
}

pub fn version() !void {
    const stdout = std.io.getStdOut();
    stdout.writeAll("0.1.0") catch unreachable;
}
