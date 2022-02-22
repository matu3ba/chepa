const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const assert = std.debug.assert;

//assume base >= 0
fn isValidNumber(comptime UT: type, cust_nr: []UT, base: UT) bool {
    for (cust_nr) |m_el| {
        if (m_el >= base)
            return false;
    }
    return true;
}

fn isNotNull(comptime UT: type, cust_nr: []const UT) bool {
    for (cust_nr) |m_el| {
        if (m_el != 0) {
            return true;
        }
    }
    return false;
}

// on successfull addition return true, otherwise false
fn add(comptime UT: type, cust_nr: []UT, base: UT) bool {
    var carry = false;
    var index: u32 = @intCast(u32, cust_nr.len - 1);
    while (index > 0) : (index -= 1) {
        var added_val = cust_nr[index] + 1;
        if (added_val == base) {
            carry = true;
        } else {
            cust_nr[index] = added_val;
            break;
        }
    }
    // prevent index underflow
    if (index == 0 and carry == true and cust_nr[index] + 1 == base) {
        return false; // could not increase anymore
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

test "isValidNumber" {
    const base: u32 = 4;
    var mem_array = [_]u32{ 1, 2, 3 };
    var is_val_nr = isValidNumber(u32, &mem_array, base);
    try testing.expectEqual(true, is_val_nr);
}

test "isNull" {
    var mem_array1 = [_]u32{ 0, 0, 0 };
    var is_not_null = isNotNull(u32, &mem_array1);
    try testing.expectEqual(false, is_not_null);

    var mem_array2 = [_]u32{ 1, 1, 1 };
    is_not_null = isNotNull(u32, &mem_array2);
    try testing.expectEqual(true, is_not_null);
}

test "add" {
    const base: u32 = 4;
    var mem_array = [_]u32{ 1, 2, 3 };
    const result = add(u32, &mem_array, base);
    const exp_mem_array = [_]u32{ 1, 3, 0 };
    try testing.expectEqual(exp_mem_array, mem_array);
    try testing.expectEqual(true, result);

    mem_array = [_]u32{ 3, 3, 3 };
    const result2 = add(u32, &mem_array, base);
    try testing.expectEqual(mem_array, mem_array);
    try testing.expectEqual(false, result2);
}
