const std = @import("std");
const io = std.io;
const mem = std.mem;

/// Allows you to print terminal styles like colors using a nicer syntax
/// If use_styles is false, style markup is removed without any styles being applied.
///
/// Non-color state is reset after each write, so it is not necessary to remove those styles unless you need to
///
/// --SYNTAX--
/// *bold*
/// [!red]
/// [!gray]
/// [!] reset color
pub fn TerminalStyleWriter(comptime WriterType: type) type {
    return struct {
        internal_writer: WriterType,
        use_styles: bool,

        pub const Error = WriterType.Error;
        pub const Writer = io.Writer(@This(), Error, write);

        pub fn write(self: @This(), bytes: []const u8) Error!usize {
            if (!self.use_styles) return self.internal_writer.write(bytes);
            var i: usize = 0;
            while (i < bytes.len) {
                i += try parse(bytes[i..], self.internal_writer, self.use_styles);
            }
            return bytes.len;
        }

        pub fn writer(self: @This()) Writer {
            return .{ .context = self };
        }
    };
}

pub fn terminalStyleWriter(writer: var, use_styles: bool) TerminalStyleWriter(@TypeOf(writer)) {
    return TerminalStyleWriter(@TypeOf(writer)){ .internal_writer = writer, .use_styles = use_styles };
}

fn parse(str: []const u8, writer: var, use_styles: bool) (@TypeOf(writer).Error)!usize {
    if (str[0] == '*') {
        if (use_styles) try writer.writeAll("\x1b[1m");
        const printed = try printUntil(str[1..], writer, "*", use_styles);
        if (use_styles) try writer.writeAll("\x1b[22m");
        return 1 + printed;
    } else if (matchLiteral(str, "[!red]")) |matched| {
        if (use_styles) try writer.writeAll("\x1b[38;5;196m");
        return matched;
    } else if (matchLiteral(str, "[!gray]")) |matched| {
        if (use_styles) try writer.writeAll("\x1b[38;5;248m");
        return matched;
    } else if (matchLiteral(str, "[!]")) |matched| {
        if (use_styles) try writer.writeAll("\x1b[39m");
        return matched;
    } else {
        try writer.writeByte(str[0]);
        return 1;
    }
}

fn printUntil(str: []const u8, writer: var, comptime until: []const u8, use_styles: bool) (@TypeOf(writer).Error)!usize {
    var i: usize = 0;
    while (i < str.len) {
        if (matchLiteral(str[i..], until)) |matched| {
            return i + matched;
        }
        i += try parse(str[i..], writer, use_styles);
    }
    return str.len;
}

fn matchLiteral(str: []const u8, comptime literal: []const u8) ?usize {
    if (str.len >= literal.len and mem.eql(u8, str[0..literal.len], literal)) {
        return literal.len;
    }
    return null;
}
