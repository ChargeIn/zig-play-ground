//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Formatter = @import("formatter.zig").NgTemplateFormatter;
const Options = @import("options").FormatterOptions;

// TESTING
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test "should use tabWidth correctly" {
    var formatter = Formatter.init(.{ .tab_width = 4 });

    const content = "<div><div>Hello World</div></div>";
    const expected_content =
        \\<div>
        \\    <div>Hello World</div>
        \\</div>
    ;
    const allocator = std.testing.allocator;
    const formatted_content = try formatter.format(allocator, content);

    expect(std.mem.eql(u8, formatted_content, expected_content)) catch |err| {
        std.debug.print("Formatted context does not match: \n\n Expected: \n{s}\n\nRecieved:\n{s}\n\n", .{ content, formatted_content });
        return err;
    };
}
