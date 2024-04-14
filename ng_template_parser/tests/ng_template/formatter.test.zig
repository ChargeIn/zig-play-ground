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

fn testFormatContent(content: [:0]const u8, expected_content: [:0]const u8, options: Options) !void {
    const allocator = std.testing.allocator;

    var formatter = try Formatter.init(allocator, options);
    defer formatter.deinit();

    const formatted_content = try formatter.format(content);

    expect(std.mem.eql(u8, formatted_content, expected_content)) catch |err| {
        std.debug.print("Formatted context does not match: \n\n Expected: \n{s}\n\nRecieved:\n{s}", .{ expected_content, formatted_content });

        for (0..expected_content.len) |i| {
            if (expected_content[i] != formatted_content[i]) {
                std.debug.print("Char at index {d} does not match: \nExpected: {c}\nRecieved: {c}\n\n", .{ i, expected_content[i], formatted_content[i] });
                break;
            }
        }

        try expectEqual(formatted_content.len, expected_content.len);

        return err;
    };
}

test "should trim text content" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    const content = "<div> \n\t      Hello      World     \n\t  </div>";
    const expected_content =
        \\<div>
        \\    Hello      World
        \\</div>
        \\
    ;

    try testFormatContent(content, expected_content, options);
}

test "should use tabWidth correctly" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();
    options.tab_width = 5;

    const content = "<div><div>Hello World</div></div>";
    const expected_content =
        \\<div>
        \\     <div>
        \\          Hello World
        \\     </div>
        \\</div>
        \\
    ;

    try testFormatContent(content, expected_content, options);
}

test "should format attributes correctly" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    options.tab_width = 5;

    const content = "<div><custom-component [input1]=\"SomeValue1\" *ngIf=\"SomeCheckValue\" (output1)=\"onEvent1($event)\" directive staticInput=\"Some Value\">Hello World</custom-component>\n \n       </div>";
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
    try testFormatContent(content, expected_content, options);
}

test "should not alter content of pre tags" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    const content =
        \\<pre> laksdf
        \\ dddf
        \\      dsf
        \\
        \\</pre>
        \\
        \\
        \\
    ;
    const expected_content =
        \\<pre> laksdf
        \\ dddf
        \\      dsf
        \\
        \\</pre>
        \\
    ;
    try testFormatContent(content, expected_content, options);
}

test "should not self close html elements" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    const content =
        \\<div></div>
        \\<span></span>
        \\<h1></h1>
        \\<h2></h2>
        \\<h3></h3>
        \\<h4></h4>
        \\<h5></h5>
        \\<h6></h6>
        \\<a></a>
        \\<table></table>
        \\<li></li>
        \\
    ;
    const expected_content =
        \\<div></div>
        \\
        \\<span></span>
        \\
        \\<h1></h1>
        \\
        \\<h2></h2>
        \\
        \\<h3></h3>
        \\
        \\<h4></h4>
        \\
        \\<h5></h5>
        \\
        \\<h6></h6>
        \\
        \\<a></a>
        \\
        \\<table></table>
        \\
        \\<li></li>
        \\
    ;
    try testFormatContent(content, expected_content, options);
}

test "should add new line between two children" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    const content = "<div><div></div><div>  </div><div>     </div></div>";
    const expected_content =
        \\<div>
        \\    <div></div>
        \\
        \\    <div></div>
        \\
        \\    <div></div>
        \\</div>
        \\
    ;
    try testFormatContent(content, expected_content, options);
}

test "should auto close custom html elements if empty" {
    const allocator = std.testing.allocator;

    var options = try Options.init(allocator);
    defer options.deinit();

    const content =
        \\<custom-1></custom-1>
        \\
        \\<custom-2>   </custom-2>
        \\
        \\<custom-3> Some test  </custom-3>
        \\
    ;

    const expected_content =
        \\<custom-1/>
        \\
        \\<custom-2/>
        \\
        \\<custom-3>
        \\    Some test
        \\</custom-3>
        \\
    ;
    try testFormatContent(content, expected_content, options);
}
