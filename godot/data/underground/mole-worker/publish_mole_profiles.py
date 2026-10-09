#!/usr/bin/env python3
"""Publish the exact reviewed mole source geometry; this never grants a route, WIP, support or work credit."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import struct

HERE = Path(__file__).resolve().parent
P = HERE / "evidence/contact-qualification"
SPEC = importlib.util.spec_from_file_location("native_cardinal_publication", P / "run_cardinal_capture.py")
N = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(N)
M, ROOT = N.M, N.BASE.ROOT
SPEC = importlib.util.spec_from_file_location("ground_source_publication", P / "close_profile_source_gates.py")
G = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G)
SOURCE_ADAPTER = P / "source-gates-v3/renew_source_closure.py"
SOURCE_ADAPTER_SHA = "1dcdbe1ea5e1a4ae1d097897cfd81dd0c7c821eae05ee78b6140cd2aa6b82272"
CURRENT_COMMIT = "b518ca1f824903b0a40658a04660064f50ab7509"
CURRENT_GROUND_SHA = "d2d96c450733c2af3c98ccd7cec9d868acce03f8b9d7df55a1032c8b2298e8c3"
CURRENT_GROUND_PATH = P / "source-gates-v3/final-consumers/ground-closure.json"
REVIEW_PINS = {
    "review-cardinal-math-v1/source-sha256.json": "16315e6df8b5fe54224d33e5667e75aa85b219171b6af3b481a283b8fb1e3b22",
    "review-cardinal-math-v1/output-sha256.json": "553080ddf4150eafdf1cf8a2092a5439c42640f805cc79a06308ba9167617576",
    "review-cardinal-native-v2/source-sha256.json": "9e1a807275abaeca84e9d5f46af443945b75c0839344d2c449f1b99398ea6c3f",
    "review-cardinal-native-v2/output-sha256.json": "d106139d90316fe46521174a45289cae1020b989e97482aa2c48656394967c2b",
    "review-profile-source-gates-v1/source-sha256.json": "f4e69a81147236ae4daf660ded5ee4fb1536b8c2c15df6b3f92278a32cd34985",
    "review-profile-source-gates-v1/output-sha256.json": "b417b9744ff3549c0e69faf2b27dbed61ecdef1b599627cfa1bdb48159ef37b0",
}
MAX_JSON = 16 * 1024 * 1024
MAX_REVIEW_FILES = 512
ROW_COUNT, BOX_COUNT, SOURCE_COUNT = 18, 194, 1
WIRE_BYTES, PAIRED_BANK_BYTES = 7268, 14520
REVISION, CERTIFICATES = 1, 15
ROOT_BOUNDS = [0, -32256, 0, 262144, 16896, 262144]


def require(value, code):
    if not value:
        raise ValueError(code)


def digest(path):
    return N.BASE.digest(path)


def bounded_json(path, expected=None):
    require(path.is_file() and path.stat().st_size <= MAX_JSON, "MOLE_PUBLICATION_JSON_CAPACITY")
    raw = path.read_bytes()
    require(expected is None or hashlib.sha256(raw).hexdigest() == expected, "MOLE_PUBLICATION_PROOF_HASH")
    return json.loads(raw)


def reviewed_files():
    """A matching true flag is insufficient; every accepted source/output byte remains an exact prerequisite."""
    result = {}
    for name, expected in REVIEW_PINS.items():
        manifest = P / name
        rows = bounded_json(manifest, expected)
        require(type(rows) is dict and 0 < len(rows) <= MAX_REVIEW_FILES, "MOLE_PUBLICATION_REVIEW_CENSUS")
        result[str(manifest.relative_to(ROOT))] = expected
        for item, pinned in rows.items():
            path = (ROOT / item).resolve()
            require(path.is_relative_to(ROOT) and re.fullmatch(r"[0-9a-f]{64}", pinned) is not None and
                    path.is_file() and digest(path) == pinned, "MOLE_PUBLICATION_REVIEW_DRIFT")
            result[str(path.relative_to(ROOT))] = pinned
    return result


def current_consumer_refusal(record, blobs):
    """Current immutable sources get explicit pins; historical compatibility is never a drift exemption."""
    require(record.get("consumer_source_commit") == CURRENT_COMMIT and set(blobs) == set(G.CONSUMERS) and
            record.get("consumer_sources") == {name: hashlib.sha256(raw).hexdigest() for name, raw in blobs.items()},
            "MOLE_PUBLICATION_CONSUMER_DRIFT")
    require(record.get("actor_image_sha256") == M.IMAGE_SHA and record.get("world_basis_sha256") == M.BASIS_SHA and
            record.get("world_root_bounds_u") == ROOT_BOUNDS and record.get("all_yaw_handoff_proof_reused") is True and
            record.get("ground_clips_source_timing_equal") is True and record.get("handoff_checks") == 9730636 and
            record.get("handoff_simplices") == 155 and record.get("certificate_bits_written") == 0,
            "MOLE_PUBLICATION_GROUND_SCOPE")


def native_refusal(spec, report, invocation, contacts):
    """Rerun the accepted exact phase/contact validator over the pinned actual native witness."""
    require(invocation.get("native_exit") == 0 and invocation.get("unexpected_diagnostics") is False and
            invocation.get("source_unchanged") is True and invocation.get("pre_import_source_unchanged") is True and
            invocation.get("isolated_override_unchanged") is True, "MOLE_PUBLICATION_NATIVE_EXECUTION")
    require(report.get("actual_species_stage_rig") == [6, 0, 6] and spec.get("content_sha256") == M.IMAGE_SHA,
            "MOLE_PUBLICATION_ACTUAL_IDENTITY")
    return N.validate_report(report, spec, N.BASE.wire_timing(spec), contacts)


def reconstructed_source():
    """Use the separately reviewed exact historical locators; current consumer blobs remain independent."""
    require(digest(SOURCE_ADAPTER) == SOURCE_ADAPTER_SHA, "MOLE_PUBLICATION_ADAPTER_DRIFT")
    spec = importlib.util.spec_from_file_location("reviewed_publication_source_adapter", SOURCE_ADAPTER)
    adapter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adapter)
    with adapter.same_source_inputs(M.I.M.W):
        return M.source_program()


def inputs():
    """Reconstruct genuine meshes/rig/source, require all accepted continuous/numerical/native evidence, then assemble."""
    pins = reviewed_files()
    profiles, contacts, _ = N.math_inputs()
    cases, parts, rig, topology, roots, count, historical, _ = reconstructed_source()
    require(roots == ROOT_BOUNDS and count == 537 and [sum(map(len, x)) for x in topology] == [10209, 1150],
            "MOLE_PUBLICATION_SOURCE_CENSUS")
    ground_path = CURRENT_GROUND_PATH
    ground = bounded_json(ground_path, CURRENT_GROUND_SHA)
    blobs = G.source_blobs(CURRENT_COMMIT)
    current_consumer_refusal(ground, blobs)
    require(profiles["0"] == ground["roles"]["0"] == profiles["1"] == ground["roles"]["1"],
            "MOLE_PUBLICATION_GROUND_ROLE_DRIFT")
    for group in (ground["producer_sources"], ground["input_sources"]):
        for name, expected in group.items():
            require(digest(ROOT / name) == expected, "MOLE_PUBLICATION_SOURCE_DRIFT")
            pins[name] = expected
    native = P / "native-cardinal-program-v5"
    observed = native_refusal(bounded_json(native / "spec.json"), bounded_json(native / "report.json"),
                              bounded_json(native / "invocation.json"), contacts)
    require(observed["driver_poses"] == 7648 and observed["contact_poses"] == 144,
            "MOLE_PUBLICATION_NATIVE_CENSUS")
    pins[str(ground_path.relative_to(ROOT))] = CURRENT_GROUND_SHA
    pins[str(SOURCE_ADAPTER.relative_to(ROOT))] = SOURCE_ADAPTER_SHA
    pins[str(Path(__file__).relative_to(ROOT))] = digest(Path(__file__))
    return profiles, ground["consumer_sources"], pins, {"original_source_files": count, "historical_source": historical,
        "continuous_work_checks": 1324737, "continuous_ground_checks": 9730636, "native": observed}


def checked_box(bounds, role):
    require(type(bounds) is list and len(bounds) == 6 and all(type(x) is int and -(1 << 31) <= x < (1 << 31) for x in bounds),
            "MOLE_PUBLICATION_BOX_INTEGER")
    sizes = [bounds[a + 3] - bounds[a] for a in range(3)]
    if role == 5:
        valid = sizes == [0, 0, 0]
    elif role == 6:
        valid = sizes.count(0) == 1 and sum(x > 0 for x in sizes) == 2
    else:
        valid = all(x > 0 for x in sizes)
    require(valid, "MOLE_PUBLICATION_BOX_SHAPE")
    return struct.pack("<7i", *bounds, role)


def encode_wire(profiles):
    """Serialization only: callers must first obtain exact complete rows from inputs(), not invented geometry."""
    require(set(profiles) == {str(i) for i in range(ROW_COUNT)}, "MOLE_PUBLICATION_ROW_CENSUS")
    rows, boxes, mapping = bytearray(), bytearray(), []
    first = 0
    for index in range(ROW_COUNT):
        role, yaw = M.row_identity(index)
        data = profiles[str(index)]
        required = set(M.ROLE_NAMES if index >= 2 else M.ROLE_NAMES[:3])
        require(set(data) == required and all(type(value) is list and value for value in data.values()),
                "MOLE_PUBLICATION_REQUIRED_ROLE")
        count = sum(map(len, data.values()))
        require(3 <= count <= 12, "MOLE_PUBLICATION_ROW_BOX_CAPACITY")
        states = (257, 451)[index] if index < 2 else 329
        fields = [0, 6, 0, 6, index if index < 2 else 3, 0, 54, 0, -1, -1,
                  1 if index < 2 else 0, yaw or 0, 0, states, first, count, 1 if index >= 2 else -1,
                  2 if index >= 2 else 0]
        rows.extend(struct.pack("<18i3q2B", *fields, REVISION, 0, 0, CERTIFICATES, 0))
        for kind, name in enumerate(M.ROLE_NAMES):
            for bounds in data.get(name, []):
                boxes.extend(checked_box(bounds, kind))
        mapping.append({"profile": index, "profile_revision": REVISION, "content_revision": REVISION,
                        "source_role": role, "yaw": yaw, "yaw_kind": "all_native" if yaw is None else "exact",
                        "first_box": first, "box_count": count})
        first += count
    require(first == BOX_COUNT, "MOLE_PUBLICATION_BOX_CENSUS")
    header = struct.pack("<8sIqIII", b"UGPROF01", 1, REVISION, ROW_COUNT, BOX_COUNT, SOURCE_COUNT)
    wire = header + bytes.fromhex(M.IMAGE_SHA) + rows + boxes + b"UGPEND01"
    require(len(wire) == WIRE_BYTES, "MOLE_PUBLICATION_WIRE_CENSUS")
    return wire, mapping


def source_constants(wire_sha, consumers):
    """Small immutable code constants; runtime never parses a full JSON report or retains a third catalog image."""
    require(set(consumers) == set(G.CONSUMERS), "MOLE_PUBLICATION_CONSUMER_CENSUS")
    result = 'extends RefCounted\n## Generated exact source pins; regenerate with publish_mole_profiles.py.\n\n'
    for key, value in (("WIRE_SHA", wire_sha), ("ACTOR_SHA", M.IMAGE_SHA), ("BASIS_SHA", M.BASIS_SHA),
                       ("BASIS_PRODUCER", M.BASIS_PRODUCER), ("CONSUMER_COMMIT", CURRENT_COMMIT)):
        result += 'const ' + key + ': String = ' + json.dumps(value) + '\n'
    result += 'const PATHS: PackedStringArray = [\n'
    result += ''.join('\t' + json.dumps('res://' + name.removeprefix('godot/')) + ',\n' for name in G.CONSUMERS)
    result += ']\nconst DIGESTS: PackedStringArray = [\n'
    result += ''.join('\t' + json.dumps(consumers[name]) + ',\n' for name in G.CONSUMERS)
    return result + ']\n'


def output_refusal(path):
    require(not path.is_symlink() and not path.exists(), "MOLE_PUBLICATION_OUTPUT_EXISTS")


def publish(out):
    output_refusal(out)  # Includes dangling symlinks before resolve or any expensive source work.
    out = out.resolve()
    profiles, consumers, pins, evidence = inputs()
    wire, mapping = encode_wire(profiles)
    wire_sha = hashlib.sha256(wire).hexdigest()
    constants = source_constants(wire_sha, consumers).encode()
    require(len(constants) <= 4096, "MOLE_PUBLICATION_CONSTANT_CAPACITY")
    # Detect source changes before making even the create-only candidate directory.
    require(all(digest(ROOT / name) == expected for name, expected in pins.items()), "MOLE_PUBLICATION_FINAL_DRIFT")
    manifest = {"schema": 1, "source_geometry_qualified": True, "world_activation_qualified": False,
        "review_status": "publication implementation candidate; independent review required before integration",
        "certificate_flags": CERTIFICATES, "wire_sha256": wire_sha, "wire_bytes": WIRE_BYTES,
        "paired_bank_bytes": PAIRED_BANK_BYTES, "profile_count": ROW_COUNT, "box_count": BOX_COUNT,
        "actor_sha256": M.IMAGE_SHA, "source_program": 4, "mapping": mapping, "world_root_bounds_u": ROOT_BOUNDS,
        "consumer_commit": CURRENT_COMMIT, "consumers": consumers, "prerequisite_pins": pins,
        "constants_sha256": hashlib.sha256(constants).hexdigest(), "evidence": evidence,
        "remaining": ["ACTUAL_WORLD_SUPPORT_AND_PAID_TARGETS", "ACTUAL_WIP_AND_MATERIAL_HANDLING",
                      "RUNTIME_PRESENTATION_ATTACHMENT", "STATIONARY_TURN_OWNER", "STEPS_AND_PACE",
                      "WHOLE_CLIENT_PEAK_AND_GAMEPLAY_CAMERA"]}
    out.mkdir(parents=True)
    for name, data in (("mole-worker.ugprof", wire), ("catalog_source.gd", constants),
                       ("manifest.json", (json.dumps(manifest, indent=2) + '\n').encode())):
        with (out / name).open("xb") as stream:
            stream.write(data)
    print(json.dumps({"profiles": ROW_COUNT, "boxes": BOX_COUNT, "wire_bytes": WIRE_BYTES,
                      "wire_sha256": wire_sha, "world_activation_qualified": False}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    publish(parser.parse_args().out)
