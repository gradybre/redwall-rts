#!/usr/bin/env python3
"""Independent read-only publication replay; outputs belong to this review only."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
from unittest.mock import patch


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    root = args.source_root.resolve()
    out = Path(__file__).resolve().parent
    e = root / "docs/validation/evidence/underground-short-step-publication-2026-10-05"
    all_pins = {}
    for name in ("source-sha256.json", "artifact-sha256.json"):
        raw = (e / name).read_bytes()
        assert raw == (out / name).read_bytes()
        all_pins.update(json.loads(raw))
    assert all(sha((root / name).read_bytes()) == value for name, value in all_pins.items())
    publisher = load(root / "godot/data/underground/mole-worker/publish_short_step_profiles.py", "independent_publisher")
    files, pins = publisher.inputs()
    rebuilt = {}
    for name, raw in files.items():
        original = root / publisher.OUTPUT / name
        assert original.read_bytes() == raw
        rebuilt[name] = {"bytes": len(raw), "sha256": sha(raw)}
    census = load(e / "census.py", "independent_census").build()
    assert json.loads((e / "census.json").read_text()) == census
    (out / "replayed-census.json").write_text(json.dumps(census, indent=2) + "\n")
    review = json.loads((root / publisher.REVIEW).read_text())
    manifest = json.loads(files["manifest.json"])
    old = json.loads((root / publisher.OLD / "manifest.json").read_text())
    refusals = {}

    def refuses(name, expected, callback):
        try:
            callback()
        except ValueError as error:
            assert expected in str(error), str(error)
            refusals[name] = str(error)
        else:
            raise AssertionError("unexpected success: " + name)

    original_read = publisher.read
    proof_path = review["source1164_report"]["path"]

    def truncated_source_proof(name, expected, captured):
        raw = original_read(name, expected, captured)
        if name == proof_path:
            report = json.loads(raw)
            report["verified_source_files"] = 536
            return json.dumps(report).encode()
        return raw

    with patch.object(publisher, "read", truncated_source_proof):
        refuses("source_count_536_after_low_level_reader", "SOURCE_PROOF", lambda: publisher.source_proof(review, {}))

    after_path = review["native_evidence"]["sources-after.json"]["path"]

    def changed_native_after(name, expected, captured):
        raw = original_read(name, expected, captured)
        if name == after_path:
            report = json.loads(raw)
            report[next(iter(report))] = "0" * 64
            return json.dumps(report).encode()
        return raw

    with patch.object(publisher, "read", changed_native_after):
        refuses("native_after_mismatch_after_low_level_reader", "NATIVE_DRIFT",
                lambda: publisher.native_proof(review, manifest["consumers"], old, {}))
    for name, code in ((publisher.CONSUMERS[3], "CURRENT_NATIVE_CONSUMER"),
                       (publisher.CONSUMERS[1], "UNCHANGED_NON_NATIVE_CONSUMER")):
        consumers = dict(manifest["consumers"])
        consumers[name] = "0" * 64
        refuses("wrong_current_binding:" + name, code,
                lambda: publisher.native_proof(review, consumers, old, {}))

    invocation = json.loads((e / "focused-3/invocation.json").read_text())
    assert invocation["exit_code"] == 0
    assert all(row["exit_code"] == 0 for row in invocation["commands"])
    assert all(invocation[key] for key in ("source_unchanged", "project_restored", "assets_restored", "registry_restored"))
    suites = []
    for path in sorted((e / "focused-3").glob("shard-*.json")):
        counts = json.loads(path.read_text())["counts"]
        assert all(counts[key] == 0 for key in ("failures", "unexpected_errors", "unexpected_warnings", "expected", "tolerated", "leaked_objects", "leaked_resources"))
        suites.append(counts)
    assert len(suites) == 5
    assert sum(row["tests"] for row in suites) == 71
    assert sum(row["assertions"] for row in suites) == 16732
    assert (e / "focused-3/analyzer.log").read_text().strip() == "0 GDScript warning(s) in 0 of 10 file(s)"
    assert json.loads((e / "focused-3/analyzer.json").read_text()) == {}
    for row in invocation["commands"]:
        if row["log"].startswith("test_"):
            text = (e / "focused-3" / row["log"]).read_text()
            assert not re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING):", text, re.M)
    editor_receipt = json.loads((out / "analyzer-editor-receipt/receipt.json").read_text())
    editor_log = (out / "analyzer-editor-receipt/gdscript_warnings_editor_6457.log").read_bytes()
    assert sha(editor_log) == editor_receipt["captured_log"]["sha256"] == "f15ffd4c558b01611d562c8c257508942bdc2dc542124f423ae2a592a46edfa6"
    assert editor_receipt["log_mtime_within_original_command"]
    assert editor_receipt["analyzer_command"] == invocation["commands"][-1]
    assert all(editor_receipt["source_matches"].values())
    scanner = load(e / "reproduce.py", "independent_receipt_scanner")
    scanner.validate_import_log(editor_log.decode())
    assert all(sha((root / name).read_bytes()) == value for name, value in all_pins.items())
    result = {"source_manifest_sha256": sha((e / "source-sha256.json").read_bytes()),
              "source_pins": 17, "artifact_pins": 8, "pins_unchanged": True,
              "generated_outputs_byte_identical": rebuilt,
              "publisher_final_input_pins": len(pins),
              "census_exact": True, "extra_refusal_probes": refusals,
              "author_engine_receipts": {"suites": 5, "tests": 71, "assertions": 16732,
                  "failures": 0, "all_strict_counters_zero": True, "analyzer_warnings": 0, "analyzer_files": 10,
                  "raw_editor_diagnostics_or_leaks": 0, "raw_editor_sha256": sha(editor_log),
                  "restoration": True, "independent_engine_rerun": False},
              "production_world_activation": False, "native_memory_measured": False}
    (out / "replay.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
