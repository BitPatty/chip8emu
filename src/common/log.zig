// --- std --- //
const io = @import("std").io;
const fmt = @import("std").fmt;
const time = @import("std").time;

const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();


/// Prints a message to stdout
pub fn info(comptime msg: []const u8, args: anytype) void {
    _ = stdout.print("{} ", .{ msTimestamp() }) catch {};
    _ = stdout.print(msg, args) catch {};
}

/// Prints a message to stdout with a trailing newline character
pub fn infoln(comptime msg: []const u8, args: anytype) void {
    _ = stdout.print("{} ", .{ msTimestamp() }) catch {};
    _ = stdout.print(msg, args) catch {};
    _ = stdout.write("\n") catch {};
}

/// Prints a mesage to stderr
pub fn err(comptime msg: []const u8, args: anytype) void {
    _ = stderr.print("{} ", .{ msTimestamp() }) catch {};
    _ = stderr.print(msg, args) catch {};
}

/// Prints a message to stderr with a trailing newline character
pub fn errln(comptime msg: []const u8, args: anytype) void {
    _ = stderr.print("{} ", .{ msTimestamp() }) catch {};
    _ = stderr.print(msg, args) catch {};
    _ = stderr.write("\n") catch {};
}

fn msTimestamp() u64 {
    return @as(u64, @truncate(@as(u128, @bitCast(@divFloor(time.nanoTimestamp(), time.ns_per_ms)))));
}