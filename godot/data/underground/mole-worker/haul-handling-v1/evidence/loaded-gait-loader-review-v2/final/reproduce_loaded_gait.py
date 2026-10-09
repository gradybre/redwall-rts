#!/usr/bin/env python3
"""Reproduce the bounded one-unit loaded source packet without changing runtime owners or profiles."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources() -> dict:
    accepted = json.loads((HERE / "evidence/program-review-v1/source-sha256.json").read_text())
    for relative, expected in accepted.items():
        if digest(ROOT / relative) != expected:
            raise ValueError("HAUL_REVIEWED_PROGRAM_SOURCE_CHANGED")
    selected = [ROOT / relative for relative in accepted]
    selected += [HERE / name for name in ("author_loaded_gait.py", "prove_carried_grip.py", "prove_loaded_gait.py",
                                          "test_loaded_gait.py", "reproduce_loaded_gait.py")]
    selected += [HERE / "evidence/program-review-v1/candidate/lift.npz", HERE / "evidence/loaded-gait-v1/carry.npz",
                 ROOT / "godot/data/item_definitions.json"]
    return {str(path.relative_to(ROOT)): digest(path) for path in selected}


def run(command: list, log: Path) -> dict:
    started = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=False)
    record = {"command": command, "returncode": result.returncode, "elapsed_s": time.monotonic() - started,
              "log": log.name, "log_sha256": digest(log)}
    if result.returncode:
        raise RuntimeError(json.dumps(record))
    return record


def require_complete_proof(path: Path) -> None:
    result = json.loads(path.read_text())["source_proof"]
    good = all(result[name] for name in ("all_intervals_complete", "non_grip_separation",
                                       "supported_feet", "continuous_two_hand_contact"))
    if not good or result["floor_penetrations"] or result["unresolved"] or result["initial_contained_vertices"]:
        raise ValueError("HAUL_SOURCE_PROOF_REFUSED:" + path.name)


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("HANDLING_OUTPUT_EXISTS")
    pins = sources()
    args.out.mkdir(parents=True)
    (args.out / "source").mkdir()
    for relative in pins:
        path = ROOT / relative
        if path.parent == HERE and path.suffix == ".py":
            shutil.copyfile(path, args.out / "source" / path.name)
    (args.out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    common = ["--palette", str(args.palette.resolve()), "--grip-palette", str(args.grip_palette.resolve())]
    candidate = args.out / "candidate"
    commands, started = [], time.monotonic()
    try:
        commands.append(run([sys.executable, str(HERE / "author_loaded_gait.py"), *common,
                             "--out", str(candidate.resolve())], args.out / "author.log"))
        for clip in ("hold", "enter", "carry", "exit"):
            proof = args.out / (clip + ".json")
            commands.append(run([sys.executable, str(HERE / "prove_loaded_gait.py"), *common,
                                 "--candidate", str(candidate.resolve()), "--wood-topology", str(HERE / "evidence/wood-topology-v1.json"),
                                 "--clip", clip, "--out", str(proof.resolve())], args.out / (clip + ".log")))
            require_complete_proof(proof)
        for frame in (0, 54, 110):
            commands.append(run([sys.executable, str(HERE / "render_candidate.py"), *common,
                                 "--candidate", str(candidate.resolve()), "--wood-topology", str(HERE / "evidence/wood-topology-v1.json"),
                                 "--frame", str(frame), "--out", str((args.out / ("carry-" + str(frame) + ".png")).resolve())],
                                args.out / ("carry-" + str(frame) + "-render.log")))
        commands.append(run([sys.executable, str(HERE / "test_loaded_gait.py"), *common,
                             "--candidate", str(candidate.resolve())], args.out / "tests.log"))
    finally:
        unchanged = sources() == pins
        outputs = {str(path.relative_to(args.out)): digest(path) for path in sorted(args.out.rglob("*")) if path.is_file()}
        invocation = {"scope": "Source-only exact-one-unit loaded geometry; no native errors, root movement, adopted rate, turns or runtime admission.",
                      "production_qualified": False, "commands": commands, "elapsed_s": time.monotonic() - started,
                      "source_unchanged": unchanged, "source_sha256": pins, "output_sha256": outputs}
        (args.out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if not unchanged or len(commands) != 9:
        raise ValueError("HAUL_REPRODUCTION_INCOMPLETE")
    print(json.dumps({"output": str(args.out), "steps": len(commands), "source_unchanged": unchanged,
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
