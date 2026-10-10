#!/usr/bin/env python3
"""Self-test for tools/build_demo_windows.py (decision 0196, the Windows demo build). Runs without Godot,
templates or staged assets: presets and reports are literal strings.

NEGATIVE TESTS COME FIRST:

  N01  a preset source that is not exactly one preset named "Windows Desktop (demo)" is refused.
  N02  a developer's other presets in godot/export_presets.cfg are never dropped, and its leading
       comment is kept.
  N03  a verification that resolved the main scene to scenes/main.tscn, lacks the demo_build feature,
       packed no staged assets, booted on placeholders or ended in an overload pause is a failure.
  N04  a pack missing an underground binary, or whose demo did not mount its underground foundation, is a
       failure (decision 1841).

Then: merging replaces the demo preset in place of an older copy, renumbers from 0, and is idempotent;
the committed preset carries the build's contract (feature, filters, x86_64, separate pck, S3TC,
unsigned), and names no underground binary, which the editor plugin packs instead (decision 1841); the README
template's placeholders are all filled.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build_demo_windows as build  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []

MAC_PRESETS = """; macOS export presets for Redwall RTS.
; a developer's own comment

[preset.0]

name="macos-benchmark-release"
platform="macOS"
custom_features=""

[preset.0.options]

binary_format/architecture="universal"
"""

OURS = """; header of the source

[preset.0]

name="Windows Desktop (demo)"
platform="Windows Desktop"
custom_features="demo_build"

[preset.0.options]

binary_format/architecture="x86_64"
"""

GOOD_REPORT = {"error": "", "main_scene": "res://demo/demo_village.tscn", "feature_demo_build": True,
	"pack": {"manifest": True, "raw_png": 44, "s3tc_ctex": 337}, "stall_clock": 'PAUSED ["CRITICAL"]',
	"stall_banner_shown": True, "after_resume_clock": "PLAYING []", "after_resume_banner_shown": False,
	"ticks_after_resume": 30, "build_info": '{"commit": "abc1234", "export": "debug"}',
	"playtest_log": "playtest-2026-10-01_10-00-00-p1.log", "underground_mounted": True,
	"runtime_files": {"error": "", "count": 14, "bytes": 3848932, "refused": []}}


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _raises(call, kind=ValueError) -> bool:
	"""Whether `call()` raises `kind`."""
	try:
		call()
	except kind:
		return True
	return False


def test_n01_a_bad_preset_source_is_refused() -> None:
	check("N01 no preset", _raises(lambda: build.merge_preset(MAC_PRESETS, "; nothing\n")))
	check("N01 the wrong name", _raises(lambda: build.merge_preset(MAC_PRESETS, MAC_PRESETS)))
	check("N01 two presets", _raises(lambda: build.merge_preset("", build.merge_preset(MAC_PRESETS, OURS))))


def test_n02_other_presets_are_kept() -> None:
	merged = build.merge_preset(MAC_PRESETS, OURS)
	_, presets = build.split_presets(merged)
	check("N02 two presets", [preset["name"] for preset in presets] == ["macos-benchmark-release", "Windows Desktop (demo)"])
	check("N02 the mac preset's options survive", 'binary_format/architecture="universal"' in merged)
	check("N02 the leading comment survives", merged.startswith("; macOS export presets for Redwall RTS."))
	check("N02 the source's own header is not copied in", "header of the source" not in merged)


def test_n03_a_bad_verification_fails() -> None:
	check("N03 a good report passes", build.verification_problems(GOOD_REPORT, "") == [])
	for key, value in [("main_scene", "res://scenes/main.tscn"), ("feature_demo_build", False),
			("pack", {"manifest": False, "raw_png": 44, "s3tc_ctex": 337}),
			("pack", {"manifest": True, "raw_png": 0, "s3tc_ctex": 337}),
			("pack", {"manifest": True, "raw_png": 44, "s3tc_ctex": 0}), ("error", "boom")]:
		check(f"N03 {key}={value} fails", build.verification_problems({**GOOD_REPORT, key: value}, "") != [])
	check("N03 placeholders fail", build.verification_problems(GOOD_REPORT, "demo assets are not staged") != [])
	check("N03 an overload pause fails",
		build.verification_problems({**GOOD_REPORT, "clock_at_end": 'PAUSED ["CRITICAL"]'}, "") != [])
	check("N03 a missing atlas fails", build.verification_problems(GOOD_REPORT, "card atlas x did not load") != [])


def test_n03_every_kept_picture_must_be_packed_and_errors_fail() -> None:
	check("N03 fewer packed pictures than kept fails", build.verification_problems(GOOD_REPORT, "", kept=45) != [])
	check("N03 as many passes", build.verification_problems(GOOD_REPORT, "", kept=44) == [])
	check("N03 an engine error in the check fails",
		build.verification_problems(GOOD_REPORT, "ERROR: Failed loading resource: res://x.png") != [])


def test_n03_the_stall_resume_must_work() -> None:
	for key, value in [("stall_clock", "PLAYING []"), ("stall_banner_shown", False),
			("after_resume_clock", 'PAUSED ["CRITICAL"]'), ("after_resume_banner_shown", True), ("ticks_after_resume", 0)]:
		check(f"N03 stall check {key}={value} fails", build.verification_problems({**GOOD_REPORT, key: value}, "") != [])
	missing = {key: value for key, value in GOOD_REPORT.items() if not key.startswith(("stall", "after", "ticks"))}
	check("N03 a report without the stall check fails", build.verification_problems(missing, "") != [])


def test_n03_the_version_and_the_playtest_log_must_be_in_the_pack() -> None:
	for key in ["build_info", "playtest_log"]:
		check(f"N03 no {key} fails", build.verification_problems({**GOOD_REPORT, key: ""}, "") != [])
		missing = dict(GOOD_REPORT)
		del missing[key]
		check(f"N03 a report without {key} fails", build.verification_problems(missing, "") != [])


def test_n03_the_packed_build_info_must_be_this_build() -> None:
	expected = {"commit": "abc1234", "export": "debug"}
	check("N03 this build's commit and mode pass", build.verification_problems(GOOD_REPORT, "", expected=expected) == [])
	check("N03 another commit fails", build.verification_problems(GOOD_REPORT, "",
		expected={**expected, "commit": "def5678"}) != [])
	check("N03 a release pack for a debug build fails", build.verification_problems(GOOD_REPORT, "",
		expected={**expected, "export": "release"}) != [])
	check("N03 unreadable build info fails", build.verification_problems({**GOOD_REPORT, "build_info": "{"}, "",
		expected=expected) != [])


def test_n04_the_underground_must_be_in_the_pack_and_mount() -> None:
	refused = {"error": "source-bound profile artifact missing: res://x.ugactor", "count": 14, "bytes": 0,
		"refused": ["res://x.ugactor"]}
	check("N04 a refused runtime binary fails", build.verification_problems({**GOOD_REPORT, "runtime_files": refused}, "")
		!= [])
	check("N04 an unmounted foundation fails",
		build.verification_problems({**GOOD_REPORT, "underground_mounted": False}, "") != [])
	missing = {key: value for key, value in GOOD_REPORT.items() if key != "underground_mounted"}
	check("N04 a report without the mount check fails", build.verification_problems(missing, "") != [])
	check("N04 the demo's refusal warning fails", build.verification_problems(GOOD_REPORT,
		"WARNING: Underground foundation unavailable: MOLE_PRESENTATION_FILE\n   at: x") != [])


def test_playtest_builds_are_debug_and_release_is_asked_for() -> None:
	check("the default is a debug export", build.export_mode(False) == "debug")
	check("--release is a release export", build.export_mode(True) == "release")
	check("debug exports with --export-debug", build.EXPORT_FLAGS["debug"] == "--export-debug")
	check("release with --export-release", build.EXPORT_FLAGS["release"] == "--export-release")
	check("each needs its own template", build.TEMPLATES == {"debug": "windows_debug_x86_64.exe",
		"release": "windows_release_x86_64.exe"})
	saved = sys.argv
	try:
		sys.argv = ["build_demo_windows.py", "--out", "x"]
		check("no flag: a playtest build", build.parse_args().release is False)
		sys.argv = ["build_demo_windows.py", "--out", "x", "--release"]
		check("--release parses", build.parse_args().release is True)
	finally:
		sys.argv = saved


def test_the_build_info_names_the_commit() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		path = build.write_build_info({"commit": "abc1234-dirty", "built": "2026-10-01 18:00 UTC",
			"godot": "4.7.2.stable", "export": "debug"}, pathlib.Path(tmp) / "build_info.json")
		info = json.loads(path.read_text())
		check("the build info holds the commit", info["commit"] == "abc1234-dirty")
		check("and the export mode", info["export"] == "debug")
		check("and the build time and Godot", info["built"] == "2026-10-01 18:00 UTC" and info["godot"] == "4.7.2.stable")
	check("it is written where the export packs it", build.BUILD_INFO == build.PROJECT / "demo/build_info.json")
	ignored = (build.ROOT / ".gitignore").read_text()
	check("and it is gitignored", "godot/demo/build_info.json" in ignored)


def test_engine_lines_are_read() -> None:
	log = "Godot Engine v4.7.2\nWARNING: a\nERROR: b\n   at: c\nSCRIPT ERROR: d\nUSER ERROR: e\nWARNING: a\n"
	check("error lines", build.error_lines(log) == ["ERROR: b", "SCRIPT ERROR: d", "USER ERROR: e"])
	check("warnings once each", build.warning_lines(log) == ["WARNING: a"])
	check("ANSI colour stripped", build.strip_ansi("\x1b[91mERROR:\x1b[0m x") == "ERROR: x")


def test_the_templates_folder_name() -> None:
	check("4.7.2", build.templates_version("4.7.2.stable.official.ed1daf0bf\n") == "4.7.2.stable")
	check("an x.y.0 release", build.templates_version("4.8.stable.official.abc") == "4.8.stable")
	check("a release candidate", build.templates_version("4.8.rc2.official.abc") == "4.8.rc2")
	check("nonsense refused", _raises(lambda: build.templates_version("Godot")))


def test_the_zip_holds_the_folder() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		folder = pathlib.Path(tmp) / build.FOLDER
		folder.mkdir()
		(folder / "RedwallDemo.exe").write_bytes(b"MZ exe")
		(folder / "RedwallDemo.pck").write_bytes(b"GDPC pack")
		(folder / "README.txt").write_text("read me")
		archive = pathlib.Path(tmp) / "out.zip"
		build.zip_folder(folder, archive)
		import zipfile
		with zipfile.ZipFile(archive) as bundle:
			names = sorted(bundle.namelist())
			exe = bundle.read(f"{build.FOLDER}/RedwallDemo.exe")
		check("everything under one top-level folder", names == [f"{build.FOLDER}/README.txt",
			f"{build.FOLDER}/RedwallDemo.exe", f"{build.FOLDER}/RedwallDemo.pck"])
		check("byte for byte", exe == b"MZ exe")


def test_merging_replaces_renumbers_and_is_idempotent() -> None:
	once = build.merge_preset(MAC_PRESETS, OURS)
	twice = build.merge_preset(once, OURS)
	check("idempotent", once == twice)
	newer = OURS.replace('custom_features="demo_build"', 'custom_features="demo_build,newer"')
	replaced = build.merge_preset(once, newer)
	_, presets = build.split_presets(replaced)
	check("replaced, not duplicated", len(presets) == 2 and 'demo_build,newer' in replaced)
	check("numbered 0 and 1", re.findall(r"^\[preset\.(\d+)\]", replaced, re.M) == ["0", "1"])
	demo_first = build.merge_preset(OURS, OURS)
	check("into an empty or demo-only file", build.split_presets(demo_first)[1][0]["name"] == build.PRESET_NAME)


def test_install_preset_writes_the_projects_file() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = pathlib.Path(tmp)
		(project / "export_presets.cfg").write_text(MAC_PRESETS)
		target = build.install_preset(project, build.PRESET_SOURCE)
		_, presets = build.split_presets(target.read_text())
		check("installed beside the mac preset", [p["name"] for p in presets] == ["macos-benchmark-release", build.PRESET_NAME])


def test_the_committed_preset_is_the_build_contract() -> None:
	text = build.PRESET_SOURCE.read_text()
	_, presets = build.split_presets(text)
	check("one preset, named as the build calls it", len(presets) == 1 and presets[0]["name"] == build.PRESET_NAME)
	for line in ['platform="Windows Desktop"', 'custom_features="demo_build"', 'export_filter="all_resources"',
			'binary_format/architecture="x86_64"', "binary_format/embed_pck=false", "texture_format/s3tc_bptc=true",
			"codesign/enable=false", 'application/product_name="Redwall Demo"', "script_export_mode=0"]:
		check(f"the preset says {line}", line in text)
	include = re.search(r'^include_filter="(.*)"$', text, re.M).group(1)
	exclude = re.search(r'^exclude_filter="(.*)"$', text, re.M).group(1)
	check("the staged assets are included", "demo/assets/*" in include and "*.json" in include)
	check("the include filter is the JSON and the staged assets alone", include.split(", ") == ["*.json", "demo/assets/*"])
	check("no underground binary is named there: the exporter skips .gdignore folders (decision 1841)",
		"data/underground" not in include and ".ug" not in include)
	check("unrelated binary evidence is not broadly packed", "*.ugprof" not in include and "*.ugactor" not in include)
	check("tests, tools and the editor-only addons are excluded",
		"test/*" in exclude and "tools/*" in exclude and "addons/*" in exclude)


def test_the_editor_plugin_packs_the_underground_binaries() -> None:
	project = (build.PROJECT / "project.godot").read_text()
	plugin = build.PROJECT / "addons/demo_pack_files"
	check("the project enables the demo pack plugin",
		'enabled=PackedStringArray("res://addons/demo_pack_files/plugin.cfg")' in project)
	check("its plugin.cfg names its script", 'script="plugin.gd"' in (plugin / "plugin.cfg").read_text())
	source = (plugin / "export_plugin.gd").read_text()
	check("it acts on the preset's own feature", 'const FEATURE: String = "demo_build"' in source
		and 'custom_features="demo_build"' in build.PRESET_SOURCE.read_text())
	check("it packs the runtime list", 'const MANIFEST: String = "res://data/underground/runtime_files.gd"' in source
		and (build.PROJECT / "data/underground/runtime_files.gd").is_file())
	check("at each file's own path, checked against its pin", "add_file(path, bytes, false)" in source
		and "_sha256(bytes) != files[path]" in source)
	check("the pack check reads the same list", 'preload("res://data/underground/runtime_files.gd")'
		in build.VERIFY_SCRIPT.read_text())


def test_the_readme_template_is_filled() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		folder = pathlib.Path(tmp)
		build.write_readme(folder, {"built": "2026-09-29 18:00 UTC", "commit": "abc1234", "godot": "4.7.2.stable",
			"pck_mib": "631.3", "export": "debug"})
		text = (folder / "README.txt").read_bytes().decode("utf-8")
		check("no placeholder left", re.search(r"\{[a-z_]+\}", text) is None)
		check("Windows line ends", "\r\n" in text and "\n" not in text.replace("\r\n", ""))
		check("it tells the reader about SmartScreen", "More info" in text and "Run anyway" in text)
		check("it names the build's mode", "a debug build" in text)
		check("and where the playtest logs are", "Redwall Demo\\logs" in text)


def main() -> int:
	"""Run every test and print the summary line."""
	for name, test in sorted(globals().items()):
		if name.startswith("test_") and callable(test):
			try:
				test()
			except Exception as error:  # noqa: BLE001 -- a crash is a failure, not a lost run
				check("%s raised %s: %s" % (name, type(error).__name__, error), False)
	for failure in FAILURES:
		print("FAIL %s" % failure)
	print("test_build_demo_windows: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
