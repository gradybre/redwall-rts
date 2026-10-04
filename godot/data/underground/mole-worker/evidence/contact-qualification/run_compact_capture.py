#!/usr/bin/env python3
"""Replay the actual version2 source driver and enforce complete finite native state census."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("state_capture", HERE / "run_state_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
H, BASE = R.H, R.BASE


def expected_poses(table):
    """Every requested half-tick, finite productive completion and exact recovery must occur in all three views."""
    if len(table) != 11 or any(row[3] % 32768 for row in table[2:]) or \
            any(row[2] != int(index in (0, 1, 2, 5, 8)) for index, row in enumerate(table)):
        raise ValueError("COMPACT_NATIVE_TIMING")
    durations = [row[3] // 32768 for row in table]
    total = 31 + 15 + 45 + 15 + 21 + 21 + 17 + 17
    for count, work, entry, recovery in ((91, 2, 3, 4), (83, 5, 6, 7), (101, 8, 9, 10)):
        if not durations[entry] < count < durations[entry] + durations[work] or durations[recovery] != durations[entry]:
            raise ValueError("COMPACT_NATIVE_TIMING")
        total += count + durations[work] - (count - durations[entry]) + durations[recovery]
    return 3 * total


def event_refusal(event, table):
    """A selected role must actually emit its own finite source frames, including the common hub and fade pairs."""
    phase, profile, frames = event.get("phase"), event.get("profile"), event.get("frames")
    if type(phase) is not int or not 0 <= phase < 9 or type(profile) is not int or not 0 <= profile < 5 or \
            type(event.get("ready")) is not bool or event["ready"] != (phase == 0) or \
            type(frames) is not list or len(frames) != 7 or any(type(v) is not int for v in frames) or \
            any(not 0 <= frames[i] <= 65536 for i in (2, 5, 6)):
        raise ValueError("COMPACT_NATIVE_EVENT")
    if phase >= 5 and profile < 2 or phase == 1 and profile != 0 or phase in (2, 4) and profile != 1:
        raise ValueError("COMPACT_NATIVE_ROLE")
    clip = {0: 0, 1: 0, 2: 1, 3: 0, 4: 1}.get(phase)
    if clip is None:
        clip = 2 + 3 * (profile - 2) + {5: 1, 6: 0, 7: 2, 8: 1}[phase]
    first, count, _, _ = table[clip]
    if not all(first <= frames[i] < first + count for i in (0, 1)):
        raise ValueError("COMPACT_NATIVE_ROLE_FRAMES")
    if phase in (0, 3) and frames[:3] != [8, 9, 0]:
        raise ValueError("COMPACT_NATIVE_HUB")
    if phase in (3, 4):
        if not all(0 <= frames[i] < table[1][0] + table[1][1] for i in (3, 4)):
            raise ValueError("COMPACT_NATIVE_FADE_SOURCE")
    elif frames[:3] != frames[3:6] or frames[6] != 65536:
        raise ValueError("COMPACT_NATIVE_UNAUTHORED_BLEND")


def validate_report(report, spec, table):
    expected = expected_poses(table)
    if report.get("production_qualified") is not False or report.get("content_sha256") != spec["content_sha256"] or report.get("failures") != []:
        raise ValueError("COMPACT_NATIVE_SCOPE")
    if type(report.get("poses")) is not int or report["poses"] != expected or \
            type(report.get("assertions")) is not int or report["assertions"] < 4 * expected:
        raise ValueError("COMPACT_NATIVE_CENSUS")
    events, counts = report.get("events"), report.get("phase_counts")
    if type(events) is not list or len(events) != expected or type(counts) is not list or len(counts) != 10 or \
            any(type(n) is not int or n <= 0 for n in counts[:9]) or counts[9] != 0 or sum(counts) != expected:
        raise ValueError("COMPACT_NATIVE_PHASES")
    actual, work_phases = [0] * 10, set()
    for event in events:
        event_refusal(event, table)
        actual[event["phase"]] += 1
        if event["profile"] >= 2:
            work_phases.add((event["profile"], event["phase"]))
    if actual != counts or not {(role, phase) for role in (2, 3, 4) for phase in (5, 6, 7)}.issubset(work_phases) or \
            type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("COMPACT_NATIVE_PHASES")
    return {"poses": expected, "assertions": report["assertions"], "phases": 9, "work_choices": 3, "production_qualified": False}


def bound_roles(source, digest, preview):
    """Decode only the exact role and program bytes pinned inside the immutable source image."""
    if not source.is_file() or not 184 <= source.stat().st_size <= 4 * 1048576 + 8192 or BASE.digest(source) != digest:
        raise ValueError("COMPACT_NATIVE_SOURCE")
    with source.open("rb") as stream:
        header = stream.read(184)
    values = []
    for name, start, limit in (("program.json", 88, 1048576), ("roles.json", 120, 1048576), ("plan.json", 152, 65536)):
        with (preview / name).open("rb") as stream:
            data = stream.read(limit + 1)
        if len(data) > limit or hashlib.sha256(data).digest() != header[start:start + 32]:
            raise ValueError("COMPACT_NATIVE_METADATA")
        values.append(json.loads(data))
    program, roles, _ = values
    if program.get("program_version") != 2 or program.get("production_qualified") is not False or \
            roles.get("production_qualified") is not False or set(roles.get("roles", {})) != {"stand", "ground_walk", "down", "high", "front"}:
        raise ValueError("COMPACT_NATIVE_METADATA")
    return roles["roles"]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("COMPACT_NATIVE_OUTPUT_EXISTS")
    preview, out = args.preview.resolve(), args.out.resolve()
    produced = json.loads((preview / "compilation.json").read_text())
    source = preview / "mole-worker.ugactor"
    roles = bound_roles(source, produced["content_sha256"], preview)
    if produced.get("production_qualified") is not False:
        raise ValueError("COMPACT_NATIVE_SOURCE")
    script, bake = HERE / "capture_compact_program.gd", HERE / "high-wall-runtime-sources-v1/bake-spec.json"
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
        raise ValueError("COMPACT_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before != after_import:
        raise ValueError("COMPACT_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = dict(BASE.closure(script, bake), **before)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(content=str(source), content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"], roles=roles)
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
        raise ValueError("COMPACT_NATIVE_OR_DRIFT")
    checked = validate_report(json.loads((out / "report.json").read_text()), spec, BASE.wire_timing(spec))
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps(checked, indent=2))


if __name__ == "__main__":
    main()
