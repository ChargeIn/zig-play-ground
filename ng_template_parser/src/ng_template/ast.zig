//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Attribute = @import("token.zig").Attribute;

pub const HtmlTextElement = struct {
    raw: []const u8,
    trimmed: []const u8,

    pub fn format(value: HtmlTextElement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "HtmlTextElement {{ raw: \"{s}\", trimmed: \"{s}\" }}",
            .{ value.raw, value.trimmed },
        );
    }

    pub fn init(raw: []const u8, trimmed: []const u8) HtmlTextElement {
        return .{ .trimmed = trimmed, .raw = raw };
    }
};

pub const HtmlElement = struct {
    name: []const u8,
    self_closing: bool,
    attributes: std.ArrayListUnmanaged(HtmlAttribute),
    children: std.ArrayListUnmanaged(NgTemplateNode),

    pub fn format(value: HtmlElement, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "HtmlElement {{ name: {s}, self_closing: {any}, attributes: [",
            .{ value.name, value.self_closing },
        );

        if (value.attributes.items.len > 0) {
            try writer.print("\n  ", .{});

            for (value.attributes.items, 0..) |attr, i| {
                try writer.print("  ", .{});
                try attr.format(fmt, opt, writer);
                if (i < value.attributes.items.len - 1) {
                    try writer.print(",\n  ", .{});
                }
            }
            try writer.print("\n", .{});
        }

        try writer.print("], children: [", .{});

        if (value.children.items.len > 0) {
            try writer.print("\n", .{});

            for (value.children.items, 0..) |child, i| {
                try writer.print("  {any}", .{child});
                if (i < value.children.items.len - 1) {
                    try writer.print(",\n", .{});
                }
            }
            try writer.print("\n", .{});
        }

        try writer.print("] }}", .{});
    }

    pub fn deinit(self: *HtmlElement, allocator: std.mem.Allocator) void {
        self.attributes.deinit(allocator);

        for (self.children.items) |*child| {
            child.deinit(allocator);
        }

        self.children.deinit(allocator);
    }
};

pub const NgIfBaseElement = struct { condition: []const u8, children: std.ArrayListUnmanaged(NgTemplateNode) };

pub const NgIfElement = struct {
    element: NgIfBaseElement,
    ng_else_if: std.ArrayListUnmanaged(NgIfBaseElement),
    ng_else: std.ArrayListUnmanaged(NgIfBaseElement),

    pub fn format(value: NgIfElement, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "NgIfControlElement {{ name: {s}, self_closing: {any}, attributes: [",
            .{ value.name, value.self_closing },
        );

        if (value.attributes.items.len > 0) {
            try writer.print("\n  ", .{});

            for (value.attributes.items, 0..) |attr, i| {
                try writer.print("  ", .{});
                try attr.format(fmt, opt, writer);
                if (i < value.attributes.items.len - 1) {
                    try writer.print(",\n  ", .{});
                }
            }
            try writer.print("\n", .{});
        }

        try writer.print("], children: [", .{});

        if (value.children.items.len > 0) {
            try writer.print("\n", .{});

            for (value.children.items, 0..) |child, i| {
                try writer.print("  {any}", .{child});
                if (i < value.children.items.len - 1) {
                    try writer.print(",\n", .{});
                }
            }
            try writer.print("\n", .{});
        }

        try writer.print("] }}", .{});
    }

    pub fn deinit(self: *HtmlElement, allocator: std.mem.Allocator) void {
        self.attributes.deinit(allocator);

        for (self.children.items) |*child| {
            child.deinit(allocator);
        }

        self.children.deinit(allocator);
    }
};

pub const HtmlAttributeType = enum {
    static,
    one_way,
    two_way,
    output,
};

pub const HtmlAttribute = struct {
    name: []const u8,
    value: []const u8,
    type: HtmlAttributeType,
    has_value: bool, // used to differentiate between attirbutes with empty values (e.g test="") and no values (e.g. test )

    pub fn init(attr: Attribute) HtmlAttribute {
        var attrType: HtmlAttributeType = HtmlAttributeType.static;
        var startOffset: usize = 0;

        if (attr.name[startOffset] == '[') {
            attrType = HtmlAttributeType.one_way;
            startOffset += 1;
        }

        if (attr.name[startOffset] == '(') {
            startOffset += 1;

            if (attrType == HtmlAttributeType.static) {
                attrType = HtmlAttributeType.output;
            } else {
                attrType = HtmlAttributeType.two_way;
            }
        }

        return HtmlAttribute{
            .name = attr.name[startOffset..(attr.name.len - startOffset)],
            .value = attr.value,
            .type = attrType,
            .has_value = attr.has_value,
        };
    }

    pub fn format(value: HtmlAttribute, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "HtmlAttribute {{ name: {s}, value: {s}, type: {any} }}",
            .{ value.name, value.value, value.type },
        );
    }
};

pub const NgTemplateNode = union(enum) {
    html_element: HtmlElement,
    doc_type: []const u8,
    cdata: []const u8,
    comment: []const u8,
    text: HtmlTextElement,
    ng_if: NgIfElement,
    eof,

    pub fn format(value: NgTemplateNode, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .html_element => |v| try v.format(fmt, opt, writer),
            .comment => |v| try writer.print("Comment {{ \"{s}\" }}", .{v}),
            .text => |v| try v.format(fmt, opt, writer),
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
