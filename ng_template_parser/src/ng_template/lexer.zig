//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;
const TextTag = tokens.TextTag;
const NgControlElement = tokens.NgControlElement;

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
    UnsupportedNgControlElement,
    EofInNgControlElement,
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

        switch (char) {
            '@' => {
                return self.parseNgControlElement();
            },
            '<' => {
                return self.parseTag(allocator);
            },
            0 => {
                return Token.eof;
            },
            else => {
                return self.parseText();
            },
        }
    }

    fn parseText(self: *Lexer) Token {
        var char = self.buffer[self.index];

        const rawStart = self.index;

        // trim starting whitespaces
        while (isWhiteSpace(char)) {
            self.index += 1;
            char = self.buffer[self.index];
        }

        const start = self.index;
        var end = self.index;

        while (char != '<' and char != 0) {
            // save last non white space index for trimming
            if (!isWhiteSpace(char)) {
                end = self.index;
            }

            self.index += 1;
            char = self.buffer[self.index];
        }

        // only if there are only white space characters keep it empty
        if (end != start) {
            end += 1;
        }

        return .{ .text = TextTag.init(self.buffer[rawStart..self.index], self.buffer[start..end]) };
    }

    fn parseTag(self: *Lexer, allocator: std.mem.Allocator) !Token {
        // skip '<' token
        self.index += 1;

        const char = self.buffer[self.index];

        switch (char) {
            'A'...'Z', 'a'...'z' => {
                return self.parseOpenTag(allocator);
            },
            '!' => {
                return self.parse_markup();
            },
            '/' => {
                return self.parseClosingTag();
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
        // skip '!' character
        self.index += 1;

        const char = self.buffer[self.index];

        switch (char) {
            '-' => {
                return self.parseComment();
            },
            'D', 'd' => {
                return self.parseDocType();
            },
            '[' => {
                return self.parseCData();
            },
            else => {
                return NgTemplateLexerErrors.IncorrectlyOpenedComment;
            },
        }
    }

    fn parseComment(self: *Lexer) !Token {
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

                    return .{ .comment = self.buffer[start..(self.index - 3)] };
                },
                0 => {
                    return NgTemplateLexerErrors.EofInComment;
                },
                else => {},
            }
        }
    }

    fn parseDocType(self: *Lexer) !Token {
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

        return .{ .doc_type = self.buffer[start..(self.index - 1)] };
    }

    fn parseCData(self: *Lexer) !Token {
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

                    return .{ .cdata = self.buffer[start..(self.index - 3)] };
                },
                else => {},
            }
        }
    }

    fn parseOpenTag(self: *Lexer, allocator: std.mem.Allocator) !Token {
        const name = try self.parseTagName();
        const attributes = try self.parseAttributes(allocator);
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

        return .{ .start_tag = tokens.StartTag.init(name, self_closing, attributes) };
    }

    fn parseClosingTag(self: *Lexer) !Token {
        // skip '/' token
        self.index += 1;

        const name = try self.parseTagName();

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];
            switch (char) {
                TAB, LINE_FEED, FORM_FEED, SPACE => {
                    // ignore
                },
                '>' => {
                    self.index += 1;
                    return .{ .end_tag = tokens.EndTag.init(name) };
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
    fn parseTagName(self: *Lexer) ![]const u8 {
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

    fn parseAttributes(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(tokens.Attribute) {
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
                    const attr = try self.parseAttribute();
                    attribute_list.append(allocator, attr) catch |err| {
                        attribute_list.deinit(allocator);
                        return err;
                    };
                },
            }
        }

        return attribute_list;
    }

    fn parseAttribute(self: *Lexer) !tokens.Attribute {
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
                    return tokens.Attribute.initNoValue(self.buffer[start..self.index]);
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
                    return tokens.Attribute.initNoValue(self.buffer[start..self.index]);
                },
                '=' => {
                    const name = self.buffer[start..name_end];

                    self.index += 1;
                    const value = try self.parseAttributeValue();

                    return tokens.Attribute.init(name, value);
                },
                TAB, LINE_FEED, FORM_FEED, SPACE => {},
                else => {
                    return tokens.Attribute.initNoValue(self.buffer[start..name_end]);
                },
            }
        }
    }

    fn parseAttributeValue(self: *Lexer) ![]const u8 {
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
                return self.parseSingleQuotedValue();
            },
            '"' => {
                return self.parseDoubleQuotedValue();
            },
            '>' => {
                return NgTemplateLexerErrors.MissingAttributeValue;
            },
            else => {
                return self.parseUnquotedValue();
            },
        }
    }

    fn parseSingleQuotedValue(self: *Lexer) ![]const u8 {
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

    fn parseDoubleQuotedValue(self: *Lexer) ![]const u8 {
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

    fn parseUnquotedValue(self: *Lexer) ![]const u8 {
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

    fn parseNgControlElement(self: *Lexer) !Token {
        // skip '@' char
        self.index += 1;

        // we need to parse the name of the control element to filter for else if statements
        var char = self.buffer[self.index];
        self.index += 1;

        switch (char) {
            // ng_if,
            'i' => {
                char = self.buffer[self.index];

                if (char != 'f') {
                    return NgTemplateLexerErrors.UnsupportedNgControlElement;
                }
                self.index += 1;
                const condition = try self.parseNgControlCondition();
                return .{ .ng_control_elment = NgControlElement.init(.ng_if, condition) };
            },
            // ng_case,
            'c' => {
                if (self.buffer[self.index] != 'a' or
                    self.buffer[self.index + 1] != 's' or
                    self.buffer[self.index + 2] != 'e')
                {
                    return NgTemplateLexerErrors.UnsupportedNgControlElement;
                }
                self.index += 3;
                const condition = try self.parseNgControlCondition();
                return .{ .ng_control_elment = NgControlElement.init(.ng_case, condition) };
            },
            // ng_default,
            // ng_defer
            'd' => {
                if (self.buffer[self.index] != 'e' or self.buffer[self.index + 1] != 'f') {
                    return NgTemplateLexerErrors.UnsupportedNgControlElement;
                }

                if (self.buffer[self.index + 2] != 'a' or
                    self.buffer[self.index + 3] != 'u' or
                    self.buffer[self.index + 4] != 'l' or
                    self.buffer[self.index + 5] != 't')
                {
                    self.index += 6;
                    const condition = try self.parseNgControlCondition();
                    return .{ .ng_control_elment = NgControlElement.init(.ng_default, condition) };
                }

                if (self.buffer[self.index + 2] != 'f' or
                    self.buffer[self.index + 3] != 'e' or
                    self.buffer[self.index + 4] != 'r')
                {
                    self.index += 5;
                    const condition = try self.parseNgControlCondition();
                    return .{ .ng_control_elment = NgControlElement.init(.ng_defer, condition) };
                }
            },
            // ng_else,
            // ng_else_if,
            // ng_empty,
            'e' => {
                if (self.buffer[self.index] == 'l') {
                    if (self.buffer[self.index + 1] != 's' or
                        self.buffer[self.index + 2] != 'e')
                    {
                        return NgTemplateLexerErrors.UnsupportedNgControlElement;
                    }

                    self.index += 3;
                    // test for else if

                } else if (self.buffer[self.index] == 'm') {
                    if (self.buffer[self.index] != 'e' or
                        self.buffer[self.index + 1] != 'f' or
                        self.buffer[self.index + 2] != 'a' or
                        self.buffer[self.index + 3] != 'u' or
                        self.buffer[self.index + 4] != 'l' or
                        self.buffer[self.index + 5] != 't')
                    {
                        return NgTemplateLexerErrors.UnsupportedNgControlElement;
                    }
                    self.index += 6;
                    const condition = try self.parseNgControlCondition();
                    return .{ .ng_control_elment = NgControlElement.init(.ng_default, condition) };
                } else {
                    return NgTemplateLexerErrors.UnsupportedNgControlElement;
                }
            },
            // ng_for,
            'f' => {},
            // ng_switch,
            's' => {},
            0 => {
                return NgTemplateLexerErrors.EofInNgControlElement;
            },
            else => {
                return NgTemplateLexerErrors.UnsupportedNgControlElement;
            },
        }
    }

    fn parseNgControlCondition(self: *Lexer) ![]const u8 {
        // skip opening brackets
        self.index += 1;

        const start = self.index;

        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (char) {
                ')' => {
                    const value = self.buffer[start..self.index];
                    self.index += 1;
                    return value;
                },
                0 => {
                    return NgTemplateLexerErrors.EofInNgControlElement;
                },
                else => {},
            }
        }
    }
};

inline fn isWhiteSpace(char: u8) bool {
    return char == SPACE or char == TAB or char == LINE_FEED or char == FORM_FEED;
}
