const std = @import("std");
const dates = @import("zig-date/src/main.zig");
const model = @import("model.zig");
const fs = std.fs;
const process = std.process;
const mem = std.mem;
const heap = std.heap;
const math = std.math;
const io = std.io;

const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;
const ArenaAllocator = heap.ArenaAllocator;
const Month = dates.Month;
const Date = dates.Date;
const Book = model.Book;
const Person = model.Person;
const cursorCountingReader = @import("cursor_counting_reader.zig").cursorCountingReader;
const errPipe = @import("err_pipe_writer.zig").errPipe;
const terminalStyleWriter = @import("terminal_style_writer.zig").terminalStyleWriter;

const readingList = @import("format_html.zig").readingList;
const storage = @import("storage.zig");
const parseBooks = storage.parseBooks;
const ParseErrorContext = storage.ParseErrorContext;

const books_filename = "books.txt";
const exe_name = "books";

pub fn main() !void {
    @setEvalBranchQuota(10000);
    loadBooks() catch |err| {
        var err_pipe = errPipe(exe_name);
        const stderr = err_pipe.writer();
        switch (err) {
            error.LoadingError => {}, // this has already been handled
            else => |system_err| {
                try stderr.writeAll(switch (system_err) {
                    error.AccessDenied => "Error while trying to access file",
                    error.Unexpected => "An unexpected error occured",
                    error.OutOfMemory => "Ran out of memory!",
                    error.EndOfStream => "Unexpected end of stream",
                    else => "God idk I don't want to handle all these error cases",
                });
                try stderr.writeByte('\n');
            },
        }

        return err;
    };
}

pub fn loadBooks() !void {
    const cwd = fs.cwd();

    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    var err_pipe = errPipe(exe_name);
    const terminal_writer = terminalStyleWriter(err_pipe.writer(), io.getStdErr().isTty());
    const stderr = terminal_writer.writer();
    var err_context = ParseErrorContext{};
    const book_list = parseBooks(io.getStdIn().reader(), allocator, &err_context) catch |err| {
        switch (err) {
            // these shouldn't really be handled here, but I want to make note of them explicitly so that I have to
            // make this decision for each new error introduced
            error.AccessDenied, error.Unexpected, error.OutOfMemory, error.EndOfStream, error.WouldBlock => return err,
            error.ConnectionTimedOut, error.ConnectionResetByPeer, error.BrokenPipe, error.OperationAborted => return err,
            error.IsDir, error.SystemResources, error.InputOutput => return err,
            else => |parse_err| {
                try stderr.writeAll("[!red]*Error while parsing book*[!]\n");
                if (err_context.state) |err_state| {
                    var i: usize = 0;
                    try stderr.print("[!gray]{d}  [!]{}\n", .{ err_state.line_number + 1, err_state.line });
                }
                try stderr.writeAll(switch (parse_err) {
                    error.NotAPerson => "*Could not parse person*",
                    error.BookStartedMultipleTimes => "Books cannot have multiple started dates",
                    error.BookFinishedMultipleTimes => "Books cannot have multiple finish dates",
                    error.BookFinishedButNotStarted => "Book with finished dates must have started states",
                    error.StreamTooLong => "Line length exceeded maximum expected",
                });
                try stderr.writeAll("\n\n");
                return error.LoadingError;
            },
        }
    };
    try readingList(book_list, io.getStdOut().writer());
}

// pub fn getLineFromFile(line: u64, allocator: *Allocator) ![]const u8 {
//     var i: usize = 0;
//     const file = try fs.cwd().openFile(books_filename, .{});
//     defer file.close();
//     const reader = file.reader();
//     while (i < line - 1) : (i += 1) {
//         try reader.skipUntilDelimiterOrEof('\n');
//     }
//     var result = ArrayList(u8).init(allocator);
//     errdefer result.deinit();
//     reader.readUntilDelimiterArrayList(&result, '\n', 1024 * 1024) catch |err| {
//         if (err != error.EndOfStream) return err;
//     };
//     return result.toOwnedSlice();
// }
