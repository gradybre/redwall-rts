#!/usr/bin/env python3
"""Self-test for tools/stage_build_art.py (decision 1913, the build panel's earth textures). Runs without the art
library: the sources are small files written into a temporary folder, with the tool's recorded hashes swapped for
theirs.

NEGATIVE TESTS COME FIRST:

  N01  a source missing from the library is skipped and reported; the other is staged.
  N02  a source whose SHA-256 differs from the record is skipped, and a copy staged before is removed with its
       .import (a stale texture never ships).
  N03  a staged texture no key names (a renamed or dropped one) is removed with its .import.

Then: a staged texture is the source byte for byte, its manifest row names it under res://demo/assets/build/ with its
source, hash and task; a second run copies nothing new; `main` writes the `build` section and leaves the manifest's
other sections as they were; and every recorded key has a task ID in the committed ledger.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import stage_build_art as art  # noqa: E402

FAILURES: list[str] = []
LEDGER = art.ROOT / "docs/art-reference/asset_library/meshy_tasks.jsonl"


def check(name: str, ok: bool, detail: str = "") -> None:
	"""Record one check."""
	print(("PASS " if ok else "FAIL ") + name + (f": {detail}" if detail and not ok else ""))
	if not ok:
		FAILURES.append(name)


def fixture(root: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path, dict]:
	"""A library with both sources (small bytes), an empty staging folder, and the tool's table for them."""
	library = root / "library"
	out = root / "out"
	table = {}
	for key, (relative, _digest, task) in art.TEXTURES.items():
		path = library / relative
		path.parent.mkdir(parents=True, exist_ok=True)
		data = f"png bytes of {key}".encode()
		path.write_bytes(data)
		table[key] = (relative, hashlib.sha256(data).hexdigest(), task)
	return library, out, table


def run(root: pathlib.Path) -> None:
	"""Every case, in one temporary folder each."""
	saved = dict(art.TEXTURES)
	try:
		library, out, table = fixture(root / "n01")
		art.TEXTURES.clear()
		art.TEXTURES.update(table)
		(library / table["earth_wall"][0]).unlink()
		made = art.stage(library, out)
		check("N01 a missing source is skipped and reported", "earth_wall" not in made["build"]
			and any(s.startswith("earth_wall: missing") for s in made["skipped"]))
		check("N01 the other is staged", (out / "build/earth_floor.png").is_file())
		library, out, table = fixture(root / "n02")
		art.TEXTURES.update(table)
		art.stage(library, out)
		(out / "build/earth_floor.png.import").write_text("[remap]\n")
		(library / table["earth_floor"][0]).write_bytes(b"something else")
		made = art.stage(library, out)
		check("N02 a changed source is skipped", any(s.startswith("earth_floor: changed") for s in made["skipped"]))
		check("N02 its staged copy and .import are removed", not (out / "build/earth_floor.png").exists()
			and not (out / "build/earth_floor.png.import").exists())
		library, out, table = fixture(root / "ok")
		art.TEXTURES.update(table)
		made = art.stage(library, out)
		row = made["build"]["earth_wall"]
		check("a staged texture is its source byte for byte",
			(out / "build/earth_wall.png").read_bytes() == (library / table["earth_wall"][0]).read_bytes())
		check("its row", row == {"path": "res://demo/assets/build/earth_wall.png",
			"source": f"assets/library/{table['earth_wall'][0]}", "sha256": table["earth_wall"][1],
			"task_id": table["earth_wall"][2]}, json.dumps(row))
		before = (out / "build/earth_wall.png").stat().st_mtime_ns
		art.stage(library, out)
		check("a second run copies nothing new", (out / "build/earth_wall.png").stat().st_mtime_ns == before)
		(out / "build/earth_old.png").write_bytes(b"old")
		(out / "build/earth_old.png.import").write_text("[remap]\n")
		art.stage(library, out)
		check("N03 a texture no key names is removed", not (out / "build/earth_old.png").exists()
			and not (out / "build/earth_old.png.import").exists())
		main_writes(library, out)
	finally:
		art.TEXTURES.clear()
		art.TEXTURES.update(saved)


def main_writes(library: pathlib.Path, out: pathlib.Path) -> None:
	"""`main` patches the manifest's `build` section only."""
	(out / "manifest.json").write_text(json.dumps({"world": {"a": 1}, "ui": {"b": 2}, "build": {"stale": 0}}))
	saved = (art.LIBRARY, art.OUT)
	art.LIBRARY, art.OUT = library, out
	try:
		art.main()
	finally:
		art.LIBRARY, art.OUT = saved
	manifest = json.loads((out / "manifest.json").read_text())
	check("main writes the build section", set(manifest["build"]) == set(art.TEXTURES), json.dumps(manifest["build"]))
	check("and leaves the others", manifest["world"] == {"a": 1} and manifest["ui"] == {"b": 2})


def ledger_tasks() -> set[str]:
	"""Every task ID in the committed ledger."""
	return {str(json.loads(line).get("task_id", "")) for line in LEDGER.read_text().splitlines() if line.strip()}


def main() -> int:
	"""Run every case; 1 on any failure."""
	with tempfile.TemporaryDirectory() as folder:
		run(pathlib.Path(folder))
	tasks = ledger_tasks()
	check("every recorded texture's task is in the ledger", all(t in tasks for _r, _d, t in art.TEXTURES.values()))
	print(f"test_stage_build_art: {len(FAILURES)} failure(s)")
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
