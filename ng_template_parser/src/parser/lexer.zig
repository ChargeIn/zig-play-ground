//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;

// For a good referenz see https://github.com/ziglang/zig/blob/master/lib/std/zig/tokenizer.zig

pub const NgTemplateLexer = Lexer;

const TAB = 0x09;
const LINE_FEED = 0x0A;
const FORM_FEED = 0x0C;
const SPACE = 0x20;

const NgTemplateLexerErrors = error{
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

const Lexer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) Lexer {
        // Skip the UTF-8 BOM if present
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Lexer{
            .buffer = buffer,
            .index = src_start,
        };
    }

    // Note: To optimize we assume the html is correct, otherwise the tokenizer will emit eof and set the error state
    pub fn next(self: *Lexer, allocator: std.mem.Allocator) !Token {
        const char = self.buffer[self.index];

        std.debug.print("\n -------- Started parsing next token --------\nStart with Char: '{c}'\n", .{char});
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

    fn parse_text(self: *Lexer) Token {
        std.debug.print("Started parsing text: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        var char = self.buffer[self.index];
        const start = self.index;

        while (char != '<' and char != 0) {
            self.index += 1;
            char = self.buffer[self.index];
        }
        return Token{ .text = self.buffer[start..self.index] };
    }

    fn parse_tag(self: *Lexer, allocator: std.mem.Allocator) !Token {
        std.debug.print("Started parsing tag : Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        // skip '<' token
        self.index += 1;

        var char = self.buffer[self.index];

        switch (char) {
            'A'...'Z', 'a'...'z' => {
                return self.parse_open_tag(allocator);
            },
            '!' => {
                return self.parse_markup();
            },
            '/' => {
                return self.parse_closing_tag();
            },
            '?' => {
                return NgTemplateLexerErrors.UnexpectedQuestionMarkInsteadOfTagName;
            },
            0 => {
                return NgTemplateLexerErrors.EofBeforeTagName;
            },
            else => {
                return NgTemplateLexerErrors.InvalidFirstCharacterOfTagName;
            },
        }
    }

    fn parse_markup(self: *Lexer) !Token {
        std.debug.print("Started parsing markup: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        // skip '!' character
        self.index += 1;

        const char = self.buffer[self.index];

        switch (char) {
            '-' => {
                return self.parse_comment();
            },
            'D', 'd' => {
                return self.parse_doc_type();
            },
            '[' => {
                return self.parse_cdata();
            },
            else => {
                return NgTemplateLexerErrors.IncorrectlyOpenedComment;
            },
        }
    }

    fn parse_comment(self: *Lexer) !Token {
        // skip '-' character
        self.index += 1;

        var char = self.buffer[self.index];

        if (char != '-') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }
        self.index += 1;

        const start = self.index;

        while (true) : (self.index += 1) {
            char = self.buffer[self.index];

            switch (char) {
                '-' => {
                    self.index += 1;
                    char = self.buffer[self.index];

                    if (char != '-') {
                        continue;
                    }

                    self.index += 1;
                    char = self.buffer[self.index];

                    if (char != '>') {
                        continue;
                    }
                    self.index += 1;

                    return Token{ .comment = self.buffer[start..(self.index - 3)] };
                },
                0 => {
                    return NgTemplateLexerErrors.EofInComment;
                },
                else => {},
            }
        }
    }

    fn parse_doc_type(self: *Lexer) !Token {
        // Note: Since this token is not really used in the context of angular templates we will not validate it but
        // keep the content as string
        self.index += 1;
        var char = self.buffer[self.index];

        if (char != 'O' and char != 'o') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'C' and char != 'c') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'T' and char != 't') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'Y' and char != 'y') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'P' and char != 'p') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'E' and char != 'e') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }
        self.index += 1;

        const start = self.index;
        while (char != '>' and char != 0) : (self.index += 1) {
            char = self.buffer[self.index];
        }

        if (char == 0) {
            return NgTemplateLexerErrors.EofInDoctype;
        }

        return Token{ .doc_type = self.buffer[start..(self.index - 1)] };
    }

    fn parse_cdata(self: *Lexer) !Token {
        // Note: Since this token is not really used in the context of angular templates we will not validate it but
        // keep the content as string
        self.index += 1;
        var char = self.buffer[self.index];

        if (char != 'C') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'D') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'A') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'T') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != 'A') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;
        char = self.buffer[self.index];

        if (char != '[') {
            return NgTemplateLexerErrors.IncorrectlyOpenedComment;
        }

        self.index += 1;

        const start = self.index;
        while (true) : (self.index += 1) {
            char = self.buffer[self.index];

            switch (char) {
                0 => {
                    return NgTemplateLexerErrors.EofInCdata;
                },
                ']' => {
                    self.index += 1;
                    char = self.buffer[self.index];

                    if (char != ']') {
                        continue;
                    }

                    self.index += 1;
                    char = self.buffer[self.index];

                    if (char != '>') {
                        continue;
                    }
                    self.index += 1;

                    return Token{ .cdata = self.buffer[start..(self.index - 4)] };
                },
                else => {},
            }
        }
    }

    fn parse_open_tag(self: *Lexer, allocator: std.mem.Allocator) !Token {
        std.debug.print("Started parsing open tag: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        const name = try self.parse_tag_name();
        const attributes = try self.parse_attributes(allocator);
        var self_closing = false;

        if (self.buffer[self.index] == '/') {
            self_closing = true;
            self.index += 1;
        }

        if (self.buffer[self.index] != '>') {
            if (self.buffer[self.index] == 0) {
                return NgTemplateLexerErrors.EofInTag;
            } else {
                return NgTemplateLexerErrors.UnexpectedSolidusInTag;
            }
        }
        self.index += 1;

        return Token{ .start_tag = tokens.StartTag.init(name, self_closing, attributes) };
    }

    fn parse_closing_tag(self: *Lexer) !Token {
        std.debug.print("Started parsing closing tag: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

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
                    return NgTemplateLexerErrors.EofInTag;
                },
                else => {
                    return NgTemplateLexerErrors.UnsupportedTokenException;
                },
            }
        }
    }

    // Note: Assumes that the first character is ASCII alpha
    fn parse_tag_name(self: *Lexer) ![]const u8 {
        std.debug.print("Started parsing tag name: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

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
                    return NgTemplateLexerErrors.EofInTag;
                },
                else => {},
            }
        }

        return self.buffer[start..self.index];
    }

    fn parse_attributes(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(tokens.Attribute) {
        std.debug.print("Started parsing attributes: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        var attribute_list = std.ArrayListUnmanaged(tokens.Attribute){};

        while (true) {
            const char = self.buffer[self.index];

            switch (char) {
                '>', '/' => {
                    break;
                },
                TAB, LINE_FEED, FORM_FEED, SPACE => {
                    // ignore
                    self.index += 1;
                },
                0 => {
                    attribute_list.deinit(allocator);
                    return NgTemplateLexerErrors.EofInTag;
                },
                '=' => {
                    attribute_list.deinit(allocator);
                    return NgTemplateLexerErrors.UnexpectedEqualsSignBeforeAttributeName;
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

    fn parse_attribute(self: *Lexer) !tokens.Attribute {
        std.debug.print("Started parsing attribute: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });
        const start = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            // we can assume that at name is not empty and the first char belongs to it
            switch (char) {
                0 => {
                    return NgTemplateLexerErrors.EofInTag;
                },
                '\'', '<', '"' => {
                    return NgTemplateLexerErrors.UnexpectedCharacterInAttributeName;
                },
                '/', '>' => {
                    return tokens.Attribute.init(self.buffer[start..self.index], "");
                },
                TAB, LINE_FEED, FORM_FEED, SPACE, '=' => {
                    break;
                },
                else => {},
            }
        }

        const name_end = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                0 => return NgTemplateLexerErrors.EofInTag,
                '\'', '<', '"' => {
                    return NgTemplateLexerErrors.UnexpectedCharacterInAttributeName;
                },
                '/', '>' => {
                    return tokens.Attribute.init(self.buffer[start..self.index], "");
                },
                '=' => {
                    const name = self.buffer[start..name_end];

                    self.index += 1;
                    const value = try self.parse_attribute_value();

                    return tokens.Attribute.init(name, value);
                },
                TAB, LINE_FEED, FORM_FEED, SPACE => {},
                else => {
                    return tokens.Attribute.init(self.buffer[start..name_end], "");
                },
            }
        }
    }

    fn parse_attribute_value(self: *Lexer) ![]const u8 {
        std.debug.print("Started parsing attribute value: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        // remove white space characters before the value parsing
        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                TAB, LINE_FEED, FORM_FEED, SPACE => {},
                else => break,
            }
        }

        const char = self.buffer[self.index];

        switch (char) {
            '\'' => {
                return self.parse_single_quoted_value();
            },
            '"' => {
                return self.parse_double_quoted_value();
            },
            '>' => {
                return NgTemplateLexerErrors.MissingAttributeValue;
            },
            else => {
                return self.parse_unquoted_value();
            },
        }
    }

    fn parse_single_quoted_value(self: *Lexer) ![]const u8 {
        std.debug.print("Started parsing attribute single quoted value: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        // skip '\'' character
        self.index += 1;

        const start = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                0 => {
                    return NgTemplateLexerErrors.EofInTag;
                },
                '\'' => {
                    const end = self.index;
                    self.index += 1;
                    return self.buffer[start..end];
                },
                else => {},
            }
        }
    }

    fn parse_double_quoted_value(self: *Lexer) ![]const u8 {
        std.debug.print("Started parsing attribute double quoted value: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });

        // skip '"' character
        self.index += 1;

        const start = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                0 => {
                    return NgTemplateLexerErrors.EofInTag;
                },
                '"' => {
                    const end = self.index;
                    self.index += 1;
                    return self.buffer[start..end];
                },
                else => {},
            }
        }
    }

    fn parse_unquoted_value(self: *Lexer) ![]const u8 {
        std.debug.print("Started parsing attribute unquoted value: Line: {any} Char: '{c}'\n", .{ self.index, self.buffer[self.index] });
        const start = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                0 => {
                    return NgTemplateLexerErrors.EofInTag;
                },
                TAB, LINE_FEED, FORM_FEED, SPACE, '>' => {
                    return self.buffer[start..self.index];
                },
                '"', '\'', '`', '<', '=' => {
                    return NgTemplateLexerErrors.UnexpectedCharacterInUnquotedAttributeValue;
                },
                else => {},
            }
        }
    }
};
