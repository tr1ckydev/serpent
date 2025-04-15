# Configuration

The serpent test runner can be configured through the already present `build.zig.zon` in your project directory.

Simply add a `.serpent` field to the file and configure it the way you want.

For a default starting point, check out this repository's [`build.zig.zon`](https://github.com/tr1ckydev/serpent/blob/main/build.zig.zon#L13-L24).

# Watch mode

To automatically re-run the tests when your files change, pass the `--watch` flag.

```bash
zig build test --watch --summary none
```

# Lifecycle hooks

Using serpent test runner, you can now use lifecycle hooks in your tests. These can be used to configure the test environment, clean up resources, generate mocking data etc.

The name of the test block should be exactly `"@BeforeAll"` or `"@AfterAll"` to execute correspondingly.

```zig
// Run this block before all the tests start.
test "@BeforeAll" {
    // start a server or,
    // create a test document
}

// Run this block after all the tests have completed.
test "@AfterAll" {
    // stop the server or,
    // clean up resources
}
```

# Utilities

## `testSkip()`

Skip the current test block from running.

```zig
const s = @import("serpent")
test {
    try s.testSkip();
}
```

## `testIf(...)`

Make the current test block conditional, to run only if the condition is *true* else skips it.
This can be useful for tests only meant to be run on certain operating systems or architectures.

> [!NOTE]
> This should be at the *first line* of the test block.

```zig
const s = @import("serpent");
// Run this test only on windows platforms.
test {
    try s.testIf(@import("builtin").os.tag == .windows);
    try s.expect(10 + 1).equals(11);
}
```

# Expect matchers

Serpent comes with jest-like matchers for testing actual values against expected ones. These matchers are named in a more logical way to represent the underlying zig code. Instead of `expect..toBe`, serpent has `expect..equals`.

```zig
const expect = @import("serpent").expect;

// Defining a custom matcher
fn beWithinRange(_actual: anytype, start: anytype, end: anytype) bool {
    return _actual >= start and _actual < end;
}

test {
    try expect(10 + 2).equals(12);
    try expect(42).not().lessThan(36);
    try expect(&[_]i32{ 11, 22, 33 }).contains(22);
    try expect(45).to(beWithinRange, .{ 4, 64 }); // custom matcher
}
```

To see all the available matchers and what they do along with example usages, check out the source code and doc comments for each matcher.

Matchers like `isNull`,`isTrue`, `isFalse`, etc. are needless and hence **will not** be implemented, following the [zig zen](https://ziglang.org/documentation/master/#Zen) as they can be replaced by `.equals(null)`, `.equals(true)`, `.equals(false)` respectively. This keeps the list of built-in matchers bare minimum and allows the user to be more expressive.
