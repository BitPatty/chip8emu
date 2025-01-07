// --- std --- //
const io = @import("std").io;
const fmt = @import("std").fmt;
const builtin = @import("builtin");

// --- common --- //
const time = @import("./time.zig");

// --- log channels --- //
const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();

const timestamp_func = time.epochMilliseconds;

/// Prints a message to stdout
pub fn info(comptime msg: []const u8, args: anytype) void {
    _ = stdout.print("{} ", .{ timestamp_func() }) catch {};
    _ = stdout.print(msg, args) catch {};
}

/// Prints a message to stdout with a trailing newline character
pub fn infoln(comptime msg: []const u8, args: anytype) void {
    _ = stdout.print("{} ", .{ timestamp_func() }) catch {};
    _ = stdout.print(msg, args) catch {};
    _ = stdout.write("\n") catch {};
}

/// Prints a mesage to stderr
pub fn err(comptime msg: []const u8, args: anytype) void {
    _ = stderr.print("{} ", .{ timestamp_func() }) catch {};
    _ = stderr.print(msg, args) catch {};
}

/// Prints a message to stderr with a trailing newline character
pub fn errln(comptime msg: []const u8, args: anytype) void {
    _ = stderr.print("{} ", .{ timestamp_func() }) catch {};
    _ = stderr.print(msg, args) catch {};
    _ = stderr.write("\n") catch {};
}
