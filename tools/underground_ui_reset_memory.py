#!/usr/bin/env python3
"""Compose the reviewed UI reset frames with the current indexed host census."""
import hashlib
import importlib.util
import json
from pathlib import Path

import underground_retirement_memory as retirement_memory

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/validation/evidence/underground-world-create-reset-2026-10-04/census.py"
SOURCE_SHA = "2abbae96f0e4864c5524a28b3039105d38f18038a1fd9435dddc38f44bb735a2"
PREDECESSOR = SOURCE.parent / "predecessor/manifest.json"
PREDECESSOR_SHA = "787685ad614e8afabb3bc58d385e9cfb2861551f781d4ed8a5b4027a2eae4363"
CURRENT = {
    "UI": ("ui_manager", "3cf277da410c6b45bb19800a9db8a42cb97f735342d3ab38739a143a6e52d59b"),
    "Form": ("ui_world_session", "263dfba991975ffa0fabe79946610e992d164e95eba04e739423862d072f6fb6"),
}


def build(index, retirement, ceiling):
    """Reuse the already checked host result, never replace injected sources with disk text."""
    # 1160 imports 1158, which imports 1155. Verify that complete closure before
    # allowing either historical producer to execute.
    retirement_memory.verified_census()
    for path, expected in ((SOURCE, SOURCE_SHA), (PREDECESSOR, PREDECESSOR_SHA)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("reviewed UI reset witness changed: " + str(path.relative_to(ROOT)))
    for row in json.loads(PREDECESSOR.read_bytes()).values():
        if hashlib.sha256((ROOT / row["locator"]).read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError("reviewed UI reset predecessor changed: " + row["locator"])
    replacements = {}
    for role, (name, expected) in CURRENT.items():
        if name not in index or hashlib.sha256(index[name].text.encode()).hexdigest() != expected:
            raise ValueError("reviewed UI reset call/allocation implementation changed: " + name)
        replacements[role] = index[name].text
    spec = importlib.util.spec_from_file_location("reviewed_ui_reset_census", SOURCE)
    census = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(census)

    def current_host(root):
        if root != ROOT or not retirement.get("current_joint_source_derived"):
            raise ValueError("UI reset requires the current indexed host census")
        return retirement

    census.H.build = current_host
    result = census.build(replacements)
    actual = retirement["accounting"]
    accounting = result["accounting"]
    if (accounting["retirement_reserved_bytes"] != actual["retirement_reserved_bytes"]
            or accounting["profile_joint_unchanged"] != actual["joint_with_retirement"]
            or accounting["profile_ceiling"] != ceiling
            or actual["joint_with_retirement"] > ceiling):
        raise ValueError("UI reset/host joint reservation disagrees or overbooks")
    result["additional_reserved_bytes"] = 0
    result["current_joint_source_derived"] = True
    return result
