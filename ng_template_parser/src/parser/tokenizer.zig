const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;

// For a good referenz see https://github.com/ziglang/zig/blob/master/lib/std/zig/tokenizer.zig

pub const NgTemplateTokenzier = Tokenizer;

const TAB = 0x09;
const LINE_FEED = 0x0A;
const FORM_FEED = 0x0C;
const SPACE = 0x20;

const NgTemplateTokenizerErrors = error{
    AbruptClosingOfEmptyComment,
    AbruptDoctypePublicIdentifier,
    AbruptDoctypeSystemIdentifier,
    AbsenceOfDigitsInNumericCharacterReference,
    CdataInHtmlContent,
    CharacterReferenceOutsideUnicodeRange,
    ControlCharacterInInputStream,
    ControlCharacterReference,
    DuplicateAttribute,
    EndTagWithAttributes,
    EndTagWithTrailingSolidus,
    EofBeforeTagName,
    EofInCdata,
    EofInComment,
    EofInDoctype,
    EofInScriptHtmlCommentLikeText,
    EofInTag,
    IncorrectlyClosedComment,
    IncorrectlyOpenedComment,
    InvalidCharacterSequenceAfterDoctypeName,
    InvalidFirstCharacterOfTagName,
    MissingAttributeValue,
    MissingDoctypeName,
    MissingDoctypePublicIdentifier,
    MissingDoctypeSystemIdentifier,
    MissingEndTagName,
    MissingQuoteBeforeDoctypePublicIdentifier,
    MissingQuoteBeforeDoctypeSystemIdentifier,
    MissingSemicolonAfterCharacterReference,
    MissingWhitespaceAfterDoctypePublicKeyword,
    MissingWhitespaceAfterDoctypeSystemKeyword,
    MissingWhitespaceBeforeDoctypeName,
    MissingWhitespaceBetweenAttributes,
    MissingWhitespaceBetweenDoctypePublicAndSystemIdentifiers,
    NestedComment,
    NoncharacterCharacterReference,
    NoncharacterInInputStream,
    NonVoidHtmlElementStartTagWithTrailingSolidus,
    NullCharacterReference,
    SurrogateCharacterReference,
    SurrogateInInputStream,
    UnexpectedCharacterAfterDoctypeSystemIdentifier,
    UnexpectedCharacterInAttributeName,
    UnexpectedCharacterInUnquotedAttributeValue,
    UnexpectedEqualsSignBeforeAttributeName,
    UnexpectedNullCharacter,
    UnexpectedQuestionMarkInsteadOfTagName,
    UnexpectedSolidusInTag,
    UnknownNamedCharacterReference,
    UnsupportedTokenException,
};

const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Tokenizer{
            .buffer = buffer,
            .index = src_start,
        };
    }

    // Note: To optimize we assume the html is correct, otherwise the tokenizer will emit eof and set the error state
    pub fn next(self: *Tokenizer, allocator: std.mem.Allocator) !Token {
        const char = self.buffer[self.index];

        switch (char) {
            '<' => {
                return self.parse_tag(allocator);
            },
            0 => {
                return Token.eof;
            },
            else => {
                return self.parse_text();
            },
        }
    }

    pub fn parse_text(self: *Tokenizer) Token {
        std.log.info("Started parsing text: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        var char = self.buffer[self.index];
        const start = self.index;

        while (char != '<' and char != 0) {
            self.index += 1;
            char = self.buffer[self.index];
        }

        return Token{ .text = self.buffer[start..self.index] };
    }

    pub fn parse_tag(self: *Tokenizer, allocator: std.mem.Allocator) !Token {
        std.log.info("Started parsing tag : Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        // skip '<' token
        self.index += 1;

        var char = self.buffer[self.index];

        switch (char) {
            'A'...'Z', 'a'...'z' => {
                return self.parse_open_tag(allocator);
            },
            '!' => {
                // TODO
            },
            '/' => {
                return self.parse_closing_tag();
            },
            '?' => {
                return NgTemplateTokenizerErrors.UnexpectedQuestionMarkInsteadOfTagName;
            },
            0 => {
                return NgTemplateTokenizerErrors.EofBeforeTagName;
            },
            else => {
                return NgTemplateTokenizerErrors.InvalidFirstCharacterOfTagName;
            },
        }

        return Token.eof;
    }

    pub fn parse_open_tag(self: *Tokenizer, allocator: std.mem.Allocator) !Token {
        std.log.info("Started parsing open tag: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        const name = try self.parse_tag_name();
        const attributes = try self.parse_attributes(allocator);
        var self_closing = false;

        if (self.buffer[self.index] == '/') {
            self_closing = true;
            self.index += 1;
        }

        if (self.buffer[self.index] != '>') {
            if (self.buffer[self.index] == 0) {
                return NgTemplateTokenizerErrors.EofInTag;
            } else {
                return NgTemplateTokenizerErrors.UnexpectedSolidusInTag;
            }
        }
        self.index += 1;

        return Token{ .start_tag = tokens.StartTag.init(name, self_closing, attributes) };
    }

    pub fn parse_closing_tag(self: *Tokenizer) !Token {
        std.log.info("Started parsing closing tag: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        // skip '/' token
        self.index += 1;

        const name = try self.parse_tag_name();

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];
            switch (char) {
                TAB, LINE_FEED, FORM_FEED, SPACE => {
                    // ignore
                },
                '>' => {
                    self.index += 1;
                    return Token{ .end_tag = tokens.EndTag.init(name) };
                },
                0 => {
                    return NgTemplateTokenizerErrors.EofInTag;
                },
                else => {
                    return NgTemplateTokenizerErrors.UnsupportedTokenException;
                },
            }
        }
    }

    // Note: Assumes that the first character is ASCII alpha
    pub fn parse_tag_name(self: *Tokenizer) ![]const u8 {
        std.log.info("Started parsing tag name: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        const start = self.index;

        var char: u8 = 0;

        // parse name
        while (true) : (self.index += 1) {
            char = self.buffer[self.index];

            switch (char) {
                TAB, LINE_FEED, FORM_FEED, SPACE, '/', '>' => {
                    break;
                },
                0 => {
                    return NgTemplateTokenizerErrors.EofInTag;
                },
                else => {},
            }
        }

        return self.buffer[start..self.index];
    }

    pub fn parse_attributes(self: *Tokenizer, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(tokens.Attribute) {
        std.log.info("Started parsing attributes: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });

        var attribute_list = std.ArrayListUnmanaged(tokens.Attribute){};

        var char: u8 = 0;

        while (true) : (self.index += 1) {
            char = self.buffer[self.index];

            switch (char) {
                '>', '/' => {
                    break;
                },
                TAB, LINE_FEED, FORM_FEED, SPACE => {
                    // ignore
                },
                0 => {
                    attribute_list.deinit(allocator);
                    return NgTemplateTokenizerErrors.EofInTag;
                },
                '=' => {
                    attribute_list.deinit(allocator);
                    return NgTemplateTokenizerErrors.UnexpectedEqualsSignBeforeAttributeName;
                },
                else => {
                    const attr = try self.parse_attribute();
                    attribute_list.append(allocator, attr) catch |err| {
                        attribute_list.deinit(allocator);
                        return err;
                    };
                },
            }
        }

        return attribute_list;
    }

    pub fn parse_attribute(self: *Tokenizer) !tokens.Attribute {
        std.log.info("Started parsing attribute: Line: {any} Char: {c}", .{ self.index, self.buffer[self.index] });
        return tokens.Attribute.init("name", "value");
    }
};

// ----------------------------------------------------------------
//                      TESTING
// ----------------------------------------------------------------
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test "rawtext" {
    const allocator = std.testing.allocator;

    const content: [:0]const u8 = "Some random html text";

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    try expectEqual(token_list.items.len, 1);
    try expect(token_list.items[0] == Token.text);
    try expect(std.mem.eql(u8, token_list.items[0].text, content));
}

test "simple div tag" {
    const allocator = std.testing.allocator;

    const content: [:0]const u8 = "<div>Hello World</div>";

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    try expectEqual(token_list.items.len, 3);
    try expect(token_list.items[0] == Token.start_tag);
    try expect(token_list.items[1] == Token.text);
    try expect(token_list.items[2] == Token.end_tag);
    try expect(std.mem.eql(u8, token_list.items[0].start_tag.name, "div"));
    try expectEqual(token_list.items[0].start_tag.self_closing, false);
    try expectEqual(token_list.items[0].start_tag.attributes.items.len, 0);
    try expect(std.mem.eql(u8, token_list.items[1].text, "Hello World"));
    try expect(std.mem.eql(u8, token_list.items[2].end_tag.name, "div"));
}

test "self closing tags" {
    const allocator = std.testing.allocator;

    const content: [:0]const u8 = "<div/>";

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    try expectEqual(token_list.items.len, 1);
    try expect(token_list.items[0] == Token.start_tag);
    try expect(std.mem.eql(u8, token_list.items[0].start_tag.name, "div"));
    try expectEqual(token_list.items[0].start_tag.self_closing, true);
    try expectEqual(token_list.items[0].start_tag.attributes.items.len, 0);
}

test "basic attribute" {
    const allocator = std.testing.allocator;

    const content: [:0]const u8 = "<div input=\"value\">";

    var token_list = try test_parse_content(content, allocator);
    defer token_list.deinit();

    try expectEqual(token_list.items.len, 1);
    try expect(token_list.items[0] == Token.start_tag);
    try expect(std.mem.eql(u8, token_list.items[0].start_tag.name, "div"));

    token_list.items[0].start_tag.attributes.deinit(allocator);
    for (token_list.items) |*token| {
        token.deinit(allocator);
    }
}

pub fn test_parse_content(content: [:0]const u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var token_list = std.ArrayList(Token).init(allocator);

    var ngTemplateTokenizer = NgTemplateTokenzier.init(content);

    var t = try ngTemplateTokenizer.next(allocator);
    while (t != Token.eof) {
        std.log.info("Parsed Token {any}", .{t});
        try token_list.append(t);
        t = try ngTemplateTokenizer.next(allocator);
    }
    return token_list;
}
