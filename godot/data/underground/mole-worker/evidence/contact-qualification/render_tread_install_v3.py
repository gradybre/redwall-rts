#!/usr/bin/env python3
"""Render a revision-3 tread-install candidate (ADR 1209 step 4) with revision 1's renderer, unchanged.

The renderer rebuilds a candidate from its recipe before drawing it. This wrapper only points that rebuild at
revision 3's `source_motion` (the elbow aimed at the accepted contact wrist, and the handle roll); the views,
colours and review numbers are revision 1's. Not a clearance proof.

    $PY .../render_tread_install_v3.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
RENDER_SPEC = importlib.util.spec_from_file_location("render_tread_install", HERE / "render_tread_install.py")
RENDER = importlib.util.module_from_spec(RENDER_SPEC)
RENDER_SPEC.loader.exec_module(RENDER)
V3_SPEC = importlib.util.spec_from_file_location("tread_install_v3", HERE / "author_tread_install_v3.py")
V3 = importlib.util.module_from_spec(V3_SPEC)
V3_SPEC.loader.exec_module(V3)


def rebuild(ready: dict, tool: dict, rig: dict, recipe: dict) -> tuple:
    """Revision 3's motion in revision 1's `source_motion` shape: (cases, diagnostics)."""
    original, parts, _, _, _, _, _ = V3.M.read_actual_source()
    cases, diagnostics, _ = V3.source_motion(ready, tool, rig, recipe, parts)
    return cases, diagnostics


def main() -> int:
    """Rebuild through revision 3's source motion, then render exactly as revision 1 does."""
    V3.M.W.snapshot_sources = V3.V1.FLIGHT.historical_snapshot
    RENDER.T.source_motion = rebuild
    return RENDER.main()


if __name__ == "__main__":
    sys.exit(main())
