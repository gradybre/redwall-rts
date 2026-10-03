#!/usr/bin/env python3
"""Run the actual finite source driver on native matrices without promoting synthetic Profile flags."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("high_capture", HERE / "run_high_wall.py")
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
BASE = H.BASE


def validate_report(report: dict, spec: dict, table: list) -> dict:
    """Require every emitted driver step/phase, not an exit code or a nonempty screenshot alone."""
    if len(table) != 8 or any(row[3] % 32768 for row in table[2:]):
        raise ValueError("STATE_NATIVE_TIMING")
    durations = [row[3] // 32768 for row in table]
    down_settle = durations[2] - (91 - durations[3]) + durations[4]
    high_settle = durations[5] - (83 - durations[6]) + durations[7]
    expected = 3 * (31 + 15 + 45 + 15 + 21 + 21 + 91 + down_settle + 83 + high_settle)
    if report.get("production_qualified") is not False or report.get("content_sha256") != spec["content_sha256"] or report.get("failures") != []:
        raise ValueError("STATE_NATIVE_SCOPE")
    if type(report.get("poses")) is not int or report["poses"] != expected or \
            type(report.get("assertions")) is not int or report["assertions"] < expected * 4:
        raise ValueError("STATE_NATIVE_CENSUS")
    events, counts = report.get("events"), report.get("phase_counts")
    if type(events) is not list or len(events) != expected or type(counts) is not list or len(counts) != 10 or \
            any(type(n) is not int or n <= 0 for n in counts[:9]) or counts[9] != 0 or sum(counts) != expected:
        raise ValueError("STATE_NATIVE_PHASES")
    actual = [0] * 10
    for event in events:
        if type(event.get("phase")) is not int or not 0 <= event["phase"] < 9 or \
                type(event.get("ready")) is not bool or event["ready"] != (event["phase"] == 0) or \
                type(event.get("frames")) is not list or len(event["frames"]) != 7:
            raise ValueError("STATE_NATIVE_EVENT")
        actual[event["phase"]] += 1
    if actual != counts or type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("STATE_NATIVE_PHASES")
    return {"poses": expected, "assertions": report["assertions"], "phases": 9, "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("STATE_NATIVE_OUTPUT_EXISTS")
    preview, out = args.preview.resolve(), args.out.resolve()
    produced = json.loads((preview / "compilation.json").read_text())
    source = preview / "mole-worker.ugactor"
    if BASE.digest(source) != produced["content_sha256"] or produced.get("production_qualified") is not False:
        raise ValueError("STATE_NATIVE_SOURCE")
    script, bake = HERE / "capture_state_program.gd", HERE / "high-wall-runtime-sources-v1/bake-spec.json"
    before = H.pre_import_pins(script, bake)
    for path in (Path(__file__).resolve(), *preview.iterdir()):
        if path.is_file():
            before[str(path)] = BASE.digest(path)
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "pre-import-sources.json").write_text(json.dumps(before, indent=2) + "\n")
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    with (out / "import.log").open("x") as log:
        code = subprocess.run(imported, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("STATE_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before != after_import:
        raise ValueError("STATE_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = dict(BASE.closure(script, bake), **before)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(content=str(source), content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"],
                roles=json.loads((preview / "roles.json").read_text())["roles"])
    for key in ("content", "basis", "manifest"):
        path = BASE.actual(spec[key]).resolve()
        pins[str(path)] = BASE.digest(path)
    (out / "sources.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "spec.json").write_text(json.dumps(spec, indent=2) + "\n")
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--fixed-fps", "60", "--script", str(script), "--", str(out / "spec.json"), str(out)]
    with (out / "native.log").open("x") as log:
        code = subprocess.run(command, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    after = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in pins}
    (out / "sources-after.json").write_text(json.dumps(after, indent=2) + "\n")
    bad = bool(BASE.DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [imported, command], "native_exit": code, "source_unchanged": pins == after,
                  "unexpected_diagnostics": bad, "production_qualified": False, "pre_import_source_unchanged": before == after_import}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if code or bad or pins != after:
        raise ValueError("STATE_NATIVE_OR_DRIFT")
    checked = validate_report(json.loads((out / "report.json").read_text()), spec, BASE.wire_timing(spec))
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps(checked, indent=2))


if __name__ == "__main__":
    main()
