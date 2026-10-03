#!/usr/bin/env python3
"""Bounded distinct upper-face source proof. A visible block is never an installed bench or work permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("wall_source", HERE / "author_high_wall.py")
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)
S, P = H.S, H.P
SOURCE_REVISION = "ecbfcb123ddf682252421584cccb9b473b234a8d"
HISTORICAL_PROFILE = "c0064e3ce55fdaa8df33ce4d0b7f54a37fc49ff938f70461ea40f58ef90ef8c2"


def read_record(path: Path, maximum: int = 262144) -> dict:
    """Bound every non-streamed evidence record before allocating its JSON image."""
    P.require(path.is_file() and path.stat().st_size <= maximum, "WALL_RECORD_CAPACITY")
    result = json.loads(path.read_text())
    P.require(type(result) is dict, "WALL_RECORD_FORMAT")
    return result


def historical_profile_bytes(expected: str) -> bytes:
    """Only this independently accepted API predecessor may differ from the current runtime checkout."""
    P.require(expected == HISTORICAL_PROFILE, "WALL_HISTORICAL_SOURCE_PIN")
    raw = subprocess.check_output(["git", "show", SOURCE_REVISION + ":godot/scripts/core/underground_profiles.gd"], cwd=P.ROOT)
    P.require(len(raw) <= 262144 and hashlib.sha256(raw).hexdigest() == expected, "WALL_HISTORICAL_SOURCE_PIN")
    return raw


def snapshot_sources(metadata: dict, snapshot: Path) -> dict:
    """Borrow exact live inputs by hard link; only one pinned historical script gets a private byte copy."""
    rows = [metadata["manifest"], *metadata["sources"]]
    P.require(len(rows) <= 2049, "WALL_SOURCE_SNAPSHOT_CAPACITY")
    restored = {}
    for row in rows:
        name = row["path"]
        if not name.startswith("res://") or name.startswith("res://.godot/imported/") or \
                (name.startswith("res://demo/assets/") and name.endswith(".import")):
            continue  # Existing verifier owns absolute paths and exact import-archive handling.
        destination = (snapshot / name[6:]).resolve()
        source = (P.ROOT / "godot" / name[6:]).resolve()
        P.require(destination.is_relative_to(snapshot) and source.is_relative_to(P.ROOT / "godot"), "WALL_SOURCE_SNAPSHOT_PATH")
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            continue  # The original verifier below rejects conflicting duplicate pins.
        if name == "res://scripts/core/underground_profiles.gd":
            destination.write_bytes(historical_profile_bytes(row["sha256"]))
            restored[name] = {"commit": SOURCE_REVISION, "sha256": row["sha256"]}
        else:
            P.require(source.is_file(), "WALL_SOURCE_SNAPSHOT_MISSING")
            os.link(source, destination)  # This proof never writes borrowed inputs or their links.
    return restored


def extract_original(source: Path, source_hash: str, proof: dict, plan: dict, archive: Path) -> tuple:
    """Use the existing full source verifier against an exact historical project view, with unchanged raw decode guards."""
    wanted = P.content.validate_plan(plan)
    P.require(proof.get("source_sha256") == source_hash and proof.get("world_root_bounds_u") == plan["world_root_bounds_u"]
              and type(proof.get("profiles")) is list, "CONTENT_PROOF_SOURCE")
    chosen, identities = {}, None
    with tempfile.TemporaryDirectory(prefix=".mole-source-proof-", dir=P.ROOT) as temporary, source.open("rb") as stream:
        reader = P.envelope.PaletteSource(stream, source_hash)
        P.envelope.palette_backend_certificate(reader.metadata)
        snapshot = Path(temporary).resolve()
        historical = snapshot_sources(reader.metadata, snapshot)
        pins = P.envelope.verify_palette_sources(reader.metadata, project_root=snapshot, import_archive=archive)
        for case in reader.cases():
            if case["id"] not in wanted:
                continue
            P.require(all(case[key] == plan[key] for key in ("cast", "species", "life_stage")), "CONTENT_CAST_IDENTITY")
            P.require(case["attachments"] == [plan["active_tool"]] and case["grounding"] is not None, "CONTENT_ATTACHMENT_KEY")
            current = tuple(P.content.part_identity(part) for part in case["geometry"])
            P.require(identities is None or current == identities, "CONTENT_PART_BINDING_DRIFT")
            identities, chosen[case["id"]] = current, case
            P.require(sum(row["frames"] for row in chosen.values()) <= P.content.MAX_FRAMES and
                      sum(row["matrices"].size + row["grounding"].size for row in chosen.values()) <= P.content.MAX_SCALARS,
                      "CONTENT_SCALAR_CAPACITY")
        P.require(P.envelope.verify_palette_sources(reader.metadata, project_root=snapshot, import_archive=archive) == pins,
                  "WALL_HISTORICAL_SOURCE_PIN")
    P.require(set(chosen) == set(wanted) and 1 <= len(identities) <= P.content.MAX_PARTS, "CONTENT_SOURCE_STATE_MISSING")
    return [chosen[key] for key in wanted], pins, historical


def source_cases_refusal(cases: list, parent: list, rig: dict, recipe: dict) -> None:
    """Rebuild every finite source matrix/timing from the pinned parent and the one authored correction."""
    P.require(len(cases) == len(parent) == 9 and recipe.get("maximum_yaw_degrees") == 15,
              "WALL_SOURCE_RECIPE")
    expected = list(parent)
    frames = list(range(14)) + list(range(12, -1, -1))
    expected[6] = P.indexed_sequence(parent[6], frames, "mole_digger.high_wall.source30_43_retrace_v1", True)
    expected[7] = H.retract_entry(parent[7], rig, 15)
    P.require(expected[7]["entry_recipe"] == recipe, "WALL_SOURCE_RECIPE")
    expected[8] = P.indexed_sequence(expected[7], list(range(expected[7]["frames"] - 1, -1, -1)),
                                     "mole_digger.high_wall.recovery_v1", False)
    for actual, wanted in zip(cases, expected):
        P.require(actual["frames"] == wanted["frames"] and P.rendered_timing(actual) == P.rendered_timing(wanted) and
                  np.array_equal(actual["matrices"], wanted["matrices"]) and
                  np.array_equal(actual["grounding"], wanted["grounding"]), "WALL_SOURCE_MOTION_DRIFT")


def native_tip_refusal(report: dict, witness: dict) -> None:
    """Each actual native point stays in its exact source equation plus the proved arithmetic residual."""
    rows = report.get("native_tip")
    P.require(type(rows) is list and len(rows) == 9, "WALL_NATIVE_CENSUS")
    endpoints = [[Fraction(value["numerator"], value["denominator"]) for value in row]
                 for row in witness["endpoint_ideal_m"]]
    errors = [Fraction(value["numerator"], value["denominator"]) for value in witness["residual_m"]]
    for step, row in enumerate(rows):
        P.require(row.get("share_q16") == step * 8192 and type(row.get("local_point_u")) is list and
                  len(row["local_point_u"]) == 3, "WALL_NATIVE_CENSUS")
        share = Fraction(step, 8)
        for axis, actual in enumerate(row["local_point_u"]):
            P.require(type(actual) in (int, float) and np.isfinite(actual), "WALL_NATIVE_FINITE")
            ideal = (1 - share) * endpoints[0][axis] + share * endpoints[1][axis]
            P.require(ideal - errors[axis] <= Fraction(actual) / 1024 <= ideal + errors[axis],
                      "WALL_NATIVE_SOURCE_ENCLOSURE")


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("analysis", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("native", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "WALL_PROOF_OUTPUT_EXISTS")
    command = read_record(args.analysis / "invocation.json")["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, pins, historical = extract_original(Path(value("source")), value("source-sha256"), proof, plan,
                                                  Path(value("import-archive")))
    geometry = original[0]["geometry"]
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), geometry)
    native = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    compiled = read_record(args.candidate / "compilation.json")
    source = read_record(args.candidate / "candidate.json")
    image = args.candidate / "mole-worker.ugactor"
    cases = S.read_image(image, compiled["content_sha256"], geometry)
    with image.open("rb") as stream:
        header = stream.read(184)
    parent_path = args.analysis / "result/mole-worker.ugactor"
    P.require(source["source"] == P.content.file_hash(parent_path) and
              header[120:152].hex() == P.content.file_hash(args.candidate / "candidate.json"), "WALL_PROOF_SOURCE")
    parent = S.read_image(parent_path, source["source"], geometry)
    source_cases_refusal(cases, parent, native["rig_binding"], source["entry_recipe"])
    P.require(len(cases) == 9 and cases[6]["frames"] == 27 and cases[7]["frames"] == cases[8]["frames"] == 31 and
              source["candidate_face_z_u"] == -536 and source["candidate_target_course_y_u"] == [1024, 2048],
              "WALL_PROOF_CANDIDATE")
    for path, expected in source["producer_sources"].items():
        P.require(P.content.file_hash(P.ROOT / path) == expected, "WALL_PROOF_PRODUCER_DRIFT")
    roots = plan["world_root_bounds_u"]
    witness = H.point_crossing(cases[6], geometry[1], roots, -536)
    P.require(witness == source["tip"], "WALL_PROOF_WITNESS_DRIFT")
    observed = read_record(args.native / "report.json")
    invocation = read_record(args.native / "invocation.json")
    P.require(observed["content_sha256"] == compiled["content_sha256"] and observed["failures"] == [] and
              observed["poses"] == 537 and observed["assertions"] >= 1074 and observed["production_qualified"] is False and
              invocation["native_exit"] == 0 and invocation["source_unchanged"] and not invocation["unexpected_diagnostics"],
              "WALL_PROOF_NATIVE")
    for path, expected in read_record(args.native / "sources.json", 1048576).items():
        P.require(P.content.file_hash(Path(path)) == expected, "WALL_NATIVE_SOURCE_DRIFT")
    native_tip_refusal(observed, witness)
    rows = {}
    for clip in (6, 7):
        case = dict(cases[clip], geometry=geometry)
        rows[str(clip)] = {"self_contact": S.prove(case, geometry, topology, native["rig_binding"], roots, "body"),
                           "floor": P.continuous_floor(case, topology, roots)}
    P.require(S.reusable_timing(cases[8], cases[7], True) and
              np.array_equal(cases[8]["matrices"], cases[7]["matrices"][::-1]) and
              np.array_equal(cases[8]["grounding"], cases[7]["grounding"][::-1]), "WALL_RECOVERY_IDENTITY")
    rows["8"] = {"exact_reverse_of": 7, "self_contact_clear": rows["7"]["self_contact"]["clear"]}
    report = {"schema": 1, "content_sha256": compiled["content_sha256"], "clips": rows, "tip": witness,
              "native_tip_samples": 9, "verified_source_files": pins, "exact_yaw": 0, "production_qualified": False,
              "source_matrices_timing_grounding_rederived": True,
              "historical_source_snapshot": historical,
              "scope": "source-local/yaw0; actual bench, support, complete approach, runtime state and world qualification absent",
              "producer_sources": {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path))
                                   for path in (__file__, H.__file__, S.__file__, P.__file__, P.envelope.__file__)}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({clip: row.get("self_contact", {}) for clip, row in rows.items()}, indent=2))
    P.require(all(row["self_contact"]["clear"] for row in rows.values() if "self_contact" in row), "WALL_SELF_UNRESOLVED")


if __name__ == "__main__":
    main()
