#!/usr/bin/env python3
"""Locate exact accepted historical inputs without changing the current consumer proof."""
from __future__ import annotations

import argparse
import copy
from contextlib import contextmanager
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import subprocess

HERE = Path(__file__).resolve().parent
CONTACT = HERE.parent
SPEC = importlib.util.spec_from_file_location("unchanged_ground_source_gate", CONTACT / "close_profile_source_gates.py")
G = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G)
ROOT = G.P.ROOT
OLD_ROOT = Path("/Users/brendan/Developer/redwall-rts-codex-ug-space")
INVOCATION = CONTACT / "analysis-carry-arm-v7/invocation.json"
INVOCATION_SHA = "5e599305d6fa7e6c15ea6b5029fd82ac4749e3cc6b0b581f6b6c30875c1934c0"
PREFIX = "godot/data/underground/mole-worker/evidence/contact-qualification/"
INPUTS = {
    "source": ("godot/demo/assets/underground-matrices/mole-grip-v3.ugpal",
               "08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda"),
    "proof": (PREFIX + "grip-proof-v2/envelopes.json",
              "69397b67ac29c8b52ab08821efeaf9984e94d6affa5f8af84888d276df308099"),
    "plan": (PREFIX + "grip-source-v3/source-plan.json",
             "0ea14eb045f32da39472c7d039463d13f7e50a372d4f35cef77e21cd1a2489b5"),
    "topology": (PREFIX + "topology-v5/topology.json",
                 "da623e5c7c3c5a6aff5c466b143425422f3aa2253497527c84f713738f997b42"),
    "world-basis": ("godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw", G.M.BASIS_SHA),
}
ARCHIVE = "godot/demo/assets/underground-matrices/mole-grip-v3.inputs"
MAX_FILE_BYTES = 16 * 1024 * 1024
LOCATORS = HERE / "historical-source-locators.json"
LOCATORS_SHA = "46741887b362bfbc32a175b7fdeb48824d54d4b39564fd5f79fe8c439139467a"
HISTORICAL_COMMIT = "ecbfcb123ddf682252421584cccb9b473b234a8d"
SNAPSHOT_PRODUCER_SHA = "4b33e7cdc9f168800f01e12e2260c33f8d039b4c9a86fd8e3070a52e0e169186"
MAX_HISTORICAL_BYTES = 262144


def require(value, code):
    if not value:
        raise ValueError(code)


def exact_file(path, expected):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= MAX_FILE_BYTES,
            "RENEWAL_INPUT_FILE")
    require(hashlib.sha256(path.read_bytes()).hexdigest() == expected, "RENEWAL_INPUT_HASH")


def argument(command, key):
    flag = "--" + key
    require(command.count(flag) == 1, "RENEWAL_INPUT_ARGUMENT")
    at = command.index(flag) + 1
    require(at < len(command) and type(command[at]) is str, "RENEWAL_INPUT_ARGUMENT")
    return at


def localize_record(record, root):
    """Change only known input locations after exact old names, authored digests and local bytes agree."""
    require(type(record) is dict and type(record.get("command")) is list, "RENEWAL_INVOCATION_SHAPE")
    result = copy.deepcopy(record)
    command = result["command"]
    root = root.resolve()
    for key, (relative, expected) in INPUTS.items():
        at = argument(command, key)
        require(command[at] == str(OLD_ROOT / relative), "RENEWAL_HISTORICAL_INPUT")
        if key != "world-basis":
            require(command[argument(command, key + "-sha256")] == expected, "RENEWAL_AUTHORED_HASH")
        path = root / relative
        require(path.resolve().is_relative_to(root), "RENEWAL_INPUT_ROOT")
        exact_file(path, expected)
        command[at] = str(path)
    at = argument(command, "import-archive")
    require(command[at] == str(OLD_ROOT / ARCHIVE), "RENEWAL_HISTORICAL_ARCHIVE")
    archive = root / ARCHIVE
    require(archive.is_dir() and not archive.is_symlink() and archive.resolve().is_relative_to(root),
            "RENEWAL_INPUT_ARCHIVE")
    # The unchanged source verifier checks every referenced archive file/hash.
    # Locating a directory here is not source or geometry permission.
    command[at] = str(archive)
    return result


def historical_locators():
    """The eleven explicit Git objects are a closed list, never an arbitrary drift fallback."""
    exact_file(LOCATORS, LOCATORS_SHA)
    manifest = json.loads(LOCATORS.read_text())
    rows = manifest["rows"]
    require(manifest["source_commit"] == HISTORICAL_COMMIT and len(rows) == 11 and
            len({row["path"] for row in rows}) == 11, "RENEWAL_LOCATOR_CENSUS")
    return rows


def historical_blob(row):
    """Bound each immutable Git blob before capture, then require the original raw-palette digest."""
    key = row["git_object"]
    require(key == HISTORICAL_COMMIT + ":godot/" + row["path"][6:] and
            type(row["bytes"]) is int and 0 < row["bytes"] <= MAX_HISTORICAL_BYTES,
            "RENEWAL_HISTORICAL_OBJECT")
    count = int(subprocess.check_output(["git", "cat-file", "-s", key], cwd=ROOT))
    require(count == row["bytes"], "RENEWAL_HISTORICAL_CAPACITY")
    raw = subprocess.check_output(["git", "cat-file", "blob", key], cwd=ROOT)
    require(len(raw) == count and hashlib.sha256(raw).hexdigest() == row["sha256"],
            "RENEWAL_HISTORICAL_HASH")
    return raw


def historical_snapshot(metadata, snapshot, original):
    """Replace only eleven owned temporary links; never write through a borrowed current-source link."""
    locators = historical_locators()
    rows = [metadata["manifest"], *metadata["sources"]]
    require(len(rows) <= 2049, "RENEWAL_SNAPSHOT_CAPACITY")
    for locator in locators:
        matches = [row for row in rows if row["path"] == locator["path"]]
        require(matches and all(row["sha256"] == locator["sha256"] for row in matches),
                "RENEWAL_HISTORICAL_METADATA")
    blobs = [(row, historical_blob(row)) for row in locators]
    result = original(metadata, snapshot)
    for row, raw in blobs:
        target = snapshot / row["path"][6:]
        require(target.is_file() and not target.is_symlink() and
                target.resolve().is_relative_to(snapshot.resolve()), "RENEWAL_SNAPSHOT_PATH")
        target.unlink()  # Unlink before creating: original() may hard-link a current source.
        with target.open("xb") as stream:
            stream.write(raw)
        result[row["path"]] = {"commit": HISTORICAL_COMMIT, "sha256": row["sha256"],
                               "git_object": row["git_object"]}
    return result


@contextmanager
def same_source_inputs(reader):
    """Adapt only locations in the exact accepted reader; restore both hooks on every exit."""
    exact_file(Path(reader.__file__), SNAPSHOT_PRODUCER_SHA)
    exact_file(INVOCATION, INVOCATION_SHA)
    original_read, original_snapshot = reader.read_record, reader.snapshot_sources

    def read_record(path, *args, **kwargs):
        if Path(path).resolve() != INVOCATION.resolve():
            return original_read(path, *args, **kwargs)
        exact_file(INVOCATION, INVOCATION_SHA)
        return localize_record(original_read(path, *args, **kwargs), ROOT)

    def snapshot_sources(metadata, snapshot):
        return historical_snapshot(metadata, snapshot, original_snapshot)

    try:
        reader.read_record, reader.snapshot_sources = read_record, snapshot_sources
        yield
    finally:
        reader.read_record, reader.snapshot_sources = original_read, original_snapshot


def execute(out, revision):
    """All mathematical, primitive, source and role checks remain unchanged."""
    require(not out.exists() and not out.is_symlink(), "RENEWAL_OUTPUT_EXISTS")
    out = out.resolve()
    exact_file(INVOCATION, INVOCATION_SHA)
    wrapper_sha = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    reader = G.M.I.M.W
    original_argv = sys.argv
    invocation = reader.read_record(INVOCATION)
    localized = localize_record(invocation, ROOT)
    try:
        with same_source_inputs(reader):
            sys.argv = [str(CONTACT / "close_profile_source_gates.py"), str(out), "--consumer-revision", revision]
            G.main()
    finally:
        sys.argv = original_argv
    exact_file(INVOCATION, INVOCATION_SHA)
    require(localize_record(reader.read_record(INVOCATION), ROOT) == localized, "RENEWAL_INPUT_DRIFT")
    historical_locators()
    require(hashlib.sha256(Path(__file__).read_bytes()).hexdigest() == wrapper_sha, "RENEWAL_ADAPTER_DRIFT")
    report_path = out / "ground-closure.json"
    report = json.loads(report_path.read_text())
    report["producer_sources"][str(Path(__file__).relative_to(ROOT))] = wrapper_sha
    report["input_sources"][str(LOCATORS.relative_to(ROOT))] = LOCATORS_SHA
    report["input_location_adapter"] = {
        "original_invocation_sha256": INVOCATION_SHA,
        "original_root": str(OLD_ROOT), "local_root": str(ROOT),
        "same_file_inputs": {key: {"path": path, "sha256": sha} for key, (path, sha) in INPUTS.items()},
        "archive": ARCHIVE, "archive_verified_by_unchanged_source_reader": True,
        "historical_source_locators": str(LOCATORS.relative_to(ROOT)),
        "historical_source_locators_sha256": LOCATORS_SHA,
        "current_consumer_source_unchanged": True,
        "only_locations_changed": True, "certificate_bits_written": 0,
    }
    (out / "localized-invocation.json").write_text(json.dumps(localized, indent=2) + "\n")
    report_path.write_text(json.dumps(report, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--consumer-revision", required=True)
    args = parser.parse_args()
    execute(args.out, args.consumer_revision)


if __name__ == "__main__":
    main()
