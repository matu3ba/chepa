const std = @import("std");
const bld = std.build;
const main = @import("src/main.zig");
const Mode = main.Mode;

const Testdata = struct {
    mode: Mode,
    foldername: []const u8,
    exp_exit_code: u8,
};
// 0123, 3 only with file output, 01 only with check
const Testcases = [_]Testdata{
    Testdata{ .mode = Mode.FileOutput, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/control_sequences/", .exp_exit_code = 2 },
};

fn createTests(b: *bld.Builder, exe: *bld.LibExeObjStep, dep_step: *bld.Step) [Testcases.len]*bld.RunStep {
    var tcases = Testcases;
    _ = tcases;
    var test_cases: [Testcases.len]*std.build.RunStep = undefined;
    for (tcases) |_, i| {
        test_cases[i] = exe.run(); // *RunStep
        test_cases[i].expected_exit_code = tcases[i].exp_exit_code;
        test_cases[i].step.dependOn(dep_step);
        // TODO different build command per mode
        const inttest_arg = b.pathJoin(&.{ b.build_root, tcases[i].foldername });
        test_cases[i].addArgs(&.{inttest_arg});
    }
    return test_cases;
    // TODO special case addArgs with
    //run_inttest.addArgs(&.{ "-outfile", tmpfile_path, inttest_arg });
    //const tmpfile_path = b.pathJoin(&.{ b.build_root, "zig-cache/tmp/inttest.txt" });
}

pub fn build(b: *bld.Builder) void {
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
    const run_tfgen = tfgen.run(); // integration test generation
    run_tfgen.step.dependOn(b.getInstallStep());
    const tfgen_arg = b.pathJoin(&.{ b.build_root, "test_folders" });
    run_tfgen.addArgs(&.{tfgen_arg});
    const run_tfgen_step = b.step("tfgen", "Test folders generation");
    run_tfgen_step.dependOn(&run_tfgen.step); // integration test generation

    const run_inttest_step = b.step("inttest", "Run integration tests");
    const testdata = createTests(b, exe, run_tfgen_step);
    for (testdata) |single_test| {
        run_inttest_step.dependOn(&single_test.step);
    }

    const perfgen = b.addExecutable("perfgen", "src/perffolder_gen.zig");
    perfgen.setTarget(target);
    perfgen.setBuildMode(mode);
    perfgen.install();
    const run_perfgen = perfgen.run(); // perf bench data generation
    run_perfgen.step.dependOn(b.getInstallStep());
    const perfgen_arg = b.pathJoin(&.{ b.build_root, "perf_folders" });
    run_perfgen.addArgs(&.{perfgen_arg});
    const run_perfgen_step = b.step("perfgen", "Perf benchmark folders generation (requires ~440MB memory)");
    run_perfgen_step.dependOn(&run_perfgen.step); // perf bench data generation
    //const run_perfbench = exe.run(); // run perf benchmarks
    //run_perfbench.step.dependOn(run_perfgen_step);
    //const perfbench_arg = b.pathJoin(&.{ b.build_root, "test_folders" });
    //run_perfbench.addArgs(&.{perfbench_arg});
    //const run_perfbench_step = b.step("inttest", "Run integration tests");
    //run_perfbench_step.dependOn(&run_perfbench.step); // run perf benchmarks
}
