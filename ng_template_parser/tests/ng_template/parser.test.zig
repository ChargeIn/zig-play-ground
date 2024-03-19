//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("ng_template").NgTemplateParser;
const ast = @import("ng_template").NgTemplateAst;
const Node = ast.NgTemplateNode;
const HtmlElement = ast.HtmlElement;
const HtmlAttribute = ast.HtmlAttribute;
const HtmlAttributeType = ast.HtmlAttributeType;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

// ----------------------------------------------------------------
//                      TESTING - UTILS
// ----------------------------------------------------------------
fn test_equals(content: [:0]const u8, nodes: []const Node) !void {
    const allocator = std.testing.allocator;

    var parser = Parser.init(content);

    var elements = try parser.parse(allocator);

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

        for (n1.html_element.attributes.items, 0..) |attr1, i| {
            expect(std.mem.eql(u8, attr1.name, n2.html_element.attributes.items[i].name)) catch |err| {
                std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
                return err;
            };

            expect(std.mem.eql(u8, attr1.value, n2.html_element.attributes.items[i].value)) catch |err| {
                std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
                return err;
            };

            expectEqual(attr1.has_value, n2.html_element.attributes.items[i].has_value) catch |err| {
                std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
                return err;
            };

            expectEqual(attr1.type, n2.html_element.attributes.items[i].type) catch |err| {
                std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
                return err;
            };
        }
    } else if (n1 == .text and n2 == .text) {
        expect(std.mem.eql(u8, n1.text.raw, n2.text.raw)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ n1, n2 });
            return err;
        };

        expect(std.mem.eql(u8, n1.text.trimmed, n2.text.trimmed)) catch |err| {
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
        .{ .text = .{ .raw = "Some random html text.", .trimmed = "Some random html text." } },
    };

    try test_equals(content, &nodes);
}

test "div" {
    const content: [:0]const u8 = "<div><div>Hello</div> World<custom property staticInput=\"H\" [simpleBinding]=\"E\" [(doubleBinding)]=\"LL\" (output)=\"O\"/></div>";

    var firstDiv = HtmlElement{
        .name = "div",
        .self_closing = false,
        .attributes = std.ArrayListUnmanaged(HtmlAttribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    const secondDiv = HtmlElement{
        .name = "div",
        .self_closing = false,
        .attributes = std.ArrayListUnmanaged(HtmlAttribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    const text1 = Node{ .text = .{ .raw = "Hello", .trimmed = "Hello" } };
    const text2 = Node{ .text = .{ .raw = " World", .trimmed = "World" } };

    var thirdDiv = HtmlElement{
        .name = "custom",
        .self_closing = true,
        .attributes = std.ArrayListUnmanaged(HtmlAttribute){},
        .children = std.ArrayListUnmanaged(Node){},
    };

    const attr1 = HtmlAttribute{
        .name = "property",
        .value = "",
        .type = HtmlAttributeType.static,
        .has_value = false,
    };

    const attr2 = HtmlAttribute{
        .name = "staticInput",
        .value = "H",
        .type = HtmlAttributeType.static,
        .has_value = true,
    };

    const attr3 = HtmlAttribute{
        .name = "simpleBinding",
        .value = "E",
        .type = HtmlAttributeType.one_way,
        .has_value = true,
    };

    const attr4 = HtmlAttribute{
        .name = "doubleBinding",
        .value = "LL",
        .type = HtmlAttributeType.two_way,
        .has_value = true,
    };

    const attr5 = HtmlAttribute{
        .name = "output",
        .value = "O",
        .type = HtmlAttributeType.output,
        .has_value = true,
    };

    const allocator = std.testing.allocator;

    try thirdDiv.attributes.append(allocator, attr1);
    try thirdDiv.attributes.append(allocator, attr2);
    try thirdDiv.attributes.append(allocator, attr3);
    try thirdDiv.attributes.append(allocator, attr4);
    try thirdDiv.attributes.append(allocator, attr5);
    defer thirdDiv.attributes.deinit(allocator);

    try firstDiv.children.append(allocator, Node{ .html_element = secondDiv });
    try firstDiv.children.append(allocator, text2);
    try firstDiv.children.append(allocator, Node{ .html_element = thirdDiv });
    defer firstDiv.children.deinit(allocator);

    try firstDiv.children.items[0].html_element.children.append(allocator, text1);
    defer firstDiv.children.items[0].html_element.children.deinit(allocator);

    var nodes = [_]Node{Node{ .html_element = firstDiv }};

    try test_equals(content, &nodes);
}
