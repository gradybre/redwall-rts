#!/usr/bin/env python3
"""Render a revision-2 tread-install candidate (ADR 1209 step 4) with revision 1's renderer, unchanged.

The renderer rebuilds a candidate from its recipe before drawing it. This wrapper only points that rebuild at
revision 2's `source_motion` (the wrist-preserving swivel elbow); the views, colours and review numbers are
revision 1's. Not a clearance proof.

    $PY .../render_tread_install_v2.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
RENDER_SPEC = importlib.util.spec_from_file_location("render_tread_install", HERE / "render_tread_install.py")
RENDER = importlib.util.module_from_spec(RENDER_SPEC)
RENDER_SPEC.loader.exec_module(RENDER)
V2_SPEC = importlib.util.spec_from_file_location("tread_install_v2", HERE / "author_tread_install_v2.py")
V2 = importlib.util.module_from_spec(V2_SPEC)
V2_SPEC.loader.exec_module(V2)


def main() -> int:
    """Rebuild through revision 2's source motion, then render exactly as revision 1 does."""
    RENDER.T.source_motion = V2.source_motion
    return RENDER.main()


if __name__ == "__main__":
    sys.exit(main())
