const std = @import("std");

// Note we assume that the content of the file is valid utf+8
// Based on the offical standard https://html.spec.whatwg.org/multipage/parsing.html
pub const DocType = struct {
    name: ?[]const u8,
    public_id: ?[]const u8,
    system_id: ?[]const u8,
    force_quirks: bool,

    pub fn init(force_quirks: bool, name: ?[]const u8, public_id: ?[]const u8, system_id: ?[]const u8) DocType {
        return DocType{
            .name = name,
            .public_id = public_id,
            .system_id = system_id,
            .force_quirks = force_quirks,
        };
    }

    pub fn format(value: DocType, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "DocType {{ name: {?s}, public_id: {?s}, system_id: {?s}, force_quirks: {any} }}",
            .{ value.name, value.public_id, value.system_id, value.force_quirks },
        );
    }
};

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

    pub fn format(value: DocType, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "StartTag {{ name: {s}, attributes: {any}, system_id: {?s}, self_closing: {any} }}",
            .{ value.name, value.attributes, value.self_closing },
        );
    }
};

pub const Attribute = struct {
    name: []const u8,
    value: []const u8,

    pub fn init(name: []const u8, value: []const u8) Attribute {
        return Attribute{
            .name = name,
            .value = value,
        };
    }
};

pub const EndTag = struct {
    name: []const u8,

    pub fn init(name: []const u8) EndTag {
        return EndTag{
            .name = name,
        };
    }

    pub fn format(value: DocType, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "EndTag {{ name: {s} }}",
            .{value.name},
        );
    }
};

pub const NgTemplateToken = union(enum) {
    doc_type: DocType,
    start_tag: StartTag,
    end_tag: EndTag,
    comment: []const u8,
    text: []const u8,
    eof,

    pub fn format(value: NgTemplateToken, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .comment => |v| try writer.print("Comment {{ \"{s}\" }}", .{v}),
            .eof => try writer.writeAll("End of File"),
            else => try writer.print("{any}", .{value}),
        }
    }
};
