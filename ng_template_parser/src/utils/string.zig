//
// Copyright (c) Florian Plesker
// florian.plesker@web.de
//
const std = @import("std");

/// Errors that may occur when using String
pub const StringError = error{
    OutOfMemory,
};

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
            .allocator = allocator,
            .size = 0,
            .batch_size = 1000,
            .end = 0,
        };
    }

    pub fn init(self: *FileString, initial_size: usize) StringError!void {
        self.size = initial_size + self.batch_size;
        self.buffer = self.allocator.alloc(u8, self.size) catch {
            return StringError.OutOfMemory;
        };
    }

    pub fn deinit(self: *FileString) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }

    pub fn allocate(self: *FileString, bytes: usize) StringError!void {
        self.size += bytes + self.batch_size;
        self.buffer = self.allocator.realloc(self.buffer, self.size) catch {
            return StringError.OutOfMemory;
        };
    }

    pub fn ensure_capacity(self: *FileString, count: usize) !void {
        if (self.end + count > self.size) {
            try self.allocate(count);
        }
    }

    pub fn concat_assume_capacity(self: *FileString, content: []const u8) void {
        var i: usize = 0;
        while (i < content.len) : (i += 1) {
            self.buffer[self.end + i] = content[i];
        }
        self.end += content.len;
    }

    pub fn concat(self: *FileString, content: []const u8) StringError!void {
        if (self.end + content.len > self.size) {
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

    pub fn indent(self: *FileString, count: usize) StringError!void {
        const new_end = self.end + count;

        if (new_end > self.size) {
            try self.allocate(count);
        }

        for (self.end..new_end) |i| {
            self.buffer[i] = ' ';
        }
        self.end += count;
    }

    pub fn indent_assume_capacity(self: *FileString, count: usize) void {
        const new_end = self.end + count;

        for (self.end..new_end) |i| {
            self.buffer[i] = ' ';
        }
        self.end += count;
    }
};
