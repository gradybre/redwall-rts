#!/usr/bin/env python3
"""Enforce the independently reviewed complete host retirement census inside the existing Profile reserve."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/validation/evidence/underground-host-retirement-2026-10-04/census.py"
SOURCE_SHA = "fcf045d97239a993cde1dede85b4bfcaca33fbe5816b4acb5d09a64784a1630b"
PREDECESSOR = SOURCE.parent / "predecessor/manifest.json"
PREDECESSOR_SHA = "014906c67cd78fd556b101050421e6eccc2a0ba90957f00654f62a4ed99e9d52"
PRODUCER = ROOT / "docs/validation/evidence/underground-world-retirement-2026-10-04/census.py"
PRODUCER_SHA = "440777a6d5762b3a4945d3b8563b1579f6db10c24e1bdfd371b59e489d7f035c"


def verified_census():
    """Verify the complete executable/baseline closure before importing either census."""
    for path, expected in ((SOURCE, SOURCE_SHA), (PRODUCER, PRODUCER_SHA),
                           (PREDECESSOR, PREDECESSOR_SHA)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("reviewed host retirement witness changed: " + str(path.relative_to(ROOT)))
    # The fixed manifest digest is the authority for these portable baseline
    # locators and hashes. A producer cannot re-author its own expected hash.
    for row in json.loads(PREDECESSOR.read_bytes()).values():
        path = ROOT / row["locator"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError("reviewed host retirement predecessor changed: " + row["locator"])
    spec = importlib.util.spec_from_file_location("reviewed_host_retirement_census", SOURCE)
    census = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(census)
    return census


def build(index, session, ceiling):
    """Use current parsed sources, including mutation tests, against the accepted portable predecessor witnesses."""
    census = verified_census()
    replacements = {}
    for name, relative in census.FILES.items():
        module = Path(relative).stem
        if module not in index:
            raise ValueError("retirement source missing from current index: " + module)
        replacements[name] = index[module].text
    result = census.build(ROOT, replacements)
    joint = session["profile_level_motion_session_joint_bytes"]
    reserve = result["accounting"]["retirement_reserved_bytes"]
    if result["accounting"]["parent_1156_joint_bytes"] != joint or joint + reserve > ceiling:
        raise ValueError("current Profile/Level/Motion/Session/retirement joint reservation disagrees or overbooks")
    result["accounting"]["joint_remaining_bytes"] = ceiling - joint - reserve
    result["current_joint_source_derived"] = True
    return result
