//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Lexer = @import("lexer.zig").NgTemplateLexer;
const ast = @import("ast.zig");
const Node = ast.NgTemplateNode;
const HtmlElement = ast.HtmlElement;
const Token = @import("token.zig").NgTemplateToken;

pub const NgTemplateParser = Parser;

const Parser = struct {
    node: ?HtmlElement,

    pub fn init() Parser {
        return Parser{
            .node = null,
        };
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(Node) {
        var elements = std.ArrayListUnmanaged(Node){};

        var lexer = Lexer.init(buffer);
        var token = try lexer.next(allocator);

        while (token != .eof) {
            token = try lexer.next(allocator);

            switch (token) {
                .start_tag => |*tag| {
                    const html_element = Node{
                        .html_element = HtmlElement{
                            .name = tag.name,
                            .attributes = tag.attributes,
                            .self_closing = tag.self_closing,
                            .children = std.ArrayListUnmanaged(Node){},
                        },
                    };

                    if (self.node) |*node| {
                        try node.children.append(allocator, html_element);
                    } else {
                        try elements.append(allocator, html_element);
                    }

                    if (tag.self_closing == false) {
                        self.node = html_element.html_element;
                    }
                },
                .end_tag => {},
                .comment => {
                    const comment = Node{ .doc_type = token.comment };
                    if (self.node) |*node| {
                        try node.children.append(allocator, comment);
                    } else {
                        try elements.append(allocator, comment);
                    }
                },
                .doc_type => {
                    const doc_type = Node{ .doc_type = token.doc_type };
                    if (self.node) |*node| {
                        try node.children.append(allocator, doc_type);
                    } else {
                        try elements.append(allocator, doc_type);
                    }
                },
                .cdata => {
                    const cdata = Node{ .cdata = token.cdata };
                    if (self.node) |*node| {
                        try node.children.append(allocator, cdata);
                    } else {
                        try elements.append(allocator, cdata);
                    }
                },
                .text => {
                    const text = Node{ .text = token.text };
                    if (self.node) |*node| {
                        try node.children.append(allocator, text);
                    } else {
                        try elements.append(allocator, text);
                    }
                },
                .eof => {
                    if (self.node) |*node| {
                        try node.children.append(allocator, Node.eof);
                    } else {
                        try elements.append(allocator, Node.eof);
                    }
                },
            }
        }
        return elements;
    }
};
