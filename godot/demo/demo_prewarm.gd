extends Node
## The demo's boot prewarm: what would first load mid-game loads while the village opens, and the
## clock starts only once the first frames are drawn. Decision 0205 (the playtest of 2026-09-29: the
## CLOCK_OVERLOADED stall recurred outside the U view -- "first at tick 16, last at tick 4616").
##
## WHY. The clock holds its REQ-SET-008 diagnostic pause when one frame puts it a quarter second behind
## at 1x. Two kinds of frame did that on the playtest's Windows machine outside the underground view:
##   * THE FIRST FRAMES. Godot compiles the pipelines of everything the village draws in the first
##     frames, and the demo released UI-SET-103's opening pause in `_ready`, before any frame was
##     drawn -- so that compile time was owed to a running clock (the stall at tick 16).
##   * FIRST USES. A prop or model is loaded -- its scene instantiated, its surfaces made and their
##     pipelines compiled (Godot compiles a surface's pipelines when it is created) -- the first time
##     it is shown: an item carried, an axe, a plank, a basket, a felled trunk, a shelf's goods, a
##     pantry icon; a plant's card atlases are decoded and mipmapped the first time a bed shows it.
##     Each is a hitch that lands mid-game, when the clock is running.
##
## WHAT. `warm()` loads all of those now, in `_ready`, while the clock still holds the opening pause:
## every staged prop and icon (demo_props.gd `warm_all`), every plant's atlases (farm_assets.gd
## `ensure_all_loaded`), and whatever else a caller registers (`add_step`: the woods' stumps, saplings
## and split trees). It times each step (`report`). `release_after_frames()` then lets WARM_FRAMES frames
## be drawn before the demo's own `_open_running` releases the opening pause, so the first frames'
## compiles are paid while paused. The underground view keeps its own first-toggle cost: the
## underground revamp owns it (docs: its design's P0 prewarm registry).

## Frames drawn before the clock is started (demo value: the village's first frame compiles its
## pipelines; two more cover the ones that settle in after the first shadow and light pass).
const WARM_FRAMES: int = 3

## What each step loaded and how long it took: [{"step", "loaded", "usec"}].
var report: Array[Dictionary] = []
## Frames still to draw before the release (-1: not waiting).
var frames_left: int = -1

var _steps: Array[Callable] = []
var _names: PackedStringArray = PackedStringArray()
var _release: Callable = Callable()


func _init() -> void:
	"""Named, processing even while the game is paused (it waits out the opening pause)."""
	name = "DemoPrewarm"
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_step(step_name: String, step: Callable) -> void:
	"""Register a warm-up step: `step() -> int`, returning how many things it loaded."""
	_names.append(step_name)
	_steps.append(step)


func warm() -> int:
	"""Run every registered step now, timing each (see `report`). Returns the total loaded."""
	var total: int = 0
	for k: int in _steps.size():
		var started: int = Time.get_ticks_usec()
		var loaded: int = int(_steps[k].call())
		report.append({"step": _names[k], "loaded": loaded, "usec": Time.get_ticks_usec() - started})
		total += loaded
	return total


func release_after_frames(release: Callable, frames: int = WARM_FRAMES) -> void:
	"""Call `release` once `frames` frames have been drawn (at once for 0)."""
	_release = release
	frames_left = maxi(frames, 0)
	set_process(true)
	if frames_left == 0:
		_fire()


func _process(_delta: float) -> void:
	"""Count the drawn frames down to the release. `_process` runs before its frame is drawn, so the
	release comes in the process after the last warm frame was drawn."""
	if frames_left < 0:
		return
	if frames_left == 0:
		_fire()
		return
	frames_left -= 1


func _fire() -> void:
	"""Release, once."""
	frames_left = -1
	set_process(false)
	var release: Callable = _release
	_release = Callable()
	if release.is_valid():
		release.call()


func total_usec() -> int:
	"""How long the warm-up took, microseconds."""
	var total: int = 0
	for row: Dictionary in report:
		total += int(row["usec"])
	return total
