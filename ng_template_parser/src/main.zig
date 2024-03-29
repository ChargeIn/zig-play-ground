//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");
const fs = std.fs;
const tokenizer = @import("ng-template/lexer.zig");
const token = @import("ng-template/token.zig");
const Formatter = @import("ng-template/formatter.zig").NgTemplateFormatter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    _ = Formatter.init(.{ .tab_width = 4 });

    // TODO specific file parsing
    const content: [:0]u8 = readFile("./src/tests/all-no-media-elements.html", allocator) catch |err| {
        std.log.err("Could not read file: {any}", .{err});
        return;
    };
    defer allocator.free(content);

    std.log.info("Content: {s}", .{content});

    var ngTemplateTokenizer = tokenizer.NgTemplateLexer.init(content);

    var t = try ngTemplateTokenizer.next(allocator);
    while (t != token.NgTemplateToken.eof) {
        std.log.info("Token {any}", .{token});
        t = try ngTemplateTokenizer.next(allocator);
    }
}

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) ![:0]u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const content = try file.readToEndAllocOptions(allocator, file_size, null, 1, 0);

    return content;
}
