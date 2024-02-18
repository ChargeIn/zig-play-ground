const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;
const StartTag = tokens.StartTag;
const EndTag = tokens.EndTag;
const Attribute = tokens.Attribute;
const NgTemplateTokenzier = @import("tokenizer.zig").NgTemplateTokenzier;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

// ----------------------------------------------------------------
//                      TESTING - UTILS
// ----------------------------------------------------------------
pub fn test_parse_content(content: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var token_list = std.ArrayList(Token).init(allocator);

    var ngTemplateTokenizer = NgTemplateTokenzier.init(content);

    var t = try ngTemplateTokenizer.next(allocator);
    std.debug.print("Parsed Token {any}\n", .{t});
    while (t != Token.eof) {
        try token_list.append(t);
        t = try ngTemplateTokenizer.next(allocator);
        std.debug.print("Parsed Token {any}\n", .{t});
    }
    return token_list;
}

pub fn test_tokenizer(content: [:0]const u8, expected_tokens: []const Token) !void {
    const allocator = std.testing.allocator;

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    try expectEqual(expected_tokens.len, token_list.items.len);

    defer for (token_list.items) |*item| {
        item.deinit(allocator);
    };

    for (expected_tokens, 0..) |t1, i| {
        const t2 = token_list.items[i];
        try test_equal_tokens(t1, t2);
    }

    std.debug.print("\n", .{});
}

pub fn test_equal_tokens(t1: Token, t2: Token) !void {
    if (t1 == .start_tag and t2 == .start_tag) {
        expect(std.mem.eql(u8, t1.start_tag.name, t2.start_tag.name)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };

        expectEqual(t1.start_tag.self_closing, t2.start_tag.self_closing) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };

        expectEqual(t1.start_tag.attributes.items.len, t2.start_tag.attributes.items.len) catch |err| {
            std.debug.print("Error: Expected same number of attributes '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };

        for (t1.start_tag.attributes.items, 0..) |attr, i| {
            expect(std.mem.eql(u8, attr.name, t2.start_tag.attributes.items[i].name)) catch |err| {
                std.debug.print("Error: Expected Attribute '{any}' recieved '{any}'\n", .{ attr, t2.start_tag.attributes.items[i] });
                return err;
            };

            expect(std.mem.eql(u8, attr.value, t2.start_tag.attributes.items[i].value)) catch |err| {
                std.debug.print("Error: Expected Attribute Value '{any}' recieved '{any}'\n", .{ attr, t2.start_tag.attributes.items[i] });
                return err;
            };
        }
    } else if (t1 == .text and t2 == .text) {
        expect(std.mem.eql(u8, t1.text, t2.text)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };
    } else if (t1 == .end_tag and t2 == .end_tag) {
        expect(std.mem.eql(u8, t1.end_tag.name, t2.end_tag.name)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };
    } else if (t1 == .comment and t2 == .comment) {
        expect(std.mem.eql(u8, t1.comment, t2.comment)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };
    } else if (t1 == .eof and t2 == .eof) {
        // accept
    } else if (t1 == .doc_type and t2 == .doc_type) {
        // TODO
    }
}

// ----------------------------------------------------------------
//                      TESTING
// ----------------------------------------------------------------

test "rawtext" {
    const content: [:0]const u8 = "Some random html text.";
    const expected = [_]Token{Token{ .text = "Some random html text." }};

    try test_tokenizer(content, &expected);
}

test "simple div tag" {
    const content: [:0]const u8 = "<div>Hello World</div>";
    const expected = [_]Token{
        Token{ .start_tag = StartTag.init("div", false, .{}) },
        Token{ .text = "Hello World" },
        Token{ .end_tag = EndTag.init("div") },
    };

    try test_tokenizer(content, &expected);
}

test "self closing tags" {
    const content: [:0]const u8 = "<div/>";
    const expected = [_]Token{Token{ .start_tag = StartTag.init("div", true, .{}) }};

    try test_tokenizer(content, &expected);
}

test "basic attribute" {
    const content: [:0]const u8 =
        \\<div
        \\  input1="value1"
        \\  input2='value2'
        \\  input3=value3
        \\  input4  =   value4
        \\>
    ;
    const allocator = std.testing.allocator;
    var attributes = std.ArrayListUnmanaged(Attribute){};
    defer attributes.deinit(allocator);

    try attributes.append(allocator, Attribute.init("input1", "value1"));
    try attributes.append(allocator, Attribute.init("input2", "value2"));
    try attributes.append(allocator, Attribute.init("input3", "value3"));
    try attributes.append(allocator, Attribute.init("input4", "value4"));

    const expected = [_]Token{
        Token{ .start_tag = StartTag.init("div", false, attributes) },
    };

    try test_tokenizer(content, &expected);
}