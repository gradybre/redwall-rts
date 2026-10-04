#!/usr/bin/env python3
"""Native source-only open-timber witness, bound before/after execution; no physical qualification is emitted."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_high_capture_base", HERE / "run_high_wall.py")
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
BASE = H.BASE


def source_metadata(preview):
    image = preview / "mole-worker.ugactor"
    compiled = json.loads((preview / "compilation.json").read_text())
    if image.stat().st_size > 4202496:
        raise ValueError("STEP_NATIVE_IMAGE")
    raw_image = image.read_bytes()
    if hashlib.sha256(raw_image).hexdigest() != compiled["content_sha256"]:
        raise ValueError("STEP_NATIVE_IMAGE")
    header = raw_image[:184]
    candidate_path, plan_path = preview / "candidate.json", preview / "plan.json"
    if candidate_path.stat().st_size > 1048576 or plan_path.stat().st_size > 65536:
        raise ValueError("STEP_NATIVE_METADATA")
    candidate_raw, plan_raw = candidate_path.read_bytes(), plan_path.read_bytes()
    if (len(header) != 184 or header[:8] != b"UGACNT01" or
            hashlib.sha256(candidate_raw).hexdigest() != header[120:152].hex() or
            hashlib.sha256(plan_raw).hexdigest() != header[152:184].hex()):
        raise ValueError("STEP_NATIVE_METADATA")
    candidate = json.loads(candidate_raw)
    cases = [{"rise_u": row["rise_u"], "run_u": row["run_u"], "phase_frames": row["phase_frames"],
              "edge_z_u": row["edge_z_u"]} for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    if (not 1 <= len(cases) <= 4 or candidate.get("production_qualified") is not False or
            any(type(row["rise_u"]) is not int or row["rise_u"] not in (-256, -128, 128, 256) or
                row["run_u"] != 512 or row["phase_frames"] != 30 or row["edge_z_u"] != -169 for row in cases)):
        raise ValueError("STEP_NATIVE_CENSUS")
    return compiled, cases


def validate_report(report, spec):
    poses = 3 * 181 * len(spec["stair_cases"])
    if (report.get("content_sha256") != spec["content_sha256"] or report.get("poses") != poses or
            type(report.get("assertions")) is not int or report["assertions"] < 2 * poses or
            report.get("failures") != [] or report.get("production_qualified") is not False or
            report.get("stair_cases") != spec["stair_cases"] or
            not isinstance(report.get("screenshots"), list) or len(report["screenshots"]) != 30 * len(spec["stair_cases"])):
        raise ValueError("STEP_NATIVE_REPORT")
    return {"poses": poses, "screenshots": len(report["screenshots"]), "production_qualified": False,
            "scope": "native source presentation only; no physical clearance or support"}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("STEP_NATIVE_OUTPUT_EXISTS")
    preview, out = args.preview.resolve(), args.out.resolve()
    compiled, cases = source_metadata(preview)
    script, bake = HERE / "capture_stair_motion.gd", HERE / "high-wall-runtime-sources-v1/bake-spec.json"
    before = H.pre_import_pins(script, bake)
    for path in (Path(__file__).resolve(), *preview.iterdir()):
        if path.is_file():
            before[str(path)] = BASE.digest(path)
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "pre-import-sources.json").write_text(json.dumps(before, indent=2)+"\n")
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    with (out / "import.log").open("x") as log:
        code = subprocess.run(imported, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("STEP_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2)+"\n")
    if before != after_import:
        raise ValueError("STEP_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2)+"\n")
    pins = dict(BASE.closure(script, bake), **before)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(content=str(preview / "mole-worker.ugactor"), content_sha256=compiled["content_sha256"],
                reserve_bytes=compiled["presentation_budget"]["admitted_peak_bytes"], stair_cases=cases, production_qualified=False)
    for key in ("content", "basis", "manifest"):
        path = BASE.actual(spec[key]).resolve()
        pins[str(path)] = BASE.digest(path)
    (out / "sources.json").write_text(json.dumps(pins, indent=2)+"\n")
    (out / "spec.json").write_text(json.dumps(spec, indent=2)+"\n")
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--fixed-fps", "60", "--script", str(script), "--", str(out / "spec.json"), str(out)]
    with (out / "native.log").open("x") as log:
        code = subprocess.run(command, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    after = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in pins}
    (out / "sources-after.json").write_text(json.dumps(after, indent=2)+"\n")
    bad = bool(BASE.DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [imported, command], "native_exit": code, "source_unchanged": pins == after,
                  "unexpected_diagnostics": bad, "production_qualified": False, "pre_import_source_unchanged": before == after_import}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2)+"\n")
    if code or bad or pins != after:
        raise ValueError("STEP_NATIVE_OR_DRIFT")
    checked = validate_report(json.loads((out / "report.json").read_text()), spec)
    (out / "verification.json").write_text(json.dumps(checked, indent=2)+"\n")
    print(json.dumps(invocation, indent=2))


if __name__ == "__main__":
    main()
