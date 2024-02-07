const std = @import("std");
const tokens = @import("token.zig");
const Token = tokens.NgTemplateToken;

// For a good referenz see https://github.com/ziglang/zig/blob/master/lib/std/zig/tokenizer.zig

pub const NgTemplateTokenzier = Tokenizer;

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,

    pub fn init(buffer: []const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Tokenizer{
            .buffer = buffer,
            .index = src_start,
        };
    }

    // taken from https://html.spec.whatwg.org/multipage/parsing.html#tokenization
    const State = enum {
        data,
        rcdata,
        rawtext,
        script_data,
        plaintext,
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
        Markup_declaration_open,
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

    pub fn next(self: *Tokenizer) Token {
        self.index += 1;
        return Token{ .comment = "test" };
    }
};
