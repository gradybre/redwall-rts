"""Create-only seven-state bake of the exact authored mole grip; old source evidence is unchanged."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
GRIP_SOURCE = "res://data/underground/mole-worker/mole_grip_source.gd"
ORIGINAL = "a938d479014ebd3a431a118a7b1c9f7aa0b522d0a33a5c5d281e58e1e2f497c1"
DERIVED = "29f8d3218fddfaa6f2369c1c1c7dfd9b0a429b3df5cbefa38c6bf6ab9364fe14"


def load(name: str, path: Path):
    specification = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(base, palette) -> tuple[dict, dict]:
    spec = base.build()
    plan = json.loads((HERE.parents[1] / "source-plan.json").read_text())
    by_id = {row["id"]: row for row in palette.with_held_pick_states(spec["cases"])}
    selected = [by_id[name] for name in plan["clips"]]
    if len(selected) != 7 or any(row["cast"] != "mole_digger" or row["attachments"] != ["mole_pick"] for row in selected):
        raise ValueError("MOLE_GRIP_EXACT_STATE_SET")
    for row in selected:
        row.update(id=row["id"] + ".firm_grip_v1", grip_recipe="mole_firm_v1",
                   source_mesh_sha256=ORIGINAL, derived_mesh_sha256=DERIVED)
    spec["cases"] = selected
    sources = {pin["path"] for pin in spec["sources"]}
    pending = [GRIP_SOURCE]
    while pending:
        path = pending.pop()
        if path in sources:
            continue
        sources.add(path)
        pending.extend(re.findall(r'(?:preload|load)\(\s*"(res://[^"]+\.gd)"\s*\)', base.actual_path(path).read_text()))
    sources.update(str(ROOT / "tools" / name) for name in ("bake_mole_grip_content.gd", "bake_underground_matrices.gd"))
    sources.update((str(Path(__file__).resolve()), str(Path(palette.__file__).resolve()),
                    str(HERE.parents[1] / "source-plan.json")))
    spec["sources"] = [base.pin(path) for path in sorted(sources)]
    plan["revision"] = 2
    plan["clips"] = [name + ".firm_grip_v1" for name in plan["clips"]]
    for group in plan["groups"]:
        for key, names in group["states"].items():
            group["states"][key] = [name + ".firm_grip_v1" for name in names]
    plan["grip_recipe"] = "mole_firm_v1"
    return spec, plan


def run(bundle: Path, raw_name: str) -> None:
    raw = ROOT / "godot/demo/assets/underground-matrices" / raw_name
    archive = raw.with_suffix(".inputs")
    if Path(raw_name).name != raw_name or not raw_name.endswith(".ugpal"):
        raise ValueError("MOLE_GRIP_RAW_NAME")
    if any(path.exists() or path.is_symlink() for path in (bundle, raw, archive)):
        raise ValueError("MOLE_GRIP_OUTPUT_EXISTS")
    bundle = bundle.resolve()
    bundle.mkdir(parents=True)
    raw.parent.mkdir(parents=True, exist_ok=True)
    base = load("accepted_runtime_capture", ROOT / "docs/design/underground-planning/evidence/modular-build/profiles/runtime/reproduce.py")
    palette = load("accepted_palette_reproduce", ROOT / "godot/data/underground/evidence/matrix-presentation/reproduce.py")
    command = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    execute(command, bundle / "import.log", base)
    spec, plan = build(base, palette)
    target, output = bundle / "bake-spec.json", bundle / "bake-report.json"
    target.write_text(json.dumps(spec, indent=2) + "\n")
    (bundle / "source-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    entry = ROOT / "tools/bake_mole_grip_content.gd"
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--script", str(entry), "--", str(target), str(output), str(raw)]
    execute(command, bundle / "native.log", base)
    report = json.loads(output.read_text())
    base.validate_report(spec, report, (bundle / "native.log").read_text())
    for pin in [spec["manifest"], *spec["sources"]]:
        if base.pin(pin["path"]) != pin:
            raise ValueError("MOLE_GRIP_SOURCE_DRIFT:" + pin["path"])
    if report["finite_presentation_content"]["sha256"] != digest(raw):
        raise ValueError("MOLE_GRIP_CONTENT_DRIFT")
    imported = palette.archive_imports(spec, archive)
    verification = {"schema": 1, "command": command, "cases": len(report["cases"]),
                    "frames": sum(row["samples"] for row in report["cases"]),
                    "native_matrix_checks": sum(row["skin_engine_matrix_checks"] for row in report["cases"]),
                    "content_path": str(raw.relative_to(ROOT)), "content_bytes": raw.stat().st_size,
                    "content_sha256": digest(raw), "spec_sha256": digest(target), "report_sha256": digest(output),
                    "import_archive": imported, "qualified_profiles": 0, "unexpected_diagnostics": 0,
                    "leaked_objects": 0, "leaked_resources": 0, "source_geometry_sha256": ORIGINAL,
                    "derived_geometry_sha256": DERIVED}
    (bundle / "verification.json").write_text(json.dumps(verification, indent=2) + "\n")
    print(json.dumps(verification, indent=2))


def execute(command: list[str], log: Path, base) -> None:
    with log.open("x") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    if result.returncode or base.DIAGNOSTIC.search(log.read_text()):
        raise ValueError("MOLE_GRIP_NATIVE_REFUSED:" + log.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--raw-name", required=True)
    arguments = parser.parse_args()
    run(arguments.bundle, arguments.raw_name)
