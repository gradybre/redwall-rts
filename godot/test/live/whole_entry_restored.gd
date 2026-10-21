extends SceneTree
## Decision 2044 (CI time): test_underground_host_whole_chain.gd's restored whole entry (`_whole_entry(true)`: the
## runtime replaced by its record every ENTRY_RESTORE_EVERY ticks, the route owners cold-restored every
## ROUTE_RESTORE_EVERY), flown by that suite's own fixture in its own process, beside the suite's uninterrupted flight,
## so the two run at once. Not discovered by the runner (it is not `test_*.gd` in test/). The suite starts it with its
## own output inherited (the runner audits every line it prints), waits for it and compares; it writes
## {result, assertions, failures, checks, restores, at_m} with var_to_bytes to the file after `--out`.
##
##     godot --headless --path godot --script res://test/live/whole_entry_restored.gd -- --out <file>

const CacheChecks := preload("res://scripts/core/runtime_cache_checks.gd")
## Loaded at runtime, not preloaded: the suite names the GameManager autoload, which a main-loop script cannot preload.
const SUITE: String = "res://test/test_underground_host_whole_chain.gd"


func _initialize() -> void:
	"""Fly the restored whole entry and write its record; exit 1 when the record could not be written."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at < 0 or at + 1 >= args.size():
		printerr("whole_entry_restored: --out <file> is required")
		quit(2)
		return
	quit(3) # Stands if `_fly` is abandoned by a script error: the suite then sees a non-zero exit.
	quit(_fly(args[at + 1]))


func _fly(out: String) -> int:
	"""The suite's `_whole_entry(true)` between its own before_each() and after_each(), recorded to `out`."""
	var suite: RefCounted = (load(SUITE) as GDScript).new()
	suite.before_each()
	var result: Array = suite._whole_entry(true)
	suite.after_each()
	var record: Dictionary = {"result": result, "assertions": suite.assertions, "failures": suite.failures,
		"checks": CacheChecks.enabled, "restores": suite._entry_restores, "at_m": suite._ticks_at_m}
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("whole_entry_restored: cannot write %s" % out)
		return 1
	file.store_buffer(var_to_bytes(record))
	file.close()
	return 0
