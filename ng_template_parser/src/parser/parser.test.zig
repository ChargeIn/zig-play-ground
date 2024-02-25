//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const ast = @import("ast.zig");
const Node = ast.NgTemplateNode;
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
    }
    if (n1 == .text and n2 == .text) {
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
    const allocator = std.testing.allocator;
    const content: [:0]const u8 = "<div>Hello World</div>";

    var parser = Parser.init();
    var elements = try parser.parse(content, allocator);

    for (elements.items) |*el| {
        el.deinit(allocator);
    }

    defer elements.deinit(allocator);
}
