//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const Parser = @import("parser.zig").NgTemplateParser;
const utils = @import("utils");
const FileString = utils.FileString;
const StringError = utils.StringError;
const ast = @import("ast.zig");
const HtmlAttributeType = ast.HtmlAttributeType;

pub const NgTemplateFormatterOptions = Options;

const Options = struct {
    allocator: std.mem.Allocator,

    tab_width: usize,
    auto_self_close: bool,
    attribute_order: std.ArrayListUnmanaged(HtmlAttributeType),

    pub fn init(allocator: std.mem.Allocator) !Options {
        var order = std.ArrayListUnmanaged(HtmlAttributeType){};
        try order.ensureTotalCapacity(allocator, 5);

        order.appendAssumeCapacity(.static);
        order.appendAssumeCapacity(.one_way);
        order.appendAssumeCapacity(.two_way);
        order.appendAssumeCapacity(.output);

        return Options{ .allocator = allocator, .tab_width = 4, .auto_self_close = true, .attribute_order = order };
    }

    pub fn deinit(self: *Options) void {
        self.attribute_order.deinit(self.allocator);
    }
};
