const std = @import("std");
const s = @import("serpent");
const expect = s.expect;

test "@BeforeAll" {
    _ = try std.fs.cwd().createFile("does_exist.txt", .{});
}

test "@AfterAll" {
    try std.fs.cwd().deleteFile("does_exist.txt");
}

test "matchers for primitive values" {
    try expect(20 + 3).equals(23);
    try expect(@intFromBool(true)).equals(1);
    try expect(!true).not().equals(true);
    try expect(45).greaterThanOrEquals(12);
    try expect(-123).lessThan(0);
    try expect(120).within(100, 150);
    try expect(0).within(-10, 10);
}

test "matchers for array like values" {
    try expect("ziguana").contains('g');
    try expect("serpent").startsWith("ser");
    try expect("framework").endsWith("work");
    try expect(&[_]i32{ -23, 56, 90 }).contains(56);
    try expect(&[_]?i32{ 13, null, 43 }).contains(null);
    try expect(&[_]i32{ -12, 82, 12 }).startsWith(&[_]i32{-12});
    try expect(&[_]i32{ 13, -23, 43 }).endsWith(&[_]i32{43});
}

test "arraylist leak test and matchers" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);

    try expect(list.items.len).greaterThan(0);
    try expect(list.items).contains(42);
    try expect(list.pop()).equals(42);
    try expect(list.pop()).equals(null);
}

fn access(comptime path: []const u8) std.fs.Dir.AccessError!void {
    return std.fs.cwd().access(path, .{});
}
test "asserting certain error happens or not" {
    try expect(access("does_not_exist.txt")).throws(error.FileNotFound);
    try expect(access("does_exist.txt")).not().throws(error.FileNotFound);
}

fn beWithinRange(_actual: anytype, start: anytype, end: anytype) bool {
    return _actual >= start and _actual < end;
}

test "check custom matcher works" {
    try expect(45).to(beWithinRange, .{ 4, 64 });
}
