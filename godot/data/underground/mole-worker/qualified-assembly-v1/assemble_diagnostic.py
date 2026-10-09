#!/usr/bin/env python3
"""Append the reviewed stationary handling geometry for diagnostic paid-owner tests.

This is a create-only input encoder, not the production Catalog publisher. The
old twenty-nine rows stay byte-exact. A second source and one explicit handling
row cannot qualify payment, native consumers, World geometry or stair travel.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / "docs/validation/evidence/underground-timber-program-binding-2026-10-05"
OLD = HERE.parent / "qualified-step-v4/mole-worker.ugprof"
OLD_SHA = "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e"
ACTOR_SHA = "b94d676e999c87dd399a4dc110674620a4fbc66f0ca07e494b8bedadac683b66"
PARENT_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
PROOF_SHA = "f2f9e8e666853d046ed2bd00414302a3a34a490e4d7b4fc953c61b13551e9233"
READY_SHA = "393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462"
REVIEW_SHA = "e0533949f950953f7eb52dc76b4fa6ffbabdb8fafb70202196521a2fbe1a0281"
HEADER, ROW, BOX = struct.Struct("<8sIqIII"), struct.Struct("<18i3q2B"), struct.Struct("<7i")
CONTENT_REVISION, PROFILE_COUNT, BOX_COUNT, SOURCE_COUNT = 4, 30, 281, 2
BODY = (-409, 0, -521, 476, 840, 234)
FOOT = (-274, -1, -169, 299, 0, 174)
TOOL = (185, 379, -732, 660, 810, -249)


def need(value, code):
    if not value:
        raise ValueError(code)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def bounded(path, maximum, expected):
    need(path.is_file() and not path.is_symlink() and path.stat().st_size <= maximum,
         "ASSEMBLY_INPUT_CAPACITY")
    raw = path.read_bytes()
    need(len(raw) <= maximum and digest(raw) == expected, "ASSEMBLY_INPUT_SHA")
    return raw


def input_admission():
    """Fixed independent receipt and complete source proof cannot be caller-relabelled."""
    review = json.loads(bounded(EVIDENCE / "source-review-3/independent-acceptance.json",
                                65536, REVIEW_SHA))
    need(review["decision"] == "ACCEPTED_SOURCE_ONLY" and
         review["accepted_scope"]["continuous_stationary_source_geometry"] is True and
         review["accepted_scope"]["world_activation"] is False, "ASSEMBLY_REVIEW_SCOPE")
    for path, sha in review["source_pins"].items():
        need(not Path(path).is_absolute() and ".." not in Path(path).parts, "ASSEMBLY_INPUT_PATH")
        bounded(ROOT / path, 4 * 1024 * 1024, sha)
    bounded(HERE / "compiled-3/mole-worker.ugactor", 135328, ACTOR_SHA)
    ready_join_admission()
    proof = json.loads(bounded(HERE / "candidate-8/proof-1.json", 4 * 1024 * 1024, PROOF_SHA))
    need(proof["verified_source_files"] == 537 and proof["production_qualified"] is False,
         "ASSEMBLY_PROOF_SCOPE")
    need(len(proof["clips"]) == 3 and sum(c["intervals"] for c in proof["clips"]) == 109 and
         all(c["complete"] and c["clear"] and not c["failures"] for c in proof["clips"]),
         "ASSEMBLY_PROOF_INCOMPLETE")
    # The fixed report proves every source body vertex above the support plane;
    # only complete anatomical feet cross it after the inherited native padding.
    # Keep their full XZ enclosure. No part of the negative body is discarded.
    feet = [s["bounds_u"] for c in proof["clips"] for s in c["full_foot_support"]]
    need(tuple(min(b[a] for b in feet) for a in range(3)) == (-274, -1, -169) and
         tuple(max(b[a + 3] for b in feet) for a in range(3)) == (299, 106, 174),
         "ASSEMBLY_FOOT_UNION")
    need(all(s["source_above"] for c in proof["clips"] for s in c["full_foot_support"]),
         "ASSEMBLY_SOURCE_FLOOR")
    for part, expected in enumerate(((-409, -1, -521, 476, 840, 234), TOOL)):
        boxes = [c["parts"][part]["full_bounds_u"] for c in proof["clips"]]
        actual = tuple(min(b[a] for b in boxes) for a in range(3))
        actual += tuple(max(b[a + 3] for b in boxes) for a in range(3))
        need(actual == expected, "ASSEMBLY_COMPLETE_PART_UNION")
    need(len(proof["clips"][1]["hand_contact"]) == 2 and
         all(c["valid"] and c["vertex"] == 14014 for c in proof["clips"][1]["hand_contact"]),
         "ASSEMBLY_LEFT_PALM_CONTACT")


def ready_join_admission(parent=None, handling=None):
    """Compare actual immutable binary palettes/grounding, not pose labels or the renderer's current frame."""
    if parent is None:
        parent = bounded(HERE.parent / "evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor",
                         4 * 1024 * 1024, PARENT_SHA)
    if handling is None:
        handling = bounded(HERE / "compiled-3/mole-worker.ugactor", 135328, ACTOR_SHA)
    need(digest(parent) == PARENT_SHA and digest(handling) == ACTOR_SHA, "ASSEMBLY_READY_IMAGE")

    def pose(raw, clip, key):
        version, _, parts, clips, frames, stride = struct.unpack_from("<6I", raw, 8)
        need(raw[:8] == b"UGACNT01" and version == 1 and parts == 2 and stride == 300 and
             raw[-8:] == b"UGAEND01" and 0 <= clip < clips, "ASSEMBLY_READY_FORMAT")
        table = 184 + 72 * parts
        first, count, _, _ = struct.unpack_from("<4I", raw, table + clip * 48)
        key = count - 1 if key == -1 else key
        need(0 <= key < count and first + count <= frames, "ASSEMBLY_READY_KEY")
        at = table + clips * 48
        need(len(raw) == at + frames * (stride + 1) * 4 + 8, "ASSEMBLY_READY_CENSUS")
        index = first + key
        return raw[at + index * stride * 4:at + (index + 1) * stride * 4] + \
            raw[at + frames * stride * 4 + index * 4:at + frames * stride * 4 + (index + 1) * 4]

    ready = pose(parent, 0, 8)
    need(digest(ready) == READY_SHA and pose(parent, 12, 0) == ready and
         pose(parent, 13, -1) == ready and pose(handling, 0, 0) == ready and
         pose(handling, 2, -1) == ready, "ASSEMBLY_READY_PALETTE")
    return READY_SHA


def encode(old):
    """Preserve every original record/box, append source1 and the explicit BUILD palm role."""
    need(digest(old) == OLD_SHA and len(old) == 10502, "ASSEMBLY_OLD_SHA")
    need(HEADER.unpack_from(old) == (b"UGPROF01", 2, 3, 29, 271, 1) and
         old[32:64].hex() == PARENT_SHA and old[-8:] == b"UGPEND01", "ASSEMBLY_OLD_HEADER")
    fields = [1, 6, 0, 6, 3, 0, 54, 0, -1, -1, 0, 0, 0, 457, 271, 10, 1, 3,
              1, 0, 0, 15, 7]
    boxes = b"".join(BOX.pack(*bounds, role) for role in (0, 2, 3) for bounds in (BODY, FOOT, TOOL))
    boxes += BOX.pack(*FOOT, 1)
    at = 64 + 29 * ROW.size
    wire = HEADER.pack(b"UGPROF01", 2, CONTENT_REVISION, PROFILE_COUNT, BOX_COUNT, SOURCE_COUNT)
    wire += old[32:64] + bytes.fromhex(ACTOR_SHA) + old[64:at] + ROW.pack(*fields)
    wire += old[at:-8] + boxes + b"UGPEND01"
    need(len(wire) == 10912 and 2 * (len(wire) - 8) == 21808, "ASSEMBLY_OUTPUT_CENSUS")
    return wire


def write_candidate(out):
    need(not out.exists() and not out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    need(out.resolve().is_relative_to(HERE), "ASSEMBLY_DIAGNOSTIC_OUTPUT_ONLY")
    input_admission()
    wire = encode(bounded(OLD, 10502, OLD_SHA))
    manifest = {"schema": 1, "diagnostic_only": True, "production_qualified": False,
                "native_qualified": False, "world_activation_qualified": False,
                "certificate_flags": 15, "certificate_scope": "candidate execution only",
                "predecessor_wire_sha256": OLD_SHA, "handling_actor_sha256": ACTOR_SHA,
                "proof_sha256": PROOF_SHA, "independent_receipt_sha256": REVIEW_SHA,
                "encoder_sha256": digest(Path(__file__).read_bytes()), "wire_sha256": digest(wire),
                "content_revision": CONTENT_REVISION, "profile_count": PROFILE_COUNT,
                "box_count": BOX_COUNT, "source_count": SOURCE_COUNT, "wire_bytes": len(wire),
                "paired_bank_bytes": 21808, "paired_delta_bytes": 820,
                "unchanged_profile_rows": [0, 28], "handling_profile": 29,
                "handling_policy": 7, "handling_source": 1, "handling_revision": 1,
                "body": BODY, "negative_foot_residual": FOOT, "held_pick": TOOL,
                "timing": "existing 30-tick entry and 30-tick recovery; no WU or quantity"}
    out.mkdir(parents=True)
    (out / "mole-worker.ugprof").write_bytes(wire)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    result = write_candidate(parser.parse_args().out)
    print(json.dumps(result, indent=2))
