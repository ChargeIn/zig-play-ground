//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const Options = @import("options").FormatterOptions;
const FileString = @import("utils").FileString;
const Node = @import("ast.zig").NgTemplateNode;

pub const NgTemplateFormatter = Formatter;

const Formatter = struct {
    options: Options,
    allocator: std.mem.Allocator,
    file_string: FileString,

    pub fn init(allocator: std.mem.Allocator, options: Options) Formatter {
        const e = Options{ .tab_width = options.tab_width };
        return .{ .options = e, .allocator = allocator, .file_string = FileString.emtpy(allocator) };
    }

    pub fn format(self: *Formatter, allocator: std.mem.Allocator, content: [:0]const u8) ![]u8 {
        self.file_string.init(content.len);

        var parser = Parser.init(content);

        var elements = try parser.parse(allocator);
        defer elements.deinit(allocator);
        defer for (elements.items) |*item| {
            item.deinit(allocator);
        };

        for (elements.items) |element| {
            if (element == Node.html_element) {
                try fileString.concat(element.html_element.name);
            }
        }

        return fileString.toString();
    }

    fn visit_node(element: Node, index: usize) void {
        switch (element) {
            .html_element => {},
            else => {},
        }
    }
};
