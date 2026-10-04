#!/usr/bin/env python3
"""Replay the actual emitted mole catalog on the certified native backend; no paid World permission."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("accepted_cardinal_native_for_publication", HERE / "run_cardinal_capture.py")
N = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(N)
BASE, H, R, M = N.BASE, N.H, N.R, N.M
PUBLICATION = HERE.parents[1] / "profile-publication-v1"
SOURCE_MANIFEST_SHA = "be98241cfb1bf6e62a3b62fb94aa2e02eb61b799630fe30297e3e51790003f91"
OUTPUT_MANIFEST_SHA = "dd609eb6b0ea1acf4def72dda9c2723765ec00d8bd1b4b6dc79ddac69ce9f398"
WIRE_SHA = "b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac"
BASIS_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
CONTACT_MANIFEST_SHA = "d106139d90316fe46521174a45289cae1020b989e97482aa2c48656394967c2b"
CONTACT_SPEC_SHA = "fb3c06f777c83e0658bf44079a411167ee223e254add1d96f702887f3785455e"
RUNTIME_BAKE_SHA = "a3e6e55ed0ea158606ed649983920d8f0198d020c70aff5cc519c06d16c45674"
RUNTIME_CHANGES_SHA = "107347c93a39c819f4335880d36ab2cbc91b90820677583fc32b4414bdc8b271"


def runtime_bake_spec():
    """Pin the separately recorded current execution closure; every row still passes existing pre/post checks."""
    directory = HERE / "published-native-runtime-sources-v1"
    bake, changes = directory / "bake-spec.json", directory / "changes.json"
    if BASE.digest(bake) != RUNTIME_BAKE_SHA or BASE.digest(changes) != RUNTIME_CHANGES_SHA:
        raise ValueError("PUBLISHED_NATIVE_RUNTIME_MANIFEST")
    return bake, {str(bake): RUNTIME_BAKE_SHA, str(changes): RUNTIME_CHANGES_SHA}


def contact_source_points():
    """Read only two original vertex facts from exact accepted native input, never waive current source checks."""
    manifest = HERE / "review-cardinal-native-v2/output-sha256.json"
    source = HERE / "native-cardinal-program-v5/spec.json"
    if BASE.digest(manifest) != CONTACT_MANIFEST_SHA:
        raise ValueError("PUBLISHED_NATIVE_CONTACT_MANIFEST")
    records = R.bounded_json(manifest, 65536)
    relative = str(source.relative_to(BASE.ROOT))
    if type(records) is not dict or len(records) != 325 or records.get(relative) != CONTACT_SPEC_SHA:
        raise ValueError("PUBLISHED_NATIVE_CONTACT_MANIFEST_RECORD")
    if BASE.digest(source) != CONTACT_SPEC_SHA:
        raise ValueError("PUBLISHED_NATIVE_CONTACT_SPEC")
    spec = R.bounded_json(source, 65536)
    if type(spec) is not dict or spec.get("content_sha256") != M.IMAGE_SHA:
        raise ValueError("PUBLISHED_NATIVE_CONTACT_SOURCE")
    points = spec.get("source_points")
    if type(points) is not dict or set(points) != {"148", "478"}:
        raise ValueError("PUBLISHED_NATIVE_CONTACT_VERTICES")
    for point in points.values():
        if type(point) is not list or len(point) != 3 or any(type(value) not in (int, float)
                or not math.isfinite(value) or abs(value) > 1024 for value in point):
            raise ValueError("PUBLISHED_NATIVE_CONTACT_POINT")
    return points, {str(manifest): CONTACT_MANIFEST_SHA, str(source): CONTACT_SPEC_SHA}


def publication_pins():
    """Only the exact independently accepted source/artifact packet may supply the native catalog."""
    pins = {}
    for name, digest, count in (("source-sha256.json", SOURCE_MANIFEST_SHA, 5),
                                ("output-sha256.json", OUTPUT_MANIFEST_SHA, 33)):
        path = HERE / "review-profile-publication-v1" / name
        if BASE.digest(path) != digest:
            raise ValueError("PUBLISHED_NATIVE_REVIEW_PACKET")
        records = R.bounded_json(path, 65536)
        if type(records) is not dict or len(records) != count:
            raise ValueError("PUBLISHED_NATIVE_REVIEW_CENSUS")
        for relative, expected in records.items():
            actual = (BASE.ROOT / relative).resolve()
            if not actual.is_relative_to(BASE.ROOT) or BASE.digest(actual) != expected:
                raise ValueError("PUBLISHED_NATIVE_SOURCE_DRIFT")
            pins[str(actual)] = expected
        pins[str(path)] = digest
    wire = PUBLICATION / "mole-worker.ugprof"
    if wire.stat().st_size != 7268 or BASE.digest(wire) != WIRE_SHA:
        raise ValueError("PUBLISHED_NATIVE_WIRE")
    return pins


def published_refusal(report):
    """Require actual artifact/map/backend observations in addition to every inherited finite-pose check."""
    row = report.get("published_catalog")
    if type(row) is not dict or row.get("wire_sha256") != WIRE_SHA or row.get("actor_sha256") != M.IMAGE_SHA \
            or row.get("basis_sha256") != BASIS_SHA or type(row.get("content_revision")) is not int \
            or row["content_revision"] != 1 or type(row.get("profile_count")) is not int or row["profile_count"] != 18:
        raise ValueError("PUBLISHED_NATIVE_CATALOG_IDENTITY")
    pins, flags = row.get("pins"), row.get("certificate_flags")
    if type(pins) is not list or any(type(value) is not int for value in pins) or \
            pins != [value for index in range(18) for value in (index, 1, 1)] or \
            type(flags) is not list or any(type(value) is not int for value in flags) or flags != [15] * 18:
        raise ValueError("PUBLISHED_NATIVE_CATALOG_MAP")
    identity = report.get("actual_species_stage_rig")
    if row.get("rendering_driver") != "opengl3" or row.get("rendering_method") != "gl_compatibility" or \
            row.get("world_activation_qualified") is not False or type(identity) is not list or \
            any(type(value) is not int for value in identity) or identity != [6, 0, 6]:
        raise ValueError("PUBLISHED_NATIVE_BINDING_SCOPE")
    return {"published_wire_sha256": WIRE_SHA, "actual_catalog_profiles": 18,
            "source_geometry_qualified": True, "world_activation_qualified": False}


def validate_report(report, spec, table, contacts):
    """Never replace the accepted event/contact oracle with the new catalog metadata check."""
    checked = N.validate_report(report, spec, table, contacts)
    return {**checked, **published_refusal(report)}


def run(out):
    """Use inherited create-only import/native execution and exact pre/post source closure with new script pins."""
    R.output_refusal(out)
    out = out.resolve()
    published = publication_pins()
    profiles, contacts, proof_pins = N.math_inputs()
    source_points, contact_pins = contact_source_points()
    script = HERE / "capture_published_mole.gd"
    bake, runtime_pins = runtime_bake_spec()
    before = H.pre_import_pins(script, bake) | proof_pins | published | contact_pins | runtime_pins
    for path in (Path(__file__), Path(N.__file__), Path(R.__file__), Path(R.R.__file__), *M.IMAGE_DIR.iterdir()):
        if path.is_file():
            before[str(path.resolve())] = BASE.digest(path)
    before |= {str(BASE.ROOT / name): digest for name, digest in M.producer_pins().items()}
    override = BASE.ROOT / "godot/override.cfg"
    if override.exists() or override.is_symlink():
        raise ValueError("PUBLISHED_NATIVE_OVERRIDE_EXISTS")
    name = "Redwall-Codex-Published-Mole-" + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    raw = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n').encode()
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    budget = R.bounded_json(M.IMAGE_DIR / "compilation.json", 65536)["presentation_budget"]
    spec.update(content=str(M.IMAGE_DIR / "mole-worker.ugactor"), content_sha256=M.IMAGE_SHA,
                reserve_bytes=budget["admitted_peak_bytes"], cardinal_profiles=profiles,
                cardinal_contacts={key: {field: row[field] for field in ("vertex", "yaw", "frame_pair")}
                                   for key, row in contacts.items()}, source_points=source_points,
                user_directory_name=name, production_qualified=False)
    encoded = (json.dumps(spec, indent=2) + "\n").encode()
    if len(encoded) > 65536:
        raise ValueError("PUBLISHED_NATIVE_SPEC_CAPACITY")
    N.expected_driver_poses(BASE.wire_timing(spec))
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "runtime-override.cfg.txt").write_bytes(raw)
    with override.open("xb") as output:
        output.write(raw)
    try:
        N.execute(out, before, script, bake, spec, encoded, contacts, override, raw)
        report = R.bounded_json(out / "report.json", 12582912)
        checked = validate_report(report, spec, BASE.wire_timing(spec), contacts)
        (out / "publication-verification.json").write_text(json.dumps(checked, indent=2) + "\n")
        print(json.dumps(checked, indent=2))
    finally:
        if not override.is_file() or override.read_bytes() != raw:
            raise ValueError("PUBLISHED_NATIVE_OVERRIDE_DRIFT")
        override.unlink()
        (out / "override-restoration.json").write_text(json.dumps({"originally_absent": True,
            "removed_own_override": True, "sha256": hashlib.sha256(raw).hexdigest(), "user_directory_name": name}, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    run(parser.parse_args().out)
