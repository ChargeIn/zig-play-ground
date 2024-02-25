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
    elements: std.ArrayListUnmanaged(Node),
    current_layer: *std.ArrayListUnmanaged(Node),

    pub fn init() Parser {
        var elements = std.ArrayListUnmanaged(Node){};

        return Parser{
            .elements = elements,
            .current_layer = &elements,
        };
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(Node) {
        var lexer = Lexer.init(buffer);
        var token = try lexer.next(allocator);

        self.elements = std.ArrayListUnmanaged(Node){};
        self.current_layer = &self.elements;

        while (token != .eof) : (token = try lexer.next(allocator)) {
            std.debug.print("Parsed token: {any}\n", .{token});
            std.debug.print("node token: {any}\n", .{self.elements});

            switch (token) {
                .start_tag => |*tag| {
                    var html_element = Node{
                        .html_element = HtmlElement{
                            .name = tag.name,
                            .attributes = tag.attributes,
                            .self_closing = tag.self_closing,
                            .children = std.ArrayListUnmanaged(Node){},
                        },
                    };

                    try self.current_layer.*.append(allocator, html_element);

                    if (tag.self_closing == false) {
                        self.current_layer = &self.current_layer.items[self.current_layer.items.len - 1].html_element.children;
                    }
                },
                .end_tag => {},
                .comment => {
                    try self.current_layer.*.append(allocator, Node{ .doc_type = token.comment });
                },
                .doc_type => {
                    try self.current_layer.*.append(allocator, Node{ .doc_type = token.doc_type });
                },
                .cdata => {
                    try self.current_layer.*.append(allocator, Node{ .cdata = token.cdata });
                },
                .text => {
                    try self.current_layer.*.append(allocator, Node{ .text = token.text });
                },
                .eof => {
                    try self.current_layer.*.append(allocator, Node.eof);
                },
            }
        }

        for (self.elements.items, 0..) |*el, i| {
            std.debug.print("Element {d}: {any}\n", .{ i, el });
        }

        return self.elements;
    }
};
