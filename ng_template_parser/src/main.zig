const std = @import("std");
const fs = std.fs;
const tokenizer = @import("parser/tokenizer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // TODO specific file parsing
    const content: [:0]u8 = readFile("./src/tests/all-no-media-elements.html", allocator) catch |err| {
        std.log.err("Could not read file: {any}", .{err});
        return;
    };
    defer allocator.free(content);

    var ngTemplateTokenizer = tokenizer.NgTemplateTokenzier.init(content);

    const token = ngTemplateTokenizer.next();

    std.log.info("file {s}\n token {any}", .{ content, token });
}

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) ![:0]u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const content = try file.readToEndAllocOptions(allocator, file_size, null, 1, 0);

    return content;
}