#!/usr/bin/env python3
"""Independent metadata fault witnesses for the starter_structures preparation module.

Staged deliverable for INIT-C-PREP-R01v1. Its planned final installed location is
tools/test_starter_structures_metadata.py; ROOT is computed from that installed tools/
location (parents[1]) so the script keeps working unmodified once moved there.

This harness exercises ONLY `source_metadata_refusal()` / `prepare_into()` /
`plan_refusal()`'s immutable-source validation gate, per
docs/validation/evidence/starter-integration-planning-2026-09-20/metadata-test-plan.json.
It intentionally does not touch, extend or reuse the unrelated Buildings owner0 metadata
fault campaign (tools/test_buildings_metadata_preflights.py) beyond reusing the same
established owned-disposable-clone technique.

Every one of the 25 planned cases (24 faults + the plan's own positive-control), plus one
additional restored control run at the end (26 records total), does the following inside a
fresh temporary clone of the repository's godot/ tree:

  * Disables ONLY that clone's [autoload] section, so a deliberately malformed immutable
    catalog table reaches the cold, non-instantiating metadata gate instead of being
    rejected first by an unrelated live settlement autoload's own startup assertions.
  * Mutates exactly one immutable Catalog/BuildingDefinitions table or named constant in a
    clone-local copy of catalog.gd or building_definitions.gd, after asserting the exact
    original token/table is present exactly once and that the mutated text differs from the
    original -- then restores that file's clone copy from the in-memory original bytes
    before the next case. The real repository files under ROOT are never written; a
    before/after sha256 check on them is the closing paranoia assertion.
  * Copies the starter_structures module under test into the clone at its eventual
    production path (res://scripts/core/starter_structures.gd), preferring an already
    installed production copy and falling back to the evidence candidate honestly (the
    fallback is recorded in the JSON report, never silently assumed to be "installed").
  * Runs exactly one generated focus suite (via a `_discover_suites()` override on top of
    the existing supervisor/worker `run_tests.gd`), so a runtime SCRIPT ERROR partway
    through a test method cannot silently read as a pass.

Each generated GDScript suite proves, for its one case:
  * `StarterStructures.source_metadata_refusal()` (the public static gate) returns the
    expected code.
  * A producer instance's `prepare_into(out)` on a freshly constructed, -1-filled `Plan`
    returns the expected boolean and `last_refusal()` returns the same code as the static
    call (direct source_metadata_refusal <-> last_refusal agreement).
  * When refused, ALL TEN of `out`'s packed arrays are byte-for-byte identical to a snapshot
    taken immediately before the `prepare_into()` call (no partial publish on rejection).
    When accepted, the header column is checked to have actually changed from its -1/0
    sentinel state, so a no-op "success" could not pass unnoticed.
  * `plan_refusal(null)` always returns `STARTER_PLAN_NULL`, regardless of source state
    (null precedes source metadata).
  * `plan_refusal()` on a second, independently freshly constructed well-shaped Plan agrees
    with the same refusal code as the static/instance calls above.
  * `plan_refusal()` on a THIRD Plan whose `buildings` array has been deliberately resized
    to the wrong length proves source metadata is checked BEFORE plan shape: a faulted
    source still reports `STARTER_SOURCE_METADATA` (not `STARTER_PLAN_SHAPE`) for this
    malformed plan, while a healthy source reports `STARTER_PLAN_SHAPE` for the very same
    malformed plan, which is the ordering promise this task asked to be demonstrated.

A line is only ever counted as a genuine catch when: the worker process exited with a real,
parsed "N test(s), N assertion(s), N failure(s)" summary line, AND no `SCRIPT ERROR:`,
`USER SCRIPT ERROR:`, `Parse Error:` or `Parser Error:` text appears anywhere in the merged
output -- even if the expected refusal string happens to also appear somewhere in that same
output. A load/parse failure (for example a GDScript compile-time constant fold over a
missing dictionary key elsewhere in a preloaded module) is reported as an execution problem
in the JSON evidence, never silently credited as "the gate caught it".

No production source, existing suite or save schema is modified by this script under any
circumstance: every mutation happens on a byte string held in this process and is written
only into files inside a `tempfile.TemporaryDirectory()`, which is discarded on exit. No
bypass switch is added anywhere; this script only reads immutable production consts and
feeds deliberately faulted copies of them to the real, unmodified gate.

Standard-library only: ast, hashlib, json, re, shutil, subprocess, tempfile, pathlib.
"""
import ast
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

# Computed from this file's eventual installed location at tools/test_starter_structures_metadata.py.
ROOT = Path(__file__).resolve().parents[1]

CATALOG = Path("godot/scripts/core/catalog.gd")
DEFINITIONS = Path("godot/scripts/core/building_definitions.gd")
PROJECT_GODOT = Path("godot/project.godot")
STARTER_PRODUCTION = Path("godot/scripts/core/starter_structures.gd")
STARTER_EVIDENCE_CANDIDATE = Path(
    "docs/validation/evidence/starter-integration-planning-2026-09-20/candidate-starter_structures.gd"
)
PLAN_JSON = Path(
    "docs/validation/evidence/starter-integration-planning-2026-09-20/metadata-test-plan.json"
)

FOCUS_PATH = Path("godot/test/starter_metadata_probe_focus.gd")
SUITE_PATH = Path("godot/test/test_starter_structures_metadata_probe.gd")

FAULT_MARKER = "##STARTERFAULT##"
SUMMARY_RE = re.compile(r"^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$", re.M)
FAULT_LINE_RE = re.compile(
    r"##STARTERFAULT## case=(\S+) static=(\S*) last=(\S*) prepared=(\S+) "
    r"probe=(\S*) malformed=(\S*)"
)
INVALID_MARKERS = ("SCRIPT ERROR:", "USER SCRIPT ERROR:", "Parse Error:", "Parser Error:")


# --- generic GDScript source-literal editing helpers, mirroring the established pattern -------


def replace_once(text: str, old: str, new: str) -> str:
    """Replace exactly one occurrence of `old`, asserting it is unique in `text`."""
    count = text.count(old)
    assert count == 1, (old, count)
    return text.replace(old, new)


def find_dict(text: str, name: str):
    """Locate the single `const NAME: Dictionary = {...}` literal and parse its value.

    Relies on the target dictionaries here containing no nested `{`/`}` (every value is a
    String, int, or a flat list of them), matching the established technique already used
    against these exact files/dictionaries elsewhere in this repository's tooling.
    """
    pattern = r"(const " + re.escape(name) + r": Dictionary = )(\{.*?\})"
    matches = list(re.finditer(pattern, text, re.S))
    assert len(matches) == 1, "expected exactly one %s dictionary literal" % name
    match = matches[0]
    return match, ast.literal_eval(match.group(2))


def replace_dict(text: str, match, values: dict) -> str:
    """Rewrite the dictionary literal `match` captured with a JSON-serialized `values`."""
    return text[: match.start(2)] + json.dumps(values) + text[match.end(2):]


def dict_fault(text: str, name: str, mutate) -> str:
    """Apply `mutate(values) -> None` to one parsed dictionary literal and rewrite it.

    Asserts the resulting source text actually differs from the original, so a fault that
    silently failed to change anything cannot be mistaken for a real fault injection.
    """
    match, values = find_dict(text, name)
    mutate(values)
    new_text = replace_dict(text, match, values)
    assert new_text != text, "dictionary fault on %s produced no change" % name
    return new_text


# --- the 24 named fault injections, one immutable table/constant edit each --------------------
#
# 'open_stockpile' and 'bed' are deliberately used for the two "missing required key" faults
# instead of 'hall' or 'shelf'/'kitchen_bench': building_definitions.gd's own
# _assert_station_binding() and shelf_capacity_g_of() index Catalog.BUILDING_DEFINITION /
# Catalog.FURNITURE_DEFINITION with those three keys as compile-time-foldable literal
# subscripts, so removing them would risk a GDScript compile-time (not semantic) failure of
# an unrelated preloaded module rather than exercising the intended runtime metadata gate.
# 'open_stockpile' and 'bed' are referenced only through this module's own guarded, dynamic
# `.has()` / function-call lookups, so renaming them cannot trigger that unrelated fold.


def fault_building_catalog_missing_required(text: str) -> str:
    """Catalog.BUILDING_DEFINITION: rename 'open_stockpile' away, size and order preserved."""

    def mutate(values: dict) -> None:
        assert "open_stockpile" in values and values["open_stockpile"] == 19
        assert "open_stockpile_renamed" not in values
        values["open_stockpile_renamed"] = values.pop("open_stockpile")

    return dict_fault(text, "BUILDING_DEFINITION", mutate)


def fault_building_catalog_extra(text: str) -> str:
    """Catalog.BUILDING_DEFINITION: add one key beyond the compiled 30, breaking the count."""

    def mutate(values: dict) -> None:
        assert len(values) == 30
        assert "_extra_probe" not in values
        values["_extra_probe"] = len(values)

    return dict_fault(text, "BUILDING_DEFINITION", mutate)


def fault_building_catalog_ordinal(text: str) -> str:
    """Catalog.BUILDING_DEFINITION: break the ascending-id sequence on 'workshop'."""

    def mutate(values: dict) -> None:
        assert values["workshop"] == 29
        values["workshop"] = 30

    return dict_fault(text, "BUILDING_DEFINITION", mutate)


def fault_building_catalog_integer_type(text: str) -> str:
    """Catalog.BUILDING_DEFINITION: 'workshop' carries a String id instead of an int."""

    def mutate(values: dict) -> None:
        assert values["workshop"] == 29
        values["workshop"] = "29"

    return dict_fault(text, "BUILDING_DEFINITION", mutate)


def fault_furniture_catalog_missing_required(text: str) -> str:
    """Catalog.FURNITURE_DEFINITION: rename 'bed' away, size and order preserved."""

    def mutate(values: dict) -> None:
        assert "bed" in values and values["bed"] == 0
        assert "bed_renamed" not in values
        values["bed_renamed"] = values.pop("bed")

    return dict_fault(text, "FURNITURE_DEFINITION", mutate)


def fault_furniture_catalog_extra(text: str) -> str:
    """Catalog.FURNITURE_DEFINITION: add one key beyond the compiled 9, breaking the count."""

    def mutate(values: dict) -> None:
        assert len(values) == 9
        assert "_extra_probe" not in values
        values["_extra_probe"] = len(values)

    return dict_fault(text, "FURNITURE_DEFINITION", mutate)


def fault_furniture_catalog_ordinal(text: str) -> str:
    """Catalog.FURNITURE_DEFINITION: break the ascending-id sequence on 'shelf'."""

    def mutate(values: dict) -> None:
        assert values["shelf"] == 8
        values["shelf"] = 9

    return dict_fault(text, "FURNITURE_DEFINITION", mutate)


def fault_furniture_catalog_integer_type(text: str) -> str:
    """Catalog.FURNITURE_DEFINITION: 'shelf' carries a String id instead of an int."""

    def mutate(values: dict) -> None:
        assert values["shelf"] == 8
        values["shelf"] = "8"

    return dict_fault(text, "FURNITURE_DEFINITION", mutate)


def fault_room_protected_ordinal(text: str) -> str:
    """Catalog.ROOM_TYPE: change the protected PANTRY ordinal away from its published value."""

    def mutate(values: dict) -> None:
        assert values["PANTRY"] == 6
        values["PANTRY"] = 7

    return dict_fault(text, "ROOM_TYPE", mutate)


def fault_active_protected_ordinal(text: str) -> str:
    """Catalog.BUILDING_STATE: change the protected ACTIVE ordinal away from its published value."""

    def mutate(values: dict) -> None:
        assert values["ACTIVE"] == 2
        values["ACTIVE"] = 3

    return dict_fault(text, "BUILDING_STATE", mutate)


def fault_building_count(text: str) -> str:
    """BuildingDefinitions.BUILDING_DEFINITION_COUNT disagrees with the pinned expectation."""
    return replace_once(
        text,
        "const BUILDING_DEFINITION_COUNT: int = 30",
        "const BUILDING_DEFINITION_COUNT: int = 31",
    )


def fault_furniture_count(text: str) -> str:
    """BuildingDefinitions.FURNITURE_DEFINITION_COUNT disagrees with the pinned expectation."""
    return replace_once(
        text,
        "const FURNITURE_DEFINITION_COUNT: int = 9",
        "const FURNITURE_DEFINITION_COUNT: int = 10",
    )


def fault_building_field_index(text: str) -> str:
    """BuildingDefinitions.B_UNLOCK disagrees with the pinned expected column index."""
    return replace_once(text, "const B_UNLOCK: int = 6", "const B_UNLOCK: int = 7")


def fault_furniture_field_index(text: str) -> str:
    """BuildingDefinitions.F_FLOOR_Z disagrees with the pinned expected column index."""
    return replace_once(text, "const F_FLOOR_Z: int = 1", "const F_FLOOR_Z: int = 2")


def fault_building_facts_row_type(text: str) -> str:
    """BUILDING_FACTS['hall'] is not an Array at all."""

    def mutate(values: dict) -> None:
        row = values["hall"]
        assert isinstance(row, list) and len(row) == 10
        values["hall"] = 12345

    return dict_fault(text, "BUILDING_FACTS", mutate)


def fault_building_facts_row_size(text: str) -> str:
    """BUILDING_FACTS['hall'] carries 9 fields instead of the required 10."""

    def mutate(values: dict) -> None:
        row = list(values["hall"])
        assert len(row) == 10
        values["hall"] = row[:-1]

    return dict_fault(text, "BUILDING_FACTS", mutate)


def fault_building_facts_value_type(text: str) -> str:
    """BUILDING_FACTS['hall']'s footprint_x field is a String instead of an int."""

    def mutate(values: dict) -> None:
        row = list(values["hall"])
        assert row[0] == 12
        row[0] = str(row[0])
        values["hall"] = row

    return dict_fault(text, "BUILDING_FACTS", mutate)


def fault_building_footprint(text: str) -> str:
    """BUILDING_FACTS['hall']'s footprint_x value itself disagrees with the required 12."""

    def mutate(values: dict) -> None:
        row = list(values["hall"])
        assert row[0] == 12
        row[0] = 13
        values["hall"] = row

    return dict_fault(text, "BUILDING_FACTS", mutate)


def fault_building_unlock(text: str) -> str:
    """BUILDING_FACTS['hall']'s required_unlock field disagrees with the required 0."""

    def mutate(values: dict) -> None:
        row = list(values["hall"])
        assert row[6] == 0
        row[6] = 1
        values["hall"] = row

    return dict_fault(text, "BUILDING_FACTS", mutate)


def fault_furniture_facts_row_type(text: str) -> str:
    """FURNITURE_FACTS['bed'] is not an Array at all."""

    def mutate(values: dict) -> None:
        row = values["bed"]
        assert isinstance(row, list) and len(row) == 4
        values["bed"] = 99

    return dict_fault(text, "FURNITURE_FACTS", mutate)


def fault_furniture_facts_row_size(text: str) -> str:
    """FURNITURE_FACTS['bed'] carries 3 fields instead of the required 4."""

    def mutate(values: dict) -> None:
        row = list(values["bed"])
        assert len(row) == 4
        values["bed"] = row[:-1]

    return dict_fault(text, "FURNITURE_FACTS", mutate)


def fault_furniture_facts_value_type(text: str) -> str:
    """FURNITURE_FACTS['bed']'s floor_x field is a String instead of an int."""

    def mutate(values: dict) -> None:
        row = list(values["bed"])
        assert row[0] == 1
        row[0] = str(row[0])
        values["bed"] = row

    return dict_fault(text, "FURNITURE_FACTS", mutate)


def fault_furniture_floor_dimensions(text: str) -> str:
    """FURNITURE_FACTS['bed']'s floor_x value itself disagrees with the required 1x1."""

    def mutate(values: dict) -> None:
        row = list(values["bed"])
        assert row[0] == 1
        row[0] = 2
        values["bed"] = row

    return dict_fault(text, "FURNITURE_FACTS", mutate)


def fault_edge_floor_dimensions(text: str) -> str:
    """FURNITURE_FACTS['interior_partition']'s floor_x disagrees with the required 0x0 edge shape."""

    def mutate(values: dict) -> None:
        row = list(values["interior_partition"])
        assert row[0] == 0
        row[0] = 1
        values["interior_partition"] = row

    return dict_fault(text, "FURNITURE_FACTS", mutate)


FAULTS = [
    ("building-catalog-missing-required", CATALOG, fault_building_catalog_missing_required),
    ("building-catalog-extra", CATALOG, fault_building_catalog_extra),
    ("building-catalog-ordinal", CATALOG, fault_building_catalog_ordinal),
    ("building-catalog-integer-type", CATALOG, fault_building_catalog_integer_type),
    ("furniture-catalog-missing-required", CATALOG, fault_furniture_catalog_missing_required),
    ("furniture-catalog-extra", CATALOG, fault_furniture_catalog_extra),
    ("furniture-catalog-ordinal", CATALOG, fault_furniture_catalog_ordinal),
    ("furniture-catalog-integer-type", CATALOG, fault_furniture_catalog_integer_type),
    ("room-protected-ordinal", CATALOG, fault_room_protected_ordinal),
    ("active-protected-ordinal", CATALOG, fault_active_protected_ordinal),
    ("building-count", DEFINITIONS, fault_building_count),
    ("furniture-count", DEFINITIONS, fault_furniture_count),
    ("building-field-index", DEFINITIONS, fault_building_field_index),
    ("furniture-field-index", DEFINITIONS, fault_furniture_field_index),
    ("building-facts-row-type", DEFINITIONS, fault_building_facts_row_type),
    ("building-facts-row-size", DEFINITIONS, fault_building_facts_row_size),
    ("building-facts-value-type", DEFINITIONS, fault_building_facts_value_type),
    ("building-footprint", DEFINITIONS, fault_building_footprint),
    ("building-unlock", DEFINITIONS, fault_building_unlock),
    ("furniture-facts-row-type", DEFINITIONS, fault_furniture_facts_row_type),
    ("furniture-facts-row-size", DEFINITIONS, fault_furniture_facts_row_size),
    ("furniture-facts-value-type", DEFINITIONS, fault_furniture_facts_value_type),
    ("furniture-floor-dimensions", DEFINITIONS, fault_furniture_floor_dimensions),
    ("edge-floor-dimensions", DEFINITIONS, fault_edge_floor_dimensions),
]


# --- GDScript suite generation ------------------------------------------------------------------

ARRAY_FIELDS = [
    "buildings", "rooms", "room_tiles", "furniture", "footprints",
    "candidate_access_tiles", "edges", "exit_tiles", "bed_furniture_ordinals", "header",
]


def suite_source(case_name: str, expected_refusal: str) -> str:
    """One focused GDScript test method proving `case_name`'s expected refusal end to end."""
    expected_literal = '&"%s"' % expected_refusal
    expected_prepared = "true" if expected_refusal == "" else "false"
    check_probe_equal = expected_refusal != ""

    lines = []
    lines.append('extends "res://test/framework/test_case.gd"')
    lines.append('const StarterStructures := preload("res://scripts/core/starter_structures.gd")')
    lines.append("")
    lines.append("func test_case() -> void:")
    lines.append("\tvar static_code: StringName = StarterStructures.source_metadata_refusal()")
    lines.append(
        '\tassert_equal(static_code, %s, "static source_metadata_refusal for %s")'
        % (expected_literal, case_name)
    )
    lines.append("")
    lines.append("\tvar producer: StarterStructures = StarterStructures.new()")
    lines.append("\tvar out: StarterStructures.Plan = StarterStructures.Plan.new()")
    for field in ARRAY_FIELDS:
        lines.append(
            "\tvar before_%s: PackedInt32Array = out.%s.duplicate()" % (field, field)
        )
    lines.append("")
    lines.append("\tvar prepared: bool = producer.prepare_into(out)")
    lines.append("\tvar last: StringName = producer.last_refusal()")
    lines.append(
        '\tassert_equal(last, %s, "producer.last_refusal for %s")' % (expected_literal, case_name)
    )
    lines.append(
        '\tassert_equal(prepared, %s, "prepare_into boolean for %s")'
        % (expected_prepared, case_name)
    )
    lines.append(
        '\tassert_equal(static_code, last, "static and instance refusal agree for %s")'
        % case_name
    )
    lines.append("")
    lines.append("\tif not prepared:")
    for field in ARRAY_FIELDS:
        lines.append(
            '\t\tassert_true(out.%s == before_%s, "%s unchanged on rejection for %s")'
            % (field, field, field, case_name)
        )
    lines.append("\telse:")
    lines.append(
        '\t\tassert_false(out.header == before_header, "header populated on success for %s")'
        % case_name
    )
    lines.append("")
    lines.append("\tvar probe: StarterStructures.Plan = StarterStructures.Plan.new()")
    lines.append("\tvar probe_code: StringName = StarterStructures.plan_refusal(probe)")
    if check_probe_equal:
        lines.append(
            '\tassert_equal(probe_code, %s, "plan_refusal agrees with source refusal for %s")'
            % (expected_literal, case_name)
        )
    else:
        lines.append(
            '\tassert_false(probe_code == &"STARTER_SOURCE_METADATA", '
            '"plan_refusal source gate passed for %s")' % case_name
        )
    lines.append("")
    lines.append("\tvar null_code: StringName = StarterStructures.plan_refusal(null)")
    lines.append(
        '\tassert_equal(null_code, &"STARTER_PLAN_NULL", '
        '"plan_refusal(null) precedes source metadata for %s")' % case_name
    )
    lines.append("")
    lines.append("\tvar malformed: StarterStructures.Plan = StarterStructures.Plan.new()")
    lines.append("\tmalformed.buildings.resize(malformed.buildings.size() - 1)")
    lines.append("\tvar malformed_code: StringName = StarterStructures.plan_refusal(malformed)")
    if check_probe_equal:
        lines.append(
            '\tassert_equal(malformed_code, %s, '
            '"source metadata precedes shape check for %s")' % (expected_literal, case_name)
        )
    else:
        lines.append(
            '\tassert_equal(malformed_code, &"STARTER_PLAN_SHAPE", '
            '"shape gate reached once source metadata passes for %s")' % case_name
        )
    lines.append("")
    lines.append(
        '\tprint("%s case=%s static=" + str(static_code) + " last=" + str(last)'
        ' + " prepared=" + str(prepared) + " probe=" + str(probe_code)'
        ' + " malformed=" + str(malformed_code))' % (FAULT_MARKER, case_name)
    )
    return "\n".join(lines) + "\n"


# --- clone / execution plumbing, mirroring the established owned-disposable-clone pattern -----


def resolve_starter_source():
    """Prefer the installed production module; fall back to the evidence candidate honestly.

    Returns (relative_path, note). The note is carried into the JSON report unchanged, so a
    run against the not-yet-installed candidate can never be mistaken for a production run.
    """
    if (ROOT / STARTER_PRODUCTION).exists():
        return STARTER_PRODUCTION, "production module (already installed)"
    if (ROOT / STARTER_EVIDENCE_CANDIDATE).exists():
        return (
            STARTER_EVIDENCE_CANDIDATE,
            "evidence candidate (starter_structures.gd is not yet installed at its "
            "production path; this run exercised the candidate under review instead)",
        )
    raise SystemExit(
        "No starter_structures source found at either the production or evidence path"
    )


def prepare_clone(clone: Path, starter_text: str) -> None:
    """Copy godot/, symlink docs/assets, strip autoloads, install starter_structures.gd."""
    shutil.copytree(ROOT / "godot", clone / "godot")
    if (ROOT / "docs").exists():
        (clone / "docs").symlink_to(ROOT / "docs", target_is_directory=True)
    if (ROOT / "assets").exists():
        (clone / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
    project = clone / PROJECT_GODOT
    config = project.read_text()
    config, count = re.subn(r"(?ms)^\[autoload\]\n.*?(?=^\[|\Z)", "", config)
    assert count == 1, "exactly one [autoload] section must be isolated in the owned clone"
    project.write_text(config)
    starter_target = clone / STARTER_PRODUCTION
    starter_target.parent.mkdir(parents=True, exist_ok=True)
    starter_target.write_text(starter_text)
    (clone / FOCUS_PATH).write_text(
        'extends "res://test/run_tests.gd"\n'
        "func _discover_suites() -> PackedStringArray:\n"
        '\treturn PackedStringArray(["res://test/test_starter_structures_metadata_probe.gd"])\n'
    )


def execute(clone: Path, case_name: str) -> dict:
    """Run the one focused suite, returning a fully honest per-case evidence record.

    A case is only ever counted `caught`/`passed` when the worker's own summary line was
    parsed cleanly AND no script/parse error text appears anywhere in the merged output --
    the presence of the expected refusal string elsewhere in the log is never sufficient by
    itself.
    """
    run = subprocess.run(
        ["godot", "--headless", "--path", "godot", "--script", "res://test/starter_metadata_probe_focus.gd"],
        cwd=clone,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=90,
    )
    text = run.stdout
    summary = SUMMARY_RE.search(text)
    has_invalid_marker = any(marker in text for marker in INVALID_MARKERS)
    valid_execution = summary is not None and not has_invalid_marker
    fault_line = FAULT_LINE_RE.search(text)

    tests = int(summary.group(1)) if summary else None
    assertions = int(summary.group(2)) if summary else None
    failures = int(summary.group(3)) if summary else None

    passed = bool(valid_execution and failures == 0 and tests == 1 and run.returncode == 0)

    record = {
        "case": case_name,
        "valid_execution": valid_execution,
        "passed": passed,
        "tests": tests,
        "assertions": assertions,
        "failures": failures,
        "returncode": run.returncode,
        "summary_line": summary.group(0) if summary else None,
    }
    if fault_line:
        record["observed"] = {
            "static_refusal": fault_line.group(2),
            "last_refusal": fault_line.group(3),
            "prepared": fault_line.group(4),
            "probe_refusal": fault_line.group(5),
            "malformed_refusal": fault_line.group(6),
        }
    else:
        record["observed"] = None
    if not valid_execution:
        record["execution_problem"] = (
            "Worker output was not a clean pass/fail run (a SCRIPT ERROR:/Parser Error:/"
            "Parse Error: line was present, or no summary line was parsed). This is reported "
            "as an execution problem, not credited as a caught refusal, even if the expected "
            "refusal string also appears in the log."
        )
        record["tail"] = "\n".join(text.splitlines()[-40:])
    return record


def main() -> None:
    starter_relpath, starter_note = resolve_starter_source()
    originals = {
        p: (ROOT / p).read_bytes()
        for p in [CATALOG, DEFINITIONS, PROJECT_GODOT, starter_relpath]
    }
    plan = json.loads((ROOT / PLAN_JSON).read_text())
    plan_expected = {case["name"]: case["expected_refusal"] for case in plan["cases"]}
    assert plan_expected.get("positive-control") == ""
    for name, _relpath, _fn in FAULTS:
        assert plan_expected.get(name) == "STARTER_SOURCE_METADATA", name
    planned_names = set(plan_expected.keys())
    fault_names = {name for name, _r, _f in FAULTS}
    assert planned_names == fault_names | {"positive-control"}, (
        "the harness's fault set must exactly match metadata-test-plan.json's cases"
    )

    starter_text = originals[starter_relpath].decode()
    results = []
    try:
        with tempfile.TemporaryDirectory(prefix="redwall-starter-metadata-") as scratch:
            clone = Path(scratch)
            prepare_clone(clone, starter_text)
            suite_file = clone / SUITE_PATH

            suite_file.write_text(suite_source("positive-control", ""))
            positive = execute(clone, "positive-control")
            assert positive["passed"], "positive-control\n" + json.dumps(positive, indent=2)
            results.append(positive)

            for case_name, relpath, fault_fn in FAULTS:
                original_text = originals[relpath].decode()
                mutated_text = fault_fn(original_text)
                assert mutated_text != original_text, case_name
                (clone / relpath).write_text(mutated_text)
                suite_file.write_text(suite_source(case_name, "STARTER_SOURCE_METADATA"))
                results.append(execute(clone, case_name))
                (clone / relpath).write_text(original_text)

            suite_file.write_text(suite_source("restored-control", ""))
            restored = execute(clone, "restored-control")
            results.append(restored)
    finally:
        for path, original in originals.items():
            assert (ROOT / path).read_bytes() == original, (
                "the real repository copy of %s must remain byte-identical" % path
            )

    assert len(results) == 26, "expected 25 planned cases plus one restored control"
    observed_names = {r["case"] for r in results}
    assert observed_names == planned_names | {"restored-control"}

    passed_count = sum(1 for r in results if r["passed"])
    invalid_count = sum(1 for r in results if not r["valid_execution"])
    failed_count = len(results) - passed_count

    report = {
        "status": "PASS" if failed_count == 0 else "FAIL",
        "scope": (
            "Independent starter_structures immutable-source metadata fault witnesses, "
            "per docs/planning/starter_structures_preparation_contract.md and "
            "docs/validation/evidence/starter-integration-planning-2026-09-20/"
            "metadata-test-plan.json. Owned disposable clone, autoloads disabled only "
            "there. No production source, test owner or save schema was written."
        ),
        "starter_source_used": {"path": str(starter_relpath), "note": starter_note},
        "totals": {
            "cases": len(results),
            "passed": passed_count,
            "failed": failed_count,
            "invalid_execution": invalid_count,
        },
        "cases": results,
        "source_sha256": {
            str(p): hashlib.sha256(data).hexdigest() for p, data in originals.items()
        },
    }
    print(json.dumps(report, indent=2))
    if failed_count != 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
