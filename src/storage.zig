const std = @import("std");
const dates = @import("zig-date/src/main.zig");
const model = @import("model.zig");
const parse_tools = @import("parse_tools.zig");
const mem = std.mem;
const io = std.io;
const math = std.math;

const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;
const Month = dates.Month;
const Date = dates.Date;
const Book = model.Book;
const ReadStatus = model.ReadStatus;
const Person = model.Person;
const VariableDate = model.VariableDate;
const cursorCountingReader = @import("cursor_counting_reader.zig").cursorCountingReader;

/// returns true if there there are still lines left
pub fn readLineToEnd(reader: var, array_list: *ArrayList(u8)) !bool {
    readLine(reader, array_list) catch |err| {
        switch (err) {
            error.EndOfStream => return false,
            else => return err,
        }
    };
    return true;
}

pub fn readLine(reader: var, array_list: *ArrayList(u8)) !void {
    try reader.readUntilDelimiterArrayList(array_list, '\n', 1024 * 1024);
}

pub const ParseErrorContext = struct {
    state: ?struct {
        line_number: u64, line: []const u8
    } = null
};

pub fn parseBooks(reader: var, allocator: *Allocator, err_context: *ParseErrorContext) ![]const Book {
    const books = &ArrayList(Book).init(allocator);
    var counter = cursorCountingReader(reader);
    const counting_reader = counter.reader();
    errdefer {
        for (books.items) |book| {
            book.deinit(allocator);
        }
        books.deinit();
    }
    var book_err_context = ParseBookErrorContext{};
    while (parseBook(counting_reader, allocator, &book_err_context) catch |err| {
        err_context.state = .{
            .line_number = counter.line - 1,
            .line = book_err_context.line orelse "",
        };
        return err;
    }) |book| {
        try books.append(book);
    }
    return books.toOwnedSlice();
}

const ParseBookErrorContext = struct {
    line: ?[]const u8 = null,
};

fn parseBook(reader: var, allocator: *Allocator, err: *ParseBookErrorContext) !?Book {
    const current_line = &ArrayList(u8).init(allocator);
    defer current_line.deinit();
    errdefer {
        err.line = current_line.toOwnedSlice();
    }
    while (current_line.items.len == 0) {
        if (!try readLineToEnd(reader, current_line)) return null;
    }
    const name = current_line.toOwnedSlice();
    try readLine(reader, current_line);
    var book = Book{
        .name = name,
        .author = try parsePerson(current_line.items, allocator),
    };
    errdefer book.deinit(allocator);

    const recs = &ArrayList(Person).init(allocator);
    errdefer {
        for (recs.items) |rec| rec.deinit(allocator);
        recs.deinit();
    }

    var maybe_started: ?VariableDate = null;
    var maybe_finished: ?VariableDate = null;
    var could_be_summary = true;
    var thoughts: ?ArrayList(u8) = null;
    var state: union(enum) { start, props, thoughts, newline: u64 } = .start;

    while (try readLineToEnd(reader, current_line)) {
        if (getProperty(current_line.items, "rec")) |value| {
            try recs.append(try parsePerson(value, allocator));
        } else if (getProperty(current_line.items, "started")) |value| {
            if (maybe_started != null) return error.BookStartedMultipleTimes;
            maybe_started = try VariableDate.parse(value, allocator);
        } else if (getProperty(current_line.items, "finished")) |value| {
            if (maybe_finished != null) return error.BookFinishedMultipleTimes;
            maybe_finished = try VariableDate.parse(value, allocator);
        } else if (getProperty(current_line.items, "shelf")) |value| {
            book.shelf = try allocator.dupe(u8, value);
        } else if (state == .start) {
            book.summary = current_line.toOwnedSlice();
        } else if (current_line.items.len == 0) {
            switch (state) {
                .thoughts => state = .{ .newline = 1 },
                .newline => |count| {
                    if (count >= 1) break;
                    state.newline += 1;
                },
                else => break,
            }
        } else {
            switch (state) {
                .thoughts => {
                    try thoughts.?.append(' ');
                    try thoughts.?.appendSlice(current_line.toOwnedSlice());
                },
                .newline => {
                    try thoughts.?.appendSlice("\n\n");
                    try thoughts.?.appendSlice(current_line.toOwnedSlice());
                    state = .thoughts;
                },
                else => {
                    thoughts = ArrayList(u8).fromOwnedSlice(allocator, current_line.toOwnedSlice());
                    state = .thoughts;
                },
            }
        }
        if (state == .start) state = .props;
    }

    if (thoughts) |*t| {
        book.thoughts = t.toOwnedSlice();
    }
    book.recommended_by = recs.toOwnedSlice();

    if (maybe_started) |started| {
        if (maybe_finished) |finished| {
            book.status = .{ .read = .{ .start = started, .end = finished } };
        } else {
            book.status = .{ .started = started };
        }
    } else if (maybe_finished != null) {
        return error.BookFinishedButNotStarted;
    }

    return book;
}

pub fn parsePerson(str: []const u8, allocator: *Allocator) !Person {
    var i: usize = 0;
    while (i < str.len and str[i] == ' ') {
        i += 1;
    }
    if (i == str.len) return error.NotAPerson;
    var link: ?[]const u8 = null;
    while (i < str.len) : (i += 1) {
        if (parse_tools.matchLiteral(str, i, " (")) |new_index| {
            const name_end = i;
            i = new_index;
            const link_start = new_index;
            while (i < str.len) : (i += 1) {
                if (str[i] == ')') {
                    const name = try allocator.dupe(u8, str[0..name_end]);
                    errdefer allocator.free(name);
                    return Person{
                        .name = name,
                        .link = try allocator.dupe(u8, str[link_start..i]),
                    };
                }
            }
            return error.NotAPerson;
        }
    }
    return Person{ .name = try allocator.dupe(u8, str[0..i]) };
}

pub fn getProperty(str: []const u8, comptime prop: []const u8) ?[]const u8 {
    if (str.len < prop.len + 2) return null;
    if (mem.eql(u8, str[0 .. prop.len + 2], prop ++ ": ")) return str[prop.len + 2 ..];
    return null;
}
