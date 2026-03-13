#!/usr/bin/env python3
"""
Test runner for validating DecentDB imports from test-data files.

Usage:
    python test_import_runner.py [--dbench PATH] [--dry-run]

Requirements:
    - DecentDB headless import must be implemented (dbench --in --out)
    - Python 3.8+
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


TEST_DATA_DIR = Path(__file__).parent.parent / "test-data"
DBENCH_DEFAULT = "apps/decent-bench/build/linux/x64/release/bundle/dbench"


@dataclass
class TestFile:
    """Represents a test file to import."""

    path: Path
    format: str
    expected_tables: Optional[int] = None
    expected_rows: Optional[dict] = None  # table_name -> row_count
    expected_columns: Optional[dict] = None  # table_name -> column_count
    expected_types: Optional[dict] = None  # table_name -> {col_name -> type}

    @property
    def name(self) -> str:
        return self.path.name


@dataclass
class TestResult:
    """Result of a single test."""

    file: TestFile
    success: bool
    message: str
    ddb_path: Optional[Path] = None
    error: Optional[str] = None
    details: dict = field(default_factory=dict)


def discover_test_files() -> list[TestFile]:
    """Discover all test files in test-data directory."""
    test_files = []

    formats = {
        "sqlite": ["sqlite"],
        "html": ["html"],
        "excel": ["xlsx", "xls"],
        "json": ["json"],
        "xml": ["xml"],
        "delimited": ["csv", "tsv", "txt"],
    }

    for format_name, extensions in formats.items():
        dir_path = TEST_DATA_DIR / format_name
        if not dir_path.exists():
            continue

        for ext in extensions:
            for file_path in dir_path.glob(f"*.{ext}"):
                test_files.append(TestFile(path=file_path, format=format_name))

    return test_files


def get_import_command(
    dbench_path: str, source: Path, target: Path, plan: Optional[Path] = None
) -> list[str]:
    """Build the dbench import command."""
    cmd = [dbench_path, "--in", str(source), "--out", str(target)]
    if plan:
        cmd.extend(["--plan", str(plan)])
    return cmd


def run_import(
    dbench_path: str,
    source: Path,
    target: Path,
    plan: Optional[Path] = None,
    timeout: int = 120,
) -> tuple[bool, str]:
    """Run the import command and return (success, output)."""
    cmd = get_import_command(dbench_path, source, target, plan)

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=source.parent
        )

        if result.returncode == 0:
            return True, result.stdout + result.stderr
        else:
            return False, result.stdout + result.stderr

    except subprocess.TimeoutExpired:
        return False, f"Import timed out after {timeout} seconds"
    except FileNotFoundError:
        return False, f"dbench not found at: {dbench_path}"
    except Exception as e:
        return False, f"Error running import: {e}"


def query_ddb(ddb_path: Path, query: str) -> tuple[bool, str]:
    """Query the imported ddb file using dbench or sqlite3."""
    # Note: This assumes there's a way to query the ddb file
    # For now, we'll just check if the file exists and has content
    if not ddb_path.exists():
        return False, f"Output file not found: {ddb_path}"

    size = ddb_path.stat().st_size
    if size == 0:
        return False, "Output file is empty"

    return True, f"File exists, size: {size} bytes"


def validate_import(ddb_path: Path, test_file: TestFile) -> dict:
    """Validate the imported database."""
    details = {}

    # Check file exists and has content
    if not ddb_path.exists():
        details["error"] = "Output file not found"
        return details

    details["file_size"] = ddb_path.stat().st_size

    # TODO: Add proper validation once we can query ddb files
    # - Connect to ddb and query table counts
    # - Verify row counts match expected
    # - Check column types were inferred correctly
    # - Verify special cases (views, calculated columns, etc.)

    return details


def run_single_test(
    dbench_path: str, test_file: TestFile, temp_dir: Path, keep_ddbs: bool = False
) -> TestResult:
    """Run a single import test."""
    target_name = test_file.path.stem + ".ddb"
    target_path = temp_dir / target_name

    # Run import
    success, output = run_import(dbench_path, test_file.path, target_path)

    if not success:
        return TestResult(
            file=test_file, success=False, message="Import failed", error=output
        )

    # Validate import
    details = validate_import(target_path, test_file)

    if "error" in details:
        return TestResult(
            file=test_file,
            success=False,
            message="Validation failed",
            ddb_path=target_path if keep_ddbs else None,
            error=details["error"],
        )

    # Clean up unless keep_ddbs is True
    if not keep_ddbs and target_path.exists():
        target_path.unlink()

    return TestResult(
        file=test_file,
        success=True,
        message="Import successful",
        ddb_path=target_path if keep_ddbs else None,
        details=details,
    )


def check_dbench_available(dbench_path: str) -> bool:
    """Check if dbench is available and supports headless import."""
    try:
        result = subprocess.run(
            [dbench_path, "--in", "test", "--out", "test.ddb"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = result.stdout + result.stderr
        return (
            "not implemented" not in output.lower()
            and "headless import mode" not in output.lower()
        )
    except Exception:
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Test DecentDB imports from test-data files"
    )
    parser.add_argument(
        "--dbench",
        default=DBENCH_DEFAULT,
        help=f"Path to dbench executable (default: {DBENCH_DEFAULT})",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Discover files but don't run imports"
    )
    parser.add_argument(
        "--skip-import-check",
        action="store_true",
        help="Skip check for headless import implementation (for development)",
    )
    parser.add_argument(
        "--keep-ddbs",
        action="store_true",
        help="Keep ddb files after tests (for debugging)",
    )
    parser.add_argument(
        "--format",
        help="Only test files of this format (sqlite, html, excel, json, xml, delimited)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show detailed output"
    )

    args = parser.parse_args()

    # Resolve dbench path
    dbench_path = Path(args.dbench)
    if not dbench_path.is_absolute():
        # Relative to repo root
        repo_root = TEST_DATA_DIR.parent
        dbench_path = repo_root / dbench_path

    if not dbench_path.exists():
        print(f"Error: dbench not found at: {dbench_path}")
        print("Build the project first with: flutter build linux")
        sys.exit(1)

    # Discover test files
    test_files = discover_test_files()

    if args.format:
        test_files = [f for f in test_files if f.format == args.format]

    if not test_files:
        print("No test files found.")
        sys.exit(0)

    print(f"Found {len(test_files)} test files:")
    for tf in test_files:
        print(f"  [{tf.format}] {tf.name}")
    print()

    if args.dry_run:
        print("Dry run complete (no imports executed)")
        sys.exit(0)

    # Check if headless import is implemented (unless skipped)
    if not args.skip_import_check:
        if not check_dbench_available(str(dbench_path)):
            print("Error: Headless import mode is not implemented yet.")
            print(
                "The dbench CLI must support: dbench --in <source> --out <target.ddb>"
            )
            print(
                "\nTo run in development mode (without actual imports), use: --skip-import-check --dry-run"
            )
            sys.exit(1)

    # Create temp directory
    temp_dir = tempfile.mkdtemp(prefix="dbench_test_")
    print(f"Using temp directory: {temp_dir}\n")

    results: list[TestResult] = []
    passed = 0
    failed = 0

    try:
        for test_file in test_files:
            print(f"Testing: {test_file.name}...", end=" ")

            result = run_single_test(
                str(dbench_path), test_file, Path(temp_dir), args.keep_ddbs
            )

            if result.success:
                print("✓ PASS")
                passed += 1
                if args.verbose:
                    print(f"  Details: {result.details}")
            else:
                print("✗ FAIL")
                failed += 1
                print(f"  Error: {result.error or result.message}")

            results.append(result)

    finally:
        # Clean up temp directory
        if not args.keep_ddbs and Path(temp_dir).exists():
            shutil.rmtree(temp_dir)
            print(f"\nCleaned up temp directory: {temp_dir}")

    # Summary
    print(f"\n{'=' * 50}")
    print(f"Results: {passed} passed, {failed} failed, {len(test_files)} total")

    if failed > 0:
        print("\nFailed tests:")
        for r in results:
            if not r.success:
                print(f"  - {r.file.name}: {r.error or r.message}")
        sys.exit(1)
    else:
        print("\nAll tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
