#!/usr/bin/env python3
"""Compile section 6 AUXILIARY_STATE's (or section 5 CHILD_ARENAS') framing table into GDScript.

ADR 1222 step 4a; `--section 5` (ADR 1222 step 3) compiles the same table shape for section 5 into
save_child_arenas_schema.gd, whose codec shares section 6's owner-block wire form.

The runtime may not read the registry JSON (it lives outside res:// and JSON.parse_string()
would put a float on every count), so this script compiles the chosen section's
owners of docs/planning/canonical_state_registry.json into the single marked region of the
GDScript schema module and leaves every hand-written line byte-identical.

Each field compiles to exactly one count rule:

  SCALAR    (0)  shape order "scalar" with count 1: the element count must be 1.
  FIXED     (1)  `count: n`, or a declared_capacity "`NAME` = N": exactly N elements. A declared
                 capacity must ALSO be a proved_equality row of the capacity audit with that value.
  BOUNDED   (2)  "`_x` <= N" (a proved_upper_bound audit row with that value), or a count_field
                 with a literal max_count: 0..N elements.
  UNPROVED  (3)  a count_field with no literal and no audit row. NO BOUND IS GUESSED: the field is
                 compiled as admitting ZERO elements only, is listed in UNPROVED_FIELDS, and is
                 named on stderr every run. `--require-proved` turns that into a refusal (exit 2).

Nothing else is trusted: keys, type codes, ordinals, owner schema versions, ASCII owner order and
the section schema version all come from the registry and are re-checked here; the audit must
name the same registry id and version.

`--check` writes nothing and exits 1 on drift. Any refusal exits 2.

    python3 tools/generate_auxiliary_state_schema.py [--section 5|6] [--check] [--require-proved]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REGISTRY_PATH = ROOT / "docs/planning/canonical_state_registry.json"
AUDIT_PATH = ROOT / "docs/planning/registry_capacity_audit.json"
TARGETS = {
    5: ROOT / "godot/scripts/core/save_child_arenas_schema.gd",
    6: ROOT / "godot/scripts/core/save_auxiliary_state_schema.gd",
}
MARKERS = {
    5: ("# --- BEGIN GENERATED CHILD ARENAS SCHEMA ---", "# --- END GENERATED CHILD ARENAS SCHEMA ---"),
    6: ("# --- BEGIN GENERATED AUXILIARY STATE SCHEMA ---",
        "# --- END GENERATED AUXILIARY STATE SCHEMA ---"),
}

# Rebound by main() from --section; every helper below reads these module globals.
SECTION_ID = 6
TARGET = TARGETS[6]
BEGIN, END = MARKERS[6]
TYPE_CODES = {"u8": 0, "u32": 1, "i32": 2, "u64": 3, "i64": 4}
TYPE_WIDTHS = {0: 1, 1: 4, 2: 4, 3: 8, 4: 8}
RULE_SCALAR, RULE_FIXED, RULE_BOUNDED, RULE_UNPROVED = 0, 1, 2, 3
STORE_COUNT_BYTES = 4
WRAPPER_FIXED_BYTES = 24
FIELD_COUNT_BYTES = 8
LINE_COLUMNS = 100
EQUALITY = re.compile(r"^`([A-Za-z_][A-Za-z0-9_.]*)` = ([0-9]+)$")
UPPER_BOUND = re.compile(r"^`(_[A-Za-z0-9_]+)` <= ([0-9]+)$")


def refuse(message: str) -> None:
    """Stop with a named refusal; nothing is written."""
    print("REFUSED: %s" % message, file=sys.stderr)
    raise SystemExit(2)


def audit_rows(audit: dict, registry: dict) -> dict:
    """Index the audit's rows for SECTION_ID by (owner, field) after checking it audited THIS registry."""
    audited = audit["audited_registry"]
    if (audited["registry_id"], audited["registry_version"]) != (
            registry["registry_id"], registry["registry_version"]):
        refuse("the capacity audit covers %s v%s, not %s v%s" % (
            audited["registry_id"], audited["registry_version"], registry["registry_id"],
            registry["registry_version"]))
    rows = {}
    for row in audit["rows"]:
        if row["section_id"] == SECTION_ID:
            key = (row["owner_key"], row["field_key"])
            if key in rows:
                refuse("the audit has two rows for %s.%s" % key)
            rows[key] = row
    return rows


def audited_value(rows: dict, owner: str, field: str, status: str, relation: str):
    """The audit's proved value for one field under one status/relation, or None."""
    row = rows.get((owner, field))
    if row is None or row["status"] != status or row["source_relation"] != relation:
        return None
    value = row["source_value"]
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        refuse("audit value for %s.%s is not a nonnegative integer" % (owner, field))
    return value


def declared_rule(rows: dict, owner: str, field: str, prose: str) -> tuple:
    """A declared_capacity's rule; the audit must prove exactly the literal the registry states."""
    equality = EQUALITY.match(prose)
    if equality:
        literal = int(equality.group(2))
        if audited_value(rows, owner, field, "proved_equality", "eq") != literal:
            refuse("%s.%s: '%s' has no matching proved_equality row" % (owner, field, prose))
        return (RULE_FIXED, literal)
    bound = UPPER_BOUND.match(prose)
    if bound:
        literal = int(bound.group(2))
        if audited_value(rows, owner, field, "proved_upper_bound", "lte") != literal:
            refuse("%s.%s: '%s' has no matching proved_upper_bound row" % (owner, field, prose))
        return (RULE_BOUNDED, literal)
    refuse("%s.%s: declared_capacity '%s' is neither `N` = n nor `_x` <= n" % (owner, field, prose))
    return (RULE_UNPROVED, 0)


def field_rule(rows: dict, owner: str, field: dict) -> tuple:
    """Compile one registry field's shape into (rule kind, rule value)."""
    shape = field["shape"]
    stride = shape.get("stride", 1)
    if "count" in shape:
        if shape["order"] == "scalar" and shape["count"] == 1:
            return (RULE_SCALAR, 1)
        return (RULE_FIXED, shape["count"])
    if "declared_capacity" in shape:
        if stride != 1:
            refuse("%s.%s: a stride on a declared capacity is ambiguous" % (owner, field["field_key"]))
        return declared_rule(rows, owner, field["field_key"], shape["declared_capacity"])
    if "count_field" not in shape:
        refuse("%s.%s: shape %s has no count rule" % (owner, field["field_key"], shape))
    if "max_count" in shape:
        if stride != 1:
            refuse("%s.%s: max_count with a stride is ambiguous" % (owner, field["field_key"]))
        return (RULE_BOUNDED, shape["max_count"])
    for status, relation in (("proved_equality", "eq"), ("proved_upper_bound", "lte")):
        value = audited_value(rows, owner, field["field_key"], status, relation)
        if value is not None:
            return (RULE_BOUNDED, value * stride)
    return (RULE_UNPROVED, 0)


def check_owner(owner: dict, previous: str) -> None:
    """ASCII order, integer schema, dense ordinals and known type codes for one registry owner."""
    key = owner["owner_key"]
    if not key.isascii() or not (previous < key):
        refuse("owner '%s' does not follow '%s' in ASCII order" % (key, previous))
    schema = owner["owner_schema_version"]
    if isinstance(schema, bool) or not isinstance(schema, int) or schema < 1:
        refuse("owner '%s' schema %r is not a positive integer" % (key, schema))
    for ordinal, field in enumerate(owner["fields"]):
        if field["ordinal"] != ordinal:
            refuse("%s.%s has ordinal %r, expected %d" % (key, field["field_key"],
                                                          field["ordinal"], ordinal))
        if TYPE_CODES.get(field["type"]) != field["type_code"]:
            refuse("%s.%s type %s/%r is not a section-%d type" % (
                key, field["field_key"], field["type"], field["type_code"], SECTION_ID))


def collect(registry: dict, rows: dict) -> dict:
    """Every owner's fields compiled into flat columns plus per-owner begin/count indexes."""
    owners = [o for o in registry["owners"] if o["section_id"] == SECTION_ID]
    table = {name: [] for name in ("OWNER_KEYS", "OWNER_SCHEMAS", "OWNER_FIELD_BEGIN",
                                   "OWNER_FIELD_COUNTS", "FIELD_KEYS", "FIELD_TYPES",
                                   "RULE_KINDS", "RULE_VALUES", "UNPROVED_FIELDS")}
    previous = ""
    for owner in owners:
        check_owner(owner, previous)
        previous = owner["owner_key"]
        table["OWNER_KEYS"].append(owner["owner_key"])
        table["OWNER_SCHEMAS"].append(owner["owner_schema_version"])
        table["OWNER_FIELD_BEGIN"].append(len(table["FIELD_KEYS"]))
        table["OWNER_FIELD_COUNTS"].append(len(owner["fields"]))
        for field in owner["fields"]:
            kind, value = field_rule(rows, owner["owner_key"], field)
            table["FIELD_KEYS"].append(field["field_key"])
            table["FIELD_TYPES"].append(field["type_code"])
            table["RULE_KINDS"].append(kind)
            table["RULE_VALUES"].append(value)
            if kind == RULE_UNPROVED:
                table["UNPROVED_FIELDS"].append("%s.%s" % (owner["owner_key"], field["field_key"]))
    return table


def section_bytes(table: dict, maximum: bool) -> int:
    """The section length with every field at its canonical-empty or its maximum count."""
    total = STORE_COUNT_BYTES
    for owner, key in enumerate(table["OWNER_KEYS"]):
        total += WRAPPER_FIXED_BYTES + len(key.encode("utf-8"))
        begin = table["OWNER_FIELD_BEGIN"][owner]
        for index in range(begin, begin + table["OWNER_FIELD_COUNTS"][owner]):
            kind, value = table["RULE_KINDS"][index], table["RULE_VALUES"][index]
            count = value if kind in (RULE_SCALAR, RULE_FIXED) or (
                maximum and kind == RULE_BOUNDED) else 0
            total += FIELD_COUNT_BYTES + count * TYPE_WIDTHS[table["FIELD_TYPES"][index]]
    return total


def wrap_items(items: list) -> str:
    """Comma-separated items wrapped inside LINE_COLUMNS with one leading tab (4 columns)."""
    lines, current = [], ""
    for item in items:
        piece = item + ","
        if current and 4 + len(current) + 1 + len(piece) > LINE_COLUMNS:
            lines.append("\t" + current)
            current = piece
        else:
            current = piece if not current else current + " " + piece
    if current:
        lines.append("\t" + current)
    return "\n".join(lines)


def array_block(name: str, gd_type: str, items: list) -> str:
    """One typed `const NAME: Array[T] = [ ... ]` declaration."""
    rendered = [json.dumps(i) if isinstance(i, str) else str(i) for i in items]
    if not rendered:
        return "const %s: Array[%s] = []" % (name, gd_type)
    return "const %s: Array[%s] = [\n%s\n]" % (name, gd_type, wrap_items(rendered))


def render(registry: dict, table: dict) -> str:
    """The whole marker-to-marker region, including its provenance comment."""
    lines = [
        BEGIN,
        "# Generated from docs/planning/canonical_state_registry.json and",
        "# docs/planning/registry_capacity_audit.json by tools/generate_auxiliary_state_schema.py"
        + ("." if SECTION_ID == 6 else " --section %d." % SECTION_ID),
        "# Registry %s v%d." % (registry["registry_id"], registry["registry_version"]),
        "# Do not hand-edit. %d owners, %d fields, %d UNPROVED (zero-only) fields."
        % (len(table["OWNER_KEYS"]), len(table["FIELD_KEYS"]), len(table["UNPROVED_FIELDS"])),
        "",
        "const SECTION_SCHEMA_VERSION: int = %d" % registry["section_schema_versions"][SECTION_ID - 1],
        "const REGISTRY_VERSION: int = %d" % registry["registry_version"],
        "const OWNER_COUNT: int = %d" % len(table["OWNER_KEYS"]),
        "const FIELD_COUNT: int = %d" % len(table["FIELD_KEYS"]),
        "const EMPTY_SECTION_BYTES: int = %d" % section_bytes(table, False),
        "const MAX_SECTION_BYTES: int = %d" % section_bytes(table, True),
        "",
    ]
    for name, gd_type in (("OWNER_KEYS", "String"), ("OWNER_SCHEMAS", "int"),
                          ("OWNER_FIELD_BEGIN", "int"), ("OWNER_FIELD_COUNTS", "int"),
                          ("FIELD_KEYS", "String"), ("FIELD_TYPES", "int"),
                          ("RULE_KINDS", "int"), ("RULE_VALUES", "int"),
                          ("UNPROVED_FIELDS", "String")):
        lines.extend([array_block(name, gd_type, table[name]), ""])
    lines[-1] = END
    return "\n".join(lines) + "\n"


def splice(source: str, region: str) -> str:
    """Replace exactly one ordered whole-line region; preserve all other bytes."""
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip("\r\n") == BEGIN]
    ends = [i for i, line in enumerate(lines) if line.rstrip("\r\n") == END]
    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        refuse("%s must have one ordered pair of generated markers" % TARGET.name)
    return "".join(lines[:starts[0]]) + region + "".join(lines[ends[0] + 1:])


def main() -> int:
    """Compile and check the table, name every unproved bound, then regenerate or check."""
    global SECTION_ID, TARGET, BEGIN, END
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--section", type=int, choices=(5, 6), default=6,
                        help="the section to compile (default 6)")
    parser.add_argument("--check", action="store_true", help="exit 1 on drift, write nothing")
    parser.add_argument("--require-proved", action="store_true",
                        help="refuse (exit 2) while any field's bound is unproved")
    args = parser.parse_args()
    SECTION_ID, TARGET = args.section, TARGETS[args.section]
    BEGIN, END = MARKERS[args.section]
    registry = json.loads(REGISTRY_PATH.read_text())
    table = collect(registry, audit_rows(json.loads(AUDIT_PATH.read_text()), registry))
    for name in table["UNPROVED_FIELDS"]:
        print("UNPROVED BOUND: %s (no literal, no max_count, no audit row)" % name, file=sys.stderr)
    if args.require_proved and table["UNPROVED_FIELDS"]:
        refuse("%d section-%d field bounds are unproved" % (len(table["UNPROVED_FIELDS"]), SECTION_ID))
    source = TARGET.read_text()
    updated = splice(source, render(registry, table))
    if updated == source:
        print("PASS generated section %d schema matches the registry" % SECTION_ID)
        return 0
    if args.check:
        print("DRIFT: %s does not match the registry; rerun without --check" % TARGET.name)
        return 1
    TARGET.write_text(updated)
    print("REWROTE generated section %d schema in %s" % (SECTION_ID, TARGET.name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
