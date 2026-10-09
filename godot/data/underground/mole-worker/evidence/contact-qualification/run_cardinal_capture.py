#!/usr/bin/env python3
"""Source-pinned native protocol4 replay and exact four-heading tip witnesses; no World permission."""
from fractions import Fraction
import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("install_native_for_cardinals", HERE / "run_install_program_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
H, BASE = R.H, R.BASE
SPEC = importlib.util.spec_from_file_location("cardinal_publication", HERE.parents[1] / "compile_profile_publication.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
YAWS = M.N.YAWS
MATH_MANIFEST_SHA = "553080ddf4150eafdf1cf8a2092a5439c42640f805cc79a06308ba9167617576"
LABEL_COUNTS = {"idle": 31, "idle-ready": 15, "walk": 45, "walk-ready": 15,
                "down-partial": 21, "down-retrace": 21, "down-work": 91, "down-recovery": 101,
                "high-work": 83, "high-recovery": 89, "front-partial": 17, "front-retrace": 17,
                "front-work": 101, "front-recovery": 91, "install-partial": 17, "install-retrace": 17,
                "install-work": 83, "install-recovery": 101}


def math_inputs():
    """Only the exact completed proof/output packet supplies diagnostic native-profile boxes."""
    manifest = HERE / "review-cardinal-math-v1/output-sha256.json"
    if BASE.digest(manifest) != MATH_MANIFEST_SHA:
        raise ValueError("CARDINAL_NATIVE_MATH_MANIFEST")
    pinned = R.bounded_json(manifest, 65536)
    if not 1 <= len(pinned) <= 64:
        raise ValueError("CARDINAL_NATIVE_MATH_CENSUS")
    for name, digest in pinned.items():
        path = (BASE.ROOT / name).resolve()
        if not path.is_relative_to(BASE.ROOT) or BASE.digest(path) != digest:
            raise ValueError("CARDINAL_NATIVE_MATH_SOURCE")
    directory = HERE / "cardinal-proof-v1"
    proof = R.bounded_json(directory / "proof.json", 1048576)
    if proof.get("source_image_sha256") != M.IMAGE_SHA or proof.get("selected_source_roles") != list(M.WORK_NAMES) or \
            proof.get("all_work_roles") is not True or proof.get("self_clearance_proved") is not True or \
            proof.get("certificate_bits_written") != 0 or proof.get("profile_count") != 16 or proof.get("box_count") != 180:
        raise ValueError("CARDINAL_NATIVE_MATH_SCOPE")
    for name, digest in proof["producer_sources"].items():
        if BASE.digest(BASE.ROOT / name) != digest:
            raise ValueError("CARDINAL_NATIVE_MATH_PRODUCER")
    old = R.bound_roles(M.IMAGE_DIR / "mole-worker.ugactor", M.IMAGE_SHA, M.IMAGE_DIR)
    profiles = {"0": old["stand"], "1": old["ground_walk"]}
    contacts = {}
    for name in M.WORK_NAMES:
        record = R.bounded_json(directory / (name + ".json"), M.MAX_REPORT_BYTES)
        if record.get("source_role") != name or record.get("self_proved") is not True or len(record["profiles"]) != 4:
            raise ValueError("CARDINAL_NATIVE_MATH_SCOPE")
        for row in record["profiles"]:
            identity = str(row["id"])
            if identity in profiles or M.row_identity(row["id"]) != (2 + M.WORK_NAMES.index(name), row["yaw"]):
                raise ValueError("CARDINAL_NATIVE_MATH_MAP")
            profiles[identity], contacts[identity] = row["roles"], row["contact"]
    if set(profiles) != {str(index) for index in range(18)}:
        raise ValueError("CARDINAL_NATIVE_MATH_MAP")
    return profiles, contacts, {str((BASE.ROOT / name).resolve()): digest for name, digest in pinned.items()} | {str(manifest): MATH_MANIFEST_SHA}


def expected_driver_poses(table):
    count = R.expected_poses(table)
    if count != 3 * sum(LABEL_COUNTS.values()):
        raise ValueError("CARDINAL_NATIVE_TIMING")
    return 8 * sum(LABEL_COUNTS.values())


def event_refusal(event, table):
    profile, yaw = event.get("profile"), event.get("yaw")
    if type(profile) is not int or not 0 <= profile < 18 or type(yaw) is not int or yaw not in YAWS:
        raise ValueError("CARDINAL_NATIVE_PROFILE")
    role, exact = M.row_identity(profile)
    if exact is not None and exact != yaw or event.get("source_role") != role:
        raise ValueError("CARDINAL_NATIVE_ROLE_HEADING")
    mapped = dict(event, profile=role)
    R.event_refusal(mapped, table)


def _fraction(record):
    if type(record) is not dict or set(record) != {"numerator", "denominator"} or \
            any(type(record[key]) is not int for key in record) or record["denominator"] <= 0 or \
            any(abs(value).bit_length() > 512 for value in record.values()):
        raise ValueError("CARDINAL_NATIVE_RATIONAL")
    return Fraction(record["numerator"], record["denominator"])


def clip_frames(row, elapsed):
    """Independent integer decoding of the documented finite Content interval, including short/loop closing edges."""
    first, count, loop, duration = row
    time = elapsed % duration if loop == 1 else min(elapsed, duration)
    if loop == 2:
        time = elapsed % (2 * duration)
        time = 2 * duration - time if time > duration else time
    final = (count - 2) * 65536
    if time == duration:
        return [first + count - 1, first + count - 1, 0]
    if time >= final:
        return [first + count - 2, first if loop == 1 else first + count - 1,
                (time - final) * 65536 // (duration - final)]
    return [first + time // 65536, first + time // 65536 + 1, time % 65536]


def contact_refusal(samples, contacts, table):
    """Every original native tip witness is enclosed at nine exact shares, with a real forward crossing."""
    if type(samples) is not list or len(samples) != 16 * 9:
        raise ValueError("CARDINAL_NATIVE_CONTACT_CENSUS")
    seen = set()
    for sample in samples:
        profile, share = sample.get("profile"), sample.get("share_q16")
        if type(profile) is not int or not 2 <= profile < 18 or type(share) is not int or \
                share not in range(0, 65537, 8192) or (profile, share) in seen:
            raise ValueError("CARDINAL_NATIVE_CONTACT_IDENTITY")
        seen.add((profile, share))
        contact = contacts[str(profile)]
        if sample.get("vertex") != contact["vertex"] or sample.get("yaw") != contact["yaw"]:
            raise ValueError("CARDINAL_NATIVE_CONTACT_IDENTITY")
        clip = 2 + 3 * ((profile - 2) % 4)
        if sample.get("frames") != clip_frames(table[clip], contact["frame_pair"][0] * 65536 + share):
            raise ValueError("CARDINAL_NATIVE_CONTACT_FRAMES")
        point = sample.get("point_u")
        if type(point) is not list or len(point) != 3 or any(type(v) not in (int, float) or
                not math.isfinite(v) or abs(v) > 2097152 for v in point):
            raise ValueError("CARDINAL_NATIVE_CONTACT_POINT")
        point = [Fraction(v) for v in point]
        ordinal = (profile - 2) // 4
        canonical = M.N.exact_cardinal(point, (-ordinal) % 4)
        first, last = [[_fraction(v) for v in row] for row in contact["exact_ideal_endpoints_m"]]
        errors = [_fraction(v) for v in contact["residual_m"]]
        t = Fraction(share, 65536)
        for axis in range(3):
            expected = ((1 - t) * first[axis] + t * last[axis]) * 1024
            if abs(canonical[axis] - expected) > errors[axis] * 1024:
                raise ValueError("CARDINAL_NATIVE_TIP_OUTSIDE_PROOF")
        patch = contact["patch_u"]
        axis = next(a for a in range(3) if patch[a] == patch[a + 3])
        if share == 0 and canonical[axis] <= patch[axis] or share == 65536 and canonical[axis] >= patch[axis]:
            raise ValueError("CARDINAL_NATIVE_TIP_NO_CROSSING")
    if seen != {(profile, share) for profile in range(2, 18) for share in range(0, 65537, 8192)}:
        raise ValueError("CARDINAL_NATIVE_CONTACT_CENSUS")


def validate_report(report, spec, table, contacts):
    driver_count = expected_driver_poses(table)
    if report.get("production_qualified") is not False or report.get("content_sha256") != M.IMAGE_SHA or \
            report.get("program_version") != 4 or report.get("failures") != [] or \
            report.get("poses") != driver_count + 144 or type(report.get("assertions")) is not int or \
            report["assertions"] < 6 * driver_count or \
            not str(report.get("user_directory", "")).endswith("/" + spec["user_directory_name"]):
        raise ValueError("CARDINAL_NATIVE_SCOPE")
    events, counts = report.get("events"), report.get("phase_counts")
    if type(events) is not list or len(events) != driver_count or type(counts) is not list or len(counts) != 10 or \
            any(type(v) is not int or v <= 0 for v in counts[:9]) or counts[9] != 0:
        raise ValueError("CARDINAL_NATIVE_PHASE_CENSUS")
    labels = {f"{view}-yaw{yaw}-{label}": count for view in ("side", "rts") for yaw in YAWS
              for label, count in LABEL_COUNTS.items()}
    seen = {label: [] for label in labels}
    actual, productive = [0] * 10, set()
    for event in events:
        event_refusal(event, table)
        label, tick = event.get("label"), event.get("tick")
        if label not in labels or type(tick) is not int:
            raise ValueError("CARDINAL_NATIVE_SEQUENCE")
        seen[label].append(tick)
        actual[event["phase"]] += 1
        if event["profile"] >= 2:
            productive.add((event["profile"], event["phase"]))
    if actual != counts or any(seen[label] != list(range(count)) for label, count in labels.items()) or \
            not {(profile, phase) for profile in range(2, 18) for phase in (5, 6, 7)} <= productive:
        raise ValueError("CARDINAL_NATIVE_SEQUENCE")
    contact_refusal(report.get("native_contacts"), contacts, table)
    if type(report.get("screenshots")) is not list or not report["screenshots"]:
        raise ValueError("CARDINAL_NATIVE_IMAGES")
    return {"driver_poses": driver_count, "contact_poses": 144, "assertions": report["assertions"],
            "exact_work_profiles": 16, "headings": list(YAWS), "production_qualified": False}


def run(out):
    R.output_refusal(out)
    out = out.resolve()
    profiles, contacts, proof_pins = math_inputs()
    _, parts, _, _, _, _, _, _ = M.source_program()
    source_points = {str(vertex): parts[1]["geometry"][0]["points"][vertex].tolist() for vertex in (148, 478)}
    script = HERE / "capture_cardinal_program.gd"
    bake = HERE / "high-wall-runtime-sources-v1/bake-spec.json"
    before = H.pre_import_pins(script, bake) | proof_pins
    for path in (Path(__file__), Path(R.__file__), Path(R.R.__file__), *M.IMAGE_DIR.iterdir()):
        if path.is_file():
            before[str(path.resolve())] = BASE.digest(path)
    before |= {str(BASE.ROOT / name): digest for name, digest in M.producer_pins().items()}
    override = BASE.ROOT / "godot/override.cfg"
    if override.exists() or override.is_symlink():
        raise ValueError("CARDINAL_NATIVE_OVERRIDE_EXISTS")
    name = "Redwall-Codex-Cardinal-" + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    raw = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n').encode()
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    budget = R.bounded_json(M.IMAGE_DIR / "compilation.json", 65536)["presentation_budget"]
    spec.update(content=str(M.IMAGE_DIR / "mole-worker.ugactor"), content_sha256=M.IMAGE_SHA,
                reserve_bytes=budget["admitted_peak_bytes"], cardinal_profiles=profiles,
                cardinal_contacts={key: {field: row[field] for field in ("vertex", "yaw", "frame_pair")} for key, row in contacts.items()},
                source_points=source_points, user_directory_name=name, production_qualified=False)
    encoded = (json.dumps(spec, indent=2) + "\n").encode()
    if len(encoded) > 65536:
        raise ValueError("CARDINAL_NATIVE_SPEC_CAPACITY")
    expected_driver_poses(BASE.wire_timing(spec))
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "runtime-override.cfg.txt").write_bytes(raw)
    with override.open("xb") as output:
        output.write(raw)
    try:
        execute(out, before, script, bake, spec, encoded, contacts, override, raw)
    finally:
        if not override.is_file() or override.read_bytes() != raw:
            raise ValueError("CARDINAL_NATIVE_OVERRIDE_DRIFT")
        override.unlink()
        (out / "override-restoration.json").write_text(json.dumps({"originally_absent": True, "removed_own_override": True,
            "sha256": hashlib.sha256(raw).hexdigest(), "user_directory_name": name}, indent=2) + "\n")


def execute(out, before, script, bake, spec, encoded, contacts, override, raw):
    (out / "pre-import-sources.json").write_text(json.dumps(before, indent=2) + "\n")
    imported = ["godot", "--headless", "--path", "godot", "--editor", "--quit", "--log-file", str(out / "engine-import.log")]
    with (out / "import.log").open("x") as log:
        code = subprocess.run(imported, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("CARDINAL_NATIVE_IMPORT")
    after_import = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out / "pre-import-after.json").write_text(json.dumps(after_import, indent=2) + "\n")
    if before != after_import or override.read_bytes() != raw:
        raise ValueError("CARDINAL_NATIVE_IMPORT_DRIFT")
    restored = H.restore_pinned_imports(bake, BASE.ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", BASE.ROOT)
    (out / "import-cache-restoration.json").write_text(json.dumps(restored, indent=2) + "\n")
    pins = dict(BASE.closure(script, bake), **before)
    for key in ("content", "basis", "manifest"):
        path = BASE.actual(spec[key]).resolve()
        pins[str(path)] = BASE.digest(path)
    (out / "sources.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "spec.json").write_bytes(encoded)
    command = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--fixed-fps", "60", "--log-file", str(out / "engine-native.log"),
               "--script", str(script), "--", str(out / "spec.json"), str(out)]
    with (out / "native.log").open("x") as log:
        code = subprocess.run(command, cwd=BASE.ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900).returncode
    after = {path: BASE.digest(Path(path)) if Path(path).is_file() else None for path in pins}
    (out / "sources-after.json").write_text(json.dumps(after, indent=2) + "\n")
    bad = bool(BASE.DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [imported, command], "native_exit": code, "source_unchanged": pins == after,
                  "unexpected_diagnostics": bad, "production_qualified": False,
                  "pre_import_source_unchanged": before == after_import, "isolated_override_unchanged": override.read_bytes() == raw}
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if code or bad or pins != after or override.read_bytes() != raw:
        raise ValueError("CARDINAL_NATIVE_OR_DRIFT")
    report = R.bounded_json(out / "report.json", 12582912)
    checked = validate_report(report, spec, BASE.wire_timing(spec), contacts)
    for row in report["screenshots"]:
        path = Path(row["path"])
        if path.name != str(path) or path.suffix != ".png" or BASE.digest(out / path) != row.get("sha256"):
            raise ValueError("CARDINAL_NATIVE_IMAGE_HASH")
    (out / "verification.json").write_text(json.dumps(checked, indent=2) + "\n")
    print(json.dumps({**invocation, **checked}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    run(parser.parse_args().out)
