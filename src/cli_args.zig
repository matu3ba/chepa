//! Experimental argument handling dealing with completion+validation and
//! the things before the main logic starts.
const std = @import("std");
const main = @import("main.zig");
const fs = std.fs;
const mem = std.mem;

const Mode = main.Mode;
const stdout = std.io.getStdOut();
const stderr = std.io.getStdErr();
const process = std.process;

const usage: []const u8 =
    \\ [mode] [options] path1 [path2 ..]
    \\ mode:
    \\ 1.                 cli mode for visual inspection (default cap to 30 lines)
    \\ 2. -c              check if good (return status 0 or bad with status 1)
    \\ 3. -outfile file   write output to file instead to stdout
    \\ options:
    \\ -a                 ascii mode for performance (default is utf8 mode)
    \\
    \\ Shells may not show control characters correctly or misbehave,
    \\ so they are only written (with exception of \n occurence) to files.
    \\ '0x00' (0) is not representable.
    \\ UTF-8 is only checked to contain valid codepoints.
;

const Context = enum {
    /// Only validation of arguments
    Check,
    /// Also execution of arguments
    Exec,
};

/// Dumb word completer based on input arguments
/// (the repl/shell/editor applies it)
/// Caller owns completion suggestions, if any.
// fn dumbWordComplArg(word: [:0]u8, mode_in: Mode) ![:0]u8 {
//     var mode: Mode = mode_in; // default execution mode
//     // TODO completion with travistaloch comptime trie
//
//     while (i < args.len) : (i += 1) {
//         if (mem.eql(u8, args[i], "-outfile")) {
//             mode = switch (mode) {
//                 Mode.ShellOutput => Mode.FileOutput,
//                 Mode.ShellOutputAscii => Mode.FileOutputAscii,
//                 else => return error.InvalidArgument,
//             };
//             if (i + 1 >= args.len) return error.InvalidArgument;
//             i += 1;
//         }
//         if (mem.eql(u8, args[i], "-c")) {
//             mode = switch (mode) {
//                 Mode.ShellOutput => Mode.CheckOnly,
//                 Mode.ShellOutputAscii => Mode.CheckOnlyAscii,
//                 else => return error.InvalidArgument,
//             };
//         }
//         if (mem.eql(u8, args[i], "-a")) {
//             mode = switch (mode) {
//                 Mode.ShellOutput => Mode.ShellOutputAscii,
//                 Mode.CheckOnly => Mode.CheckOnlyAscii,
//                 Mode.FileOutput => Mode.FileOutputAscii,
//                 else => return error.InvalidArgument,
//             };
//         }
//     }
//     return mode;
// }

/// Simple syntax based completion suggestions (CS) with complete args
/// (the repl/shell/editor applies it)
/// No suggestions, if 1. timeout, 2. too many CS
/// Caller owns completion suggestions, if any.
fn dumbStatelessComplArgs() ![:0]u8 {}

/// Stateful expansion suggestions based on past input logic with complete args
/// (the repl/shell/editor applies it)
/// Caller owns completion suggestions, if any.
fn smartStatelessComplArgs() ![:0]u8 {}

/// Simple syntax based completion suggestions (CS)
/// (the repl/shell/editor applies it)
/// No suggestions, if 1. timeout, 2. too many CS
/// Caller owns completion suggestions, if any.
fn dumbStatefulComplArgs() ![:0]u8 {}

/// Stateful expansion suggestions based on past input
/// (the repl/shell/editor applies it)
/// Caller owns completion suggestions, if any.
fn smartStatefulComplArgs() ![:0]u8 {}

// never returns Mode, but an error to bubble up to main
fn cleanup(write_file: *?fs.File) !Mode {
    if (write_file.* != null) {
        write_file.*.?.close();
    }
    return error.InvalidArgument;
}

/// Check input arguments for correctness and stop early.
/// TODO: How to ensure process.exit is never used as return status of zig error codes?
pub fn validateArgs(args: [][:0]u8, write_file_in: *?fs.File, mode_in: Mode) !Mode {
    var mode: Mode = mode_in; // default execution mode
    var write_file: *?fs.File = write_file_in;
    if (args.len <= 1) {
        try stdout.writer().print("Usage: {s} {s}\n", .{ args[0], usage });
        process.exit(1);
    }
    if (args.len >= 255) {
        try stdout.writer().writeAll("At maximum 255 arguments are supported\n");
        process.exit(1);
    }
    var i: u64 = 1; // skip program name
    while (i < args.len) : (i += 1) {
        if (mem.eql(u8, args[i], "-outfile")) {
            mode = switch (mode) {
                Mode.ShellOutput => Mode.FileOutput,
                Mode.ShellOutputAscii => Mode.FileOutputAscii,
                else => try cleanup(write_file),
            };
            if (i + 1 >= args.len) {
                return error.InvalidArgument;
            }
            i += 1;
            write_file.* = try fs.cwd().createFile(args[i], .{});
        }
        if (mem.eql(u8, args[i], "-c")) {
            mode = switch (mode) {
                Mode.ShellOutput => Mode.CheckOnly,
                Mode.ShellOutputAscii => Mode.CheckOnlyAscii,
                else => try cleanup(write_file),
            };
        }
        if (mem.eql(u8, args[i], "-a")) {
            mode = switch (mode) {
                Mode.ShellOutput => Mode.ShellOutputAscii,
                Mode.CheckOnly => Mode.CheckOnlyAscii,
                Mode.FileOutput => Mode.FileOutputAscii,
                else => try cleanup(write_file),
            };
        }
    }
    return mode;
}
