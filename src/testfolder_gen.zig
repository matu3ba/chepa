//! program to ensure folder structure for tests on disk
const std = @import("std");
const Barr = std.BoundedArray;
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const os = std.os;
const process = std.process;
const stdout = std.io.getStdOut();

// 1. ensure test_folders existence
// 2. control_sequences 0x00..0x31 and 0x7F
// 3. bad_patterns like ' filename', 'filename ', '~filename', '-filename', 'f1 -f2'

const usage: []const u8 =
    \\ path
;

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(2);
}

fn ensureDir(path: []const u8) !void {
    //std.debug.print("path: {s}\n", .{path});
    std.fs.cwd().makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            fatal("unable to create test directory '{s}': {s}", .{
                path, @errorName(err),
            });
        },
    };
}

// -------------- move above parts into testhelper.zig --------------

fn ensureFile(path: []const u8) !void {
    var file = std.fs.cwd().createFile(path, .{
        .read = true,
    }) catch |err| switch (err) {
        error.PathAlreadyExists => {
            return; // TODO open file to ensure things work correctly
        },
        else => {
            fatal("unable to create test file '{s}': {s}", .{
                path, @errorName(err),
            });
        },
    };
    defer file.close();
    const stat = try file.stat();
    if (stat.kind != .File)
        fatal("stat on test file '{s}' failed", .{path});
}

pub fn main() !void {
    var path_buffer: [1000]u8 = undefined;
    var n_pbuf: u64 = 0; // next free position
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args: [][:0]u8 = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
    for (args) |arg| {
        std.debug.print("{s}\n", .{arg});
    }
    if (args.len != 2) {
        try stdout.writer().print("To create test at path, run in shell: {s} {s}\n", .{ args[0], usage });
        std.process.exit(1);
    }
    // 1. folders for tests
    try ensureDir(args[1]);
    var test_dir = try std.fs.cwd().openDir(args[1], .{
        .no_follow = true,
    });
    defer test_dir.close();
    mem.copy(u8, path_buffer[n_pbuf..], args[1]);
    n_pbuf += args[1].len;

    // 2. control_sequences (0x00..0x31 and 0x7F)
    // to keep things simple, we create direcories with d_controlsequence
    // and files with f_controlsequences inside folder control_sequences
    {
        const path2: []const u8 = "/control_sequences";
        mem.copy(u8, path_buffer[n_pbuf..], path2);
        n_pbuf += path2.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path2.len;
        {
            // 1. directories
            var tmpbuf = "/d_2".*;
            //tmpbuf[2] = 0x00; // cannot access memory at addres 0x0/null
            tmpbuf[3] = 0x01;
            var i: u8 = 1;
            while (i < 32) : (i += 1) {
                mem.copy(u8, path_buffer[n_pbuf..], tmpbuf[0..]);
                n_pbuf += tmpbuf.len;
                try ensureDir(path_buffer[0..n_pbuf]);
                n_pbuf -= tmpbuf.len;
                tmpbuf[3] = i;
            }
            tmpbuf[3] = 0x7F;
            mem.copy(u8, path_buffer[n_pbuf..], tmpbuf[0..]);
            n_pbuf += tmpbuf.len;
            try ensureDir(path_buffer[0..n_pbuf]);
            n_pbuf -= tmpbuf.len;

            // 2. files
            tmpbuf[1] = 'f'; // f_symbol
            //tmpbuf[2] = 0x00; // cannot access memory at addres 0x0/null
            tmpbuf[3] = 0x01;
            i = 1;
            while (i < 32) : (i += 1) {
                mem.copy(u8, path_buffer[n_pbuf..], tmpbuf[0..]);
                n_pbuf += tmpbuf.len;
                try ensureFile(path_buffer[0..n_pbuf]);
                n_pbuf -= tmpbuf.len;
                tmpbuf[3] = i;
            }
            tmpbuf[3] = 0x7F;
            mem.copy(u8, path_buffer[n_pbuf..], tmpbuf[0..]);
            n_pbuf += tmpbuf.len;
            try ensureFile(path_buffer[0..n_pbuf]);
            n_pbuf -= tmpbuf.len;
        }
    }
    // 3. bad_patterns like ' filename', 'filename ', '~filename', '-filename', 'f1 -f2'
    const bad_patterns = [_][]const u8{
        "/ fname",
        "/fname ",
        "/~fname",
        "/-fname",
        "/--fname",
        "/fname1 ~fname2",
        "/fname1 -fname2",
        "/fname1 --fname2",
        // TODO extend this list
        // TODO think of bad patterns in utf8
    };
    {
        const path3: []const u8 = "/bad_patterns";
        mem.copy(u8, path_buffer[n_pbuf..], path3);
        n_pbuf += path3.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path3.len;
        {
            for (bad_patterns) |pattern| {
                mem.copy(u8, path_buffer[n_pbuf..], pattern[0..]);
                n_pbuf += pattern.len;
                try ensureDir(path_buffer[0..n_pbuf]);
                n_pbuf -= pattern.len;
            }
        }
    }

    try stdout.writer().print("test creation finished\n", .{});
}

test "use of realpath instead of realpathAlloc" {
    // to be called after running `zig test tfgen`
    // realpath utilizes the cwd() of the current process (undocumented in libstd)
    const path_name: []const u8 = "test_folders/bad_patterns/ fname/.."; // adding \x00 breaks things
    var out_buf: [4096]u8 = undefined;
    const real_path = try os.realpath(path_name, &out_buf); // works
    std.debug.print("real_path: {s}\n", .{real_path});
}

// TODO test cases with escaped path delimiter, ie blabla\/blabla
