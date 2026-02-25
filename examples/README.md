# Manv Standard Library Examples

This directory contains detailed examples demonstrating how to use modules from the `std` package.

## Running Examples

Each example file is a self-contained program with a `main()` function. Run them with:

```bash
manv run std/examples/00_std_package_smoke.mv
```

## Package-First Examples

These examples follow the current include style where `std` is the package root:

- `00_std_package_smoke.mv`  
  Uses `include "std";` and alias types (`int`, `uint`, `byte`, `float`).
- `07_core_module_basics.mv`  
  Uses `include "std/core";` and core helpers like `abs`, `max`, `clamp`.
- `08_grouped_modules_smoke.mv`  
  Uses grouped modules: `std/num`, `std/string`, `std/collections`.
- `09_assert_module_basics.mv`  
  Uses `include "std/assert";` and basic assertion helpers.

## Example Files

### 01_prelude_example.mv
**Module:** `std/prelude`

Demonstrates:
- Type aliases (`i32`, `f32`, `u8`, `string`, etc.)
- Mathematical constants (`PI`, `E`, `TAU`)

```manv
include "std/prelude";

i32 counter = 0;
f32 radius = 5.0;
f32 area = PI * radius * radius;
```

### 02_core_example.mv
**Module:** `std/core`

Demonstrates:
- Integer operations: `abs()`, `max()`, `min()`, `clamp()`
- Float operations: `abs_f()`, `max_f()`, `min_f()`, `clamp_f()`

```manv
include "std/core";

int value = abs(-42);      // 42
int biggest = max(3, 7);   // 7
int limited = clamp(150, 0, 100);  // 100
```

### 03_option_example.mv
**Module:** `std/option`

Demonstrates:
- Creating `Option<T>` values (`some`, `none`)
- Checking for values (`is_some()`, `is_none()`)
- Extracting values (`unwrap()`, `unwrap_or()`)
- Practical patterns (safe division, lookup)

```manv
include "std/option";

Option<int> result = Option<int>.some(42);
int value = result.unwrap_or(0);  // 42

Option<int> empty = Option<int>.none();
int fallback = empty.unwrap_or(0);  // 0
```

### 04_result_example.mv
**Module:** `std/result`

Demonstrates:
- Creating `Result<T, E>` values (`ok`, `err`)
- Checking for success (`is_ok()`, `is_err()`)
- Extracting values and errors
- Error handling patterns

```manv
include "std/result";

Result<int, str> success = Result<int, str>.ok(42);
Result<int, str> failure = Result<int, str>.err("Something went wrong");

if (success.is_ok()) {
    int value = success.unwrap();  // 42
}
```

### 05_assert_example.mv
**Module:** `std/assert`

Demonstrates:
- Basic assertions (`assert()`, `assert_true()`, `assert_false()`)
- Equality checks (`assert_eq()`, `assert_ne()`)
- Pointer checks (`assert_null()`, `assert_not_null()`)
- Debug assertions (`debug_assert()`)
- Panic functions (`panic()`, `unreachable()`, `todo()`)

```manv
include "std/assert";

int x = 10;
assert(x > 0, "x should be positive");
assert_eq(42, result, "result should equal 42");
```

### 06_memory_example.mv
**Module:** `std/mem`

Demonstrates:
- Low-level memory operations (`Memory.alloc()`, `Memory.free()`)
- Arena allocator (`Arena`, `ArenaRef<T>`)
- Dynamic buffers (`Buffer`)
- Save/restore points

```manv
include "std/mem";

// Arena for temporary allocations
Arena* arena = Arena.with_capacity(4096);
int* temp = arena.alloc_array<int>(100);
arena.reset();  // Free all at once

// Dynamic buffer
Buffer* buf = Buffer.with_capacity(16);
buf.push(72);  // 'H'
buf.push(105); // 'i'
```

## Module Overview

| Module | Include | Purpose |
|--------|---------|---------|
| prelude | `include "std/prelude";` | Type aliases, constants |
| core | `include "std/core";` | Utility functions |
| option | `include "std/option";` | Optional values |
| result | `include "std/result";` | Error handling |
| assert | `include "std/assert";` | Assertions, panic |
| mem | `include "std/mem";` | Memory management |

## Including the Full Standard Library

To include all modules at once:

```manv
include "std";
```

This includes all active modules. You can also include specific modules as needed.
