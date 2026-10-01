extends Node
## THE CAMERA'S MODES (decision 0801, feature #60): bookmarks, following a resident, a slow orbit round a building and
## the underground's cutaway angle, over the RTS rig (demo_camera.gd), which stays the player's. PRESENTATION ONLY:
## everything here is a float on the camera; nothing reaches the simulation (UI §6: "The camera remains a presentation
## service, never an entity-state writer"; REQ-SET-181).
##
## KEYS (all in `_unhandled_input`, so a key the HUD or an open panel took never reaches them, and none while a modal
## is open -- the gate lets End through to a focused control, never to the world). ESC FOR THE ORBIT keeps its place in
## UI §3's dismissal ladder (one layer per press): an open pop-up or panel, then the Dig tool's piece or the tool, take
## Esc first; the orbit's stop comes next (`escape_hook`, the command layer's input hook, which sees an event after the
## tools and before the selection), then clearing the selection, then the game menu.
##   End               FOLLOW the primary selected resident; End again stops (UI §5 `camera_follow`, adopted)
##   Ctrl+Shift+1..4   SAVE the view the camera is going to as bookmark 1..4 (camera_bookmarks.gd)    PROPOSAL
##   Shift+1..4        go back to bookmark 1..4                                                         PROPOSAL
##   Shift+O           ORBIT the building nearest the view's centre; Shift+O or Esc stops            PROPOSAL
##   Shift+U           the CUTAWAY ANGLE in the U view (turning it on); Shift+U again: your angle back  PROPOSAL
## UI §5 binds F1-F3 to the speeds, F4 to the roof mode, F5/F9 to quicksave/quickload, F6 to the world list, Ctrl+0..9
## and 0..9 to the control groups -- so a bookmark cannot take F1-F4 -- and macOS keeps Ctrl+F1..F4 for keyboard access.
##
## FOLLOW (UI §5: "Toggle following primary resident; manual camera movement cancels follow"). The view's centre eases
## after the resident every frame (`track`: the rig's own damp; with reduced motion it is held on them, no easing). A
## PAN the player makes -- the keys, the edge pan, the minimap, a "Go to", Home, a bookmark -- ends it, read from the
## rig's pan revision; turning, zooming and tilting do not, so the player can frame the one they follow.
##
## ORBIT. The building nearest the view's centre (within ORBIT_REACH_M; else the centre itself) is framed at
## ORBIT_PITCH_DEGREES from a distance fitted to its size, and the view turns round it at ORBIT_DEGREES_PER_SECOND of
## real time (paused too: UI §6, "all camera operations continue on real delta"). Zoom and tilt still work; Esc,
## Shift+O, a pan, a turn, a bookmark or a follow end it. With reduced motion the framing lands at once and the turn is
## steady (it is what was asked for; there is no ease to take out of it). The demo cannot select a building (the
## settlement's building selection is not built), so "the selected building" is the one the player has centred.
##
## CUTAWAY. In the U view the tunnels read best from steeply above: CUTAWAY_PITCH_DEGREES (UI §6's steepest, 65) over
## the middle of the network on the level shown, at a distance that fits it all (CUTAWAY_FIT; no closer than
## CUTAWAY_MIN_M), keeping the heading. Shift+U again, or leaving the U view, gives the pitch and distance you had back.
## The camera only: the U view's lights and environment are the tunnels' (tunnel_view.gd), untouched.

const DemoCamera := preload("res://demo/camera/demo_camera.gd")
const Bookmarks := preload("res://demo/camera/camera_bookmarks.gd")
const StripScript := preload("res://demo/camera/camera_strip.gd")
const EdgePanScript := preload("res://demo/camera/edge_pan.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Graph := preload("res://demo/tunnel/underground_graph.gd")

const MODE_FREE: int = 0
const MODE_FOLLOW: int = 1
const MODE_ORBIT: int = 2

const FOLLOW_ACTION: StringName = &"camera_follow"
const ORBIT_KEY: Key = KEY_O
const CUTAWAY_KEY: Key = KEY_U

const ORBIT_DEGREES_PER_SECOND: float = 6.0
const ORBIT_PITCH_DEGREES: float = 35.0
const ORBIT_REACH_M: float = 12.0
const ORBIT_FIT: float = 1.4
const ORBIT_MIN_M: float = 12.0
const ORBIT_MAX_M: float = 40.0
const CUTAWAY_PITCH_DEGREES: float = 65.0
const CUTAWAY_FIT: float = 1.3
const CUTAWAY_MIN_M: float = 18.0

const FOLLOW_TEXT: String = "Following %s · End or a pan stops"
const FOLLOW_NONE: String = "Select a resident, then End follows them"
const FOLLOW_STOPPED: String = "Stopped following %s"
const ORBIT_TEXT: String = "Orbiting %s · Esc stops"
const ORBIT_STOPPED: String = "Orbit stopped"
const CUTAWAY_TEXT: String = "Cutaway angle · Shift+U: your view back"
const CUTAWAY_BACK: String = "Your view back"
const SAVED_TEXT: String = "View %d saved · Shift+%d returns here"
const RECALL_TEXT: String = "View %d"
const EMPTY_TEXT: String = "No view %d yet · Ctrl+Shift+%d saves one"
const CENTRE_WORDS: String = "the view's centre"
## Each village building's words, by its model key (world_layout.gd BUILDINGS).
const BUILDING_WORDS: Dictionary = {&"hall": "the hall", &"well": "the well", &"residence": "the residence",
	&"kitchen": "the kitchen", &"covered_store": "the covered store", &"open_stockpile": "the open stockpile",
	&"workbench": "the workbench"}

## `primary() -> int`: the primary selected resident (-1: none).
var primary: Callable = Callable()
## `resident_point(who) -> Vector3`: where resident `who` stands (INF: no such resident).
var resident_point: Callable = Callable()
## `resident_name(who) -> String`: what resident `who` is called.
var resident_name: Callable = Callable()
## `modal_open() -> bool`: whether a modal holds the input (no camera key then).
var modal_open: Callable = Callable()
## `underground() -> bool` and `set_underground(on)`: the U view.
var underground: Callable = Callable()
var set_underground: Callable = Callable()
## `tunnel_extent() -> Rect2`: the network on the level shown, in metres (x, z); a negative size when there is none.
var tunnel_extent: Callable = Callable()

var strip: StripScript = StripScript.new()
## The edge pan (edge_pan.gd), off while a modal holds the input.
var edge: EdgePanScript = EdgePanScript.new()
var mode: int = MODE_FREE

var _rig: DemoCamera = null
var _who: int = -1
var _who_name: String = ""
var _orbit_name: String = ""
var _cutaway: bool = false
var _before_pitch: float = 0.0
var _before_distance: float = 0.0
var _seen_pan: int = 0
var _seen_turn: int = 0
## The village's buildings: (x, z, framing radius) and their words (`village_buildings`).
var _buildings: PackedVector3Array = PackedVector3Array()
var _building_words: PackedStringArray = PackedStringArray()


func _init() -> void:
	"""Named for the scene tree, with the strip and the edge pan as its children; runs before the rig each frame, so a
	follow's centre is this frame's."""
	name = "CameraModes"
	process_priority = -1
	village_buildings(_buildings, _building_words)
	add_child(strip)
	add_child(edge)


func configure(rig: DemoCamera) -> void:
	"""Drive `rig`, and start the edge pan over it."""
	_rig = rig
	_note_player()
	edge.configure(rig)
	edge.modal_open = _blocked


func escape_hook(event: InputEvent) -> bool:
	"""Esc stops an orbit, at its place in the dismissal ladder (see KEYS): true when it did (the event is taken)."""
	if mode != MODE_ORBIT or not is_escape(event) or _blocked():
		return false
	stop_orbit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	"""The modes' keys (see KEYS)."""
	if handle_key(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_key(event: InputEvent) -> bool:
	"""Apply one key press; true when it was the modes'."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _blocked() or _rig == null:
		return false
	if key.is_action_pressed(FOLLOW_ACTION, false, true):
		toggle_follow()
		return true
	var code: Key = key_of(key)
	var slot: int = code - KEY_0
	if Bookmarks.is_slot(slot) and key.shift_pressed and not (key.alt_pressed or key.meta_pressed):
		if key.ctrl_pressed:
			save_view(slot)
		else:
			recall_view(slot)
		return true
	if not shift_only(key):
		return false
	if code == ORBIT_KEY:
		toggle_orbit()
		return true
	if code == CUTAWAY_KEY:
		toggle_cutaway()
		return true
	return false


func _blocked() -> bool:
	"""Whether a modal holds the input."""
	return modal_open.is_valid() and bool(modal_open.call())


func _process(delta: float) -> void:
	"""One frame: end a mode the player's own move ended, leave the cutaway with the U view, and run the mode."""
	if _rig == null:
		return
	_watch_player()
	if _cutaway and underground.is_valid() and not bool(underground.call()):
		_restore_angle()
	if mode == MODE_FOLLOW:
		_follow_step()
	elif mode == MODE_ORBIT:
		_rig.turn_target(deg_to_rad(ORBIT_DEGREES_PER_SECOND) * delta)


func _watch_player() -> void:
	"""A pan the player made ends a follow or an orbit; a turn they made ends an orbit (see FOLLOW, ORBIT)."""
	var panned: bool = _rig.pan_revision() != _seen_pan
	var turned: bool = _rig.turn_revision() != _seen_turn
	_note_player()
	if mode == MODE_FOLLOW and panned:
		stop_follow()
	elif mode == MODE_ORBIT and (panned or turned):
		stop_orbit()


func _note_player() -> void:
	"""Take the rig's revisions as seen."""
	if _rig != null:
		_seen_pan = _rig.pan_revision()
		_seen_turn = _rig.turn_revision()


# --- follow ---------------------------------------------------------------------------------------------------

func toggle_follow() -> bool:
	"""End: follow the primary selected resident, or stop following. Returns whether a follow is on now."""
	if mode == MODE_FOLLOW:
		stop_follow()
		return false
	var who: int = int(primary.call()) if primary.is_valid() else -1
	if who < 0 or not _stands(who):
		strip.flash(FOLLOW_NONE)
		return false
	_end_orbit()
	mode = MODE_FOLLOW
	_who = who
	_who_name = String(resident_name.call(who)) if resident_name.is_valid() else ""
	_note_player()
	_follow_step()
	_refresh_strip()
	return true


func stop_follow() -> void:
	"""End the follow where the view is now, and say so."""
	if mode != MODE_FOLLOW:
		return
	mode = MODE_FREE
	_who = -1
	strip.flash(FOLLOW_STOPPED % _who_name)
	_refresh_strip()


func _stands(who: int) -> bool:
	"""Whether resident `who` is somewhere."""
	return resident_point.is_valid() and (resident_point.call(who) as Vector3).is_finite()


func _follow_step() -> void:
	"""Ease the centre over the followed resident; one gone ends the follow."""
	if not _stands(_who):
		stop_follow()
		return
	_rig.track(resident_point.call(_who) as Vector3)


func followed() -> int:
	"""The resident followed (-1: no follow)."""
	return _who if mode == MODE_FOLLOW else -1


# --- orbit ----------------------------------------------------------------------------------------------------

func toggle_orbit() -> bool:
	"""Shift+O: orbit the building nearest the view's centre, or stop. Returns whether an orbit is on now."""
	if mode == MODE_ORBIT:
		stop_orbit()
		return false
	_end_follow()
	_cutaway = false
	var centre: Vector3 = _rig.target_focus()
	var row: int = nearest_building(_buildings, centre, ORBIT_REACH_M)
	var metres: float = _rig.target_distance()
	_orbit_name = CENTRE_WORDS
	if row >= 0:
		centre = Vector3(_buildings[row].x, 0.0, _buildings[row].y)
		metres = orbit_distance(_buildings[row].z)
		_orbit_name = _building_words[row]
	_rig.aim(centre, _rig.target_yaw_degrees(), ORBIT_PITCH_DEGREES, metres)
	mode = MODE_ORBIT
	_note_player()
	_refresh_strip()
	return true


func stop_orbit() -> void:
	"""End the orbit; the view settles where it is."""
	if mode != MODE_ORBIT:
		return
	mode = MODE_FREE
	strip.flash(ORBIT_STOPPED)
	_refresh_strip()


func orbit_name() -> String:
	"""What the orbit turns round ("" with no orbit)."""
	return _orbit_name if mode == MODE_ORBIT else ""


# --- bookmarks ------------------------------------------------------------------------------------------------

func save_view(slot: int) -> bool:
	"""Keep the view the camera is going to in bookmark `slot`, and say so."""
	if not Bookmarks.save(slot, _rig.target_focus(), _rig.target_yaw_degrees(), _rig.target_pitch_degrees(),
			_rig.target_distance()):
		return false
	strip.flash(SAVED_TEXT % [slot, slot])
	return true


func recall_view(slot: int) -> bool:
	"""Go back to bookmark `slot` (eased; at once with reduced motion), ending a follow, an orbit and the cutaway angle;
	an empty slot says how to fill it."""
	if not Bookmarks.has(slot):
		strip.flash(EMPTY_TEXT % [slot, slot])
		return false
	_end_follow()
	_end_orbit()
	_cutaway = false
	_rig.aim(Bookmarks.focus_of(slot), Bookmarks.yaw_of(slot), Bookmarks.pitch_of(slot), Bookmarks.distance_of(slot))
	_note_player()
	strip.flash(RECALL_TEXT % slot)
	_refresh_strip()
	return true


# --- the cutaway angle ----------------------------------------------------------------------------------------

func toggle_cutaway() -> bool:
	"""Shift+U: the U view at the cutaway angle, or the angle you had back. Returns whether the cutaway is on now."""
	if _cutaway:
		_restore_angle()
		strip.flash(CUTAWAY_BACK)
		return false
	if set_underground.is_valid() and underground.is_valid() and not bool(underground.call()):
		set_underground.call(true)
	if not underground.is_valid() or not bool(underground.call()):
		return false
	_end_orbit()
	_before_pitch = _rig.target_pitch_degrees()
	_before_distance = _rig.target_distance()
	var extent: Rect2 = tunnel_extent.call() if tunnel_extent.is_valid() else Rect2(0.0, 0.0, -1.0, -1.0)
	var centre: Vector3 = _rig.target_focus()
	var metres: float = _rig.target_distance()
	if extent.size.x >= 0.0:
		centre = Vector3(extent.get_center().x, 0.0, extent.get_center().y)
		metres = cutaway_distance(extent)
	_rig.aim(centre, _rig.target_yaw_degrees(), CUTAWAY_PITCH_DEGREES, metres)
	_cutaway = true
	_refresh_strip()
	return true


func _restore_angle() -> void:
	"""The pitch and distance from before the cutaway, where the view is now."""
	_cutaway = false
	_rig.aim(_rig.target_focus(), _rig.target_yaw_degrees(), _before_pitch, _before_distance)
	_refresh_strip()


func cutaway() -> bool:
	"""Whether the cutaway angle is on."""
	return _cutaway


# --- shared ---------------------------------------------------------------------------------------------------

func _end_follow() -> void:
	"""End a follow without a word (another mode takes over)."""
	if mode == MODE_FOLLOW:
		mode = MODE_FREE
		_who = -1


func _end_orbit() -> void:
	"""End an orbit without a word (another mode takes over)."""
	if mode == MODE_ORBIT:
		mode = MODE_FREE


func _refresh_strip() -> void:
	"""The strip's lasting line: the follow's, else the orbit's, else the cutaway's, else none."""
	if mode == MODE_FOLLOW:
		strip.set_mode_text(FOLLOW_TEXT % _who_name)
	elif mode == MODE_ORBIT:
		strip.set_mode_text(ORBIT_TEXT % _orbit_name)
	elif _cutaway:
		strip.set_mode_text(CUTAWAY_TEXT)
	else:
		strip.set_mode_text("")


# --- the pure parts, public for the suite ---------------------------------------------------------------------

static func key_of(event: InputEventKey) -> Key:
	"""The event's key: its physical key when it has one, else its logical key (a bookmark is the digit's place)."""
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func shift_only(event: InputEventKey) -> bool:
	"""Whether Shift and no other modifier is held."""
	return event.shift_pressed and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed)


static func is_escape(event: InputEvent) -> bool:
	"""Whether `event` presses Esc (no repeat)."""
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key_of(key) == KEY_ESCAPE


static func village_buildings(out: PackedVector3Array, words: PackedStringArray) -> void:
	"""Fill `out` with each village building's (x, z, framing radius) -- the larger of half its footprint's diagonal
	and its height (world_sizes.gd) -- and `words` with its words, in world_layout.gd's order."""
	out.clear()
	words.clear()
	for entry: Dictionary in Layout.BUILDINGS:
		var key: StringName = entry["key"]
		var at: Vector2 = entry["at"]
		var radius: float = maxf(Sizes.scaled_rect(key, 1.0).size.length() * 0.5, Sizes.target_height_m(key))
		out.append(Vector3(at.x, at.y, radius))
		words.append(String(BUILDING_WORDS.get(key, "the building")))


static func nearest_building(buildings: PackedVector3Array, point: Vector3, reach: float) -> int:
	"""The row of the building whose centre is nearest `point` (x, z) within `reach` m (-1: none that near)."""
	var best: int = -1
	var best_d2: float = reach * reach
	for row: int in buildings.size():
		var dx: float = buildings[row].x - point.x
		var dz: float = buildings[row].y - point.z
		if dx * dx + dz * dz <= best_d2:
			best_d2 = dx * dx + dz * dz
			best = row
	return best


static func orbit_distance(radius: float) -> float:
	"""How far the orbit stands from a building of framing radius `radius` m: it fills about two thirds of the
	frame's height."""
	return clampf(radius * ORBIT_FIT / tan(deg_to_rad(DemoCamera.FOV_DEGREES * 0.5)), ORBIT_MIN_M, ORBIT_MAX_M)


static func cutaway_distance(extent: Rect2) -> float:
	"""How far the cutaway stands to fit a network spanning `extent` (m) in the frame."""
	var radius: float = extent.size.length() * 0.5
	return clampf(radius * CUTAWAY_FIT / tan(deg_to_rad(DemoCamera.FOV_DEGREES * 0.5)), CUTAWAY_MIN_M,
		DemoCamera.DISTANCE_MAX)


static func network_extent(network: Graph, level: int) -> Rect2:
	"""The box (x, z, m) round every node of `network` on `level`; a negative size when it has none there."""
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for node: int in network.node_kind.size():
		if not network.is_node(node) or int(network.node_level[node]) != level:
			continue
		var at: Vector2 = network.node_m(node)
		low = low.min(at)
		high = high.max(at)
	if low.x > high.x:
		return Rect2(0.0, 0.0, -1.0, -1.0)
	return Rect2(low, high - low)
