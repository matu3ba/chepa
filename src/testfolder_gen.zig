//! program to ensure folder structure for tests on disk
const std = @import("std");
const process = std.process;
const log = std.log;
const mem = std.mem;
const Barr = std.BoundedArray;
const stdout = std.io.getStdOut();
const fmt = std.fmt;
// 1. base_perf
// each folder has either 0 or 10 subfolders
// tree structure: last nesting level has 0 folders, others have 10 folders
// nice combinatorics
// - 1. root folders name with 0..9
// - 2. children of root folder prefixed by 0..9, so 00 01 .. 09 are children of 0,
//      10 11 .. 19 are children of 1

// 2. control_sequences 0x00..0x31 and 0x7F

// 3. bad_patterns ' filename', 'filename ', '~filename', '-filename', 'f1 -f2'

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
    const char_of_dig = fmt.digitToChar(nr, fmt.Case.lower);
    const str_nr: []const u8 = &[2]u8{ slash, char_of_dig };
    mem.copy(u8, path_buf[n_pbuf.*..], str_nr);
    n_pbuf.* += str_nr.len;
    try ensureDir(path_buf[0..n_pbuf.*]);
    //std.debug.print("addEnsurePathDir\n", .{});
    //std.debug.print("path_buf: {s}\n", .{path_buf[0..n_pbuf.*]});
    //std.debug.print("write insert_nr: {d}\n", .{nr});
    nesting.* += 1;
}

// does not remove direcories, only removes `/number` of the path
fn rmPathDir(n_pbuf: *u64, nesting: *u8) void {
    n_pbuf.* -= 2;
    nesting.* -= 1;
    //std.debug.print("rm dir\n", .{});
}

// on successfull addition return true, otherwise false
fn add(comptime UT: type, cust_nr: []UT, base: UT, path_buf: []u8, n_pbuf: *u64, nesting: *u8) bool {
    //std.debug.print("cust_nr: {d} {d} {d}", .{ cust_nr.len, base, nesting.* });
    //return true;
    _ = nesting;
    //std.debug.print("nesting: {d}\n", .{nesting.*});
    var carry = false;
    var index: u64 = cust_nr.len - 1;
    // get first index from right-hand side that can be updated
    while (index > 0) : (index -= 1) {
        var added_val = cust_nr[index] + 1;
        if (added_val == base) {
            carry = true;
        } else {
            break; // defer updating number until overflow check
        }
    }

    // prevent index overflow
    if (index == 0 and carry == true and cust_nr[index] + 1 == base) {
        return false; // could not increase anymore
    }
    cust_nr[index] += 1; // update value

    // logic for directories
    {
        var dir_index: u64 = cust_nr.len - 1;
        std.debug.assert(dir_index >= index);
        std.debug.assert(nesting.* == cust_nr.len);
        // remove directories from path string from end to index
        while (dir_index > index) : (dir_index -= 1)
            rmPathDir(n_pbuf, nesting);
        rmPathDir(n_pbuf, nesting); // also remove dir from index to replace it
        std.debug.assert(dir_index == index);
        //std.debug.print("path_buf before ensureDir: {s}\n", .{path_buf[0..n_pbuf.*]});
        // replacement of dir at index
        try addEnsurePathDir(path_buf, n_pbuf, cust_nr[index], nesting);
        dir_index += 1; // update index after appending dir to point to new dir
        //std.debug.print("nesting after addEnsurePathDir : {d}\n", .{nesting.*});
        //std.debug.print("dir_index : {d}\n", .{dir_index});
        // ensure zero dirs until nesting = cust_nr.len
        while (dir_index < cust_nr.len) : (dir_index += 1)
            try addEnsurePathDir(path_buf, n_pbuf, 0, nesting); // add 0 dirs
        std.debug.assert(nesting.* == cust_nr.len);
    }

    // zero out numbers right of the index
    if (carry == true) {
        std.debug.assert(index < cust_nr.len - 1);
        index += 1;
        while (index < cust_nr.len) : (index += 1) {
            cust_nr[index] = 0;
        }
    }
    return true;
}

// TODO upstream with tests to libstd, but
fn digitsToChars(buf: []u8, case: fmt.Case) void {
    var char: u8 = undefined;
    for (buf) |digit, i| {
        char = fmt.digitToChar(digit, case);
        buf[i] = char;
    }
}

pub fn charsToDigits(buf: []u8, radix: u8) (error{InvalidCharacter}!void) {
    var digit: u8 = undefined;
    for (buf) |char, i| {
        digit = try fmt.charToDigit(char, radix);
        buf[i] = digit;
    }
}

fn printCustomNr(comptime UT: type, cust_nr: []UT) !void {
    try stdout.writeAll("created ");
    const case = fmt.Case.lower;
    digitsToChars(cust_nr, case);
    try stdout.writeAll(cust_nr);
    try charsToDigits(cust_nr, 11); // invalidate digits > 10
    try stdout.writeAll(" +1 direcories\n");
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

    // 1.1 base_perf
    // because we need to store where what number overlfowed
    {
        mem.copy(u8, path_buffer[n_pbuf..], args[1]);
        n_pbuf += args[1].len;
        const path1: []const u8 = "/base_perf";
        mem.copy(u8, path_buffer[n_pbuf..], path1);
        n_pbuf += path1.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path1.len;
        {
            // custom number system backed by buffer
            //var cust_nr = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; 10^{10} == too big
            var cust_nr = [_]u8{ 0, 0, 0, 0, 0 }; // 10^{5} == 100_000
            //var cust_nr = [_]u8{ 0, 0, 0 }; // 10^{3} == 1_000
            //var cust_nr = [_]u8{ 0, 0 }; // 10^{2} == 100 (+10)
            const base: u32 = 10;
            var nesting: u8 = 0;
            var i: u64 = 0;
            while (i < cust_nr.len) : (i += 1) {
                try addEnsurePathDir(&path_buffer, &n_pbuf, 0, &nesting);
            }
            // cust_nr now represents the ensured path structure
            i = 0;
            while (add(u8, &cust_nr, base, &path_buffer, &n_pbuf, &nesting)) {
                //std.debug.print("i: {d}\n", .{i});
                //printCustomNr(u8, &cust_nr);
                i += 1;
                std.debug.assert(i < 1_000_000);
            }
            try printCustomNr(u8, &cust_nr);
            i = 0;
            while (i < cust_nr.len) : (i += 1) {
                rmPathDir(&n_pbuf, &nesting);
            }
            std.debug.assert(n_pbuf == args[1].len + path1.len);
            std.debug.assert(nesting == 0);
        }
    }
    std.debug.print("base_perf_path: {s}\n", .{path_buffer[0..n_pbuf]});

    // 1.2 control_sequences
    {
        const path2: []const u8 = "/control_sequences";
        mem.copy(u8, path_buffer[n_pbuf..], path2);
        n_pbuf += path2.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path2.len;
    }

    // bad_patterns
    {
        const path3: []const u8 = "/bad_patterns";
        mem.copy(u8, path_buffer[n_pbuf..], path3);
        n_pbuf += path3.len;
        try ensureDir(path_buffer[0..n_pbuf]);
        defer n_pbuf -= path3.len;
    }

    try stdout.writer().print("test creation finished\n", .{});
}
