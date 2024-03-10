//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");

/// A string libaray optimized for holden large strings
pub const FileString = struct {
    /// The buffer for the content
    buffer: []u8,
    /// The allocator used for managing the buffer
    allocator: std.mem.Allocator,
    /// The total size of the String
    size: usize,
    /// The batch size used for allocation
    batch_size: usize,
    // current end index of the buffer
    end: usize,

    pub fn empty(allocator: std.mem.Allocator) FileString {
        return .{
            .buffer = &[0]u8{},
            .allocator = all,
            .size = 0,
            .batch_size = 1000,
            .end = 0,
        };
    }

    pub fn init(self: *FileString, initial_size: usize) !FileString {
        self.size = initial_size + self.batch_size;
        self.buffer = try self.allocator.alloc(u8, size);
    }

    pub fn deinit(self: *FileString) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }

    pub fn allocate(self: *FileString, bytes: usize) !void {
        self.size += bytes + self.batch_size;
        self.buffer = try self.allocator.realloc(self.buffer, self.size);
    }

    pub fn concat(self: *FileString, content: []const u8) !void {
        if (self.size + content.len > self.buffer.len) {
            try self.allocate(content.len);
        }

        var i: usize = 0;
        while (i < content.len) : (i += 1) {
            self.buffer[self.end + i] = content[i];
        }
        self.end += content.len;
    }

    pub fn toString(self: *FileString) []u8 {
        return self.buffer[0..self.end];
    }
};
