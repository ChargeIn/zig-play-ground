const std = @import("std");
const fs = std.fs;
const tokens = @import("parser/token.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // TODO specific file parsing
    const content = readFile("./src/tests/all-no-media-elements.html", allocator) catch |err| {
        std.log.err("Could not read file: {any}", .{err});
        return;
    };
    defer allocator.free(content);

    std.log.info("file {s} {any}", .{content});
}

pub fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const content = try file.readToEndAlloc(allocator, file_size);

    return content;
}
