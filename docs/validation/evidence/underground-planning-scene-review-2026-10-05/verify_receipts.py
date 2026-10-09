"""Read author receipts and frozen source; no engine, cache, or foreign writes."""
from pathlib import Path
import argparse
import hashlib
import json
import re


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def raw_findings(path):
    return [line for line in path.read_text().splitlines()
            if re.match(r"\s*(?:ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING):", line)
            or "leaked at exit" in line or "resources still in use at exit" in line]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    assert not out.is_relative_to(root), "review output must not enter author worktree"
    e = root / "docs/validation/evidence/underground-planning-scene-2026-10-05"
    c, n = e / "candidate-9", e / "native-4"
    sources = read(c / "source-sha256.json")
    scene = "godot/demo/burrow/modular_demo_live.tscn"
    sources[scene] = digest(root / scene)
    before, after = read(n / "source-before.json"), read(n / "source-after.json")
    assert before == after and len(before) == 1285
    assert all(digest(root / path) == value for path, value in before.items())
    assert all(before[path] == value == digest(root / path) for path, value in sources.items())
    assert read(c / "source-before.json") == read(c / "source-after.json")
    inv, native, report = read(c / "invocation.json"), read(n / "invocation.json"), read(n / "report.json")
    assert inv["exit_code"] == native["exit_code"] == 0
    assert all(inv[key] for key in ("project_restored", "assets_restored", "sources_unchanged", "old_sidecars_restored"))
    assert all(native[key] for key in ("override_unchanged", "project_restored", "source_unchanged"))
    assert inv["analyzer_raw_findings"] == [] and inv["import_findings"] == []
    assert all(x["exit_code"] == 0 for x in inv["commands"] + native["commands"])
    assert all(x["raw_findings"] == [] for x in native["commands"])
    assert report == {"backend": "forward_plus", "checks": 74, "driver": "metal", "failures": [], "playable_room_complete": False}
    assert sum(x["tests"] for x in inv["counts"].values()) == 30
    assert sum(x["assertions"] for x in inv["counts"].values()) == 1132
    assert all(x[key] == 0 for x in inv["counts"].values() for key in
               ("failures", "unexpected_errors", "unexpected_warnings", "expected", "tolerated", "leaked_objects", "leaked_resources"))
    assert (c / "analyzer.log").read_text().strip() == "0 GDScript warning(s) in 0 of 6 file(s)"
    logs = [c / "clean-import.log", c / "analyzer-editor.log", n / "staged-import.log", n / "native.log"]
    assert all(raw_findings(path) == [] for path in logs)
    for name, counts in inv["counts"].items():
        content = (c / (name + ".log")).read_text()
        assert f'{counts["tests"]} test(s), {counts["assertions"]} assertion(s), 0 failure(s)' in content
        assert "diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)" in content
        assert "log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s)." in content
    images = read(n / "image-sha256.json")
    assert len(images) == 5 and all(digest(n / path) == value for path, value in images.items())
    assert "MODULAR-DEMO-SUMMARY 74 checks / 0 failures" in (n / "native.log").read_text()
    assert (n / "native.log").read_text().count("MODULAR-DEMO PASS:") == 74
    out.mkdir(parents=True, exist_ok=True)
    retained = [c / "invocation.json", c / "analyzer.json", c / "analyzer.log", c / "analyzer-editor.log", c / "clean-import.log", n / "invocation.json", n / "report.json", n / "native.log", n / "staged-import.log", n / "image-sha256.json", n / "source-before.json", n / "source-after.json"]
    retained += [c / (name + ".log") for name in inv["counts"]]
    receipts = {}
    for source in retained:
        target = out / (source.parent.name + "-" + source.name)
        target.write_bytes(source.read_bytes())
        receipts[str(source.relative_to(root))] = digest(source)
    for path, value in sources.items():
        (out / (Path(path).name + ".txt")).write_bytes((root / path).read_bytes())
    result = {
        "status": "accepted", "scope": "Independent source review and verification of exact author strict/native receipts; no independent engine rerun",
        "source_sha256": sources, "verified_native_source_paths": len(before), "all_native_current_sources_match": True,
        "strict_tests": 30, "strict_assertions": 1132, "strict_failures": 0,
        "strict_and_raw_diagnostics_and_leaks": 0, "analyzer_files": 6, "analyzer_warnings": 0,
        "native_checks": 74, "native_failures": 0, "native_backend": "Metal/Forward+", "native_resolution": [1280, 720],
        "native_image_sha256": images, "receipts": receipts,
        "closed_findings": ["R1: held camera and pointer modal ownership", "R2: real UI World Create and explicit reopen", "R3: pre-GUI keyboard/focus modal ownership"],
        "remaining_high_medium_findings": [], "foreign_writes": False, "engine_rerun": False,
        "playable_room_complete": False, "performance_qualified": False,
        "limitations": ["Actual access and paid worker excavation remain outside this scene acceptance", "No full no-argument milestone or broad runtime memory measurement is claimed", "Source findings were independently read; corrective engine evidence was run by root"]
    }
    (out / "acceptance.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "sources": len(sources), "closure": len(before), "strict": [30, 1132, 0], "native": [74, 0], "acceptance_sha256": digest(out / "acceptance.json")}, sort_keys=True))


if __name__ == "__main__":
    main()
