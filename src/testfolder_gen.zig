//! program to ensure folder structure for tests on disk
const std = @import("std");
const process = std.process;
const stdout = std.io.getStdOut();
const log = std.log;
const mem = std.mem;
const Barr = std.BoundedArray;
// 1. base_perf
// each folder has either 0 or 10 subfolders
// tree structure: last nesting level has 0 folders, others have 10 folders
// nice combinatorics
// - 1. root folders name with 0..9
// - 2. children of root folder prefixed by 0..9, so 00 01 .. 09 are children of 0,
//      10 11 .. 19 are children of 1

// 2. control_sequences
// 0x00..0x31 and 0x7F

// 3. bad_patterns
// ' filename', 'filename ', '~filename', '-filename', 'f1 -f2'

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

// assume: nesting < 10
fn addEnsurePathDir(path_buf: []u8, n_pbuf: *u64, nr: u8, nesting: *u8) !void {
    const slash: u8 = '/';
    const char_of_dig = std.fmt.digitToChar(nr, std.fmt.Case.lower);
    const str_nr: []const u8 = &[2]u8{ slash, char_of_dig };
    mem.copy(u8, path_buf[n_pbuf.*..], str_nr);
    n_pbuf.* += str_nr.len;
    try ensureDir(path_buf[0..n_pbuf.*]);
    std.debug.print("addEnsurePathDir\n", .{});
    std.debug.print("path_buf: {s}\n", .{path_buf[0..n_pbuf.*]});
    std.debug.print("write insert_nr: {d}\n", .{nr});
    nesting.* += 1;
}

// does not remove direcories, only removes `/number` of the path
fn rmPathDir(n_pbuf: *u64, nesting: *u8) void {
    n_pbuf.* -= 2;
    nesting.* -= 1;
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
        //.access_sub_paths = true,
        //.iterate = true,
        .no_follow = true,
    });
    defer test_dir.close();
    //std.debug.print("arg: {s}\n", .{args[1]});
    //std.debug.print("len(args[1]): {d}\n", .{args[1].len});
    //std.debug.print("len(path_buffer): {d}\n", .{path_buffer.len});

    // 1.1 base perf
    // TODO reuse custom number system,
    // because we need to store where what number overlfowed
    {
        mem.copy(u8, path_buffer[n_pbuf..], args[1]);
        n_pbuf += args[1].len;
        const path1: []const u8 = "/base_perf";
        mem.copy(u8, path_buffer[n_pbuf..], path1);
        n_pbuf += path1.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path1.len;
        //{
        //// custom number system backed by buffer
        ////var cust_nr = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        //var cust_nr = [_]u8{ 0, 0, 0, 0, 0}; // 100_000
        //const base: u32 = 10;
        //var nesting: u8 = 0;
        //    var i: u8 = 0;
        //    while (i < 5) : (i += 1) {
        //        try addEnsurePathDir(&path_buffer, &n_pbuf, 0, &nesting);
        //    }
        //    while(add(u8, &cust_nr, base)) {
        //        std.debug.print("test123\n");
        //    }
        //}
        // adjust numbers
        // 0 1 2 3 4..
        // path0/path1/path2..
    }
    std.debug.print("base_perf_path: {s}\n", .{path_buffer[0..n_pbuf]});

    // 1.2 control sequences
    {
        const path2: []const u8 = "/control_sequences";
        mem.copy(u8, path_buffer[n_pbuf..], path2);
        n_pbuf += path2.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path2.len;
    }

    // bad patterns
    {
        const path3: []const u8 = "/bad_patterns";
        mem.copy(u8, path_buffer[n_pbuf..], path3);
        n_pbuf += path3.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path3.len;
    }

    try stdout.writer().print("test creation finished\n", .{});
}
