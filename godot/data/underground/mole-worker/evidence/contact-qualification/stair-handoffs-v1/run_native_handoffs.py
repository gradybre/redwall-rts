#!/usr/bin/env python3
"""Create-only exact-source native stair episode; no runtime support, pace or profile publication."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import subprocess

HERE = Path(__file__).resolve().parent
P = HERE.parent
IMPORT = importlib.util.spec_from_file_location("handoff_native_import", P / "run_high_wall.py")
H = importlib.util.module_from_spec(IMPORT)
IMPORT.loader.exec_module(H)
BASE, ROOT = H.BASE, H.BASE.ROOT
ONE = 65536
ORDER = ("approach", "descent", "turn", "ascent", "retreat")
VIEWS = ("side", "opposite", "rts")
READY = "393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462"
REVIEW = {
    "source-sha256.json": "c9d5a97579bb0b5867082ff2b96db707532cd8d62cb6c4472347c24680f1b925",
    "output-sha256.json": "8269f80a2a4fc7020ad8a72ead6f0b8f89250f2c2fc020bd89b9031893bf57c3",
    "history-sha256.json": "5cf4d070e3dc6d87bee27ba3191e220b6bc027995068b05d51961e5797f5d54d",
    "inherited-sha256.json": "5588390a4d02e1fec3705d86b4cbcf0721dfc1192a570d91942d5219a33bcf77",
}
BAKE_SHA = "063417e6f215fc80d820237c2af43ec162c0f0d6a18420c5cd7c20a28ea465c9"
CHANGE_SHA = "16ba895b928a244a80aa3597fc492175386ad961e0018d7a98cf0728d04d3a96"
CONSUMERS = ("scripts/core/underground_profiles.gd", "scripts/core/underground_work_face.gd",
    "scripts/core/underground_connector_contacts.gd", "scripts/core/underground_routes.gd",
    "scripts/core/underground_world_routes.gd", "demo/cast/underground_actor.gd",
    "demo/cast/underground_actor_content.gd", "data/underground/mole-worker/mole_profile_driver.gd")


def require(condition, code):
    if not condition:
        raise ValueError(code)


def digest(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 3 * 1024**3,
            "HANDOFF_NATIVE_INPUT_FILE")
    hashing = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def bounded_json(path, maximum=1048576):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum,
            "HANDOFF_NATIVE_METADATA_CAPACITY")
    return json.loads(path.read_text())


def repository_file(name):
    require(type(name) is str and not Path(name).is_absolute() and ".." not in Path(name).parts,
            "HANDOFF_NATIVE_INPUT_PATH")
    path = ROOT / name
    require(path.resolve().is_relative_to(ROOT), "HANDOFF_NATIVE_INPUT_PATH")
    return path


def reviewed_pins():
    """Every accepted source/output/history locator stays exact; this harness cannot amend offline evidence."""
    pins = {}
    for name, expected in REVIEW.items():
        path = HERE / "review-v1" / name
        require(digest(path) == expected, "HANDOFF_NATIVE_REVIEW_MANIFEST")
        pins[str(path)] = expected
        rows = bounded_json(path)
        require(type(rows) is dict and 0 < len(rows) <= 512, "HANDOFF_NATIVE_REVIEW_CENSUS")
        for relative, source_sha in rows.items():
            source = repository_file(relative)
            require(digest(source) == source_sha, "HANDOFF_NATIVE_REVIEW_SOURCE:" + relative)
            pins[str(source)] = source_sha
    return pins


def runtime_bake():
    """A separately pinned finite 11-row update retains every original raw asset/import and every recursive guard."""
    bake = HERE / "native-runtime-v1/bake-spec.json"
    changes = HERE / "native-runtime-v1/changes.json"
    require(digest(bake) == BAKE_SHA and digest(changes) == CHANGE_SHA, "HANDOFF_NATIVE_RUNTIME_PINS")
    record = bounded_json(changes)
    old = repository_file(record["original_bake"])
    require(digest(old) == record["original_sha256"], "HANDOFF_NATIVE_RUNTIME_ORIGINAL")
    expected = bounded_json(old)
    seen = set()
    for change in record["changes"]:
        name = change["path"]
        require(name not in seen and name.endswith(".gd") and
                name.startswith(("res://scripts/core/", "res://demo/cast/")), "HANDOFF_NATIVE_RUNTIME_MAP")
        seen.add(name)
        rows = [row for row in expected["sources"] if row["path"] == name]
        require(len(rows) == 1 and rows[0]["sha256"] == change["historical_sha256"] and
                digest(BASE.actual(name)) == change["current_sha256"], "HANDOFF_NATIVE_RUNTIME_DRIFT")
        rows[0]["sha256"] = change["current_sha256"]
    require(len(seen) == 11 and expected == bounded_json(bake), "HANDOFF_NATIVE_RUNTIME_EXACT_DELTA")
    return bake


def rotate(point, quarter):
    x, y, z = point
    return ([x, y, z], [z, y, -x], [-x, y, -z], [-z, y, x])[quarter]


def phase_state(program, time):
    count = program["intervals"]
    require(type(time) is int and 0 <= time <= count * ONE, "HANDOFF_NATIVE_PHASE")
    first = min(time // ONE, count)
    last, share = min(first + 1, count), time % ONE if first < count else 0
    value = [-(-(program["keys"][first][axis] * (ONE - share) +
                 program["keys"][last][axis] * share) // ONE) for axis in range(4)]
    if program["root_frame"] == "local_then_fixed_quarter_turn":
        value[:3] = [v + o for v, o in zip(rotate(value[:3], program["quarter_turn"]), program["origin_u"])]
    return value


def source_program(name, image, compilation, keys, clip, frame, quarter=0, origin=(0, 0, 0)):
    require(compilation.get("production_qualified") is False and digest(image) == compilation["content_sha256"],
            "HANDOFF_NATIVE_IMAGE_IDENTITY")
    count = len(keys) - 1
    require(count == (270 if name == "turn" else 90) and all(type(row) is list and len(row) == 5 and
            all(type(v) is int for v in row) and all(abs(v) <= 8192 for v in row[:3]) and
            0 <= row[3] <= 32768 and 1 <= row[4] <= 3 for row in keys), "HANDOFF_NATIVE_KEYS")
    table = BASE.wire_timing({"content": str(image), "content_sha256": compilation["content_sha256"]})
    require(table[clip][1:] == (count + 1, 0, count * ONE), "HANDOFF_NATIVE_TIMING")
    shots = sorted(set(range(0, 2 * count + 1, 60)) | ({316, 318, 462, 466, 468} if name == "turn" else set()))
    program = dict(name=name, content=str(image), content_sha256=compilation["content_sha256"],
        reserve_bytes=compilation["presentation_budget"]["admitted_peak_bytes"], clip=clip, first_frame=table[clip][0],
        intervals=count, root_frame=frame, quarter_turn=quarter, origin_u=list(origin), keys=keys,
        endpoint_pose_sha256=READY, shot_ticks=shots)
    program["entry_root_u"] = phase_state(program, 0)[:3]
    program["exit_root_u"] = phase_state(program, count * ONE)[:3]
    return program


def build_spec(name):
    """Project only already reviewed source fields; no source motion or support geometry is authored here."""
    pins = reviewed_pins()
    preview = HERE / "candidate-6/result"
    candidate, compilation = (bounded_json(preview / key) for key in ("candidate.json", "compilation.json"))
    programs = {}
    for clip, recipe in enumerate(candidate["attempts"]):
        keys = [[*r["root_u"], r["yaw"], r["planted_mask"]] for r in recipe["keys"]]
        programs[recipe["name"]] = source_program(recipe["name"], preview / "mole-worker.ugactor", compilation,
                                                 keys, clip, "fixed_program_frame")
    inputs = bounded_json(P / "stair-program-v1/source-inputs.json")
    for item in inputs["programs"]:
        files = {key: repository_file(value) for key, value in item["paths"].items()}
        require(all(digest(path) == item["sha256"][key] for key, path in files.items()), "HANDOFF_NATIVE_OLD_SOURCE")
        recipe = bounded_json(files["candidate"])["attempts"][0]
        placement = bounded_json(files["fixture"])["segments"][0]
        yaw = placement["quarter_turn"] * 16384
        keys = [[*r, yaw, mask] for r, mask in zip(recipe["root_u"], recipe["planted_mask"])]
        programs[item["direction"]] = source_program(item["direction"], files["image"], bounded_json(files["compilation"]),
            keys, 0, "local_then_fixed_quarter_turn", placement["quarter_turn"], placement["origin_u"])
    spec = bounded_json(P.parent / "grip-native-v2/spec.json", 65536)
    spec.update(content=str(preview / "mole-worker.ugactor"), content_sha256=compilation["content_sha256"],
        reserve_bytes=compilation["presentation_budget"]["admitted_peak_bytes"], programs=[programs[k] for k in ORDER],
        solids_u=bounded_json(P / "stair-sequence-prefix-v1/descent-fixture.json")["solids_u"],
        program_content_sha256=[programs[k]["content_sha256"] for k in ORDER],
        user_directory_name=name, production_qualified=False)
    require(len(spec["solids_u"]) == 22 and len(json.dumps(spec).encode()) <= 65536, "HANDOFF_NATIVE_SPEC_CAPACITY")
    for key in ("basis", "manifest"):
        path = BASE.actual(spec[key]).resolve()
        require(digest(path) == spec[key + "_sha256"], "HANDOFF_NATIVE_BASIS_OR_ASSET")
        pins[str(path)] = digest(path)
    pins[str(P.parent / "grip-native-v2/spec.json")] = digest(P.parent / "grip-native-v2/spec.json")
    for relative in CONSUMERS:
        path = ROOT / "godot" / relative
        pins[str(path)] = digest(path)
    return spec, pins


def image_frames(program):
    """Bounded binary32 source rows independently predict every native palette readback hash."""
    path = Path(program["content"])
    require(digest(path) == program["content_sha256"] and path.stat().st_size <= 4194304 + 8192,
            "HANDOFF_NATIVE_ORACLE_IMAGE")
    raw = path.read_bytes()
    _, _, parts, clips, frames, stride = struct.unpack_from("<6I", raw, 8)
    require(parts == 2 and stride == 300 and 1 <= clips <= 3 and 91 <= frames <= 453,
            "HANDOFF_NATIVE_ORACLE_CENSUS")
    at = 184 + parts * 72 + clips * 48
    values = struct.unpack_from("<" + "f" * (frames * (stride + 1)), raw, at)
    require(all(math.isfinite(v) for v in values), "HANDOFF_NATIVE_ORACLE_FINITE")
    return [values[i * stride:(i + 1) * stride] + (values[frames * stride + i],) for i in range(frames)]


def expected_events(spec):
    images, events = {}, []
    for view in VIEWS:
        for program in spec["programs"]:
            key = program["content_sha256"]
            if key not in images:
                images[key] = image_frames(program)
            for tick in range(2 * program["intervals"] + 1):
                i = min(tick // 2, program["intervals"])
                j = min(i + 1, program["intervals"])
                share = (tick % 2) * 32768 if i < program["intervals"] else 0
                first, last = program["first_frame"] + i, program["first_frame"] + j
                t = share / ONE
                sampled = [a * (1.0 - t) + b * t for a, b in zip(images[key][first], images[key][last])]
                # Actor's two identical source samples still pass through the explicit final blend.
                sampled = [value * 0.0 + value * 1.0 for value in sampled]
                state = phase_state(program, tick * 32768)
                events.append(dict(view=view, program=program["name"], half_tick=tick, root_u=state[:3], yaw=state[3],
                    frames=[first, last, share], palette_sha256=hashlib.sha256(struct.pack("<301f", *sampled)).hexdigest()))
    return events


def expected_joins(spec):
    joins = []
    for view in VIEWS:
        for prior, following in zip(spec["programs"], spec["programs"][1:]):
            state = phase_state(prior, prior["intervals"] * ONE)
            require(state == phase_state(following, 0), "HANDOFF_NATIVE_SOURCE_JOIN")
            joins.append(dict(view=view, **{"from": prior["name"], "to": following["name"]},
                              root_u=state[:3], yaw=state[3], palette_sha256=READY))
    return joins


def expected_shots(spec):
    return [(f"{view}-{p['name']}-{tick:03d}.png", p["clip"], tick)
            for view in VIEWS for p in spec["programs"] for tick in p["shot_ticks"]]


def validate_report(report, spec):
    require(report.get("scope") == "source_only_stair_handoffs_gl" and report.get("production_qualified") is False and
            all(report.get(k) is False for k in ("gameplay_rate_adopted", "actual_world_playback", "metal_qualified")) and
            report.get("renderer") == "gl_compatibility" and report.get("failures") == [] and
            str(report.get("user_directory", "")).endswith("/" + spec["user_directory_name"]), "HANDOFF_NATIVE_SCOPE")
    events = expected_events(spec)
    require(len(events) == 3795 and report.get("poses") == len(events) and type(report.get("assertions")) is int and
            report["assertions"] >= 32 * len(events) and report.get("bone_checks") == 24 * len(events) and
            report.get("world_checks") == 2 * len(events) and report.get("fixture_parts") == 22, "HANDOFF_NATIVE_CENSUS")
    require(report.get("program_content_sha256") == spec["program_content_sha256"] and
            report.get("basis_sha256") == spec["basis_sha256"], "HANDOFF_NATIVE_SOURCE_IDENTITY")
    require(report.get("events") == events, "HANDOFF_NATIVE_EXACT_EVENTS")
    require(report.get("joins") == expected_joins(spec), "HANDOFF_NATIVE_EXACT_JOINS")
    shots = report.get("screenshots")
    require(type(shots) is list and [(r.get("path"), r.get("clip"), r.get("half_tick")) for r in shots] ==
            expected_shots(spec), "HANDOFF_NATIVE_IMAGES")
    return dict(poses=len(events), joins=len(report["joins"]), screenshots=len(shots),
        bone_checks=report["bone_checks"], world_checks=report["world_checks"], assertions=report["assertions"],
        production_qualified=False, scope=report["scope"])


def output_refusal(out):
    require(not out.exists() and not out.is_symlink(), "HANDOFF_NATIVE_OUTPUT_EXISTS")


def write_json(path, value, compact=False):
    with path.open("x") as stream:
        json.dump(value, stream, indent=None if compact else 2)
        stream.write("\n")


def snapshot(pins):
    return {name: digest(Path(name)) if Path(name).is_file() else None for name in pins}


def run_command(command, log_path, timeout):
    with log_path.open("x") as log:
        code = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout).returncode
    return code, bool(BASE.DIAGNOSTIC.search(log_path.read_text()))


def execute(out, spec, before, script, bake, override, raw, head):
    write_json(out / "pre-import-sources.json", before)
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit", "--log-file", str(out / "engine-import.log")]
    write_json(out / "import-command.json", imported)
    code, bad = run_command(imported, out / "import.log", 600)
    after_import = snapshot(before)
    write_json(out / "pre-import-after.json", after_import)
    write_json(out / "import-result.json", dict(exit=code, unexpected_diagnostics=bad, source_unchanged=before == after_import))
    require(not code and not bad and before == after_import and override.read_bytes() == raw, "HANDOFF_NATIVE_IMPORT")
    restored = H.restore_pinned_imports(bake, ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", ROOT)
    write_json(out / "import-cache-restoration.json", restored)
    pins = dict(BASE.closure(script, bake), **before)
    write_json(out / "spec.json", spec, compact=True)
    pins[str(out / "spec.json")] = digest(out / "spec.json")
    write_json(out / "sources.json", pins)
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
        "--fixed-fps", "60", "--quit-after", "12000", "--log-file", str(out / "engine-native.log"), "--script", str(script),
        "--", str(out / "spec.json"), str(out)]
    write_json(out / "native-command.json", command)
    code, bad = run_command(command, out / "native.log", 900)
    after = snapshot(pins)
    write_json(out / "sources-after.json", after)
    current_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    invocation = dict(commands=[imported, command], native_exit=code, unexpected_diagnostics=bad,
        source_unchanged=pins == after, pre_import_source_unchanged=before == after_import,
        head_before=head, head_after=current_head, override_unchanged=override.read_bytes() == raw,
        production_qualified=False)
    write_json(out / "invocation.json", invocation)
    require(not code and not bad and pins == after and head == current_head and override.read_bytes() == raw,
            "HANDOFF_NATIVE_EXECUTION_OR_DRIFT")
    report = bounded_json(out / "report.json", 8388608)
    checked = validate_report(report, spec)
    for row in report["screenshots"]:
        path = Path(row["path"])
        require(path.name == str(path) and path.suffix == ".png" and digest(out / path) == row.get("sha256"),
                "HANDOFF_NATIVE_IMAGE_HASH")
    write_json(out / "verification.json", checked)
    print(json.dumps(checked, indent=2))


def run(out):
    output_refusal(out)
    out = out.resolve()
    name = "Redwall-Codex-Handoffs-" + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    spec, proof_pins = build_spec(name)
    bake, script = runtime_bake(), HERE / "capture_stair_handoffs.gd"
    before = dict(proof_pins, **H.pre_import_pins(script, bake))
    for path in (Path(__file__), HERE / "test_native_handoffs.py", HERE / "native-runtime-v1/changes.json", ROOT / "godot/project.godot"):
        before[str(path)] = digest(path)
    override = ROOT / "godot/override.cfg"
    require(not override.exists() and not override.is_symlink(), "HANDOFF_NATIVE_OVERRIDE_EXISTS")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    raw = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n').encode()
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "runtime-override.cfg.txt").write_bytes(raw)
    with override.open("xb") as stream:
        stream.write(raw)
    try:
        execute(out, spec, before, script, bake, override, raw, head)
    finally:
        require(override.is_file() and override.read_bytes() == raw, "HANDOFF_NATIVE_OVERRIDE_DRIFT")
        override.unlink()
        write_json(out / "override-restoration.json", dict(originally_absent=True, removed_own_override=True,
            sha256=hashlib.sha256(raw).hexdigest(), user_directory_name=name))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    run(parser.parse_args().out)
