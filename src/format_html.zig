const std = @import("std");
const dates = @import("zig-date/src/main.zig");
const model = @import("model.zig");
const parse_tools = @import("parse_tools.zig");
const mem = std.mem;

const Month = dates.Month;
const Date = dates.Date;
const Book = model.Book;
const ReadStatus = model.ReadStatus;
const Person = model.Person;

pub fn readingList(books: []const Book, writer: var) !void {
    try writer.writeAll(
        \\ <!DOCTYPE html>
        \\ <meta charset="utf-8" />
        \\ <title>Clarity's Books</title>
        \\ <link rel="stylesheet" href="./style.css" />
        \\ <main>
        \\   <h1>Clarity's Books</h1>
        \\   <section id="section_current">
        \\     <h2><a href="#section_current" class="toc">Currently Reading</a></h2>
    );
    for (books) |book| {
        if (book.status == .started) {
            try formatBook(book, writer);
        }
    }
    try writer.writeAll(
        \\  </section>
        \\   <section id="section_bookshelf">
        \\     <h2><a href="#section_bookshelf" class="toc">Bookshelf</a></h2>
    );
    for (books) |book| {
        if (book.status == .read) {
            try formatBook(book, writer);
        }
    }
    try writer.writeAll(
        \\  </section>
        \\   <section id="section_reading_list">
        \\     <h2><a href="#section_reading_list" class="toc">Reading List</a></h2>
    );
    for (books) |book| {
        if (book.status == .unread) {
            try formatBook(book, writer);
        }
    }
    try writer.writeAll(
        \\   </section>
        \\ </main>
        \\ <footer>
        \\   This color palette is
        \\   <a href="https://www.colourlovers.com/palette/2598543/Let_Me_Be_Myself_*"
        \\     >Let Me Be Myself *</a
        \\   >
        \\   by <a href="https://www.colourlovers.com/lover/sugar%21">sugar!</a>. License:
        \\   <a href="https://creativecommons.org/licenses/by-nc-sa/3.0/"
        \\     >CC-BY-NC-SA 3.0</a
        \\   >.
        \\ </footer>
    );
}

pub fn formatBook(book: Book, writer: var) !void {
    const title = Title{ .name = book.name };
    const recommenders = Recommenders{ .people = book.recommended_by };
    const summary = Summary{ .summary = book.summary };
    const class: []const u8 = if (book.status == .unread) "class=\"unread\" " else "";
    const author = HtmlPerson{ .person = book.author };
    try writer.print(
        \\<article id="{id}" {}>
    , .{ title, class });
    if (book.status != .unread) {
        const cover = Cover{ .title = title };
        try writer.print("{}", .{cover});
    }
    try writer.print(
        \\  <header>
        \\    <h3>
        \\      <a href="#{0id}" class="toc">{0}</a>
        \\    </h3>
        \\    by {1}
        \\  </header>
        \\  {2}
    , .{ title, author, summary });
    if (book.recommended_by.len > 0 or book.status != .unread) {
        try writer.print(
            \\  <ul>
            \\    {}
        , .{recommenders});
        try formatReadStatus(book.status, writer);
        try writer.writeAll(
            \\  </ul>
        );
    }
    if (book.thoughts) |thoughts| {
        const paragraphs = Paragraphs{ .text = thoughts };
        try writer.print("<details><summary>My thoughts</summary>{}</details>", .{paragraphs});
    }
    try writer.writeAll("</article>");
}

pub fn formatReadStatus(read_status: ReadStatus, writer: var) !void {
    switch (read_status) {
        .unread => {},
        .started => |start_date| {
            try writer.print(
                \\    <li><span>Started</span> <span>{}</span></li>
            , .{start_date});
        },
        .read => |read_period| {
            try writer.writeAll(
                \\<li>
                \\  <span>Read</span>
                \\  <span>
            );
            if (read_period.start.equals(read_period.end)) {
                try writer.print("{}", .{read_period.start});
            } else {
                try writer.print("{}-{}", .{ read_period.start, read_period.end });
            }
            try writer.writeAll(
                \\  </span>
                \\</li>
            );
        },
    }
}

const Recommenders = struct {
    people: []const Person,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        if (value.people.len == 0) return;
        _ = try writer.writeAll(
            \\<li>
            \\  <span>Recommended by</span>
            \\  <span>
        );
        if (value.people.len == 2) {
            try writer.print("{} and {}", .{ value.people[0], value.people[1] });
        } else for (value.people) |person, i| {
            const html_person = HtmlPerson{ .person = person };
            try writer.print("{}", .{html_person});
            if (i + 2 <= value.people.len) {
                _ = try writer.writeAll(", ");
            }
            if (i + 2 == value.people.len) {
                try writer.writeAll("and ");
            }
        }
        _ = try writer.writeAll(
            \\  </span>
            \\</li>
        );
    }
};

const HtmlPerson = struct {
    person: Person,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        const person = value.person;
        if (person.link) |link| {
            try writer.print(
                \\<a href="{}">{}</a>
            , .{ link, person.name });
        } else {
            _ = try writer.writeAll(person.name);
        }
    }
};

const Id = struct {
    name: []const u8,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {}
};

const Title = struct {
    name: []const u8,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        if (mem.eql(u8, fmt, "accessible")) {
            for (value.name) |char| {
                if (char == '_' or char == '?') {
                    continue;
                } else {
                    try writer.writeByte(char);
                }
            }
        } else if (mem.eql(u8, fmt, "id")) {
            var italic = false;
            for (value.name) |char| {
                if (char == '_') {
                    italic = true;
                } else if (char == '?' or char == ':') {
                    continue;
                } else if (char == ' ') {
                    try writer.writeByte('_');
                } else {
                    try writer.writeByte(char);
                }
            }
        } else {
            var italic = false;
            for (value.name) |char| {
                if (char == '_') {
                    if (italic) {
                        italic = false;
                        _ = try writer.writeAll("</em>");
                    } else {
                        italic = true;
                        _ = try writer.writeAll("<em>");
                    }
                } else {
                    try writer.writeByte(char);
                }
            }
        }
    }
};

const Cover = struct {
    title: Title,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        try writer.print(
            \\  <div class="img">
            \\    <img src="./images/{0id}.png" alt="Cover art for '{0accessible}'" />
            \\  </div>
        , .{value.title});
    }
};

const Summary = struct {
    summary: ?[]const u8,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        if (value.summary) |summary| {
            try writer.print(
                \\<p>{}</p>
            , .{summary});
        }
    }
};

const Paragraphs = struct {
    text: []const u8,
    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        var written: usize = 0;
        while (written < value.text.len) {
            try writer.writeAll("<p>");
            var i: usize = written;
            while (i < value.text.len) : (i += 1) {
                if (parse_tools.matchLiteral(value.text, i, "\n\n")) |index| {
                    _ = try writer.writeAll(value.text[written..i]);
                    written = index;
                    break;
                }
            }
            if (i >= value.text.len) {
                _ = try writer.writeAll(value.text[written..]);
                written = value.text.len;
            }
            _ = try writer.writeAll("</p>");
        }
    }
};

fn List(comptime T: type) type {
    return struct {
        items: []const T,

        pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
            for (value.items) |item| {
                try writer.print("{" ++ fmt ++ "}", .{item});
            }
        }
    };
}
