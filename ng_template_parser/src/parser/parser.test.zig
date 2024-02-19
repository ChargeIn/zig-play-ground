//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;

test "rawtext" {
    const allocator = std.testing.allocator;
    const content: [:0]const u8 = "Some random html text.";

    var parser = Parser.init();
    var elements = try parser.parse(content, allocator);

    for (elements.items) |*el| {
        std.debug.print("{any}", .{el});
    }

    defer elements.deinit(allocator);
}
