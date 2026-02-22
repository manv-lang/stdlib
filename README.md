I# ManV Standard Library

This directory contains the standard library for the ManV programming language.

## Structure

```
stdlib/
├── core/           # Core types and utilities
│   ├── core.mvh    # Core header file
│   ├── core.asm    # Exit and basic functions
│   ├── str.asm     # String functions
│   ├── int.asm     # Integer functions
│   ├── float.asm   # Float functions
│   ├── array.asm   # Array functions
│   └── bytes.asm   # Bytes functions
├── io/             # Input/Output
│   ├── io.mvh      # IO header file
│   └── io.asm      # print, printi, flush functions
├── math/           # Math library
│   ├── math.mvh    # Math header file
│   └── math.asm    # SSE-based math functions
├── memory/         # Memory management
│   ├── memory.mvh  # Memory header file
│   ├── gc.asm      # Garbage collector
│   ├── arena.asm   # Arena allocator
│   └── mem.asm     # Memory utilities (copy, set, compare, etc.)
├── build.py        # Build script
├── libcore.a       # Compiled core library (after build)
└── libstd.a        # Compiled std library (after build)
```

## Libraries

### libcore.a

Core types and utilities:

- **String functions**: `str_len`, `str_concat`, `str_slice`, `str_contains`, `str_find`, etc.
- **Integer functions**: `int_abs`, `int_min`, `int_max`, `int_clamp`, `int_pow`, `int_to_str`
- **Float functions**: `float_abs`, `float_floor`, `float_ceil`, `float_round`, `float_to_str`
- **Array functions**: `array_len`, `array_get`, `array_at`, `array_set`, `array_is_empty`
- **Bytes functions**: `bytes_len`, `bytes_get`, `bytes_set`

### libstd.a

Standard library modules:

- **IO**: `print`, `printi`, `flush`, `flush_stdout`, `flush_stderr`
- **Math** (SSE-optimized):
  - Integer: `int_abs`, `int_min`, `int_max`, `int_clamp`, `int_pow`, `int_sqrt`, `int_gcd`, `int_lcm`
  - Float: `float_sqrt`, `float_floor`, `float_ceil`, `float_round`, `float_trunc`
  - Trigonometric: `float_sin`, `float_cos`, `float_tan`, `float_asin`, `float_acos`, `float_atan`, `float_atan2`
  - Exponential: `float_exp`, `float_log`, `float_log2`, `float_log10`, `float_pow`, `float_cbrt`
  - Utilities: `float_is_nan`, `float_is_inf`, `float_is_finite`, `float_degrees`, `float_radians`, `float_hypot`
- **Memory**:
  - GC: `gc_init`, `gc_alloc`, `gc_collect`, `gc_register_frame`, `gc_unregister_frame`, `gc_get_stats`
  - Arena: `arena_new`, `arena_alloc`, `arena_free`, `arena_reset`, `arena_available`, `arena_get_stats`
  - Utilities: `mem_copy`, `mem_set`, `mem_compare`, `mem_move`, `mem_zero`

## Building

### Prerequisites

- NASM (Netwide Assembler)
- ar (GNU archiver, usually part of binutils)
- Python 3.x

### Build Commands

```bash
# Build libraries
python build.py

# Clean and rebuild
python build.py --clean

# Verbose output
python build.py -v

# Specify stdlib directory
python build.py --stdlib-dir /path/to/stdlib
```

### Output

After building, you'll have:

- `libcore.a` - Static library containing core functions
- `libstd.a` - Static library containing standard library functions

## Usage in ManV

### Including Headers

```manv
// Include core types
include "core/core.mvh";

// Include specific modules
include "io/io.mvh";
include "math/math.mvh";
include "memory/memory.mvh";
```

### Using with the Compiler

```bash
# Compile with auto-detected stdlib
manv compile program.mv

# Specify stdlib path
manv compile -S /path/to/stdlib program.mv

# Disable automatic stdlib linking
manv compile --no-link-stdlib program.mv
```

### Example Program

```manv
include "io/io.mvh";
include "core/core.mvh";
include "math/math.mvh";

fn main() -> void {
    str* message = "Hello, World!";
    int len = str_len(message);
    
    print(message, len);
    
    // Using math library
    float x = 2.0;
    float result = float_sqrt(x);
}
```

## Memory Management

### Garbage Collector

```manv
include "memory/memory.mvh";

fn example() -> void {
    // Initialize GC (optional, auto-initialized)
    gc_init();
    
    // Allocate GC-managed object
    gc<int> data = gc_alloc(8, TYPE_ID_INT);
    
    // Trigger manual collection
    int freed = gc_collect();
}
```

### Arena Allocator

```manv
include "memory/memory.mvh";

fn example() -> void {
    // Create arena with 4KB capacity
    arena a = arena_new(4096);
    
    // Allocate in arena
    arena_ref<int> tmp = arena_alloc(a, 8, 16);
    
    // Free entire arena at once
    arena_free(a);
}
```

## Constants

### Math Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `PI` | 3.14159... | π (pi) |
| `TAU` | 6.28318... | 2π (tau) |
| `E` | 2.71828... | Euler's number |
| `PHI` | 1.61803... | Golden ratio |
| `SQRT2` | 1.41421... | Square root of 2 |
| `LN2` | 0.69314... | Natural log of 2 |
| `LN10` | 2.30258... | Natural log of 10 |

### IO Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `STDIN` | 0 | Standard input |
| `STDOUT` | 1 | Standard output |
| `STDERR` | 2 | Standard error |

## License

MIT License - See [LICENSE](../manv/LICENSE) for details.