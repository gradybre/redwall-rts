#!/usr/bin/env python3
"""Create-only v3 driver replay with exact role/frame census and an isolated native user directory."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_install_capture", HERE / "run_compact_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
H, BASE = R.H, R.BASE
PROFILE_NAMES = ("stand", "ground_walk", "down", "high", "front", "install")


def bounded_json(path, maximum):
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= maximum:
        raise ValueError("INSTALL_PROGRAM_NATIVE_METADATA_CAPACITY")
    return json.loads(path.read_text())


def expected_poses(table):
    """The inherited compact program plus interrupted entry and a complete INSTALL work/recovery cycle."""
    if len(table) != 14 or [list(row[1:]) for row in table[11:]] != [
            [33, 1, 32 * 65536], [31, 0, 30 * 65536], [31, 0, 30 * 65536]]:
        raise ValueError("INSTALL_PROGRAM_NATIVE_TIMING")
    return R.expected_poses(table[:11]) + 3 * (17 + 17 + 60 + 64 + 60)


def event_refusal(event, table):
    """Every emitted frame pair must belong to the exact selected productive role or proved hub/fade."""
    phase, profile, frames = event.get("phase"), event.get("profile"), event.get("frames")
    if type(phase) is not int or not 0 <= phase < 9 or type(profile) is not int or not 0 <= profile < 6 or \
            type(event.get("ready")) is not bool or event["ready"] != (phase == 0) or \
            type(frames) is not list or len(frames) != 7 or any(type(v) is not int for v in frames) or \
            any(not 0 <= frames[i] <= 65536 for i in (2, 5, 6)):
        raise ValueError("INSTALL_PROGRAM_NATIVE_EVENT")
    if phase >= 5 and profile < 2 or phase == 1 and profile != 0 or phase in (2, 4) and profile != 1:
        raise ValueError("INSTALL_PROGRAM_NATIVE_ROLE")
    clip = {0: 0, 1: 0, 2: 1, 3: 0, 4: 1}.get(phase)
    if clip is None:
        clip = 2 + 3 * (profile - 2) + {5: 1, 6: 0, 7: 2, 8: 1}[phase]
    first, count, _, _ = table[clip]
    if not all(first <= frames[i] < first + count for i in (0, 1)):
        raise ValueError("INSTALL_PROGRAM_NATIVE_ROLE_FRAMES")
    if phase in (0, 3) and frames[:3] != [8, 9, 0]:
        raise ValueError("INSTALL_PROGRAM_NATIVE_HUB")
    if phase in (3, 4):
        if not all(0 <= frames[i] < table[1][0] + table[1][1] for i in (3, 4)):
            raise ValueError("INSTALL_PROGRAM_NATIVE_FADE_SOURCE")
    elif frames[:3] != frames[3:6] or frames[6] != 65536:
        raise ValueError("INSTALL_PROGRAM_NATIVE_UNAUTHORED_BLEND")


def validate_report(report, spec, table):
    expected = expected_poses(table)
    if report.get("production_qualified") is not False or report.get("content_sha256") != spec["content_sha256"] or \
            report.get("failures") != [] or report.get("program_version") != 3 or \
            not str(report.get("user_directory", "")).endswith("/" + spec["user_directory_name"]):
        raise ValueError("INSTALL_PROGRAM_NATIVE_SCOPE")
    if type(report.get("poses")) is not int or report["poses"] != expected or \
            type(report.get("assertions")) is not int or report["assertions"] < 4 * expected:
        raise ValueError("INSTALL_PROGRAM_NATIVE_CENSUS")
    events, counts = report.get("events"), report.get("phase_counts")
    if type(events) is not list or len(events) != expected or type(counts) is not list or len(counts) != 10 or \
            any(type(n) is not int or n <= 0 for n in counts[:9]) or counts[9] != 0 or sum(counts) != expected:
        raise ValueError("INSTALL_PROGRAM_NATIVE_PHASES")
    actual, work_phases = [0] * 10, set()
    for event in events:
        event_refusal(event, table)
        actual[event["phase"]] += 1
        if event["profile"] >= 2:
            work_phases.add((event["profile"], event["phase"]))
    if actual != counts or not {(role, phase) for role in (2, 3, 4, 5) for phase in (5, 6, 7)}.issubset(work_phases) or \
            (5, 8) not in work_phases or type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("INSTALL_PROGRAM_NATIVE_PHASES")
    install_sequence_refusal(events)
    return {"poses": expected, "assertions": report["assertions"], "phases": 9, "work_choices": 4,
            "production_qualified": False}


def install_sequence_refusal(events):
    """An empty install cycle cannot be replaced with extra valid idle poses or a partial other view."""
    labels = {view + "-install-" + phase: count for view in ("side", "opposite", "rts")
              for phase, count in (("partial", 17), ("retrace", 17), ("work", 83), ("recovery", 101))}
    observed = {label: [] for label in labels}
    for event in events:
        if event["profile"] != 5:
            continue
        label, tick = event.get("label"), event.get("tick")
        if label not in labels or type(tick) is not int:
            raise ValueError("INSTALL_PROGRAM_NATIVE_SEQUENCE")
        observed[label].append(tick)
    if any(observed[label] != list(range(count)) for label, count in labels.items()):
        raise ValueError("INSTALL_PROGRAM_NATIVE_SEQUENCE")


def bound_roles(source, digest, preview):
    """The actual immutable source image owns protocol and complete role bytes; filenames are insufficient."""
    if source.is_symlink() or not source.is_file() or not 184 <= source.stat().st_size <= 4 * 1048576 + 8192 or BASE.digest(source) != digest:
        raise ValueError("INSTALL_PROGRAM_NATIVE_SOURCE")
    with source.open("rb") as stream:
        header = stream.read(184)
    values = []
    for name, start, limit in (("program.json", 88, 1048576), ("roles.json", 120, 1048576), ("plan.json", 152, 65536)):
        path = preview / name
        value = bounded_json(path, limit)
        if bytes.fromhex(BASE.digest(path)) != header[start:start + 32]:
            raise ValueError("INSTALL_PROGRAM_NATIVE_METADATA")
        values.append(value)
    program, roles, _ = values
    if program.get("program_version") != 3 or program.get("production_qualified") is not False or \
            roles.get("production_qualified") is not False or set(roles.get("roles", {})) != set(PROFILE_NAMES) or \
            program.get("profile_roles") != dict(zip(PROFILE_NAMES, range(6))) or \
            roles.get("complete_install_phase_coverage", {}).get("clear") is not True:
        raise ValueError("INSTALL_PROGRAM_NATIVE_METADATA")
    return roles["roles"]


def output_refusal(path):
    """Check before resolve: a dangling symlink cannot redirect a supposedly new evidence bundle."""
    if path.exists() or path.is_symlink():
        raise ValueError("INSTALL_PROGRAM_NATIVE_OUTPUT_EXISTS")


def run(preview, out):
    output_refusal(out)
    out = out.resolve()
    produced = bounded_json(preview / "compilation.json", 65536)
    source = preview / "mole-worker.ugactor"
    roles = bound_roles(source, produced["content_sha256"], preview)
    if produced.get("production_qualified") is not False:
        raise ValueError("INSTALL_PROGRAM_NATIVE_SOURCE")
    expected_poses(BASE.wire_timing({"content": str(source), "content_sha256": produced["content_sha256"]}))
    script, bake = HERE / "capture_install_program.gd", HERE / "high-wall-runtime-sources-v1/bake-spec.json"
    before = H.pre_import_pins(script, bake)
    for path in (Path(__file__).resolve(), Path(R.__file__).resolve(), Path(R.R.__file__).resolve(), *preview.iterdir()):
        if path.is_file():
            before[str(path)] = BASE.digest(path)
    override = BASE.ROOT / "godot/override.cfg"
    if override.exists() or override.is_symlink():
        raise ValueError("INSTALL_PROGRAM_NATIVE_OVERRIDE_EXISTS")
    name = "Redwall-Codex-Install-Program-" + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    raw = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n').encode()
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "runtime-override.cfg.txt").write_bytes(raw)
    with override.open("xb") as stream:
        stream.write(raw)
    try:
        execute(preview, out, produced, roles, before, script, bake, name, override, raw)
    finally:
        if not override.is_file() or override.read_bytes() != raw:
            raise ValueError("INSTALL_PROGRAM_NATIVE_OVERRIDE_DRIFT")
        override.unlink()
        (out / "override-restoration.json").write_text(json.dumps({"originally_absent": True, "removed_own_override": True,
            "sha256": hashlib.sha256(raw).hexdigest(), "user_directory_name": name}, indent=2) + "\n")


def execute(preview, out, produced, roles, before, script, bake, name, override, raw):
    (out / "pre-import-sources.json").write_text(json.dumps(before, indent=2) + "\n")
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit", "--log-file", str(out / "engine-import.log")]
    with (out / "import.log").open("x") as log:
        code = subprocess.run(imported, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("INSTALL_PROGRAM_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before != after_import or override.read_bytes() != raw:
        raise ValueError("INSTALL_PROGRAM_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = dict(BASE.closure(script, bake), **before)
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    spec.update(content=str(preview / "mole-worker.ugactor"), content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"], roles=roles,
                user_directory_name=name, production_qualified=False)
    for key in ("content", "basis", "manifest"):
        path = BASE.actual(spec[key]).resolve()
        pins[str(path)] = BASE.digest(path)
    (out / "sources.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "spec.json").write_text(json.dumps(spec, indent=2) + "\n")
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--fixed-fps", "60", "--log-file", str(out / "engine-native.log"),
               "--script", str(script), "--", str(out / "spec.json"), str(out)]
    with (out / "native.log").open("x") as log:
        code = subprocess.run(command, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    after = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in pins}
    (out / "sources-after.json").write_text(json.dumps(after, indent=2) + "\n")
    bad = bool(BASE.DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [imported, command], "native_exit": code, "source_unchanged": pins == after,
        "unexpected_diagnostics": bad, "production_qualified": False, "pre_import_source_unchanged": before == after_import,
        "isolated_override_unchanged": override.read_bytes() == raw, "override_sha256": hashlib.sha256(raw).hexdigest()}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if code or bad or pins != after or override.read_bytes() != raw:
        raise ValueError("INSTALL_PROGRAM_NATIVE_OR_DRIFT")
    report = bounded_json(out / "report.json", 8388608)
    checked = validate_report(report, spec, BASE.wire_timing(spec))
    for row in report["screenshots"]:
        path = Path(row["path"])
        if path.name != str(path) or path.suffix != ".png" or BASE.digest(out / path) != row.get("sha256"):
            raise ValueError("INSTALL_PROGRAM_NATIVE_IMAGE_HASH")
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps({**invocation, **checked}, indent=2))


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    output_refusal(args.out)
    run(args.preview.resolve(), args.out)


if __name__ == "__main__":
    main()
