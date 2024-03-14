//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const tokens = @import("ng_template").NgTemplateToken;
const Token = tokens.NgTemplateToken;
const StartTag = tokens.StartTag;
const EndTag = tokens.EndTag;
const Attribute = tokens.Attribute;
const NgTemplateLexer = @import("ng_template").NgTemplateLexer;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

// ----------------------------------------------------------------
//                      TESTING - UTILS
// ----------------------------------------------------------------
pub fn test_parse_content(content: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var token_list = std.ArrayList(Token).init(allocator);

    var ngTemplateLexer = NgTemplateLexer.init(content);

    var t = try ngTemplateLexer.next(allocator);

    while (t != Token.eof) {
        try token_list.append(t);
        t = try ngTemplateLexer.next(allocator);
    }
    return token_list;
}

pub fn test_tokenizer(content: [:0]const u8, expected_tokens: []const Token) !void {
    const allocator = std.testing.allocator;

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    expectEqual(expected_tokens.len, token_list.items.len) catch |err| {
        defer for (token_list.items) |*item| {
            item.deinit(allocator);
        };
        return err;
    };

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
        return;
    } else if (t1 == .doc_type and t2 == .doc_type) {
        // TODO;
    } else if (t1 == .cdata and t2 == .cdata) {
        expect(std.mem.eql(u8, t1.cdata, t2.cdata)) catch |err| {
            std.debug.print("Error: Expected '{any}' recieved '{any}'\n", .{ t1, t2 });
            return err;
        };
    } else {
        std.debug.print("Error: Expected Equal Types '{any}' recieved '{any}'\n", .{ t1, t2 });
        return error.UnequalTokenType;
    }
}

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) ![:0]u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const content = try file.readToEndAllocOptions(allocator, file_size, null, 1, 0);

    return content;
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

test "tag attributes" {
    const content: [:0]const u8 =
        \\<div
        \\   input1="value1"
        \\   input2='value2'
        \\   input3=value3
        \\   input4  =   value4
        \\   input5
        \\   input6>
    ;
    const allocator = std.testing.allocator;
    var attributes = std.ArrayListUnmanaged(Attribute){};
    defer attributes.deinit(allocator);

    try attributes.append(allocator, Attribute.init("input1", "value1"));
    try attributes.append(allocator, Attribute.init("input2", "value2"));
    try attributes.append(allocator, Attribute.init("input3", "value3"));
    try attributes.append(allocator, Attribute.init("input4", "value4"));
    try attributes.append(allocator, Attribute.init("input5", ""));
    try attributes.append(allocator, Attribute.init("input6", ""));

    const expected = [_]Token{
        Token{ .start_tag = StartTag.init("div", false, attributes) },
    };

    try test_tokenizer(content, &expected);
}

test "comment" {
    const content: [:0]const u8 = "<!--Hello &amp; <-> World! -->";
    const expected = [_]Token{Token{ .comment = "Hello &amp; <-> World! " }};

    try test_tokenizer(content, &expected);
}

test "doctype" {
    const content: [:0]const u8 =
        \\<!DOCTYPE html><!DocType html><!Doctype html><!doctype html><!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML      4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
    ;
    const expected = [_]Token{
        Token{ .doc_type = " html" },
        Token{ .doc_type = " html" },
        Token{ .doc_type = " html" },
        Token{ .doc_type = " html" },
        Token{ .doc_type = "  HTML PUBLIC \"-//W3C//DTD HTML      4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\"" },
    };

    try test_tokenizer(content, &expected);
}

test "cdata" {
    const content: [:0]const u8 = "<![CDATA[<div>-!#&8--!<!-->ds]] .!<\"§$%&/(]]>";
    const expected = [_]Token{Token{ .cdata = "<div>-!#&8--!<!-->ds]] .!<\"§$%&/(" }};

    try test_tokenizer(content, &expected);
}

test "parse all elements" {
    const allocator = std.testing.allocator;

    const content: [:0]u8 = readFile("tests/ng_template/data/all-no-media-elements.html", allocator) catch |err| {
        std.log.err("Could not read file: {any}", .{err});
        return;
    };
    defer allocator.free(content);

    var token_list = try test_parse_content(content, allocator);

    for (token_list.items) |*item| {
        item.deinit(allocator);
    }

    defer token_list.deinit();
}
