//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const Options = @import("options.zig").NgTemplateFormatterOptions;
const utils = @import("utils");
const FileString = utils.FileString;
const StringError = utils.StringError;
const ast = @import("ast.zig");
const Node = ast.NgTemplateNode;
const HtmlElement = ast.HtmlElement;
const HtmlAttribute = ast.HtmlAttribute;

pub const NgTemplateFormatter = Formatter;

const Formatter = struct {
    options: Options,
    allocator: std.mem.Allocator,
    file_string: FileString,
    html_elements: std.StringHashMapUnmanaged(bool),

    pub fn init(allocator: std.mem.Allocator, options: Options) StringError!Formatter {
        return .{
            .options = options,
            .allocator = allocator,
            .file_string = FileString.empty(allocator),
            .html_elements = try createHtmlElements(allocator),
        };
    }

    pub fn deinit(self: *Formatter) void {
        self.html_elements.deinit(self.allocator);
        self.file_string.deinit();
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
            try self.visitNode(element, 0);
        }

        return self.file_string.toString();
    }

    fn visitNode(self: *Formatter, element: *Node, indent: usize) StringError!void {
        switch (element.*) {
            .html_element => {
                try self.writeHtmlElement(element.html_element, indent);
            },
            .comment => {
                try self.writeComment(element, indent);
            },
            .text => {
                try self.writeText(element, indent);
            },
            else => {},
        }
    }

    fn writeHtmlElement(self: *Formatter, html_element: HtmlElement, indent: usize) StringError!void {

        // check if self closing or auto closing
        if (html_element.self_closing or self.shouldAutoClose(html_element)) {
            try self.writeSelfClosingTag(html_element, indent);
            return;
        }

        try self.writeOpenTag(html_element, indent);

        const new_indent = indent + self.options.tab_width;

        for (html_element.children.items) |*child| {
            try self.visitNode(child, new_indent);
        }

        try self.writeClosingTag(html_element, indent);
    }

    fn writeSelfClosingTag(self: *Formatter, element: HtmlElement, indent: usize) StringError!void {
        try self.file_string.ensure_capacity(indent + element.name.len + 5);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<");
        self.file_string.concat_assume_capacity(element.name);
        try self.writeAttributes(element, indent);
        self.file_string.concat_assume_capacity("/>\n");
    }

    fn writeOpenTag(self: *Formatter, element: HtmlElement, indent: usize) StringError!void {
        try self.file_string.ensure_capacity(indent + element.name.len + 4);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<");
        self.file_string.concat_assume_capacity(element.name);
        try self.writeAttributes(element, indent);
        self.file_string.concat_assume_capacity(">");

        if (element.children.items.len > 0) {
            self.file_string.concat_assume_capacity("\n");
        }
    }

    fn writeClosingTag(self: *Formatter, element: HtmlElement, indent: usize) StringError!void {
        try self.file_string.ensure_capacity(indent + element.name.len + 5);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("</");
        self.file_string.concat_assume_capacity(element.name);
        self.file_string.concat_assume_capacity(">\n");
    }

    fn writeAttributes(self: *Formatter, node: HtmlElement, indent: usize) StringError!void {
        const attr_indent: usize = indent + self.options.tab_width;

        self.sortAttirbutes(node.attributes);

        for (node.attributes.items) |*attr| {
            // ensure max possible combination e.g. two way binding ("[(") and value (=\") + new lines
            // new lines (2 chars) + wrapper around name (4 chars) + equals signs and wrapper quotes (3) + name, value, indent len
            try self.file_string.ensure_capacity(attr_indent + 9 + attr.name.len + attr.value.len);

            self.file_string.concat_assume_capacity("\n");
            self.file_string.indent_assume_capacity(attr_indent);
            self.writeAttribute(attr);
        }

        if (node.attributes.items.len > 0) {
            try self.file_string.concat("\n");
            try self.file_string.indent(indent);
        }
    }

    fn sortAttirbutes(self: *Formatter, attributes: std.ArrayListUnmanaged(HtmlAttribute)) void {
        if (attributes.items.len == 0) {
            return;
        }

        var i: usize = 0;

        for (self.options.attribute_order.items) |order_type| {
            for (i..attributes.items.len) |j| {
                if (attributes.items[j].type == order_type) {
                    // switch the item with the first unsorted item in the list
                    const item = attributes.items[i];
                    attributes.items[i] = attributes.items[j];
                    attributes.items[j] = item;
                    i += 1;
                }
            }
        }
    }

    fn writeAttribute(self: *Formatter, attr: *HtmlAttribute) void {
        // we already assumed capacity in the write attributes function
        switch (attr.type) {
            .static => {
                self.file_string.concat_assume_capacity(attr.name);
            },
            .one_way => {
                self.file_string.concat_assume_capacity("[");
                self.file_string.concat_assume_capacity(attr.name);
                self.file_string.concat_assume_capacity("]");
            },
            .two_way => {
                self.file_string.concat_assume_capacity("[(");
                self.file_string.concat_assume_capacity(attr.name);
                self.file_string.concat_assume_capacity(")]");
            },
            .output => {
                self.file_string.concat_assume_capacity("(");
                self.file_string.concat_assume_capacity(attr.name);
                self.file_string.concat_assume_capacity(")");
            },
        }

        if (attr.has_value) {
            self.file_string.concat_assume_capacity("=\"");
            self.file_string.concat_assume_capacity(attr.value);
            self.file_string.concat_assume_capacity("\"");
        }
    }

    fn writeComment(self: *Formatter, node: *Node, indent: usize) StringError!void {
        try self.file_string.ensure_capacity(indent + node.comment.len);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity("<-- ");
        self.file_string.concat_assume_capacity(node.comment);
        self.file_string.concat_assume_capacity(" -->");
    }

    fn writeText(self: *Formatter, node: *Node, indent: usize) StringError!void {
        try self.file_string.ensure_capacity(indent + node.text.len + 1);

        self.file_string.indent_assume_capacity(indent);
        self.file_string.concat_assume_capacity(node.text);
        self.file_string.concat_assume_capacity("\n");
    }

    inline fn shouldAutoClose(self: *Formatter, html_element: HtmlElement) bool {
        return self.options.auto_self_close and html_element.children.items.len == 0 and self.html_elements.get(html_element.name) != true;
    }
};

fn createHtmlElements(allocator: std.mem.Allocator) StringError!std.StringHashMapUnmanaged(bool) {
    var map = std.StringHashMapUnmanaged(bool){};
    map.ensureTotalCapacity(allocator, 108) catch {
        return StringError.OutOfMemory;
    };

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
    map.putAssumeCapacity("h2", true);
    map.putAssumeCapacity("h3", true);
    map.putAssumeCapacity("h4", true);
    map.putAssumeCapacity("h5", true);
    map.putAssumeCapacity("h6", true);
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
