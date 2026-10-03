#!/usr/bin/env python3
"""Export an isolated real-source cleanup probe; never modify the working Godot project."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ENTRY = "scripts/core/underground_world_bindings.gd"
FIXED = '\t\tvar released: StringName = _budget.release(token)\n\t\tassert(released == &"", "Exact completed phase lease releases once")'
REJECTED = '\t\tassert(_budget.release(token) == &"", "Exact completed phase lease releases once")'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_dependencies(destination: Path) -> dict[str, str]:
    """Copy byte-identical transitive res:// files, including source hashes for the exported probe."""
    pending, hashes = [ENTRY], {}
    while pending:
        relative = pending.pop()
        source = ROOT / "godot" / relative
        if relative in hashes or not source.is_file():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[relative] = digest(source)
        if source.suffix in {".gd", ".tscn", ".tres"}:
            pending.extend(re.findall(r'res://([^"\s]+)', source.read_text()))
    return dict(sorted(hashes.items()))


def run(command: list[str], log: Path) -> dict:
    with log.open("w") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    return {"command": command, "exit_code": result.returncode, "log": log.name}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--rejected-assert", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="codex-phase-release-") as temporary:
        project = Path(temporary) / "project"
        project.mkdir()
        hashes = copy_dependencies(project)
        source = project / ENTRY
        if args.rejected_assert:
            assert source.read_text().count(FIXED) == 1
            source.write_text(source.read_text().replace(FIXED, REJECTED))
        (project / "project.godot").write_text('''config_version=5
[application]
config/name="PhaseLeaseProbe"
run/main_scene="res://probe.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
''')
        (project / "probe.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://probe.gd" id="1"]
[node name="PhaseLeaseProbe" type="Node"]
script = ExtResource("1")
''')
        shutil.copyfile(HERE / "release_probe.gd", project / "probe.gd")
        (project / "export_presets.cfg").write_text('''[preset.0]
name="phase-release"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="universal"
application/bundle_identifier="org.redwall.phaseleaseprobe"
codesign/codesign=0
''')
        app = Path(temporary) / "PhaseLeaseProbe.app"
        calls = [run(["godot", "--headless", "--path", str(project), "--editor", "--quit"], args.output / "import.log")]
        assert calls[-1]["exit_code"] == 0, calls[-1]
        calls.append(run(["godot", "--headless", "--path", str(project), "--export-release", "phase-release", str(app)], args.output / "export.log"))
        assert calls[-1]["exit_code"] == 0, calls[-1]
        executable = next((app / "Contents/MacOS").iterdir())
        calls.append(run([str(executable), "--headless"], args.output / "release.log"))
        expected = 1 if args.rejected_assert else 0
        log = (args.output / "release.log").read_text()
        passed = calls[-1]["exit_code"] == expected and "assert_ran=false" in log
        if not args.rejected_assert:
            passed = passed and "checks=8 failures=0" in log
            passed = passed and not re.search(r"(?:SCRIPT ERROR|ERROR:|WARNING:|leaked|still in use)", log)
        evidence = {"scope": "isolated actual cleanup, not full room construction", "rejected_assert": args.rejected_assert,
                    "source_sha256": hashes, "exported_entry_sha256": digest(source),
                    "fixture_sha256": digest(HERE / "release_probe.gd"), "commands": calls, "passed": passed}
        (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
        print(log, end="")
        assert passed, "Release probe did not show the expected actual behavior"


if __name__ == "__main__":
    main()
