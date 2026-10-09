#!/usr/bin/env python3
"""ADR 1209 step 4: a short-reach adze fitting tap for installing tread T_k from the tread above it.

The accepted fitting source (`install-source-v4`, ADR 1116 record) taps the broad adze end (vertex 478) onto a
billed bearer laid across the previous deck's forward top edge, 448 u ahead of a station on L0. On a 512 u
tread that station does not fit (ADR 1209). This author keeps the accepted recipe unchanged and only moves
the contact point and the station:

- **Workpiece.** T_k's left bearer, quarter-turned exactly as part 8 is for T0, lies across T_{k-1}'s forward
  top edge: station-local [-256, 0, -d, 256, 128, -d + 128]. The contact plane stays y = 128.
- **Station.** On T_{k-1} at x = 0, yaw 0, a distance d behind T_{k-1}'s far edge. The compact ready pose's own
  vertices bound d: below y = 128 the body reaches z = -168 (it must clear the workpiece's back face, -d + 128),
  and in the band y in [64, 128) it reaches z = +188 (it must clear the riser of the deck behind, 512 - d). So
  296 <= d <= 323; the author uses the midpoint, d = 310.
- **Motion.** `author_install_source.poll_pose`'s solver unchanged: the planted lower body, unchanged arm links,
  the real grip, the poll lowered from y = 208 to 126 over 17 keys, mirrored to 33; the planted entry (31 keys)
  and its exact reverse as recovery. Two things are new, both recorded per candidate: the upper body is pitched
  back about Spine02 (`pitched_ready`), and the handle lean may reach 60 degrees (v4 stopped at 50). Standing
  upright, no lean or azimuth clears the forearm or snout at this short reach.

The fixture is station-local and covers every tread T1..T6's installation at once: the support deck (any
T_{k-1}), conservative side boxes that contain its bearers and posts, the deck behind with the same
conservative sides (a superset of L0's and of any tread's, ADR 1209), and the workpiece. The proofs are the
accepted ones from `install-source-proof-v4/prove_candidate.py`, unchanged: the exact adze crossing patch, the
active tool below the target plane, body self-clearance and the complete world proof.

    PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
    $PY .../author_tread_install.py <out> --x-u 128 --z-u -278 --lean-degrees 50 --azimuth-degrees 30 --torso-degrees -30
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
PROOF_SPEC = importlib.util.spec_from_file_location("accepted_install_proof",
                                                    HERE / "install-source-proof-v4" / "prove_candidate.py")
V4 = importlib.util.module_from_spec(PROOF_SPEC)
PROOF_SPEC.loader.exec_module(V4)
FLIGHT_SPEC = importlib.util.spec_from_file_location("descent_flight", HERE / "prove_descent_flight.py")
FLIGHT = importlib.util.module_from_spec(FLIGHT_SPEC)
FLIGHT_SPEC.loader.exec_module(FLIGHT)
I, M, P, S = V4.I, V4.M, V4.P, V4.S
PREFIX = HERE / "stair-sequence-prefix-v1" / "first-entry-prefix-v1.source.json"
STATION_D = 310
PLANE_U = 128
DECK_DEPTH = 512
FLOOR_LOCAL = -896  # the cut floor below T0's top, the deepest any station sits above it
POLL_HEIGHTS = (208, 126)
LEAN_DOMAIN = (25, 60)
AZIMUTH_DOMAIN = (0, 60)


class _WiderPoseInput:
    """The accepted `poll_pose` solver, unchanged, with only its input-domain guard replaced.

    v4's guard admits handle leans of 25-50 degrees and azimuths of 15-45. With the torso pitched back (see
    `pitched_ready`) clear candidates exist at 50-60 degrees (ADR 1209 step 4), so this author admits leans of
    25-60 and azimuths of 0-60, and checks that domain itself. Every other refusal is the accepted one.
    """

    def __init__(self, accepted):
        self._accepted = accepted

    def __getattr__(self, name):
        return getattr(self._accepted, name)

    def require(self, value, code):
        if code != "INSTALL_POSE_INPUT":
            self._accepted.require(value, code)


def poll_pose(ready: dict, tool: dict, rig: dict, point: list, lean: int, azimuth: int) -> tuple:
    """Call the accepted solver under this author's own lean/azimuth domain."""
    require(type(lean) is int and LEAN_DOMAIN[0] <= lean <= LEAN_DOMAIN[1] and type(azimuth) is int
            and AZIMUTH_DOMAIN[0] <= azimuth <= AZIMUTH_DOMAIN[1] and np.max(np.abs(point)) <= 2048, "POSE_INPUT")
    accepted = I.P
    I.P = _WiderPoseInput(accepted)
    try:
        return I.poll_pose(ready, tool, rig, point, lean, azimuth)
    finally:
        I.P = accepted


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed authoring fact."""
    if not value:
        raise ValueError("TREAD_INSTALL_" + code)


def station_bounds(ready: dict, parts: list) -> dict:
    """The compact ready body's own vertex reach that bounds d (float diagnostic; the proofs decide)."""
    body = I.G.source_positions(parts[0], ready["matrices"][8], ready["grounding"][8])
    low = body[(body[:, 1] < PLANE_U) & (np.abs(body[:, 0]) <= 256)]
    band = body[(body[:, 1] >= 64) & (body[:, 1] < 128)]
    front, back = float(low[:, 2].min()), float(band[:, 2].max())
    lowest = int(np.ceil(PLANE_U - front))
    highest = int(np.ceil(DECK_DEPTH - back)) - 1
    require(lowest <= STATION_D <= highest, "STATION_RANGE")
    return {"front_z_below_plane_u": front, "back_z_in_riser_band_u": back, "d_range_u": [lowest, highest],
            "chosen_d_u": STATION_D}


def fixture(packet: dict, d: int) -> dict:
    """Station-local solids: support deck first, the workpiece last; sides and the deck behind are supersets."""
    t0 = {row["id"]: row["bounds_u"] for row in packet["parts"]}
    shift = (0, 128, 2560 - d)
    def local(box):
        return [v + shift[a % 3] for a, v in enumerate(box)]
    deck = local(t0[7])
    require(deck == [-1024, -64, -d, 1024, 0, DECK_DEPTH - d], "SUPPORT_DECK")
    def side(low_x):
        return [low_x, FLOOR_LOCAL, -d, low_x + 128, -64, DECK_DEPTH - d]
    def behind(low_x):
        return [low_x, FLOOR_LOCAL, DECK_DEPTH - d, low_x + 128, 64, 2560 - d]
    for part in (8, 10, 11):
        require(all(side(-896)[a] <= local(t0[part])[a] and local(t0[part])[a + 3] <= side(-896)[a + 3]
                    for a in range(3)), "SIDE_SUPERSET")
    above = local(t0[0])
    require(above == [-1024, 64, DECK_DEPTH - d, 1024, 128, 2560 - d], "DECK_BEHIND")
    workpiece = [-256, 0, -d, 256, PLANE_U, -d + 128]
    solids = [deck, side(-896), side(768), above, behind(-896), behind(768), workpiece]
    labels = ["support deck T_{k-1}", "T_{k-1} left bearer and posts (superset)", "T_{k-1} right bearer and posts (superset)",
              "deck behind (L0, or T_{k-2})", "behind left bearer and posts (superset)",
              "behind right bearer and posts (superset)", "paid WIP candidate: T_k left bearer, quarter-turned"]
    return {"assembly": 1, "solids_u": solids, "source_labels": labels, "support_solid": 0,
            "workpiece_solid": len(solids) - 1, "workpiece_support": False}


TORSO_DOMAIN = (-35, 0)
TORSO_PIVOT_BONE = 9  # Spine02, the first upper-body bone (child of Hips); bones 0-8 stay the planted ready source


def pitched_ready(ready: dict, rig: dict, degrees: int) -> dict:
    """The compact ready source with the whole upper body (bones 9-24, tool included) pitched about Spine02.

    Negative degrees pitch the torso back (+Z). The lower body, grounding and every link length are unchanged:
    the upper body turns rigidly, and `put_pose` keeps bones 0-8 bit-identical to ready frame 8. Standing upright,
    no handle lean clears the forearm and snout at this reach (ADR 1209 step 4); pitched back 20-35 degrees, the
    shoulder sits farther from the workpiece and the accepted arm solve clears.
    """
    require(type(degrees) is int and TORSO_DOMAIN[0] <= degrees <= TORSO_DOMAIN[1], "TORSO_INPUT")
    parents, inverse, inverse_inverse = I.A.hierarchy(rig)
    actual, _, fit = I.A.joints(ready, 8, parents, inverse_inverse)
    angle = np.deg2rad(degrees)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), np.sin(angle)], [0., -np.sin(angle), np.cos(angle)]])
    pivot = actual[TORSO_PIVOT_BONE][:3, 3]
    moved = [matrix.copy() for matrix in actual]
    for at in range(TORSO_PIVOT_BONE, 24):
        moved[at][:3, :3] = turn @ actual[at][:3, :3]
        moved[at][:3, 3] = pivot + turn @ (actual[at][:3, 3] - pivot)
    result = dict(ready, matrices=ready["matrices"].copy(), grounding=ready["grounding"].copy())
    I.A.put_pose(result, 8, moved, inverse, fit, ready)
    return result


def source_motion(ready: dict, tool: dict, rig: dict, recipe: dict) -> tuple:
    """The accepted tap recipe at the new contact point: 17 lowering keys, mirrored, with planted entry/recovery."""
    frames, diagnostics = [], []
    base = pitched_ready(ready, rig, recipe["torso_degrees"])
    for at in range(17):
        share = at / 16
        height = PLANE_U + 80 - (82 * share * share * (3 - 2 * share))
        pose, facts = poll_pose(base, tool, rig, [recipe["x_u"], height, recipe["z_u"]],
                                recipe["lean_degrees"], recipe["azimuth_degrees"])
        frames.append(pose["matrices"][0])
        diagnostics.append(facts)
    work = dict(ready, id="mole_worker.install_tread.tap_v1", frames=33, source_loop_mode=0,
                source_duration_s=Fraction(32, 30), duration_q16=32 * 65536,
                matrices=np.stack(frames + frames[-2::-1]),
                grounding=np.full(33, ready["grounding"][8], dtype=np.float32))
    entry = I.A.planted_entry(ready, work, rig, 31)
    entry["id"] = "mole_worker.install_tread.entry_v1"
    recovery = P.indexed_sequence(entry, list(range(30, -1, -1)), "mole_worker.install_tread.recovery_v1", False)
    return [work, entry, recovery], diagnostics


def prove(cases: list, parts: list, topology: list, rig: dict, roots: list, station: dict, recipe: dict) -> dict:
    """The accepted v4 proofs, unchanged, over the station-local tread fixture."""
    for case in cases:
        case["geometry"] = parts
    target = station["solids_u"][-1]
    limits = [target[0], PLANE_U, target[2], target[3], PLANE_U, target[5]]
    contacts = V4.crossing_patch(cases[0], parts[1], roots, I.POLL_VERTEX)
    require(all(V4.contained(row["patch_u"], limits) for row in contacts), "PATCH_ESCAPES_WORKPIECE")
    below = {str(c): V4.plane_intersection(case, parts[1], topology[1][0], roots, PLANE_U)
             for c, case in enumerate(cases)}
    local = {str(c): P.continuous_floor(case, topology, roots) for c, case in enumerate(cases)}
    own = {str(c): S.prove(cases[c], parts, topology, rig["rig_binding"], roots, "body") for c in (0, 1)}
    require(S.reusable_timing(cases[2], cases[1], True) and
            cases[2]["matrices"].tobytes() == cases[1]["matrices"][::-1].tobytes(), "REVERSE_SOURCE")
    own["2"] = dict(own["1"], reused_exact_reverse_clip=1)
    world = {str(c): V4.world_proof(case, parts, topology, roots, station, c == 0, below[str(c)])
             for c, case in enumerate(cases[:2])}
    world["2"] = dict(world["1"], reused_exact_reverse_clip=1)
    clear = all(row["clear"] for row in own.values()) and all(row["clear"] for row in world.values())
    return {"clear": clear, "contacts": contacts, "below_target_plane": below, "local": local, "self": own,
            "world": world}


def extents(cases: list, parts: list) -> dict:
    """Sampled body/tool x extents: the trench walls at |x| = 1024 are omitted from the fixture, so record the margin."""
    xs = []
    for case in cases:
        for frame in range(case["frames"]):
            xs.append(I.G.source_positions(parts[0], case["matrices"][frame], case["grounding"][frame])[:, 0])
            xs.append(I.prop_points(case, frame, parts[1])[:, 0])
    flat = np.concatenate(xs)
    require(float(np.abs(flat).max()) < 1024 - 128, "WALL_MARGIN")
    return {"sampled_max_abs_x_u": float(np.abs(flat).max()), "trench_wall_abs_x_u": 1024}


def encode(out: Path, cases: list, report: dict, roots: list) -> None:
    """Write the create-only candidate image and records, as author_install_source.write_candidate does."""
    command = M.W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    proof = P.content.read_json(Path(command[command.index("--proof") + 1]), command[command.index("--proof-sha256") + 1])
    plan = {"revision": 106, "world_root_bounds_u": roots, "clips": [case["id"] for case in cases]}
    raw_report = (json.dumps(report, indent=2) + "\n").encode()
    raw_plan = (json.dumps(plan, indent=2) + "\n").encode()
    image, budget = P.content.encode(cases, plan, proof, M.COMPACT_SHA, hashlib.sha256(raw_report).hexdigest(),
                                     hashlib.sha256(raw_plan).hexdigest())
    out.mkdir(parents=True)
    for name, raw in (("candidate.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (out / name).open("xb") as stream:
            stream.write(raw)
    (out / "compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2) + "\n")


def main() -> int:
    """Author one candidate, prove it, and write the image, the candidate record and the proof."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--x-u", type=int, required=True)
    parser.add_argument("--z-u", type=int, required=True)
    parser.add_argument("--lean-degrees", type=int, required=True)
    parser.add_argument("--azimuth-degrees", type=int, required=True)
    parser.add_argument("--torso-degrees", type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    recipe = {"x_u": args.x_u, "z_u": args.z_u, "lean_degrees": args.lean_degrees,
              "azimuth_degrees": args.azimuth_degrees, "torso_degrees": args.torso_degrees,
              "contact_plane_y_u": PLANE_U, "poll_y_u": [208, 126, 208]}
    require(-256 < args.x_u < 256 and -STATION_D < args.z_u < -STATION_D + 128, "TARGET_OFF_WORKPIECE")
    M.W.snapshot_sources = FLIGHT.historical_snapshot
    packet = P.content.read_json(PREFIX, I.PREFIX_SHA, 65536)
    original, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    bounds = station_bounds(original[0], parts)
    station = fixture(packet, STATION_D)
    cases, diagnostics = source_motion(original[0], parts[1], rig, recipe)
    result = prove(cases, parts, topology, rig, roots, station, recipe)
    paths = [Path(__file__), Path(V4.__file__), Path(I.__file__), Path(FLIGHT.__file__), PREFIX]
    pins = {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    report = {"schema": 1, "decision": "1209", "station": bounds, "station_root_local_u": [0, 0, 0],
              "station_from_far_edge_u": STATION_D, "fixture": station, "source_recipe": recipe,
              "poll_source_vertex": I.POLL_VERTEX, "pose_solver_diagnostics": diagnostics,
              "wall_margin": extents(cases, parts), "producer_sources": pins,
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "remaining": ["BRENDAN_REVIEW", "ARRIVAL_REPOSITION_FROM_DESCENT_END", "T6_SILL_WORKPIECE_PLANE_64",
                            "HANDLING_PROGRAM", "NATIVE_CAPTURE", "INTEGER_ROWS_AND_CONTENT_7"],
              "production_qualified": False}
    encode(args.out, cases, report, roots)
    with (args.out / "proof.json").open("x") as stream:
        json.dump({"schema": 1, "decision": "1209", "clear": result["clear"], **result,
                   "production_qualified": False}, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"clear": result["clear"], "contacts": [row["anchor_u"] for row in result["contacts"]],
                      "world_pairs": {k: v.get("pairs") for k, v in result["world"].items()}}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
