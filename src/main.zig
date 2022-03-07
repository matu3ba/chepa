const builtin = @import("builtin");
const std = @import("std");
const ascii = std.ascii;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const os = std.os;
const process = std.process;
const stdout = std.io.getStdOut();
const stderr = std.io.getStdErr();

const testing = std.testing;

const usage: []const u8 =
    \\ [options] path1 [path2 ..]
    \\ options:
    \\ -outfile file    write output to file instead to stdout
    \\ Shells may not show control characters correctly or misbehave.
    \\ '0x00' (0) is not representable.
;

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(1);
}

const CheckError = error{
    ControlCharacter,
    Antipattern,
    NonPortable,
};

// assume: path.len > 0
fn isFilenameSaneUtf8(path: []u8) CheckError!void {
    try stdout.writeAll("path:\n");
    var visited_space: bool = true;

    // leading and trailing space
    if (path[0] == ' ') return error.Antipattern;
    if (path[path.len - 1] == ' ') return error.Antipattern;

    for (path) |char| {
        if (ascii.isCntrl(char)) return error.ControlCharacter;

        // TODO utf8
        // dashes or hyphen after space
        if (visited_space and (char == '-' or char == '~')) return error.Antipattern;
        if (char == ' ') {
            visited_space = true;
        } else {
            visited_space = false;
        }

        // comma and newline
        if (char == ',') return error.Antipattern;
        if (char == '\n') return error.Antipattern;
    }
    try stdout.writeAll("\n");
}

// POSIX portable file name character set
fn isCharPosixPortable(char: u8) bool {
    // 0-9
    if (0x30 <= char and char <= 0x39)
        return true;
    // a-z
    if (0x41 <= char and char <= 0x5A)
        return true;
    // A-Z
    if (0x61 <= char and char <= 0x7A)
        return true;
    // 2D `-`, 2E `.`, 5F `_`
    if (char == 0x2D or char == 0x2E or char == 0x5F)
        return true;
    return false;
}

// assume: path.len > 0
fn isFilenamePortAscii(path: []const u8) bool {
    for (path) |char| {
        if (isCharPosixPortable(char) == false) return false;
    }
    return true;
}

const Cli = struct {
    write_file: ?std.fs.File = null,
};

// assume: no file `-outfile` exists
// assume: user specifies non-overlapping input paths
pub fn main() !void {
    // 1. read path names from cli args
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args: [][:0]u8 = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
    if (args.len <= 1) {
        try stdout.writer().print("Usage: {s} {s}\n", .{ args[0], usage });
        std.process.exit(1);
    }
    if (args.len >= 255) {
        try stdout.writer().writeAll("At maximum 255 arguments are supported\n");
        std.process.exit(1);
    }

    // tmp data for realpath(), never to be references otherwise
    var tmp_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try process.getCwdAlloc(arena); // windows compatibility
    defer arena.free(cwd);

    var cli = Cli{};

    var i: u64 = 1; // skip program name
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-outfile")) {
            if (i + 1 >= args.len) {
                //stderr.writeAll("invalid argument for '-outfile'\n");
                return error.InvalidArgument;
            }
            i += 1;
            cli.write_file = try std.fs.cwd().createFile(args[i], .{});
        }
    }
    defer if (cli.write_file != null)
        cli.write_file.?.close();

    // 2. recursively check children of each given path
    // * output sanitized for ascii escape sequences and control characters on default
    // * output usable in vim and shell
    var found_ctrlchars = false;
    var found_newline = false;
    i = 1; // skip program name
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-outfile")) { // skip -outfile + filename
            i += 1;
            continue;
        }
        // perf of POSIX/Linux nftw, Rust walkdir and find are comparable.
        // zig libstd offers higher perf for less convenience with optimizations
        // see https://github.com/romkatv/gitstatus/blob/master/docs/listdir.md
        const root_path = args[i];
        {
            // ensure that super path does not contain any
            // control characters, that might get printed later
            const real_path = try os.realpath(root_path, &tmp_buf);
            var it = mem.tokenize(u8, root_path, &[_]u8{fs.path.sep});

            // TODO: test this in CI
            // windows root path?
            const native_os = builtin.target.os.tag;
            switch (native_os) {
                .windows => {
                    if (0x61 <= it.buffer[0] and it.buffer[0] <= 0x7A // A-Z
                    and it.buffer[1] == ':') {
                        it.next();
                    }
                },
                else => {},
            }

            while (it.next()) |entry| {
                if (entry.len == 0 or isFilenamePortAscii(entry) == false) {
                    var has_ctrlchars = false;
                    var has_newline = false;
                    for (entry) |char| {
                        if (ascii.isCntrl(char))
                            has_ctrlchars = true;
                        if (char == '\n')
                            has_newline = true;
                    }
                    if (has_ctrlchars)
                        found_ctrlchars = true;
                    if (has_newline)
                        found_newline = true;
                    if (cli.write_file != null) {
                        if (has_newline) {
                            try cli.write_file.?.writeAll("'");
                            try cli.write_file.?.writeAll(root_path);
                            try cli.write_file.?.writeAll("' newline in absolute HERE\n");
                        } else {
                            try cli.write_file.?.writeAll(real_path);
                            try cli.write_file.?.writeAll("\n");
                        }
                    } else {
                        if (has_ctrlchars) {
                            try stdout.writeAll("subfile of '");
                            try stdout.writeAll(root_path);
                            try stdout.writeAll("' has control characters in its absolute path\n");
                        } else {
                            try stdout.writeAll("'");
                            try stdout.writeAll(real_path);
                            try stdout.writeAll("' has non-portable ascii symbols\n");
                        }
                    }
                    if (cli.write_file != null) cli.write_file.?.close();
                    std.process.exit(1);
                }
            }
        }

        log.debug("reading (recursively) file '{s}'", .{root_path});
        var root_dir = fs.cwd().openDir(root_path, .{ .iterate = true, .no_follow = true }) catch |err| {
            if (cli.write_file != null) cli.write_file.?.close();
            fatal("unable to open root directory '{s}': {s}", .{
                root_path, @errorName(err),
            });
        };
        defer root_dir.close();

        var walker = try root_dir.walk(arena);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            const basename = entry.basename;
            //log.debug("file '{s}'", .{basename}); // fails at either d_\t/\n\r\v\f
            //std.debug.print("basename[2]: {d}\n", .{basename[2]});

            if (basename.len == 0 or isFilenamePortAscii(basename) == false) {
                var has_ctrlchars = false;
                var has_newline = false;
                for (basename) |char| {
                    if (ascii.isCntrl(char))
                        has_ctrlchars = true;
                    if (char == '\n')
                        has_newline = true;
                }
                if (has_ctrlchars)
                    found_ctrlchars = true;
                if (has_newline)
                    found_newline = true;

                const super_dir: []const u8 = &[_]u8{fs.path.sep} ++ "..";
                const p_sup_dir = try mem.concat(arena, u8, &.{ root_path, &[_]u8{fs.path.sep}, entry.path, super_dir });
                defer arena.free(p_sup_dir);
                //std.debug.print("resolvePosix(arena, {s})\n", .{p_sup_dir});
                // `realpath` requires relative path from cwd() of process
                // `realpath` does not work on files with postfixed `..`
                const rl_sup_dir = try fs.path.resolve(arena, &.{p_sup_dir});
                defer arena.free(rl_sup_dir);
                const rl_sup_dir_rel = try fs.path.relative(arena, cwd, rl_sup_dir);
                defer arena.free(rl_sup_dir_rel);
                //std.debug.print("fs.path.resolve result: '{s}'\n", .{rl_sup_dir});
                // root folder is without control characters or terminate
                // program would have been terminated
                if (cli.write_file != null) {
                    if (has_newline) {
                        try cli.write_file.?.writeAll("'");
                        try cli.write_file.?.writeAll(rl_sup_dir_rel);
                        try cli.write_file.?.writeAll("' newline in subfile HERE\n");
                    } else {
                        try cli.write_file.?.writeAll(entry.path);
                        try cli.write_file.?.writeAll("\n");
                    }
                } else {
                    if (has_ctrlchars) {
                        try stdout.writeAll("'");
                        try stdout.writeAll(rl_sup_dir_rel);
                        try stdout.writeAll("' has file with ctrl chars\n");
                    } else {
                        try stdout.writeAll("'");
                        try stdout.writeAll(entry.path);
                        try stdout.writeAll("' has non-portable ascii chars\n");
                    }
                }
            }
        }
        if (found_newline and cli.write_file != null) {
            try stdout.writeAll("found newlines, please manually resolve in output file\n");
        }
    }
}

test "resolvePosix" {
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x01/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x02/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x03/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x04/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x05/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x06/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x07/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x08/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x09/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0a/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0b/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0c/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0d/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0e/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x0f/", ".." }, "/test_folders/control_sequences"); // 15
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x10/", ".." }, "/test_folders/control_sequences"); // 16
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x11/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x12/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x13/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x14/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x15/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x16/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x17/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x18/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x19/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1a/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1b/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1c/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1d/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1e/", ".." }, "/test_folders/control_sequences");
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x1f/", ".." }, "/test_folders/control_sequences"); // 31
    try testResolvePosix(&[_][]const u8{ "/test_folders/control_sequences/\x7f/", ".." }, "/test_folders/control_sequences");
}

fn testResolvePosix(paths: []const []const u8, expected: []const u8) !void {
    const actual = try fs.path.resolvePosix(testing.allocator, paths);
    defer testing.allocator.free(actual);
    try testing.expect(mem.eql(u8, actual, expected));
}
