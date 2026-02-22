#!/usr/bin/env python3
"""
Build script for ManV standard library.

Compiles all assembly files into object files and archives them
into static libraries: libcore.a and libstd.a

Usage:
    python build.py [--clean] [--verbose]

Output:
    libcore.a - Core types (str, int, float, array, bytes, mem)
    libstd.a  - Standard library (io, math, memory)
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path
from typing import List, Tuple

# Try to import rich for colored output
try:
    from rich import print
    HAS_RICH = True
except ImportError:
    HAS_RICH = False


# Library structure
# libcore.a: Core types and utilities
CORE_SOURCES = [
    "core/core.asm",
    "core/str.asm",
    "core/int.asm",
    "core/float.asm",
    "core/array.asm",
    "core/bytes.asm",
]

# libstd.a: Standard library modules
STD_SOURCES = [
    "io/io.asm",
    "math/math.asm",
    "memory/gc.asm",
    "memory/arena.asm",
    "memory/mem.asm",
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


def log_cmd(command: List[str]) -> None:
    """Print command being executed."""
    if HAS_RICH:
        print(f"[bold cyan][CMD][reset]: {' '.join(command)}")
    else:
        print(f"[CMD]: {' '.join(command)}")


def run_command(command: List[str], verbose: bool = False) -> Tuple[bool, str]:
    """
    Run a command and return success status and output.
    
    Args:
        command: Command and arguments to run
        verbose: Whether to print command output
    1
    Returns:
        Tuple of (success, output)
    """
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True
        )
        
        if verbose and result.stdout:
            print(result.stdout)
        if result.stderr and result.returncode != 0:
            print(result.stderr)
        
        return result.returncode == 0, result.stderr
    except FileNotFoundError:
        return False, f"Command not found: {command[0]}"
    except Exception as e:
        return False, str(e)


def check_dependencies() -> bool:
    """Check that required tools are available."""
    log_info("Checking dependencies...")
    
    dependencies = ["nasm", "ar"]
    all_found = True
    
    for dep in dependencies:
        result = subprocess.run(
            ["which", dep],
            capture_output=True
        )
        
        if result.returncode != 0:
            log_error(f"Required tool not found: {dep}")
            all_found = False
        else:
            if HAS_RICH:
                print(f"  [green]✓[reset] {dep}")
            else:
                print(f"  ✓ {dep}")
    
    return all_found


def compile_asm(source: Path, output: Path, verbose: bool = False) -> bool:
    """
    Compile an assembly file to an object file.
    
    Args:
        source: Path to source .asm file
        output: Path to output .o file
        verbose: Whether to print verbose output
    
    Returns:
        True if compilation succeeded
    """
    command = [
        "nasm",
        "-f", "elf64",
        str(source),
        "-o", str(output)
    ]
    
    if verbose:
        log_cmd(command)
    
    success, error = run_command(command, verbose)
    
    if not success:
        log_error(f"Failed to compile {source}")
        if error:
            print(error)
    
    return success


def create_archive(objects: List[Path], output: Path, verbose: bool = False) -> bool:
    """
    Create a static library archive from object files.
    
    Args:
        objects: List of object file paths
        output: Path to output .a file
        verbose: Whether to print verbose output
    
    Returns:
        True if archive creation succeeded
    """
    command = ["ar", "rcs", str(output)] + [str(obj) for obj in objects]
    
    if verbose:
        log_cmd(command)
    
    success, error = run_command(command, verbose)
    
    if not success:
        log_error(f"Failed to create archive {output}")
        if error:
            print(error)
    
    return success


def build_library(
    name: str,
    sources: List[str],
    stdlib_dir: Path,
    build_dir: Path,
    verbose: bool = False
) -> bool:
    """
    Build a static library from assembly sources.
    
    Args:
        name: Library name (without .a extension)
        sources: List of source paths relative to stdlib_dir
        stdlib_dir: Path to stdlib directory
        build_dir: Path to build output directory
        verbose: Whether to print verbose output
    
    Returns:
        True if build succeeded
    """
    log_info(f"Building {name}...")
    
    objects: List[Path] = []
    
    for source in sources:
        source_path = stdlib_dir / source
        
        if not source_path.exists():
            log_error(f"Source file not found: {source_path}")
            return False
        
        # Output object file path
        obj_name = source.replace("/", "_").replace(".asm", ".o")
        obj_path = build_dir / obj_name
        
        # Compile
        if verbose:
            log_info(f"  Compiling {source}")
        
        if not compile_asm(source_path, obj_path, verbose):
            return False
        
        objects.append(obj_path)
    
    # Create archive
    archive_path = stdlib_dir / f"{name}.a"
    
    if verbose:
        log_info(f"  Creating archive {name}.a")
    
    if not create_archive(objects, archive_path, verbose):
        return False
    
    if HAS_RICH:
        print(f"  [green]✓[reset] Created {archive_path}")
    else:
        print(f"  ✓ Created {archive_path}")
    
    return True


def clean_build(stdlib_dir: Path, build_dir: Path) -> None:
    """Clean build artifacts."""
    log_info("Cleaning build artifacts...")
    
    # Remove object files
    for obj_file in build_dir.glob("*.o"):
        obj_file.unlink()
        if HAS_RICH:
            print(f"  [yellow]Removed[reset] {obj_file}")
        else:
            print(f"  Removed {obj_file}")
    
    # Remove archives
    for archive in stdlib_dir.glob("*.a"):
        archive.unlink()
        if HAS_RICH:
            print(f"  [yellow]Removed[reset] {archive}")
        else:
            print(f"  Removed {archive}")


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Build ManV standard library"
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
    
    args = parser.parse_args()
    
    # Determine stdlib directory
    if args.stdlib_dir:
        stdlib_dir = args.stdlib_dir.resolve()
    else:
        stdlib_dir = Path(__file__).parent.resolve()
    
    build_dir = stdlib_dir / "build"
    
    # Check dependencies
    if not check_dependencies():
        return 1
    
    # Create build directory
    build_dir.mkdir(exist_ok=True)
    
    # Clean if requested
    if args.clean:
        clean_build(stdlib_dir, build_dir)
    
    log_info(f"Building in {stdlib_dir}")
    
    # Build libcore.a
    if not build_library("libcore", CORE_SOURCES, stdlib_dir, build_dir, args.verbose):
        return 1
    
    # Build libstd.a
    if not build_library("libstd", STD_SOURCES, stdlib_dir, build_dir, args.verbose):
        return 1
    
    log_info("Build complete!")
    
    # Print summary
    print()
    print("Output files:")
    for lib in ["libcore.a", "libstd.a"]:
        lib_path = stdlib_dir / lib
        if lib_path.exists():
            size = lib_path.stat().st_size
            if HAS_RICH:
                print(f"  [green]✓[reset] {lib_path} ({size:,} bytes)")
            else:
                print(f"  ✓ {lib_path} ({size:,} bytes)")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())