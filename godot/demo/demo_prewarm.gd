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
## compiles are paid while paused.
##
## FRAME STEPS (`add_frame_step`, decision 0206): a warm-up that needs frames DRAWN a certain way -- the
## underground view, drawn for a couple of frames with a sample of everything it can show
## (demo/tunnel/tunnel_view.gd `begin_prewarm`) -- runs after the warm frames, one after another: its
## `begin` is called (in a process, so that frame is its first), its frames are drawn, its `finish` is
## called, and only then is the pause released. Each is timed in `report` like a step (`loaded`: the
## frames it drew).

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
## Frame steps: name, frames, begin and finish (see FRAME STEPS); the one running (-1: none) and when.
var _frame_names: PackedStringArray = PackedStringArray()
var _frame_counts: PackedInt32Array = PackedInt32Array()
var _frame_begins: Array[Callable] = []
var _frame_finishes: Array[Callable] = []
var _frame_step: int = -1
var _frame_started: int = 0


func _init() -> void:
	"""Named, processing even while the game is paused (it waits out the opening pause)."""
	name = "DemoPrewarm"
	process_mode = Node.PROCESS_MODE_ALWAYS


func add_step(step_name: String, step: Callable) -> void:
	"""Register a warm-up step: `step() -> int`, returning how many things it loaded."""
	_names.append(step_name)
	_steps.append(step)


func add_frame_step(step_name: String, frames: int, begin: Callable, finish: Callable) -> void:
	"""Register a warm-up drawn over `frames` frames after the warm frames (see FRAME STEPS)."""
	_frame_names.append(step_name)
	_frame_counts.append(maxi(frames, 1))
	_frame_begins.append(begin)
	_frame_finishes.append(finish)


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
	"""Call `release` once `frames` frames -- and every frame step's -- have been drawn (at once for 0
	with no frame steps)."""
	_release = release
	frames_left = maxi(frames, 0)
	set_process(true)
	if frames_left == 0 and _frame_names.is_empty():
		_fire()


func _process(_delta: float) -> void:
	"""Count the drawn frames down to the release. `_process` runs before its frame is drawn, so the
	release comes in the process after the last warm frame was drawn -- and after the frame steps'."""
	if frames_left < 0:
		return
	if frames_left > 0:
		frames_left -= 1
		return
	if _next_frame_step():
		return
	_fire()


func _next_frame_step() -> bool:
	"""With the frames counted out: finish the frame step running (timed), then begin the next, its
	frames to count. False when none is left to begin."""
	if _frame_step >= 0:
		_frame_finishes[_frame_step].call()
		report.append({"step": _frame_names[_frame_step], "loaded": _frame_counts[_frame_step],
			"usec": Time.get_ticks_usec() - _frame_started})
	_frame_step += 1
	if _frame_step >= _frame_names.size():
		return false
	_frame_started = Time.get_ticks_usec()
	_frame_begins[_frame_step].call()
	frames_left = _frame_counts[_frame_step] - 1
	return true


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
