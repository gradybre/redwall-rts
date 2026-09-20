#!/usr/bin/env python3
"""Compile section 4's component-column metadata into save_component_columns_schema.gd.

SAVE-S4-STREAM-R01 v2 / ADR 0169 make docs/planning/component_columns_layout.json the explicit
declaration of section 4's first implemented body: 18 owners, 298 fields, five independent child
extents, 193184 descriptor rows and 12947565 bytes. The runtime may not read that JSON -- it lives
outside res:// and JSON.parse_string() would put a float on the path of every count -- so this
script compiles it into the single marked region of the GDScript schema module and leaves every
hand-written line byte-identical.

Nothing is trusted from prose. Before writing a byte the generator:

  * checks keys, type codes, owner schema versions, ordinals and ASCII owner order against
    docs/planning/canonical_state_registry.json. Counts and primary/child extents are ABSENT from
    that table and are never taken from it;
  * re-proves all 298 element counts through tools/audit_registry_capacities.py, requiring a
    freshly built section-4 row per field with status proved_equality, source_relation eq and a
    source_value equal to the layout's count, with no missing, extra or duplicate key;
  * recomputes every payload length, block length, section offset, the row total, the section
    total, the widest owner wrapper and the child-header overhead from the framing rules, and
    refuses any disagreement with the layout's own declared numbers.

`--check` writes nothing and exits 1 on drift. The test suite independently compares all 298
entries against the layout artifact rather than regenerating this table from itself.

    python3 tools/generate_component_columns_schema.py [--check]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from audit_registry_capacities import build_audit, load_source_index  # noqa: E402

LAYOUT_PATH = ROOT / "docs/planning/component_columns_layout.json"
REGISTRY_PATH = ROOT / "docs/planning/canonical_state_registry.json"
TARGET = ROOT / "godot/scripts/core/save_component_columns_schema.gd"

BEGIN = "# --- BEGIN GENERATED COMPONENT COLUMN METADATA ---"
END = "# --- END GENERATED COMPONENT COLUMN METADATA ---"

# One leading tab rendered at the project's four-column tab stop, wrapped inside 100 columns.
TAB_COLUMNS = 4
LINE_COLUMNS = 100

SECTION_ID = 4
LAYOUT_SCHEMA = "RWL-COMPONENT-COLUMNS-LAYOUT-1"
TYPE_CODES = {"u8": 0, "i32": 2, "i64": 4}
TYPE_WIDTHS = {0: 1, 2: 4, 4: 8}

STORE_COUNT_BYTES = 4
OWNER_HEADER_FIXED_BYTES = 24
CHILD_COUNT_BYTES = 4
CHILD_EXTENT_BYTES = 8
FIELD_COUNT_BYTES = 8
CHUNK_BYTES = 65536

EXPECTED_DECLARATION_VERSION = 1
EXPECTED_SECTION_SCHEMA = 2
EXPECTED_STORE_COUNT = 18
EXPECTED_FIELD_COUNT = 298
EXPECTED_SECTION_BYTES = 12947565
EXPECTED_ROW_COUNT = 193184
EXPECTED_MAX_WRAPPER_BYTES = 53
EXPECTED_CHILD_OVERHEAD_BYTES = 112

COLUMN_ORDER = [
    "OWNER_KEYS", "OWNER_KEY_BYTES", "OWNER_VERSIONS", "OWNER_PRIMARY_COUNTS",
    "OWNER_FIELD_COUNTS", "OWNER_FIELD_BEGIN", "OWNER_CHILD_COUNTS", "OWNER_CHILD_BEGIN",
    "CHILD_EXTENTS", "OWNER_OFFSETS", "OWNER_PAYLOAD_BYTES", "OWNER_BLOCK_BYTES",
    "FIELD_KEYS", "FIELD_TYPES", "FIELD_COUNTS",
]


def refuse(message: str) -> None:
    """Stop without writing. Every check below reports rather than repairing the artifact."""
    raise SystemExit("REFUSED: %s" % message)


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


def check_integer_tokens(value, path="layout") -> None:
    """JSON booleans and floats must not compare equal to declared integer metadata."""
    if isinstance(value, (bool, float)):
        refuse("%s contains a non-integer numeric token %r" % (path, value))
    if isinstance(value, dict):
        for key, child in value.items():
            check_integer_tokens(child, path + "." + key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_integer_tokens(child, "%s[%d]" % (path, index))


def check_declaration(layout: dict) -> None:
    """The layout must be the adopted section 4 declaration, at its pinned totals."""
    if layout.get("schema") != LAYOUT_SCHEMA:
        refuse("layout schema %r is not %r" % (layout.get("schema"), LAYOUT_SCHEMA))
    if layout.get("declaration_version") != EXPECTED_DECLARATION_VERSION:
        refuse("declaration_version %r is not %d"
               % (layout.get("declaration_version"), EXPECTED_DECLARATION_VERSION))
    if layout.get("section_schema") != EXPECTED_SECTION_SCHEMA:
        refuse("section_schema %r is not %d"
               % (layout.get("section_schema"), EXPECTED_SECTION_SCHEMA))
    if layout.get("section_bytes") != EXPECTED_SECTION_BYTES \
            or layout.get("descriptor_row_count") != EXPECTED_ROW_COUNT:
        refuse("layout declares %r bytes over %r rows"
               % (layout.get("section_bytes"), layout.get("descriptor_row_count")))


def check_registry_integer_fields(registry: dict) -> None:
    """Check numeric parity keys only; registry policy flags are legitimate booleans."""
    for owner in registry["owners"]:
        for key in ["section_id", "owner_schema_version"]:
            if type(owner.get(key)) is not int:
                refuse("registry owner %r %s must be an integer" % (owner.get("owner_key"), key))
        for field in owner["fields"]:
            for key in ["ordinal", "type_code"]:
                if type(field.get(key)) is not int:
                    refuse("registry field %r %s must be an integer" % (field.get("field_key"), key))


def check_registry_parity(layout: dict, registry: dict) -> None:
    """Keys, ordinals, type codes, owner versions and ASCII order come from the registry."""
    owners = [o for o in registry["owners"] if o["section_id"] == SECTION_ID]
    declared = [o["owner"] for o in layout["owners"]]
    if [o["owner_key"] for o in owners] != declared:
        refuse("section 4 owner keys/order differ from the canonical registry")
    for owner, block in zip(owners, layout["owners"]):
        if owner["owner_schema_version"] != block["owner_schema_version"]:
            refuse("owner '%s' schema version %d is not the registry's %d"
                   % (block["owner"], block["owner_schema_version"],
                      owner["owner_schema_version"]))
        if len(owner["fields"]) != len(block["fields"]):
            refuse("owner '%s' declares %d fields; the registry declares %d"
                   % (block["owner"], len(block["fields"]), len(owner["fields"])))
        for known, field in zip(owner["fields"], block["fields"]):
            if known["ordinal"] != field["ordinal"] or known["field_key"] != field["key"]:
                refuse("owner '%s' field %d is '%s'; the registry has %d '%s'"
                       % (block["owner"], field["ordinal"], field["key"],
                          known["ordinal"], known["field_key"]))
            if known["type_code"] != TYPE_CODES.get(field["type"]):
                refuse("owner '%s' field '%s' is %r; the registry type code is %d"
                       % (block["owner"], field["key"], field["type"], known["type_code"]))


def check_source_proofs(layout: dict, registry: dict) -> None:
    """Re-prove all 298 counts against freshly built section-4 source equalities."""
    proved = {}
    for row in build_audit(registry, load_source_index())["rows"]:
        if row["section_id"] != SECTION_ID:
            continue
        key = (row["owner_key"], row["ordinal"], row["field_key"])
        if key in proved:
            refuse("section 4 source proof %r appears twice" % (key,))
        proved[key] = row
    seen = set()
    for owner in layout["owners"]:
        for field in owner["fields"]:
            key = (owner["owner"], field["ordinal"], field["key"])
            row = proved.get(key)
            if row is None:
                refuse("no section 4 source proof for %r" % (key,))
            if row["status"] != "proved_equality" or row.get("source_relation") != "eq":
                refuse("%r is %s / %r, not a proved equality"
                       % (key, row["status"], row.get("source_relation")))
            if row.get("source_value") != field["count"]:
                refuse("%r declares %d; source proves %r"
                       % (key, field["count"], row.get("source_value")))
            seen.add(key)
    extra = sorted(set(proved) - seen)
    if extra:
        refuse("%d proved section 4 field(s) are absent from the layout: %r"
               % (len(extra), extra[:4]))


# Explicit protocol bindings from ADR0169. These are named table choices, not an
# inference from whichever field happens to come first. Counts have already been
# proved against source before this check runs.
PRIMARY_FIELDS = {
    "buildings": "_b_present", "construction": "_present", "farming": "_present",
    "field_policy": "_field_present", "fishing": "_habitat_present", "forage": "_zone_present",
    "injury": "_present", "jobs": "_job_present", "movement": "_vx", "needs": "_present",
    "orchard_hive": "_o_present", "priorities": "_present", "residents": "_present",
    "resource_nodes": "_present", "schedule": "_present", "transforms": "_bound_persistent_id",
    "work": "_potential_remainder", "world_init": "_fauna_zone_slot",
}
CHILD_FIELDS = {
    "buildings": ["_r_present", "_f_present"], "field_policy": ["_plot_field_slot"],
    "jobs": ["_agent_present"], "orchard_hive": ["_h_present"],
}


def check_extent_bindings(layout: dict) -> None:
    """Each explicit primary/child is the source-proved capacity of its named table."""
    for owner in layout["owners"]:
        key = owner["owner"]
        counts = {field["key"]: field["count"] for field in owner["fields"]}
        if owner["primary_count"] != counts[PRIMARY_FIELDS[key]]:
            refuse("owner '%s' primary does not match its declared table" % key)
        expected = [counts[field] for field in CHILD_FIELDS.get(key, [])]
        if owner["child_extents"] != expected:
            refuse("owner '%s' child extents/order differ from declared tables" % key)


def check_arithmetic(layout: dict) -> None:
    """Rebuild every payload, block, offset and total from the framing rules alone."""
    owners = layout["owners"]
    if len(owners) != EXPECTED_STORE_COUNT:
        refuse("layout declares %d owners, not %d" % (len(owners), EXPECTED_STORE_COUNT))
    keys = [owner["owner"] for owner in owners]
    if keys != sorted(keys) or len(set(keys)) != len(keys):
        refuse("owner blocks are not in strict ASCII key order")
    offset, rows, fields, child_overhead, widest = STORE_COUNT_BYTES, 0, 0, 0, 0
    for owner in owners:
        extents = owner["child_extents"]
        if any(extent <= 0 for extent in extents) or owner["primary_count"] <= 0:
            refuse("owner '%s' declares a nonpositive primary count or child extent"
                   % owner["owner"])
        if not owner["owner"].isascii():
            refuse("owner key %r is not ASCII" % owner["owner"])
        header = CHILD_COUNT_BYTES + CHILD_EXTENT_BYTES * len(extents)
        payload = header
        child_overhead += header
        for position, field in enumerate(owner["fields"]):
            if field["ordinal"] != position or not field["key"] or field["count"] <= 0:
                refuse("owner '%s' field %d is malformed" % (owner["owner"], position))
            if field["type"] not in TYPE_CODES:
                refuse("owner '%s' field '%s' declares unsupported type %r"
                       % (owner["owner"], field["key"], field["type"]))
            payload += FIELD_COUNT_BYTES \
                + field["count"] * TYPE_WIDTHS[TYPE_CODES[field["type"]]]
        key_bytes = len(owner["owner"].encode("ascii"))
        block = OWNER_HEADER_FIXED_BYTES + key_bytes + payload
        wrapper = OWNER_HEADER_FIXED_BYTES + key_bytes + header
        widest = max(widest, wrapper)
        if wrapper > CHUNK_BYTES:
            refuse("owner '%s' wrapper is %d bytes" % (owner["owner"], wrapper))
        if owner["payload_bytes"] != payload or owner["block_bytes"] != block \
                or owner["section_offset"] != offset:
            refuse("owner '%s' declares %d/%d at %d; framing gives %d/%d at %d"
                   % (owner["owner"], owner["payload_bytes"], owner["block_bytes"],
                      owner["section_offset"], payload, block, offset))
        offset += block
        rows += owner["primary_count"]
        fields += len(owner["fields"])
    if fields != EXPECTED_FIELD_COUNT or rows != EXPECTED_ROW_COUNT \
            or offset != EXPECTED_SECTION_BYTES:
        refuse("framing gives %d fields, %d rows and %d bytes" % (fields, rows, offset))
    if widest != EXPECTED_MAX_WRAPPER_BYTES \
            or child_overhead != EXPECTED_CHILD_OVERHEAD_BYTES:
        refuse("widest wrapper %d and child overhead %d are not %d and %d"
               % (widest, child_overhead, EXPECTED_MAX_WRAPPER_BYTES,
                  EXPECTED_CHILD_OVERHEAD_BYTES))


def collect(layout: dict) -> dict:
    """Flatten the validated layout into the parallel columns the GDScript table declares."""
    table = {name: [] for name in COLUMN_ORDER}
    field_begin, child_begin = 0, 0
    for owner in layout["owners"]:
        table["OWNER_KEYS"].append(json.dumps(owner["owner"]))
        table["OWNER_KEY_BYTES"].append(str(len(owner["owner"].encode("ascii"))))
        table["OWNER_VERSIONS"].append(str(owner["owner_schema_version"]))
        table["OWNER_PRIMARY_COUNTS"].append(str(owner["primary_count"]))
        table["OWNER_FIELD_COUNTS"].append(str(len(owner["fields"])))
        table["OWNER_FIELD_BEGIN"].append(str(field_begin))
        table["OWNER_CHILD_COUNTS"].append(str(len(owner["child_extents"])))
        table["OWNER_CHILD_BEGIN"].append(str(child_begin))
        table["OWNER_OFFSETS"].append(str(owner["section_offset"]))
        table["OWNER_PAYLOAD_BYTES"].append(str(owner["payload_bytes"]))
        table["OWNER_BLOCK_BYTES"].append(str(owner["block_bytes"]))
        for extent in owner["child_extents"]:
            table["CHILD_EXTENTS"].append(str(extent))
        for field in owner["fields"]:
            table["FIELD_KEYS"].append(json.dumps(field["key"]))
            table["FIELD_TYPES"].append(str(TYPE_CODES[field["type"]]))
            table["FIELD_COUNTS"].append(str(field["count"]))
        field_begin += len(owner["fields"])
        child_begin += len(owner["child_extents"])
    return table


def render(layout: dict, table: dict) -> str:
    """Build the whole marker-to-marker region, including its provenance header comment."""
    header = [
        BEGIN,
        "# Generated from docs/planning/component_columns_layout.json and the canonical registry by",
        "# tools/generate_component_columns_schema.py. Do not hand-edit: the generator re-proves all %d"
        % len(table["FIELD_KEYS"]),
        "# counts against tools/audit_registry_capacities.py's section-4 source equalities before writing.",
        "#   layout %s, declaration_version %d, base registry %d"
        % (layout["schema"], layout["declaration_version"], layout["base_registry"]),
        "#   %d owners, %d fields, %d child extents, %d descriptor rows, %d section bytes."
        % (len(layout["owners"]), len(table["FIELD_KEYS"]), len(table["CHILD_EXTENTS"]),
           layout["descriptor_row_count"], layout["section_bytes"]),
        "",
        'const LAYOUT_SCHEMA: String = "%s"' % layout["schema"],
        "const DECLARATION_VERSION: int = %d" % layout["declaration_version"],
        "const STORE_COUNT: int = %d" % len(layout["owners"]),
        "const FIELD_COUNT: int = %d" % len(table["FIELD_KEYS"]),
        "const SECTION_SCHEMA_VERSION: int = %d" % layout["section_schema"],
        "const SECTION_BYTES: int = %d" % layout["section_bytes"],
        "const DESCRIPTOR_ROW_COUNT: int = %d" % layout["descriptor_row_count"],
        "",
    ]
    blocks = []
    for name in COLUMN_ORDER:
        blocks.extend([array_block(name, table[name]), ""])
    blocks[-1] = END
    return "\n".join(header + blocks) + "\n"


def splice(source: str, region: str) -> str:
    """Replace exactly one ordered whole-line region; preserve all other bytes."""
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip("\r\n") == BEGIN]
    ends = [i for i, line in enumerate(lines) if line.rstrip("\r\n") == END]
    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        refuse("%s must have one ordered pair of generated metadata markers" % TARGET.name)
    return "".join(lines[:starts[0]]) + region + "".join(lines[ends[0] + 1:])


def main() -> int:
    """Validate every proof and check, then regenerate or check the compiled region."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 on drift, write nothing")
    args = parser.parse_args()
    layout = json.loads(LAYOUT_PATH.read_text())
    registry = json.loads(REGISTRY_PATH.read_text())
    check_integer_tokens(layout)
    check_declaration(layout)
    check_registry_integer_fields(registry)
    check_registry_parity(layout, registry)
    check_source_proofs(layout, registry)
    check_extent_bindings(layout)
    check_arithmetic(layout)
    source = TARGET.read_text()
    updated = splice(source, render(layout, collect(layout)))
    if updated == source:
        print("PASS generated component column metadata matches %s" % LAYOUT_PATH.name)
        return 0
    if args.check:
        print("DRIFT: %s does not match %s; rerun without --check"
              % (TARGET.name, LAYOUT_PATH.name))
        return 1
    TARGET.write_text(updated)
    print("REWROTE generated component column metadata in %s" % TARGET.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
