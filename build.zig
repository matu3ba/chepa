const std = @import("std");
const main = @import("src/main.zig");
const Mode = main.Mode;

const Testdata = struct {
    mode: Mode,
    dirpath: []const u8,
    exp_exit_code: u8,
};
// 0123, 3 only with file output, 01 only with check
const Testcases = [_]Testdata{
    // TODO utf8 control sequences, deprecated characters
    // => question: how to write the test cases?
    // TODO pipe stdout
    Testdata{ .mode = .CheckOnly, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x02", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x03", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x04", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x05", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x06", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x07", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x08", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x09", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x1c", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x1d", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x1e", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x1f", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/f_\x20", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnly, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 1 },

    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 1 },
    Testdata{ .mode = .CheckOnlyAscii, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 1 },

    Testdata{ .mode = .ShellOutput, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = .ShellOutput, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 2 },

    Testdata{ .mode = .ShellOutputAscii, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = .ShellOutputAscii, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 2 },

    Testdata{ .mode = .FileOutput, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/ctrl_seq_nonewline/", .exp_exit_code = 2 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = .FileOutput, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 3 },

    Testdata{ .mode = .FileOutputAscii, .dirpath = "zig-out/", .exp_exit_code = 0 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/-fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/--fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/~fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/ fname", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/fname ", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/fname1 -fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/bad_patterns/fname1 ~fname2", .exp_exit_code = 1 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/ctrl_seq_nonewline/", .exp_exit_code = 2 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/control_sequences/f_\x01", .exp_exit_code = 2 },
    Testdata{ .mode = .FileOutputAscii, .dirpath = "test_dirs/control_sequences/", .exp_exit_code = 3 },
};

fn createTests(b: *std.Build, exe: *std.Build.Step.Compile, dep_step: *std.Build.Step) [Testcases.len]*std.Build.Step.Run {
    const tcases = Testcases;
    // idea: parallel test execution?
    //var prev_test_case: ?*std.build.RunStep = null;
    var test_cases: [Testcases.len]*std.Build.Step.Run = undefined;
    for (tcases, 0..) |_, i| {
        test_cases[i] = b.addRunArtifact(exe); // *RunStep
        test_cases[i].expectExitCode(tcases[i].exp_exit_code);
        test_cases[i].step.dependOn(dep_step);
        //        if (prev_test_case != null)
        //            test_cases[i].step.dependOn(&(prev_test_case.?.step));
        //
        const inttest_arg = b.pathJoin(&.{ b.build_root.path.?, tcases[i].dirpath });
        test_cases[i].addArgs(&.{inttest_arg});
        switch (tcases[i].mode) {
            Mode.CheckOnly => test_cases[i].addArgs(&.{"-c"}),
            Mode.CheckOnlyAscii => test_cases[i].addArgs(&.{ "-a", "-c" }),
            Mode.FileOutput => {
                // multiple executables write same file
                const tmpfile_path = b.pathJoin(&.{ b.build_root.path.?, "zig-cache/tmp/inttest.txt" });
                test_cases[i].addArgs(&.{ "-outfile", tmpfile_path });
            },
            Mode.FileOutputAscii => {
                // multiple executables write same file
                const tmpfile_path = b.pathJoin(&.{ b.build_root.path.?, "zig-cache/tmp/inttest.txt" });
                test_cases[i].addArgs(&.{ "-a", "-outfile", tmpfile_path });
            },
            Mode.ShellOutput => {},
            Mode.ShellOutputAscii => test_cases[i].addArgs(&.{"-a"}),
        }
        //prev_test_case = test_cases[i];
    }
    return test_cases;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // install
    const exe = b.addExecutable(.{
        .name = "chepa",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args|
        run_cmd.addArgs(args);
    const run_cmd_step = b.step("run", "Run the app");
    run_cmd_step.dependOn(&run_cmd.step);

    // unit tests
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    // build and run binary to create test dirs
    const tfgen = b.addExecutable(.{
        .name = "tfgen",
        .root_source_file = .{ .path = "src/testdir_gen.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tfgen);
    const run_tfgen = b.addRunArtifact(tfgen); // integration test generation
    run_tfgen.step.dependOn(b.getInstallStep());
    const tfgen_arg = b.pathJoin(&.{ b.build_root.path.?, "test_dirs" });
    run_tfgen.addArgs(&.{tfgen_arg});
    const run_tfgen_step = b.step("tfgen", "Test dirs generation");
    run_tfgen_step.dependOn(&run_tfgen.step); // integration test generation

    const run_inttest_step = b.step("inttest", "Run integration tests");
    const testdata = createTests(b, exe, run_tfgen_step);
    // idea: how to enumerate test sequences?

    // workaround https://github.com/ziglang/zig/issues/14734
    var i: u64 = 0;
    while (i < testdata.len) : (i += 1) {
        run_inttest_step.dependOn(&testdata[i].step);
    }

    // TODO expand build.zig: StdIoAction limits *make*, which executes *RunStep
    // => requires comptime-selection of string compare function,

    const perfgen = b.addExecutable(.{
        .name = "perfgen",
        .root_source_file = .{ .path = "src/perfdir_gen.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(perfgen);
    const run_perfgen = b.addRunArtifact(perfgen); // perf bench data generationn
    run_perfgen.step.dependOn(b.getInstallStep());
    const perfgen_arg = b.pathJoin(&.{ b.build_root.path.?, "perf_dirs" });
    run_perfgen.addArgs(&.{perfgen_arg});
    const run_perfgen_step = b.step("perfgen", "Perf benchmark dirs generation (requires ~440MB memory)");
    run_perfgen_step.dependOn(&run_perfgen.step); // perf bench data generation

    //idea: check, if hyperfine is installed or build+use a proper c/c++ equivalent
    //hyperfine './zig-out/bin/chepa perf_dirs/ -c' 'fd -j1 "blabla" perf_dirs/'
    //hyperfine './zig-out/bin/chepa perf_dirs/' 'fd -j1 "blabla" perf_dirs/'
    //'./zig-out/bin/chepa perf_dirs/ -c' ran
    //  2.23 ± 0.07 times faster than 'fd -j1 "blabla" perf_dirs/'
    //'./zig-out/bin/chepa perf_dirs/' ran
    //  2.30 ± 0.04 times faster than 'fd -j1 "blabla" perf_dirs/'

    //const run_perfbench = exe.run(); // run perf benchmarks
    //run_perfbench.step.dependOn(run_perfgen_step);
    //const perfbench_arg = b.pathJoin(&.{ b.build_root.path.?, "perf_dirs" });
    //run_perfbench.addArgs(&.{perfbench_arg});
    //const run_perfbench_step = b.step("inttest", "Run integration tests");
    //run_perfbench_step.dependOn(&run_perfbench.step); // run perf benchmarks
}
