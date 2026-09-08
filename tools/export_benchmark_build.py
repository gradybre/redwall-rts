#!/usr/bin/env python3
"""Export a release build that boots straight into the work benchmark fixture, and prove that
that build compiled `assert()` out.

WHY A DEDICATED BUILD, AND NOT THE OTHER TWO OPTIONS. Godot 4.7.2's official export templates
are compiled with `disable_path_overrides=true`. Verified on this machine, not assumed:

  * the editor's own `--help` marks `--path`, `--main-pack` and `-s/--script` with `X`
    ("only available in editor builds, and export templates compiled with
    disable_path_overrides=false");
  * none of those three options appears in the release template's `--help` at all;
  * `godot_macos_release.universal --headless --path <project>` aborts with
    "`--path` was specified on the command line, but this Godot binary was compiled without
    support for path overrides. Aborting." (main/main.cpp:1784), and `--main-pack` aborts the
    same way at main.cpp:1894.

So running the existing `--path`/`--script` invocation on a release template is impossible, and
so is `--main-pack` against an exported PCK. What remains is exporting a build whose main loop
IS the fixture, which is what this script does.

WHAT IT DOES NOT TOUCH. `tools/benchmark_work.gd` is copied byte for byte; its SHA-256 is
recorded on both sides so the editor and release runs demonstrably time the same fixture
source. `godot/` is never exported in place and never modified: a throwaway copy is built under
--work-dir, the three project-setting deltas it needs are applied to the COPY, and every delta
is recorded in the manifest.

WHAT THIS BUILD IS NOT. A release build on this machine is not the REQ-SET-163 qualification
floor (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080). Nothing produced from it may be
presented as satisfying REQ-SET-163.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

PRESET_NAME = "macos-benchmark-release"
BENCH_DIR = "bench"
FIXTURE_RES_PATH = "res://bench/benchmark_work.gd"
MAIN_LOOP_RES_PATH = "res://bench/benchmark_main_loop.gd"
MAIN_LOOP_CLASS = "RedwallBenchmarkMainLoop"
MAIN_SCENE_RES_PATH = "res://bench/bench_main.tscn"
IMPORT_TIMEOUT_SECONDS = 600
EXPORT_TIMEOUT_SECONDS = 600
PROBE_TIMEOUT_SECONDS = 120

MAIN_SCENE_TEXT = """[gd_scene format=3 uid="uid://cbmrwbenchmain0"]

[node name="BenchmarkMain" type="Node"]
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-path", required=True, type=Path,
                        help="the real project, copied and never modified")
    parser.add_argument("--work-dir", required=True, type=Path,
                        help="throwaway directory for the benchmark project and its build")
    parser.add_argument("--manifest-path", required=True, type=Path)
    parser.add_argument("--godot", default="godot", help="the EDITOR binary, used to export")
    parser.add_argument("--fixture-path", type=Path,
                        default=Path(__file__).with_name("benchmark_work.gd"))
    parser.add_argument("--main-loop-path", type=Path,
                        default=Path(__file__).with_name("benchmark_main_loop.gd"))
    parser.add_argument("--preset-path", type=Path, default=None,
                        help="export_presets.cfg to copy in; defaults to the project's own")
    return parser.parse_args()


def utc_now() -> str:
    """An ISO-8601 UTC timestamp for the manifest."""
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    """The SHA-256 of one file's bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def core_source_hashes(project: Path) -> dict[str, str]:
    """SHA-256 of every core script, so a build can name the code it packed."""
    return {path.name: sha256_file(path)
            for path in sorted((project / "scripts/core").glob("*.gd"))}


def strip_ansi(text: str) -> str:
    """Godot colours its console output; the manifest stores it plain."""
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def run(command: list[str], timeout: int) -> dict:
    """Run one bounded subprocess and return its record. Raises on timeout."""
    completed = subprocess.run(command, capture_output=True, text=True, check=False,
                               timeout=timeout)
    return {
        "command": [str(part) for part in command],
        "returncode": completed.returncode,
        "stdout": strip_ansi(completed.stdout)[-8000:],
        "stderr": strip_ansi(completed.stderr)[-8000:],
    }


def copy_project(source: Path, destination: Path) -> None:
    """Copy the project without its engine cache, so the copy imports from a clean state."""
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination,
                    ignore=shutil.ignore_patterns(".godot", "*.tmp", ".DS_Store"))


def project_deltas() -> list[tuple[str, str, str, str]]:
    """Every project-setting change the benchmark build needs, with the reason for each.

    Returned as (section, key, value, reason). Nothing here is a balance constant and nothing
    here may be read back into `godot/project.godot` without its owner deciding to.
    """
    return [
        ("application", "run/main_scene", f'"{MAIN_SCENE_RES_PATH}"',
         "an exported build always instantiates a main scene; an empty Node keeps that "
         "instantiation out of the fixture's way, where the shipped main scene would not"),
        ("application", "run/main_loop_type", f'"{MAIN_LOOP_CLASS}"',
         "the only way an exported build can reach a SceneTree-derived fixture, because "
         "--script is rejected by the release template"),
        ("rendering", "textures/vram_compression/import_etc2_astc", "true",
         "the macOS arm64/universal export refuses to run without it; x86_64 is not used "
         "instead because it would measure Rosetta 2 translation on Apple Silicon"),
    ]


def apply_deltas(project_file: Path) -> dict:
    """Apply the benchmark build's project-setting deltas, recording before and after."""
    original = project_file.read_text()
    text = original
    applied = []
    for section, key, value, reason in project_deltas():
        text = set_setting(text, section, key, value)
        applied.append({"section": section, "key": key, "value": value, "reason": reason})
    project_file.write_text(text)
    return {
        "applied": applied,
        "project_godot_sha256_before": hashlib.sha256(original.encode()).hexdigest(),
        "project_godot_sha256_after": hashlib.sha256(text.encode()).hexdigest(),
    }


def set_setting(text: str, section: str, key: str, value: str) -> str:
    """Set one `key=value` inside `[section]`, replacing an existing line or appending it."""
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    header = f"[{section}]"
    if header not in text:
        return text + f"\n{header}\n\n{key}={value}\n"
    start = text.index(header) + len(header)
    end = text.find("\n[", start)
    end = len(text) if end < 0 else end
    body = text[start:end]
    if pattern.search(body):
        body = pattern.sub(f"{key}={value}", body, count=1)
    else:
        body = body.rstrip("\n") + f"\n{key}={value}\n"
    return text[:start] + body + text[end:]


def assemble(args: argparse.Namespace) -> tuple[Path, dict]:
    """Build the throwaway benchmark project and return it with its assembly record."""
    project = args.project_path.resolve()
    bench_project = args.work_dir.resolve() / "benchproj"
    copy_project(project, bench_project)
    bench_dir = bench_project / BENCH_DIR
    bench_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.fixture_path, bench_dir / "benchmark_work.gd")
    shutil.copyfile(args.main_loop_path, bench_dir / "benchmark_main_loop.gd")
    (bench_dir / "bench_main.tscn").write_text(MAIN_SCENE_TEXT)
    preset_source = args.preset_path or (project / "export_presets.cfg")
    if not preset_source.is_file():
        raise SystemExit(f"no export preset at {preset_source}")
    shutil.copyfile(preset_source, bench_project / "export_presets.cfg")
    record = {
        "benchmark_project": str(bench_project),
        "project_settings": apply_deltas(bench_project / "project.godot"),
        "export_preset_source": str(preset_source),
        "export_preset_sha256": sha256_file(preset_source),
    }
    return bench_project, record


def verify_sources(project: Path, bench_project: Path, args: argparse.Namespace) -> dict:
    """Refuse unless the packed fixture and every packed core script are byte-identical."""
    original = core_source_hashes(project)
    packed = core_source_hashes(bench_project)
    fixture = sha256_file(args.fixture_path)
    packed_fixture = sha256_file(bench_project / BENCH_DIR / "benchmark_work.gd")
    if original != packed:
        raise RuntimeError(f"packed core sources differ from {project}")
    if fixture != packed_fixture:
        raise RuntimeError("the packed fixture is not byte-identical to tools/benchmark_work.gd")
    return {
        "core_source_hashes": original,
        "core_sources_identical": True,
        "fixture_path": str(args.fixture_path),
        "fixture_sha256": fixture,
        "packed_fixture_sha256": packed_fixture,
        "fixture_identical": True,
        "main_loop_path": str(args.main_loop_path),
        "main_loop_sha256": sha256_file(args.main_loop_path),
    }


def export_build(args: argparse.Namespace, bench_project: Path) -> tuple[Path, dict]:
    """Import the benchmark project, export it release, and return the executable it produced."""
    build_dir = args.work_dir.resolve() / "build"
    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True)
    app_path = build_dir / "RedwallWorkBenchmark.app"
    editor = run([args.godot, "--headless", "--path", str(bench_project), "--editor", "--quit"],
                 IMPORT_TIMEOUT_SECONDS)
    if editor["returncode"] != 0:
        raise RuntimeError(f"benchmark project import failed: {editor}")
    export = run([args.godot, "--headless", "--path", str(bench_project),
                  "--export-release", PRESET_NAME, str(app_path)], EXPORT_TIMEOUT_SECONDS)
    if export["returncode"] != 0:
        raise RuntimeError(f"release export failed: {export}")
    executable = find_executable(app_path)
    return executable, {
        "import": editor,
        "export": export,
        "app_path": str(app_path),
        "executable": str(executable),
        "executable_sha256": sha256_file(executable),
        "packed_files": packed_file_list(export["stdout"]),
    }


def packed_file_list(export_stdout: str) -> list[str]:
    """Every `res://` path the exporter reported storing, so the PCK's contents are on record."""
    return sorted(set(re.findall(r"Storing File: (res://\S+)", export_stdout)))


def find_executable(app_path: Path) -> Path:
    """The single Mach-O entry point inside the exported bundle. Refuses if it is not single."""
    macos_dir = app_path / "Contents/MacOS"
    if not macos_dir.is_dir():
        raise RuntimeError(f"exported bundle has no Contents/MacOS: {app_path}")
    entries = [item for item in sorted(macos_dir.iterdir()) if item.is_file()]
    if len(entries) != 1:
        raise RuntimeError(f"expected exactly one executable in {macos_dir}, found {entries}")
    return entries[0]


def assert_probe(command: list[str], output_path: Path, label: str) -> dict:
    """Run the paired assert probe once and read back whatever stage it managed to write."""
    if output_path.exists():
        output_path.unlink()
    process = run(command, PROBE_TIMEOUT_SECONDS)
    record = json.loads(output_path.read_text()) if output_path.exists() else None
    return {"label": label, "process": process, "probe": record}


def run_assert_probes(args: argparse.Namespace, bench_project: Path,
                      executable: Path) -> dict:
    """Run the same probe source on both binaries and refuse unless they disagree correctly."""
    work = args.work_dir.resolve()
    editor_out = work / "assert-probe-editor.json"
    release_out = work / "assert-probe-release.json"
    editor = assert_probe([args.godot, "--headless", "--path", str(bench_project),
                           "--script", MAIN_LOOP_RES_PATH, "--quit-after", "1",
                           "--", "--assert-probe", "--output", str(editor_out)],
                          editor_out, "editor binary")
    release = assert_probe([str(executable), "--headless", "--quit-after", "1",
                            "--", "--assert-probe", "--output", str(release_out)],
                           release_out, "exported release build")
    verdict = probe_verdict(editor, release)
    if not verdict["release_asserts_compiled_out"]:
        raise RuntimeError(f"the exported build did NOT strip asserts: {verdict}")
    if not verdict["editor_asserts_live"]:
        raise RuntimeError(f"the editor control did not show live asserts: {verdict}")
    return {"editor": editor, "release": release, "verdict": verdict}


def probe_verdict(editor: dict, release: dict) -> dict:
    """Turn the two probe records into the one claim this build is allowed to make."""
    editor_probe = editor["probe"] or {}
    release_probe = release["probe"] or {}
    editor_live = (editor_probe.get("argument_evaluations") ==
                   editor_probe.get("expected_debug_evaluations")
                   and editor_probe.get("reached_after_failing_assert") is False
                   and "Assertion failed" in editor["process"]["stdout"] +
                   editor["process"]["stderr"])
    release_out = (release_probe.get("argument_evaluations") == 0
                   and release_probe.get("reached_after_failing_assert") is True
                   and "Assertion failed" not in release["process"]["stdout"] +
                   release["process"]["stderr"])
    return {
        "editor_asserts_live": bool(editor_live),
        "release_asserts_compiled_out": bool(release_out),
        "editor_argument_evaluations": editor_probe.get("argument_evaluations"),
        "release_argument_evaluations": release_probe.get("argument_evaluations"),
        "editor_stage": editor_probe.get("stage"),
        "release_stage": release_probe.get("stage"),
        "editor_features": feature_summary(editor_probe),
        "release_features": feature_summary(release_probe),
    }


def feature_summary(probe: dict) -> dict:
    """The binary's own self-report, recorded beside the behaviour rather than instead of it."""
    keys = ("os_is_debug_build", "feature_debug", "feature_release", "feature_editor",
            "feature_template", "feature_template_debug", "feature_template_release",
            "feature_arm64", "feature_x86_64", "processor_name")
    return {key: probe.get(key) for key in keys}


def main() -> int:
    """Assemble, export, prove the asserts are gone, and write the manifest."""
    args = parse_args()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    started = utc_now()
    bench_project, assembly = assemble(args)
    sources = verify_sources(args.project_path.resolve(), bench_project, args)
    executable, build = export_build(args, bench_project)
    probes = run_assert_probes(args, bench_project, executable)
    manifest = {
        "schema": "redwall-benchmark-build-manifest-v1",
        "ok": True,
        "started_utc": started,
        "finished_utc": utc_now(),
        "godot_editor": run([args.godot, "--version"], PROBE_TIMEOUT_SECONDS),
        "source_project": str(args.project_path.resolve()),
        "export_preset_name": PRESET_NAME,
        "assembly": assembly,
        "sources": sources,
        "build": build,
        "assert_probes": probes,
        "is_release_measurement_capable": True,
        "is_qualification_floor_measurement": False,
        "scope_note": (
            "An Apple Silicon release build is not the REQ-SET-163 qualification floor "
            "(Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080). Windows is deferred."
        ),
        "host": {"platform": platform.platform(), "machine": platform.machine()},
        "python": sys.version,
    }
    args.manifest_path.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"benchmark build ready: {executable}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
