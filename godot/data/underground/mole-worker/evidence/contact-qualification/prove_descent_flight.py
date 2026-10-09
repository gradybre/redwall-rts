#!/usr/bin/env python3
"""ADR 1209 step 2: the unchanged 128u descent and ascent, repeated over a derived T0-family flight.

The accepted gaits (`stair-descent-v7` case0, `stair-motion-v15` case0) start and end in the same ready pose,
and each moves its root exactly (0, -128, -512) or (0, 128, 512). A flight of treads that repeats T0's
geometry at that pitch is therefore walked by repeating the same gait, translated. This script derives the
flight from the first-entry prefix artifact alone and checks the gait over it with the accepted, unchanged
sequence prover (`prove_stair_sequence.prove`):

- tread k (k = 1..5) is T0's seven parts translated by (0, -128k, -512k), with every post still standing on
  the cut floor at y = -1024, so only the posts get shorter. Each post keeps its natural bearing below the
  floor. Tread 6 would need a post of height -64, so the derivation refuses it: it is not a T0-family tread;
- the trench is the existing two cut groups plus three more whole cube rows (z down to -6144), the rows that
  T2..T6 occupy. Its floor slab, side walls and end walls are natural solids in the fixture;
- descent segments k = 0..5 run L0 -> T0 -> ... -> T5; ascent segments run T5 -> ... -> T0 -> L0.

Only the prover's segment and solid capacities are raised (4 -> 8 segments, 32 -> 96 solids). Every proof
rule, tolerance and source check is the accepted one. The proof re-reads the accepted source closure; pinned
project scripts that have changed since the actor image was captured are restored from the git commit whose
bytes match their pinned SHA-256 (ADR 1205), and the restored commits are recorded in the output.

    PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
    $PY godot/data/underground/mole-worker/evidence/contact-qualification/prove_descent_flight.py \
        godot/data/underground/mole-worker/evidence/contact-qualification/descent-flight-v1
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("accepted_stair_sequence", HERE / "prove_stair_sequence.py")
SEQ = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SEQ)
P = SEQ.P
ROOT = P.ROOT
PREFIX = ROOT / "docs/design/underground-planning/first-entry-prefix-v1.json"
PREFIX_SHA = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"
FLOOR_Y = -1024
RISE, RUN = 128, 512
T0_PARTS = range(7, 14)
FAMILY_TREADS = 5
CUT_ROWS = 6
BEARING_DEPTH = 128
GAITS = {
    "descent": ("stair-descent-v7", "stair-descent-v7/terrain-v1.json",
                "a79a7f4fe233cf3ff2172173631cfde2d8392edc50e355b7082e0370f806c7ae", -RISE),
    "ascent": ("stair-motion-v15", "stair-motion-v15/terrain-v3.json",
               "caef0c5208a06a15d62f63b86a12673179dee929506a527dfac918e1077d9258", RISE),
}
DESCENT_START = (0, 0, -1879)
ASCENT_START = (0, -128, -2217)
MAX_SEGMENTS, MAX_SOLIDS = 8, 96


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed derivation fact."""
    if not value:
        raise ValueError("DESCENT_FLIGHT_" + code)


def read_prefix() -> dict:
    """The prefix artifact is the only geometry source; it is pinned by SHA-256."""
    raw = PREFIX.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == PREFIX_SHA, "PREFIX_SHA")
    spec = json.loads(raw)
    require([p["id"] for p in spec["parts"]] == list(range(14)) and spec["sequence_fixture"]["rise_u"] == -RISE,
            "PREFIX_SHAPE")
    return spec


def tread(spec: dict, k: int) -> list:
    """T0's parts translated by k pitches; a post keeps its foot on the cut floor, so only its height changes."""
    parts = []
    for index in T0_PARTS:
        box = list(spec["parts"][index]["bounds_u"])
        moved = [box[0], box[1] - RISE * k, box[2] - RUN * k, box[3], box[4] - RISE * k, box[5] - RUN * k]
        if box[1] == FLOOR_Y:
            moved[1] = FLOOR_Y
            require(moved[4] > FLOOR_Y, "TREAD_%d_POST_BELOW_FLOOR" % k)
        parts.append(moved)
    return parts


def bearings(spec: dict, k: int) -> list:
    """Each post's retained natural bearing moves with its post in z only; it stays below the cut floor."""
    rows = [b["bounds_u"] for b in spec["natural_bearings"] if b["part"] in T0_PARTS]
    require(len(rows) == 4 and all(b[1] == FLOOR_Y - BEARING_DEPTH and b[4] == FLOOR_Y for b in rows), "BEARINGS")
    return [[b[0], b[1], b[2] - RUN * k, b[3], b[4], b[5] - RUN * k] for b in rows]


def trench(spec: dict, rows: int) -> list:
    """Natural solids around the cut: the floor slab, both side walls and both end walls."""
    cuts = [g["bounds_u"] for g in spec["cut_groups"]]
    x0, x1, near = cuts[0][0], cuts[0][3], cuts[0][5]
    far = near - 1024 * rows
    require(all(c[0] == x0 and c[3] == x1 and c[1] == FLOOR_Y and c[4] == 0 for c in cuts) and cuts[1][2] > far,
            "TRENCH")
    low = FLOOR_Y - BEARING_DEPTH
    return [[x0, low, far, x1, FLOOR_Y, near], [x0 - 1024, low, far, x0, 0, near], [x1, low, far, x1 + 1024, 0, near],
            [x0 - 1024, low, far - 1024, x1 + 1024, 0, far], [x0 - 1024, low, near, x1 + 1024, 0, near + 1024]]


def derivation(spec: dict, rows: int = CUT_ROWS) -> dict:
    """All solids, with the deck ordinal of L0 and of every tread, and the refused sixth tread."""
    solids = [p["bounds_u"] for p in spec["parts"]] + [b["bounds_u"] for b in spec["natural_bearings"]]
    decks = [0, 7]
    for k in range(1, FAMILY_TREADS + 1):
        decks.append(len(solids))
        solids += tread(spec, k) + bearings(spec, k)
    solids += trench(spec, rows)
    try:
        tread(spec, FAMILY_TREADS + 1)
        sixth = "accepted"
    except ValueError as refusal:
        sixth = str(refusal)
    tops = [solids[d][4] for d in decks]
    require(tops == [-RISE * k for k in range(FAMILY_TREADS + 2)], "DECK_TOPS")
    return {"solids": solids, "decks": decks, "sixth_tread": sixth}


def segments(decks: list, gait: str) -> list:
    """Consecutive translated gaits: each starts where the previous one ended, on the shared deck."""
    rows = []
    for k in range(FAMILY_TREADS + 1):
        if gait == "descent":
            origin = [DESCENT_START[0], DESCENT_START[1] - RISE * k, DESCENT_START[2] - RUN * k]
            rows.append({"origin_u": origin, "quarter_turn": 0, "support_solids": [decks[k], decks[k + 1]]})
        else:
            j = FAMILY_TREADS - k
            origin = [ASCENT_START[0], ASCENT_START[1] - RISE * j, ASCENT_START[2] - RUN * j]
            rows.append({"origin_u": origin, "quarter_turn": 2, "support_solids": [decks[j + 1], decks[j]]})
    return rows


def bottom(spec: dict, rows: int) -> tuple:
    """Candidate T6 (ADR 1209 option D1-a): T0's deck and bearers six pitches down, the bearers cut to the floor.

    Returns the solids and the two final descent segments, T5 -> T6 and T6 -> the cut floor, for a trench of
    `rows` cube rows. This is a decision diagnostic: T6's form and the trench length are Brendan's choices.
    """
    flight = derivation(spec, rows)
    solids, decks = flight["solids"], flight["decks"]
    k = FAMILY_TREADS + 1
    sill = [[b[0], b[1] - RISE * k, b[2] - RUN * k, b[3], b[4] - RISE * k, b[5] - RUN * k]
            for b in (spec["parts"][i]["bounds_u"] for i in T0_PARTS[:3])]
    for bearer in sill[1:]:
        bearer[1] = FLOOR_Y
    require(all(b[1] < b[4] for b in sill), "SILL")
    decks.append(len(solids))
    solids += sill
    decks.append(len(solids) - 3 - 5)  # the trench floor slab, the first trench solid
    require(solids[decks[-1]][4] == FLOOR_Y and solids[decks[-1]][0] == -1024, "FLOOR_SLAB")
    rows_out = [{"origin_u": [DESCENT_START[0], DESCENT_START[1] - RISE * j, DESCENT_START[2] - RUN * j],
                 "quarter_turn": 0, "support_solids": [decks[j], decks[j + 1]]} for j in (k, k + 1)]
    return solids, rows_out


def git_blob_with(path: str, expected: str) -> tuple:
    """The newest commit whose tracked bytes at `path` hash to the pinned SHA-256 (ADR 1205)."""
    commits = subprocess.check_output(["git", "rev-list", "--all", "--", path], cwd=ROOT, text=True).split()
    require(0 < len(commits) <= 4096, "HISTORY_CENSUS:" + path)
    seen = set()
    for commit in commits:
        blob = subprocess.run(["git", "rev-parse", "%s:%s" % (commit, path)], cwd=ROOT, capture_output=True, text=True)
        if blob.returncode or blob.stdout in seen:
            continue
        seen.add(blob.stdout)
        raw = subprocess.check_output(["git", "cat-file", "blob", blob.stdout.strip()], cwd=ROOT)
        if hashlib.sha256(raw).hexdigest() == expected:
            return commit, raw
    raise ValueError("DESCENT_FLIGHT_HISTORICAL_SOURCE_MISSING:" + path)


def historical_snapshot(metadata: dict, snapshot: Path) -> dict:
    """The accepted snapshot rule, with every drifted tracked script restored from its matching commit."""
    restored = {}
    for row in [metadata["manifest"], *metadata["sources"]]:
        name = row["path"]
        if not name.startswith("res://") or name.startswith("res://.godot/imported/") or \
                (name.startswith("res://demo/assets/") and name.endswith(".import")):
            continue
        destination = (snapshot / name[6:]).resolve()
        source = (ROOT / "godot" / name[6:]).resolve()
        require(destination.is_relative_to(snapshot) and source.is_relative_to(ROOT / "godot"), "SNAPSHOT_PATH")
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            continue
        require(source.is_file(), "SNAPSHOT_MISSING:" + name)
        if hashlib.sha256(source.read_bytes()).hexdigest() == row["sha256"]:
            os.link(source, destination)
            continue
        commit, raw = git_blob_with("godot/" + name[6:], row["sha256"])
        destination.write_bytes(raw)
        restored[name] = {"commit": commit, "sha256": row["sha256"]}
    return restored


def prove_gait(name: str, fixture_path: Path, source: tuple) -> dict:
    """The accepted prover, unchanged, over the derived multi-segment fixture."""
    preview, base_path, base_sha, rise = GAITS[name]
    image = HERE / preview / "mole-worker.ugactor"
    compilation = SEQ.M.W.read_record(HERE / preview / "compilation.json")
    _, parts, _, topology, world_roots, _, _ = source
    cases = SEQ.S.read_image(image, compilation["content_sha256"], parts)
    with image.open("rb") as stream:
        header = stream.read(184)
    candidate = P.content.read_json(HERE / preview / "candidate.json", header[120:152].hex(), 1048576)
    base = P.content.read_json(HERE / base_path, base_sha, 2 * 1048576)
    fixture = P.content.read_json(fixture_path, P.content.file_hash(fixture_path), 65536)
    recipes = [row for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    choices = [(case, recipe) for case, recipe in zip(cases, recipes) if recipe["rise_u"] == rise]
    rows = [row for row in base["clips"] if row["rise_u"] == rise]
    require(len(choices) == len(rows) == 1 and base.get("content_sha256") == compilation["content_sha256"], "CASE")
    case, recipe = choices[0]
    result = SEQ.prove(case, parts, topology, world_roots, recipe, rows[0], fixture)
    return {"gait": name, "preview": preview, "content_sha256": compilation["content_sha256"],
            "baseline_proof": base_path, "baseline_proof_sha256": base_sha, "result": result}


def write_new(path: Path, value: dict) -> None:
    """Create-only JSON output."""
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def producer_pins() -> dict:
    """SHA-256 of this script, the unchanged provers and the prefix artifact."""
    return {str(Path(p).resolve().relative_to(ROOT)): P.content.file_hash(Path(p))
            for p in (__file__, SEQ.__file__, SEQ.T.__file__, PREFIX)}


def run_bottom(out: Path, rows: int) -> int:
    """Decision diagnostic: the last two descents onto candidate T6 and the floor, for one trench length."""
    solids, rows_out = bottom(read_prefix(), rows)
    out.mkdir()
    path = out / "descent-fixture.json"
    write_new(path, {"schema": 1, "engineering_only": True, "rise_u": -RISE, "solids_u": solids, "segments": rows_out})
    report = prove_gait("descent", path, SEQ.M.read_actual_source())
    write_new(out / "proof.json", {"schema": 1, "decision": "1209", "producer_sources": producer_pins(),
              "cut_rows": rows, "t6_candidate": "T0 deck and bearers six pitches down; bearers cut to the floor; no posts",
              "scope": "decision diagnostic only: T6's form and the trench length are not adopted",
              "production_qualified": False, "gaits": {"descent": report}})
    print(json.dumps({"cut_rows": rows, "clear": report["result"]["clear"],
                      "unresolved": len(report["result"]["unresolved"])}), flush=True)
    return 0 if report["result"]["clear"] else 2


def main() -> int:
    """Derive the flight, write both fixtures, then prove both gaits over them (or run the bottom diagnostic)."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--bottom-rows", type=int, choices=(6, 7))
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    SEQ.MAX_SEGMENTS, SEQ.MAX_SOLIDS = MAX_SEGMENTS, MAX_SOLIDS
    SEQ.M.W.snapshot_sources = historical_snapshot
    if args.bottom_rows:
        return run_bottom(args.out, args.bottom_rows)
    spec = read_prefix()
    flight = derivation(spec)
    args.out.mkdir()
    write_new(args.out / "derivation.json", {"schema": 1, "decision": "1209", "prefix_sha256": PREFIX_SHA,
              "rise_u": RISE, "run_u": RUN, "family_treads": FAMILY_TREADS, "cut_rows": CUT_ROWS,
              "deck_solids": flight["decks"], "sixth_tread": flight["sixth_tread"], "solids_u": flight["solids"]})
    source = SEQ.M.read_actual_source()
    reports = {}
    for name in ("descent", "ascent"):
        rise = GAITS[name][3]
        fixture = {"schema": 1, "engineering_only": True, "rise_u": rise, "solids_u": flight["solids"],
                   "segments": segments(flight["decks"], name)}
        path = args.out / (name + "-fixture.json")
        write_new(path, fixture)
        reports[name] = prove_gait(name, path, source)
        print(json.dumps({"gait": name, "clear": reports[name]["result"]["clear"],
                          "unresolved": len(reports[name]["result"]["unresolved"]),
                          "pairs": reports[name]["result"]["pairs"]}), flush=True)
    write_new(args.out / "proof.json", {"schema": 1, "decision": "1209", "producer_sources": producer_pins(),
              "historical_source_snapshot": source[6], "verified_source_files": source[5],
              "capacities": {"segments": MAX_SEGMENTS, "solids": MAX_SOLIDS},
              "scope": "unchanged source triangles of both accepted 128u gaits, repeated over the derived T0-family "
                       "flight L0..T5 and its trench; source-local yaw0, no pace, Location, route or installed support",
              "production_qualified": False, "gaits": reports})
    return 0 if all(r["result"]["clear"] for r in reports.values()) else 2


if __name__ == "__main__":
    sys.exit(main())
