#!/usr/bin/env python3
"""Create-only content-9 mole profile publication `qualified-claw-approach-v10/` (ADR 1217 step 4e). Data only.

Content 9 is content 8 (`qualified-claw-split-v9`, unused) with the narrow tool-free approach and retreat rows
Brendan approved in step 4d, on the claw source 4:

- **Rows 0-42** keep content 8's words and boxes (42 is source 4's canonical-ground WALK).
- **43-46** READY_FORWARD (approach) at yaws 0, 16384, 32768 and 49152, and **47-50** READY_BACKWARD (retreat) at
  the same yaws. Their words are row 42's with YAW_EXACT, the heading and the policy: pick rows 2-9 without the
  tool. Their boxes are `claw-approach-v1/approach.json`'s, copied as derived.
- **51-58** are content 8's dig/tap rows 43-50, and **59** its paw handling row 51 (source 5). Profiles sorts
  rows by key within each source, and the WALK rows must precede source 4's WORK rows, so these rows move by 8.
  Content 8 has no consumer, and their words and boxes are unchanged.

**Fade window (Brendan, step 4d).** The READY fade at the end of an approach or retreat may start only from walk
keys 0-27 or 38-43. A mole in keys 28-37 walks on to key 38 first. The publisher checks this against the
derivation record: every unresolved self-clearance pair there lies in a fade from keys 28-37, and every other
handoff and both bearers are clear. The window is published in the accessor
(`CLAW_FADE_BLOCKED_FIRST`/`LAST`, `CLAW_FADE_RESUME_KEY`) for the source program to read.

**Ground paces.** Each narrow row gets a RATE_GROUND_CAP row, as pick rows 2-9 have. They reuse the adopted Movement
cap; no constant is new.

    python3 godot/data/underground/mole-worker/publish_claw_approach_runtime.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys

import publish_claw_runtime as PUB7
import publish_claw_split_runtime as PUB8
import publish_haul_runtime as H

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-claw-split-v9"
OUTPUT = HERE / "qualified-claw-approach-v10"
OLD_WIRE_SHA = "2b79e39bc21b7bbfaa4703d3bf5a111c8f50c70ad25dc4918c1f80661b56bb61"
OLD_GROUND_SHA = "fb749b773a108c8d94b9013444889b54184b0313cdfabddcb946e374ec330feb"
OLD_MOTION_SHA = "19b2b71c67d8339a33ebe5d211a30b7f5fa21e016054100c7fd43e1a937e4324"
APPROACH = (HERE / "claw-work-v1/evidence/claw-approach-v1/approach.json",
            "ad74ec3fde23a9152f9293a2df0d7f7bacc2cbd9be4ec1a7818633a0bcb6b4b6")
OLD_COUNTS, NEW_REVISION, CLAW_SOURCE = (8, 52, 477, 6), 9, 4
F_SOURCE, F_YAW_KIND, F_YAW, F_FIRST_BOX, F_POLICY = 0, 10, 11, 14, 22
WALK_TEMPLATE, KEEP = 42, 43
POLICIES = {"READY_FORWARD": 1, "READY_BACKWARD": 2}
FADE_BLOCKED, FADE_RESUME, READY_KEY, WALK_KEYS = (28, 37), 38, 8, 45
APPROACH_ROWS, RETREAT_ROWS = (43, 44, 45, 46), (47, 48, 49, 50)
DIG_ROWS, TAP_ROWS, HANDLING_ROW = (51, 53, 55, 57), (52, 54, 56, 58), 59
YAWS = (0, 16384, 32768, 49152)


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("CLAW_APPROACH_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def read_approach() -> dict:
    """The pinned derivation record, checked against Brendan's fade window."""
    raw = APPROACH[0].read_bytes()
    require(sha(raw) == APPROACH[1], "INPUT_APPROACH")
    record = json.loads(raw)
    proofs = record["proofs"]
    blocked = range(FADE_BLOCKED[0], FADE_BLOCKED[1] + 1)
    require(all(row["clear"] for row in proofs["bearers"].values()), "BEARERS")
    require(proofs["self_clearance"]["handoffs"] == WALK_KEYS and record["ready_key"] == READY_KEY, "HANDOFFS")
    require(all(row["handoff"] == "walk" and row["interval"][0] in blocked
                for row in proofs["self_clearance"]["unresolved"]), "FADE_WINDOW")
    return record


def narrow_rows(fields: list, rows: list, record: dict) -> list:
    """(fields, boxes) of the eight narrow rows, in record order: forward then backward, four yaws each."""
    template = list(fields[WALK_TEMPLATE])
    require(template[F_SOURCE] == CLAW_SOURCE and template[4] == 1 and template[6] == -1 and
            template[F_YAW_KIND] == 1 and template[F_POLICY] == 6, "WALK_TEMPLATE")
    result = []
    for row in record["rows"]:
        require(row["mode"] == 1 and row["tool"] == -1 and row["states"] == template[13], "NARROW_RECORD")
        words = list(template)
        words[F_YAW_KIND], words[F_YAW], words[F_POLICY] = 0, row["yaw"], POLICIES[row["policy"]]
        result.append((words, PUB7.role_boxes(row["roles"])))
    require([(w[F_POLICY], w[F_YAW]) for w, _ in result] == [(p, y) for p in (1, 2) for y in YAWS], "NARROW_ORDER")
    return result


def encode(digests: list, fields: list, rows: list) -> bytes:
    """A complete UGPROF01 wire at revision 9; first-box indices recomputed in row order."""
    wire = PUB7.HEADER.pack(b"UGPROF01", 2, NEW_REVISION, len(fields), sum(map(len, rows)), len(digests))
    wire += b"".join(digests)
    first, packed, boxes = 0, b"", b""
    for row_fields, row_boxes in zip(fields, rows):
        row_fields = list(row_fields)
        row_fields[F_FIRST_BOX], row_fields[15] = first, len(row_boxes)
        packed += PUB7.ROW.pack(*row_fields)
        boxes += b"".join(PUB7.BOX.pack(*box) for box in row_boxes)
        first += len(row_boxes)
    return wire + packed + boxes + b"UGPEND01"


def build_wire(record: dict) -> tuple:
    """Rows 0-42, the eight narrow rows, then content 8's rows 43-51."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    new_fields, new_rows = [list(f) for f in fields[:KEEP]], [list(r) for r in rows[:KEEP]]
    for words, boxes in narrow_rows(fields, rows, record):
        new_fields.append(words)
        new_rows.append(boxes)
    new_fields += [list(f) for f in fields[KEEP:]]
    new_rows += [list(r) for r in rows[KEEP:]]
    return encode(digests, new_fields, new_rows), old


def check(old: bytes, new: bytes) -> None:
    """Sources unchanged; rows 0-42 unchanged; content 8's 43-51 are 51-59; source 4's block key-sorted."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 60 and digests == old_digests, "NEW_COUNTS")
    same = lambda a, b: [v for k, v in enumerate(a) if k != F_FIRST_BOX] == [v for k, v in enumerate(b) if k != F_FIRST_BOX]
    for new_index, old_index in list(zip(range(KEEP), range(KEEP))) + list(zip(range(51, 60), range(43, 52))):
        require(same(fields[new_index], old_fields[old_index]) and rows[new_index] == old_rows[old_index],
                "ROW_PRESERVED")
    block = [f for f in fields if f[F_SOURCE] == CLAW_SOURCE]
    keys = [tuple(f[1:10]) + (f[16],) for f in block]
    require(len(block) == 17 and keys == sorted(keys) and all(f[6] == -1 for f in block), "KEY_ORDER")


def build_ground(old: bytes) -> bytes:
    """Content 8's sixteen ground caps plus one per narrow row; revision 9; source binding unchanged."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    head = struct.unpack_from("<8sIq7I3q", old)
    require(head == (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 16, 8, 1, CLAW_SOURCE) and len(old) == 720, "GROUND_HEADER")
    paces = [H.PACE.unpack_from(old, 136 + 36 * r) for r in range(16)]
    require(paces[-1][0] == 42 and all(p[1:] == (-1, 0, 1, 1, 0, 0, 1) for p in paces), "GROUND_ROWS")
    out = bytearray(old[:-8])
    profiles = APPROACH_ROWS + RETREAT_ROWS
    struct.pack_into("<I", out, 44, 16 + len(profiles))
    struct.pack_into("<q", out, 48, NEW_REVISION)
    for profile in profiles:
        out += H.PACE.pack(profile, *paces[0][1:])
    return bytes(out) + b"UGCEND01"


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Content 8's rule: profile revisions, wire digest and input manifest digest only."""
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (8,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    ranges = [(16, 24), (H.I64_AT + 8, H.I64_AT + 24), (H.BYTE_AT + 160, H.BYTE_AT + 192),
              (H.BYTE_AT + 384, H.BYTE_AT + 416)]
    require(all(a == b or any(lo <= i < hi for lo, hi in ranges) for i, (a, b) in enumerate(zip(motion, out))),
            "MOTION_FOREIGN_DELTA")
    return bytes(out)


def row_constants() -> str:
    """Row IDs and the fade window, for the source program and the certificate."""
    pack = lambda values: "[" + ", ".join(map(str, values)) + "]"
    return "\n".join([
        f"const CLAW_WALK_ROW: int = {WALK_TEMPLATE}",
        f"const CLAW_APPROACH_ROWS: PackedInt32Array = {pack(APPROACH_ROWS)}",
        f"const CLAW_RETREAT_ROWS: PackedInt32Array = {pack(RETREAT_ROWS)}",
        f"const CLAW_DIG_ROWS: PackedInt32Array = {pack(DIG_ROWS)}",
        f"const CLAW_TAP_ROWS: PackedInt32Array = {pack(TAP_ROWS)}",
        f"const PAW_HANDLING_ROW: int = {HANDLING_ROW}",
        f"const CLAW_READY_KEY: int = {READY_KEY}",
        f"const CLAW_WALK_KEYS: int = {WALK_KEYS}",
        "## Brendan, ADR 1217 step 4d: the READY fade never starts from these walk keys (inclusive).",
        f"const CLAW_FADE_BLOCKED_FIRST: int = {FADE_BLOCKED[0]}",
        f"const CLAW_FADE_BLOCKED_LAST: int = {FADE_BLOCKED[1]}",
        f"const CLAW_FADE_RESUME_KEY: int = {FADE_RESUME}"])


def accessor(old_text: str, wire_sha: str) -> str:
    """Content 8's accessor with the new wire, the row/fade constants and current consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_claw_split_runtime.py (ADR 1217 step 4c). Do not edit.",
                        "## Generated by publish_claw_approach_runtime.py (ADR 1217 step 4e). Do not edit.")
    require(text.count("const ACTOR_SHA:") == 1, "ACCESSOR_SHAPE")
    text = text.replace("const ACTOR_SHA:", row_constants() + "\nconst ACTOR_SHA:", 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    digests = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:digests.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[digests.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    record = read_approach()
    wire, old = build_wire(record)
    check(old, wire)
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes())
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire))
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": "1217", "content_revision": NEW_REVISION, "profile_count": count,
                "box_count": boxes, "source_count": 6, "wire_sha256": sha(wire), "wire_bytes": len(wire),
                "paired_bank_bytes": 2 * (len(wire) - 8),
                "rows": {"42": "WALK canonical ground (source 4)", "43-46": "READY_FORWARD narrow approach, yaws 0-49152",
                         "47-50": "READY_BACKWARD narrow retreat, yaws 0-49152", "51/53/55/57": "dig",
                         "52/54/56/58": "tap", "59": "paw handling (source 5)"},
                "moved_from_content_8": {"43-51": "51-59 (words and boxes unchanged)"},
                "fade_window": {"blocked_walk_keys": list(FADE_BLOCKED), "resume_key": FADE_RESUME,
                                "decision": "Brendan, ADR 1217 step 4d: fade only from clear frames"},
                "superset_of": {"wire_sha256": OLD_WIRE_SHA, "rows": "0-42"},
                "inputs": {str(APPROACH[0].relative_to(ROOT)): APPROACH[1]},
                "ground_sha256": sha(ground), "ground_pace_profiles": list(APPROACH_ROWS + RETREAT_ROWS),
                "motion_sha256": sha(motion), "motion_inputs": pins, "motion_numerical_input_sha256": numerical,
                "runtime_admitted": False,
                "not_qualified": ["source programs and Routes dispatch for sources 4/5 (ADR 1217 step 5)",
                                  "presentation of sources 4/5", "consumer renewal and activation"]}
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def main() -> int:
    """Create the publication exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), {n: sha(r)[:12] for n, r in outputs.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
