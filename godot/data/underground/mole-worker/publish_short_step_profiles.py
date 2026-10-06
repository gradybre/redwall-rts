#!/usr/bin/env python3
"""Create one reviewed protocol-6 source publication; never grant actual World access.

qualified-step-v4 is now a historical publication: it binds profile content 3,
which content 5 (`qualified-haul-v6`, ADR 1200) superseded at runtime. Its pins
describe the tree at CONSUMER_COMMIT, so every pinned file git tracks there is
read from that commit, never from the live tree; untracked inputs are read live
and must still match exactly. A module this replay executes must also match live.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import struct
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
E = "docs/validation/evidence/underground-short-step-publication-2026-10-05/"
ACCEPTED = "docs/validation/evidence/underground-short-work-step-runtime-2026-10-05/"
REVIEW = ACCEPTED + "independent-review/acceptance.json"
REVIEW_SHA = "6613e4cfa8c1b3a17b779d19bff46f8fb16b6115da5f50f47fc5f8a78818a37e"
LINEAGE_SHA = "3b6dcb9daa88c49d0a487a50cce8078ddcb31d2ab1d681c9f2291f11b9fd7bb4"
CURRENT_SHA = "51e90f566dc8ebd043a2b7bd052bad0f0ee0bdf84aff08123e87c709f8543342"
NATIVE_INPUTS_SHA = "9e087e4b645dbc9e1b967f7262468f4e25673aaa46fbaa8d22dd44c68d7126b8"
OLD = "godot/data/underground/mole-worker/profile-publication-v3-frontier/"
OLD_WIRE_SHA = "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204"
WIRE_SHA = "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e"
GROUND_SHA = "454eaab1b2a722aab2700285d31a0bcc093312dad211208da7993baa32bc2f24"
GROUND_COMPILER = "godot/data/underground/ground-pace-v1/compile_ground_pace.py"
GROUND_COMPILER_SHA = "14dbac8fa70c17648711db856cab2fe5b7666a53ae1a0ca61b2eb4761bebf539"
SERIALIZER = "godot/data/underground/mole-worker/work-step-v1/assemble_diagnostic.py"
SERIALIZER_SHA = "07d0b78fb5e4dc4046285a93862e7dd7f99e83103661a5fc82cccc5ca4e1c3da"
ACTOR_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
BASIS_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
BASIS_PRODUCER = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"
CONSUMER_COMMIT = "912de685b423c5eedd36ee68bc78f18670276cb7"
PUBLISHED_AT = "84739fcc1569ad34596e3deac32a010563a1c844"
CONSUMERS = (
    "godot/scripts/core/underground_profiles.gd",
    "godot/scripts/core/underground_work_face.gd",
    "godot/scripts/core/underground_connector_contacts.gd",
    "godot/scripts/core/underground_routes.gd",
    "godot/scripts/core/underground_world_routes.gd",
    "godot/demo/cast/underground_actor.gd",
    "godot/demo/cast/underground_actor_content.gd",
    "godot/data/underground/mole-worker/mole_profile_driver.gd",
    "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
    "godot/data/underground/mole-worker/work-step-v1/source_program.gd",
)
OLD_MOTION = "godot/data/underground/mole-worker/motion-catalog-v2/"
OLD_MOTION_SHA = "2f44037e5e4eed0b4e2966cd1ac1881bdf4481dd083a26b11d8eea0c5ca0f986"
OLD_MOTION_MANIFEST_SHA = "ed484d13e7e4544b772cfee49b0e7b0c24cd3d52ba5bd3200f7726ef77ac8ab3"
OUTPUT = "godot/data/underground/mole-worker/qualified-step-v4/"
NATIVE_PREFIX = "/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime/"
I64_AT = 32 + 12 + 17421 * 4 + 12
BYTE_AT = I64_AT + 67 * 8 + 12


def require(value, code):
    if not value:
        raise ValueError("STEP_PUBLICATION_" + code)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


_BATCHES = {}
LFS = b"version https://git-lfs.github.com/spec/v1\n"


def relative(name):
    require(type(name) is str and str(PurePosixPath(name)) == name and not name.startswith("/")
            and ".." not in PurePosixPath(name).parts, "PATH")


def historical(name, commit=CONSUMER_COMMIT):
    """Bytes of `name` tracked at `commit`, or None when ROOT is not a checkout that tracks it there."""
    relative(name)
    key = (str(ROOT), commit)
    if key not in _BATCHES:
        probe = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        tracked = probe.returncode == 0 and Path(probe.stdout.strip()).resolve() == ROOT.resolve()
        _BATCHES[key] = subprocess.Popen(["git", "-C", str(ROOT), "cat-file", "--batch"],
                                         stdin=subprocess.PIPE, stdout=subprocess.PIPE) if tracked else None
    batch = _BATCHES[key]
    if batch is None:
        return None
    batch.stdin.write(f"{commit}:{name}\n".encode())
    batch.stdin.flush()
    header = batch.stdout.readline().split()
    require(len(header) in (2, 3), "HISTORICAL:" + name)
    if header[-1] == b"missing":
        return None
    require(header[1] == b"blob", "HISTORICAL:" + name)
    raw = batch.stdout.read(int(header[2]))
    require(len(raw) == int(header[2]) and batch.stdout.read(1) == b"\n", "HISTORICAL:" + name)
    return raw


def canonical(name, maximum=32 * 1024 * 1024):
    """Canonical bounded regular files only; a symlink cannot move a proof outside its repository."""
    relative(name)
    path = ROOT / name
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(ROOT)
            and 0 <= path.stat().st_size <= maximum, "FILE:" + name)
    return path


def admit(name, expected, pins):
    """Pin one input; return its historical bytes, or None when the live file itself was verified."""
    require(type(expected) is str and len(expected) == 64 and all(c in "0123456789abcdef" for c in expected), "DIGEST")
    raw = historical(name)
    if raw is None or raw.startswith(LFS):
        # Stream even large archived mesh/import inputs; do not materialize their aggregate payload.
        hashing = hashlib.sha256()
        with canonical(name, 512 * 1024 * 1024).open("rb") as stream:
            while chunk := stream.read(1048576):
                hashing.update(chunk)
        actual = hashing.hexdigest()
        # An LFS pointer names its content by SHA-256, so the checkout must hold exactly those bytes.
        require(raw is None or b"oid sha256:" + actual.encode() + b"\n" in raw, "HISTORICAL_LFS:" + name)
        raw = None
    else:
        actual = digest(raw)
    require(actual == expected, "HASH:" + name)
    require(name not in pins or pins[name] == expected, "PIN_CONFLICT")
    pins[name] = expected
    return raw


def check(name, expected, pins):
    admit(name, expected, pins)


def read(name, expected, pins):
    raw = admit(name, expected, pins)
    return canonical(name).read_bytes() if raw is None else raw


def add_pins(values, pins):
    require(type(values) is dict and 0 < len(values) <= 2048, "PIN_CENSUS")
    for name, expected in values.items():
        check(name, expected, pins)


def module(name, expected, pins):
    read(name, expected, pins)
    require(digest(canonical(name).read_bytes()) == expected, "MODULE_DRIFT:" + name)
    spec = importlib.util.spec_from_file_location("step_publication_" + Path(name).stem, ROOT / name)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def lineage(pins):
    """Verify the immutable old proof through explicit historical locators, never a live-consumer exemption."""
    record = json.loads(read(E + "lineage-inputs.json", LINEAGE_SHA, pins))
    old = json.loads(read(record["manifest_path"], record["manifest_sha256"], pins))
    require(record["manifest_path"] == OLD + "manifest.json" and record["count"] == 523
            and len(record["rows"]) == 523 and set(record["rows"]) == set(old["prerequisite_pins"]), "LINEAGE_CENSUS")
    for name, expected in old["prerequisite_pins"].items():
        row = record["rows"][name]
        require(row["sha256"] == expected, "LINEAGE_IDENTITY")
        if row["locator"] != name:
            require(row["historical_commit"] == old["consumer_commit"] and
                    row["locator"].startswith(E + "historical-inputs/"), "HISTORICAL_SCOPE")
        check(row["locator"], expected, pins)
    read(OLD + "catalog_source.gd", old["constants_sha256"], pins)
    require(old["source_geometry_qualified"] is True and old["world_activation_qualified"] is False
            and old["wire_sha256"] == OLD_WIRE_SHA and len(old["consumers"]) == 9, "LINEAGE_QUALIFICATION")
    return old


def current_consumers(pins):
    current = json.loads(read(E + "current-consumers.json", CURRENT_SHA, pins))
    require(current["commit"] == CONSUMER_COMMIT and tuple(current["consumers"]) == CONSUMERS, "CURRENT_CENSUS")
    for name, expected in current["consumers"].items():
        raw = read(name, expected, pins)
        require(0 < len(raw.decode()) <= 262144, "CONSUMER_SIZE")
    return current["consumers"]


def source_proof(review, pins):
    """The unchanged accepted source adapter reconstructs all 537 source inputs in its isolated snapshot."""
    row = review["source1164_report"]
    raw = read(row["path"], row["sha256"], pins)
    proof = json.loads(raw)
    require(proof["verified_source_files"] == 537 and proof["actor_sha256"] == ACTOR_SHA
            and proof["production_qualified"] is False and proof["certificate_bits_written"] == 0, "SOURCE_PROOF")
    add_pins(proof["source_inputs"], pins)
    add_pins(proof["producer_sources"], pins)
    name = "godot/data/underground/mole-worker/work-approach-v1/compile_work_approach.py"
    adapter = module(name, proof["producer_sources"][name], pins)
    basis = ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
    with adapter.original_source_inputs():
        before = adapter.M.input_pins(basis)
        result = adapter.M.source_program()
        require(result[5] == 537 and result[4] == proof["root_domain_u"] and
                result[6] == proof["historical_source_snapshot"] and
                before == adapter.M.input_pins(basis), "SOURCE_RECONSTRUCTION")
    return raw, proof


def native_proof(review, consumers, old, pins):
    """Require exact accepted native bytes, full original input closure and current eight executed consumers."""
    raw = {key: read(row["path"], row["sha256"], pins) for key, row in review["native_evidence"].items()}
    before = json.loads(raw["sources-before.json"])
    require(before == json.loads(raw["sources-after.json"]) and len(before) == 402, "NATIVE_DRIFT")
    inputs = json.loads(read(ACCEPTED + "inputs-sha256.json", NATIVE_INPUTS_SHA, pins))
    require(all(name.startswith(NATIVE_PREFIX) for name in before) and
            {name.removeprefix(NATIVE_PREFIX): value for name, value in before.items()} == inputs, "NATIVE_PATHS")
    add_pins(inputs, pins)
    require(sum(canonical(name, 512 * 1024 * 1024).stat().st_size for name in inputs) <= 2 * 1024**3, "NATIVE_CAPACITY")
    for name in CONSUMERS:
        if name in CONSUMERS[1:3]:
            require(consumers[name] == old["consumers"][name], "UNCHANGED_NON_NATIVE_CONSUMER")
        else:
            require(inputs.get(name) == consumers[name], "CURRENT_NATIVE_CONSUMER")
    invocation = json.loads(raw["invocation.json"])
    require(len(invocation["commands"]) == 2 and all(row["exit"] == 0 and not row["raw_diagnostic"]
            for row in invocation["commands"]) and all(invocation[key] is True for key in
            ("source_unchanged", "override_restored", "import_sidecars_restored")), "NATIVE_INVOCATION")
    report = json.loads(raw["report.json"])
    require(report["failures"] == [] and report["program_version"] == 6 and report["poses"] == 462
            and report["assertions"] == 2558 and report["resolution"] == [1280, 720]
            and report["production_qualified"] is False and digest(raw["native.bin"]) == report["native_sha256"], "NATIVE_REPORT")
    name = "godot/data/underground/mole-worker/work-step-v1/run_canonical.py"
    auditor = module(name, review["candidate_sources"][name], pins)
    verified = auditor.validate(ROOT / (ACCEPTED + "native-4"))
    require(verified == json.loads(raw["verification.json"]) == review["native_verification"], "NATIVE_ORACLE")
    for shot in report["screenshots"]:
        check(ACCEPTED + "native-4/" + shot["path"], shot["sha256"], pins)


def source_constants(consumers):
    text = 'extends RefCounted\n## Generated exact source pins; use publish_short_step_profiles.py.\n\n'
    for name, value in (("WIRE_SHA", WIRE_SHA), ("ACTOR_SHA", ACTOR_SHA), ("BASIS_SHA", BASIS_SHA),
                        ("BASIS_PRODUCER", BASIS_PRODUCER), ("CONSUMER_COMMIT", CONSUMER_COMMIT)):
        text += 'const ' + name + ': String = ' + json.dumps(value) + '\n'
    text += 'const PATHS: PackedStringArray = [\n'
    text += ''.join('\t' + json.dumps('res://' + name.removeprefix('godot/')) + ',\n' for name in CONSUMERS)
    text += ']\nconst DIGESTS: PackedStringArray = [\n'
    text += ''.join('\t' + json.dumps(consumers[name]) + ',\n' for name in CONSUMERS)
    raw = (text + ']\n').encode()
    require(len(raw) <= 4096, "CONSTANTS_CAPACITY")
    return raw


def motion_rebind(profile_manifest, pins):
    """Only shared source revision/digest metadata changes; all independent stair words remain exact."""
    profile = json.loads(profile_manifest)
    require(profile.get("prerequisite_pins") == pins and profile.get("source_review_sha256") == REVIEW_SHA
            and profile.get("source_geometry_qualified") is True and profile.get("world_activation_qualified") is False
            and profile.get("wire_sha256") == WIRE_SHA and profile.get("content_revision") == 3
            and profile.get("profile_count") == 29 and profile.get("box_count") == 271
            and tuple(profile.get("consumers", {})) == CONSUMERS, "MOTION_PROFILE_PUBLICATION")
    manifest = json.loads(read(OLD_MOTION + "manifest.json", OLD_MOTION_MANIFEST_SHA, pins))
    add_pins(manifest["source_pins"], pins)
    original = read(OLD_MOTION + "motion.ugmotion", OLD_MOTION_SHA, pins)
    old_numerical = digest(json.dumps(manifest["source_pins"], sort_keys=True, separators=(",", ":")).encode())
    require(len(original) == 70936 and digest(original) == OLD_MOTION_SHA
            and old_numerical == manifest["numerical_input_manifest_sha256"]
            and original[BYTE_AT + 384:BYTE_AT + 416].hex() == old_numerical
            and original[BYTE_AT + 160:BYTE_AT + 192].hex() == OLD_WIRE_SHA
            and struct.unpack_from('<q', original, 16) == (2,)
            and struct.unpack_from('<3q', original, I64_AT) == (1, 2, 2), "MOTION_PROVENANCE")
    for program in range(5):
        require(all(struct.unpack_from('<i', original, 44 + (16903 + field * 5 + program) * 4)[0] == -1
                    for field in (9, 10)), "MOTION_UNBOUND_PROFILE")
        require(all(struct.unpack_from('<q', original, I64_AT + (32 + field * 5 + program) * 8)[0] == 0
                    for field in (0, 1, 4, 5, 6)), "MOTION_UNBOUND_RATE")
    numerical = {OLD_MOTION + "manifest.json": OLD_MOTION_MANIFEST_SHA,
                 OLD_MOTION + "motion.ugmotion": OLD_MOTION_SHA,
                 OUTPUT + "manifest.json": digest(profile_manifest), OUTPUT + "mole-worker.ugprof": WIRE_SHA}
    numerical_sha = digest(json.dumps(numerical, sort_keys=True, separators=(",", ":")).encode())
    result = bytearray(original)
    struct.pack_into('<q', result, 16, 3)
    struct.pack_into('<2q', result, I64_AT + 8, 3, 3)
    result[BYTE_AT + 160:BYTE_AT + 192] = bytes.fromhex(WIRE_SHA)
    result[BYTE_AT + 384:BYTE_AT + 416] = bytes.fromhex(numerical_sha)
    ranges = [(16, 24), (I64_AT + 8, I64_AT + 24), (BYTE_AT + 160, BYTE_AT + 192), (BYTE_AT + 384, BYTE_AT + 416)]
    require(all(a == b or any(low <= index < high for low, high in ranges)
                for index, (a, b) in enumerate(zip(original, result))), "MOTION_FOREIGN_DELTA")
    return bytes(result), {"schema": 1, "content_revision": 3, "profiles_content_revision": 3,
        "wire_sha256": digest(result), "wire_bytes": 70936, "bank_bytes": 70860,
        "source_pins": numerical, "numerical_input_manifest_sha256": numerical_sha,
        "original_wire_sha256": OLD_MOTION_SHA, "permitted_changed_byte_ranges": ranges,
        "all_original_geometry_preserved": True, "all_original_permission_and_rate_values_preserved": True,
        "runtime_activation": False, "pace_adopted": False, "scope": "Source-only shared Profile identity rebind."}


def inputs():
    pins = {}
    review = json.loads(read(REVIEW, REVIEW_SHA, pins))
    require(review["accepted"] is True and review["source_runtime_accepted"] is True
            and review["sampled_native_replay_accepted"] is True and not review["findings"]
            and all(review[key] is False for key in ("world_activation_qualified",
                "production_publication_qualified", "native_memory_qualified", "performance_qualified")), "REVIEW")
    add_pins(review["candidate_sources"], pins)
    old = lineage(pins)
    consumers = current_consumers(pins)
    proof_raw, proof = source_proof(review, pins)
    native_proof(review, consumers, old, pins)
    serializer = module(SERIALIZER, SERIALIZER_SHA, pins)
    wire, mapping = serializer.encode(read(OLD + "mole-worker.ugprof", OLD_WIRE_SHA, pins), proof_raw)
    require(digest(wire) == WIRE_SHA and len(wire) == 10502, "WIRE")
    constants = source_constants(consumers)
    ground = module(GROUND_COMPILER, GROUND_COMPILER_SHA, pins)
    require(all(name in pins for name in (ground.MOVEMENT_PATH, ground.RESIDENTS_PATH,
            ground.PROFILE_OWNER_PATH, 'godot/scripts/core/catalog.gd')), "GROUND_SOURCE_CLOSURE")
    movement = ground.movement_identity(read(ground.MOVEMENT_PATH, pins[ground.MOVEMENT_PATH], pins).decode(),
                                        read(ground.RESIDENTS_PATH, pins[ground.RESIDENTS_PATH], pins).decode())
    profile_owner = read(ground.PROFILE_OWNER_PATH, pins[ground.PROFILE_OWNER_PATH], pins).decode()
    revision, actor, rows, excluded = ground.walking_rows(wire, movement,
        ground.integer_constant(profile_owner, "MODE_WALK"), ground.integer_constant(profile_owner, "CERT_REQUIRED"))
    level = read(ground.LEVEL_PATH, ground.LEVEL_SHA, pins)
    ground_wire = ground.encode(revision, actor, struct.unpack_from('<q', level, 12)[0],
                                bytes.fromhex(ground.LEVEL_SHA), movement, rows)
    require([row["profile_id"] for row in rows] == list(range(1, 13)) and digest(ground_wire) == GROUND_SHA, "GROUND_ROWS")
    producer = str(Path(__file__).relative_to(ROOT))
    published = historical(producer, PUBLISHED_AT)
    pins[producer] = digest(Path(__file__).read_bytes() if published is None else published)
    manifest = {"schema": 1, "source_geometry_qualified": True, "world_activation_qualified": False,
        "native_memory_qualified": False, "performance_qualified": False,
        "scope": "Accepted complete source geometry and sampled protocol-6 native clock; actual World admission remains mandatory.",
        "wire_sha256": WIRE_SHA, "wire_version": 2, "content_revision": 3, "profile_revision": 1,
        "certificate_flags": 15, "profile_count": 29, "box_count": 271, "wire_bytes": 10502,
        "paired_bank_bytes": 20988, "actor_sha256": ACTOR_SHA, "source_program": 6,
        "mapping": mapping, "world_root_bounds_u": proof["root_domain_u"],
        "consumer_commit": CONSUMER_COMMIT, "consumers": consumers, "prerequisite_pins": pins.copy(),
        "constants_sha256": digest(constants), "source_review_sha256": REVIEW_SHA,
        "source_reconstruction_files": 537, "native_input_files": 402,
        "native_executed_consumers": [name for name in CONSUMERS if name not in CONSUMERS[1:3]],
        "unchanged_prior_qualified_consumers": list(CONSUMERS[1:3]),
        "remaining": ["Integrated whole-pack accounting", "Actual paid next-cell composition",
                      "Finite World activation", "Target-hardware performance", "Native memory measurement"]}
    encoded_manifest = (json.dumps(manifest, indent=2) + '\n').encode()
    motion_wire, motion_manifest = motion_rebind(encoded_manifest, pins)
    ground_manifest = {"schema": 1, "wire_version": 2, "catalog_revision": 1,
        "artifact_sha256": GROUND_SHA, "artifact_bytes": len(ground_wire),
        "counts": {"variants": 0, "points": 0, "regions": 0, "parts": 0, "vertices": 0, "materials": 0, "paces": 12},
        "profile_content_revision": 3, "profile_wire_sha256": WIRE_SHA,
        "profile_manifest_sha256": digest(encoded_manifest), "rows": rows, "excluded_non_walk": excluded,
        "movement": movement, "rate_kind": "RATE_GROUND_CAP", "rate_value": 0,
        "compiler_sha256": GROUND_COMPILER_SHA, "runtime_activation_qualified": False,
        "clearance_or_actor_permission": False, "native_memory_measured": False}
    files = {"mole-worker.ugprof": wire, "catalog_source.gd": constants, "manifest.json": encoded_manifest,
             "ground-pace.ugconn": ground_wire, "ground-manifest.json": (json.dumps(ground_manifest, indent=2) + '\n').encode(),
             "motion.ugmotion": motion_wire, "motion-manifest.json": (json.dumps(motion_manifest, indent=2) + '\n').encode()}
    return files, pins


def publish(out):
    require(out.resolve() == ROOT / OUTPUT and not out.exists() and not out.is_symlink(), "OUTPUT")
    files, pins = inputs()
    add_pins(pins.copy(), {})
    out.mkdir(parents=True)
    for name, raw in files.items():
        with (out / name).open('xb') as stream:
            stream.write(raw)
    return {name: digest(raw) for name, raw in files.items()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('out', type=Path)
    print(json.dumps(publish(parser.parse_args().out), indent=2))
