class_name RedwallBenchmarkMainLoop
extends "res://bench/benchmark_work.gd"
## Packable entry point for the work benchmark, plus the probe that proves whether the binary
## running it compiled `assert()` in or out.
##
## ---------------------------------------------------------------------------------------
## WHY THIS FILE EXISTS.
##
## The editor invocation `godot --headless --path godot --script tools/benchmark_work.gd` HAS
## NO RELEASE EQUIVALENT. Godot 4.7.2's official export templates are compiled with
## `disable_path_overrides=true`: `--path`, `--main-pack` and `-s/--script` are all marked `X`
## ("only available in editor builds") in the editor's own `--help`, they do not appear in the
## release template's `--help` at all, and the release template aborts with
##   `--path` was specified on the command line, but this Godot binary was compiled without
##   support for path overrides. Aborting.
## An exported build can therefore only start from its own main loop. `application/run/
## main_loop_type` names the class below, so the exported benchmark build boots straight into
## the fixture.
##
## ---------------------------------------------------------------------------------------
## `tools/benchmark_work.gd` IS NOT MODIFIED BY ANY OF THIS. The export helper copies it byte
## for byte to `res://bench/benchmark_work.gd` and records its SHA-256, which is why the
## editor and release runs can be said to have timed the same fixture source. This file adds
## only a dispatch in front of `_initialize()`; the timed region is untouched.

## The user argument that selects the assert probe instead of a benchmark run.
const ASSERT_PROBE_ARGUMENT: String = "--assert-probe"
## How many times the probe asks `assert()` to evaluate a counting condition. A debug build
## evaluates all of them; a release build evaluates none, because the statement is not compiled.
const ASSERT_PROBE_EVALUATIONS: int = 3

var _assert_argument_evaluations: int = 0


func _initialize() -> void:
	"""Run the assert probe when it is asked for, otherwise run the unmodified fixture."""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has(ASSERT_PROBE_ARGUMENT):
		quit(_run_assert_probe(user_args))
		return
	super()


func _count_assert_argument_evaluation() -> bool:
	"""Record one evaluation of an `assert()` condition, and report success so it cannot fail."""
	_assert_argument_evaluations += 1
	return true


func _assert_probe_output_path(user_args: PackedStringArray) -> String:
	"""The `--output` path in these user arguments, or an empty string when there is none."""
	var index: int = user_args.find("--output")
	if index < 0 or index + 1 >= user_args.size():
		return ""
	return user_args[index + 1]


func _run_assert_probe(user_args: PackedStringArray) -> int:
	"""Establish behaviourally whether this binary compiled `assert()` in or out.

	Two independent signals, neither of which is a build flag reporting on itself:

	  * `argument_evaluations` -- a debug build EVALUATES an assert's condition, so the counter
	    reaches ASSERT_PROBE_EVALUATIONS. A release build omits the whole statement, including
	    the call inside it, so the counter stays at 0.
	  * `reached_after_failing_assert` -- a debug build halts at `assert(false, ...)` and never
	    reaches the statement after it. A release build walks straight past.

	The record is written BEFORE the failing assert on purpose: that is the only way the debug
	side leaves evidence, because its execution stops there and never returns from this
	function. A caller must pass `--quit-after` so the debug side still terminates.
	"""
	var output_path: String = _assert_probe_output_path(user_args)
	if output_path == "":
		printerr("ASSERT_PROBE_FAILURE missing --output")
		return 1
	for repeat: int in ASSERT_PROBE_EVALUATIONS:
		assert(_count_assert_argument_evaluation(), "the probe condition is always true")
	if not _write_assert_probe(output_path, "before_failing_assert", false):
		return 1
	assert(false, "a debug build halts here; a release build never sees this statement")
	if not _write_assert_probe(output_path, "after_failing_assert", true):
		return 1
	return 0


func _write_assert_probe(path: String, stage: String, reached: bool) -> bool:
	"""Write the probe record for one stage, overwriting the earlier stage if there was one."""
	var record: Dictionary = _assert_probe_record(stage, reached)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("ASSERT_PROBE_FAILURE cannot open %s" % path)
		return false
	file.store_string(JSON.stringify(record) + "\n")
	file.close()
	print("ASSERT_PROBE %s" % JSON.stringify(record))
	return true


func _assert_probe_record(stage: String, reached: bool) -> Dictionary:
	"""The two behavioural signals, plus what this binary says about itself for cross-checking.

	`asserts_compiled_out` is derived from the two BEHAVIOURAL fields only. The `feature_*`
	fields are the binary's own self-report and are recorded to be compared against the
	behaviour, never to stand in for it.
	"""
	return {
		"schema": "redwall-assert-probe-v1",
		"stage": stage,
		"argument_evaluations": _assert_argument_evaluations,
		"expected_debug_evaluations": ASSERT_PROBE_EVALUATIONS,
		"reached_after_failing_assert": reached,
		"asserts_compiled_out": _assert_argument_evaluations == 0 and reached,
		"os_is_debug_build": OS.is_debug_build(),
		"feature_debug": OS.has_feature("debug"),
		"feature_release": OS.has_feature("release"),
		"feature_editor": OS.has_feature("editor"),
		"feature_template": OS.has_feature("template"),
		"feature_template_debug": OS.has_feature("template_debug"),
		"feature_template_release": OS.has_feature("template_release"),
		"feature_arm64": OS.has_feature("arm64"),
		"feature_x86_64": OS.has_feature("x86_64"),
		"processor_name": OS.get_processor_name(),
		"engine_version": Engine.get_version_info(),
	}
