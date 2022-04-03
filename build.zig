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
    // TODO utf8 control sequences, deprecated characters
    // => question: how to write the test cases?
    // TODO pipe stdout
    Testdata{ .mode = Mode.CheckOnly, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x02", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x03", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x04", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x05", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x06", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x07", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x08", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x09", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x1c", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x1d", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x1e", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x1f", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/f_\x20", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnly, .foldername = "test_folders/control_sequences/", .exp_exit_code = 1 },

    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.CheckOnlyAscii, .foldername = "test_folders/control_sequences/", .exp_exit_code = 1 },

    Testdata{ .mode = Mode.ShellOutput, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.ShellOutput, .foldername = "test_folders/control_sequences/", .exp_exit_code = 2 },

    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.ShellOutputAscii, .foldername = "test_folders/control_sequences/", .exp_exit_code = 2 },

    Testdata{ .mode = Mode.FileOutput, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/ctrl_seq_nonewline/", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.FileOutput, .foldername = "test_folders/control_sequences/", .exp_exit_code = 3 },

    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/ctrl_seq_nonewline/", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = Mode.FileOutputAscii, .foldername = "test_folders/control_sequences/", .exp_exit_code = 3 },
};

fn createTests(b: *bld.Builder, exe: *bld.LibExeObjStep, dep_step: *bld.Step) [Testcases.len]*bld.RunStep {
    var tcases = Testcases;
    _ = tcases;
    // idea: parallel test execution?
    //var prev_test_case: ?*std.build.RunStep = null;
    var test_cases: [Testcases.len]*std.build.RunStep = undefined;
    for (tcases) |_, i| {
        test_cases[i] = exe.run(); // *RunStep
        test_cases[i].expected_exit_code = tcases[i].exp_exit_code;
        test_cases[i].step.dependOn(dep_step);
        //        if (prev_test_case != null)
        //            test_cases[i].step.dependOn(&(prev_test_case.?.step));
        //
        const inttest_arg = b.pathJoin(&.{ b.build_root, tcases[i].foldername });
        test_cases[i].addArgs(&.{inttest_arg});
        switch (tcases[i].mode) {
            Mode.CheckOnly => test_cases[i].addArgs(&.{"-c"}),
            Mode.CheckOnlyAscii => test_cases[i].addArgs(&.{ "-a", "-c" }),
            Mode.FileOutput => {
                // multiple executables write same file
                const tmpfile_path = b.pathJoin(&.{ b.build_root, "zig-cache/tmp/inttest.txt" });
                test_cases[i].addArgs(&.{ "-outfile", tmpfile_path });
            },
            Mode.FileOutputAscii => {
                // multiple executables write same file
                const tmpfile_path = b.pathJoin(&.{ b.build_root, "zig-cache/tmp/inttest.txt" });
                test_cases[i].addArgs(&.{ "-a", "-outfile", tmpfile_path });
            },
            Mode.ShellOutput => {},
            Mode.ShellOutputAscii => test_cases[i].addArgs(&.{"-a"}),
        }
        //prev_test_case = test_cases[i];
    }
    return test_cases;
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
    // idea: how to enumerate test sequences?
    for (testdata) |single_test| {
        run_inttest_step.dependOn(&single_test.step);
    }

    // TODO expand build.zig: StdIoAction limits *make*, which executes *RunStep
    // => requires comptime-selection of string compare function,

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

    //idea: check, if hyperfine is installed or build+use a proper c/c++ equivalent
    //hyperfine './zig-out/bin/chepa perf_folders/ -c' 'fd -j1 "blabla" perf_folders/'
    //hyperfine './zig-out/bin/chepa perf_folders/' 'fd -j1 "blabla" perf_folders/'
    //'./zig-out/bin/chepa perf_folders/ -c' ran
    //  2.23 ± 0.07 times faster than 'fd -j1 "blabla" perf_folders/'
    //'./zig-out/bin/chepa perf_folders/' ran
    //  2.30 ± 0.04 times faster than 'fd -j1 "blabla" perf_folders/'

    //const run_perfbench = exe.run(); // run perf benchmarks
    //run_perfbench.step.dependOn(run_perfgen_step);
    //const perfbench_arg = b.pathJoin(&.{ b.build_root, "perf_folders" });
    //run_perfbench.addArgs(&.{perfbench_arg});
    //const run_perfbench_step = b.step("inttest", "Run integration tests");
    //run_perfbench_step.dependOn(&run_perfbench.step); // run perf benchmarks
}
