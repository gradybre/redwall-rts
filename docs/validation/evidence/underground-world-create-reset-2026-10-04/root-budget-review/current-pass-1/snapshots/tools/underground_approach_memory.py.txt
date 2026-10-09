#!/usr/bin/env python3
"""Replay the reviewed 1156 census on current sources without a Git-history dependency.

This is an enforcement adapter, not another allocation or qualification.  The
immutable census still performs its complete retained/payload/frame arithmetic.
Only its source provider is replaced: current sources come from the caller's
parsed index; predecessors come from exact, repository-contained witnesses.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

import audit_registry_capacities as audit

ROOT = Path(__file__).resolve().parents[1]
LEGACY = Path("docs/validation/evidence/underground-work-approach-2026-10-04")
EVIDENCE = Path("docs/validation/evidence/underground-approach-memory-2026-10-04")
PINS = {
    LEGACY / "census.py": "dc9ae8a01583d44391ef95ae9b0314064dd6ac6ea6a38a8164f83bba39019b75",
    LEGACY / "census.json": "4a85ab69a8cc002416990b4e720840149e5e69ce90daca8341ad629109fd47e2",
    LEGACY / "supporting/retirement-source.gd.txt": "e7e93ee1d4cb0c879b5d41e24d3a7023e9048f5dd4da2993088817007e50dbb9",
    EVIDENCE / "predecessors.json": "9ec7f83583ba3a6f7e474145c037db5ca91e56f618e937d7ab4db60ac2d46660",
    EVIDENCE / "foreign-frames.json": "b200d2d822504669582df54e1b481b8e3c9592d70045534102a2a65a36a78dec",
}
NONCORE = {
    "mole_profile_driver": "godot/data/underground/mole-worker/mole_profile_driver.gd",
    "source_program": "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
    "mole_profile_catalog": "godot/data/underground/mole-worker/mole_profile_catalog.gd",
}
CURRENT = (
    "underground_profiles", "underground_routes", "underground_world_routes",
    "mole_profile_driver", "source_program", "gear", "haul_carry", "inventory",
)
JOINT_SOURCES = (
    "underground_profiles", "mole_profile_catalog", "underground_level_catalog",
    "underground_motion_catalog", "underground_session", "underground_world_retirement",
    "underground_budget",
)
OWNED_CALL_GRAPH = CURRENT[:5]


def require(condition, message):
    if not condition:
        raise ValueError("approach memory: " + message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def relative_path(name):
    return NONCORE.get(name, "godot/scripts/core/" + name + ".gd")


def pinned_bytes(relative):
    raw = (ROOT / relative).read_bytes()
    require(digest(raw) == PINS[relative], "immutable witness changed: " + str(relative))
    return raw


def current_index(index):
    """Never replace a supplied Module.text with disk text or stale parsed constants."""
    result = dict(index)
    for name in NONCORE:
        if name not in result:
            relative = relative_path(name)
            result[name] = audit.parse_module(name, relative, (ROOT / relative).read_text())
    for name in set(CURRENT) | set(JOINT_SOURCES):
        require(name in result, "missing current module: " + name)
        module = result[name]
        require(module.name == name and module.relative_path == relative_path(name),
                "current module identity: " + name)
        # A caller may inject changed text while leaving cached consts/sha256 unchanged.
        result[name] = audit.parse_module(name, module.relative_path, module.text)
    return result


class CurrentPath:
    """Only the two path operations used by the pinned census's source-hash report."""

    def __init__(self, module):
        self.module = module

    def relative_to(self, root):
        require(root == ROOT, "census root substitution")
        return Path(self.module.relative_path)

    def read_bytes(self):
        return self.module.text.encode("utf-8")


def replay(index):
    """Execute the exact reviewed algorithm, including assertions under python -O."""
    blobs = {path: pinned_bytes(path) for path in PINS}
    accepted = json.loads(blobs[LEGACY / "census.json"])
    predecessors = json.loads(blobs[EVIDENCE / "predecessors.json"])
    foreign = json.loads(blobs[EVIDENCE / "foreign-frames.json"])
    namespace = {"__file__": str(ROOT / LEGACY / "census.py"),
                 "__name__": "_reviewed_1156_census"}
    exec(compile(blobs[LEGACY / "census.py"], namespace["__file__"], "exec", optimize=0), namespace)
    require(predecessors["base"] == namespace["BASE"], "predecessor revision")
    require(set(predecessors["sources"]) == set(namespace["EXISTING"]) | {"haul_carry", "inventory"},
            "complete predecessor source set")
    for name, row in predecessors["sources"].items():
        require(row["path"] == relative_path(name) and digest(row["text"].encode()) == row["sha256"],
                "predecessor source identity: " + name)

    def source(name, old=False):
        require(name in predecessors["sources"] if old else name in CURRENT,
                "unreviewed source dependency: " + name)
        return predecessors["sources"][name]["text"] if old else index[name].text

    namespace["ROOT"] = ROOT
    namespace["source"] = source
    namespace["path"] = lambda name: CurrentPath(index[name])
    captured = []
    namespace["print"] = captured.append
    try:
        namespace["main"]()
    except AssertionError as error:
        raise ValueError("approach memory: reviewed census refused " + str(error)) from error
    require(len(captured) == 1, "exact census result")
    result = json.loads(captured[0])
    # Arithmetic and declared frames must reproduce the reviewed result. Only
    # source hashes may differ for independently changed foreign owner methods.
    require({k: v for k, v in result.items() if k != "source_sha256"}
            == {k: v for k, v in accepted.items() if k != "source_sha256"},
            "reviewed numeric/retained/lifetime census changed")
    # Enumerated chains alone cannot detect an added call with no new locals.
    # Pin the full five reviewed implementations and exact foreign frame bodies.
    for name in OWNED_CALL_GRAPH:
        require(digest(index[name].text.encode()) == accepted["source_sha256"][relative_path(name)],
                "reviewed call/allocation implementation changed: " + name)
    foreign_keys = {key for chain in namespace["PATHS"].values() for key in chain
                    if key.split(":")[0] not in OWNED_CALL_GRAPH}
    require(set(foreign["frames"]) == foreign_keys, "complete foreign frame set")
    for key, row in foreign["frames"].items():
        body = namespace["function"](key)
        require(body == row["text"] and digest(body.encode()) == row["sha256"],
                "reviewed foreign call/allocation implementation changed: " + key)
    return result, {key: row["sha256"] for key, row in foreign["frames"].items()}


def joint_census(index, joint, result):
    """Check current source constants against the actual Motion joint, not an old literal total."""
    constants = dict(index)
    for name in JOINT_SOURCES:
        module = index[name]
        text = re.sub(r"(?m)^(const \w+: int = [^#\n]+)#[^\n]*$", r"\1", module.text)
        constants[name] = audit.parse_module(name, module.relative_path, text)

    def value(module, symbol):
        found = audit.resolve_expression(constants, module, symbol)
        require(isinstance(found, audit.Proved), "unproved current constant: " + module + "." + symbol)
        return found.value

    profiles = value("mole_profile_catalog", "PROFILE_COUNT")
    boxes = value("mole_profile_catalog", "BOX_COUNT")
    sources = value("underground_session", "PROFILE_SOURCE_COUNT")
    require((profiles, boxes, sources) == (26, 250, 1), "current configured Profile counts")
    widths = (value("underground_profiles", "I32_FIELDS"),
              value("underground_profiles", "I64_FIELDS"), value("underground_profiles", "BYTE_FIELDS"))
    row = 4 * widths[0] + 8 * widths[1] + widths[2]
    require(row == value("underground_profiles", "PROFILE_WIRE_BYTES") == 98, "current Profile row width")
    paired = 2 * (profiles * row + boxes * 28 + sources * 32 + 32)
    control = value("underground_profiles", "CONTROL_RESERVE")
    require(paired == value("mole_profile_catalog", "PAIRED_BANK_BYTES") == 19224,
            "current actual paired Profile payload")
    require(control == value("mole_profile_catalog", "CONTROL_RESERVE") == 32768,
            "unchanged Profile logical/native reservation")
    terms = {
        "profiles": paired + control,
        "levels": value("underground_level_catalog", "RESERVED_BYTES"),
        "paired_motion": 2 * value("underground_motion_catalog", "BANK_BYTES"),
        "decode": value("underground_motion_catalog", "DECODE_BYTES"),
        "caller": value("underground_motion_catalog", "CALLER_BYTES"),
        "logical_helper": value("underground_motion_catalog", "CONTROL_BYTES"),
        "native": value("underground_motion_catalog", "NATIVE_RESERVE"),
    }
    maximum_counts = tuple(value("underground_profiles", key)
                           for key in ("MAX_PROFILES", "MAX_BOXES", "MAX_SOURCES"))
    require(maximum_counts == (256, 3072, 64), "unchanged independent Profile maxima")
    maximum_profile = 2 * (maximum_counts[0] * row + maximum_counts[1] * 28
                           + maximum_counts[2] * 32 + 32) + control
    envelope = value("underground_budget", "PROFILE_BYTES")
    require(envelope == value("underground_profiles", "ARENA_BYTES") == 262144,
            "unchanged joint Profile arena")
    expected = terms | {
        "total": sum(terms.values()), "reservation": envelope,
        "headroom": envelope - sum(terms.values()),
        "independent_maxima_total_refuses": sum(terms.values()) - terms["profiles"] + maximum_profile,
    }
    require(set(joint) == set(expected) and all(type(v) is int for v in joint.values()) and joint == expected,
            "actual Motion joint differs, contains another slice, or uses stale Profile counts")
    complete = {
        "paired_profiles": paired, "profile_controls": control, "levels": terms["levels"],
        "paired_motion": terms["paired_motion"], "decode": terms["decode"], "motion_caller": terms["caller"],
        "motion_helpers": terms["logical_helper"], "motion_native_provisional": terms["native"],
        "session": value("underground_session", "RESERVED_BYTES"),
        "retirement": value("underground_world_retirement", "RETIREMENT_RESERVED_BYTES"),
    }
    require(complete == result["joint"]["terms"], "full current coexistence differs from reviewed1156 census")
    require(sum(complete.values()) == 246868 <= envelope < expected["independent_maxima_total_refuses"],
            "configured joint admission or independent maxima refusal")
    return expected


def build(index, joint):
    """Use current parsed sources and Motion['joint'] BEFORE its Session/retirement additions.

    The returned profile_control and joint are validation evidence inside existing
    reservations. additional_reserved_bytes is zero; callers must not add this
    report's totals to their already-counted PROFILE_BYTES contribution.
    """
    current = current_index(index)
    result, foreign = replay(current)
    before = joint_census(current, joint, result)
    result["additional_reserved_bytes"] = 0
    result["portable_enforcement"] = {
        "witness_sha256": {path.as_posix(): sha for path, sha in PINS.items()},
        "current_text_overrides_honored": True,
        "git_or_subprocess_required": False,
        "whole_reviewed_call_graph_modules": list(OWNED_CALL_GRAPH),
        "foreign_frame_sha256": foreign,
        "current_joint_source_sha256": {current[name].relative_path: digest(current[name].text.encode())
                                       for name in JOINT_SOURCES},
        "motion_joint_before_session_and_retirement": before,
        "source_policy": "Changed reviewed calls, allocations, or frames require explicit recount; foreign unrelated methods may change.",
        "scope": "Logical existing reservation enforcement only; no native RAM, presentation, route, or World qualification.",
    }
    return result
