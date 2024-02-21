//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Attribute = @import("token.zig").Attribute;

pub const HtmlElement = struct {
    name: []const u8,
    self_closing: bool,
    attributes: std.ArrayListUnmanaged(Attribute),
    children: std.ArrayListUnmanaged(NgTemplateNode),

    pub fn format(value: HtmlElement, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "HtmlElement {{ name: {s}, self_closing: {any}, attributes: [",
            .{ value.name, value.self_closing },
        );

        if (value.attributes.items.len > 0) {
            try writer.print(" ", .{});

            for (value.attributes.items, 0..) |attr, i| {
                try attr.format(fmt, opt, writer);
                if (i < value.attributes.items.len - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print(" ", .{});
        }

        try writer.print("], children: [", .{});

        if (value.children.items.len > 0) {
            try writer.print(" ", .{});

            for (value.children.items, 0..) |child, i| {
                try writer.print("{any}", .{child});
                if (i < value.children.items.len - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print(" ", .{});
        }

        try writer.print("] }}", .{});
    }

    pub fn deinit(self: *HtmlElement, allocator: std.mem.Allocator) void {
        self.attributes.deinit(allocator);
        self.children.deinit(allocator);
    }
};

pub const NgTemplateNode = union(enum) {
    html_element: HtmlElement,
    doc_type: []const u8,
    cdata: []const u8,
    comment: []const u8,
    text: []const u8,
    eof,

    pub fn format(value: NgTemplateNode, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .html_element => |v| try v.format(fmt, opt, writer),
            .comment => |v| try writer.print("Comment {{ \"{s}\" }}", .{v}),
            .text => |v| try writer.print("Text {{ \"{s}\" }}", .{v}),
            .cdata => |v| try writer.print("RcData {{ \"{s}\" }}", .{v}),
            .doc_type => |v| try writer.print("DocType {{ \"{s}\" }}", .{v}),
            .eof => try writer.print("End of File", .{}),
        }
    }

    pub fn deinit(self: *NgTemplateNode, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .html_element => |*v| v.deinit(allocator),
            else => {},
        }
    }
};
