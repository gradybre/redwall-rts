#!/usr/bin/env python3
"""Build the standalone Windows demo: compress -> import -> export -> verify -> zip. Decision 0196.

    python3 tools/build_demo_windows.py --out <folder>

writes <folder>/redwall-demo-windows/ (RedwallDemo.exe, RedwallDemo.console.exe, RedwallDemo.pck,
README.txt) and <folder>/redwall-demo-windows.zip, plus build.json (what was built and measured) and
the export and verification logs beside them.

  1. Refuse unless the demo's assets are staged (tools/stage_demo_assets.py): a build on placeholder
     shapes is not the demo. `--allow-unstaged` overrides.
  2. tools/demo_texture_imports.py: import, set the staged textures' VRAM compression, reimport until
     nothing changes.
  3. Merge tools/demo_build/windows_export_preset.cfg into godot/export_presets.cfg (gitignored and
     local; other presets in it are kept) by preset name.
  4. `godot --headless --path godot --export-debug "Windows Desktop (demo)"` -- a PLAYTEST build, on the
     debug template, by Brendan's ruling of 2026-10-01 (decision 0562): a GDScript error is then reported
     with its script frames and the game carries on, where the release template ends the process at a
     null call with no word. `--release` exports on the release template instead (for a final build).
     Needs Godot's Windows export templates (windows_debug_x86_64.exe, or windows_release_x86_64.exe) for
     this Godot version; without them it stops and says how to install them. `--pack-only` exports just the .pck (no template needed) to check it.
  5. Verify the pack with the editor binary (`--main-pack`, tools/godot/verify_demo_pack.gd): the
     main scene resolves to the demo, the staged assets and raw atlases are packed, the demo boots,
     the beaver's flat tail is bound; screenshots of it.
  6. Write README.txt (tools/demo_build/README.txt, with this build's facts) and zip the folder.

Before the export it writes godot/demo/build_info.json (gitignored) -- the commit, the build time and Godot's
version -- which the export packs (include_filter "*.json") and the playtest log's header quotes (decision 0562);
it is removed again when the build ends, so a run from the project never reads a stale one.

The export log is scanned: any `ERROR:` line fails the build. Export warnings are kept in build.json.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import demo_texture_imports  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
PRESET_SOURCE = ROOT / "tools/demo_build/windows_export_preset.cfg"
README_SOURCE = ROOT / "tools/demo_build/README.txt"
VERIFY_SCRIPT = ROOT / "tools/godot/verify_demo_pack.gd"
BUILD_INFO = PROJECT / "demo/build_info.json"
PRESET_NAME = "Windows Desktop (demo)"
FOLDER = "redwall-demo-windows"
EXE = "RedwallDemo.exe"
DEMO_SCENE = "res://demo/demo_village.tscn"
## The template each export mode needs (decision 0562: playtest builds are debug, `--release` for a final build).
TEMPLATES = {"debug": "windows_debug_x86_64.exe", "release": "windows_release_x86_64.exe"}
EXPORT_FLAGS = {"debug": "--export-debug", "release": "--export-release"}
EXPORT_TIMEOUT = 3600
VERIFY_TIMEOUT = 600


# --- the export preset ------------------------------------------------------------------------

SECTION = re.compile(r"^\[preset\.(\d+)(\.options)?\]\s*$")


def split_presets(text: str) -> tuple[str, list[dict]]:
	"""(the text before the first preset, [{"name", "body", "options"}]) of an export_presets.cfg."""
	head, presets, current, key = [], [], None, None
	for line in text.splitlines(keepends=True):
		match = SECTION.match(line)
		if match:
			index = int(match.group(1))
			if current is None or current["index"] != index:
				current = {"index": index, "name": None, "body": "", "options": ""}
				presets.append(current)
			key = "options" if match.group(2) else "body"
			continue
		if current is None:
			head.append(line)
			continue
		current[key] += line
		name = re.match(r'^name="(.*)"\s*$', line)
		if key == "body" and name:
			current["name"] = name.group(1)
	return "".join(head), presets


def merge_preset(existing: str, ours: str, name: str = PRESET_NAME) -> str:
	"""`existing` with the preset called `name` replaced by (or appended as) the one in `ours`, every
	preset renumbered from 0 in order. The other presets, and `existing`'s leading comments, are kept."""
	head, presets = split_presets(existing)
	_, mine = split_presets(ours)
	if len(mine) != 1 or mine[0]["name"] != name:
		raise ValueError(f"the preset source must hold exactly one preset named {name!r}")
	kept = [preset for preset in presets if preset["name"] != name] + mine
	parts = [head.rstrip("\n") + "\n\n" if head.strip() else ""]
	for index, preset in enumerate(kept):
		parts.append(f"[preset.{index}]\n{preset['body'].rstrip()}\n\n")
		parts.append(f"[preset.{index}.options]\n{preset['options'].rstrip()}\n\n")
	return "".join(parts).rstrip("\n") + "\n"


def install_preset(project: pathlib.Path = PROJECT, source: pathlib.Path = PRESET_SOURCE) -> pathlib.Path:
	"""Merge the demo's preset into the project's export_presets.cfg; idempotent."""
	target = project / "export_presets.cfg"
	existing = target.read_text() if target.is_file() else ""
	merged = merge_preset(existing, source.read_text())
	if merged != existing:
		target.write_text(merged)
	return target


# --- running Godot ----------------------------------------------------------------------------

def strip_ansi(text: str) -> str:
	"""Godot colours its console output."""
	return re.sub(r"\x1b\[[0-9;]*m", "", text)


def run(command: list[str], log: pathlib.Path, timeout: int) -> tuple[int, str]:
	"""Run one bounded command, keep its whole output in `log`, return (status, output)."""
	completed = subprocess.run(command, capture_output=True, text=True, check=False, timeout=timeout)
	output = strip_ansi(completed.stdout + completed.stderr)
	log.write_text("$ " + " ".join(command) + "\n" + output)
	return completed.returncode, output


def godot_version(godot: str) -> str:
	"""The export templates' folder name for a Godot binary."""
	return templates_version(subprocess.run([godot, "--version"], capture_output=True, text=True, check=True).stdout)


def templates_version(version: str) -> str:
	"""`4.7.2.stable` from `4.7.2.stable.official.ed1daf0bf`, `4.8.stable` from `4.8.stable.official.x`."""
	match = re.match(r"\s*(\d+(?:\.\d+)+\.[a-z]+\d*)", version)
	if match is None:
		raise ValueError(f"not a Godot version: {version!r}")
	return match.group(1)


def templates_dir(version: str) -> pathlib.Path:
	"""Where Godot keeps its export templates on this OS."""
	if sys.platform == "darwin":
		base = pathlib.Path.home() / "Library/Application Support/Godot"
	elif sys.platform.startswith("win"):
		base = pathlib.Path.home() / "AppData/Roaming/Godot"
	else:
		base = pathlib.Path.home() / ".local/share/godot"
	return base / "export_templates" / version


def error_lines(output: str) -> list[str]:
	"""Every engine error line in a log."""
	return [line for line in output.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "USER ERROR:"))]


def warning_lines(output: str) -> list[str]:
	"""Every engine warning line in a log, once each."""
	return sorted({line for line in output.splitlines() if line.startswith(("WARNING:", "USER WARNING:"))})


def export_mode(release: bool) -> str:
	"""'debug' (a playtest build, the default) or 'release' (`--release`)."""
	return "release" if release else "debug"


def export(godot: str, target: pathlib.Path, logs: pathlib.Path, pack_only: bool, mode: str = "debug") -> dict:
	"""Export the preset to `target` (an .exe on `mode`'s template, or a .pck with pack_only); refuse on any error
	line."""
	flag = "--export-pack" if pack_only else EXPORT_FLAGS[mode]
	status, output = run([godot, "--headless", "--path", str(PROJECT), flag, PRESET_NAME, str(target)],
		logs / "export.log", EXPORT_TIMEOUT)
	errors = error_lines(output)
	pack = target.with_suffix(".pck")
	if status != 0 or errors or not target.is_file() or not pack.is_file():
		raise RuntimeError(f"export failed (status {status}); see {logs / 'export.log'}:\n" + "\n".join(errors[:20]))
	return {"command": flag, "mode": mode, "status": status, "warnings": warning_lines(output)}


def verify(godot: str, pack: pathlib.Path, logs: pathlib.Path, kept: int, expected: dict[str, str] | None = None) -> dict:
	"""Boot the pack with the editor binary and read back what verify_demo_pack.gd found. `kept` is how
	many pictures the demo reads itself (tools/demo_texture_imports.py); all of them must be packed."""
	report = logs / "verify.json"
	if report.exists():
		report.unlink()
	status, output = run([godot, "--main-pack", str(pack), "--resolution", "1920x1080", "--script",
		str(VERIFY_SCRIPT), "--", str(report), str(logs / "screenshots")], logs / "verify.log", VERIFY_TIMEOUT)
	if not report.is_file():
		raise RuntimeError(f"pack verification did not run (status {status}); see {logs / 'verify.log'}")
	found = json.loads(report.read_text())
	problems = verification_problems(found, output, kept, expected)
	if status != 0:
		problems.append(f"the check exited {status}")
	if problems:
		raise RuntimeError("pack verification failed: " + "; ".join(problems))
	found["log_errors"] = error_lines(output)
	return found


def stall_problems(found: dict) -> list[str]:
	"""What is wrong with the stall Resume check: a forced stall must pause (CRITICAL) and show the banner,
	and Enter must resume it, the ticks running again."""
	problems = []
	if "CRITICAL" not in str(found.get("stall_clock", "")) or not found.get("stall_banner_shown"):
		problems.append(f"a stall did not show the Resume banner: {found.get('stall_clock')!r}, "
			f"shown {found.get('stall_banner_shown')}")
	if "CRITICAL" in str(found.get("after_resume_clock", "CRITICAL")) or found.get("after_resume_banner_shown"):
		problems.append(f"Enter did not resume from the stall: {found.get('after_resume_clock')!r}")
	if found.get("ticks_after_resume", 0) <= 0:
		problems.append("the clock did not run after Resume")
	return problems


def build_info_problems(found: dict, expected: dict[str, str] | None) -> list[str]:
	"""What is wrong with the packed demo/build_info.json: missing, unreadable, or (when `expected` is given) not this
	build's commit or export mode."""
	if not found.get("build_info"):
		return ["the pack carries no demo/build_info.json: the playtest log would not know its version"]
	try:
		info = json.loads(found["build_info"])
	except (TypeError, ValueError):
		return [f"the packed demo/build_info.json is not JSON: {found['build_info']!r}"]
	if expected is None:
		return []
	return [f"the packed build info says {key} {info.get(key)!r}, not {value!r}" for key, value in expected.items()
		if info.get(key) != value]


def verification_problems(found: dict, output: str, kept: int = 1, expected: dict[str, str] | None = None) -> list[str]:
	"""What is wrong with a verification report, or nothing."""
	problems = []
	if found.get("error"):
		problems.append(found["error"])
	if found.get("main_scene") != DEMO_SCENE:
		problems.append(f"main scene resolves to {found.get('main_scene')!r}, not the demo")
	if not found.get("feature_demo_build"):
		problems.append("the pack does not carry the demo_build feature")
	pack = found.get("pack", {})
	if not pack.get("manifest") or not pack.get("s3tc_ctex") or pack.get("raw_png", 0) < max(kept, 1):
		problems.append(f"staged assets missing from the pack ({kept} pictures kept as files): {pack}")
	if error_lines(output):
		problems.append("the check printed engine errors: " + "; ".join(error_lines(output)[:5]))
	if "demo assets are not staged" in output:
		problems.append("the demo booted on placeholders")
	if "CRITICAL" in str(found.get("clock_at_end", "")):
		problems.append("the game clock paused itself on an overload (CRITICAL) during the check")
	problems += stall_problems(found)
	if "did not load" in output:
		problems.append("a card atlas or icon did not load from the pack")
	problems += build_info_problems(found, expected)
	if not found.get("playtest_log"):
		problems.append("the playtest log did not start in the pack (decision 0562)")
	return problems


# --- README and zip ---------------------------------------------------------------------------

def git_commit() -> str:
	"""The commit this build was made from, marked dirty if the tree has changes."""
	head = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
		capture_output=True, text=True, check=False).stdout.strip()
	dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no"],
		capture_output=True, text=True, check=False).stdout.strip()
	return head + ("-dirty" if dirty else "")


def write_build_info(facts: dict[str, str], path: pathlib.Path = BUILD_INFO) -> pathlib.Path:
	"""godot/demo/build_info.json: the commit, build time, Godot version and export mode the playtest log's header
	quotes."""
	info = {"schema": "redwall-demo-build-info-v1", "commit": facts["commit"], "built": facts["built"],
		"godot": facts["godot"], "export": facts["export"]}
	path.write_text(json.dumps(info, indent=1) + "\n")
	return path


def write_readme(folder: pathlib.Path, facts: dict[str, str]) -> None:
	"""README.txt for the person running the build, with this build's facts filled in (Windows line ends)."""
	text = README_SOURCE.read_text()
	for key, value in facts.items():
		text = text.replace("{" + key + "}", value)
	(folder / "README.txt").write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def zip_folder(folder: pathlib.Path, archive: pathlib.Path) -> None:
	"""Zip `folder` (as its own top-level folder) into `archive`."""
	if archive.exists():
		archive.unlink()
	with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as bundle:
		for path in sorted(folder.rglob("*")):
			if path.is_file():
				bundle.write(path, path.relative_to(folder.parent).as_posix())


def mib(path: pathlib.Path) -> float:
	"""A file's size in MiB, one decimal."""
	return round(path.stat().st_size / 1048576.0, 1)


# --- main -------------------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
	"""The command line."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--out", type=pathlib.Path, required=True, help="folder for the build, its zip and logs")
	parser.add_argument("--godot", default="godot", help="the Godot EDITOR binary (exports and verifies)")
	parser.add_argument("--pack-only", action="store_true", help="export and verify just the .pck (no templates)")
	parser.add_argument("--allow-unstaged", action="store_true", help="build even if the assets are not staged")
	parser.add_argument("--skip-verify", action="store_true", help="do not boot the pack")
	parser.add_argument("--release", action="store_true",
		help="export on the release template (a final build); the default is a debug playtest build (decision 0562)")
	return parser.parse_args()


def preflight(args: argparse.Namespace) -> str:
	"""Refuse early -- no staged assets, no Windows template -- and return the Godot version."""
	if not (demo_texture_imports.ASSETS / demo_texture_imports.MANIFEST).is_file() and not args.allow_unstaged:
		raise SystemExit("the demo's assets are not staged: run python3 tools/stage_demo_assets.py first")
	version = godot_version(args.godot)
	template = templates_dir(version) / TEMPLATES[export_mode(args.release)]
	if not args.pack_only and not template.is_file():
		raise SystemExit(f"no Windows export template at {template}.\nInstall Godot {version}'s export templates "
			"(Godot editor: Editor > Manage Export Templates > Download and Install, or install the "
			f"Godot_v{version.replace('.stable', '-stable')}_export_templates.tpz from godotengine.org), "
			"or pass --pack-only to build and check the .pck alone.")
	return version


def fresh_folders(out: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
	"""(the build folder, emptied; the logs folder)."""
	folder = out / FOLDER
	logs = out / "logs"
	if folder.exists():
		shutil.rmtree(folder)
	folder.mkdir(parents=True)
	logs.mkdir(parents=True, exist_ok=True)
	return folder, logs


def main() -> int:
	"""Compress, import, export, verify and zip the Windows demo."""
	args = parse_args()
	version = preflight(args)
	out = args.out.resolve()
	folder, logs = fresh_folders(out)
	started = dt.datetime.now(dt.timezone.utc)
	textures = demo_texture_imports.settle(args.godot)
	preset = install_preset()
	pack = folder / EXE.replace(".exe", ".pck")
	mode = export_mode(args.release)
	facts = {"built": started.strftime("%Y-%m-%d %H:%M UTC"), "commit": git_commit(), "godot": version,
		"export": mode}
	write_build_info(facts)
	try:
		exported = export(args.godot, pack if args.pack_only else folder / EXE, logs, args.pack_only, mode)
	finally:
		BUILD_INFO.unlink(missing_ok=True)
	expected = {"commit": facts["commit"], "export": mode}
	verified = {} if args.skip_verify else verify(args.godot, pack, logs, textures[demo_texture_imports.ROLE_RAW],
		expected)
	facts["pck_mib"] = str(mib(pack))
	write_readme(folder, facts)
	archive = out / f"{FOLDER}.zip"
	if not args.pack_only:
		zip_folder(folder, archive)
	record = {
		"schema": "redwall-demo-windows-build-v1", "decision": "0196", **facts,
		"preset": PRESET_NAME, "export_presets": str(preset), "pack_only": args.pack_only,
		"textures": {key: (len(value) if isinstance(value, list) else value) for key, value in textures.items()},
		"export": exported, "verify": verified,
		"files": {path.name: mib(path) for path in sorted(folder.iterdir()) if path.is_file()},
		"zip_mib": mib(archive) if archive.is_file() else None,
		"finished": dt.datetime.now(dt.timezone.utc).isoformat(),
	}
	(out / "build.json").write_text(json.dumps(record, indent=1) + "\n")
	print(f"build_demo_windows: {folder}" + (f" -> {archive} ({record['zip_mib']} MiB)" if record["zip_mib"] else ""))
	return 0


if __name__ == "__main__":
	sys.exit(main())
