const std = @import("std");
const fs = std.fs;
const process = std.process;
const mem = std.mem;

const dates = @import("zig-date/src/main.zig");
const Month = dates.Month;
const Date = dates.Date;
const Allocator = mem.Allocator;

const html = @import("format_html");

pub const Book = struct {
    name: []const u8,
    author: Person,
    recommended_by: []const Person = &[0]Person{},
    summary: ?[]const u8 = null,
    status: ReadStatus = .unread,
    thoughts: ?[]const u8 = null,
    shelf: ?[]const u8 = null,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        try writer.print("[Book: {}, by {}]", .{ value.name, value.author });
    }

    pub fn deinit(self: @This(), allocator: *Allocator) void {
        allocator.free(self.name);
        self.author.deinit(allocator);
        for (self.recommended_by) |person| {
            person.deinit(allocator);
        }
        allocator.free(self.recommended_by);
        if (self.summary) |summary| {
            allocator.free(summary);
        }
        if (self.thoughts) |thoughts| {
            allocator.free(thoughts);
        }
    }
};

pub const ReadStatus = union(enum) {
    unread,
    started: VariableDate,
    read: struct {
        start: VariableDate, end: VariableDate
    },

    pub fn deinit(self: @This(), allocator: *Allocator) void {
        switch (self) {
            .unread => {},
            .started => |started| started.deinit(allocator),
            .read => |read| {
                read.start.deinit(allocator);
                read.end.deinit(allocator);
            },
        }
    }
};

pub const VariableDate = union(enum) {
    period: []const u8,
    year: u16,
    month: Month,
    date: Date,

    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: var) !void {
        switch (value) {
            .period => |period| _ = try writer.writeAll(period),
            .year => |year| try writer.print("{d}", .{year}),
            .month => |month| try writer.print("{Month YYYY}", .{month}),
            .date => |date| try writer.print("{Month DD, YYYY}", .{date}),
        }
    }

    pub fn parse(str: []const u8, allocator: *Allocator) !VariableDate {
        if (Date.parse(str) catch null) |date| {
            return VariableDate{ .date = date };
        }
        if (Month.parse(str) catch null) |month| {
            return VariableDate{ .month = month };
        }
        if (std.fmt.parseInt(u16, str, 10) catch null) |year| {
            return VariableDate{ .year = year };
        }
        return VariableDate{ .period = try allocator.dupe(u8, str) };
    }

    pub fn deinit(self: *@This(), allocator: *Allocator) void {
        switch (self) {
            .period => |period| try allocator.free(period),
            .year, .month, .date => {},
        }
    }

    pub fn equals(self: @This(), other: @This()) bool {
        return switch (self) {
            .period => |period| other == .period and mem.eql(u8, period, other.period),
            .year => |year| other == .year and other.year == self.year,
            .month => |month| other == .month and month.equals(other.month),
            .date => |date| other == .date and date.equals(other.date),
        };
    }
};

pub const Person = struct {
    name: []const u8,
    link: ?[]const u8 = null,

    pub fn deinit(self: @This(), allocator: *Allocator) void {
        allocator.free(self.name);
        if (self.link) |link| {
            allocator.free(link);
        }
    }
};
