const std = @import("std");
const builtin = @import("builtin");
const Chameleon = @import("chameleon/src/chameleon.zig");

/// Config that modifies the behavior of the test runner.
const Config = struct {
    serpent: struct {
        verbose: bool = false,
        rerun_each: u8 = 1,
        bail: u8 = 0,
        lifecycle_hooks: bool = true,
    } = .{},
};

/// Outcome of each test ran.
const Status = enum { pass, fail, skip, leak, hook };

/// **WARN**: Don't call this function anywhere in your code!
pub fn main() !void {
    // Create allocator using a fixed length buffer.
    var fba_buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&fba_buffer);
    const allocator = fba.allocator();

    // Initialize chameleon for colored logging.
    var c = Chameleon.initRuntime(.{ .allocator = allocator });
    defer c.deinit();

    // Check for build.zig.zon in cwd and import it, else use the default values.
    const config = blk: {
        const contents_buf = std.fs.cwd().readFileAllocOptions(allocator, "build.zig.zon", 8192, null, @alignOf(u8), 0) catch |err| {
            // File doesn't exist, so return default values.
            if (err == error.FileNotFound) {
                break :blk (Config{}).serpent;
            } else {
                return err;
            }
        };
        // File exists, so parse and return it.
        break :blk (try std.zon.parse.fromSlice(Config, allocator, contents_buf, null, .{ .ignore_unknown_fields = true })).serpent;
    };
    fba.reset();

    var pass_count: usize = 0;
    var fail_count: usize = 0;
    var skip_count: usize = 0;
    var leak_count: usize = 0;
    var total_count: usize = 0;

    // Run 'BeforeAll' lifecycle hook.
    if (config.lifecycle_hooks) {
        for (builtin.test_functions) |test_fn| {
            if (std.mem.endsWith(u8, test_fn.name, "@BeforeAll")) {
                var t = try std.time.Timer.start();
                test_fn.func() catch |err| {
                    try c.red().printErr("'@BeforeAll' lifecycle hook failed!\n", .{});
                    return err;
                };
                if (config.verbose) try printStatus(&c, test_fn.name, .hook, t.read());
            }
        }
    }

    // Track time taken by entire test suite.
    var t_global = try std.time.Timer.start();

    // Run the actual tests.
    for (builtin.test_functions) |test_fn| {
        // Check for bail and exit early.
        if (config.bail > 0 and fail_count == config.bail) {
            break;
        }
        // Skip lifecycle hooks.
        if (std.mem.endsWith(u8, test_fn.name, "@BeforeAll") or std.mem.endsWith(u8, test_fn.name, "@AfterAll")) {
            continue;
        }
        std.testing.allocator_instance = .{};
        var t = try std.time.Timer.start();
        if (test_fn.func()) |_| {
            if (config.verbose) try printStatus(&c, test_fn.name, .pass, t.read());
            pass_count += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                if (config.verbose) try printStatus(&c, test_fn.name, .skip, t.read());
                skip_count += 1;
            },
            else => {
                std.debug.print("error: {s}\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    popStackTrace(trace);
                    std.debug.dumpStackTrace(trace.*);
                }
                try printStatus(&c, test_fn.name, .fail, t.read());
                fail_count += 1;
            },
        }
        if (std.testing.allocator_instance.deinit() == .leak) {
            try printStatus(&c, test_fn.name, .leak, t.read());
            leak_count += 1;
        }
        fba.reset();
        total_count += 1;
    }

    // Run 'AfterAll' lifecycle hook.
    if (config.lifecycle_hooks) {
        for (builtin.test_functions) |test_fn| {
            if (std.mem.endsWith(u8, test_fn.name, "@AfterAll")) {
                var t = try std.time.Timer.start();
                test_fn.func() catch |err| {
                    try c.red().printErr("'@AfterAll' lifecycle hook failed!\n", .{});
                    return err;
                };
                if (config.verbose) try printStatus(&c, test_fn.name, .hook, t.read());
            }
        }
    }

    std.debug.print("\n{s} passed, {s} failed, {s} skipped, {s} leaked {s}\n", .{
        try c.green().fmt("{}", .{pass_count}),
        try c.red().fmt("{}", .{fail_count}),
        try c.yellow().fmt("{}", .{skip_count}),
        try c.blue().fmt("{}", .{leak_count}),
        try c.gray().fmt("({} total)", .{total_count}),
    });

    std.debug.print("{s} {s}\n", .{
        if (fail_count == 0 and leak_count == 0)
            try c.bold().green().fmt("✓ Test suite passed", .{})
        else
            try c.bold().red().fmt("✕ Test suite failed", .{}),
        try c.gray().fmt("({})", .{std.fmt.fmtDuration(t_global.read())}),
    });
}

fn printStatus(c: *Chameleon.RuntimeChameleon, fn_name: []const u8, s: Status, elapsed: u64) !void {
    std.debug.print("{s} {s} {s}\n", .{
        switch (s) {
            .pass => try c.black().bgGreen().fmt(" PASS ", .{}),
            .fail => try c.black().bgRed().fmt(" FAIL ", .{}),
            .skip => try c.black().bgYellow().fmt(" SKIP ", .{}),
            .leak => try c.black().bgBlue().fmt(" LEAK ", .{}),
            .hook => try c.black().bgWhite().fmt(" HOOK ", .{}),
        },
        fn_name[std.mem.lastIndexOfScalar(u8, fn_name, '.').? + 1 ..],
        try c.gray().fmt("({})", .{std.fmt.fmtDuration(elapsed)}),
    });
}

/// Pops the first element of the error stack trace which corresponds to the internal serpent library
/// code line, not useful to the user.
fn popStackTrace(trace: *std.builtin.StackTrace) void {
    for (0..trace.instruction_addresses.len - 1) |i| {
        trace.instruction_addresses[i] = trace.instruction_addresses[i + 1];
    }
    trace.index -= 1;
}

/// Skip the current test block from running.
///
/// ```zig
/// const s = @import("serpent");
/// test {
///     // Skip this block from being executed.
///     try s.testSkip();
/// }
/// ```
pub fn testSkip() !void {
    return error.SkipZigTest;
}

/// Make the current test block conditional, to run only if the condition is *true* else skips it.
/// This can be useful for tests only meant to be run on certain operating systems or architectures.
///
/// ```zig
/// const s = @import("serpent");
/// // Run this test only on windows platforms.
/// test {
///     try s.testIf(@import("builtin").os.tag == .windows);
///     try s.expect(10 + 1).equals(11);
/// }
/// ```
///
/// **NOTE:** This should be at the *first line* of the test block.
pub fn testIf(ok: bool) !void {
    if (!ok) try testSkip();
}

// Re-export
pub const expect = @import("expect.zig").expect;
