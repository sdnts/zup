const std = @import("std");

pub fn init(args: [][:0]const u8) !void {
    _ = args;
    try help();
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

fn list() !void {}
