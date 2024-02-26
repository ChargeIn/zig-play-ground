//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const ast = @import("ast.zig");
const Attribute = @import("token.zig").Attribute;
const Node = ast.NgTemplateNode;
const HtmlElement = ast.HtmlElement;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

// ----------------------------------------------------------------
//                      TESTING - UTILS
// ----------------------------------------------------------------
fn test_equals(content: [:0]const u8, nodes: []const Node) !void {
    const allocator = std.testing.allocator;

    var parser = Parser.init();

    var elements = try parser.parse(content, allocator);

    try expectEqual(elements.items.len, nodes.len);

    for (nodes, 0..) |node, i| {
        try test_equal_nodes(node, elements.items[i]);
    }

    for (elements.items) |*el| {
        el.deinit(allocator);
    }

    defer elements.deinit(allocator);
}

fn test_equal_nodes(n1: Node, n2: Node) !void {
    if (n1 == .html_element and n2 == .html_element) {
        expect(std.mem.eql(u8, n1.html_element.name, n2.html_element.name)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };

        expectEqual(n1.html_element.self_closing, n2.html_element.self_closing) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };

        expectEqual(n1.html_element.attributes.items.len, n2.html_element.attributes.items.len) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };

        expectEqual(n1.html_element.children.items.len, n2.html_element.children.items.len) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };

        for (n1.html_element.children.items, 0..) |item, i| {
            try test_equal_nodes(item, n2.html_element.children.items[i]);
        }
    } else if (n1 == .text and n2 == .text) {
        expect(std.mem.eql(u8, n1.text, n2.text)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };
    } else {
        return error.InvalidNodeType;
    }
}

// ----------------------------------------------------------------
//                         TESTS
// ----------------------------------------------------------------
test "rawtext" {
    const content: [:0]const u8 = "Some random html text.";

    const nodes = [_]Node{
        Node{ .text = "Some random html text." },
    };

    try test_equals(content, &nodes);
}

test "div" {
    const content: [:0]const u8 = "<div><div>Hello</div> World<div/></div>";

    var firstDiv = HtmlElement{
        .name = "div",
        .self_closing = false,
        .attributes = std.ArrayListUnmanaged(Attribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    var secondDiv = HtmlElement{
        .name = "div",
        .self_closing = false,
        .attributes = std.ArrayListUnmanaged(Attribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    const text1 = Node{ .text = "Hello" };
    const text2 = Node{ .text = "World" };

    const thirdDiv = HtmlElement{
        .name = "div",
        .self_closing = true,
        .attributes = std.ArrayListUnmanaged(Attribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    const allocator = std.testing.allocator;
    try firstDiv.children.append(allocator, Node{ .html_element = secondDiv });
    try firstDiv.children.append(allocator, text2);
    try firstDiv.children.append(allocator, Node{ .html_element = thirdDiv });
    defer firstDiv.children.deinit(allocator);

    try secondDiv.children.append(allocator, text1);
    defer secondDiv.children.deinit(allocator);

    var nodes = [_]Node{Node{ .html_element = firstDiv }};

    try test_equals(content, &nodes);
}
