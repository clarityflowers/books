const std = @import("std");
const io = std.io;

/// A reader that counts lines and columns.
/// Useful for returning helpful errors in the middle of file parsing.
pub fn CursorCountingReader(comptime ReaderType: type) type {
    return struct {
        internal_reader: ReaderType,
        line: u64 = 1,
        col: u64 = 0,
        on_newline: bool = false,

        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*@This(), Error, read);

        pub fn read(self: *@This(), dest: []u8) Error!usize {
            const read_bytes = try self.internal_reader.read(dest);
            var i: usize = 0;
            while (i < read_bytes) : (i += 1) {
                if (self.on_newline) {
                    self.line += 1;
                    self.col = 0;
                    self.on_newline = false;
                }
                switch (dest[i]) {
                    '\n' => {
                        self.on_newline = true;
                    },
                    else => self.col += 1,
                }
            }
            return read_bytes;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn cursorCountingReader(reader: var) CursorCountingReader(@TypeOf(reader)) {
    return CursorCountingReader(@TypeOf(reader)){ .internal_reader = reader };
}
