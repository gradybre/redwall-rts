#!/usr/bin/env python3
"""Reproduce the bounded four-phase source checkpoint into a new output directory."""
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
    accepted = json.loads((HERE / "evidence/static-contact-review-v1/source-sha256.json").read_text())
    for relative, expected in accepted.items():
        if digest(ROOT / relative) != expected:
            raise ValueError("HANDLING_REVIEWED_STATIC_SOURCE_CHANGED")
    selected = [HERE / name for name in ("author_program.py", "prove_program.py", "test_handling_program.py", "reproduce_program.py")]
    selected += [ROOT / relative for relative in accepted]
    selected += [HERE / "evidence/static-contact-review-v1/candidate/poses.npz",
                 HERE / "evidence/static-contact-review-v1/static-contact.json", HERE / "evidence/wood-topology-v1.json"]
    selected += [ROOT / path for path in ("tools/export_underground_envelopes.py", "tools/compile_underground_actor_content.py")]
    proof = HERE.parent / "evidence/contact-qualification"
    selected += [proof / path for path in ("author_stair_motion.py", "assess_stair_rig.py", "prove_self_clearance.py",
                                          "topology-v5/topology.json", "compact-program-compile-v2/result/mole-worker.ugactor")]
    selected += [HERE.parent / "compile_profiles.py"]
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
        commands.append(run([sys.executable, str(HERE / "author_program.py"), *common,
                             "--segments", "60", "--out", str(candidate.resolve())], args.out / "author.log"))
        for clip in ("approach", "lift", "place", "recovery"):
            commands.append(run([sys.executable, str(HERE / "prove_program.py"), *common, "--candidate", str(candidate.resolve()),
                                 "--wood-topology", str(HERE / "evidence/wood-topology-v1.json"), "--clip", clip,
                                 "--out", str((args.out / (clip + ".json")).resolve())], args.out / (clip + ".log")))
        for name, frame in (("pickup", 0), ("mid-lift", 30), ("loaded-hub", 60)):
            commands.append(run([sys.executable, str(HERE / "render_candidate.py"), *common, "--candidate", str(candidate.resolve()),
                                 "--wood-topology", str(HERE / "evidence/wood-topology-v1.json"), "--frame", str(frame),
                                 "--out", str((args.out / (name + ".png")).resolve())], args.out / (name + "-render.log")))
        commands.append(run([sys.executable, str(HERE / "test_handling_program.py"), *common,
                             "--candidate", str(candidate.resolve())], args.out / "tests.log"))
    finally:
        unchanged = sources() == pins
        outputs = {str(path.relative_to(args.out)): digest(path) for path in sorted(args.out.rglob("*")) if path.is_file()}
        invocation = {"scope": "Source-only four-phase geometry; no native replay, gameplay rate, runtime admission or quantity mapping.",
                      "production_qualified": False, "commands": commands, "elapsed_s": time.monotonic() - started,
                      "source_unchanged": unchanged, "source_sha256": pins, "output_sha256": outputs}
        (args.out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if not unchanged or len(commands) != 9:
        raise ValueError("HANDLING_REPRODUCTION_INCOMPLETE")
    print(json.dumps({"output": str(args.out), "steps": len(commands), "source_unchanged": unchanged,
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
