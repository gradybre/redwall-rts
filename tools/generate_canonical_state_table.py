#!/usr/bin/env python3
"""Compile docs/planning/canonical_state_registry.json into the GDScript declaration table.

REG-R01 (docs/rulings/2026-09-12_save_registry_answers.md) makes the registry the single
source of canonical record order, and ADR 0127 explains why the runtime cannot read that
JSON: it lives outside `res://` and Godot's `JSON.parse_string()` would put a float on the
path of `ordinal`, `type_code` and `section_id`. The compromise is a checked-in compiled
table. This script is what compiles it, so the table is never hand-maintained.

It rewrites only the region between the BEGIN/END marker comments in
`godot/scripts/core/canonical_state_hash.gd`; everything else in that file is hand-written
and is left byte-identical. `--check` rewrites nothing and exits 1 on any drift, which is
what CI and a reviewer should run.

`test_canonical_state_hash.gd` re-reads the same JSON from Godot and compares every emitted
entry against it, so this script is a convenience and not a trusted oracle.
"""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "docs/planning/canonical_state_registry.json"
TARGET = ROOT / "godot/scripts/core/canonical_state_hash.gd"

BEGIN = "# --- BEGIN GENERATED DECLARATION TABLE ---"
END = "# --- END GENERATED DECLARATION TABLE ---"

# One leading tab rendered at the project's four-column tab stop, wrapped inside 100 columns.
TAB_COLUMNS = 4
LINE_COLUMNS = 100


def wrap_items(items: list) -> str:
    """Greedily pack rendered items onto tab-indented lines that end inside 100 columns."""
    lines = []
    current = ""
    for index, item in enumerate(items):
        piece = item + ("" if index == len(items) - 1 else ",")
        candidate = piece if not current else current + " " + piece
        if current and TAB_COLUMNS + len(candidate) > LINE_COLUMNS:
            lines.append("\t" + current)
            current = piece
        else:
            current = candidate
    if current:
        lines.append("\t" + current)
    return "\n".join(lines)


def array_block(name: str, items: list) -> str:
    """Render one `const NAME: Array = [ ... ]` declaration with wrapped contents."""
    return "const %s: Array = [\n%s\n]" % (name, wrap_items(items))


def collect(data: dict) -> dict:
    """Flatten the registry into the parallel columns the GDScript table declares."""
    owners = data["owners"]
    out = {
        "sections": [], "keys": [], "versions": [], "field_counts": [],
        "field_keys": [], "field_types": [], "excluded": [],
        "count_indexes": [], "count_values": [], "cap_indexes": [], "cap_values": [],
    }
    index = 0
    for owner in owners:
        out["sections"].append(str(owner["section_id"]))
        out["keys"].append(json.dumps(owner["owner_key"]))
        out["versions"].append(str(owner["owner_schema_version"]))
        out["field_counts"].append(str(len(owner["fields"])))
        for field in owner["fields"]:
            out["field_keys"].append(json.dumps(field["field_key"]))
            out["field_types"].append(str(field["type_code"]))
            if not field["hash"]:
                out["excluded"].append(str(index))
            if "count" in field["shape"]:
                out["count_indexes"].append(str(index))
                out["count_values"].append(str(field["shape"]["count"]))
            if "max_utf8_bytes" in field:
                out["cap_indexes"].append(str(index))
                out["cap_values"].append(str(field["max_utf8_bytes"]))
            index += 1
    out["field_total"] = index
    return out


def render(data: dict) -> str:
    """Build the whole marker-to-marker region, including its provenance header comment."""
    table = collect(data)
    records = sum(int(f["hash"]) for o in data["owners"] for f in o["fields"])
    # THE BLIND SPOT THIS CLOSES. `records` is COMPUTED from the owners, and everything below
    # emits the computed value, so a stale `record_count` sitting in the registry passed
    # --check untouched: the generator regenerated a table that agreed with itself while
    # disagreeing with the artifact it generates from. Found by decision 0142's mutant M11,
    # where freezing record_count at 599 left this check green and only
    # validate_save_registry_handoff.py refused. Two checks that look complementary are not
    # complementary if one of them cannot see the field the other is pinning.
    declared_records = int(data["record_count"])
    if records != declared_records:
        raise SystemExit(
            "generate_canonical_state_table: registry record_count is %d but its owners carry "
            "%d hash:true fields. The declared count is stale or a field's hash flag moved; "
            "fix the registry rather than regenerating over it." % (declared_records, records))
    header = [
        BEGIN,
        "# Generated from docs/planning/canonical_state_registry.json by",
        "# tools/generate_canonical_state_table.py. Do not hand-edit: test_canonical_state_hash.gd",
        "# re-reads that JSON and proves every entry below equals it.",
        "#   registry_id %s, registry_version %d" % (data["registry_id"], data["registry_version"]),
        "#   %d owners, %d declared fields, %d canonical records, %d persisted packed fields."
        % (len(data["owners"]), table["field_total"], records, data["packed_source_field_count"]),
        "",
        'const DECLARATION_ID: String = "%s"' % data["registry_id"],
        "const DECLARATION_VERSION: int = %d" % data["registry_version"],
        "const CANONICAL_OWNER_COUNT: int = %d" % len(data["owners"]),
        "const CANONICAL_FIELD_COUNT: int = %d" % table["field_total"],
        "const CANONICAL_RECORD_COUNT: int = %d" % records,
        "",
    ]
    body = [
        array_block("OWNER_SECTIONS", table["sections"]), "",
        array_block("OWNER_KEYS", table["keys"]), "",
        array_block("OWNER_VERSIONS", table["versions"]), "",
        array_block("OWNER_FIELD_COUNTS", table["field_counts"]), "",
        array_block("FIELD_KEYS", table["field_keys"]), "",
        array_block("FIELD_TYPES", table["field_types"]), "",
        "## Field indexes the registry marks hash=false: emitted by no record. See hash_location.",
        array_block("FIELD_EXCLUDED_INDEXES", table["excluded"]), "",
        "## Sparse (index, value) pairs for fields whose shape declares an exact element count.",
        array_block("FIELD_COUNT_INDEXES", table["count_indexes"]),
        array_block("FIELD_COUNT_VALUES", table["count_values"]), "",
        "## Sparse (index, value) pairs for type-5 fields' declared UTF-8 byte cap (SAVE-R09-002).",
        array_block("FIELD_MAX_UTF8_INDEXES", table["cap_indexes"]),
        array_block("FIELD_MAX_UTF8_VALUES", table["cap_values"]),
        END,
    ]
    return "\n".join(header + body) + "\n"


def splice(source: str, region: str) -> str:
    """Replace the marked region in the target source, refusing if a marker is missing."""
    start = source.index(BEGIN)
    stop = source.index(END) + len(END) + 1
    return source[:start] + region + source[stop:]


def main() -> int:
    """Regenerate or check the compiled declaration table. Returns 0 when in sync."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 on drift, write nothing")
    args = parser.parse_args()
    data = json.loads(REGISTRY.read_text())
    source = TARGET.read_text()
    updated = splice(source, render(data))
    if updated == source:
        print("PASS generated declaration table matches %s" % REGISTRY.name)
        return 0
    if args.check:
        print("DRIFT: %s does not match %s; rerun without --check" % (TARGET.name, REGISTRY.name))
        return 1
    TARGET.write_text(updated)
    print("REWROTE generated declaration table in %s" % TARGET.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
