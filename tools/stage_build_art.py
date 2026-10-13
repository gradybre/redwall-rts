#!/usr/bin/env python3
"""The build panel's earth textures, staged for the live demo, and written into its manifest's `build` section.
Decision 1913 (Brendan's ruling on P-1913-2, "Yes, all three (78 credits)").

The proof of concept's earth view (godot/demo/build_panel/demo_build_earth.gd) draws a level's packed-earth floors
and dug walls with two tileable textures bought for it. Like every library file they are gitignored
(assets/library/, decision 0188); the ledger (docs/art-reference/asset_library/meshy_tasks.jsonl) holds their task
IDs. This copies each one, byte for byte, into the gitignored godot/demo/assets/build/, only when its SHA-256 is the
one recorded here: a missing or changed source is skipped and reported, and a staged copy it leaves behind is removed
with its .import, so a stale texture never ships. The demo reads them raw (`demo_props.gd build_texture`), so they are
named in the manifest, where tools/demo_texture_imports.py finds them. With nothing staged (CI) the earth keeps its
procedural surfaces.

The burrow mouth and the stair flight bought in the same ruling are props: tools/make_demo_props.py makes them.

	python3 tools/stage_build_art.py          # patch the staged manifest (stage_demo_assets.py runs `stage`)
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
RES = "res://demo/assets"
FOLDER = "build"

## key -> (library file, its SHA-256 as downloaded, the Meshy task that made it).
TEXTURES = {
	"earth_floor": ("texture/earth_floor/concept.png",
		"bdcec21f720387d2366e53ae7bc7154ee2483ec31332c17e2211407379cc62a6", "01a1356b-d802-70bf-8505-3cd3d221f661"),
	"earth_wall": ("texture/earth_wall/concept.png",
		"6d1ebd8dd124eed4a9f6c160a7d976381e6f8bf1a3c5a1ce1256981846474bdb", "01a1356c-8780-74c8-9bdc-f544dd7fff42"),
}


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def _remove(path: pathlib.Path) -> None:
	"""A staged copy and its .import, gone."""
	for stale in (path, path.with_name(path.name + ".import")):
		if stale.exists():
			stale.unlink()


def stage(library: pathlib.Path = LIBRARY, out: pathlib.Path = OUT) -> dict:
	"""Copy every texture whose source is present and unchanged: {"build": rows, "skipped": [reasons]}."""
	rows: dict = {}
	skipped: list[str] = []
	for key, (relative, digest, task) in TEXTURES.items():
		source = library / relative
		staged = out / FOLDER / f"{key}.png"
		reason = "" if source.is_file() else "missing"
		if not reason and sha256(source) != digest:
			reason = "changed"
		if reason:
			skipped.append(f"{key}: {reason} ({source})")
			_remove(staged)
			continue
		staged.parent.mkdir(parents=True, exist_ok=True)
		if not staged.is_file() or sha256(staged) != digest:
			shutil.copyfile(source, staged)
		rows[key] = {"path": f"{RES}/{FOLDER}/{key}.png", "source": f"assets/library/{relative}", "sha256": digest,
			"task_id": task}
	return {"build": rows, "skipped": skipped}


def main() -> int:
	"""Stage and patch the existing manifest; 0 even when something is skipped (the demo then draws its own)."""
	made = stage()
	path = OUT / "manifest.json"
	manifest = json.loads(path.read_text()) if path.is_file() else {"world": {}, "cast": {}}
	manifest["build"] = made["build"]
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(manifest, indent=1) + "\n")
	print(f"stage_build_art: {len(made['build'])} textures; skipped: {made['skipped'] or 'none'}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
