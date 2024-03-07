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
    lexer: Lexer,

    pub fn init(buffer: [:0]const u8) Parser {
        var lexer = Lexer.init(buffer);
        return Parser{ .lexer = lexer };
    }

    pub fn parse(self: *Parser, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(Node) {
        var token = try self.lexer.next(allocator);

        var elements = std.ArrayListUnmanaged(Node){};

        while (token != .eof) : (token = try self.lexer.next(allocator)) {
            std.debug.print("Parsed token: {any}\n", .{token});
            std.debug.print("node token: {any}\n", .{elements});

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

                    if (tag.self_closing == false) {
                        html_element.html_element.children = try self.parse(allocator);
                    }
                    try elements.append(allocator, html_element);
                },
                .end_tag => {
                    return elements;
                },
                .comment => {
                    try elements.append(allocator, Node{ .doc_type = token.comment });
                },
                .doc_type => {
                    try elements.append(allocator, Node{ .doc_type = token.doc_type });
                },
                .cdata => {
                    try elements.append(allocator, Node{ .cdata = token.cdata });
                },
                .text => {
                    try elements.append(allocator, Node{ .text = token.text });
                },
                .eof => {
                    try elements.append(allocator, Node.eof);
                },
            }
        }

        for (elements.items, 0..) |*el, i| {
            std.debug.print("Element {d}: {any}\n", .{ i, el });
        }

        return elements;
    }
};
