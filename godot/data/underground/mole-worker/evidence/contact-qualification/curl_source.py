#!/usr/bin/env python3
"""ADR 1216: the successor source closure for pick-source proofs on the curled paw (the haul authors keep v3).

`read_curl_source()` returns the same tuple as `assess_stair_rig.read_actual_source()`. Each input is pinned:

- **Geometry and gripped states**: the native bake `mole-grip-v4.ugpal` (`grip-source-v4/`). It is read through
  the accepted palette verifier with its own import archive and the grip-proof-v3 envelopes.
- **Rig and topology**: the native census `topology-curl-v1` of the compiled curled content `curl-v1`.
- **Ready carry**: the accepted compact ready key (compact-program-compile-v2, key 8). It is read through the
  accepted v3 closure, then re-held with the curled paw's own lateral-2 fit; only the pick's matrix (bone 24)
  changes, because bone matrices do not depend on the mesh. The compact image's other clips are not returned:
  they hold the accepted fit and belong to the accepted paw.

Pinned scripts that changed since a capture are restored from their matching git commit (ADR 1214), as for
every other proof in this directory.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("author_pick_refit", HERE / "author_pick_refit.py")
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)
P, I, M = F.P, F.I, F.M
CONTENT = HERE / "grip-source-v4" / "content"
UGPAL = CONTENT / "mole-grip-v4.ugpal"
UGPAL_SHA = "d72d3fd63705beb191775ace4150ac2d1d68f8d0c60d0832b07c9dc27b1bcb74"
ARCHIVE = CONTENT / "mole-grip-v4.inputs"
PROOF = HERE / "grip-proof-v3" / "envelopes.json"
PROOF_SHA = "8f5e4d2c02eb5e7c33c1ba310463e63fbf39e6293e0ae6a33cbbb53661d97d76"
PLAN = HERE / "grip-source-v4" / "source-plan.json"
PLAN_SHA = "432f669df101fe4e776a7da9d0b08ebe8df4c9415de57f41e7bb4825c3bf8daf"
TOPOLOGY = HERE / "topology-curl-v1" / "topology.json"
TOPOLOGY_SHA = "f3c326a6b7530ba3699f16665a1e4a970f92adaaf5a0754fbe729488d0e0faf4"
CURL_CONTENT_SHA = "8ad9d1ad9f14515edac430648d28dc7728ce1bde1debc40191105935134d8457"
CURLED_PAW = HERE / "curled-paw-v1" / "paw.json"


def lateral_2() -> np.ndarray:
    """The curled paw's approved hand-local pick fit, from the approved shape's record."""
    import json
    return np.asarray(json.loads(CURLED_PAW.read_text())["fit_hand_to_pick_lateral_2"], dtype=np.float64)


def read_curl_source() -> tuple:
    """(cases, parts, rig, topology, roots, sources, historical) on the curled paw; cases holds the re-held ready."""
    M.W.snapshot_sources = F.V1.FLIGHT.historical_snapshot
    accepted = M.read_actual_source()
    proof = P.content.read_json(PROOF, PROOF_SHA)
    plan = P.content.read_json(PLAN, PLAN_SHA, 65536)
    original, sources, historical = M.W.extract_original(UGPAL, UGPAL_SHA, proof, plan, ARCHIVE)
    parts = original[0]["geometry"]
    rig = P.content.read_json(TOPOLOGY, TOPOLOGY_SHA, P.MAX_TOPOLOGY_BYTES)
    topology = P.read_topology(TOPOLOGY, TOPOLOGY_SHA, CURL_CONTENT_SHA, parts)
    ready = F.refit_ready(accepted[0][0], rig, lateral_2())
    return [ready], parts, rig, topology, plan["world_root_bounds_u"], sources, historical
