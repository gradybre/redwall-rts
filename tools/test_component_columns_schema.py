#!/usr/bin/env python3
"""Black-box generator failure tests in an owned temporary source clone.

The production checkout is read only. Refusal must precede any output write, and
fresh source drift must be detected instead of trusting the old numeric census.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = Path("godot/scripts/core/save_component_columns_schema.gd")
LAYOUT = Path("docs/planning/component_columns_layout.json")
GENERATOR = Path("tools/generate_component_columns_schema.py")
checks = 0


def check(ok, message):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(message)


def run(root, *args):
    return subprocess.run([sys.executable, str(root / GENERATOR), *args],
                          cwd=root, capture_output=True, text=True)


def refused_without_write(root, label):
    before = (root / TARGET).read_bytes()
    result = run(root)
    check(result.returncode != 0, label + " refuses")
    check((root / TARGET).read_bytes() == before, label + " leaves output unchanged")
    check("Traceback" not in result.stderr, label + " uses a deliberate diagnostic")


def main():
    with tempfile.TemporaryDirectory(prefix="redwall-component-schema-") as scratch:
        clone = Path(scratch)
        shutil.copytree(ROOT / "godot/scripts/core", clone / "godot/scripts/core")
        (clone / "tools").mkdir()
        (clone / "docs/planning").mkdir(parents=True)
        for name in [GENERATOR, Path("tools/audit_registry_capacities.py"),
                     Path("tools/generate_canonical_state_table.py"), LAYOUT,
                     Path("docs/planning/canonical_state_registry.json")]:
            shutil.copyfile(ROOT / name, clone / name)
        original = (clone / LAYOUT).read_bytes()
        target_before = (clone / TARGET).read_bytes()
        good = run(clone, "--check")
        check(good.returncode == 0, "fresh matching source validates: " + good.stdout + good.stderr)
        check((clone / TARGET).read_bytes() == target_before, "--check never writes")
        mutations = [
            ("wrong fixed count", lambda j: j["owners"][0]["fields"][0].update(count=1023)),
            ("float count", lambda j: j["owners"][0]["fields"][0].update(count=1024.0)),
            ("boolean schema", lambda j: j["owners"][0].update(owner_schema_version=True)),
            ("missing field", lambda j: j["owners"][0]["fields"].pop()),
            ("wrong field type", lambda j: j["owners"][0]["fields"][0].update(type="i64")),
            ("wrong owner key", lambda j: j["owners"][0].update(owner="unknown")),
            ("wrong payload length", lambda j: j["owners"][0].update(payload_bytes=1)),
            ("wrong child extent", lambda j: j["owners"][0]["child_extents"].reverse()),
            ("wrong section length", lambda j: j.update(section_bytes=12947566)),
            ("balanced but wrong primaries", lambda j: (j["owners"][0].update(primary_count=1023),
                                                       j["owners"][1].update(primary_count=82945))),
        ]
        for label, mutate in mutations:
            data = json.loads(original)
            mutate(data)
            (clone / LAYOUT).write_text(json.dumps(data))
            refused_without_write(clone, label)
            (clone / LAYOUT).write_bytes(original)
        registry_path = clone / "docs/planning/canonical_state_registry.json"
        registry_original = registry_path.read_bytes()
        for label, mutate in [
            ("registry float type code", lambda o: o["fields"][0].update(type_code=0.0)),
            ("registry boolean version", lambda o: o.update(owner_schema_version=True)),
            ("registry float section id", lambda o: o.update(section_id=4.0)),
        ]:
            registry = json.loads(registry_original)
            owner = next(o for o in registry["owners"] if o["section_id"] == 4)
            mutate(owner)
            registry_path.write_text(json.dumps(registry))
            refused_without_write(clone, label)
            registry_path.write_bytes(registry_original)
        begin = "# --- BEGIN GENERATED COMPONENT COLUMN METADATA ---"
        end = "# --- END GENERATED COMPONENT COLUMN METADATA ---"
        target_text = target_before.decode()
        marker_mutations = [
            ("missing begin marker", target_text.replace(begin, "# missing begin")),
            ("duplicate begin marker", target_text + begin + "\n"),
            ("duplicate end marker", target_text + end + "\n"),
            ("reversed markers", target_text.replace(begin, "# TEMP").replace(end, begin).replace("# TEMP", end)),
        ]
        for label, mutated in marker_mutations:
            (clone / TARGET).write_text(mutated)
            refused_without_write(clone, label)
            (clone / TARGET).write_bytes(target_before)
        fishing = clone / "godot/scripts/core/fishing.gd"
        source = fishing.read_text()
        needle = "const FISH_HABITAT_CAPACITY: int = 32"
        check(source.count(needle) == 1, "source drift fixture matches an actual capacity")
        fishing.write_text(source.replace(needle, "const FISH_HABITAT_CAPACITY: int = 31"))
        refused_without_write(clone, "fresh source contradicts old registry/census")
        fishing.write_text(source)
        check(run(clone, "--check").returncode == 0, "restored source validates again")
    print(f"test_component_columns_schema: PASS -- {checks} checks")


if __name__ == "__main__":
    main()
