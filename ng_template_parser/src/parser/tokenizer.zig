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
};

const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,
    state: State,
    return_state: State,
    error_state: ?NgTemplateTokenizerErrors,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Tokenizer{
            .buffer = buffer,
            .index = src_start,
            .state = State.data,
            .return_state = State.data,
            .error_state = null,
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

    pub inline fn reconsume_in(self: *Tokenizer, state: State) void {
        self.index -= 1;
        self.state = state;
    }

    pub fn next(self: *Tokenizer) !Token {
        var token: Token = Token.eof;

        while (true) : (self.index += 1) {
            var char = self.buffer[self.index];

            switch (self.state) {
                .data => switch (char) {
                    '&' => {
                        self.return_state = .data;
                        self.state = .character_reference;
                    },
                    '<' => {
                        self.state = .tag_open;
                    },
                    0 => {
                        return Token.eof;
                    },
                    else => {
                        return Token{ .character = char };
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
                    0 => {
                        return Token.eof;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                },
                .rawtext => switch (char) {
                    '<' => {
                        self.state = .rawtext_less_than_sign;
                    },
                    0 => {
                        return Token.eof;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                },
                .script_data => switch (char) {
                    '<' => {
                        self.state = .script_data_less_than_sign;
                    },
                    0 => {
                        return Token.eof;
                    },
                    else => {
                        return Token{ .character = char };
                    },
                },
                .tag_open => switch (char) {
                    '!' => {
                        self.state = .markup_declaration_open;
                    },
                    '/' => {
                        self.state = .end_tag_open;
                    },
                    'a'...'z', 'A'...'Z', '0'...'9' => {
                        var len: usize = 0;

                        while (true) {
                            switch (char) {
                                TAB, LINE_FEED, FORM_FEED, SPACE => {
                                    self.state = .before_attribute_name;
                                    break;
                                },
                                '/' => {
                                    self.state = .self_closing_start_tag;
                                    break;
                                },
                                '>' => {
                                    self.state = .data;
                                    return token;
                                },
                                0 => {
                                    self.error_state = NgTemplateTokenizerErrors.EofInTag;
                                    return Token.eof;
                                },
                                else => {
                                    len += 1;
                                },
                            }
                            self.index += 1;
                            char = self.buffer[self.index];
                        }

                        const start: usize = self.index - len;
                        const attrs: []tokens.TagAttribute = &.{};

                        token = Token{
                            .start_tag = tokens.StartTag{
                                .name = self.buffer[start..self.index],
                                .self_closing = false,
                                .attributes = attrs,
                            },
                        };
                    },
                    '?' => {
                        self.error_state = NgTemplateTokenizerErrors.UnexpectedQuestionMarkInsteadOfTagName;
                        self.reconsume_in(.bogus_comment);
                    },
                    0 => {
                        self.error_state = NgTemplateTokenizerErrors.EofBeforeTagName;
                        return Token{ .character = '>' };
                    },
                    else => {
                        self.error_state = NgTemplateTokenizerErrors.InvalidFirstCharacterOfTagName;
                        self.reconsume_in(.data);
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
