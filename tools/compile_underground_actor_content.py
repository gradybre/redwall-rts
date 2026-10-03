#!/usr/bin/env python3
"""Compile exact finite presentation content. This never grants production profile permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

import export_underground_envelopes as envelope

MAX_PARTS = 8
MAX_CLIPS = 16
MAX_FRAMES = 2048
MAX_SCALARS = 1048576
MAX_VERTICES = 32768
MAX_SURFACES = 8
CONTROL_RESERVE = 2 * 1024 * 1024
MESH_BYTES_PER_VERTEX = 256
STATES = {"idle": 1, "walk": 2, "carry": 4, "work": 8, "crouch": 16,
          "climb": 32, "entry": 64, "reversal": 128, "recovery": 256}
REQUIRED = {"stand": {"idle", "recovery"},
            "walk": {"idle", "walk", "entry", "reversal", "recovery"},
            "work": {"idle", "work", "entry", "recovery"}}
require = envelope.require


def file_hash(path: Path) -> str:
    with path.open("rb") as stream:
        hashing = hashlib.sha256()
        while data := stream.read(65536):
            hashing.update(data)
        return hashing.hexdigest()


def read_json(path: Path, expected: str, maximum: int = 2 * 1024 * 1024) -> dict:
    require(path.is_file() and path.stat().st_size <= maximum, "CONTENT_JSON_CAPACITY")
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == expected, "CONTENT_JSON_DIGEST")
    value = json.loads(data)
    require(type(value) is dict, "CONTENT_JSON_FORMAT")
    return value


def validate_plan(plan: dict) -> list[str]:
    require(plan.get("schema") == 1 and type(plan.get("revision")) is int and
            0 < plan["revision"] < (1 << 31), "CONTENT_PLAN_SCHEMA")
    for key in ("cast", "species", "life_stage", "active_tool"):
        require(type(plan.get(key)) is str and 0 < len(plan[key]) <= 128, "CONTENT_PLAN_IDENTITY")
    clips = plan.get("clips")
    require(type(clips) is list and 1 <= len(clips) <= MAX_CLIPS and
            all(type(x) is str and 0 < len(x) <= 128 for x in clips) and
            len(set(clips)) == len(clips), "CONTENT_CLIP_CENSUS")
    groups = plan.get("groups")
    require(type(groups) is list and 1 <= len(groups) <= MAX_CLIPS, "CONTENT_GROUP_CENSUS")
    seen = set()
    for group in groups:
        require(type(group) is dict and type(group.get("id")) is str and
                group.get("id") not in seen and type(group.get("mode")) is str and group.get("mode") in REQUIRED,
                "CONTENT_GROUP_IDENTITY")
        seen.add(group["id"])
        states = group.get("states")
        require(type(states) is dict and REQUIRED[group["mode"]] <= set(states) <= set(STATES),
                "CONTENT_REQUIRED_STATE_MISSING")
        for cases in states.values():
            require(type(cases) is list and cases and len(cases) <= MAX_CLIPS and
                    all(type(x) is str for x in cases) and len(set(cases)) == len(cases) and all(x in clips for x in cases),
                    "CONTENT_STATE_SOURCE_MISSING")
    envelope.world_root_bounds(plan.get("world_root_bounds_u"))
    return clips


def geometry_fingerprint(part: dict) -> bytes:
    """Same little-endian source geometry transcript the native loader checks on borrowed meshes."""
    require(0 <= part["binds"] <= 128 and 1 <= len(part["geometry"]) <= MAX_SURFACES,
            "CONTENT_MESH_CAPACITY")
    require(len(part["geometry"]) == len(part["surface_formats"]), "CONTENT_SURFACE_CENSUS")
    hashing = hashlib.sha256(b"UGMESH01")
    hashing.update(struct.pack("<II", part["binds"], len(part["geometry"])))
    bounds = part.get("mesh_aabb")
    require(type(bounds) is list and len(bounds) == 6, "CONTENT_MESH_AABB")
    hashing.update(struct.pack("<6f", *bounds))
    total = 0
    for surface, format_value in zip(part["geometry"], part["surface_formats"]):
        points, ids, weights = surface["points"], surface["ids"], surface["weights"]
        count, stride = len(points), weights.shape[1]
        total += count
        require(0 < count <= MAX_VERTICES and total <= MAX_VERTICES, "CONTENT_VERTEX_CAPACITY")
        hashing.update(struct.pack("<QII", format_value, count, stride))
        # Reconstruct the exact streamed transcript, including every zero-weight influence.
        record = np.empty((count, 3 + 2 * stride), dtype="<u4")
        record[:, :3] = np.ascontiguousarray(points, dtype="<f4").view("<u4")
        record[:, 3::2] = ids
        record[:, 4::2] = np.ascontiguousarray(weights, dtype="<f4").view("<u4")
        hashing.update(record.tobytes())
    return hashing.digest()


def part_identity(part: dict) -> tuple:
    return (part["kind"], part["name"], part["binds"], part.get("mesh_resource", ""),
            part.get("instance_material_override", False), geometry_fingerprint(part))


def union_boxes(boxes: list[list[int]]) -> list[int]:
    require(boxes and all(len(x) == 6 and all(type(v) is int for v in x) and
                         all(x[a] < x[a + 3] for a in range(3)) for x in boxes),
            "CONTENT_ENVELOPE_FORMAT")
    return [min(x[a] for x in boxes) for a in range(3)] + [max(x[a] for x in boxes) for a in range(3, 6)]


def state_unions(plan: dict, proof: dict, cases: dict[str, dict]) -> list[dict]:
    """All declared source states, including every attachment, remain in the conservative role unions."""
    rows = {row["id"]: row for row in proof["profiles"]}
    require(len(rows) == len(proof["profiles"]), "CONTENT_PROOF_DUPLICATE")
    result = []
    for group in plan["groups"]:
        required_clip = {"idle": "idle", "walk": "walk", "crouch": "cautious_crouch_walk_forward",
                         "work": "heavy_hammer_swing", "carry": "carry_heavy_object_walk"}
        for state, keys in group["states"].items():
            if state in required_clip:
                require(all(cases[key]["clip"] == required_clip[state] for key in keys),
                        "CONTENT_STATE_LABEL_MISMATCH")
        used = sorted({key for keys in group["states"].values() for key in keys})
        all_parts, body_parts, tool_parts = [], [], []
        for key in used:
            require(key in rows and rows[key].get("world_model_representation_enclosed") is True,
                    "CONTENT_WORLD_PROOF_MISSING")
            proven = rows[key]
            actual = cases[key]
            require(proven["frames"] == actual["frames"] and len(proven["parts"]) == len(actual["geometry"]),
                    "CONTENT_PROOF_CENSUS")
            for expected, part in zip(proven["parts"], actual["geometry"]):
                require((expected["kind"], expected["name"]) == (part["kind"], part["name"]),
                        "CONTENT_PROOF_PART")
                box = expected["world_all_headings_bounds_u"]
                all_parts.append(box)
                if part["kind"] == "attachment" and part["name"] == plan["active_tool"]:
                    tool_parts.append(box)
                else:
                    body_parts.append(box)
        productive = group["mode"] == "work"
        require(not productive or tool_parts, "CONTENT_ACTIVE_TOOL_MISSING")
        result.append({"id": group["id"], "mode": group["mode"], "states": group["states"],
            "state_mask": sum(STATES[key] for key in group["states"]),
            "all_parts_u": union_boxes(all_parts),
            "body_non_target_u": union_boxes(body_parts if productive else all_parts),
            "active_tool_stroke_u": union_boxes(tool_parts) if productive else None,
            "recovery_all_parts_u": union_boxes(all_parts),
            "qualification": "SOURCE_STATE_UNION_ONLY",
            "remaining": ["EXACT_WORK_YAW_AND_CONTACT", "ACTUAL_STANCE_SUPPORT", "DYNAMIC_OWNER_KEY",
                          "ANIMATED_QUALITY_AND_MODE_HANDOFF"],
            "production_qualified": False})
    return result


def extract(source: Path, source_hash: str, proof: dict, plan: dict, archive: Path | None) -> tuple:
    wanted = validate_plan(plan)
    require(proof.get("source_sha256") == source_hash and proof.get("world_root_bounds_u") ==
            plan["world_root_bounds_u"] and type(proof.get("profiles")) is list,
            "CONTENT_PROOF_SOURCE")
    chosen, identities, raw_sources = {}, None, 0
    with source.open("rb") as stream:
        reader = envelope.PaletteSource(stream, source_hash)
        envelope.palette_backend_certificate(reader.metadata)
        raw_sources = envelope.verify_palette_sources(reader.metadata, import_archive=archive)
        for case in reader.cases():
            if case["id"] not in wanted:
                continue
            require(all(case[key] == plan[key] for key in ("cast", "species", "life_stage")),
                    "CONTENT_CAST_IDENTITY")
            require(case["attachments"] == [plan["active_tool"]], "CONTENT_ATTACHMENT_KEY")
            require(case["grounding"] is not None, "CONTENT_GROUNDING_MISSING")
            current = tuple(part_identity(part) for part in case["geometry"])
            require(identities is None or current == identities, "CONTENT_PART_BINDING_DRIFT")
            identities = current
            chosen[case["id"]] = case
            require(sum(x["frames"] for x in chosen.values()) <= MAX_FRAMES, "CONTENT_FRAME_CAPACITY")
            require(sum(x["matrices"].size + x["grounding"].size for x in chosen.values()) <= MAX_SCALARS,
                    "CONTENT_SCALAR_CAPACITY")
    require(set(chosen) == set(wanted), "CONTENT_SOURCE_STATE_MISSING")
    require(1 <= len(identities) <= MAX_PARTS, "CONTENT_PART_CAPACITY")
    return [chosen[key] for key in wanted], state_unions(plan, proof, chosen), raw_sources


def presentation_budget(parts: list[dict], clips: int, scalars: int) -> dict:
    largest_mesh = max(sum(len(s["points"]) for s in part["geometry"]) for part in parts)
    tables = 80 * len(parts) + 48 * clips + 152
    retained = 4 * scalars
    arrays = largest_mesh * MESH_BYTES_PER_VERTEX
    return {"retained_palette_bytes": retained, "decode_staging_bytes": retained,
            "borrowed_mesh_array_allowance_bytes": arrays, "packed_tables_bytes": tables,
            "reader_native_control_reserve_bytes": CONTROL_RESERVE,
            "admitted_peak_bytes": retained + max(retained, arrays) + tables + CONTROL_RESERVE,
            "world_basis_separately_shared_bytes": 544768,
            "native_peak_measured": False,
            "excluded_borrowed_resources": "original meshes/textures and per-Actor RIDs; separate actual presentation-owner admission"}


def encode(cases: list[dict], plan: dict, proof: dict, source_hash: str, proof_hash: str, plan_hash: str) -> tuple[bytes, dict]:
    parts = cases[0]["geometry"]
    frames = sum(c["frames"] for c in cases)
    stride = sum(max(1, p["binds"]) * 12 for p in parts)
    scalars = frames * (stride + 1)
    require(frames <= MAX_FRAMES and scalars <= MAX_SCALARS, "CONTENT_SCALAR_CAPACITY")
    output = bytearray(b"UGACNT01")
    output += struct.pack("<6I", 1, plan["revision"], len(parts), len(cases), frames, stride)
    output += struct.pack("<6i", *plan["world_root_bounds_u"])
    for value in (proof["world_basis"]["sha256"], source_hash, proof_hash, plan_hash):
        require(type(value) is str and len(value) == 64, "CONTENT_SOURCE_DIGEST")
        output += bytes.fromhex(value)
    for at, part in enumerate(parts):
        ungrounded = None
        offset = sum(max(1, p["binds"]) for p in parts[:at])
        for case in cases:
            matrices = case["matrices"][:, offset:offset + max(1, part["binds"])]
            local, _ = envelope.palette_part_envelope(part, matrices, None)
            ungrounded = envelope.include(ungrounded, local)
        # Static bounds are in the original mesh frame before its whole affine transform.
        if not part["binds"]:
            points = np.concatenate([s["points"] for s in part["geometry"]])
            ungrounded = [envelope.Interval(envelope.Interval.exact(float(points[:, a].min())).low,
                                          envelope.Interval.exact(float(points[:, a].max())).high) for a in range(3)]
        bounds = envelope.units(ungrounded)
        # Degenerate planar sources still need nonempty culling bounds, never physical permission.
        bounds = [v - 1 if a < 3 else v + 1 for a, v in enumerate(bounds)]
        output += struct.pack("<4I", part["binds"], sum(len(s["points"]) for s in part["geometry"]),
                              len(part["geometry"]), int(part["kind"] == "attachment"))
        output += geometry_fingerprint(part) + struct.pack("<6i", *bounds)
    first = 0
    for case in cases:
        duration = Fraction(case["source_duration_s"]) * 30 * 65536
        duration_q16 = -(-duration.numerator // duration.denominator)
        require((case["frames"] - 2) * 65536 < duration_q16 <= (case["frames"] - 1) * 65536,
                "CONTENT_CLIP_DURATION")
        output += struct.pack("<4I", first, case["frames"], case["source_loop_mode"], duration_q16)
        output += hashlib.sha256(case["id"].encode()).digest()
        first += case["frames"]
    for case in cases:
        output += np.ascontiguousarray(case["matrices"], dtype="<f4").tobytes()
    for case in cases:
        output += np.ascontiguousarray(case["grounding"], dtype="<f4").tobytes()
    output += b"UGAEND01"
    return bytes(output), presentation_budget(parts, len(cases), scalars)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "proof", "plan", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("source", "proof", "plan"):
        parser.add_argument("--" + name + "-sha256", required=True)
    parser.add_argument("--import-archive", type=Path)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "CONTENT_OUTPUT_EXISTS")
    proof = read_json(args.proof, args.proof_sha256)
    plan = read_json(args.plan, args.plan_sha256, 65536)
    cases, unions, pins = extract(args.source, args.source_sha256, proof, plan, args.import_archive)
    image, budget = encode(cases, plan, proof, args.source_sha256, args.proof_sha256, args.plan_sha256)
    args.out.mkdir(parents=True)
    with (args.out / "mole-worker.ugactor").open("xb") as stream:
        stream.write(image)
    report = {"schema": 1, "source_sha256": args.source_sha256, "proof_sha256": args.proof_sha256,
              "plan_sha256": args.plan_sha256, "content_sha256": hashlib.sha256(image).hexdigest(),
              "content_bytes": len(image), "frames": sum(c["frames"] for c in cases),
              "verified_source_files": pins, "clips": plan["clips"], "state_unions": unions,
              "presentation_budget": budget, "production_qualified": False,
              "producer_sources": {Path(__file__).name: file_hash(Path(__file__)),
                                   Path(envelope.__file__).name: file_hash(Path(envelope.__file__))}}
    with (args.out / "compilation.json").open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({k: report[k] for k in ("content_sha256", "content_bytes", "frames", "presentation_budget")}, indent=2))


if __name__ == "__main__":
    main()
