const std = @import("std");

pub fn init(a: std.mem.Allocator, args: [][:0]const u8) !void {
    _ = args;
    try install(a);
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

fn install() !void {
    // Find latest Zig version
    // Find latest ZLS version
    //
    // If they do not match, exit
    //
    // Create a ~/.zig/versions/<version> directory
    // Download Zig and ZLS to this directory
    // Extract them in-place
    // Delete tars
    //
    // Copy ~/.zig/bin/zls -> ~/.zig/versions/<version>/zls
    // Copy ~/.zig/bin/zig -> ~/.zig/versions/<version>
}
