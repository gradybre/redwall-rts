#!/usr/bin/env python3
"""Create-only native contact evidence with complete frozen source pins before and after execution."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
DIAGNOSTIC = re.compile(r"(?m)^(?:ERROR:|WARNING:|SCRIPT ERROR:)|leaked at exit|resources still in use")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def actual(path: str) -> Path:
    return ROOT / "godot" / path[6:] if path.startswith("res://") else Path(path)


def closure(script: Path, bake: Path) -> dict:
    """The accepted bake supplies all actual assets/imports; close every new literal script dependency too."""
    spec = json.loads(bake.read_text())
    result = {}
    for row in [spec["manifest"], *spec["sources"]]:
        path = actual(row["path"])
        if digest(path) != row["sha256"]:
            raise ValueError("CONTACT_CAPTURE_SOURCE_DRIFT:" + row["path"])
        result[str(path)] = row["sha256"]
    pending = [script]
    seen = set()
    while pending:
        path = pending.pop().resolve()
        if path in seen:
            continue
        seen.add(path)
        result[str(path)] = digest(path)
        text = path.read_text()
        for dependency in re.findall(r'(?:preload|load)\(\s*"(res://[^"\n]+\.gd)"\s*\)', text):
            pending.append(actual(dependency))
        for dependency in re.findall(r'^extends\s+"([^"\n]+\.gd)"', text, re.M):
            pending.append(actual(dependency) if dependency.startswith("res://") else path.parent / dependency)
        if len(seen) > 2048:
            raise ValueError("CONTACT_CAPTURE_SOURCE_CAPACITY")
    for path in (Path(__file__).resolve(), bake.resolve()):
        result[str(path)] = digest(path)
    return result


def wire_timing(spec: dict) -> list[tuple[int, int, int, int]]:
    """Read timing from the exact image executed by Content, never infer it from a requested pose count."""
    path = actual(spec["content"])
    if not path.is_file() or path.stat().st_size > 4194304 + 8192:
        raise ValueError("CONTACT_CAPTURE_IMAGE_CAPACITY")
    raw = path.read_bytes()
    if len(raw) < 184 or hashlib.sha256(raw).hexdigest() != spec["content_sha256"] or raw[:8] != b"UGACNT01":
        raise ValueError("CONTACT_CAPTURE_IMAGE_SOURCE")
    version, revision, parts, clips, frames, stride = struct.unpack_from("<6I", raw, 8)
    if version != 1 or revision <= 0 or not 1 <= parts <= 16 or not 1 <= clips <= 16 or not 2 <= frames <= 2048:
        raise ValueError("CONTACT_CAPTURE_IMAGE_CENSUS")
    at = 184 + parts * 72
    if stride < 12 or stride % 12 or at + clips * 48 + frames * (stride + 1) * 4 + 8 != len(raw) or raw[-8:] != b"UGAEND01":
        raise ValueError("CONTACT_CAPTURE_IMAGE_CENSUS")
    table = [struct.unpack_from("<4I", raw, at + clip * 48) for clip in range(clips)]
    prefix = 0
    for first, count, loop, duration in table:
        if first != prefix or count < 2 or loop > 2 or not (count - 2) * 65536 < duration <= (count - 1) * 65536:
            raise ValueError("CONTACT_CAPTURE_IMAGE_TIMING")
        prefix += count
    if prefix != frames:
        raise ValueError("CONTACT_CAPTURE_IMAGE_TIMING")
    return table


def validate_report(report: dict, mode: str, spec: dict, table: list[tuple[int, int, int, int]]) -> dict:
    """A zero native exit cannot bless an empty, partial, failed or wrongly scoped evidence report."""
    if report.get("production_qualified") is not False or report.get("content_sha256") != spec["content_sha256"]:
        raise ValueError("CONTACT_CAPTURE_REPORT_SCOPE")
    if type(report.get("assertions")) is not int or report["assertions"] <= 0 or report.get("failures") != []:
        raise ValueError("CONTACT_CAPTURE_REPORT_ASSERTIONS")
    if mode == "topology":
        parts = report.get("parts")
        if type(parts) is not list or len(parts) != 2 or any(type(part.get("surfaces")) is not list or
                not part["surfaces"] for part in parts):
            raise ValueError("CONTACT_CAPTURE_REPORT_TOPOLOGY")
        count = sum(len(row.get("indices", [])) for part in parts for row in part["surfaces"])
        if not 0 < count <= 393216 or count % 3 or any(type(row.get("vertex_count")) is not int or
                row["vertex_count"] <= 0 for part in parts for row in part["surfaces"]):
            raise ValueError("CONTACT_CAPTURE_REPORT_TOPOLOGY")
        return {"parts": 2, "indices": count, "assertions": report["assertions"]}
    if mode == "work":
        if len(table) != 9 or len(spec["source_frame_indices"]) != table[6][1]:
            raise ValueError("CONTACT_CAPTURE_REPORT_TIMING")
        handoff = sum(table[i][3] // 32768 + 1 for i in (7, 8)) if spec.get("rig_entry") else 9
        expected = 4 * (table[6][1] * 2 + handoff + sum(table[i][3] // 32768 + 1 for i in (0, 1, 4)))
        loops = [(clip, row) for clip, row in enumerate(table) if row[2] == 1]
        observed = report.get("loop_intervals")
        if type(observed) is not list or len(observed) != len(loops):
            raise ValueError("CONTACT_CAPTURE_REPORT_LOOPS")
        for found, (clip, (first, count, _, duration)) in zip(observed, loops):
            start = (count - 2) * 65536
            expected_samples = []
            for step in range(5):
                time = start + min(duration - start - 1, (duration - start) * step // 4)
                expected_samples.append([time, first + count - 2, first, (time - start) * 65536 // (duration - start)])
            if found != {"clip": clip, "duration_q16": duration, "frames": count, "samples": expected_samples}:
                raise ValueError("CONTACT_CAPTURE_REPORT_LOOPS")
        expected += 5 * len(loops)
    elif mode == "tip":
        expected = 9
        rows = report.get("native_points")
        if type(rows) is not list or len(rows) != 9 or any(row.get("share_q16") != i * 8192 for i, row in enumerate(rows)):
            raise ValueError("CONTACT_CAPTURE_REPORT_TIP")
    elif mode == "motion":
        expected = 6 * (2 * spec["last_source_frame"] + 1)
    else:
        raise ValueError("CONTACT_CAPTURE_REPORT_MODE")
    if type(report.get("poses")) is not int or report["poses"] != expected or report["assertions"] < expected * 2:
        raise ValueError("CONTACT_CAPTURE_REPORT_POSES")
    if type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("CONTACT_CAPTURE_REPORT_IMAGES")
    return {"poses": expected, "assertions": report["assertions"]}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--mode", choices=["topology", "motion", "work", "tip"], required=True)
    parser.add_argument("--last-frame", type=int, default=17)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--witness", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("CONTACT_CAPTURE_OUTPUT_EXISTS")
    if not 1 <= args.last_frame <= 56:
        raise ValueError("CONTACT_CAPTURE_FRAME")
    out = args.out.resolve()
    bake = HERE / "grip-source-v3/bake-spec.json"
    script = HERE / {"topology": "capture_topology.gd", "motion": "capture_motion.gd", "work": "capture_work_motion.gd",
                     "tip": "capture_tip_witness.gd"}[args.mode]
    # Asset import can change import-cache identities, so it precedes the actual
    # frozen native bundle. Its diagnostics still fail this complete run.
    out.mkdir(parents=True)
    command = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    with (out / "import.log").open("x") as log:
        imported = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    if imported.returncode or DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("CONTACT_CAPTURE_IMPORT")
    pins = closure(script, bake)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(last_source_frame=args.last_frame, mode=args.mode)
    if args.mode in ("work", "tip"):
        if args.preview is None:
            raise ValueError("CONTACT_CAPTURE_PREVIEW_MISSING")
        preview = args.preview.resolve()
        produced = json.loads((preview / "compilation.json").read_text())
        source = preview / "mole-worker.ugactor"
        if digest(source) != produced["content_sha256"] or produced.get("production_qualified") is not False:
            raise ValueError("CONTACT_CAPTURE_PREVIEW_SOURCE")
        spec.update(content=str(source), content_sha256=produced["content_sha256"],
                    reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"],
                    source_frame_indices=produced["source_frame_indices"], rig_entry=produced.get("rig_entry", False))
        for path in preview.iterdir():
            if path.is_file():
                pins[str(path)] = digest(path)
    if args.mode == "tip":
        if args.witness is None or not args.witness.is_file() or args.witness.stat().st_size > 1048576:
            raise ValueError("CONTACT_CAPTURE_WITNESS_MISSING")
        witness = json.loads(args.witness.read_text())
        if witness.get("content_sha256") != spec["content_sha256"] or witness.get("production_qualified") is not False:
            raise ValueError("CONTACT_CAPTURE_WITNESS_SOURCE")
        spec["tip_witness"] = {key: witness[key] for key in ("clip", "part", "mesh_sha256", "witness", "contact_patch_u")}
        pins[str(args.witness.resolve())] = digest(args.witness)
    for key in ("content", "basis", "manifest"):
        pins[str(actual(spec[key]).resolve())] = digest(actual(spec[key]))
    (out / "sources.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "spec.json").write_text(json.dumps(spec, indent=2) + "\n")
    native = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
              "--fixed-fps", "60", "--script", str(script), "--", str(out / "spec.json"), str(out)]
    with (out / "native.log").open("x") as log:
        result = subprocess.run(native, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
    after = {name: digest(Path(name)) if Path(name).is_file() else None for name in pins}
    (out / "sources-after.json").write_text(json.dumps(after, indent=2) + "\n")
    bad = bool(DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [command, native], "returncodes": [imported.returncode, result.returncode],
                  "source_unchanged": pins == after, "unexpected_diagnostics": bad, "production_qualified": False}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if result.returncode or bad or pins != after:
        raise ValueError("CONTACT_CAPTURE_NATIVE_OR_SOURCE")
    output = out / ("topology.json" if args.mode == "topology" else "report.json")
    report = json.loads(output.read_text())
    invocation["validated_report"] = validate_report(report, args.mode, spec, wire_timing(spec))
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    (out / "output-sha256.json").write_text(json.dumps({output.name: digest(output)}, indent=2) + "\n")
    print(json.dumps(invocation, indent=2))


if __name__ == "__main__":
    main()
