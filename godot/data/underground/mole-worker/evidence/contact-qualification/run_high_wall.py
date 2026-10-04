#!/usr/bin/env python3
"""Create-only source-pinned native high-wall candidate witness. No paid game geometry is created."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("capture_support", HERE / "run_capture.py")
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)


def pre_import_pins(script: Path, bake: Path) -> dict:
    """Pin executable/raw sources before import; generated cache files are separately matched after import."""
    spec = json.loads(bake.read_text())
    result = {}
    for row in [spec["manifest"], *spec["sources"]]:
        if row["path"].startswith("res://.godot/"):
            continue
        path = BASE.actual(row["path"])
        if BASE.digest(path) != row["sha256"]:
            raise ValueError("HIGH_WALL_PREIMPORT_SOURCE")
        result[str(path)] = row["sha256"]
    pending = [script]
    seen = set()
    while pending:
        path = pending.pop().resolve()
        if path in seen:
            continue
        seen.add(path)
        result[str(path)] = BASE.digest(path)
        text = path.read_text()
        for dependency in BASE.re.findall(r'(?:preload|load)\(\s*"(res://[^"\n]+\.gd)"\s*\)', text):
            pending.append(BASE.actual(dependency))
        for dependency in BASE.re.findall(r'^extends\s+"([^"\n]+\.gd)"', text, BASE.re.M):
            pending.append(BASE.actual(dependency) if dependency.startswith("res://") else path.parent / dependency)
        if len(seen) > 2048:
            raise ValueError("HIGH_WALL_PREIMPORT_CAPACITY")
    for path in (Path(__file__).resolve(), Path(BASE.__file__).resolve(), bake.resolve()):
        result[str(path)] = BASE.digest(path)
    return result


def validate_report(report: dict, spec: dict, table: list) -> dict:
    """Require every expected rendered pose and all actual tip observations, even after a zero native exit."""
    if len(table) != 9 or len(spec["source_frame_indices"]) != table[6][1]:
        raise ValueError("HIGH_WALL_REPORT_TIMING")
    expected = 3 * (2 * table[6][1] + sum(table[i][3] // 32768 + 1 for i in (7, 8))) + 9
    if report.get("production_qualified") is not False or report.get("content_sha256") != spec["content_sha256"] \
            or report.get("source_frame_indices") != spec["source_frame_indices"] or report.get("failures") != []:
        raise ValueError("HIGH_WALL_REPORT_SCOPE")
    if type(report.get("poses")) is not int or report["poses"] != expected or \
            type(report.get("assertions")) is not int or report["assertions"] < 2 * expected:
        raise ValueError("HIGH_WALL_REPORT_CENSUS")
    points = report.get("native_tip")
    if type(points) is not list or len(points) != 9 or any(row.get("share_q16") != i * 8192 or
            type(row.get("local_point_u")) is not list or len(row["local_point_u"]) != 3 for i, row in enumerate(points)):
        raise ValueError("HIGH_WALL_REPORT_TIP")
    if type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("HIGH_WALL_REPORT_IMAGES")
    return {"poses": expected, "assertions": report["assertions"], "tip_samples": 9}


def restore_pinned_imports(bake: Path, archive: Path, root: Path) -> list:
    """Reproduce the accepted native import bytes in this isolated cache; never overwrite source assets or scripts."""
    directory = root / "godot/.godot/imported"
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("HIGH_WALL_IMPORT_CACHE")
    records, total = [], 0
    for row in json.loads(bake.read_text())["sources"]:
        name = row["path"]
        if not name.startswith("res://.godot/imported/"):
            continue
        relative = name.removeprefix("res://.godot/imported/")
        if Path(relative).name != relative or not relative.endswith(".scn"):
            raise ValueError("HIGH_WALL_IMPORT_PATH")
        expected = row["sha256"]
        if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
            raise ValueError("HIGH_WALL_IMPORT_HASH")
        source, target = archive / (expected + ".input"), directory / relative
        if source.is_symlink() or not source.is_file() or target.is_symlink() or source.stat().st_size > 16777216:
            raise ValueError("HIGH_WALL_IMPORT_ARCHIVE")
        total += source.stat().st_size
        if total > 67108864 or len(records) >= 256 or BASE.digest(source) != expected:
            raise ValueError("HIGH_WALL_IMPORT_ARCHIVE")
        records.append({"path": str(target), "archive": str(source), "sha256": expected,
                        "before": BASE.digest(target) if target.is_file() else None})
    # Validate every archive before replacing even one generated cache entry.
    for row in records:
        data = Path(row["archive"]).read_bytes()
        if BASE.hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise ValueError("HIGH_WALL_IMPORT_ARCHIVE_DRIFT")
        Path(row["path"]).write_bytes(data)
    return records


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("HIGH_WALL_OUTPUT_EXISTS")
    preview = args.preview.resolve()
    produced = json.loads((preview / "compilation.json").read_text())
    candidate = json.loads((preview / "candidate.json").read_text())
    source = preview / "mole-worker.ugactor"
    if BASE.digest(source) != produced["content_sha256"] or produced.get("production_qualified") is not False:
        raise ValueError("HIGH_WALL_SOURCE")
    out = args.out.resolve()
    script = HERE / "capture_high_wall.gd"
    bake = HERE / "high-wall-runtime-sources-v1/bake-spec.json"
    before_import = pre_import_pins(script, bake)
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "pre-import-sources.json").write_text(json.dumps(before_import, indent=2) + "\n")
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    with (out / "import.log").open("x") as log:
        code = subprocess.run(imported, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("HIGH_WALL_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before_import}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before_import != after_import:
        raise ValueError("HIGH_WALL_IMPORT_SOURCE_DRIFT")
    restored = restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = BASE.closure(script, bake)
    pins[str(Path(__file__).resolve())] = BASE.digest(Path(__file__))
    pins[str(Path(BASE.__file__).resolve())] = BASE.digest(Path(BASE.__file__))
    for path in preview.iterdir():
        if path.is_file():
            pins[str(path)] = BASE.digest(path)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(content=str(source), content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"],
                source_frame_indices=produced["source_frame_indices"], rig_entry=True, wall_tip=candidate["tip"])
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
                  "unexpected_diagnostics": bad, "production_qualified": False,
                  "pre_import_source_unchanged": before_import == after_import}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if code or bad or pins != after:
        raise ValueError("HIGH_WALL_NATIVE_OR_DRIFT")
    checked = validate_report(json.loads((out / "report.json").read_text()), spec, BASE.wire_timing(spec))
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps(invocation, indent=2))


if __name__ == "__main__":
    main()
