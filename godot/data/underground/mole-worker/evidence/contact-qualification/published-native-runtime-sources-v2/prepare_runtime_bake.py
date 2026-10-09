#!/usr/bin/env python3
"""Create a new native input record; never change historical geometry qualification."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
OLD_ROOT = Path("/Users/brendan/Developer/redwall-rts-codex-ug-space")
PRIOR = HERE.parent / "published-native-runtime-sources-v1/bake-spec.json"
PRIOR_SHA = "a3e6e55ed0ea158606ed649983920d8f0198d020c70aff5cc519c06d16c45674"
ARCHIVE = "godot/demo/assets/underground-matrices/mole-grip-v3.inputs"
SOURCE_COMMIT = "bdef27f082611b68ce61cdd54d4f2d23bf11472b"
CHANGES = {
    "res://demo/cast/underground_actor.gd": (
        "64ce149244114c7404e6e7374b6c268fa2ebbe2e70dfa940d3d3e791c763c4b6",
        "b0ef7640d2b5626eb95c162d19318d9b3985a51479d19dfdf9a38e0176a06e91"),
    "res://scripts/core/modular_project_contract.gd": (
        "52928df5232a8522623b3b743eb306f1bf5ce6d24acfa74a12fcd197c3ab5135",
        "9e8b9ed5f3778b959ed54385999a9c1b1713dc3b46e6829d2bd553760b140849"),
    "res://scripts/core/transforms.gd": (
        "75a07d3fb01806e96d0ac6aa12c7a85e4fd7073489cf1a86897c41ee501e8319",
        "7534a10b6043aecb5183a8f791b7a6bf443a1462e44be174bb8c83e9ff2d4aaa"),
}
MAX_INPUT_BYTES = 268435456
# The exact 537 records read 3,081,042,450 bytes, including original and staged
# copies. This offline I/O bound retains only a 1 MiB hashing chunk at a time.
MAX_TOTAL_BYTES = 3221225472


def require(condition, code):
    if not condition:
        raise ValueError(code)


def digest(path):
    """Read in bounded chunks, including the separately owned original raw assets."""
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_INPUT_BYTES,
            "RUNTIME_INPUT_FILE")
    result = hashlib.sha256()
    count = 0
    with path.open("rb") as stream:
        while block := stream.read(1048576):
            count += len(block)
            require(count <= MAX_INPUT_BYTES, "RUNTIME_INPUT_CAPACITY")
            result.update(block)
    return result.hexdigest()


def verify_row(row, root):
    """Verify imported scenes from the accepted archive, other sources at their actual location."""
    name = row["path"]
    if name.startswith("res://.godot/imported/"):
        path = root / ARCHIVE / (row["sha256"] + ".input")
    else:
        path = root / "godot" / name[6:] if name.startswith("res://") else Path(name)
    require(digest(path) == row["sha256"], "RUNTIME_SOURCE_DRIFT")
    return path.stat().st_size


def renew_record(prior, root):
    """Only three reviewed current sources and 25 identical-file locations can differ."""
    require(len(prior["sources"]) == 536, "RUNTIME_SOURCE_CENSUS")
    result = copy.deepcopy(prior)
    changed, relocated, seen = [], [], set()
    total = 0
    for before, after in zip(prior["sources"], result["sources"], strict=True):
        name = before["path"]
        require(name not in seen, "RUNTIME_DUPLICATE_SOURCE")
        seen.add(name)
        if name in CHANGES:
            old, new = CHANGES[name]
            require(before["sha256"] == old, "RUNTIME_PRIOR_SOURCE")
            after["sha256"] = new
            changed.append({"path": name, "prior_sha256": old, "current_sha256": new})
        if name.startswith(str(OLD_ROOT) + "/"):
            relative = Path(name).relative_to(OLD_ROOT)
            path = root / relative
            require(path.resolve().is_relative_to(root.resolve()), "RUNTIME_LOCATION_ROOT")
            after["path"] = str(path)
            relocated.append({"prior_path": name, "current_path": str(path), "sha256": after["sha256"]})
        total += verify_row(after, root)
        require(total <= MAX_TOTAL_BYTES, "RUNTIME_TOTAL_CAPACITY")
    require(len(changed) == 3 and len(relocated) == 25, "RUNTIME_CHANGE_CENSUS")
    total += verify_row(result["manifest"], root)
    require(total <= MAX_TOTAL_BYTES, "RUNTIME_TOTAL_CAPACITY")
    result["runtime_closure_refresh"] = {
        "schema": 3,
        "scope": "New native execution inputs only; no historical proof refresh or new qualification.",
        "prior_spec": str(PRIOR.relative_to(ROOT)), "prior_sha256": PRIOR_SHA,
        "current_source_commit": SOURCE_COMMIT,
        "changed_sources": changed, "same_source_locations": relocated,
        "asset_import_case_and_gap_facts_unchanged": True,
        "verified_input_bytes": total,
        "production_qualified": False,
    }
    return result


def execute(out):
    """Check all inputs before creating output and again afterwards; refuse every unlisted drift."""
    require(not out.exists() and not out.is_symlink(), "RUNTIME_OUTPUT_EXISTS")
    require(PRIOR.stat().st_size <= 1048576 and digest(PRIOR) == PRIOR_SHA, "RUNTIME_PRIOR_SPEC")
    producer_sha = digest(Path(__file__))
    prior = json.loads(PRIOR.read_text())
    record = renew_record(prior, ROOT)
    encoded = (json.dumps(record, indent=2) + "\n").encode()
    require(len(encoded) <= 1048576, "RUNTIME_OUTPUT_CAPACITY")
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    (out / "bake-spec.json").write_bytes(encoded)
    changes = {
        "schema": 2, "previous": {"path": str(PRIOR.relative_to(ROOT)), "sha256": PRIOR_SHA},
        "current": {"path": str((out / "bake-spec.json").resolve()),
                    "sha256": hashlib.sha256(encoded).hexdigest()},
        "producer": {"path": str(Path(__file__).relative_to(ROOT)), "sha256": producer_sha},
        "changed_sources": record["runtime_closure_refresh"]["changed_sources"],
        "same_source_locations": record["runtime_closure_refresh"]["same_source_locations"],
        "current_source_commit": SOURCE_COMMIT, "native_executed": False, "certificate_bits_written": 0,
    }
    require(digest(PRIOR) == PRIOR_SHA and digest(Path(__file__)) == producer_sha and
            renew_record(prior, ROOT) == record, "RUNTIME_INPUT_CHANGED_DURING_CAPTURE")
    (out / "changes.json").write_text(json.dumps(changes, indent=2) + "\n")
    print(json.dumps({"sources_plus_manifest": 537, "changed_sources": 3, "relocated_identical_sources": 25,
                      "native_executed": False, "certificate_bits_written": 0}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    execute(parser.parse_args().out)
