extends "res://test/run_tests.gd"
## Runner focus: restrict suite discovery to the retired-state probe only.
##
## No inherited old tests. `_discover_suites()` is the only override: it returns exactly one
## path, `res://test/construction_retired_probe.gd`, which the dispatching harness places there
## as an owned clone of this evidence packet's `retired-state-probe.gd`. Everything else --
## the worker/supervisor split, the marker protocol, the abort detection described in
## `run_tests.gd`'s own header -- is inherited unchanged from the base runner.

const FOCUS_SUITE_PATH: String = "res://test/construction_retired_probe.gd"


func _discover_suites() -> PackedStringArray:
	"""Return only the one suite this focus exists to run."""
	var paths: PackedStringArray = PackedStringArray()
	paths.append(FOCUS_SUITE_PATH)
	return paths
