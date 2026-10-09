#!/usr/bin/env python3
"""Audit preserved receipts only; never starts Godot or modifies source."""
from pathlib import Path
import gzip
import hashlib
import json
import re

E = Path(__file__).resolve().parent
ROOT = E.parents[3]
CHECKPOINT = "ca1edc3f62b09300f0e36ff0dfbcb1172a5f90ac"
RUNS = ("full-ca1edc3f", "analyzer-retry-1", "input-map-1", "input-platform-1", "lsp-order-1")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(relative):
    return json.loads((E / relative).read_text())


def methods(text):
    result, current = {}, None
    for line in text.splitlines():
        if re.fullmatch(r"test_\S+\.gd", line):
            current = line
            assert current not in result
            result[current] = []
        elif re.fullmatch(r"  PASS  test_\S+", line):
            assert current is not None
            result[current].append(line.removeprefix("  PASS  "))
    return {key: sorted(value) for key, value in sorted(result.items())}


def main():
    runs = {}
    for name in RUNS:
        invocation = read(name + "/invocation.json")
        assert invocation["head"] == CHECKPOINT
        pins = read(name + "/source-sha256.json")
        missing = [key for key, expected in pins.items() if sha(ROOT / key) != expected]
        assert not missing
        restoration = {key: invocation[key] for key in (
            "source_unchanged_before_cleanup", "source_unchanged", "project_restored",
            "assets_restored", "sidecars_restored", "head_unchanged")}
        assert all(restoration.values())
        runs[name] = {"exit_code": invocation["exit_code"], "source_pins": len(pins),
                      "independent_rehash_mismatches": missing, "restoration": restoration}
    full = read("full-ca1edc3f/result.json")
    ci = read("ci-reference/aggregate.json")
    ci_run = read("ci-reference/run.json")
    assert ci_run["headSha"] == CHECKPOINT and ci_run["conclusion"] == "success"
    local_methods = methods((E / "full-ca1edc3f/full-suite.log").read_text())
    ci_methods, ci_suites = {}, {}
    ci_pins = read("ci-reference/compressed-raw-log-pins.json")
    for path in sorted((E / "ci-reference/verified-artifacts").glob("shard-*.log.gz")):
        compressed = path.read_bytes()
        relative = str(path.relative_to(E / "ci-reference"))
        row = ci_pins[relative.removesuffix(".gz")]
        assert hashlib.sha256(compressed).hexdigest() == row["gzip_sha256"]
        raw = gzip.decompress(compressed)
        assert hashlib.sha256(raw).hexdigest() == row["raw_sha256"]
        text = raw.decode()
        subset = methods(text)
        assert not ci_methods.keys() & subset.keys()
        ci_methods.update(subset)
        for line in text.splitlines():
            if line.startswith("CI_SUITE_TIME "):
                data = json.loads(line.removeprefix("CI_SUITE_TIME "))
                assert data["suite"] not in ci_suites
                ci_suites[data["suite"]] = data
    assert len(local_methods) == len(ci_methods) == len(ci_suites) == 406
    assert local_methods == ci_methods
    assert sum(map(len, local_methods.values())) == 11226
    replay = read("input-map-1/shard-397.json")["suite_counts"]["test_demo_build.gd"]
    platform = read("input-platform-1/input-map.json")
    raw_map = read("input-map-1/input-map.json")
    suite = ROOT / "godot/test/test_demo_build.gd"
    assert sha(suite) == "27585d03b8cf114c29fd9025f4196a53a37d098ac6749244e6e2df2f6787ddd0"
    assert len(re.findall(r"\bassert_(?:equal|true|false)\(", suite.read_text())) == 18
    fixed = 17  # The eighteenth assertion is inside the InputEventKey loop.
    assert platform["base_event_count"] == 197 and platform["keyboard_event_count"] == 207
    differences = [row for row in platform["actions"] if row["delta"]]
    assert len(differences) == 8 and sum(row["delta"] for row in differences) == 10
    assert all(row["actual"] == row["macos"] for row in differences)
    ci_demo = ci_suites["test_demo_build.gd"]
    assert fixed + platform["base_event_count"] == ci_demo["assertions"] == 214
    assert fixed + platform["keyboard_event_count"] == replay["assertions"] == 224
    assert full["assertions"] - ci["counts"]["assertions"] == replay["assertions"] - ci_demo["assertions"] == 10
    original_editor = (E / "full-ca1edc3f/analyzer-editor.log").read_bytes()
    assert original_editor == (E / "analyzer-retry-1/analyzer-editor.log").read_bytes()
    original_errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:).*$", original_editor.decode(), re.M)
    assert len(original_errors) == 8
    trace = read("lsp-order-1/probe/trace.json")
    first_errors = next(row for row in trace if row["raw_diagnostics_so_far"])
    assert first_errors["method"] == "textDocument/didClose"
    assert first_errors["uri"].endswith("/demo/ui/demo_stall_banner.gd")
    assert len(first_errors["raw_diagnostics_so_far"]) == 5
    result = {
        "checkpoint": CHECKPOINT,
        "exact_full_gate_passed": False,
        "full": {key: full[key] for key in ("suites", "tests", "assertions", "failures", "strict_diagnostics", "raw_diagnostics", "analyzer")},
        "ci": {"run": ci_run["databaseId"], "attempt": ci_run["attempt"], "counts": ci["counts"]},
        "comparison": {"all_suite_and_pass_method_names_equal": True, "suites": 406, "tests": 11226,
            "local_noarg_per_suite_assertions_available": False,
            "exact_net_assertion_difference": 10,
            "demonstrated_source": "test_demo_build.gd::test_f11_is_bound_to_nothing_else",
            "unchanged_singleton_replay": replay,
            "ci_same_suite": {key: ci_demo[key] for key in ("tests", "assertions", "failures")},
            "fixed_assertions": fixed, "base_keyboard_events": 197, "macos_keyboard_events": 207,
            "macos_overrides": differences,
            "limit": "Original no-argument log omits per-suite assertion totals; same-source singleton replay and actual platform settings account for the complete net difference. No assertion count is normalized."},
        "editor": {"original_raw_error_lines": original_errors, "fresh_retry_byte_identical": True,
            "bounded_probe_first_error_after": "textDocument/didOpen demo/ui/demo_stall_banner.gd",
            "bounded_probe_errors": 5,
            "remaining_specimen_error_family_reproduced_in_seven_file_subset": False,
            "root_cause_proved": False},
        "runs": runs,
        "native_memory_qualified": False, "playable_or_visual_qualified": False,
    }
    (E / "audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"audited_runs": len(runs), "source_rehashes_match": True,
                      "suite_methods_match": True, "assertion_difference": 10,
                      "full_gate_passed": False}, indent=2))


if __name__ == "__main__":
    main()
