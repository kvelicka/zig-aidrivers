const std = @import("std");


pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const zgt_exe = b.addExecutable("zgt", "src/zgt-ui.zig");
    {
        zgt_exe.setTarget(target);
        zgt_exe.setBuildMode(mode);
        @import("ext/zgt/build.zig").install(zgt_exe, "ext/zgt") catch std.log.debug("no zgt??", .{});
        zgt_exe.install();
    }

    const stdout_exe = b.addExecutable("stdout", "src/stdout-ui.zig");
    {
        stdout_exe.setTarget(target);
        stdout_exe.setBuildMode(mode);
        stdout_exe.install();
    }

    const headless_exe = b.addExecutable("headless", "src/main.zig");
    {
        headless_exe.setTarget(target);
        headless_exe.setBuildMode(mode);
        headless_exe.install();
    }


    const zgt_run_cmd = zgt_exe.run();
    zgt_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        zgt_run_cmd.addArgs(args);
    }
    const zgt_run_step = b.step("run-zgt", "Run the app, zgt output");
    zgt_run_step.dependOn(&zgt_run_cmd.step);


    const stdout_run_cmd = stdout_exe.run();
    stdout_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        stdout_run_cmd.addArgs(args);
    }
    const stdout_run_step = b.step("run-stdout", "Run the app, stdout output");
    stdout_run_step.dependOn(&stdout_run_cmd.step);

    const headless_run_cmd = headless_exe.run();
    headless_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        headless_run_cmd.addArgs(args);
    }
    const headless_run_step = b.step("run-main", "Run the app, no output (benchmark)");
    headless_run_step.dependOn(&headless_run_cmd.step);
}
