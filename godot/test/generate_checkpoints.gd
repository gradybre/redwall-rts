extends SceneTree
## Regenerates the committed test checkpoints (decision 1240). Run it through
## `./tools/regenerate_test_checkpoints.sh [name ...]`, which gives it a private `user://` and checks
## its report; with no names it regenerates every recipe in `checkpoint_recipes.gd`.
##
## Prints `CHECKPOINT-OK <name> <point>=<tick> ...` per written checkpoint, or
## `CHECKPOINT-FAIL <name>: <reason>`; exits 1 on any failure. Not a suite: the runner discovers
## only `test_*.gd`.

const RECIPES_PATH: String = "res://test/fixtures/checkpoint_recipes.gd"
const STORE_PATH: String = "res://test/fixtures/checkpoint_store.gd"


func _initialize() -> void:
	"""Build and write each requested checkpoint, then quit with 0 only when every one was written."""
	# Loaded at run time: the recipes name the GameManager autoload, which a --script parse cannot see.
	var recipes: GDScript = load(RECIPES_PATH)
	var store: GDScript = load(STORE_PATH)
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		names = recipes.NAMES
	var failed: int = 0
	for name: String in names:
		if not _generate(recipes, store, name):
			failed += 1
	quit(1 if failed > 0 else 0)


func _generate(recipes: GDScript, store: GDScript, name: String) -> bool:
	"""Replay one recipe and write it; print its report line. True when it was written."""
	var started: int = Time.get_ticks_msec()
	var built: RefCounted = recipes.build(name)
	var error: String = built.error
	if error == "":
		error = store.write(name, recipes.roots(), built.points)
	if error != "":
		print("CHECKPOINT-FAIL %s: %s" % [name, error])
		return false
	var parts: PackedStringArray = PackedStringArray()
	for point: String in built.points:
		parts.append("%s=%d" % [point, built.points[point][0]])
	print("CHECKPOINT-OK %s %s (%d ms)" % [name, " ".join(parts), Time.get_ticks_msec() - started])
	return true
