#!/usr/bin/env python3
"""
Test runner for validating DecentDB imports from test-data files.

Usage:
    python test-data/test_import_runner.py [--dbench PATH] [--dry-run]

Requirements:
    - Python 3.8+
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parent.parent
TEST_DATA_DIR = REPO_ROOT / "test-data"
MANIFEST_PATH = REPO_ROOT / "apps/decent-bench/test/support/import_fixture_manifest.dart"
DBENCH_DEFAULT = "apps/decent-bench/build/linux/x64/release/bundle/dbench"
ROUND_TRIP_FIXTURE_SECTIONS = (
    "genericImportRoundTripFixtures",
    "sqliteImportRoundTripFixtures",
    "excelImportRoundTripFixtures",
    "sqlDumpImportRoundTripFixtures",
)
ACCOUNTING_ONLY_FIXTURE_SECTIONS = (
    "genericInspectionFixtures",
    "sqliteInspectionFixtures",
    "detectionFixtures",
)
NON_IMPORT_DOCUMENTATION_FIXTURE_PATHS = {
    "test-data/README.md",
    "test-data/excel/README.txt",
    "test-data/test_import_runner.py",
}


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
    report: Optional[dict] = None
    details: dict = field(default_factory=dict)


@dataclass(frozen=True)
class CoverageFixture:
    """Represents a non-import fixture that is still accounted for in the manifest."""

    relative_path: str
    section: str

    @property
    def name(self) -> str:
        return Path(self.relative_path).name


@dataclass(frozen=True)
class FixtureAccounting:
    """Summary of how test-data files are represented in the manifest."""

    import_fixtures: tuple[TestFile, ...]
    coverage_only_fixtures: tuple[CoverageFixture, ...]
    uncovered_fixture_paths: tuple[str, ...]


def _discover_manifest_relative_paths(section_names: tuple[str, ...]) -> dict[str, list[str]]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Import fixture manifest not found: {MANIFEST_PATH}")

    manifest_text = MANIFEST_PATH.read_text(encoding="utf-8")
    discovered: dict[str, list[str]] = {}
    for section_name in section_names:
        section_body = _extract_manifest_section(manifest_text, section_name)
        discovered[section_name] = re.findall(
            r"relativePath:\s*'([^']+)'", section_body
        )
    return discovered


def discover_test_files() -> list[TestFile]:
    """Discover importable fixtures from the in-repo round-trip fixture manifest."""
    discovered = _discover_manifest_relative_paths(ROUND_TRIP_FIXTURE_SECTIONS)
    relative_paths: list[str] = []
    for section_name in ROUND_TRIP_FIXTURE_SECTIONS:
        relative_paths.extend(discovered[section_name])

    test_files: list[TestFile] = []
    for relative_path in relative_paths:
        path = REPO_ROOT / relative_path
        if not path.exists():
            raise FileNotFoundError(
                f"Fixture listed in manifest does not exist on disk: {relative_path}"
            )
        test_files.append(TestFile(path=path, format=classify_fixture_format(path)))

    return sorted(test_files, key=lambda item: (item.format, str(item.path)))


def _is_ignored_fixture_path(relative_path: str) -> bool:
    normalized = relative_path.replace(os.sep, "/")
    return (
        normalized in NON_IMPORT_DOCUMENTATION_FIXTURE_PATHS
        or "/__pycache__/" in f"/{normalized}"
        or normalized.endswith((".pyc", ".pyo", ".ddb", ".ddb-wal", ".ddb-shm"))
    )


def discover_fixture_accounting() -> FixtureAccounting:
    import_fixtures = discover_test_files()
    accounting_paths = _discover_manifest_relative_paths(ACCOUNTING_ONLY_FIXTURE_SECTIONS)

    coverage_only: list[CoverageFixture] = []
    for section_name in ACCOUNTING_ONLY_FIXTURE_SECTIONS:
        for relative_path in accounting_paths[section_name]:
            path = REPO_ROOT / relative_path
            if not path.exists():
                raise FileNotFoundError(
                    f"Fixture listed in manifest does not exist on disk: {relative_path}"
                )
            coverage_only.append(
                CoverageFixture(relative_path=relative_path, section=section_name)
            )

    discovered_fixture_paths = {
        str(path.relative_to(REPO_ROOT)).replace(os.sep, "/")
        for path in TEST_DATA_DIR.rglob("*")
        if path.is_file()
    }
    non_ignored_fixture_paths = {
        relative_path
        for relative_path in discovered_fixture_paths
        if not _is_ignored_fixture_path(relative_path)
    }
    manifest_covered_paths = {
        str(test_file.path.relative_to(REPO_ROOT)).replace(os.sep, "/")
        for test_file in import_fixtures
    } | {fixture.relative_path for fixture in coverage_only}

    uncovered = sorted(non_ignored_fixture_paths.difference(manifest_covered_paths))

    return FixtureAccounting(
        import_fixtures=tuple(import_fixtures),
        coverage_only_fixtures=tuple(
            sorted(coverage_only, key=lambda item: (item.section, item.relative_path))
        ),
        uncovered_fixture_paths=tuple(uncovered),
    )


def _extract_manifest_section(source: str, section_name: str) -> str:
    marker = f"{section_name} ="
    marker_index = source.find(marker)
    if marker_index == -1:
        raise ValueError(f"Could not locate manifest section: {section_name}")

    list_start = source.find("[", marker_index)
    if list_start == -1:
        raise ValueError(f"Could not locate list start for manifest section: {section_name}")

    depth = 0
    in_string = False
    escape = False
    for index in range(list_start, len(source)):
        char = source[index]
        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == "'":
                in_string = False
            continue

        if char == "'":
            in_string = True
            continue
        if char == "[":
            depth += 1
            continue
        if char == "]":
            depth -= 1
            if depth == 0:
                return source[list_start : index + 1]

    raise ValueError(f"Manifest section is missing a closing bracket: {section_name}")


def classify_fixture_format(path: Path) -> str:
    lower_name = path.name.lower()
    lower_suffixes = [suffix.lower() for suffix in path.suffixes]

    if lower_name.endswith(".sql.gz") or path.suffix.lower() == ".sql":
        return "sql_dump"
    if path.suffix.lower() in {".sqlite", ".sqlite3", ".db"}:
        return "sqlite"
    if path.suffix.lower() in {".xlsx", ".xls"}:
        return "excel"
    if path.suffix.lower() in {".html", ".htm"}:
        return "html"
    if path.suffix.lower() == ".xml":
        return "xml"
    if path.suffix.lower() in {".json", ".ndjson", ".jsonl"}:
        return "json"
    if lower_name.endswith(".csv.gz") or path.suffix.lower() in {".csv", ".tsv", ".psv"}:
        return "delimited"
    if ".gz" in lower_suffixes:
        return "compressed"
    return "other"


def get_import_command(
    dbench_path: str, source: Path, target: Path, plan: Optional[Path] = None
) -> list[str]:
    """Build the dbench import command."""
    cmd = [dbench_path, "--in", str(source), "--out", str(target), "--silent"]
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
            cmd, capture_output=True, text=True, timeout=timeout, cwd=REPO_ROOT
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

    return details


def parse_import_report(output: str) -> Optional[dict]:
    """Parse the final headless JSON summary from stdout/stderr text."""
    for line in reversed(output.splitlines()):
        candidate = line.strip()
        if not candidate or not candidate.startswith("{"):
            continue
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict) and "target_path" in parsed:
            return parsed
    return None


def run_single_test(
    dbench_path: str, test_file: TestFile, temp_dir: Path, keep_ddbs: bool = False
) -> TestResult:
    """Run a single import test."""
    target_name = test_file.path.stem + ".ddb"
    target_path = temp_dir / target_name

    # Run import
    success, output = run_import(dbench_path, test_file.path, target_path)
    report = parse_import_report(output)

    if not success:
        return TestResult(
            file=test_file,
            success=False,
            message="Import failed",
            error=output,
            report=report,
        )

    # Validate import
    details = validate_import(target_path, test_file)
    details["report"] = report

    if report is None:
        return TestResult(
            file=test_file,
            success=False,
            message="Validation failed",
            ddb_path=target_path if keep_ddbs else None,
            error="Headless import did not emit a final JSON report",
            report=report,
            details=details,
        )

    imported_tables = report.get("imported_tables") or []
    database_tables = report.get("database_tables") or []
    if not imported_tables:
        return TestResult(
            file=test_file,
            success=False,
            message="Validation failed",
            ddb_path=target_path if keep_ddbs else None,
            error="Headless import report contained no imported tables",
            report=report,
            details=details,
        )
    if not database_tables:
        return TestResult(
            file=test_file,
            success=False,
            message="Validation failed",
            ddb_path=target_path if keep_ddbs else None,
            error="Headless import report contained no database tables",
            report=report,
            details=details,
        )

    if "error" in details:
        return TestResult(
            file=test_file,
            success=False,
            message="Validation failed",
            ddb_path=target_path if keep_ddbs else None,
            error=details["error"],
            report=report,
            details=details,
        )

    # Clean up unless keep_ddbs is True
    if not keep_ddbs:
        cleanup_generated_database(target_path)

    return TestResult(
        file=test_file,
        success=True,
        message="Import successful",
        ddb_path=target_path if keep_ddbs else None,
        report=report,
        details=details,
    )


def cleanup_generated_database(path: Path) -> None:
    for candidate in (path, Path(f"{path}-wal"), Path(f"{path}-shm")):
        if candidate.exists():
            candidate.unlink()


def check_dbench_available(dbench_path: str) -> bool:
    """Check if dbench is available and supports headless import."""
    try:
        result = subprocess.run(
            [dbench_path, "--in", "/no/such/source.csv", "--out", "/tmp/test.ddb", "--silent"],
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
        help="Only test fixtures of this format (sqlite, html, excel, json, xml, delimited, sql_dump)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show detailed output"
    )

    args = parser.parse_args()

    # Resolve dbench path
    dbench_path = Path(args.dbench)
    if not dbench_path.is_absolute():
        dbench_path = REPO_ROOT / dbench_path

    if not dbench_path.exists():
        print(f"Error: dbench not found at: {dbench_path}")
        print("Build the project first with: flutter build linux")
        sys.exit(1)

    # Discover test files and overall manifest accounting.
    accounting = discover_fixture_accounting()
    test_files = list(accounting.import_fixtures)

    if args.format:
        test_files = [f for f in test_files if f.format == args.format]

    if not test_files:
        print("No test files found.")
        sys.exit(0)

    print(f"Found {len(test_files)} import fixtures from the round-trip manifest:")
    for tf in test_files:
        print(f"  [{tf.format}] {tf.name}")
    print()

    coverage_only = accounting.coverage_only_fixtures
    print(f"Found {len(coverage_only)} additional coverage-only fixtures:")
    for fixture in coverage_only:
        print(f"  [{fixture.section}] {fixture.name}")
    print()

    accounted_total = len(accounting.import_fixtures) + len(coverage_only)
    if accounting.uncovered_fixture_paths:
        print(
            f"Manifest accounting check: {accounted_total} covered, "
            f"{len(accounting.uncovered_fixture_paths)} uncovered"
        )
        for relative_path in accounting.uncovered_fixture_paths:
            print(f"  [uncovered] {relative_path}")
        sys.exit(1)

    print(
        "Manifest accounting check: "
        f"{accounted_total} non-document test-data files are covered"
    )
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
    print(f"Import results: {passed} passed, {failed} failed, {len(test_files)} total")
    print(
        "Coverage-only fixtures accounted for: "
        f"{len(coverage_only)}"
    )
    print(
        "Overall manifest accounting: "
        f"{len(accounting.import_fixtures) + len(coverage_only)} covered, 0 uncovered"
    )

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
