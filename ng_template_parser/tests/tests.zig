//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
comptime {
    // ng-template
    _ = @import("ng_template/lexer.test.zig");
    _ = @import("ng_template/parser.test.zig");
    _ = @import("ng_template/formatter.test.zig");
}
