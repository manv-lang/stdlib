# Manv Standard Library Layout

## Directory Structure
The standard library is a standalone package located in its own directory, logically separate from the `manv` compiler source:

```
std/
├── src/
│   ├── mod.mv          # The primary package entry point for 'include "std";'
│   ├── prelude.mv      # Core types and aliases
│   ├── core.mv         # Foundational utilities
│   ├── mem/
│   │   ├── mod.mv      # 'include "std/mem";'
│   │   └── ...
│   ├── collections/
│   │   └── mod.mv      # 'include "std/collections";'
│   └── ...
```

## Module Resolution Rules
- `include "std";` resolves to `std/src/mod.mv`. This loads the curated public API of the standard library.
- `include "std/<module>";` resolves to `std/src/<module>.mv` or `std/src/<module>/mod.mv`. This allows users to only pull specific modules if they prefer not to load the entire stdlib.

## Public Surface Rule
- The public API is curated exclusively through `pub use` statements in `mod.mv` files.
- Internal files and submodules do not form part of the stable public API unless they are explicitly re-exported by a parent `mod.mv`.
