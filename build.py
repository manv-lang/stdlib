#!/usr/bin/env python3
"""
Build script for ManV standard library.

The stdlib is now implemented in pure ManV (.mv files) with no assembly.
This script provides build orchestration and validation.

Usage:
    python build.py [--clean] [--verbose]

Modules:
    core/core.mv      - Core types (String, Int, Float, Array, Bytes)
    io/io.mv          - I/O operations (Reader, Writer, Stdin, Stdout)
    math/math.mv      - Math operations (Math, Vec2, Vec3)
    memory/memory.mv  - Memory management (Arena, GC, Pool, Buffer)
    exception/exception.mv - Exception handling (Exception, Result)
    sys/sys.mv        - System operations (Sys, SysInfo)
    os/os.mv          - OS utilities (OS, Process, DiskInfo)
    file/file.mv      - File I/O (File, FileStat, Path, Dir)
    socket/socket.mv  - Networking (Socket, SockAddrIn, PollFd)
    threads/threads.mv - Threading (Thread, Mutex, CondVar, RwLock)
"""

import os
import sys
import argparse
from pathlib import Path
from typing import List, Tuple

# Try to import rich for colored output
try:
    from rich import print
    HAS_RICH = True
except ImportError:
    HAS_RICH = False


# Module structure
# All modules are now pure ManV (.mv files)
MODULES = [
    "core/core.mv",
    "io/io.mv",
    "math/math.mv",
    "memory/memory.mv",
    "exception/exception.mv",
    "sys/sys.mv",
    "os/os.mv",
    "file/file.mv",
    "socket/socket.mv",
    "threads/threads.mv",
    "collections/collections.mv",
    "hash/hash.mv",
    "encoding/encoding.mv",
    "time/time.mv",
    "crypto/crypto.mv",
    "compression/compression.mv",
    "json/json.mv",
    "toml/toml.mv",
    "dotenv/dotenv.mv",
    "logger/logger.mv",
    "test/test.mv",
]


def log_info(message: str) -> None:
    """Print info message."""
    if HAS_RICH:
        print(f"[bold green][INFO][reset]: {message}")
    else:
        print(f"[INFO]: {message}")


def log_error(message: str) -> None:
    """Print error message."""
    if HAS_RICH:
        print(f"[bold red][ERROR][reset]: {message}")
    else:
        print(f"[ERROR]: {message}")


def log_warn(message: str) -> None:
    """Print warning message."""
    if HAS_RICH:
        print(f"[bold yellow][WARN][reset]: {message}")
    else:
        print(f"[WARN]: {message}")


def validate_modules(stdlib_dir: Path) -> bool:
    """
    Validate that all module files exist.
    
    Args:
        stdlib_dir: Path to stdlib directory
    
    Returns:
        True if all modules exist
    """
    log_info("Validating modules...")
    
    all_valid = True
    
    for module in MODULES:
        module_path = stdlib_dir / module
        
        if not module_path.exists():
            log_error(f"Module not found: {module}")
            all_valid = False
        else:
            if HAS_RICH:
                print(f"  [green]✓[reset] {module}")
            else:
                print(f"  ✓ {module}")
    
    return all_valid


def check_old_files(stdlib_dir: Path) -> List[Path]:
    """
    Check for old .mvh and .asm files that should be removed.
    
    Args:
        stdlib_dir: Path to stdlib directory
    
    Returns:
        List of old files found
    """
    old_files = []
    
    # Look for .mvh files
    for mvh_file in stdlib_dir.glob("**/*.mvh"):
        old_files.append(mvh_file)
    
    # Look for .asm files
    for asm_file in stdlib_dir.glob("**/*.asm"):
        old_files.append(asm_file)
    
    return old_files


def clean_build(stdlib_dir: Path) -> None:
    """Clean build artifacts."""
    log_info("Cleaning build artifacts...")
    
    # Check for and warn about old files
    old_files = check_old_files(stdlib_dir)
    
    if old_files:
        log_warn("Found old files that should be removed:")
        for f in old_files:
            if HAS_RICH:
                print(f"  [yellow]-[reset] {f}")
            else:
                print(f"  - {f}")
    else:
        log_info("No old files found.")
    
    # Remove build directory
    build_dir = stdlib_dir / "build"
    if build_dir.exists():
        for obj_file in build_dir.glob("*.o"):
            obj_file.unlink()
            if HAS_RICH:
                print(f"  [yellow]Removed[reset] {obj_file}")
            else:
                print(f"  Removed {obj_file}")
        
        # Remove build directory if empty
        try:
            build_dir.rmdir()
            if HAS_RICH:
                print(f"  [yellow]Removed[reset] {build_dir}")
            else:
                print(f"  Removed {build_dir}")
        except:
            pass
    
    # Remove old .a files
    for archive in stdlib_dir.glob("*.a"):
        archive.unlink()
        if HAS_RICH:
            print(f"  [yellow]Removed[reset] {archive}")
        else:
            print(f"  Removed {archive}")


def generate_module_info(stdlib_dir: Path) -> None:
    """Generate module information file."""
    info_path = stdlib_dir / "modules.txt"
    
    with open(info_path, "w") as f:
        f.write("# ManV Standard Library Modules\n")
        f.write("# Auto-generated by build.py\n\n")
        
        for module in MODULES:
            f.write(f"{module}\n")
    
    log_info(f"Generated module info: {info_path}")


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Build ManV standard library (pure ManV, no assembly)"
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Clean build artifacts before building"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print verbose output"
    )
    parser.add_argument(
        "--stdlib-dir",
        type=Path,
        default=None,
        help="Path to stdlib directory (default: script directory)"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Only validate modules, don't build"
    )
    
    args = parser.parse_args()
    
    # Determine stdlib directory
    if args.stdlib_dir:
        stdlib_dir = args.stdlib_dir.resolve()
    else:
        stdlib_dir = Path(__file__).parent.resolve()
    
    # Clean if requested
    if args.clean:
        clean_build(stdlib_dir)
    
    log_info(f"Stdlib directory: {stdlib_dir}")
    
    # Validate modules
    if not validate_modules(stdlib_dir):
        return 1
    
    if args.check:
        log_info("Validation complete!")
        return 0
    
    # Check for old files
    old_files = check_old_files(stdlib_dir)
    if old_files:
        log_warn("Found old files. Run with --clean to see details.")
    
    # Generate module info
    generate_module_info(stdlib_dir)
    
    log_info("Build complete!")
    log_info("Note: The stdlib is now pure ManV. Use the ManV compiler to compile .mv files.")
    
    # Print summary
    print()
    print("Available modules:")
    for module in MODULES:
        module_path = stdlib_dir / module
        if module_path.exists():
            size = module_path.stat().st_size
            if HAS_RICH:
                print(f"  [green]INFO[reset] {module} ({size:,} bytes)")
            else:
                print(f"  INFO {module} ({size:,} bytes)")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())