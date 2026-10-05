#!/usr/bin/env python3
"""Renew unchanged v3 geometry after reviewed frontier consumer changes.

Historical bytes prove the earlier publication; they never replace a live
consumer. All current consumers and native evidence are checked separately.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = "godot/data/underground/mole-worker/profile-publication-v3/"
E = "docs/validation/evidence/underground-frontier-profile-renewal-2026-10-05/"
REVIEW = E + "source-compatibility-review.json"
REVIEW_SHA = "12085f7793f6520057a8fae21ae7460e43d437c58dd235aac29e04f14da708d1"
OLD_MANIFEST_SHA = "8f210e11768131779e6c825d7a3d2509cb32076aedd6891e6573489d1b6814c1"
OLD_CONSTANTS_SHA = "fca8e5410940b8dfa98a1e7796b4138f25464402e784de46447d020402c06e0c"
WIRE_SHA = "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204"
COMMIT = "8003bfe155092e9a8bc8b5590228e6069b859173"
CHANGED = (
    "godot/scripts/core/underground_work_face.gd",
    "godot/scripts/core/underground_routes.gd",
    "godot/scripts/core/underground_world_routes.gd",
)
NATIVE_EXECUTED = (
    "godot/scripts/core/underground_profiles.gd",
    CHANGED[1], CHANGED[2],
    "godot/data/underground/mole-worker/mole_profile_driver.gd",
    "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
)


def need(condition, code):
    if not condition:
        raise ValueError("FRONTIER_RENEWAL_" + code)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read(name, expected):
    """All authority comes from bounded, canonical repository files with fixed hashes."""
    need(type(name) is str and name == str(PurePosixPath(name)) and
         not name.startswith("/") and ".." not in PurePosixPath(name).parts, "PATH")
    path = ROOT / name
    need(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(ROOT)
         and path.stat().st_size <= 32 * 1024 * 1024, "FILE:" + name)
    raw = path.read_bytes()
    need(type(expected) is str and len(expected) == 64 and digest(raw) == expected, "HASH:" + name)
    return raw


def native(review, consumers, pins):
    """Bind actual before/after consumer bytes, report and exact native oracle result."""
    raw = {}
    for name, sha in review["native_report"].items():
        path = E + "native-1/" + name
        raw[name] = read(path, sha)
        pins[path] = sha
    before = json.loads(raw["sources-before.json"])
    need(before == json.loads(raw["sources-after.json"]), "NATIVE_SOURCE_DRIFT")
    for name in NATIVE_EXECUTED:
        actual = [sha for path, sha in before.items() if path.endswith("/" + name)]
        need(actual == [consumers[name]], "NATIVE_CONSUMER:" + name)
    invocation = json.loads(raw["invocation.json"])
    need(len(invocation["commands"]) == 2 and all(
        row["exit"] == 0 and row["raw_diagnostic"] is False for row in invocation["commands"])
        and all(invocation[key] is True for key in
                ("source_unchanged", "override_restored", "import_sidecars_restored")), "NATIVE_INVOCATION")
    report, verification = json.loads(raw["report.json"]), json.loads(raw["verification.json"])
    need(report["failures"] == [] and report["program_version"] == 5 and report["poses"] == 1504
         and report["resolution"] == [1280, 720] and report["assertions"] == 9336
         and report["production_qualified"] is False and digest(raw["native.bin"]) == report["native_sha256"],
         "NATIVE_REPORT")
    need(verification["poses"] == 1504 and verification["exact_native_scalar_comparisons"] == 469248
         and verification["assertions"] == 9336 and verification["production_qualified"] is False,
         "NATIVE_ORACLE")


def inputs():
    """Recheck all 509 old prerequisites and every current consumer before returning output."""
    pins = {OLD + "manifest.json": OLD_MANIFEST_SHA, OLD + "catalog_source.gd": OLD_CONSTANTS_SHA,
            OLD + "mole-worker.ugprof": WIRE_SHA, REVIEW: REVIEW_SHA}
    initial = {name: read(name, sha) for name, sha in pins.items()}
    old = json.loads(initial[OLD + "manifest.json"])
    review = json.loads(initial[REVIEW])
    need(review["accepted"] is True and review["geometry_or_clock_equations_changed"] is False
         and review["findings"] == [] and review["base_commit"] == old["consumer_commit"]
         and review["consumer_commit"] == COMMIT, "REVIEW")
    replacements = review["changed_consumers"]
    consumers = review["consumer_sources"]
    need(tuple(replacements) == CHANGED and set(consumers) == set(old["consumers"])
         and len(consumers) == 9 and len(old["prerequisite_pins"]) == 509, "CENSUS")
    for name, expected in old["prerequisite_pins"].items():
        locator = name
        if name in replacements:
            row = replacements[name]
            need(row["before_sha256"] == expected == old["consumers"][name]
                 and row["after_sha256"] == consumers[name], "HISTORICAL_IDENTITY")
            locator = row["historical_locator"]
        read(locator, expected)
        need(locator not in pins or pins[locator] == expected, "PIN_CONFLICT")
        pins[locator] = expected
    for name, expected in consumers.items():
        original = subprocess.check_output(["git", "show", COMMIT + ":" + name], cwd=ROOT)
        need(digest(original) == expected, "REVIEWED_COMMIT:" + name)
        read(name, expected)
        need(name in replacements or old["consumers"][name] == expected, "UNREVIEWED_DELTA")
        pins[name] = expected
    native(review, consumers, pins)
    constants = initial[OLD + "catalog_source.gd"]
    constants = constants.replace(b"publish_work_approach_profiles.py", b"renew_work_approach_profiles.py")
    constants = constants.replace(old["consumer_commit"].encode(), COMMIT.encode())
    for name in CHANGED:
        previous = old["consumers"][name].encode()
        need(constants.count(previous) == 1, "CONSTANT_IDENTITY")
        constants = constants.replace(previous, consumers[name].encode())
    need(len(constants) <= 4096, "CONSTANT_SIZE")
    producer = Path(__file__).relative_to(ROOT).as_posix()
    pins[producer] = digest(Path(__file__).read_bytes())
    manifest = dict(old)
    manifest.update(consumer_commit=COMMIT, consumers=consumers, prerequisite_pins=pins,
                    constants_sha256=digest(constants), source_review_sha256=REVIEW_SHA,
                    historical_source_replacements=replacements, renewed_from_sha256=OLD_MANIFEST_SHA,
                    source_native_replay_sha256=review["native_report"]["verification.json"],
                    scope="Unchanged v3 source geometry renewed for reviewed frontier consumers; actual World admission and paid work remain separate.")
    return initial[OLD + "mole-worker.ugprof"], constants, manifest


def publish(out):
    """Create an immutable successor only after final prerequisite revalidation."""
    need(not out.exists() and not out.is_symlink() and out.resolve().is_relative_to(HERE), "OUTPUT")
    wire, constants, manifest = inputs()
    for path, sha in manifest["prerequisite_pins"].items():
        read(path, sha)
    out.mkdir(parents=True)
    for name, raw in (("mole-worker.ugprof", wire), ("catalog_source.gd", constants),
                      ("manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())):
        with (out / name).open("xb") as stream:
            stream.write(raw)
    print(json.dumps({"profiles": 26, "boxes": 250, "wire_sha256": digest(wire),
                      "current_consumers": 9, "world_activation_qualified": False}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    publish(parser.parse_args().out)
