#!/usr/bin/env python3
"""Extract the authoritative ItemDefinition catalog from docs/gameplay_balance.md §3.1.

docs/gameplay_balance.md §3.1 "ItemDefinition rows" is the single source of truth for the
game's item catalog (GDD §4.2/§4.3, BAL-CAT-001/002). This script parses that markdown table
and emits godot/data/item_definitions.json, so the catalog has exactly one authored source and
is mechanically regenerable whenever the balance document changes -- nobody hand-copies the
table into JSON or into GDScript.

Usage (from the repository root):
    python3 tools/extract_item_definitions.py

Exits 0 and writes the JSON file only when every guard below passes. Any guard failure prints
a message to stderr and exits non-zero without writing a (possibly stale) output file:

  * the §3.1 section must contain exactly 60 data rows (the current authored catalog size);
  * no item id may repeat;
  * every numeric column (mass_g, nutrition_per_u, shelf_hours, raw_edible, seed, effect_value)
    must parse as a base-10 integer -- a decimal point, exponent, or empty cell is rejected;
  * raw_edible and seed must each be exactly "0" or "1";
  * no item id may be one of the nine keys retired by SET-AMEND-001 §3 (docs/setting_rules_amendment.md):
    bow, carcass_boar, carcass_deer, carcass_grouse, hide, hunting_tool, meal_game_roast,
    raw_game, smoked_game (REQ-ADM-003: a retired key is rejected, never carried forward).

Standard library only -- no third-party dependencies.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Optional

REPO_ROOT: Path = Path(__file__).resolve().parent.parent
SOURCE_DOC: Path = REPO_ROOT / "docs" / "gameplay_balance.md"
OUTPUT_JSON: Path = REPO_ROOT / "godot" / "data" / "item_definitions.json"

SECTION_START: str = "### 3.1 ItemDefinition rows"
SECTION_END: str = "### 3.2"

EXPECTED_HEADER: list[str] = [
    "id", "category", "mass_g", "nutrition_per_u", "shelf_hours",
    "raw_edible", "seed", "effect", "effect_value", "Provenance",
]
EXPECTED_ROW_COUNT: int = 61

# SET-AMEND-001 §3 (docs/setting_rules_amendment.md): retired item keys. REQ-ADM-003 requires
# these be rejected outright, never substituted or carried into the compiled catalog.
RETIRED_KEYS: frozenset[str] = frozenset({
    "bow", "carcass_boar", "carcass_deer", "carcass_grouse", "hide",
    "hunting_tool", "meal_game_roast", "raw_game", "smoked_game",
})

INTEGER_PATTERN: re.Pattern[str] = re.compile(r"^-?\d+$")
NUMERIC_COLUMNS: tuple[str, ...] = (
    "mass_g", "nutrition_per_u", "shelf_hours", "raw_edible", "seed", "effect_value",
)
BOOLEAN_COLUMNS: tuple[str, ...] = ("raw_edible", "seed")


class ExtractionError(Exception):
    """Raised for any guard failure; the message is printed to stderr verbatim."""


def _extract_section(document_text: str) -> str:
    """Return the raw text of §3.1, from its heading up to (not including) §3.2."""
    start_index: int = document_text.find(SECTION_START)
    if start_index == -1:
        raise ExtractionError("could not find section heading %r in %s" % (SECTION_START, SOURCE_DOC))
    end_index: int = document_text.find(SECTION_END, start_index)
    if end_index == -1:
        raise ExtractionError("could not find section heading %r after §3.1" % SECTION_END)
    return document_text[start_index:end_index]


def _split_row(line: str) -> list[str]:
    """Split one markdown table row on '|', trimming the leading/trailing empty cells."""
    cells: list[str] = line.split("|")
    if cells and cells[0].strip() == "":
        cells = cells[1:]
    if cells and cells[-1].strip() == "":
        cells = cells[:-1]
    return [cell.strip() for cell in cells]


def _is_separator_row(cells: list[str]) -> bool:
    """True when every cell is a run of dashes, i.e. the markdown header/body separator."""
    return all(re.fullmatch(r"-+:?|:?-+", cell) for cell in cells)


def _find_table_lines(section_text: str) -> list[str]:
    """Return every '|'-delimited line inside the §3.1 section, in document order."""
    return [line for line in section_text.splitlines() if line.strip().startswith("|")]


def _parse_table(section_text: str) -> list[dict[str, str]]:
    """Parse the §3.1 markdown table into a list of raw (still-string) column dictionaries."""
    lines: list[str] = _find_table_lines(section_text)
    if len(lines) < 2:
        raise ExtractionError("§3.1 table has too few rows to contain a header and a separator")
    header_cells: list[str] = _split_row(lines[0])
    if header_cells != EXPECTED_HEADER:
        raise ExtractionError(
            "§3.1 header changed shape: expected %r, found %r" % (EXPECTED_HEADER, header_cells)
        )
    if not _is_separator_row(_split_row(lines[1])):
        raise ExtractionError("§3.1 second table line is not a markdown header separator")
    data_rows: list[dict[str, str]] = []
    for line in lines[2:]:
        cells: list[str] = _split_row(line)
        if len(cells) != len(EXPECTED_HEADER):
            raise ExtractionError("§3.1 row has %d cells, expected %d: %r" % (len(cells), len(EXPECTED_HEADER), line))
        data_rows.append(dict(zip(EXPECTED_HEADER, cells)))
    return data_rows


def _validate_row_count(rows: list[dict[str, str]]) -> None:
    """Fail loudly unless §3.1 contains exactly the expected number of data rows."""
    if len(rows) != EXPECTED_ROW_COUNT:
        raise ExtractionError(
            "§3.1 has %d data row(s), expected exactly %d" % (len(rows), EXPECTED_ROW_COUNT)
        )


def _validate_unique_ids(rows: list[dict[str, str]]) -> None:
    """Fail loudly on any duplicated item id."""
    seen: set[str] = set()
    for row in rows:
        item_id: str = row["id"]
        if item_id in seen:
            raise ExtractionError("duplicate item id %r in §3.1" % item_id)
        seen.add(item_id)


def _validate_no_retired_keys(rows: list[dict[str, str]]) -> None:
    """Fail loudly if a SET-AMEND-001 retired key is present (REQ-ADM-003)."""
    for row in rows:
        if row["id"] in RETIRED_KEYS:
            raise ExtractionError(
                "retired key %r (SET-AMEND-001 §3) is present in §3.1; it must be removed, "
                "not compiled" % row["id"]
            )


def _validate_and_convert_numeric(row: dict[str, str], row_index: int) -> dict[str, Any]:
    """Return `row` with every numeric column parsed to int, refusing non-integer text."""
    converted: dict[str, Any] = dict(row)
    for column in NUMERIC_COLUMNS:
        raw_value: str = row[column]
        if not INTEGER_PATTERN.match(raw_value):
            raise ExtractionError(
                "row %d (id=%r): column %r is not a base-10 integer: %r"
                % (row_index, row["id"], column, raw_value)
            )
        converted[column] = int(raw_value)
    for column in BOOLEAN_COLUMNS:
        if converted[column] not in (0, 1):
            raise ExtractionError(
                "row %d (id=%r): column %r must be 0 or 1, got %d"
                % (row_index, row["id"], column, converted[column])
            )
    return converted


def _build_records(rows: list[dict[str, str]]) -> list[dict[str, Any]]:
    """Validate and convert every row, dropping the documentation-only Provenance column."""
    records: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        converted: dict[str, Any] = _validate_and_convert_numeric(row, index)
        records.append({
            "id": converted["id"],
            "category": converted["category"],
            "mass_g": converted["mass_g"],
            "nutrition_per_u": converted["nutrition_per_u"],
            "shelf_hours": converted["shelf_hours"],
            "raw_edible": converted["raw_edible"],
            "seed": converted["seed"],
            "effect": converted["effect"],
            "effect_value": converted["effect_value"],
        })
    return records


def extract(source_path: Path = SOURCE_DOC) -> list[dict[str, Any]]:
    """Parse, validate, and return the full list of ItemDefinition records from `source_path`.

    `source_path` defaults to the real docs/gameplay_balance.md; the test suite
    (godot/test/test_item_definitions.gd) points it at throwaway fixture documents to exercise
    each guard (bad row count, duplicate id, retired key, non-integer field) without touching
    the real balance document.
    """
    document_text: str = source_path.read_text(encoding="utf-8")
    section_text: str = _extract_section(document_text)
    rows: list[dict[str, str]] = _parse_table(section_text)
    _validate_row_count(rows)
    _validate_unique_ids(rows)
    _validate_no_retired_keys(rows)
    return _build_records(rows)


def _parse_args(argv: list[str]) -> Any:
    """Parse optional --source/--output overrides, defaulting to the real repo paths."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE_DOC, help="balance doc to parse")
    parser.add_argument("--output", type=Path, default=OUTPUT_JSON, help="JSON file to write")
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    """Run extraction, write the JSON output, and return a process exit code."""
    args: Any = _parse_args(sys.argv[1:] if argv is None else argv)
    try:
        records: list[dict[str, Any]] = extract(args.source)
    except ExtractionError as error:
        print("extract_item_definitions: %s" % error, file=sys.stderr)
        return 1
    payload: dict[str, Any] = {
        "$schema_note": (
            "Generated by tools/extract_item_definitions.py from docs/gameplay_balance.md "
            "§3.1. Do not hand-edit; re-run the generator after the balance doc changes."
        ),
        "source": "docs/gameplay_balance.md#3.1-ItemDefinition-rows",
        "count": len(records),
        "items": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print("extract_item_definitions: wrote %d record(s) to %s" % (len(records), args.output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
