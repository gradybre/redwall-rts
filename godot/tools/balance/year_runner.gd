extends SceneTree
## THE BALANCE HARNESS's command line (decision 0911). Everything is in balance_run.gd -- read its header for the
## arguments, the settings and the output:
##
##     godot --headless --path godot --fixed-fps 30 --script res://tools/balance/year_runner.gd -- \
##         --seed 1 --policy hands_off --days 48 --out /abs/run.json [--csv /abs/run.csv] [--hours N] [--fps 30]
##
## This script only hands the frames on: a main loop's script is compiled before the autoloads are registered, and the
## demo's scripts name them, so the run is loaded here at start-up rather than preloaded.

var _run: RefCounted = null


func _initialize() -> void:
	"""Load the run and let it boot the village."""
	_run = (load("res://tools/balance/balance_run.gd") as GDScript).new()
	_run.call(&"begin", self)


func _process(delta: float) -> bool:
	"""Hand the frame to the run."""
	return bool(_run.call(&"frame", delta))
