const std = @import("std");
const io = std.io;
const fs = std.fs;

const File = fs.File;

/// If stdin and stdout are interctive terminals, this is identical to stderr
/// Otherwise, this appends the exe name to every newline written.
/// If stderr isn't an interactive terminal, filters out ansi style codes like ESC[##,##,##m
pub const ErrPipe = struct {
    exe_name: []const u8,
    stderr: File,
    in_tty: bool,
    out_tty: bool,
    beginning: bool = true,

    pub const Error = File.WriteError;
    pub const Writer = io.Writer(*@This(), Error, write);

    pub fn write(self: *@This(), bytes: []const u8) Error!usize {
        const stderr = io.getStdErr().writer();
        if (self.in_tty and self.out_tty) {
            return stderr.write(bytes);
        }
        if (self.beginning) {
            try stderr.print("{}: ", .{self.exe_name});
            self.beginning = false;
        }
        var start: usize = 0;
        var end = start;
        while (end < bytes.len) : (end += 1) {
            if (bytes[end] == '\n') {
                try stderr.writeAll(bytes[start .. end + 1]);
                try stderr.print("{}: ", .{self.exe_name});
                start = end + 1;
            } else if (!self.stderr.isTty()) {
                if (parseAnsiStyleCode(bytes[end..])) |bytes_to_skip| {
                    try stderr.writeAll(bytes[start..end]);
                    end = end + bytes_to_skip;
                    start = end + 1;
                }
            }
        }
        try stderr.writeAll(bytes[start..]);
        return bytes.len;
    }

    pub fn writer(self: *@This()) Writer {
        return .{ .context = self };
    }
};

fn parseAnsiStyleCode(bytes: []const u8) ?usize {
    if (bytes.len >= 3) {
        if (bytes[0] == '\x1b' and bytes[1] == '[') {
            var i: usize = 2;
            while (i < bytes.len) : (i += 1) {
                if (bytes[i] == 'm') return i;
            }
        }
    }
    return null;
}

pub fn errPipe(exe_name: []const u8) ErrPipe {
    return .{
        .exe_name = exe_name,
        .stderr = io.getStdErr(),
        .in_tty = io.getStdIn().isTty(),
        .out_tty = io.getStdOut().isTty(),
    };
}
