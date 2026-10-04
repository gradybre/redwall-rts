#!/usr/bin/env python3
"""Validate and inspect the underground implementation queue; never launch work."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_QUEUE = ROOT / "docs/tasks/underground-build-queue.json"
STATES = {"queued", "running", "implemented", "blocked", "verified"}
REQUIREMENT = re.compile(r"^\| (UG-[A-Z]+-\d{3}) \|", re.MULTILINE)


def load_requirements(root: Path) -> set[str]:
    """Read the actual approved requirement tables, rather than a copied count."""
    directory = root / "docs/design/underground-planning"
    names = ("shape-and-surface-requirements.md", "levels-and-connections.md",
             "furnishing-and-room-use.md")
    return {item for name in names for item in
            REQUIREMENT.findall((directory / name).read_text())}


def overlaps(left: str, right: str) -> bool:
    """Ownership paths are exact files or directory prefixes ending in '/'."""
    return left == right or (left.endswith("/") and right.startswith(left)) or (
        right.endswith("/") and left.startswith(right))


def validate(queue: dict, requirements: set[str]) -> list[str]:
    """Reject missing scope, invalid dependency graphs and active file conflicts."""
    errors: list[str] = []
    lanes = queue.get("lanes", [])
    by_id = {lane["id"]: lane for lane in lanes}
    if len(by_id) != len(lanes):
        errors.append("duplicate lane id")
    covered: set[str] = set()
    for lane in lanes:
        name = lane["id"]
        if lane.get("status") not in STATES:
            errors.append(f"{name}: unknown status")
        if not lane.get("owns") or not lane.get("acceptance"):
            errors.append(f"{name}: missing file ownership or acceptance gates")
        for path in lane.get("owns", []):
            canonical = str(PurePosixPath(path)) + ("/" if path.endswith("/") else "")
            if (path.startswith("/") or ".." in PurePosixPath(path).parts
                    or path != canonical or path in (".", "./", "")
                    or any(char in path for char in "*?[]\\")):
                errors.append(f"{name}: ownership must be a repo path or prefix: {path}")
        for dependency in lane.get("depends_on", []):
            if dependency not in by_id:
                errors.append(f"{name}: unknown dependency {dependency}")
            elif lane["status"] in {"running", "implemented", "verified"} \
                    and by_id[dependency]["status"] != "verified":
                errors.append(f"{name}: active or completed before dependency {dependency} verified")
        lease = lane.get("lease", {})
        if lease.get("state") not in {"free", "held", "released"}:
            errors.append(f"{name}: missing or invalid file lease")
        if lease.get("state") == "free" and (lane["status"] != "queued"
                or lane.get("agent") or lane.get("branch") or lane.get("evidence")):
            errors.append(f"{name}: only an unassigned, never-started queued lane may have a free lease")
        if lease.get("state") == "released" and not lease.get("stop_evidence"):
            errors.append(f"{name}: file lease released without worker-stop evidence")
        if lane["status"] == "running" and lease.get("state") != "held":
            errors.append(f"{name}: running worker has no file lease")
        if lane["status"] == "verified" and lease.get("state") != "released":
            errors.append(f"{name}: verified work must release its file lease explicitly")
        if lane.get("kind", "implementation") != "qualification":
            covered.update(lane.get("requirements", []))
        for item in set(lane.get("requirements", [])) - requirements:
            errors.append(f"{name}: unknown requirement: {item}")
        if lane["status"] == "verified":
            evidence = lane.get("evidence", {})
            for key in ("commit", "tests", "diagnostics", "review", "integration"):
                if not evidence.get(key):
                    errors.append(f"{name}: verified without {key} evidence")
    for item in sorted(requirements - covered):
        errors.append(f"requirement has no owner: {item}")
    visiting: set[str] = set()
    visited: set[str] = set()

    def walk(name: str) -> None:
        if name in visiting:
            errors.append(f"dependency cycle at {name}")
            return
        if name in visited or name not in by_id:
            return
        visiting.add(name)
        for dependency in by_id[name].get("depends_on", []):
            walk(dependency)
        visiting.remove(name)
        visited.add(name)

    for name in by_id:
        walk(name)
    active = [lane for lane in lanes if lane.get("lease", {}).get("state") == "held"]
    for index, left in enumerate(active):
        for right in active[index + 1:]:
            for a in left["owns"]:
                for b in right["owns"]:
                    if overlaps(a, b):
                        errors.append(f"active ownership conflict {left['id']} / "
                                      f"{right['id']}: {a} overlaps {b}")
    return errors


def ready_lanes(queue: dict) -> list[dict]:
    """Only reviewed, integrated dependencies release queued, unclaimed work."""
    lanes = queue["lanes"]
    done = {lane["id"] for lane in lanes if lane["status"] == "verified"}
    leases = [path for lane in lanes if lane.get("lease", {}).get("state") == "held"
              for path in lane["owns"]]
    ready = []
    for lane in lanes:
        if lane["status"] != "queued":
            continue
        if not set(lane.get("depends_on", [])).issubset(done):
            continue
        if any(overlaps(path, lease) for path in lane["owns"] for lease in leases):
            continue
        ready.append(lane)
        leases.extend(lane["owns"])
    return ready


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "status", "ready"))
    parser.add_argument("--queue", type=Path, default=DEFAULT_QUEUE)
    args = parser.parse_args()
    queue = json.loads(args.queue.read_text())
    requirements = load_requirements(ROOT)
    errors = validate(queue, requirements)
    if errors:
        for error in errors:
            print(f"error: {error}")
        return 1
    if args.command == "validate":
        print(f"ok: {len(queue['lanes'])} lanes, {len(requirements)} requirements; "
              "complete coverage, acyclic dependencies, no active file conflicts")
    elif args.command == "ready":
        print(json.dumps(ready_lanes(queue), indent=2))
    else:
        for lane in queue["lanes"]:
            dependencies = ", ".join(lane.get("depends_on", [])) or "none"
            print(f"{lane['id']} [{lane['status']}] {lane['title']} "
                  f"(dependencies: {dependencies})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
