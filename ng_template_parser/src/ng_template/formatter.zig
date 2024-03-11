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
    html_elements: std.StringHashMapUnmanaged(bool),

    pub fn init(allocator: std.mem.Allocator, options: Options) !Formatter {
        return .{
            .options = options,
            .allocator = allocator,
            .file_string = FileString.empty(allocator),
            .html_elements = try create_html_elements(allocator),
        };
    }

    pub fn deinit(self: *Formatter) void {
        self.html_elements.deinit(self.allocator);
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
                try self.write_html_element(element.html_element, indent);
            },
            .comment => {
                try self.write_comment(element, indent);
            },
            .text => {
                try self.write_text(element, indent);
            },
            else => {},
        }
    }

    fn write_html_element(self: *Formatter, html_element: HtmlElement, indent: usize) !void {

        // check if self closing or auto closing
        if (html_element.self_closing or self.should_auto_close(html_element)) {
            try self.write_self_closing_tag(html_element, indent);
            return;
        }

        try self.write_open_tag(html_element, indent);

        const new_indent = indent + self.options.tab_width;

        for (html_element.children.items) |*child| {
            try self.file_string.indent(new_indent);
            try self.visit_node(child, new_indent);
        }

        try self.write_closing_tag(html_element, indent);
    }

    fn write_self_closing_tag(self: *Formatter, element: HtmlElement, indent: usize) !void {
        try self.file_string.ensure_capacity(indent + element.name.len + 5);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<");
        self.file_string.concat_assume_capacity(element.name);
        self.file_string.concat_assume_capacity("/>\n");
    }

    fn write_open_tag(self: *Formatter, element: HtmlElement, indent: usize) !void {
        try self.file_string.ensure_capacity(indent + element.name.len + 4);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<");
        self.file_string.concat_assume_capacity(element.name);
        self.file_string.concat_assume_capacity(">\n");
    }

    fn write_closing_tag(self: *Formatter, element: HtmlElement, indent: usize) !void {
        try self.file_string.ensure_capacity(indent + element.name.len + 5);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("</");
        self.file_string.concat_assume_capacity(element.name);
        self.file_string.concat_assume_capacity(">\n");
    }

    fn write_comment(self: *Formatter, node: *Node, indent: usize) !void {
        try self.file_string.ensure_capacity(indent + node.comment.len);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<-- ");
        self.file_string.concat_assume_capacity(node.comment);
        self.file_string.concat_assume_capacity(" -->");
    }

    fn write_text(self: *Formatter, node: *Node, indent: usize) !void {
        try self.file_string.ensure_capacity(indent + node.text.len);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity(node.text);
    }

    inline fn should_auto_close(self: *Formatter, html_element: HtmlElement) bool {
        return self.options.auto_self_close and html_element.children.items.len == 0 and self.html_elements.get(html_element.name) == true;
    }
};

fn create_html_elements(allocator: std.mem.Allocator) !std.StringHashMapUnmanaged(bool) {
    var map = std.StringHashMapUnmanaged(bool){};
    try map.ensureTotalCapacity(allocator, 108);

    map.putAssumeCapacity("a", true);
    map.putAssumeCapacity("abbr", true);
    map.putAssumeCapacity("address", true);
    map.putAssumeCapacity("area", true);
    map.putAssumeCapacity("article", true);
    map.putAssumeCapacity("aside", true);
    map.putAssumeCapacity("audio", true);
    map.putAssumeCapacity("b", true);
    map.putAssumeCapacity("base", true);
    map.putAssumeCapacity("bdi", true);
    map.putAssumeCapacity("bdo", true);
    map.putAssumeCapacity("blockquote", true);
    map.putAssumeCapacity("body", true);
    map.putAssumeCapacity("br", true);
    map.putAssumeCapacity("button", true);
    map.putAssumeCapacity("canvas", true);
    map.putAssumeCapacity("caption", true);
    map.putAssumeCapacity("cite", true);
    map.putAssumeCapacity("code", true);
    map.putAssumeCapacity("col", true);
    map.putAssumeCapacity("colgroup", true);
    map.putAssumeCapacity("data", true);
    map.putAssumeCapacity("datalist", true);
    map.putAssumeCapacity("dd", true);
    map.putAssumeCapacity("del", true);
    map.putAssumeCapacity("details", true);
    map.putAssumeCapacity("dfn", true);
    map.putAssumeCapacity("dialog", true);
    map.putAssumeCapacity("div", true);
    map.putAssumeCapacity("dl", true);
    map.putAssumeCapacity("dt", true);
    map.putAssumeCapacity("em", true);
    map.putAssumeCapacity("embed", true);
    map.putAssumeCapacity("fencedframe", true);
    map.putAssumeCapacity("fieldset", true);
    map.putAssumeCapacity("figcaption", true);
    map.putAssumeCapacity("figure", true);
    map.putAssumeCapacity("footer", true);
    map.putAssumeCapacity("form", true);
    map.putAssumeCapacity("h1", true);
    map.putAssumeCapacity("head", true);
    map.putAssumeCapacity("header", true);
    map.putAssumeCapacity("hgroup", true);
    map.putAssumeCapacity("hr", true);
    map.putAssumeCapacity("html", true);
    map.putAssumeCapacity("i", true);
    map.putAssumeCapacity("iframe", true);
    map.putAssumeCapacity("img", true);
    map.putAssumeCapacity("input", true);
    map.putAssumeCapacity("ins", true);
    map.putAssumeCapacity("kbd", true);
    map.putAssumeCapacity("label", true);
    map.putAssumeCapacity("legend", true);
    map.putAssumeCapacity("li", true);
    map.putAssumeCapacity("link", true);
    map.putAssumeCapacity("main", true);
    map.putAssumeCapacity("map", true);
    map.putAssumeCapacity("mark", true);
    map.putAssumeCapacity("menu", true);
    map.putAssumeCapacity("meta", true);
    map.putAssumeCapacity("meter", true);
    map.putAssumeCapacity("nav", true);
    map.putAssumeCapacity("noscript", true);
    map.putAssumeCapacity("object", true);
    map.putAssumeCapacity("ol", true);
    map.putAssumeCapacity("optgroup", true);
    map.putAssumeCapacity("option", true);
    map.putAssumeCapacity("output", true);
    map.putAssumeCapacity("p", true);
    map.putAssumeCapacity("picture", true);
    map.putAssumeCapacity("portal", true);
    map.putAssumeCapacity("pre", true);
    map.putAssumeCapacity("progress", true);
    map.putAssumeCapacity("q", true);
    map.putAssumeCapacity("rp", true);
    map.putAssumeCapacity("rt", true);
    map.putAssumeCapacity("ruby", true);
    map.putAssumeCapacity("s", true);
    map.putAssumeCapacity("samp", true);
    map.putAssumeCapacity("script", true);
    map.putAssumeCapacity("search", true);
    map.putAssumeCapacity("section", true);
    map.putAssumeCapacity("select", true);
    map.putAssumeCapacity("slot", true);
    map.putAssumeCapacity("small", true);
    map.putAssumeCapacity("source", true);
    map.putAssumeCapacity("span", true);
    map.putAssumeCapacity("strong", true);
    map.putAssumeCapacity("style", true);
    map.putAssumeCapacity("sub", true);
    map.putAssumeCapacity("summary", true);
    map.putAssumeCapacity("sup", true);
    map.putAssumeCapacity("table", true);
    map.putAssumeCapacity("tbody", true);
    map.putAssumeCapacity("td", true);
    map.putAssumeCapacity("template", true);
    map.putAssumeCapacity("textarea", true);
    map.putAssumeCapacity("tfoot", true);
    map.putAssumeCapacity("th", true);
    map.putAssumeCapacity("thead", true);
    map.putAssumeCapacity("time", true);
    map.putAssumeCapacity("title", true);
    map.putAssumeCapacity("tr", true);
    map.putAssumeCapacity("track", true);
    map.putAssumeCapacity("u", true);
    map.putAssumeCapacity("ul", true);
    map.putAssumeCapacity("var", true);
    map.putAssumeCapacity("video", true);
    map.putAssumeCapacity("wbr", true);
    return map;
}
