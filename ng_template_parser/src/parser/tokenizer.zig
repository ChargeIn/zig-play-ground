const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;

// For a good referenz see https://github.com/ziglang/zig/blob/master/lib/std/zig/tokenizer.zig

pub const NgTemplateTokenzier = Tokenizer;

const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,
    state: State,
    return_state: State,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Tokenizer{
            .buffer = buffer,
            .index = src_start,
            .state = State.data,
            .return_state = State.data,
        };
    }

    // taken from https://html.spec.whatwg.org/multipage/parsing.html#tokenization
    const State = enum {
        data,
        rcdata,
        rawtext,
        script_data,
        // plaintext, deprecated
        tag_open,
        end_tag_open,
        tag_name,
        rcdata_less_than_sign,
        rcdata_end_tag_open,
        rcdata_end_tag_name,
        rawtext_less_than_sign,
        rawtext_end_tag_open,
        rawtext_end_tag_name,
        script_data_less_than_sign,
        script_data_end_tag_open,
        script_data_end_tag_name,
        script_data_escape_start,
        script_data_escape_start_dash,
        script_data_escaped,
        script_data_escaped_dash,
        script_data_escaped_dash_dash,
        script_data_escaped_less_than_sign,
        script_data_escaped_end_tag_open,
        script_data_escaped_end_tag_name,
        script_data_double_escape_start,
        script_data_double_escaped,
        script_data_double_escaped_dash,
        script_data_double_escaped_dash_dash,
        script_data_double_escaped_less_than_sign,
        script_data_double_escape_end,
        before_attribute_name,
        attribute_name,
        after_attribute_name,
        before_attribute_value,
        attribute_value_double_quoted,
        attribute_value_single_quoted,
        attribute_value_unquoted,
        after_attribute_value_quoted,
        self_closing_start_tag,
        bogus_comment,
        markup_declaration_open,
        comment_start,
        comment_start_dash,
        comment,
        comment_less_than_sign,
        comment_less_than_sign_bang,
        comment_less_than_sign_bang_dash,
        comment_less_than_sign_bang_dash_dash,
        comment_end_dash,
        comment_end,
        comment_end_bang,
        doctype,
        before_doctype_name,
        doctype_name,
        after_doctype_name,
        after_doctype_public_keyword,
        before_doctype_public_identifier,
        doctype_public_identifier_double_quoted,
        doctype_public_identifier_single_quoted,
        after_doctype_public_identifier,
        between_doctype_public_and_system_identifiers,
        after_doctype_system_keyword,
        before_doctype_system_identifier,
        doctype_system_identifier_double_quoted,
        doctype_system_identifier_single_quoted,
        after_doctype_system_identifier,
        bogus_doctype,
        cdata_section,
        cdata_section_bracket,
        cdata_section_end,
        character_reference,
        named_character_reference,
        ambiguous_ampersand,
        numeric_character_reference,
        hexadecimal_character_reference_start,
        decimal_character_reference_start,
        hexadecimal_character_reference,
        decimal_character_reference,
        numeric_character_reference_end,
    };

    pub fn readChar(self: *Tokenizer) u8 {
        const char = self.buffer[self.index];
        self.index += 1;
        return char;
    }

    pub fn next(self: *Tokenizer) !Token {
        while (true) : (self.index += 1) {
            const char = self.buffer[self.index];

            switch (self.state) {
                .data => switch (char) {
                    '&' => {
                        self.return_state = .data;
                        self.state = .character_reference;
                    },
                    '<' => {
                        self.state = .tag_open;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                    0 => {
                        return Token.eof;
                    },
                },
                .rcdata => switch (char) {
                    '&' => {
                        self.return_state = .rcdata;
                        self.state = .character_reference;
                    },
                    '<' => {
                        self.state = .rcdata_less_than_sign;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                    0 => {
                        return Token.eof;
                    },
                },
                .rawtext => switch (char) {
                    '<' => {
                        self.state = .rawtext_less_than_sign;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                    0 => {
                        return Token.eof;
                    },
                },
                .script_data => switch (char) {
                    '<' => {
                        self.state = .script_data_less_than_sign;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                    0 => {
                        return Token.eof;
                    },
                },
                .tag_open => switch (char) {
                    '!' => {
                        self.state = .markup_declaration_open;
                    },
                    '/' => {
                        self.state = .end_tag_open;
                    },
                    'a'...'z', 'A'...'Z', '0'...'9' => {},
                    '?' => {},
                    else => {
                        // This is an invalid-first-character-of-tag-name parse error. Emit a U+003C LESS-THAN SIGN character token. Reconsume in the data state.
                        return Token{ .character = '>' };
                    },
                    0 => {
                        // This is an eof-before-tag-name parse error. Emit a U+003C LESS-THAN SIGN character token and an end-of-file token.
                        return Token{ .character = '>' };
                    },
                },
                else => {
                    return Token{ .comment = "test" };
                },
            }
        }

        return Token{ .comment = "test" };
    }
};