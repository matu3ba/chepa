const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    // install
    const exe = b.addExecutable("chepa", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    // run
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args|
        run_cmd.addArgs(args);
    const run_cmd_step = b.step("run", "Run the app");
    run_cmd_step.dependOn(&run_cmd.step);

    // unit tests
    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    // build and run binary to create test folders
    // stage1: panic from build system, if executable is non-existing
    //const tfgen = b.addExecutable("tfgen", "src/testfolder_gen.zig");
    const tfgen = b.addExecutable("tfgen", "src/testfolder_gen.zig");
    tfgen.setTarget(target);
    tfgen.setBuildMode(mode);
    tfgen.install();

    const run_tfgen = tfgen.run();
    run_tfgen.step.dependOn(b.getInstallStep());
    const tfgen_arg = b.pathJoin(&.{ b.build_root, "test_folders" });
    run_tfgen.addArgs(&.{tfgen_arg});
    const run_tfgen_step = b.step("tfgen", "Test folders generation");
    run_tfgen_step.dependOn(&run_tfgen.step);

    // integration tests
    const run_inttest = exe.run();
    run_inttest.step.dependOn(run_cmd_step);
    run_inttest.step.dependOn(run_tfgen_step);
    const inttest_arg = b.pathJoin(&.{ b.build_root, "test_folders" });
    run_inttest.addArgs(&.{inttest_arg});
    const run_inttest_step = b.step("inttest", "Run integration tests");
    run_inttest_step.dependOn(&run_inttest.step);
}
