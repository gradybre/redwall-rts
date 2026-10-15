extends "res://test/live/demo_build_furnish_live.gd"
## ROUNDED, HAND-DUG WALLS, live (decision 1914): the Furnish tab's whole loop (decision 1921) with a bent Passage
## added south of the Kitchen, through the real input gate on the real village. Besides the furnish loop's checks it
## frames what the rounding changes -- a room mid-dig, the dug Kitchen, Passage and Dormitory with their furniture, a
## passage mouth close up and the bent tunnel -- and checks Brendan's two rules on the drawn earth: every dug cell's
## floor is whole (rule a: never hide a usable cell), and nothing ordered is rounded (rule b: plan in squares).
## Optional: -- --capture <directory> for its frames.

## The bent Passage: east out of the Kitchen, then north (2 cells wide, as a passage is painted; south of z 40 the
## panel covers the floor, north of z 32 lies the stream).
const BEND_EAST_FROM: Vector2i = Vector2i(24, 36)
const BEND_EAST_TO: Vector2i = Vector2i(28, 37)
const BEND_NORTH_FROM: Vector2i = Vector2i(27, 32)
const BEND_NORTH_TO: Vector2i = Vector2i(28, 35)
## The furnish loop's 70 cells and the bend's 18.
const ROUNDED_CELLS: int = 88
## Cells dug before the mid-dig frame.
const MID_DIG_CELLS: int = 40
## Level 1's floor lies about this far below the ground the camera centres on (m); and how far nearer the camera it
## centres, so the point framed sits above the panel.
const LEVEL_DROP_M: float = 4.6
const ABOVE_PANEL_M: float = 2.5
## The close-ups: the Passage's mouth into the Kitchen, and the bend.
const MOUTH_AT: Vector2 = Vector2(18.0, 37.0)
const BEND_AT: Vector2 = Vector2(27.0, 35.5)
const CLOSE_UP_PITCH_DEG: float = 48.0
const CLOSE_UP_M: float = 9.0


func _initialize() -> void:
	"""The furnish loop's steps, with the bend painted before Confirm all and the frames along the way."""
	super()
	var at: int = _steps.find(_confirm_the_rooms)
	var bend: Array[Callable] = [_scroll_to.bind("Passage"), _choose_the_passage,
		_paint_the_bend.bind(BEND_EAST_FROM, BEND_EAST_TO), _paint_the_bend.bind(BEND_NORTH_FROM, BEND_NORTH_TO)]
	for k: int in bend.size():
		_steps.insert(at + k, bend[k])
	_steps[_steps.find(_confirm_the_rooms)] = _confirm_the_rounded_rooms
	_steps.insert(_steps.find(_wait_for_the_digging), _wait_for_mid_dig)
	_steps.insert(_steps.find(_wait_for_the_digging), _check_square_plan)
	_steps.insert(_steps.find(_close_the_panel), _frame_close_ups)


func _paint_the_bend(from: Vector2i, to: Vector2i) -> void:
	"""One leg of the bent Passage, dragged: ✓, joined to the Kitchen or to the first leg."""
	_check("the bend's corners are on open ground", not _over_ui(_screen_of(from, 1)) and not _over_ui(_screen_of(to, 1)))
	_drag(_screen_of(from, 1), _screen_of(to, 1))
	var batch: Object = _build().get("batch")
	_check("the bend's leg is painted, ✓", int(batch.call(&"first_invalid")) < 0, str(batch.call(&"last_dropped")))


func _confirm_the_rounded_rooms() -> void:
	"""Confirm all: every cell, the bend's too, ordered; at 4x."""
	_click(_centre(_build().get("panel").call(&"controls")[&"confirm"]))
	_check("every cell ordered, the bend's too", int(_build().get("works").call(&"waiting")) == ROUNDED_CELLS,
		str(_build().get("works").call(&"waiting")))
	_manager().call(&"set_speed", 4)


func _wait_for_mid_dig() -> void:
	"""Until MID_DIG_CELLS are dug: the camera on the cell being dug, its frame."""
	_wait_until("the mole is half way", func() -> bool:
		var digger: Object = _build().get("digger")
		var ready: bool = digger != null and int(digger.get("dug")) >= MID_DIG_CELLS \
			and bool(_build().call(&"digging")) and (digger.call(&"digging_cell") as Vector3i).x == 1
		if ready:
			var cell: Vector3i = digger.call(&"digging_cell")
			_aim_below(Vector2(cell.y + 0.5, cell.z + 0.5), 0.0, CLOSE_UP_PITCH_DEG, CLOSE_UP_M)
		return ready, "rounded_mid_dig", DIG_STEPS)


func _frame_close_ups() -> void:
	"""The dug rooms with their furniture from above, the Passage's mouth into the Kitchen, and the bend."""
	_aim_below(Vector2(18.0, 38.0), 0.0, CLOSE_PITCH_DEG, CLOSE_M)
	_steps.push_front(_capture_after.bind("rounded_rooms_furnished", 2))
	_steps.insert(1, _aim_and_capture.bind(MOUTH_AT, 20.0, "rounded_passage_mouth"))
	_steps.insert(2, _aim_and_capture.bind(BEND_AT, 0.0, "rounded_bent_tunnel"))


func _aim_and_capture(at: Vector2, yaw_deg: float, capture_name: String) -> void:
	"""A close-up of the level-1 point `at`, then its frame."""
	_aim_below(at, yaw_deg, CLOSE_UP_PITCH_DEG, CLOSE_UP_M)
	_steps.push_front(_capture_after.bind(capture_name, 2))


func _aim_below(at: Vector2, yaw_deg: float, pitch_deg: float, metres: float) -> void:
	"""Aim the camera so the level-1 point `at` (m) is framed above the panel: the ground point the ray through it
	meets, LEVEL_DROP_M down, then ABOVE_PANEL_M nearer the camera."""
	var yaw: float = deg_to_rad(yaw_deg)
	var nearer_m: float = LEVEL_DROP_M / tan(deg_to_rad(pitch_deg)) + ABOVE_PANEL_M
	var toward_camera: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * nearer_m
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", Vector3(at.x, 0.0, at.y) + toward_camera, yaw_deg, pitch_deg, metres)
	camera.call(&"snap")
