# Stdlib API Reference

## Overview

The Manv Standard Library (`std`) provides essential types, functions, and utilities for common programming tasks.

## Including the Stdlib

Include the entire stdlib:

```manv
include "std";
```

Or include specific modules:

```manv
include "std/types";
include "std/core";
include "std/prelude";
```

---

## Core Modules

### `std/types` — Standard Type Aliases

The types module defines Tier B standard type aliases that provide ergonomic names for common use cases.

#### Core Aliases

| Alias | Canonical Type | Description |
|-------|---------------|-------------|
| `int` | `isize` | Machine-native signed integer |
| `uint` | `usize` | Machine-native unsigned integer |
| `byte` | `u8` | Single byte (unsigned 8-bit) |
| `float` | `f64` | Double-precision floating point |

#### Additional Aliases

| Alias | Canonical Type |
|-------|---------------|
| `float32` | `f32` |
| `float64` | `f64` |
| `int32` | `i32` |
| `int64` | `i64` |
| `uint32` | `u32` |
| `uint64` | `u64` |
| `Size` | `usize` |
| `Offset` | `isize` |
| `Char` | `char` |

#### Usage

```manv
include "std";

int counter = 0;        // Equivalent to isize
uint length = 100;      // Equivalent to usize
byte data = 0xFF;       // Equivalent to u8
float ratio = 0.5;      // Equivalent to f64
```

---

### `std/prelude` — Essential Constants

Common constants and syscall numbers.

#### Constants

```manv
// Mathematical constants
float PI = 3.14159265358979323846;
float E = 2.71828182845904523536;
float TAU = 6.28318530717958647692;

// Syscall numbers (Linux x86_64)
int SYS_WRITE = 1;
int SYS_READ = 0;
int SYS_EXIT = 60;
int SYS_OPEN = 2;
int SYS_CLOSE = 3;
int SYS_MMAP = 9;
int SYS_MUNMAP = 11;
int SYS_BRK = 12;

// File descriptors
int STDIN = 0;
int STDOUT = 1;
int STDERR = 2;

// Memory
int PAGE_SIZE = 4096;
int NULL = 0;
```

---

### `std/core` — Core Functions

Basic I/O and utility functions.

#### Functions

```manv
// Print a string to stdout
fn print(message: str) -> void;

// Print a string with newline
fn println(message: str) -> void;

// Print an integer
fn print_int(value: int) -> void;

// Exit the program
fn exit(code: int) -> void;
```

---

### `std/option` — Option Type

Represents an optional value that may or may not exist.

#### Definition

```manv
struct Option<T> {
    has_value: bool;
    value: T;
}
```

#### Functions

```manv
// Create Some(value)
fn Some<T>(value: T) -> Option<T>;

// Create None
fn None<T>() -> Option<T>;

// Check if option has value
fn is_some<T>(opt: Option<T>) -> bool;
fn is_none<T>(opt: Option<T>) -> bool;

// Unwrap value (panics if None)
fn unwrap<T>(opt: Option<T>) -> T;

// Unwrap with default
fn unwrap_or<T>(opt: Option<T>, default: T) -> T;
```

---

### `std/result` — Result Type

Represents either a success value or an error.

#### Definition

```manv
struct Result<T, E> {
    is_ok: bool;
    value: T;
    error: E;
}
```

#### Functions

```manv
// Create Ok(value)
fn Ok<T, E>(value: T) -> Result<T, E>;

// Create Err(error)
fn Err<T, E>(error: E) -> Result<T, E>;

// Check if result is Ok
fn is_ok<T, E>(result: Result<T, E>) -> bool;
fn is_err<T, E>(result: Result<T, E>) -> bool;

// Unwrap value (panics if Err)
fn unwrap<T, E>(result: Result<T, E>) -> T;

// Unwrap error (panics if Ok)
fn unwrap_err<T, E>(result: Result<T, E>) -> E;
```

---

### `std/assert` — Assertions

Assertion functions for testing and debugging.

#### Functions

```manv
// Basic assertions
fn assert(condition: bool, message: str) -> void;
fn assert_eq(expected: int, actual: int, message: str) -> void;
fn assert_ne(expected: int, actual: int, message: str) -> void;
fn assert_true(condition: bool, message: str) -> void;
fn assert_false(condition: bool, message: str) -> void;

// Pointer assertions
fn assert_null(ptr: void*, message: str) -> void;
fn assert_not_null(ptr: void*, message: str) -> void;

// Panic functions
fn panic(message: str) -> void;
fn panicf(format: str, value: int) -> void;
fn unreachable(message: str) -> void;
fn todo(message: str) -> void;
fn unimplemented(message: str) -> void;
```

---

## Memory Management

### `std/mem` — Memory Module

Memory allocation and management utilities.

#### Submodules

- `std/mem/alloc` — General purpose allocators
- `std/mem/arena` — Arena allocators
- `std/mem/gc` — Garbage collector
- `std/mem/buffer` — Buffer utilities

---

## Collections

### `std/collections` — Collection Types

Data structures for storing multiple values.

#### Map

Hash map implementation with open addressing.

```manv
struct Map<K, V> {
    entries: MapEntry<K, V>*;
    size: int;
    capacity: int;
}

impl Map<K, V> {
    fn new() -> Map<K, V>*;
    fn insert(self, key: K, value: V) -> void;
    fn get(self, key: K) -> Option<V>;
    fn remove(self, key: K) -> bool;
    fn contains_key(self, key: K) -> bool;
    fn len(self) -> int;
    fn is_empty(self) -> bool;
}
```

#### Set

Hash set backed by Map.

```manv
struct Set<T> {
    map: Map<T, bool>*;
}

impl Set<T> {
    fn new() -> Set<T>*;
    fn insert(self, value: T) -> void;
    fn contains(self, value: T) -> bool;
    fn remove(self, value: T) -> bool;
}
```

---

## I/O

### `std/io` — Input/Output

File and stream I/O operations.

#### File Operations

```manv
struct File {
    fd: int;
    path: str*;
    mode: str*;
    is_open: bool;
}

impl File {
    fn open(path: str*, mode: str*) -> File*;
    fn close(self) -> void;
    fn read_all(self) -> str*;
    fn write_str(self, content: str*) -> int;
}
```

---

## Encoding

### `std/encoding` — Encoding Utilities

Encode and decode various formats.

#### Base64

```manv
fn base64_encode(data: bytes*, len: int) -> str*;
fn base64_decode(s: str*) -> bytes*;
```

#### Hex

```manv
fn hex_encode(data: bytes*, len: int) -> str*;
fn hex_decode(s: str*) -> bytes*;
```

---

## Hashing

### `std/hash` — Hash Functions

Hashing algorithms for data integrity.

```manv
fn hash_str(s: str*) -> int;
fn hash_int(n: int) -> int;
fn hash_bytes(data: bytes*) -> int;
fn hash_combine(h1: int, h2: int) -> int;
```

---

## Math

### `std/math` — Mathematical Functions

Mathematical operations and constants.

```manv
// Basic operations
fn abs(x: int) -> int;
fn min(a: int, b: int) -> int;
fn max(a: int, b: int) -> int;

// Floating point
fn sqrt(x: float) -> float;
fn pow(base: float, exp: float) -> float;
fn sin(x: float) -> float;
fn cos(x: float) -> float;
fn tan(x: float) -> float;
```

---

## Time

### `std/time` — Time Utilities

Time-related functions.

```manv
fn time_now() -> int;
fn time_sleep_ms(ms: int) -> void;
```

---

## Changelog

### v0.2.0 — Two-Tier Type System

**New Features:**
- Added `std/types` module with standard type aliases
- New typedef syntax: `typedef Name = Type;`
- Tier A primitives: `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, `u128`, `isize`, `usize`, `f32`, `f64`, `bool`
- Tier B stdlib aliases: `int`, `uint`, `byte`, `float`
- Alias canonicalization and cycle detection

**Breaking Changes:**
- `int` now maps to `isize` (64-bit on x86_64) instead of 32-bit
- `float` now maps to `f64` explicitly
- Old typedef syntax `typedef Type Name;` is deprecated but still supported

**Migration Guide:**
- Code using `int` continues to work but now has different size semantics
- Use `i32` or `i64` explicitly when specific bit widths are required
- Use `int` and `uint` for general-purpose integers in application code