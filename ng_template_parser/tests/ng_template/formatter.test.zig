//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Formatter = @import("ng_template").NgTemplateFormatter;
const Options = @import("ng_template").NgTemplateFormatterOptions;

// TESTING
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test "should use tabWidth correctly" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();
    options.tab_width = 5;

    var formatter = try Formatter.init(allocator, options);
    defer formatter.deinit();

    const content = "<div><div>Hello World</div></div>";
    const expected_content =
        \\<div>
        \\     <div>
        \\          Hello World
        \\     </div>
        \\</div>
        \\
    ;

    const formatted_content = try formatter.format(content);

    expect(std.mem.eql(u8, formatted_content, expected_content)) catch |err| {
        std.debug.print("Formatted context does not match: \n\n Expected: \n{s}\n\nRecieved:\n{s}\n\n", .{ expected_content, formatted_content });
        return err;
    };
}

test "should format attributes correctly" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    options.tab_width = 5;

    var formatter = try Formatter.init(allocator, options);
    defer formatter.deinit();

    const content = "<div><custom-component [input1]=\"SomeValue1\" *ngIf=\"SomeCheckValue\" (output1)=\"onEvent1($event)\" directive staticInput=\"Some Value\">Hello World</custom-component></div>";
    const expected_content =
        \\<div>
        \\     <custom-component
        \\          *ngIf="SomeCheckValue"
        \\          directive
        \\          staticInput="Some Value"
        \\          [input1]="SomeValue1"
        \\          (output1)="onEvent1($event)"
        \\     >
        \\          Hello World
        \\     </custom-component>
        \\</div>
        \\
    ;

    const formatted_content = try formatter.format(content);

    expect(std.mem.eql(u8, formatted_content, expected_content)) catch |err| {
        std.debug.print("Formatted context does not match: \n\n Expected: \n{s}\n\nRecieved:\n{s}", .{ expected_content, formatted_content });

        for (0..expected_content.len) |i| {
            if (expected_content[i] != formatted_content[i]) {
                std.debug.print("Char at index {d} does not match: \nExpected: {c}\nRecieved: {c}\n\n", .{ i, expected_content[i], formatted_content[i] });
            }
        }

        return err;
    };
}
