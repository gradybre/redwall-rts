#!/usr/bin/env python3
"""Check or renew the runtime source pins of the active mole profile publication (ADR 1192).

The active publication's (`qualified-haul-v6`, ADR 1200) generated `catalog_source.gd` pins the SHA-256 of every
runtime consumer script. `mole_profile_catalog.gd` refuses with
MOLE_CATALOG_SOURCE_DRIFT when a cached script no longer matches its pin. Any
edit to a consumer therefore needs its pin renewed in the same commit.

    python3 tools/renew_source_pins.py --check   # exit 1 and list drift
    python3 tools/renew_source_pins.py --write   # renew DIGESTS + manifest consumers

`--write` changes only the current consumer digests. It records every renewal
under the manifest's `renewals` list and never rewrites `prerequisite_pins`,
the wire, the actor or any other reviewed publication field.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = ROOT / "godot/data/underground/mole-worker/qualified-stone-v7"
LIST = re.compile(r"const (PATHS|DIGESTS): PackedStringArray = \[\n(.*?)\n\]", re.S)


def _entries(text: str, name: str) -> list[str]:
    """Return the quoted strings of one generated PackedStringArray constant."""
    match = next((m for m in LIST.finditer(text) if m.group(1) == name), None)
    if match is None:
        raise ValueError(f"{name} constant not found")
    return re.findall(r'"([^"]+)"', match.group(2))


def drift(publication: Path) -> list[tuple[str, str, str]]:
    """List (repo path, pinned digest, current digest) for every stale consumer."""
    text = (publication / "catalog_source.gd").read_text()
    paths, digests = _entries(text, "PATHS"), _entries(text, "DIGESTS")
    if len(paths) != len(digests):
        raise ValueError("PATHS and DIGESTS differ in length")
    stale = []
    for res_path, pinned in zip(paths, digests):
        repo_path = "godot/" + res_path.removeprefix("res://")
        current = hashlib.sha256((ROOT / repo_path).read_bytes()).hexdigest()
        if current != pinned:
            stale.append((repo_path, pinned, current))
    return stale


def renew(publication: Path, stale: list[tuple[str, str, str]]) -> None:
    """Replace each stale digest in the accessor and the manifest's current consumer map."""
    source = publication / "catalog_source.gd"
    text = source.read_text()
    for _, pinned, current in stale:
        if text.count(f'"{pinned}"') != 1:
            raise ValueError(f"pin {pinned} is not unique in {source}")
        text = text.replace(f'"{pinned}"', f'"{current}"')
    source.write_text(text)
    manifest_path = publication / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for repo_path, pinned, current in stale:
        if manifest["consumers"].get(repo_path) != pinned:
            raise ValueError(f"manifest consumer {repo_path} does not match the accessor pin")
        manifest["consumers"][repo_path] = current
        manifest.setdefault("renewals", []).append({"path": repo_path, "from": pinned, "to": current})
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    parser.add_argument("--publication", type=Path, default=ACTIVE)
    args = parser.parse_args()
    stale = drift(args.publication)
    for repo_path, pinned, current in stale:
        print(f"{'renewed' if args.write else 'DRIFT'} {repo_path} {pinned[:12]} -> {current[:12]}")
    if args.write and stale:
        renew(args.publication, stale)
        return 0
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
