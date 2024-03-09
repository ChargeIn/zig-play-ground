//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");

pub const StartTag = struct {
    name: []const u8,
    self_closing: bool,
    attributes: std.ArrayListUnmanaged(Attribute),

    pub fn init(name: []const u8, self_closing: bool, attributes: std.ArrayListUnmanaged(Attribute)) StartTag {
        return StartTag{
            .name = name,
            .self_closing = self_closing,
            .attributes = attributes,
        };
    }

    pub fn deinit(self: *StartTag, allocator: std.mem.Allocator) void {
        self.attributes.deinit(allocator);
    }

    pub fn format(value: StartTag, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "StartTag {{ name: {s}, self_closing: {any}, attributes: [",
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

        try writer.print("] }}", .{});
    }
};

pub const Attribute = struct {
    name: []const u8,
    value: []const u8,
    has_value: bool,

    pub fn initNoValue(name: []const u8) Attribute {
        return Attribute{
            .name = name,
            .value = "",
            .has_value = false,
        };
    }

    pub fn init(name: []const u8, value: []const u8) Attribute {
        return Attribute{
            .name = name,
            .value = value,
            .has_value = true,
        };
    }

    pub fn format(value: Attribute, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "Attribute {{ name: \"{s}\", value: \"{s}\" }}",
            .{ value.name, value.value },
        );
    }
};

pub const EndTag = struct {
    name: []const u8,

    pub fn init(name: []const u8) EndTag {
        return EndTag{
            .name = name,
        };
    }

    pub fn format(value: EndTag, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "EndTag {{ name: {s} }}",
            .{value.name},
        );
    }
};

pub const NgTemplateToken = union(enum) {
    start_tag: StartTag,
    end_tag: EndTag,
    doc_type: []const u8,
    cdata: []const u8,
    comment: []const u8,
    text: []const u8,
    eof,

    pub fn format(value: NgTemplateToken, comptime fmt: []const u8, opt: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .comment => |v| try writer.print("Comment {{ \"{s}\" }}", .{v}),
            .text => |v| try writer.print("Text {{ \"{s}\" }}", .{v}),
            .cdata => |v| try writer.print("RcData {{ \"{s}\" }}", .{v}),
            .doc_type => |v| try writer.print("DocType {{ \"{s}\" }}", .{v}),
            .eof => try writer.print("End of File", .{}),
            .start_tag => |v| try v.format(fmt, opt, writer),
            .end_tag => |v| try v.format(fmt, opt, writer),
        }
    }

    pub fn deinit(self: *NgTemplateToken, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .start_tag => |*v| v.deinit(allocator),
            else => {},
        }
    }
};
