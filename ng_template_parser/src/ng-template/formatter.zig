//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const Options = @import("options").FormatterOptions;
const FileString = @import("utils").FileString;
const Node = @import("ast.zig").NgTemplateNode;
const HtmlElement = @import("ast.zig").HtmlElement;

pub const NgTemplateFormatter = Formatter;

const Formatter = struct {
    options: Options,
    allocator: std.mem.Allocator,
    file_string: FileString,

    pub fn init(allocator: std.mem.Allocator, options: Options) Formatter {
        const e = Options{ .tab_width = options.tab_width };
        return .{ .options = e, .allocator = allocator, .file_string = FileString.empty(allocator) };
    }

    pub fn format(self: *Formatter, content: [:0]const u8) ![]u8 {
        try self.file_string.init(content.len);

        var parser = Parser.init(content);

        var elements = try parser.parse(self.allocator);
        defer elements.deinit(self.allocator);
        defer for (elements.items) |*item| {
            item.deinit(self.allocator);
        };

        for (elements.items) |*element| {
            try self.visit_node(element, 0);
        }

        return self.file_string.toString();
    }

    fn visit_node(self: *Formatter, element: *Node, indent: usize) !void {
        switch (element.*) {
            .html_element => {
                try self.print_open_tag(element.html_element);

                const new_indent = indent + self.options.tab_width;
                for (element.html_element.children.items) |*child| {
                    try self.file_string.indent(new_indent);
                    try self.visit_node(child, new_indent);
                }

                try self.print_closing_tag(element.html_element);
            },
            else => {},
        }
    }

    fn print_self_closing_tag(self: *Formatter, element: HtmlElement) !void {
        try self.file_string.concat("<");
        try self.file_string.concat(element.name);
        try self.file_string.concat("/>\n");
    }

    fn print_open_tag(self: *Formatter, element: HtmlElement) !void {
        try self.file_string.concat("<");
        try self.file_string.concat(element.name);
        try self.file_string.concat(">\n");
    }

    fn print_closing_tag(self: *Formatter, element: HtmlElement) !void {
        try self.file_string.concat("</");
        try self.file_string.concat(element.name);
        try self.file_string.concat(">\n");
    }
};
