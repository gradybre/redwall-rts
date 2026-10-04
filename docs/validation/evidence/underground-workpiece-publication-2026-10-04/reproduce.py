#!/usr/bin/env python3
"""Replay the reviewed four-suite START seam check into a fresh output folder."""

import hashlib
import importlib.util
from pathlib import Path
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[4]
    path = root / "docs/validation/evidence/underground-prepared-location-observation-2026-10-04/reproduce.py"
    expected = "051b1fdaaed6f760a61d3a81efa25a8a133ac53fa77b5b0596dd8bb33049a821"
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit("Reviewed checkpoint runner changed; review before replay")
    if len(sys.argv) != 2:
        raise SystemExit("usage: reproduce.py <fresh-output-directory>")
    output = sys.argv[1]
    spec = importlib.util.spec_from_file_location("reviewed_checkpoint", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.FILES = [
        "godot/scripts/core/modular_project_contract.gd",
        "godot/scripts/core/modular_projects.gd",
        "godot/test/test_underground_workpiece_publication.gd",
    ]
    sys.argv = [str(path), "--out", output, "--port", "6198"]
    for suite in ("test_underground_workpiece_publication.gd", "test_modular_projects.gd",
                  "test_underground_connector_work.gd", "test_underground_connector_payment_guard.gd"):
        sys.argv.extend(["--suite", suite])
    sys.argv.extend(["--dependency", "godot/scripts/core/underground_connector_work.gd"])
    return module.main()


if __name__ == "__main__":
    raise SystemExit(main())
