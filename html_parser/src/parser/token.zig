// Note we assume that the content of the file is valid utf+8
// Based on the offical standard https://html.spec.whatwg.org/multipage/parsing.html
pub const TokenType = enum {
    doc_type,
    start_tag,
    end_tag,
    comment,
    character,
    eof,
};

pub const Token = union(TokenType) {
    doc_type: struct {
        name: ?[]const u8,
        public_id: ?[]const u8,
        system_id: ?[]const u8,
        force_quirks: bool,
    },
    start_tag: struct {
        name: []const u8,
        self_closing: bool,
        attributes: []TagAttribute,
    },
    end_tag: struct { name: []u8 },
    comment: []u8,
    character: u8,
    eof,
};

pub const TagAttribute = struct {
    name: []u8,
    value: []u8,
};
