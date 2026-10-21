#!/usr/bin/env python3
"""Decision 2041 P-DF-1 (b): an offline feasibility probe of the accepted tool-free stair gaits at a 160 u rise.

Evidence only. It authors no row, publishes nothing and is never a source candidate for review. It answers one
question: do the accepted authors and provers (ADR 1217 M7, `author_claw_stairs.py`) succeed when the only thing
changed is the rise, 160 u instead of 128 u, the one whole-number rise between 128 and 256 that divides a level's
5,120 u (decision 2041 §2.2)?

**What is the same as M7.** The authors (`author_stair_descent.source_case`, `author_stair_motion.source_case`) with
M7's recipe values (descent: advance 256, drop 128, leading foot 360, guide 0, toe 20°; ascent: lead advance 68,
lead lift 50), the claw ready, the approved 3° right-arm swing (`author_claw_stairs.swing_arms`), and the accepted
provers: two-deck terrain (`prove_stair_terrain.prove`), the repeated flight (`prove_stair_sequence.prove`) and
self-clearance (`prove_claw_pair.self_rows`), with M7's one-body census (`author_claw_stairs.body_only`).

**The only change.** Four accepted functions whitelist the rise: `author_stair_motion.tracks` (±128, ±256),
`author_stair_descent.tracks` (−128, −256) and `prove_stair_terrain.fixture_boxes` / `validate_recipe` (±128, ±256).
This probe re-executes exactly those four function bodies in every module object that holds them (the terrain
prover is loaded twice, once by `author_claw_stairs` and once by the sequence prover), in memory, with ±160 added to
the literal tuple and nothing else changed (`widened`, which restores the original function objects on exit). Every
repository source file the probe reaches through its loaded modules is hashed before and after and must be unchanged.
As in M7's own `prove`, the sequence prover's segment and solid capacities take `prove_descent_flight`'s values.

**The fixture.** `prove_descent_flight.derivation`'s flight with the pitch changed: T0's seven parts and four
bearings moved by (0, −32 − 160k, −512k) for T_k, so T_k's top is −160(k + 1); every post keeps its foot on the
trench floor (−1,024). In a one-metre trench that is T0–T4 (T4's post is 32 u, T5's would be negative), so the flight
proves five descents L0 → T4 and five ascents back: enough to show the repeated gait, since the proof is
translation-invariant (ADR 1209: 4,044 pairs = 6 × 674). The bottom (the sill and the floor) is not probed: a 160 u
flight's floor is a full level down (decision 2041 §2.2), and that fixture belongs to full authoring.

    $PY probe_rise_160.py <out-dir> [--rise 160] [--descent-drop 128]
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import inspect
import json
from pathlib import Path
import sys
import textwrap

import author_claw_stairs as ACS

DESC, ASC, TERRAIN, SEQ, FLIGHT = ACS.DESC, ACS.ASC, ACS.TERRAIN, ACS.SEQ, ACS.FLIGHT
W, SRC = ACS.W, ACS.SRC
M7_SWING = {"right": 3, "left": 0}  # ADR 1217 M7, approved 2026-10-08.
TREADS_IN_TRENCH = 5  # T0-T4 at 160 u keep a post above the one-metre floor.
L0_TOP, T0_TOP = 0, -128


def require(value: bool, code: str) -> None:
    """Every refusal names its failed fact."""
    if not value:
        raise ValueError("RISE_PROBE_" + code)


def loaded_sources() -> list:
    """Every repository source file reachable from `author_claw_stairs` through module globals, except this probe."""
    root, seen, files, queue = SRC.ROOT.resolve(), set(), set(), [ACS]
    while queue:
        module = queue.pop()
        if id(module) in seen:
            continue
        seen.add(id(module))
        path = Path(getattr(module, "__file__", "") or "/").resolve()
        if path.is_relative_to(root) and path != Path(__file__).resolve():
            files.add(path)
        queue += [v for v in vars(module).values() if isinstance(v, type(sys)) and
                  Path(getattr(v, "__file__", "") or "/").resolve().is_relative_to(root)]
    return sorted(files)


def accepted_hashes() -> dict:
    """SHA-256 of every accepted source file this probe reaches."""
    return {str(p.relative_to(SRC.ROOT.resolve())): hashlib.sha256(p.read_bytes()).hexdigest() for p in loaded_sources()}


def widen(module, name: str, old: str, new: str) -> None:
    """Re-execute one accepted function body in its own module with one literal replaced (in memory only)."""
    text = textwrap.dedent(inspect.getsource(getattr(module, name)))
    require(text.count(old) == 1, "WIDEN_" + name.upper())
    exec(compile(text.replace(old, new), f"<rise probe: {module.__name__}.{name}>", "exec"), module.__dict__)


@contextlib.contextmanager
def widened(rise: int):
    """The four rise whitelists widened by ±rise for the block; the original function objects come back after it."""
    saved = [(module, name, getattr(module, name)) for module, name in WHITELISTS()]
    try:
        yield widen_all(rise)
    finally:
        for module, name, function in saved:
            setattr(module, name, function)


def WHITELISTS() -> list:
    """(module, function) of every rise whitelist, each terrain module object once."""
    rows = [(ASC, "tracks"), (DESC, "tracks")]
    for terrain in {id(m): m for m in (TERRAIN, SEQ.T)}.values():
        rows += [(terrain, "fixture_boxes"), (terrain, "validate_recipe")]
    return rows


def widen_all(rise: int) -> list:
    """The four rise whitelists, each gaining ±rise; returns what was widened. Call it only inside `widened`."""
    four = "(-256, -128, 128, 256)"
    wide = f"(-256, -{rise}, -128, 128, {rise}, 256)"
    edits = [(ASC, "tracks", "rise in " + four, "rise in " + wide),
             (DESC, "tracks", "rise in (-128, -256)", f"rise in (-128, -{rise}, -256)")]
    for terrain in {id(m): m for m in (TERRAIN, SEQ.T)}.values():
        edits += [(terrain, "fixture_boxes", "rise in " + four, "rise in " + wide),
                  (terrain, "validate_recipe", 'recipe["rise_u"] in ' + four, 'recipe["rise_u"] in ' + wide)]
    for module, name, old, new in edits:
        widen(module, name, old, new)
    return [f"{m.__name__}.{n}" for m, n, _, _ in edits]


def author(src: dict, rise: int, drop: int) -> dict:
    """M7's two gaits at the probe rise, with M7's approved swing; endpoints must be the ready key exactly."""
    ready, topology = ACS.ready_source(src)
    d, a = ACS.RECIPES["descent"], ACS.RECIPES["ascent"]
    cases, refusals = {}, {}
    for gait in ("descent", "ascent"):
        try:
            if gait == "descent":
                case = DESC.source_case(ready, src["topology"], topology, -rise, d["advance"], drop, d["lead_foot"],
                                        d["guide"], d["toe_degrees"])
            else:
                case = ASC.source_case(ready, src["topology"], rise, a["lead_advance"], a["lead_lift"], topology)
        except ValueError as refusal:
            refusals[gait] = str(refusal)
            continue
        case["geometry"] = [src["body"]]
        cases[gait] = ACS.swing_arms(src, case, M7_SWING)
    return {"cases": cases, "refusals": refusals}


def moved_tread(spec: dict, k: int, rise: int) -> list:
    """T0's parts moved to T_k at `rise`; a post's foot stays on the trench floor."""
    dy = (-rise - T0_TOP) - rise * k
    parts = []
    for index in FLIGHT.T0_PARTS:
        box = list(spec["parts"][index]["bounds_u"])
        moved = [box[0], box[1] + dy, box[2] - FLIGHT.RUN * k, box[3], box[4] + dy, box[5] - FLIGHT.RUN * k]
        if box[1] == FLIGHT.FLOOR_Y:
            moved[1] = FLIGHT.FLOOR_Y
            require(moved[4] > FLIGHT.FLOOR_Y, "TREAD_%d_POST_BELOW_FLOOR" % k)
        parts.append(moved)
    return parts


def fixture(spec: dict, rise: int) -> dict:
    """L0 and T0-T4 at `rise` with their bearings and the trench; deck ordinals and segments for both gaits."""
    solids = [p["bounds_u"] for p in spec["parts"] if p["id"] not in FLIGHT.T0_PARTS]
    solids += [b["bounds_u"] for b in spec["natural_bearings"] if b["part"] not in FLIGHT.T0_PARTS]
    decks = [0]
    for k in range(TREADS_IN_TRENCH):
        decks.append(len(solids))
        solids += moved_tread(spec, k, rise) + FLIGHT.bearings(spec, k)
    solids += FLIGHT.trench(spec, FLIGHT.CUT_ROWS)
    require([solids[d][4] for d in decks] == [L0_TOP] + [-rise * (k + 1) for k in range(TREADS_IN_TRENCH)],
            "DECK_TOPS")
    descent = [{"origin_u": [0, -rise * k, FLIGHT.DESCENT_START[2] - FLIGHT.RUN * k], "quarter_turn": 0,
                "support_solids": [decks[k], decks[k + 1]]} for k in range(TREADS_IN_TRENCH)]
    ascent = [{"origin_u": [0, -rise * (j + 1), FLIGHT.ASCENT_START[2] - FLIGHT.RUN * j], "quarter_turn": 2,
               "support_solids": [decks[j + 1], decks[j]]} for j in reversed(range(TREADS_IN_TRENCH))]
    return {"solids": solids, "segments": {"descent": descent, "ascent": ascent}}


def prove(src: dict, cases: dict, rise: int) -> dict:
    """Terrain, flight and self-clearance per gait, as M7's `prove` (without the bottom)."""
    parts, topology = [src["body"]], [[src["triangles"]]]
    flight = fixture(FLIGHT.read_prefix(), rise)
    SEQ.MAX_SEGMENTS, SEQ.MAX_SOLIDS = FLIGHT.MAX_SEGMENTS, FLIGHT.MAX_SOLIDS
    report = {}
    for gait, case in cases.items():
        ACS.program_ok(case, parts)
        recipe = case["stair_recipe"]
        rows = {}
        try:
            with ACS.body_only():
                terrain = TERRAIN.prove(case, parts, topology, SRC.ROOT_BOUNDS, recipe)
            terrain = json.loads(json.dumps(terrain, default=str))
            rows["terrain"] = ACS.summary(terrain)
            if terrain["clear"]:
                fix = {"schema": 1, "engineering_only": True, "rise_u": recipe["rise_u"],
                       "solids_u": flight["solids"], "segments": flight["segments"][gait]}
                with ACS.body_only():
                    rows["flight"] = ACS.summary(SEQ.prove(case, parts, topology, SRC.ROOT_BOUNDS, recipe, terrain,
                                                           fix))
        except ValueError as refusal:
            rows["refused"] = str(refusal)
        selfrows = ACS.self_clear(src, case, ACS.PAIRPROOF.classes(src))
        rows["self"] = {side: value["clear"] for side, value in selfrows.items() if isinstance(value, dict)
                        and "clear" in value}
        report[gait] = rows
        print(json.dumps({gait: rows}, default=str)[:600], flush=True)
    return report


def verdict(authored: dict, report: dict) -> bool:
    """Clear only when both gaits author and every proof that ran is clear."""
    if authored["refusals"] or set(report) != {"descent", "ascent"}:
        return False
    for rows in report.values():
        if "refused" in rows or not rows["terrain"]["clear"] or not rows.get("flight", {}).get("clear", False):
            return False
        if not all(rows["self"].values()):
            return False
    return True


def main() -> int:
    """Widen, author, prove, write one result file; the accepted files must be unchanged."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--rise", type=int, default=160)
    parser.add_argument("--descent-drop", type=int, default=ACS.RECIPES["descent"]["drop"])
    args = parser.parse_args()
    require(not args.out.exists() and args.rise in (128, 160), "ARGUMENTS")
    before = accepted_hashes()
    src = ACS.SEAT.corrected_source()
    with widened(args.rise) if args.rise != 128 else contextlib.nullcontext([]) as names:
        authored = author(src, args.rise, args.descent_drop)
        report = prove(src, authored["cases"], args.rise)
    require(accepted_hashes() == before, "ACCEPTED_SOURCE_DRIFT")
    clear = verdict(authored, report)
    record = {"schema": 1, "decision": "2041 P-DF-1 (b)", "probe_only": True, "production_qualified": False,
              "rise_u": args.rise, "run_u": 512, "descent_drop_u": args.descent_drop, "arm_swing_degrees": M7_SWING,
              "widened_whitelists": names, "authoring_refusals": authored["refusals"], "proofs": report,
              "clear": clear, "accepted_sources_unchanged": before,
              "probe_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    args.out.mkdir(parents=True)
    (args.out / "result.json").write_text(json.dumps(record, indent=1, default=str) + "\n")
    print(json.dumps({"rise_u": args.rise, "clear": clear, "refusals": authored["refusals"]}))
    return 0 if clear else 2


if __name__ == "__main__":
    sys.exit(main())
