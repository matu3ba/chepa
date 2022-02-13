const builtin = @import("builtin");
const std = @import("std");
const ascii = std.ascii;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const process = std.process;
const stdout = std.io.getStdOut();

const usage: []const u8 =
    \\ path1 [path2 ..]
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

pub fn main() !void {
    // 1. read path names from cli args
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args: [][:0]u8 = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
    if (args.len <= 1) {
        try stdout.writer().print("Usage: {s} {s}\n", .{ args[0], usage });
    }
    // 2. recursively check children of each given path
    // * output sanitized for ascii escape sequences on default
    // * output usable in vim and shell
    var found_ctrlchars = false;
    var i: u64 = 1; // skip program name
    while (i < args.len) : (i += 1) {
        // perf of POSIX/Linux nftw, Rust walkdir and find are comparable.
        // zig libstd offers higher perf for less convenience with optimizations
        // see https://github.com/romkatv/gitstatus/blob/master/docs/listdir.md

        const root_path = args[i];
        {
            // ensure that super path does not contain any
            // control characters, that might get printed later
            const realpath = try fs.realpathAlloc(arena, root_path);
            defer arena.free(realpath);
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
                    for (entry) |char| {
                        if (ascii.isCntrl(char))
                            has_ctrlchars = true;
                    }
                    if (has_ctrlchars) {
                        found_ctrlchars = true;
                        try stdout.writeAll("realpath of '");
                        try stdout.writeAll(root_path);
                        try stdout.writeAll("' has control characters in its absolute path \n");
                    } else {
                        try stdout.writeAll("'");
                        try stdout.writeAll(realpath);
                        try stdout.writeAll("' has non-portable ascii symbols\n");
                    }
                    std.process.exit(1);
                }
            }
        }

        log.debug("reading (recursively) file '{s}'", .{root_path});
        var root_dir = fs.cwd().openDir(root_path, .{ .iterate = true }) catch |err| {
            fatal("unable to open root directory '{s}': {s}", .{
                root_path, @errorName(err),
            });
        };
        defer root_dir.close();

        var walker = try root_dir.walk(arena);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            const basename = entry.basename;
            if (basename.len == 0 or isFilenamePortAscii(basename) == false) {
                var has_ctrlchars = false;
                for (basename) |char| {
                    if (ascii.isCntrl(char))
                        has_ctrlchars = true;
                }

                // perf: do we have the handle with `walker` and can then
                // use or implement anything along `cwd().realpathAlloc('..')` ?
                const super_dir: []const u8 = &[_]u8{fs.path.sep} ++ "..";
                const p_sup_dir = try mem.concat(arena, u8, &.{ entry.path, super_dir });
                defer arena.free(p_sup_dir);
                const rl_sup_dir = try fs.realpathAlloc(arena, p_sup_dir);
                defer arena.free(rl_sup_dir);

                if (has_ctrlchars) {
                    found_ctrlchars = true;
                    // root folder is without control characters or terminate
                    // program would have been terminated
                    try stdout.writeAll("'");
                    try stdout.writeAll(rl_sup_dir);
                    try stdout.writeAll("' has subfolder with control characters\n");
                } else {
                    try stdout.writeAll("'");
                    try stdout.writeAll(entry.path);
                    try stdout.writeAll("' has non-portable ascii symbols\n");
                }
            }
        }
    }
    if (found_ctrlchars) {
        try stdout.writeAll("WARNING: Do __NOT__ use the shell to inspect control characters");
        try stdout.writeAll("Use a (graphical) file manager or tool to remove or rename them");
    }
}
