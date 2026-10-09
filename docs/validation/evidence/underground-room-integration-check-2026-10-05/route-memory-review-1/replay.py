#!/usr/bin/env python3
"""Independent read-only 1167 integration accounting replay and refusal probes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest import mock

sys.dont_write_bytecode = True
parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, required=True)
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
root = args.root.resolve()
out = args.out.resolve()
assert not out.exists() and root not in out.parents
out.mkdir(parents=True)
sys.path.insert(0, str(root / "tools"))
import audit_registry_capacities as audit
import underground_room_memory as room
import underground_memory_budget as budget
import test_underground_room_memory as tests
import test_underground_memory_budget as budget_tests


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(name, value):
    (out / name).write_text(json.dumps(value, indent=2) + "\n")


paths = ["tools/underground_room_memory.py", "tools/test_underground_room_memory.py",
         "tools/underground_memory_budget.py", "tools/test_underground_memory_budget.py",
         str(room.MANIFEST)]
before = {path: sha((root / path).read_bytes()) for path in paths}
for path in paths:
    (out / (Path(path).name + ".txt")).write_bytes((root / path).read_bytes())
manifest = json.loads((root / room.MANIFEST).read_bytes())
assert sha((root / room.MANIFEST).read_bytes()) == room.MANIFEST_SHA
pins = {row["path"]: row["sha256"] for row in manifest["sources"].values()}
pins.update(manifest["witnesses"])
for group in ("baseline", "publisher_predecessors", "route_predecessors"):
    for row in manifest[group].values():
        pins[row["locator"]] = row["sha256"]
assert all(sha((root / path).read_bytes()) == digest for path, digest in pins.items())
write_json("review-inputs.json", before)
write_json("verified-closure.json", pins)

# Independently verify every nested route producer dependency occurs in the
# outer closure, including the engine source used to bound literal lifetime.
closure = {}
for name in ("constructor-source-sha256.json", "inherited-sha256.json",
             "engine-lifetime/source-sha256.json", "predecessor/manifest.json"):
    rows = json.loads((root / room.R / name).read_bytes())
    missing = []
    for path, row in rows.items():
        actual = row.get("locator", path) if isinstance(row, dict) else path
        expected = row["sha256"] if isinstance(row, dict) else row
        if pins.get(actual) != expected:
            missing.append(actual)
    assert not missing, missing
    closure[name] = {"count": len(rows), "missing": missing}
write_json("nested-closure.json", closure)

suite = unittest.defaultTestLoader.loadTestsFromModule(tests)
for name in ("test_route_constructor_is_current_and_uses_the_same_retirement_reserve",
             "test_ui_current_text_mutation_is_not_replaced_with_disk_source"):
    suite.addTest(budget_tests.JointPackTests(name))
started = time.monotonic()
with (out / "tests.log").open("w") as log:
    result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
assert result.wasSuccessful()

index = audit.load_source_index()
mutations = []
for name, row in manifest["sources"].items():
    original = index.get(name) or audit.parse_module(name, row["path"], (root / row["path"]).read_text())
    # Preserve the stale SHA, constants and columns; only executable text grows.
    changed = original._replace(text=original.text +
        "\nfunc review_hidden_scratch() -> void:\n\tvar value: PackedByteArray = PackedByteArray()\n\tvalue.resize(4096)\n")
    with mock.patch.object(room, "producer") as producer:
        try:
            room.build(dict(index, **{name: changed}))
        except ValueError as error:
            assert str(error) == "room memory: current reviewed source changed: " + name
            mutations.append({"kind": "current injected text", "name": name, "refusal": str(error)})
        else:
            raise AssertionError("accepted changed current source " + name)
        producer.assert_not_called()

read_bytes = Path.read_bytes
immutable = dict(manifest["witnesses"])
for group in ("baseline", "publisher_predecessors", "route_predecessors"):
    immutable.update({row["locator"]: row["sha256"] for row in manifest[group].values()})
for path in immutable:
    target = root / path
    changed = target.read_bytes() + b"\n# independent mutation\n"

    def read(candidate):
        return changed if candidate == target else read_bytes(candidate)

    with mock.patch.object(Path, "read_bytes", read), mock.patch.object(room, "producer") as producer:
        try:
            room.build(index)
        except ValueError as error:
            assert "reviewed witness changed" in str(error) or "reviewed predecessor changed" in str(error)
            mutations.append({"kind": "immutable closure", "path": path, "refusal": str(error)})
        else:
            raise AssertionError("accepted changed witness " + path)
        producer.assert_not_called()
write_json("independent-mutations.json", mutations)

# The accepted normal entry must reconstruct the whole pack without invoking
# Git, a subprocess census, or any writer for shared metadata.
with mock.patch.object(subprocess, "check_output", side_effect=AssertionError("unexpected subprocess")):
    rebuilt = budget.build(index)
rendered = json.dumps(rebuilt, indent=2) + "\n"
assert rendered == (root / "docs/planning/underground_memory_pack.json").read_text()
(out / "rebuilt-memory-pack.json").write_text(rendered)
route = rebuilt["room_extension_reservation"]["route_composition"]
assert route["constructor_exclusive_reuse"]["simultaneous_total"] == 8161
assert route["accounting"]["controls"] == 6067
assert route["accounting"]["helpers"] == 1919
assert rebuilt["live_with_reserve_bytes"] == 99999806
assert rebuilt["headroom_bytes"] == 194
assert rebuilt["runtime_qualified"] is False
assert rebuilt["room_extension_reservation"]["native_measured"] is False
assert {path: sha((root / path).read_bytes()) for path in before} == before
assert all(sha((root / path).read_bytes()) == digest for path, digest in pins.items())
write_json("result.json", {
    "tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
    "seconds": round(time.monotonic() - started, 3),
    "current_source_probes": len(manifest["sources"]),
    "immutable_closure_probes": len(immutable),
    "all_refused_before_producer": True,
    "nested_closure": closure, "current_source_pins": len(manifest["sources"]),
    "unique_closure_pins": len(pins), "all_pins_unchanged": True,
    "rebuilt_pack_sha256": sha(rendered.encode()), "rebuilt_pack_byte_identical": True,
    "controls": 6067, "helpers": 1919, "constructor_coexistence": 8161,
    "existing_retirement_reserve": 8192, "live_with_reserve_bytes": 99999806,
    "headroom_bytes": 194, "runtime_qualified": False, "native_measured": False,
    "engine_processes_started": 0, "foreign_writes": 0,
})
print((out / "result.json").read_text())
