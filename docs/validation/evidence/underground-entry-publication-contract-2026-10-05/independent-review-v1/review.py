"""Read-only independent ADR1190 formatter replay; writes only a fresh evidence directory."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

SOURCE = "godot/data/underground/first-entry-prefix-v1/"
PINS = {
    SOURCE + "entry_source_constants.py": "0a9e2922ce025383d8a4fb53ae3843ac75eec7bc66ec1c99f4ccf393051f2ad6",
    SOURCE + "test_entry_source_constants.py": "71224a2d96d90bf19e50d2f179347af0cc940fbd4ba80f1ef2ab1ef1a3f86613",
}
EVIDENCE = "docs/validation/evidence/underground-entry-publication-contract-2026-10-05/constants-2/"
FIXTURE = "docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1/"
READERS = ["underground_connector_catalog", "underground_connector_assemblies",
           "underground_connector_recipes", "underground_entry_frontier",
           "underground_connector_workpieces", "underground_profiles"]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = list(PINS) + ["godot/scripts/core/" + name + ".gd" for name in READERS]
    paths += ["docs/decisions/1190-fixed-entry-source-publication-contract.md"]
    paths += [EVIDENCE + name for name in ("report.json", "tests.log", "catalog_source.gd.txt")]
    paths += [FIXTURE + name for name in ("structure.ugconn", "assemblies.ugasmb", "recipes.ugrecp",
                                         "frontier.ugfront", "ground-pace.ugconn", "mole-worker.ugprof")]
    captured = {name: (args.root / name).read_bytes() for name in paths}
    before = {name: sha(raw) for name, raw in captured.items()}
    assert all(before[name] == expected for name, expected in PINS.items()), "frozen source drift"
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "source-before.json").write_text(json.dumps(before, indent=2, sort_keys=True) + "\n")
    for name in PINS:
        (args.output / (Path(name).name + ".txt")).write_bytes(captured[name])
    command = [sys.executable, "-B", str(args.root / (SOURCE + "test_entry_source_constants.py")), "-v"]
    result = subprocess.run(command, cwd=args.root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (args.output / "tests.log").write_bytes(result.stdout)
    assert result.returncode == 0, "independent test refusal"
    spec = importlib.util.spec_from_file_location("reviewed_constants_tests", args.root / (SOURCE + "test_entry_source_constants.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    packet = module.fixture()
    packet_before = dict(packet)
    generated = module.C.generate(packet)
    assert packet == packet_before, "input mutation"
    assert generated == captured[EVIDENCE + "catalog_source.gd.txt"], "saved output mismatch"
    report = json.loads(captured[EVIDENCE + "report.json"])
    assert report["output_bytes"] == len(generated) and report["output_sha256"] == sha(generated)
    after = {name: sha((args.root / name).read_bytes()) for name in paths}
    assert before == after, "review input changed"
    (args.output / "source-after.json").write_text(json.dumps(after, indent=2, sort_keys=True) + "\n")
    (args.output / "catalog_source.gd.txt").write_bytes(generated)
    verdict = {
        "scope": "Pure fixed-name linked-header metadata formatter only; no row-body or physical qualification",
        "source_pins": PINS, "tests": 10, "test_exit": result.returncode, "command": command,
        "input_files_unchanged": len(before), "output_bytes": len(generated), "output_sha256": sha(generated),
        "saved_output_byte_equal": True, "input_packet_unchanged": True,
        "engine_run": False, "publication_emitted": False, "world_activation_qualified": False,
    }
    (args.output / "review.json").write_text(json.dumps(verdict, indent=2, sort_keys=True) + "\n")
    print(json.dumps(verdict, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
