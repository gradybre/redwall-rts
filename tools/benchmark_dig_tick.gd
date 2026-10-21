extends "res://test/run_tests.gd"
## Decision 1951: the dig-tick benchmark. Runs the benchmark suites under godot/test/bench/ (outside the suite's
## discovery, so CI never pays for them) through the test runner's supervisor, so a script error still fails.
##
##     REDWALL_DIG_REPORT=<file> [REDWALL_DIG_TRACE=<file>] [REDWALL_DIG_BENCH=room|entry] \
##         godot --headless --path godot --script "$PWD/tools/benchmark_dig_tick.gd"
##
## Each suite prints `DIG-BENCH <label> <series> n= p50= p95= p99= max= sum=` lines (microseconds) and appends
## them to REDWALL_DIG_REPORT. REDWALL_DIG_TRACE adds a per-tick SHA-256 of every owner the run drives; traced
## runs are slower, so take timings from untraced runs and compare traces between revisions with `diff`.

const BENCH_SUITES: Dictionary = {
	"room": "res://test/bench/bench_dig_room_loop.gd",
	"entry": "res://test/bench/bench_dig_entry.gd",
}


func _discover_suites() -> PackedStringArray:
	"""The benchmark suites, or the one REDWALL_DIG_BENCH names."""
	var only: String = OS.get_environment("REDWALL_DIG_BENCH")
	var paths: PackedStringArray = PackedStringArray()
	for key: String in BENCH_SUITES:
		if only == "" or only == key: paths.append(BENCH_SUITES[key])
	return paths
