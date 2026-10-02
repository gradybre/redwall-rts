extends "res://tools/scale_test/scale_test.gd"
## FAULT INJECTION for test_scale_stress.gd (decision 0998): the real scale harness -- the real village, its real end
## (scale_test.gd "THE END FREES THE VILLAGE FIRST") -- with ONE extra resource retained at exit. The resource holds
## itself in its metadata, a cycle nothing breaks, under a path so the engine's resource cache counts it. The engine's
## exit report must then read exactly "1 resources still in use at exit", and the suite's exit-report check must fail
## it. The plan is cut to TINY_PLAN so the run costs little more than the village's boot.

## The retained resource's path (it is never written; the cache only needs a name).
const LEAK_PATH: String = "res://test/fixtures/scale_exit_leak_injected.tres"
## One phase of a few ticks at 1x: the village opens, steps, reports and closes as in a real run.
const TINY_PLAN: Array = [["1x_breakfast", 1, 10]]


func _initialize() -> void:
	"""Retain the one injected resource, then boot as the harness does."""
	var leak := Resource.new()
	leak.take_over_path(LEAK_PATH)
	leak.set_meta(&"retains_itself", leak)
	super._initialize()


func _read_args() -> void:
	"""The harness's arguments, then the tiny plan."""
	super._read_args()
	plan = TINY_PLAN
