const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zup",
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const watchexec = b.addSystemCommand(&.{"watchexec"});
    watchexec.addArgs(&.{
        "-q",
        "-c",
        "-e",
        "zig,zon",
        "-i",
        "zig-cache/**",
        "-i",
        "zig-out/**",
        "zig",
        "build",
        "run",
        "--",
        // "install",
        "list",
        // "remove",
    });
    watchexec.step.dependOn(b.getInstallStep());

    const watch = b.step("watch", "(Re)build and run app when source changes");
    watch.dependOn(&watchexec.step);
}
