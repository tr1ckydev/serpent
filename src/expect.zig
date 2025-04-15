const std = @import("std");
const Chameleon = @import("chameleon/src/chameleon.zig");

fn ExpectMatchers(comptime T: type) type {
    return struct {
        actual: T,
        negate: bool = false,
        fn printDiff(self: @This(), expected_fmt: anytype, actual_fmt: anytype) !void {
            var fba_buffer: [2048]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&fba_buffer);
            var c = Chameleon.initRuntime(.{ .allocator = fba.allocator() });
            defer c.deinit();
            std.debug.print("expected: {s}{s}\nreceived: {s}\n", .{
                if (self.negate) "not " else "",
                try c.green().fmt(expected_fmt[0], expected_fmt[1]),
                try c.red().fmt(actual_fmt[0], actual_fmt[1]),
            });
        }
        /// Negates the result of a subsequent assertion. If you know how to test something,
        /// use `not()` to test it's opposite.
        ///
        /// ```zig
        /// test {
        ///     try expect(14).not().equals(18);
        ///     try expect(42).not().lessThan(36);
        /// }
        /// ```
        pub fn not(self: @This()) @This() {
            return .{ .actual = self.actual, .negate = true };
        }
        /// Asserts that `actual` == `expected`.
        ///
        /// ```zig
        /// test {
        ///     try expect(20 + 3).equals(23);
        ///     try expect(12.6).equals(12.6);
        ///     try expect(true).equals(true);
        ///     try expect(null).equals(null);
        ///     try expect(@TypeOf(std.io.getStdOut())).equals(std.fs.File);
        /// }
        /// ```
        ///
        /// **TODO:** Support more types similar to `std.testing.expectEqual`.
        pub fn equals(self: @This(), expected: T) !void {
            if (self.negate == (self.actual == expected)) {
                try self.printDiff(.{ "{?}", .{expected} }, .{ "{?}", .{self.actual} });
                return error.TestExpectedEqual;
            }
        }
        /// Asserts that `actual` > `expected`.
        ///
        /// ```zig
        /// test {
        ///     try expect(16).greaterThan(9);
        ///     try expect(20.2).greaterThan(20.1);
        /// }
        /// ```
        pub fn greaterThan(self: @This(), expected: T) !void {
            if (self.negate == (self.actual > expected)) {
                try self.printDiff(.{ ">{?}", .{expected} }, .{ "{?}", .{self.actual} });
                return error.TestExpectedGreaterThan;
            }
        }
        /// Asserts that `actual` >= `expected`.
        ///
        /// ```zig
        /// test {
        ///     try expect(16).greaterThanOrEquals(9);
        ///     try expect(20.2).greaterThanOrEquals(20.2);
        /// }
        /// ```
        pub fn greaterThanOrEquals(self: @This(), expected: T) !void {
            if (self.negate == (self.actual >= expected)) {
                try self.printDiff(.{ ">={?}", .{expected} }, .{ "{?}", .{self.actual} });
                return error.TestExpectedGreaterThanEqual;
            }
        }
        /// Asserts that `actual` < `expected`.
        ///
        /// ```zig
        /// test {
        ///     try expect(9).lessThan(16);
        ///     try expect(20.2).lessThan(20.6);
        /// }
        /// ```
        pub fn lessThan(self: @This(), expected: T) !void {
            if (self.negate == (self.actual < expected)) {
                try self.printDiff(.{ "<{?}", .{expected} }, .{ "{?}", .{self.actual} });
                return error.TestExpectedLessThan;
            }
        }
        /// Asserts that `actual` <= `expected`.
        ///
        /// ```zig
        /// test {
        ///     try expect(9).lessThanOrEquals(16);
        ///     try expect(20.2).lessThanOrEquals(20.2);
        /// }
        /// ```
        pub fn lessThanOrEquals(self: @This(), expected: T) !void {
            if (self.negate == (self.actual <= expected)) {
                try self.printDiff(.{ "<={?}", .{expected} }, .{ "{?}", .{self.actual} });
                return error.TestExpectedLessThanEqual;
            }
        }
        /// Asserts that `actual` is between a `start`(inclusive) and `end`(exclusive) value.
        ///
        /// (`actual` >= `start` and `actual` < `end`)
        ///
        /// ```zig
        /// test {
        ///     try expect(45).within(20, 150);
        ///     try expect(0).within(-10, 10);
        /// }
        /// ```
        pub fn within(self: @This(), start: T, end: T) !void {
            if (self.negate == (self.actual >= start and self.actual < end)) {
                try self.printDiff(.{ ">={?} and <{?}", .{ start, end } }, .{ "{?}", .{self.actual} });
                return error.TestExpectedWithinRange;
            }
        }
        /// Asserts that the `actual` array contains the `expected` child element.
        ///
        /// ```zig
        /// test {
        ///     try expect("serpent").contains('p');
        ///     try expect(&[_]i32{ 11, 22, 33 }).contains(22);
        /// }
        /// ```
        pub fn contains(self: @This(), expected: ExtractChild(T)) !void {
            if (self.negate == std.mem.containsAtLeastScalar(ExtractChild(T), self.actual, 1, expected)) {
                try self.printDiff(.{ "to contain {?}", .{expected} }, .{ "{any}", .{self.actual} });
                return error.TestExpectedContains;
            }
        }
        /// Asserts that the `actual` array starts with the `expected` array.
        ///
        /// ```zig
        /// test {
        ///     try expect("serpent").startsWith("ser");
        ///     try expect(&[_]i32{ -12, 82, 12 }).startsWith(&[_]i32{-12});
        /// }
        /// ```
        pub fn startsWith(self: @This(), expected: []const ExtractChild(T)) !void {
            if (self.negate == std.mem.startsWith(ExtractChild(T), self.actual, expected)) {
                try self.printDiff(.{ "to start with {any}", .{expected} }, .{ "starting with {any}", .{self.actual[0..expected.len]} });
                return error.TestExpectedStartsWith;
            }
        }
        /// Asserts that the `actual` array ends with the `expected` array.
        ///
        /// ```zig
        /// test {
        ///     try expect("framework").endsWith("work");
        ///     try expect(&[_]i32{ 13, -23, 43 }).endsWith(&[_]i32{43});
        /// }
        /// ```
        pub fn endsWith(self: @This(), expected: []const ExtractChild(T)) !void {
            if (self.negate == std.mem.endsWith(ExtractChild(T), self.actual, expected)) {
                try self.printDiff(.{ "to end with {any}", .{expected} }, .{ "ending with {any}", .{self.actual[self.actual.len - expected.len ..]} });
                return error.TestExpectedEndsWith;
            }
        }
        /// Asserts that `actual` returns the `expected` error value.
        ///
        /// ```zig
        /// fn access(comptime path: []const u8) std.fs.Dir.AccessError!void {
        ///     return std.fs.cwd().access(path, .{});
        /// }
        /// test {
        ///     try expect(access("does_not_exist.txt")).throws(error.FileNotFound);
        ///     try expect(access(".")).not().throws(error.FileNotFound);
        /// }
        /// ```
        ///
        pub fn throws(self: @This(), expected: anyerror) !void {
            if (self.actual) |actual_payload| {
                if (!self.negate) {
                    try self.printDiff(.{ "{}", .{expected} }, .{ "{any}", .{actual_payload} });
                    return error.TestExpectedError;
                }
            } else |actual_error| {
                if (self.negate == (expected == actual_error)) {
                    try self.printDiff(.{ "{}", .{expected} }, .{ "{}", .{actual_error} });
                    return error.TestUnexpectedError;
                }
            }
        }
        /// Use a custom matcher to test your `_actual` value.
        ///
        /// Create a matcher function which should return a bool with the first arg as `_actual` and
        /// then add as many args you require.
        /// Then pass it as `to(your_matcher, .{tuple_of_args})`,
        /// where `tuple_of_args` excludes the first arg.
        ///
        /// ```zig
        /// fn beWithinRange(_actual: anytype, start: anytype, end: anytype) bool {
        ///     return _actual >= start and _actual < end;
        /// }
        /// test {
        ///     try expect(45).to(beWithinRange, .{ 4, 64 });
        /// }
        /// ```
        pub fn to(self: @This(), comptime custom_fn: anytype, args: anytype) !void {
            if (self.negate == @call(.auto, custom_fn, .{self.actual} ++ args)) {
                // TODO: Allow the user to provide custom diff formatting.
                return error.TestUnexpectedResult;
            }
        }
    };
}

/// Same as `std.meta.Child` with pointer being recursively unwrapped.
fn ExtractChild(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .array => |info| info.child,
        .vector => |info| info.child,
        .pointer => |info| ExtractChild(info.child),
        .optional => |info| info.child,
        else => T,
    };
}

/// Asserts that a value matches some criteria.
pub fn expect(actual: anytype) ExpectMatchers(@TypeOf(actual)) {
    return .{ .actual = actual };
}
