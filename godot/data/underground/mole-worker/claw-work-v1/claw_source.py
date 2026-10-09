#!/usr/bin/env python3
"""ADR 1217: the tool-free open-paw source closure for claw and paw work (DEC-052). Source reading only.

Every input is published and pinned:

- **Body.** The open paw: the supplied cast body of `mole_digger.idle.plain` in `all-cast-v9.ugpal` (`5b368eb3…`),
  geometry fingerprint `a938d479…`. It is the original mesh before the pick's closed-paw derivative; its skin ids
  and weights equal the closed paw's, and only 845 right-hand positions differ (ADR 1216).
- **Rig and triangles.** `topology-v5/topology.json` (`da623e5c…`): its rig binding and the body index buffer,
  which it records for the same original body (`original_body_sha256`).
- **Ready.** Stand key 8 of the accepted tool-free stand (ADR 1199, `empty-walk-v1/candidate/stand.npz`,
  `7086ef2a…`), the hub of tool-free rows 30/31.
- **Target.** The Frontier's first episode: cube 0 from station 4 (`compile_entry_frontier.tables`), mapped into
  the yaw-0 source frame with the published quarter-turn convention, checked against rows 13 and 25.

The palette is read from the staged demo assets (cloned from the frozen `redwall-rts-codex-ug-space` worktree,
ADR 1192 §6) and checked by its whole-file digest.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import struct
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
MOLE = HERE.parent
ROOT = MOLE.parents[3]
sys.path.insert(0, str(MOLE / "haul-handling-v1"))
import author_handling as A  # noqa: E402
import inspect_source as I  # noqa: E402

FRONTIER_SPEC = importlib.util.spec_from_file_location(
    "claw_frontier", ROOT / "godot/data/underground/first-entry-prefix-v1/compile_entry_frontier.py")
FRONTIER = importlib.util.module_from_spec(FRONTIER_SPEC)
FRONTIER_SPEC.loader.exec_module(FRONTIER)

PALETTE = ROOT / "godot/demo/assets/underground-matrices/all-cast-v9.ugpal"
STAND = MOLE / "haul-handling-v1/evidence/empty-walk-v1/candidate/stand.npz"
STAND_SHA = "7086ef2a3aab64537d7822393c04ece86d67879e59e1c7e54d333a5c7f974c7d"
TOPOLOGY = I.PROOF / "topology-v5/topology.json"
PROFILES = MOLE / "qualified-stone-v7/mole-worker.ugprof"
PROFILES_SHA = "30c3dc1f5e9162f5530f410c437ed6f85d28dc6879f88dec81cb193ea87b0df5"
ROOT_BOUNDS = [0, -32256, 0, 262144, 16896, 262144]  # The tool-free closure's world root range (ADR 1199).
READY_FRAME = 8
FIRST_EPISODE = 0  # Cube 0 from station 4: the Frontier's first episode.
TRIANGLES = 10209
require = A.require


def sha(path: Path) -> str:
    """Lower-case hex SHA-256 of a file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quarter(box: list) -> list:
    """The published yaw-0 → yaw-16384 box map (`publish_haul_runtime.rotate_quarter`): x' = z, z' = −x."""
    x0, y0, z0, x1, y1, z1 = box
    return [z0, y0, -x1, z1, y1, -x0]


def profile_rows(profiles: tuple) -> dict:
    """(yaw, boxes) of published rows from the active content-6 wire."""
    require(sha(PROFILES) == PROFILES_SHA, "CLAW_PROFILES_PIN")
    wire = PROFILES.read_bytes()
    rows, _, sources = struct.unpack_from("<III", wire, 20)
    at, row, box = 32 + 32 * sources, struct.Struct("<18i3q2B"), struct.Struct("<7i")
    result = {}
    for profile in profiles:
        fields = row.unpack_from(wire, at + 98 * profile)
        result[profile] = (fields[11], [box.unpack_from(wire, at + 98 * rows + 28 * k)
                                        for k in range(fields[14], fields[14] + fields[15])])
    return result


def contact_rows() -> dict:
    """Rows 13 (yaw 0) and 25 (yaw 49152) contact points."""
    return {profile: {"yaw": yaw, "point": [b[:6] for b in boxes if b[6] == 5][0]}
            for profile, (yaw, boxes) in profile_rows((13, 25)).items()}


def stance_inset_limit() -> int:
    """How far a cut station may move toward its cube while the tool-free all-yaw stance stays off the pocket.

    The station stands 512 u behind the cube's near face. Rows 30 and 31 (tool-free STAND/WALK, the travel a
    clawed worker uses) share the STANCE_SUPPORT box [-406, 406]; ADR 1188 requires the whole all-yaw foot
    certificate outside the future pocket. So the station may move in by at most 512 - 406 = 106 u.
    """
    stances = [[b[:6] for b in boxes if b[6] == 1] for _, boxes in profile_rows((30, 31)).values()]
    require(stances[0] == stances[1] and len(stances[0]) == 1, "CLAW_STANCE_ROWS")
    reach = stances[0][0][5]
    require(stances[0][0] == (-reach, -1, -reach, reach, 0, reach), "CLAW_STANCE_SYMMETRY")
    return 512 - reach


def first_target() -> dict:
    """Cube 0 relative to station 4, turned into the yaw-0 source frame; the convention is checked on rows 13/25."""
    table, _ = FRONTIER.tables({"cut_groups": [], "fastening_candidates": [{"target_bounds_u": []}] * 2,
                                "natural_bearings": []})
    station = table[1][2 + FIRST_EPISODE]
    root, yaw, profile = station[1:4], station[4], station[5]
    cube = FRONTIER.cube(FIRST_EPISODE)
    relative = [value - root[axis % 3] for axis, value in enumerate(cube)]
    rows = contact_rows()
    require(yaw == 49152 and profile == 25 and rows[25]["yaw"] == 49152 and rows[13]["yaw"] == 0, "CLAW_STATION")
    turned = rows[13]["point"]
    for _ in range(3):
        turned = quarter(turned)
    require(turned == list(rows[25]["point"]), "CLAW_QUARTER_CONVENTION")
    local = quarter(relative)  # Three quarter turns take yaw 0 to 49152; one more returns to yaw 0.
    require(local == [-512, -1024, -1536, 512, 0, -512], "CLAW_TARGET_CUBE")
    return {"station_root_u": root, "station_yaw": yaw, "replaced_profile": profile, "cube_world_u": cube,
            "cube_local_u": local, "accepted_pick_anchor_local_u": list(rows[13]["point"][:3])}


def read_stand() -> dict:
    """The accepted tool-free stand clip (ADR 1199), whose key 8 is the shared tool-free ready."""
    require(sha(STAND) == STAND_SHA, "CLAW_STAND_PIN")
    with np.load(STAND, allow_pickle=False) as image:
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    require(matrices.dtype == np.float32 and matrices.shape[1:] == (24, 12) and len(matrices) > READY_FRAME,
            "CLAW_STAND_SHAPE")
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding}


def read_claw_source(palette: Path = PALETTE) -> dict:
    """The open-paw body, rig, triangles, tool-free ready hub and target, all pinned."""
    rows, _ = I.read_selected(palette, I.PALETTE_SHA, (I.CASE_IDS[0],))
    body = rows[I.CASE_IDS[0]]["geometry"][0]
    require(I.CONTENT.geometry_fingerprint(body).hex() == I.OLD_BODY and body["binds"] == 24, "CLAW_OPEN_PAW")
    topology = I.CONTENT.read_json(TOPOLOGY, I.TOPOLOGY_SHA, 8 * 1024 * 1024)
    require(topology["original_body_sha256"] == I.OLD_BODY, "CLAW_TOPOLOGY_BODY")
    triangles = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int64).reshape(-1, 3)
    require(triangles.shape == (TRIANGLES, 3) and int(triangles.max()) < len(body["geometry"][0]["points"]),
            "CLAW_TRIANGLES")
    parents, inverse, inverse_inverse = A.hierarchy(topology)
    stand = read_stand()
    return {"body": body, "triangles": triangles, "topology": topology, "rig": topology["rig_binding"],
            "parents": parents, "inverse": inverse, "inverse_inverse": inverse_inverse, "stand": stand,
            "hub": A.globals_at(stand, READY_FRAME, inverse_inverse),
            "grounding": np.float32(stand["grounding"][READY_FRAME]), "roots": ROOT_BOUNDS,
            "target": first_target(),
            "pins": {"palette": I.PALETTE_SHA, "open_body": I.OLD_BODY, "topology": I.TOPOLOGY_SHA,
                     "stand": STAND_SHA, "profiles": PROFILES_SHA}}
