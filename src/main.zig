const std = @import("std");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    const a = GPA.allocator();
    defer std.debug.assert(GPA.deinit() == std.heap.Check.ok);

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);
}

test "test" {
    std.testing.refAllDecls(@This());
}
