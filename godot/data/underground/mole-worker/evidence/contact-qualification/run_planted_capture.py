#!/usr/bin/env python3
"""Create-only native planted-source witness, with pre-import and pre/post execution source closure."""
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


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("PLANTED_NATIVE_OUTPUT_EXISTS")
    preview, out = args.preview.resolve(), args.out.resolve()
    produced = json.loads((preview / "compilation.json").read_text())
    candidate = json.loads((preview / "candidate.json").read_text())
    source = preview / "mole-worker.ugactor"
    if BASE.digest(source) != produced["content_sha256"] or produced.get("production_qualified") is not False:
        raise ValueError("PLANTED_NATIVE_SOURCE")
    script = HERE / "capture_planted_front.gd"
    bake = HERE / "high-wall-runtime-sources-v1/bake-spec.json"
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
        raise ValueError("PLANTED_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before != after_import:
        raise ValueError("PLANTED_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = dict(BASE.closure(script, bake), **before)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    witness = candidate["contact_candidates"][0]
    if witness["frame_pair"] != [14, 15] or witness["patch_u"][2] != -768:
        raise ValueError("PLANTED_NATIVE_TIP_SOURCE")
    # The same original native pick/mesh digest owns vertex148 in both source packets.
    previous_tip = json.loads((HERE / "high-wall-source-v4/candidate.json").read_text())["tip"]
    pins[str(HERE / "high-wall-source-v4/candidate.json")] = BASE.digest(HERE / "high-wall-source-v4/candidate.json")
    spec.update(content=str(source), content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"],
                source_frame_indices=list(range(30, 49)) + list(range(47, 29, -1)), rig_entry=True,
                wall_tip=dict(witness, source_point_f32_m=previous_tip["source_point_f32_m"]))
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
        raise ValueError("PLANTED_NATIVE_OR_DRIFT")
    checked = H.validate_report(json.loads((out / "report.json").read_text()), spec, BASE.wire_timing(spec))
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps(invocation, indent=2))


if __name__ == "__main__":
    main()
