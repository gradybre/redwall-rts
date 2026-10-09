#!/usr/bin/env python3
"""Read-only stripped-manifest regression; all supplied bytes live in memory."""
import argparse
import importlib.util
import json
from pathlib import Path


def probe(root):
    producer = root / "godot/data/underground/mole-worker/rebind_motion_profiles.py"
    spec = importlib.util.spec_from_file_location("review_rebind", producer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    diagnostic = root / "docs/validation/evidence/underground-host-checkpoint-2026-10-04/approach-profile-diagnostic-2/mole-worker.ugprof"
    wire = diagnostic.read_bytes()
    level = "godot/data/underground/initial_level_pack.uglvl"
    stripped = {
        "source_geometry_qualified": True,
        "world_activation_qualified": False,
        "wire_sha256": module.PROFILE_SHA,
        "content_revision": 2,
        "profile_count": 26,
        "box_count": 250,
        "prerequisite_pins": {level: module.digest((root / level).read_bytes())},
    }
    manifest = (json.dumps(stripped) + "\n").encode()
    actual_read = module.read

    def injected(path, expected=None, maximum=4 * 1024 * 1024):
        if path == module.PROFILES / "mole-worker.ugprof":
            raw = wire
        elif path == module.PROFILES / "manifest.json":
            raw = manifest
        else:
            return actual_read(path, expected, maximum)
        module.require(len(raw) <= maximum, "MOTION_REBIND_SOURCE_SIZE")
        module.require(expected is None or module.digest(raw) == expected,
                       "MOTION_REBIND_SOURCE_HASH")
        return raw

    module.read = injected
    result = {"producer_sha256": module.digest(producer.read_bytes()),
              "stripped_manifest": stripped, "foreign_writes": False}
    try:
        output, report = module.inputs()
        result.update(accepted=True, wire_bytes=len(output),
                      runtime_activation=report["runtime_activation"])
    except ValueError as error:
        result.update(accepted=False, refusal=str(error))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--expect-refusal", action="store_true")
    arguments = parser.parse_args()
    result = probe(arguments.root.resolve())
    print(json.dumps(result, indent=2))
    if arguments.expect_refusal:
        assert result["accepted"] is False
