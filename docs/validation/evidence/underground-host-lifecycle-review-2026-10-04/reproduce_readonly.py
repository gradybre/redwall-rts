#!/usr/bin/env python3
"""Read/hash the frozen review inputs; write only the caller's review output directory."""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest(root, path):
    expected = json.loads(path.read_text())
    actual = {name: digest(root / name) for name in expected}
    assert actual == expected, {name: [expected[name], actual[name]]
                               for name in expected if expected[name] != actual[name]}
    return expected


def body(source, name):
    match = re.search(r"^func " + name + r"\(", source, re.M)
    end = re.search(r"^func ", source[match.start() + 1:], re.M)
    return source[match.start():match.start() + 1 + end.start()] if end else source[match.start():]


def footers(folder):
    suites = []
    for path in sorted(folder.glob("test_*.gd.log")):
        lines = [line for line in path.read_text().splitlines()
                 if re.search(r"\d+ test\(s\), \d+ assertion\(s\), \d+ failure\(s\)", line)
                 or line.startswith(("diagnostics:", "log:"))]
        assert len(lines) == 3, (path, lines)
        count = re.search(r"(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)", lines[0])
        assert int(count[3]) == 0
        assert all("0 unexpected error(s), 0 unexpected warning(s)" in line
                   and "0 object(s), 0 resource(s)" in line for line in lines[1:])
        suites.append({"suite": path.name, "sha256": digest(path), "tests": int(count[1]),
                       "assertions": int(count[2]), "footers": lines})
    return {"suites": suites, "tests": sum(row["tests"] for row in suites),
            "assertions": sum(row["assertions"] for row in suites)}


def restoration(folder):
    value = json.loads((folder / "invocation.json").read_text())
    result = {key: value[key] for key in ("source_unchanged", "project_restored",
                                        "registry_restored", "assets_restored")}
    assert all(result.values())
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    assert not out.is_relative_to(root), "review must not write into the reviewed worktree"
    out.mkdir(parents=True, exist_ok=True)
    host = root / "docs/validation/evidence/underground-host-lifecycle-2026-10-04"
    pins = manifest(root, host / "final-source-sha256.json")
    focused = json.loads((host / "focused-3/source-sha256.json").read_text())
    ui_path = "godot/scripts/systems/ui_manager.gd"
    changed = [path for path in pins if pins[path] != focused[path]]
    assert changed == [ui_path]
    baseline_ui = subprocess.check_output(["git", "show", "HEAD:" + ui_path], cwd=root, text=True)
    current_ui = (root / ui_path).read_text()
    old_doc = re.search(r'\t""".*?"""', body(baseline_ui, "create_world"), re.S).group()
    current_doc = re.search(r'\t""".*?"""', body(current_ui, "create_world"), re.S).group()
    reconstructed = current_ui.replace(current_doc, old_doc, 1)
    assert hashlib.sha256(reconstructed.encode()).hexdigest() == focused[ui_path]
    member_delta = {}
    for path in list(pins)[:6]:
        old = subprocess.check_output(["git", "show", "HEAD:" + path], cwd=root, text=True)
        current = (root / path).read_text()
        members = lambda text: dict(re.findall(r"^var (\w+):\s*([^=\n]+?)\s*=", text, re.M))
        before, after = members(old), members(current)
        member_delta[path] = {
            "added": {key: value for key, value in after.items() if key not in before},
            "removed": {key: value for key, value in before.items() if key not in after},
            "changed": {key: [before[key], after[key]] for key in before.keys() & after.keys()
                        if before[key] != after[key]}}
    settlement_path = "godot/scripts/systems/settlement_system.gd"
    assert member_delta[settlement_path]["added"] == {"_underground_session": "UndergroundSession"}
    assert all(not any(row.values()) for path, row in member_delta.items() if path != settlement_path)
    spec = importlib.util.spec_from_file_location("review_session_memory", root / "tools/underground_session_memory.py")
    memory = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(memory)
    session_source = (root / "godot/scripts/core/underground_session.gd").read_text()
    numeric, chain = memory.longest(memory.functions(session_source), "numeric_and_name_bytes")
    assert numeric <= 512
    ui = body((root / "godot/scripts/ui/ui_world_session.gd").read_text(), "create_with_cohort_into")
    assert "WorldInitScript.new" not in ui
    order = [ui.index(value) for value in ("candidate.preflight", "reset.call",
             "candidate.seed_prepared_streams", "cohort.call", "candidate.publish_prepared", "_world = candidate")]
    assert order == sorted(order)
    settlement = (root / settlement_path).read_text()
    mount = body(settlement, "mount_underground")
    assert mount.index("_underground_session = UndergroundSession.new()") < mount.index("_underground_session.configure")
    reset = body(settlement, "reset")
    assert reset.index("\n\tif not prepare_world_reset") < reset.index("\n\t_clear_stores()")
    restore = body(current_ui, "_restore_underground_after_create")
    assert "Content.new" not in restore and "load_file" not in restore and "mount_underground(content)" in restore
    report = {
        "verdict": "ACCEPTED_SCOPED_SOURCE_REVIEW", "reviewer_engine_runs": 0,
        "root_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "source_sha256": pins, "final_delta_is_only_ui_create_docstring": True,
        "member_delta": member_delta,
        "session_own_longest_numeric_name_chain": {"bytes": numeric, "chain": chain, "reserve": 512},
        "focused_2": footers(host / "focused-2"), "focused_3": footers(host / "focused-3"),
        "focused_2_restoration": restoration(host / "focused-2"),
        "focused_3_restoration": restoration(host / "focused-3"),
        "focused_3_analyzer": (host / "focused-3/analyzer.log").read_text().strip(),
        "scope": "Unbound foundation lifecycle only; no operational authority teardown or playable delivery claim",
        "native_or_runtime_memory_qualification": False}
    (out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "review.json").write_text(json.dumps(report, indent=2) + "\n")
    patch = subprocess.check_output(["git", "diff", "--", *pins], cwd=root)
    (out / "reviewed.patch.gz").write_bytes(gzip.compress(patch, mtime=0))
    (out / "new-host-test.gd.txt").write_bytes((root / "godot/test/test_underground_host.gd").read_bytes())
    assert pins == {path: digest(root / path) for path in pins}
    print(json.dumps({"pins": len(pins), "session_helper": numeric,
                      "focused_2": [report["focused_2"]["tests"], report["focused_2"]["assertions"]],
                      "final_docstring_only": True, "source_unchanged": True}, indent=2))


if __name__ == "__main__":
    main()
