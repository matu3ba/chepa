const std = @import("std");
const main = @import("main.zig");
const fs = std.fs;
const testing = std.testing;
const mem = std.mem;
fn printErrorSet(comptime fun: anytype) void {
    const info = @typeInfo(@TypeOf(fun));
    const ret_type = info.Fn.return_type.?;
    inline for (@typeInfo(@typeInfo(ret_type).ErrorUnion.error_set).ErrorSet.?) |reterror| {
        std.debug.print("{s}\n", .{reterror.name});
    }
}
test "printErrors" {
    printErrorSet(main.main);
}

//pub fn main() void {
//    main2() catch |err| {
//        switch (err) {
//            else => fatal("error: {s}", .{@errorName(err)}),
//        }
//    };
//}

//const ReturnError = error{
//    ControlChars,
//    UnportableChars,
//};

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
