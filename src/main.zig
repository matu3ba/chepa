const builtin = @import("builtin");
const std = @import("std");
const ascii = std.ascii;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const os = std.os;
const process = std.process;
const unicode = std.unicode;
const testing = std.testing;

const stdout = std.io.getStdOut();
const stderr = std.io.getStdErr();

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

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    process.exit(1);
}

const CheckError = error{
    ControlCharacter,
    Antipattern,
    NonPortable,
};

// POSIX portable file name character set
fn isCharPosixPortable(char: u8) bool {
    switch (char) {
        0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F => return true, // 0-9, a-z, A-Z, 2D `-`, 2E `.`, 5F `_`
        else => return false,
    }
}

// assume: len(word) > 0
fn isWordSanePosixPortable(word: []const u8) bool {
    if (word[0] == '-') return false;
    for (word) |char| {
        if (isCharPosixPortable(char) == false) return false;
    }
    return true;
}

// assume: len(word) > 0
// assume: word described by /word/word/ and / not part of word
fn isWordOkAscii(word: []const u8) bool {
    var visited_space: bool = false;
    switch (word[0]) {
        '~', '-', ' ' => return false, // leading tilde,dash,empty space
        else => {},
    }
    for (word) |char| {
        switch (char) {
            0...31 => return false, // Cntrl (includes '\n', '\r', '\t')
            ',', '`' => return false,
            '-', '~' => {
                if (visited_space) return false;
                visited_space = false;
            }, // antipattern
            ' ' => {
                visited_space = true;
            },
            127 => return false, // Cntrl
            else => {
                visited_space = false;
            },
        }
    }
    if (visited_space) return false; // ending empty space
    return true;
}

const StatusOkAsciiExt = enum {
    Ok,
    Antipattern,
    CntrlChar,
    Newline,
};

// assume: path.len > 0
fn isWordOkAsciiExtended(word: []const u8) StatusOkAsciiExt {
    var status: StatusOkAsciiExt = StatusOkAsciiExt.Ok;
    var visited_space: bool = false;
    switch (word[0]) {
        '~', '-', ' ' => {
            status = StatusOkAsciiExt.Antipattern;
        }, // leading tilde,dash,empty space
        else => {},
    }
    for (word) |char| {
        switch (char) {
            0...9 => {
                status = StatusOkAsciiExt.CntrlChar;
            }, // Cntrl (includes '\n', '\r', '\t')
            10 => {
                return StatusOkAsciiExt.Newline;
            }, // Line Feed '\n'
            11...31 => {
                status = StatusOkAsciiExt.CntrlChar;
            }, // Cntrl (includes '\n', '\r', '\t')
            ',', '`' => {
                if (status != StatusOkAsciiExt.CntrlChar)
                    status = StatusOkAsciiExt.Antipattern;
            }, // antipattern
            '-', '~' => {
                if (visited_space and status != StatusOkAsciiExt.CntrlChar)
                    status = StatusOkAsciiExt.Antipattern;
            }, // antipattern
            ' ' => {
                visited_space = true;
            },
            127 => {
                status = StatusOkAsciiExt.CntrlChar;
            }, // Cntrl
            else => {
                visited_space = false;
            },
        }
    }

    if (visited_space and status != StatusOkAsciiExt.CntrlChar) {
        return StatusOkAsciiExt.Antipattern;
    } // ending empty space
    return status;
}

inline fn skipItIfWindows(it: *mem.TokenIterator(u8)) void {
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
}

const Encoding = enum {
    Ascii,
    Utf8,
};

// returns success or failure of the check
// assume: correct cwd and args are given
fn checkOnly(comptime enc: Encoding, arena: mem.Allocator, args: [][:0]u8) !u8 {
    var i: u64 = 1; // skip program name
    while (i < args.len) : (i += 1) {
        if (enc == Encoding.Ascii) {
            if (mem.eql(u8, args[i], "-a")) continue; // skip -a
        }
        if (mem.eql(u8, args[i], "-c")) // skip -c
            continue;
        const root_path = args[i];
        var it = mem.tokenize(u8, root_path, &[_]u8{fs.path.sep});
        skipItIfWindows(&it);
        while (it.next()) |entry| {
            std.debug.assert(entry.len > 0);
            switch (enc) {
                Encoding.Ascii => {
                    if (!isWordOkAscii(entry)) return 1;
                },
                Encoding.Utf8 => {
                    if (!isWordOk(entry)) return 1;
                },
            }
        }
        var root_dir = try fs.cwd().openDir(root_path, .{ .iterate = true, .no_follow = true });
        defer root_dir.close();
        var walker = try root_dir.walk(arena);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            const basename = entry.basename;
            std.debug.assert(basename.len > 0);
            switch (enc) {
                Encoding.Ascii => {
                    if (!isWordOkAscii(basename)) return 1;
                },
                Encoding.Utf8 => {
                    if (!isWordOk(basename)) return 1;
                },
            }
        }
    }
    return 0;
}

// assume: len(word) > 0
// assume: path described by /word/word/ and / not part of word
fn isWordOk(word: []const u8) bool {
    var visited_space: bool = false;
    switch (word[0]) {
        '~', '-', ' ' => return false, // leading tilde,dash,empty space
        else => {},
    }
    var utf8 = (unicode.Utf8View.init(word) catch {
        return false;
    }).iterator();
    // TODO do \ escaped characters (some OSes disallow them)
    // TODO Is 1 switch prong in a padded variable faster?
    while (utf8.nextCodepointSlice()) |codepoint| {
        switch (codepoint.len) {
            0 => unreachable,
            1 => {
                const char = codepoint[0]; // U+0000...U+007F
                switch (char) { // perf: how does this get lowered?
                    0...31 => return false, // Cntrl (includes '\n', '\r', '\t')
                    ',', '`' => return false,
                    '-', '~' => {
                        if (visited_space) return false;
                        visited_space = false;
                    }, // antipattern
                    ' ' => {
                        visited_space = true; // TODO FIX THIS!
                    },
                    127 => return false, // Cntrl
                    else => {
                        visited_space = false;
                    },
                }
            },
            2 => {
                const char = mem.bytesAsValue(u16, codepoint[0..2]); // U+0080...U+07FF
                switch (char.*) {
                    128...159 => return false, // Cntrl (includes next line 0x85)
                    160 => return false, // disallowed space: no-break space
                    173 => return false, // soft hyphen
                    else => {
                        visited_space = false;
                    },
                }
            },
            3 => {
                const char = mem.bytesAsValue(u24, codepoint[0..4]); // U+0800...U+FFFF
                switch (char.*) {
                    // disallowed spaces, see README.md
                    0x1680, 0x180e, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004 => return false,
                    0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200a, 0x200b => return false,
                    0x200c, 0x200d, 0x2028, 0x2029, 0x202f, 0x205f, 0x2060 => return false,
                    0x3000, 0xfeff => return false,
                    else => {
                        visited_space = false;
                    },
                }
            },
            4 => {
                visited_space = false; // U+10000...U+10FFFF
            },
            else => unreachable,
        }
        //std.debug.print("got codepoint {s}\n", .{codepoint});
    }
    if (visited_space) return false; // ending empty space
    return true;
}

const StatusOkExt = enum {
    Ok,
    Antipattern,
    CntrlChar,
    Newline,
    InvalUnicode,
};

// return codes: 0 ok, 1 antipattern, 2 cntrl, 3 newline, 4 invalid unicode
// assume: len(word) > 0
// assume: path described by /word/word/ and / not part of word
fn isWordOkExtended(word: []const u8) StatusOkExt {
    var status: StatusOkExt = StatusOkExt.Ok;
    var visited_space: bool = false;
    switch (word[0]) {
        '~', '-', ' ' => {
            status = StatusOkExt.Antipattern;
        }, // leading tilde,dash,empty space
        else => {},
    }

    var utf8 = (unicode.Utf8View.init(word) catch {
        return StatusOkExt.InvalUnicode;
    }).iterator();
    // TODO do \ escaped characters (some OSes disallow them)
    // TODO Is 1 switch prong in a padded variable faster?
    while (utf8.nextCodepointSlice()) |codepoint| {
        switch (codepoint.len) {
            0 => unreachable,
            1 => {
                const char = codepoint[0]; // U+0000...U+007F
                switch (char) {
                    0...9 => {
                        status = StatusOkExt.CntrlChar;
                    }, // Cntrl (includes '\n', '\r', '\t')
                    10 => {
                        return StatusOkExt.Newline;
                    }, // Line Feed '\n'
                    11...31 => {
                        status = StatusOkExt.CntrlChar;
                    }, // Cntrl (includes '\n', '\r', '\t')
                    ',', '`' => {
                        if (status != StatusOkExt.CntrlChar)
                            status = StatusOkExt.Antipattern;
                    }, // antipattern
                    '-', '~' => {
                        if (visited_space and status != StatusOkExt.CntrlChar)
                            status = StatusOkExt.Antipattern;
                    }, // antipattern
                    ' ' => {
                        visited_space = true;
                    },
                    127 => {
                        status = StatusOkExt.CntrlChar;
                    }, // Cntrl
                    else => {
                        visited_space = false;
                    },
                }
            },
            2 => {
                const char = mem.bytesAsValue(u16, codepoint[0..2]); // U+0080...U+07FF
                switch (char.*) {
                    128...159 => status = StatusOkExt.CntrlChar, // Cntrl: also next line 0x85)
                    160 => {
                        if (status != StatusOkExt.CntrlChar)
                            status = StatusOkExt.Antipattern;
                    }, // disallowed space: no-break space
                    173 => status = StatusOkExt.CntrlChar, // Cntrl: soft hyphen
                    else => {
                        visited_space = false;
                    },
                }
            },
            3 => {
                const char = mem.bytesAsValue(u24, codepoint[0..4]); // U+0800...U+FFFF
                switch (char.*) {
                    // disallowed spaces, see README.md
                    0x1680, 0x180e, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200a, 0x200b => {
                        if (status != StatusOkExt.CntrlChar)
                            status = StatusOkExt.Antipattern;
                    },
                    // disallowed spaces, see README.md (continued)
                    0x200c, 0x200d, 0x2028, 0x2029, 0x202f, 0x205f, 0x2060, 0x3000, 0xfeff => {
                        if (status != StatusOkExt.CntrlChar)
                            status = StatusOkExt.Antipattern;
                    },
                    else => {
                        visited_space = false;
                    },
                }
            },
            4 => {
                visited_space = false; // U+10000...U+10FFFF
            },
            else => unreachable,
        }
        //std.debug.print("got codepoint {s}\n", .{codepoint});
    }
    if (visited_space and status != StatusOkExt.CntrlChar) {
        return StatusOkExt.Antipattern;
    } // ending empty space
    return status;
}

fn writeRes(
    comptime phase: Phase,
    comptime mode: Mode,
    nl_ctrl: bool,
    file: *const fs.File,
    abs_path: []const u8,
    short_path: []const u8,
) !void {
    switch (phase) {
        Phase.RootPath => {
            switch (mode) {
                Mode.FileOutput, Mode.FileOutputAscii => {
                    if (nl_ctrl) { // newline
                        try file.writeAll("'");
                        try file.writeAll(abs_path);
                        try file.writeAll("' newline in absolute HERE\n");
                    } else {
                        try file.writeAll(abs_path);
                        try file.writeAll("\n");
                    }
                },
                Mode.ShellOutputAscii, Mode.ShellOutput => {
                    if (nl_ctrl) { // ctrl char
                        try file.writeAll("'");
                        try file.writeAll(short_path);
                        try file.writeAll("' root abs path has ctrl chars\n");
                        process.exit(2); // root path wrong
                    } else {
                        try file.writeAll("'");
                        try file.writeAll(abs_path);
                        try file.writeAll("' is antipattern\n");
                        process.exit(1); // root path wrong
                    }
                },
                else => unreachable,
            }
        },
        Phase.ChildPaths => {
            switch (mode) {
                Mode.FileOutput, Mode.FileOutputAscii => {
                    if (nl_ctrl) {
                        try file.writeAll("'");
                        //try file.writeAll(rl_sup_dir_rel);
                        try file.writeAll(abs_path);
                        try file.writeAll("' newline in subfile HERE\n");
                        //return 3;
                    } else {
                        //try file.writeAll(entry.path);
                        try file.writeAll(abs_path);
                        try file.writeAll("\n");
                    }
                },
                Mode.ShellOutput, Mode.ShellOutputAscii => {
                    if (nl_ctrl) {
                        try file.writeAll("'");
                        try file.writeAll(abs_path);
                        try file.writeAll("' has file with ctrl chars\n"); // OK
                        //return 2;
                    } else {
                        try file.writeAll("'");
                        try file.writeAll(short_path);
                        try file.writeAll("' is antipattern\n");
                    }
                },
                else => unreachable,
            }
        },
    }
}

// writes output to File (stdout, open file etc)
fn writeOutput(comptime mode: Mode, file: *const fs.File, arena: mem.Allocator, args: [][:0]u8) !u8 {
    std.debug.assert(mode != Mode.CheckOnly and mode != Mode.CheckOnlyAscii);
    const max_msg: u32 = 30; // unused for FileOutputAscii, FileOutput
    var cnt_msg: u32 = 0; // unused for FileOutputAscii, FileOutput
    var found_newline = false; // unused for ShellOutputAscii, ShellOutput

    // tmp data for realpath(), never to be references otherwise
    var tmp_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try process.getCwdAlloc(arena); // windows compatibility
    defer arena.free(cwd);

    var found_ctrlchars = false;
    var found_badchars = false;
    var i: u64 = 1; // skip program name
    while (i < args.len) : (i += 1) {
        if (mode == Mode.FileOutputAscii or mode == Mode.ShellOutputAscii) {
            if (mem.eql(u8, args[i], "-a")) continue; // skip -a
        }
        if (mode == Mode.FileOutputAscii or mode == Mode.FileOutput) {
            if (mem.eql(u8, args[i], "-outfile")) { // skip -outfile + filename
                i += 1;
                continue;
            }
        }
        const root_path = args[i];
        {
            // ensure that super path does not contain any
            // control characters, that might get printed later
            const real_path = try os.realpath(root_path, &tmp_buf);
            var it = mem.tokenize(u8, root_path, &[_]u8{fs.path.sep});
            skipItIfWindows(&it);
            while (it.next()) |entry| {
                std.debug.assert(entry.len > 0);
                var has_ctrlchars = false;
                var has_newline = false;
                switch (mode) {
                    Mode.ShellOutputAscii, Mode.FileOutputAscii => {
                        const status = isWordOkAsciiExtended(entry);
                        switch (status) {
                            StatusOkAsciiExt.Ok => {},
                            StatusOkAsciiExt.Antipattern => {},
                            StatusOkAsciiExt.CntrlChar => {
                                has_ctrlchars = true;
                                found_ctrlchars = true;
                            },
                            StatusOkAsciiExt.Newline => {
                                if (mode == Mode.FileOutputAscii or mode == Mode.FileOutput) {
                                    has_newline = true;
                                    found_newline = true;
                                }
                            },
                        }
                        const arg_decision =
                            switch (mode) {
                            Mode.FileOutputAscii => has_newline,
                            Mode.ShellOutputAscii => has_ctrlchars,
                            else => unreachable,
                        };
                        if (status != StatusOkAsciiExt.Ok) {
                            try writeRes(
                                Phase.RootPath,
                                mode,
                                arg_decision,
                                file,
                                real_path,
                                root_path,
                            );
                        }
                        switch (status) {
                            StatusOkAsciiExt.Ok => {},
                            StatusOkAsciiExt.Antipattern => return 1,
                            StatusOkAsciiExt.CntrlChar => return 2,
                            StatusOkAsciiExt.Newline => {
                                if (mode == Mode.FileOutputAscii or mode == Mode.FileOutput) {
                                    return 3;
                                } else {
                                    unreachable;
                                }
                            },
                        }
                    },
                    Mode.ShellOutput, Mode.FileOutput => {
                        const status: StatusOkExt = isWordOkExtended(entry);
                        switch (status) {
                            StatusOkExt.Ok => {},
                            StatusOkExt.Antipattern => {},
                            StatusOkExt.CntrlChar => {
                                has_ctrlchars = true;
                                found_ctrlchars = true;
                            },
                            StatusOkExt.Newline => {
                                if (mode == Mode.FileOutput) {
                                    has_newline = true;
                                    found_newline = true;
                                }
                                has_ctrlchars = true;
                                found_ctrlchars = true;
                            },
                            StatusOkExt.InvalUnicode => {
                                if (mode == Mode.ShellOutput or mode == Mode.ShellOutputAscii)
                                    try file.writeAll("root path has invalid unicode!\n");
                                return 4;
                            },
                        }
                        const arg_decision =
                            switch (mode) {
                            Mode.FileOutput => has_newline,
                            Mode.ShellOutput => has_ctrlchars,
                            else => unreachable,
                        };
                        if (status != StatusOkExt.Ok) {
                            try writeRes(
                                Phase.RootPath,
                                mode,
                                arg_decision,
                                file,
                                real_path,
                                root_path,
                            );
                        }
                        switch (status) {
                            StatusOkExt.Ok => {},
                            StatusOkExt.Antipattern => return 1,
                            StatusOkExt.CntrlChar => return 2,
                            StatusOkExt.Newline => {
                                if (mode == Mode.FileOutputAscii or mode == Mode.FileOutput) {
                                    return 3;
                                } else {
                                    unreachable;
                                }
                            },
                            StatusOkExt.InvalUnicode => unreachable,
                        }
                    },
                    else => unreachable,
                }
            }
        }

        //log.debug("reading (recursively) file '{s}'", .{root_path});
        var root_dir = fs.cwd().openDir(root_path, .{ .iterate = true, .no_follow = true }) catch |err| {
            if (mode == Mode.FileOutput or mode == Mode.FileOutputAscii) file.close();
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
            std.debug.assert(basename.len > 0);

            switch (mode) {
                Mode.ShellOutputAscii, Mode.FileOutputAscii, Mode.ShellOutput, Mode.FileOutput => {
                    var has_ctrlchars = false;
                    var has_newline = false;

                    const status = isWordOkAsciiExtended(basename);
                    switch (status) {
                        StatusOkAsciiExt.Ok => {},
                        StatusOkAsciiExt.Antipattern => {
                            cnt_msg += 1;
                            found_badchars = true;
                        },
                        StatusOkAsciiExt.CntrlChar => {
                            cnt_msg += 1;
                            has_ctrlchars = true;
                            found_ctrlchars = true;
                        },
                        StatusOkAsciiExt.Newline => {
                            cnt_msg += 1;
                            if (mode == Mode.FileOutput or mode == Mode.FileOutputAscii) {
                                has_newline = true;
                                found_newline = true;
                            } else {
                                has_ctrlchars = true;
                                found_ctrlchars = true;
                            }
                        }, // TODO perf: remove case Newline
                    }
                    const super_dir: []const u8 = &[_]u8{fs.path.sep} ++ "..";
                    const p_sup_dir = try mem.concat(arena, u8, &.{ root_path, &[_]u8{fs.path.sep}, entry.path, super_dir });
                    defer arena.free(p_sup_dir);
                    //std.debug.print("resolvePosix(arena, {s})\n", .{p_sup_dir});
                    const rl_sup_dir = try fs.path.resolve(arena, &.{p_sup_dir});
                    defer arena.free(rl_sup_dir);
                    const rl_sup_dir_rel = try fs.path.relative(arena, cwd, rl_sup_dir);
                    defer arena.free(rl_sup_dir_rel);
                    //std.debug.print("fs.path.resolve result: '{s}'\n", .{rl_sup_dir});
                    // root folder is without control characters or terminate program would have been terminated

                    const arg_decision =
                        switch (mode) {
                        Mode.FileOutput => has_newline,
                        Mode.FileOutputAscii => has_newline,
                        Mode.ShellOutput => has_ctrlchars,
                        Mode.ShellOutputAscii => has_ctrlchars,
                        else => unreachable,
                    };
                    if (status != StatusOkAsciiExt.Ok) {
                        try writeRes(
                            Phase.ChildPaths,
                            mode,
                            arg_decision,
                            file,
                            rl_sup_dir_rel,
                            entry.path,
                        );
                    }
                    if (cnt_msg == max_msg) {
                        switch (mode) {
                            Mode.FileOutput, Mode.FileOutputAscii => {
                                if (found_newline) return 3;
                                if (found_ctrlchars) return 2;
                            },
                            Mode.ShellOutput, Mode.ShellOutputAscii => {
                                if (found_ctrlchars) return 2;
                            },
                            else => unreachable,
                        }
                        std.debug.assert(found_badchars);
                        return 1;
                    }
                },
                else => unreachable,
            }
        }
    }
    switch (mode) {
        Mode.FileOutput, Mode.FileOutputAscii => {
            if (found_newline) return 3;
            if (found_ctrlchars) return 2;
            if (found_badchars) return 1;
        },
        Mode.ShellOutput, Mode.ShellOutputAscii => {
            if (found_ctrlchars) return 2;
            if (found_badchars) return 1;
        },
        else => unreachable,
    }
    return 0; // invariant: status == 0
}

const Phase = enum {
    RootPath,
    ChildPaths,
};

pub const Mode = enum {
    /// only check withs status code
    CheckOnly,
    /// ascii only check withs status code
    CheckOnlyAscii,
    /// heck with limited output
    ShellOutput,
    /// ascii heck with limited output
    ShellOutputAscii,
    /// check with output to file
    FileOutput,
    /// ascii check with output to file
    FileOutputAscii,
};

// never returns Mode, but an error to bubble up to main
fn cleanup(write_file: *?fs.File) !Mode {
    if (write_file.* != null) {
        write_file.*.?.close();
    }
    return error.TestUnexpectedResult;
}

// return codes
// 0 success
// 1 bad pattern, in case of -c option: found something bad
// 2 control character
// 3 newline occured (only in case of -outfile)
// 4 invalid unicode
// + other error codes generated from zig

// assume: no file `-outfile` exists
// assume: user specifies non-overlapping input paths
// assume: user wants 30 lines output space and a summary of total output size
// * output sanitized for ascii escape sequences and control characters on default
// * output usable in vim and shell

// perf of POSIX/Linux nftw, Rust walkdir and find are comparable.
// zig libstd offers higher perf for less convenience with optimizations
// see https://github.com/romkatv/gitstatus/blob/master/docs/listdir.md
// TODO benchmarks to show this
pub fn main() !u8 {
    var write_file: ?fs.File = null;
    var mode: Mode = Mode.ShellOutput; // default execution mode
    // 1. read path names from cli args
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    const args: [][:0]u8 = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
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
                else => try cleanup(&write_file), // hack around stage1
            };
            if (i + 1 >= args.len) {
                return error.InvalidArgument;
            }
            i += 1;
            write_file = try fs.cwd().createFile(args[i], .{});
        }
        if (mem.eql(u8, args[i], "-c")) {
            mode = switch (mode) {
                Mode.ShellOutput => Mode.CheckOnly,
                Mode.ShellOutputAscii => Mode.CheckOnlyAscii,
                else => try cleanup(&write_file), // hack around stage1
            };
        }
        if (mem.eql(u8, args[i], "-a")) {
            mode = switch (mode) {
                Mode.ShellOutput => Mode.ShellOutputAscii,
                Mode.CheckOnly => Mode.CheckOnlyAscii,
                Mode.FileOutput => Mode.FileOutputAscii,
                else => try cleanup(&write_file), // hack around stage1
            };
        }
    }
    defer if (write_file != null)
        write_file.?.close();

    const ret = switch (mode) {
        // only check status
        Mode.CheckOnly => try checkOnly(Encoding.Utf8, arena, args),
        Mode.CheckOnlyAscii => try checkOnly(Encoding.Ascii, arena, args),
        // shell output => capped at 30 lines
        Mode.ShellOutput => try writeOutput(Mode.ShellOutput, &stdout, arena, args),
        Mode.ShellOutputAscii => try writeOutput(Mode.ShellOutputAscii, &stdout, arena, args),
        // file output => files with '\n' marked
        Mode.FileOutput => try writeOutput(Mode.FileOutput, &(write_file.?), arena, args),
        Mode.FileOutputAscii => try writeOutput(Mode.FileOutputAscii, &(write_file.?), arena, args),
    };
    // TODO close file on error
    return ret;
}
