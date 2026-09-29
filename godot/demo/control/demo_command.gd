extends Node3D
## Select residents and order them about, in the live demo only. Decision 0196. Presentation: the
## orders move the demo cast (demo/cast/), never the simulation, whose movement is not built.
##
## CONTROLS (all raw mouse buttons and one key; the game's pointer router is not built):
##   left click a resident        select it alone          shift: toggle it in the selection
##   left drag                    box-select by screen position   shift: add to the selection
##   left click empty ground      clear the selection
##   right click ground           move the selection there, spread into a formation, then hold
##   right click a POI's spot     work there (its free slots; the rest hold behind it)
##   R                            release the selection back to wandering
##   Esc (`selection_clear`)      clear the selection
## The camera keeps WASD/arrows, wheel, Q/E and Home: nothing here reads them. R is the project's
## `placement_rotate`, which nothing in the demo handles (no placement tool is open); Esc is also
## `ui_cancel`/`open_menu`, so it is consumed here only while something is selected.
##
## ---------------------------------------------------------------------------------------
## INPUT arrives through `_unhandled_input`, after the GUI: a click the HUD (or the demo party
## panel) consumed never selects or orders. The one exception is a drag ALREADY STARTED on the
## world: its motion and release are followed in `_input` too, so a box dragged across a HUD panel
## keeps growing and still closes, instead of being left open by a release the HUD swallowed. PICKING is a camera ray against each resident's
## capsule proxy (demo_pick.gd) -- no physics bodies. MARKS: a pulsing brass ring under each
## selected resident, a faint ring under the hovered one, and a fading marker where an order
## landed (clay when refused). Per-frame work moves existing marks and allocates nothing; the
## panel is rebuilt only when what it shows changes.

const PickScript := preload("res://demo/control/demo_pick.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const RING_GAP_M: float = 0.12
const PULSE_HZ: float = 1.1
const PULSE_SCALE: float = 0.06
const MARKER_POOL: int = 4
const MARKER_S: float = 1.2
const MARKER_RADIUS_M: float = 0.6
const MARKER_GROWTH: float = 0.8
const PANEL_REFRESH_S: float = 0.2
const BOX_BORDER_PX: int = 2

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _panel: PanelScript = null
var _selected: PackedByteArray = PackedByteArray()
var _hover: int = -1
var _pressing: bool = false
var _dragging: bool = false
var _additive: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _rings: Array[MeshInstance3D] = []
var _hover_ring: MeshInstance3D = null
var _markers: Array[MeshInstance3D] = []
var _marker_age: PackedFloat32Array = PackedFloat32Array()
var _marker_colour: PackedColorArray = PackedColorArray()
var _marker_next: int = 0
var _box_layer: CanvasLayer = null
var _box: Panel = null
var _feet: PackedVector3Array = PackedVector3Array()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _screen: PackedVector2Array = PackedVector2Array()
var _on_screen: PackedByteArray = PackedByteArray()
var _hits: PackedInt32Array = PackedInt32Array()
var _signature: PackedInt32Array = PackedInt32Array()
var _shown: PackedInt32Array = PackedInt32Array()
var _time: float = 0.0
var _refresh_in: float = 0.0


func configure(cast: DemoCastScript, camera: Camera3D, hud_root: Control = null) -> void:
	"""Command this cast, picking through this camera. Builds the marks, box and party panel; the
	panel keeps clear of the HUD under `hud_root` (see demo_party_panel.gd)."""
	name = "DemoCommand"
	_cast = cast
	_camera = camera
	var count := cast.actor_count()
	_selected.resize(count)
	_on_screen.resize(count)
	_feet.resize(count)
	_heights.resize(count)
	_radii.resize(count)
	_screen.resize(count)
	_hits.resize(count)
	_build_marks(count)
	_build_box()
	_panel = PanelScript.new()
	add_child(_panel)
	_panel.watch_hud(hud_root)


func _build_marks(count: int) -> void:
	"""One selection ring per resident, a hover ring and a small pool of order markers."""
	for i in count:
		_rings.append(MarksScript.make_ring(MarksScript.SELECTED))
		add_child(_rings[i])
	_hover_ring = MarksScript.make_ring(MarksScript.HOVER)
	add_child(_hover_ring)
	for i in MARKER_POOL:
		_markers.append(MarksScript.make_ring(MarksScript.ORDERED))
		add_child(_markers[i])
	_marker_age.resize(MARKER_POOL)
	_marker_age.fill(MARKER_S)
	_marker_colour.resize(MARKER_POOL)


func _build_box() -> void:
	"""The drag box: a brass-edged, faintly washed rectangle over the world, ignoring the mouse."""
	_box_layer = CanvasLayer.new()
	_box_layer.layer = 0
	add_child(_box_layer)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.CREAM, 0.16)
	style.border_color = Color(Palette.DEEP_SHADE, 0.85)
	style.set_border_width_all(BOX_BORDER_PX)
	_box = Panel.new()
	_box.add_theme_stylebox_override(&"panel", style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_box_layer.add_child(_box)


# --- input ----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	"""Follow a world drag across the HUD (see INPUT). Nothing else is read here."""
	if not _pressing:
		return
	if event is InputEventMouseMotion:
		_on_motion((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not event.is_pressed():
		_on_button(event as InputEventMouseButton)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	"""World input the GUI did not consume."""
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	"""Apply one event; true when it was a selection or order input (and so consumed)."""
	if event is InputEventMouseButton:
		return _on_button(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		return _on_motion((event as InputEventMouseMotion).position)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _on_key(event as InputEventKey)
	return false


func _on_button(event: InputEventMouseButton) -> bool:
	"""Left press/release select (click or box); right press orders."""
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_additive = event.shift_pressed
			_press_at = event.position
		elif _pressing:
			_pressing = false
			_box.visible = false
			_finish_select(event.position)
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and selection_count() > 0:
		order_at(event.position)
		return true
	return false


func _on_motion(at: Vector2) -> bool:
	"""Grow the drag box while the left button is held; otherwise track the hovered resident."""
	if _pressing and (_dragging or PickScript.is_drag(_press_at, at)):
		_dragging = true
		_hover = -1
		_box.position = _press_at.min(at)
		_box.size = (_press_at - at).abs()
		_box.visible = true
		return true
	_hover = pick(at)
	return false


func _on_key(event: InputEventKey) -> bool:
	"""Esc clears a selection; R releases it."""
	if selection_count() == 0:
		return false
	if event.is_action_pressed(&"selection_clear"):
		clear_selection()
		return true
	if event.physical_keycode == KEY_R and not (event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		release_selection()
		return true
	return false


# --- selection ------------------------------------------------------------------------------

func _finish_select(at: Vector2) -> void:
	"""End a left press: a box selects what it holds; a click picks one resident or clears."""
	if _dragging:
		_dragging = false
		select_box(_press_at, at, _additive)
		return
	var hit := pick(at)
	if hit < 0:
		if not _additive:
			clear_selection()
	elif _additive:
		_selected[hit] = 1 - _selected[hit]
	else:
		_selected.fill(0)
		_selected[hit] = 1
	_refresh_in = 0.0


func select_box(corner_a: Vector2, corner_b: Vector2, additive: bool) -> void:
	"""Select every resident whose screen position lies in the box (added to the selection when
	`additive`)."""
	_update_screen()
	if not additive:
		_selected.fill(0)
	var count := PickScript.box_members(_screen, _on_screen, corner_a, corner_b, _hits)
	for k in count:
		_selected[_hits[k]] = 1
	_refresh_in = 0.0


func clear_selection() -> void:
	"""Deselect everyone."""
	_selected.fill(0)
	_refresh_in = 0.0


func selection_count() -> int:
	"""How many residents are selected."""
	return _selected.count(1)


func selected() -> PackedInt32Array:
	"""The selected actor indices, in cast order."""
	var out := PackedInt32Array()
	for i in _selected.size():
		if _selected[i] != 0:
			out.append(i)
	return out


func pick(at: Vector2) -> int:
	"""The resident under a screen point (nearest capsule the camera ray enters), or -1."""
	_update_proxies()
	var origin := _camera.project_ray_origin(at)
	var direction := _camera.project_ray_normal(at)
	return PickScript.nearest_hit(origin, direction, _feet, _heights, _radii)


func _update_proxies() -> void:
	"""Each resident's capsule proxy: foot position, height and body radius."""
	for i in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		_feet[i] = actor.global_position
		_heights[i] = actor.height_m
		_radii[i] = actor.brain.radius


func _update_screen() -> void:
	"""Each resident's mid-height point on screen, and whether it is in front of the camera."""
	_update_proxies()
	for i in _feet.size():
		var mid := _feet[i] + Vector3(0.0, _heights[i] * 0.5, 0.0)
		_on_screen[i] = 0 if _camera.is_position_behind(mid) else 1
		_screen[i] = _camera.unproject_position(mid)


# --- orders ---------------------------------------------------------------------------------

func order_at(at: Vector2) -> bool:
	"""Order the selection to the ground under a screen point: work at a POI's spot, otherwise move.
	Marks where the order landed, or a refusal. True when accepted."""
	var t := PickScript.ray_ground(_camera.project_ray_origin(at), _camera.project_ray_normal(at), 0.0)
	if t < 0.0:
		return false
	var point := _camera.project_ray_origin(at) + _camera.project_ray_normal(at) * t
	return order_to(point)


func order_to(point: Vector3) -> bool:
	"""Order the selection to a ground point (see order_at)."""
	var members := selected()
	var poi := _cast.poi_at(point)
	var result := _cast.order_work(members, poi) if poi >= 0 else _cast.order_move(members, point)
	mark(result["at"] if result["ok"] else point, bool(result["ok"]))
	_refresh_in = 0.0
	return bool(result["ok"])


func release_selection() -> void:
	"""Hand the selection back to wandering (it stays selected)."""
	_cast.release(selected())
	_refresh_in = 0.0


func mark(at: Vector3, accepted: bool) -> void:
	"""Start a fading ring at `at`: ember for an order, clay for a refusal."""
	var i := _marker_next
	_marker_next = (_marker_next + 1) % MARKER_POOL
	_marker_age[i] = 0.0
	_marker_colour[i] = MarksScript.ORDERED if accepted else MarksScript.REFUSED
	_markers[i].position = Vector3(at.x, MarksScript.LIFT_M, at.z)
	_markers[i].visible = true


# --- per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Move the rings with their residents, age the markers, and refresh the panel on change."""
	if _cast == null:
		return
	_time += delta
	_place_rings()
	_age_markers(delta)
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		_refresh_panel()
		_panel.follow_hud()


func _place_rings() -> void:
	"""Selection rings (pulsing) at the selected residents' feet; the hover ring at the hovered one."""
	var pulse := 1.0 + PULSE_SCALE * sin(TAU * PULSE_HZ * _time)
	for i in _rings.size():
		var ring := _rings[i]
		ring.visible = _selected[i] != 0
		if ring.visible:
			_put_ring(ring, _cast.actor(i) as DemoActorScript, pulse)
	_hover_ring.visible = _hover >= 0 and _hover < _cast.actor_count() and _selected[_hover] == 0
	if _hover_ring.visible:
		_put_ring(_hover_ring, _cast.actor(_hover) as DemoActorScript, 1.0)


func _put_ring(ring: MeshInstance3D, actor: DemoActorScript, pulse: float) -> void:
	"""A ring on the ground under `actor`, sized to its body radius."""
	var r := (actor.brain.radius + RING_GAP_M) * pulse
	ring.position.x = actor.global_position.x
	ring.position.y = MarksScript.LIFT_M
	ring.position.z = actor.global_position.z
	ring.scale.x = r
	ring.scale.y = 1.0
	ring.scale.z = r


func _age_markers(delta: float) -> void:
	"""Order markers grow a little and fade out over MARKER_S."""
	for i in MARKER_POOL:
		if not _markers[i].visible:
			continue
		_marker_age[i] += delta
		var f := _marker_age[i] / MARKER_S
		if f >= 1.0:
			_markers[i].visible = false
			continue
		var r := MARKER_RADIUS_M * (1.0 + MARKER_GROWTH * f)
		_markers[i].scale.x = r
		_markers[i].scale.z = r
		MarksScript.set_alpha(_markers[i], _marker_colour[i], 1.0 - f * f)


func _refresh_panel() -> void:
	"""Rebuild the panel only when the selection or what a selected resident is doing changed."""
	_signature.clear()
	for i in _selected.size():
		if _selected[i] != 0:
			var brain := (_cast.actor(i) as DemoActorScript).brain
			_signature.append(i)
			_signature.append(brain.activity())
			_signature.append(brain.poi)
			_signature.append(brain.clip.hash())
	if _signature == _shown:
		return
	_shown = _signature.duplicate()
	_panel.show_party(party_entries())


func party_entries() -> Array[Dictionary]:
	"""What the panel shows for each selected resident."""
	var entries: Array[Dictionary] = []
	var space := _cast.space()
	for i in selected():
		var actor := _cast.actor(i) as DemoActorScript
		var brain := actor.brain
		var place := ""
		if brain.poi >= 0:
			place = String(space.poi_names[brain.poi]).replace("_", " ")
		entries.append({"name": actor.display_name, "species": actor.species, "colour": actor.chip_colour,
			"state": PanelScript.state_text(brain.activity(), brain.clip, place)})
	return entries


func panel() -> PanelScript:
	"""The demo party panel."""
	return _panel
