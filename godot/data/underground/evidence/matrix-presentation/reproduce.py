#!/usr/bin/env python3
"""Create-only actual-source native matrix baking. No paid service or main-worktree mutation."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[5]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def archive_imports(spec, destination):
    """Preserve exact imported bytes across future clean CI imports, without accepting different sources."""
    if destination.exists() or destination.is_symlink():
        raise ValueError("PALETTE_IMPORT_ARCHIVE_EXISTS")
    destination.mkdir()
    unique = {}
    for pin in spec["sources"]:
        name = pin["path"]
        generated_import = name.startswith("res://demo/assets/") and name.endswith(".import")
        if not name.startswith("res://.godot/imported/") and not generated_import:
            continue
        source = (ROOT / "godot" / name[6:]).resolve()
        expected_root = ROOT / ("godot/demo/assets" if generated_import else "godot/.godot/imported")
        if not source.is_relative_to(expected_root.resolve()) or digest(source) != pin["sha256"]:
            raise ValueError("PALETTE_IMPORT_ARCHIVE_SOURCE")
        if pin["sha256"] in unique:
            continue
        target = destination / (pin["sha256"] + ".input")
        with source.open("rb") as incoming, target.open("xb") as outgoing:
            shutil.copyfileobj(incoming, outgoing, length=65536)
        if digest(target) != pin["sha256"]:
            raise ValueError("PALETTE_IMPORT_ARCHIVE_COPY")
        unique[pin["sha256"]] = source.stat().st_size
    return {"path": str(destination), "files": len(unique), "bytes": sum(unique.values())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--raw-name", required=True, help="unique filename in this own worktree's ignored matrix assets")
    parser.add_argument("--preview", action="store_true", help="also capture native original/affine comparison images")
    args = parser.parse_args()
    # Test the lexical path before resolve() can hide a dangling output symlink.
    if args.directory.exists() or args.directory.is_symlink():
        raise ValueError("PALETTE_OUTPUT_BUNDLE_EXISTS")
    bundle = args.directory.resolve()
    if Path(args.raw_name).name != args.raw_name or not args.raw_name.endswith(".ugpal"):
        raise ValueError("PALETTE_RAW_NAME")
    content = ROOT / "godot/demo/assets/underground-matrices" / args.raw_name
    if content.exists() or content.is_symlink():
        raise ValueError("PALETTE_RAW_EXISTS")
    archive = content.with_suffix(".inputs")
    if archive.exists() or archive.is_symlink():
        raise ValueError("PALETTE_IMPORT_ARCHIVE_EXISTS")
    content.parent.mkdir(parents=True, exist_ok=True)
    bundle.mkdir(parents=True)
    commands = [
        ["godot", "--headless", "--path", "godot", "--editor", "--quit"],
        ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
         "--script", "res://data/underground/evidence/matrix-presentation/native_adapter_check.gd"],
        ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
         "--script", "res://data/underground/evidence/matrix-presentation/native_grounding_check.gd"],
    ]
    for command, name in zip(commands, ["import", "native-adapter", "native-grounding"]):
        with (bundle / (name + ".log")).open("x") as log:
            completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        if completed.returncode:
            raise ValueError(f"PALETTE_{name.upper()}_EXIT:{completed.returncode}")
        text = (bundle / (name + ".log")).read_text()
        if any(marker in text for marker in ("ERROR:", "WARNING:", "SCRIPT ERROR:", "leaked at exit", "resources still in use")):
            raise ValueError(f"PALETTE_{name.upper()}_DIAGNOSTIC")
    source = ROOT / "docs/design/underground-planning/evidence/modular-build/profiles/runtime/reproduce.py"
    specification = importlib.util.spec_from_file_location("reviewed_capture_reproduce", source)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    spec = module.build()
    if args.case:
        selected = set(args.case)
        spec["cases"] = [row for row in spec["cases"] if row["id"] in selected]
        if len(spec["cases"]) != len(selected):
            raise ValueError("PALETTE_CASE_NOT_IN_ACTUAL_MANIFEST")
    else:
        # Heading is applied by the actual renderer, not silently baked into a source clip.
        spec["cases"] = [row for row in spec["cases"] if row["scenario"] != "turn"]
    for relative in ("tools/bake_underground_matrices.gd", "godot/demo/cast/underground_actor.gd"):
        path = ROOT / relative
        spec["sources"].append({"path": str(path), "sha256": digest(path)})
    entry = ROOT / "tools/bake_underground_matrices.gd"
    if args.preview:
        entry = Path(__file__).with_name("native_compare.gd")
        spec["sources"].append({"path": str(entry), "sha256": digest(entry)})
    target = bundle / "bake-spec.json"
    with target.open("x") as stream:
        json.dump(spec, stream, indent=2)
        stream.write("\n")
    output = bundle / "bake-report.json"
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--script", str(entry), "--", str(target), str(output), str(content)]
    with (bundle / "native-bake.log").open("x") as log:
        completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
    if completed.returncode:
        raise ValueError(f"PALETTE_NATIVE_EXIT:{completed.returncode}")
    report = json.loads(output.read_text())
    module.validate_report(spec, report, (bundle / "native-bake.log").read_text())
    for pin in [spec["manifest"], *spec["sources"]]:
        if module.pin(pin["path"]) != pin:
            raise ValueError(f"PALETTE_SOURCE_DRIFT:{pin['path']}")
    if report["finite_presentation_content"]["sha256"] != digest(content):
        raise ValueError("PALETTE_CONTENT_DRIFT")
    imported = archive_imports(spec, archive)
    verification = {"schema": 1, "command": command, "cases": len(report["cases"]),
                    "frames": sum(row["samples"] for row in report["cases"]),
                    "native_matrix_checks": sum(row["skin_engine_matrix_checks"] for row in report["cases"]),
                    "content_path": str(content.relative_to(ROOT)),
                    "content_bytes": content.stat().st_size, "content_sha256": digest(content),
                    "spec_sha256": digest(target), "report_sha256": digest(output),
                    "import_archive": imported,
                    "qualified_profiles": 0, "meaning": "finite matrix presentation source, pending enclosure and visual gates",
                    "unexpected_diagnostics": 0, "leaked_objects": 0, "leaked_resources": 0}
    with (bundle / "verification.json").open("x") as stream:
        json.dump(verification, stream, indent=2)
        stream.write("\n")
    print(json.dumps(verification, indent=2))


if __name__ == "__main__":
    main()
