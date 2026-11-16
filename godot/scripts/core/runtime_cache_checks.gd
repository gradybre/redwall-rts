extends RefCounted
## Decision 1952: the switch that makes the runtime caches check themselves. It has no dependencies on purpose: the
## test framework loads it from its static initializer, and probes that deliberately break the game's scripts
## (tools/test_buildings_metadata_preflights.py, tools/test_run_tests_diagnostics.py) must still parse the framework.

## While true (the test framework sets it; the game and the dig benchmark leave it false), every cache keyed on an
## owner's token also computes its answer live, answers live, and reports a remembered answer that differs. A bank
## edited in place without moving its token is then caught by the suite that edits it instead of being read stale.
## Never saved.
static var enabled: bool = false


static func report(cache: String, detail: String) -> void:
	"""A remembered answer differed from the live one while checking is on."""
	push_error("RUNTIME_CACHE_STALE %s: %s (decision 1952)" % [cache, detail])
