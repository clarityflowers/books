const std = @import("std");
const mem = std.mem;

pub fn matchLiteral(str: []const u8, index: var, comptime literal: []const u8) ?@TypeOf(index) {
    if (str.len - index >= literal.len and mem.eql(u8, str[index .. index + literal.len], literal)) {
        return index + literal.len;
    }
    return null;
}
