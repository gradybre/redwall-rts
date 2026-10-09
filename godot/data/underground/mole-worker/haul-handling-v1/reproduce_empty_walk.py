#!/usr/bin/env python3
"""Reproduce the tool-free stand/walk packet (ADR 1198 step 1) into a new evidence directory."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
OWN = ("author_empty_walk.py", "prove_empty_walk.py", "test_empty_walk.py", "reproduce_empty_walk.py")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources() -> dict:
    """The reviewed four-phase program sources stay pinned; this packet only adds files."""
    accepted = json.loads((HERE / "evidence/program-review-v1/source-sha256.json").read_text())
    for relative, expected in accepted.items():
        if digest(ROOT / relative) != expected:
            raise ValueError("EMPTY_WALK_REVIEWED_PROGRAM_SOURCE_CHANGED")
    selected = [ROOT / relative for relative in accepted]
    selected += [HERE / name for name in OWN]
    selected += [HERE / "author_loaded_gait.py", HERE / "author_program.py", HERE / "prove_program.py",
                 HERE / "evidence/program-review-v1/candidate/approach.npz",
                 HERE / "evidence/program-review-v1/candidate/recovery.npz",
                 ROOT / "godot/data/underground/mole-worker/evidence/contact-qualification/compile_state_program.py",
                 ROOT / "godot/data/underground/mole-worker/evidence/contact-qualification/prove_state_handoffs.py"]
    return {str(path.relative_to(ROOT)): digest(path) for path in sorted(set(selected))}


def run(command: list, log: Path) -> dict:
    started = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=HERE, stdout=stream, stderr=subprocess.STDOUT, check=False)
    record = {"command": [Path(part).name if "/" in part else part for part in command],
              "returncode": result.returncode, "elapsed_s": round(time.monotonic() - started, 3),
              "log": log.name, "log_sha256": digest(log)}
    if result.returncode:
        raise RuntimeError(json.dumps(record))
    return record


def require_complete(path: Path) -> None:
    report = json.loads(path.read_text())
    for name, proof in report["source_proof"].items():
        if proof["floor_penetrations"] or not proof["supported_feet"]:
            raise ValueError("EMPTY_WALK_PROOF_REFUSED:" + name)
        separation = proof.get("stock_separation")
        if separation is not None and not (separation["all_intervals_complete"] and separation["non_grip_separation"]
                                           and not separation["floor_penetrations"]):
            raise ValueError("EMPTY_WALK_STOCK_REFUSED:" + name)


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "world-basis", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink():
        raise ValueError("HANDLING_OUTPUT_EXISTS")
    pins = sources()
    args.out.mkdir(parents=True)
    (args.out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    common = ["--palette", str(args.palette.resolve()), "--grip-palette", str(args.grip_palette.resolve())]
    candidate, proof = args.out / "candidate", args.out / "empty-walk.json"
    commands, started = [], time.monotonic()
    try:
        commands.append(run([sys.executable, "-B", str(HERE / "author_empty_walk.py"), *common,
                             "--out", str(candidate.resolve())], args.out / "author.log"))
        commands.append(run([sys.executable, "-B", str(HERE / "prove_empty_walk.py"), *common,
                             "--candidate", str(candidate.resolve()), "--world-basis", str(args.world_basis.resolve()),
                             "--out", str(proof.resolve())], args.out / "prove.log"))
        require_complete(proof)
        commands.append(run([sys.executable, "-B", str(HERE / "test_empty_walk.py"), *common,
                             "--world-basis", str(args.world_basis.resolve()), "--candidate", str(candidate.resolve()),
                             "--proof", str(proof.resolve())], args.out / "tests.log"))
    finally:
        unchanged = sources() == pins
        outputs = {str(path.relative_to(args.out)): digest(path) for path in sorted(args.out.rglob("*"))
                   if path.is_file() and path.name != "invocation.json"}
        invocation = {"scope": "Source-only tool-free stand/walk and haul joins with all-yaw row geometry; "
                               "no native replay, runtime row, route or World permission.",
                      "production_qualified": False, "commands": commands,
                      "palette_sha256": "5b368eb3ad594b4a6f82b5981a891150e6f7053944daf888d4ab5aa293c822fe",
                      "grip_palette_sha256": "08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda",
                      "world_basis_sha256": digest(args.world_basis),
                      "source_unchanged": unchanged, "source_sha256": pins, "output_sha256": outputs}
        (args.out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    if not unchanged or len(commands) != 3:
        raise ValueError("EMPTY_WALK_REPRODUCTION_INCOMPLETE")
    print(json.dumps({"output": str(args.out), "steps": len(commands), "source_unchanged": unchanged,
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
