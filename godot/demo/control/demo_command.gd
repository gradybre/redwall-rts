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
##   shift + right click          APPEND the order to the selection's order lists instead (decision 0411, UI §3's
##                                `command_queue`): a bed, a tree or the like queues its job, open ground a walk --
##                                the work board's `queue_at` (demo/work/work_orders.gd); not in the underground view
##   R                            release the selection back to wandering
##   Esc (`selection_clear`)      clear the selection
##   B (or T) / U                 the Dig tool (the cutaway, drag a tunnel) / underground view -- the
##                                tool (demo/tunnel/tunnel_control.gd) sees every event first and,
##                                while it is open, takes the clicks and keys it uses
##   left click a finished tunnel select it for the "Tunnels & burrows (demo)" panel, keeping any
##                                selected residents (demo/tunnel/tunnel_ext.gd)
##   left / right click a bed, a tree, a trunk, deadfall or the sawhorse: the farm's and the woods'
##                                GROUND HANDLERS take it first, in the order they were added
##                                (add_ground_handlers); a tool of theirs (the woods' zone marking)
##                                sees every event before selection does (add_input_hook)
## The camera keeps WASD/arrows, wheel, Q/E and Home: nothing here reads them. R is the project's
## `placement_rotate`, which nothing in the demo handles (no placement tool is open); Esc is also
## `ui_cancel`/`open_menu`, so it is consumed here only while something is selected.
##
## ---------------------------------------------------------------------------------------
## INPUT arrives through `_unhandled_input`, after the GUI: a click the HUD (or the demo party
## panel) consumed never selects or orders. The one exception is a drag ALREADY STARTED on the
## world: its motion and release are followed in `_input` too, so a box dragged across a HUD panel
## keeps growing and still closes, instead of being left open by a release the HUD swallowed. The
## other is the Dig tool's (tunnel_control.gd, decision 0208): Enter, and a drag's motion and release,
## are read in `_input`, before the GUI, so Enter always digs the piece laid and never presses a HUD button
## that happens to hold the focus, and a drag ending over the HUD still ends in the tool.
##
## PICKING is a camera ray against each resident's capsule proxy (demo_pick.gd) -- no physics
## bodies. A resident underground is picked where it is SEEN: at bore depth in the underground
## view; in the surface view, a digging mole by the mound over it (a squat capsule the mound's size
## on the ground), and anyone else below not at all. In the U view a resident on the surface is its
## marker on the level's floor, and a click on the ground lands on that floor (decision 0206: the
## cutaway shows the floor), where only the tunnel tool and the residents answer -- the farm's, the
## woods', the water's and the spoil heaps' handlers are surface things the U view does not draw.
## MARKS: a pulsing brass ring under each selected resident, a faint ring under the hovered one, and a
## fading marker where an order landed (clay when refused) -- each a PAIR, one on the surface's marks
## layer and one drawn through the cap on the floor for the U view (demo_layers.gd), so switching the
## view touches none of them. Per-frame work moves existing marks and allocates nothing; the panel is
## rebuilt only when what it shows changes.

const PickScript := preload("res://demo/control/demo_pick.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const TunnelControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const AbilitiesScript := preload("res://demo/control/resident_abilities.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const OrderList := preload("res://demo/work/order_list.gd")
const QueueAnswer := preload("res://demo/work/queue_answer.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")

const RING_GAP_M: float = 0.12
const PULSE_HZ: float = 1.1
const PULSE_SCALE: float = 0.06
const MARKER_POOL: int = 4
const MARKER_S: float = 1.2
const MARKER_RADIUS_M: float = 0.6
const MARKER_GROWTH: float = 0.8
const PANEL_REFRESH_S: float = 0.2
const BOX_BORDER_PX: int = 2
## A selection ring follows its resident's ground down no further than this (the water's surface: a
## diver's ring stays on top of the water, over it).
const SWIM_RING_FLOOR_M: float = -0.2
## The pick proxy of a mound over a digging mole: this tall, the mound's radius wide (see PICKING).
const MOUND_PICK_HEIGHT_M: float = 0.6
## The pick proxy of a surface resident's marker in the U view: this tall, the marker's radius wide.
const MARKER_PICK_HEIGHT_M: float = 0.3
## The U view's marks are drawn over the cap, after its markers (demo_actor.gd).
const BELOW_PRIORITY: int = 7

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _panel: PanelScript = null
var _tunnels: TunnelControlScript = null
var _selected: PackedByteArray = PackedByteArray()
## Bumped whenever the selection changes (decision 0361, the review's F01): a per-frame reader compares it with the one
## it last saw and reads the selection again only when it moved (`first_selected`, `selected_into`), never building
## an array a frame.
var _selection_revision: int = 0
var _hover: int = -1
var _pressing: bool = false
var _dragging: bool = false
var _additive: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _rings: Array[MeshInstance3D] = []
var _hover_ring: MeshInstance3D = null
var _markers: Array[MeshInstance3D] = []
## The same marks as the U view draws them, on the level's floor (see MARKS).
var _rings_below: Array[MeshInstance3D] = []
var _hover_below: MeshInstance3D = null
var _markers_below: Array[MeshInstance3D] = []
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
var _proxy: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
## Farm and woods hooks (demo/farm/, demo/forestry/): see add_ground_handlers, add_task_text,
## add_input_hook and set_skill_text; none: not used.
var _ground_clicks: Array[Callable] = []
var _ground_orders: Array[Callable] = []
var _task_texts: Array[Callable] = []
var _input_hooks: Array[Callable] = []
var _skill_texts: Array[Callable] = []
## `fed(actor_index, alone) -> String`: how fed a resident is (the kitchen's, decision 0381; see set_fed_text).
var _fed_text: Callable = Callable()
## The job owners' resume rules (work_interrupt.gd; see add_resume_rule).
var _resume_rules: Array[Callable] = []
## The camera's "look at this point" (set_centre), for pick_member.
var _centre: Callable = Callable()
## Shift+right-click's handler (`queue(screen, ground, members) -> QueueAnswer`; see set_queue_handler).
var _queue: Callable = Callable()
## The tool buttons' action card (reused; _refresh_tool_cards).
var _tool_card_data: CardScript = CardScript.new()
## The party panel's notice line, per resident (see say): its text, and when it was said (0: never).
var _notice_of: PackedStringArray = PackedStringArray()
var _notice_order: PackedInt32Array = PackedInt32Array()
var _notice_general: String = ""
var _notices_said: int = 0


func configure(cast: DemoCastScript, camera: Camera3D, hud_root: Control = null,
		services: ServicesScript = null) -> void:
	"""Command this cast, picking through this camera. Builds the marks, box and party panel; the
	panel keeps clear of the HUD under `hud_root` (see demo_party_panel.gd). `services` are the demo's
	shared weather, water and notice feed, for the tunnel works (none: they make their own)."""
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
	_notice_of.resize(count)
	_notice_order.resize(count)
	_build_marks(count)
	_build_box()
	_panel = PanelScript.new()
	add_child(_panel)
	_panel.watch_hud(hud_root)
	_tunnels = TunnelControlScript.new()
	add_child(_tunnels)
	_tunnels.configure(cast, camera, selected, mark, say, services)
	_tunnels.set_notice_about(say_about)
	register_below(_tunnels.view.prewarm)
	_connect_panel()
	_tunnels.ext.set_hud(hud_root)
	_tunnels.ext.set_interrupt(interrupt_text)


func _connect_panel() -> void:
	"""The party panel's buttons: the Dig and room tools, a member's row (pick_member), Release (R)."""
	_panel.dig_requested.connect(_on_dig_requested)
	_panel.room_requested.connect(_on_room_requested)
	_panel.member_picked.connect(pick_member)
	_panel.release_requested.connect(release_selection)


func set_world(world: DemoWorldScript) -> void:
	"""The world the tunnel tool's underground view fades and whose buildings it keeps out from under."""
	_tunnels.set_world(world)


func _on_dig_requested() -> void:
	"""The panel's "Dig tunnel" button: the same as B -- the Dig tool opened, or closed."""
	_tunnels.toggle_plan()


func _on_room_requested(kind: int) -> void:
	"""The panel's "Burrow home" / "Root cellar" buttons: the Dig tool's room tool for that template (H / C in
	the tool; decision 0209)."""
	_tunnels.begin_room(kind)


func tunnels() -> TunnelControlScript:
	"""The tunnel tool."""
	return _tunnels


func set_ground_handlers(click: Callable, order: Callable) -> void:
	"""Let one owner (the farm, demo/farm/) take world clicks first, replacing any others:
	`click(screen: Vector2) -> bool` on a left click that hit no resident (true: taken, and the
	selection is kept), `order(screen: Vector2) -> bool` on a right click with a selection (true: taken,
	no move or work order is given)."""
	_ground_clicks = [click]
	_ground_orders = [order]


func add_ground_handlers(click: Callable, order: Callable) -> void:
	"""Another owner's ground handlers (the woods, demo/forestry/), asked after those added before it."""
	_ground_clicks.append(click)
	_ground_orders.append(order)


func set_task_text(provider: Callable) -> void:
	"""`provider(actor_index: int) -> String`: what a resident is doing for the farm ("" for nothing),
	shown in the panel in place of its walking or holding state (see doing_text). Replaces any others."""
	_task_texts = [provider]


func add_task_text(provider: Callable) -> void:
	"""Another owner's "doing" words (the woods'), asked after those added before it."""
	_task_texts.append(provider)


func add_input_hook(hook: Callable) -> void:
	"""`hook(event: InputEvent) -> bool`: sees every world event after the tunnel tool and before
	selection (the woods' zone marking); true takes the event."""
	_input_hooks.append(hook)


func set_skill_text(provider: Callable) -> void:
	"""`provider(actor_index: int, alone: bool) -> String`: a resident's skills for the panel -- the
	long form when it is selected alone, the short one in a list (demo/forestry/forest_skills.gd).
	Replaces any others."""
	_skill_texts = [provider]


func add_skill_text(provider: Callable) -> void:
	"""Another owner's skills or meters (the water's: bridge building, breath and stamina), shown after
	those added before it."""
	_skill_texts.append(provider)


func set_fed_text(provider: Callable) -> void:
	"""`provider(actor_index: int, alone: bool) -> String`: how fed a resident is (demo/kitchen/kitchen.gd `fed_text`),
	the party panel's own rows right after what it is doing -- never after the skills, where a long list would push it
	down the inspector (decision 0381's note, with 0391)."""
	_fed_text = provider


func fed_text(actor_index: int) -> String:
	"""A resident's fed rows for the panel ("" with no kitchen): the long form alone, its word in a list."""
	return String(_fed_text.call(actor_index, selection_count() <= 1)) if _fed_text.is_valid() else ""


func say(text: String) -> void:
	"""THE PARTY PANEL'S NOTICE LINE (decision 0205): a prompt, an answer or a refusal ("" clears it), for
	whoever is selected now. It is kept per resident -- each selected one's own -- so selecting someone
	else shows theirs, not this (the playtest's otter showed the mole's "Resuming the tunnel at 44%").
	Said with nobody selected, it is the panel's general line, shown while nobody is."""
	_notices_said += 1
	var members := selected()
	if members.is_empty():
		_notice_general = text
	for i: int in members:
		_notice_of[i] = text
		_notice_order[i] = _notices_said
	_panel.show_notice(notice_for_selection())


func say_about(text: String, who: int) -> void:
	"""A notice about one resident, said whoever is selected (a tunnel opening or pausing on its own):
	kept for that resident, shown now only if it is selected (see say)."""
	if who < 0 or who >= _notice_of.size():
		return
	_notices_said += 1
	_notice_of[who] = text
	_notice_order[who] = _notices_said
	_panel.show_notice(notice_for_selection())


func notice_for_selection() -> String:
	"""The notice line for the selection: the latest said to any selected resident ("" for none said),
	or with nobody selected the general line."""
	var members := selected()
	if members.is_empty():
		return _notice_general
	var latest: int = -1
	for i: int in members:
		if _notice_order[i] > 0 and (latest < 0 or _notice_order[i] > _notice_order[latest]):
			latest = i
	return _notice_of[latest] if latest >= 0 else ""


func doing_text(actor_index: int) -> String:
	"""THE ONE ANSWER to "what is this resident doing for someone else?", in words ("" for nothing: the
	panel then says what it is walking or holding for). Two kinds of outside work drive a resident, and
	they never overlap: a TASK (resident_brain ORDER_TASK -- a tunnel job, a dig crew's place, an
	evacuation) speaks for itself through `task_label()`; the farm's work is ordered walks and holds, so
	the farm's crew says what it is (set_task_text). A task takes a resident from the farm's work, so it
	is asked first."""
	var brain := (_cast.actor(actor_index) as DemoActorScript).brain
	if brain.order == BrainScript.ORDER_TASK:
		return brain.task_label()
	for provider: Callable in _task_texts:
		var said: String = String(provider.call(actor_index))
		if not said.is_empty():
			return said
	return ""


func _build_marks(count: int) -> void:
	"""One selection ring per resident, a hover ring and a small pool of order markers -- each twice,
	for the surface and for the U view (see MARKS); the U view's selection rings share one material."""
	var selected_below: MeshInstance3D = null
	for i in count:
		_rings.append(_mark_node(MarksScript.SELECTED, false))
		_rings_below.append(_mark_node(MarksScript.SELECTED, true))
		if selected_below == null:
			selected_below = _rings_below[i]
		_rings_below[i].material_override = selected_below.material_override
	_hover_ring = _mark_node(MarksScript.HOVER, false)
	_hover_below = _mark_node(MarksScript.HOVER, true)
	for i in MARKER_POOL:
		_markers.append(_mark_node(MarksScript.ORDERED, false))
		_markers_below.append(_mark_node(MarksScript.ORDERED, true))
	_marker_age.resize(MARKER_POOL)
	_marker_age.fill(MARKER_S)
	_marker_colour.resize(MARKER_POOL)


func _mark_node(colour: Color, below: bool) -> MeshInstance3D:
	"""One ring mark on the surface's marks layer -- or, `below`, the U view's, drawn over the cap."""
	var ring := MarksScript.make_ring(colour)
	ring.layers = Layers.MARKS_ALL if below else Layers.SURFACE_MARKS
	if below:
		var material := ring.material_override as StandardMaterial3D
		material.no_depth_test = true
		material.render_priority = BELOW_PRIORITY
	add_child(ring)
	return ring


func register_below(prewarm: PrewarmScript) -> void:
	"""What the U view's marks draw, for its prewarm (decision 0206)."""
	for ring: MeshInstance3D in _rings_below + _markers_below + [_hover_below]:
		prewarm.add_mesh(ring.mesh, ring.material_override)


func underground_view() -> bool:
	"""Whether the tunnel tool's underground view is on."""
	return _tunnels != null and _tunnels.view.on


func _is_surface_click(event: InputEvent) -> bool:
	"""Whether `event` is a mouse press the surface tools must not see: any press in the U view (see
	PICKING). Releases, motion and keys still reach them, so a drag or an armed tool can end."""
	var button := event as InputEventMouseButton
	return underground_view() and button != null and button.pressed


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
	"""Follow a world drag across the HUD, and take the Dig tool's Enter and drags first (see INPUT).
	Nothing else is read here."""
	if take_before_gui(event):
		get_viewport().set_input_as_handled()
		return
	if not _pressing:
		return
	if event is InputEventMouseMotion:
		_on_motion((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not event.is_pressed():
		_on_button(event as InputEventMouseButton)
		get_viewport().set_input_as_handled()


func take_before_gui(event: InputEvent) -> bool:
	"""In the Dig tool, Enter (dig the piece laid) and a drag's motion and release, before any HUD control
	can take them (see INPUT). True when taken."""
	if _tunnels == null or not _tunnels.takes_before_gui(event):
		return false
	_tunnels.handle_input(event)
	_refresh_in = 0.0
	return true


func _unhandled_input(event: InputEvent) -> void:
	"""World input the GUI did not consume."""
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	"""Apply one event; true when it was a tunnel, selection or order input (and so consumed)."""
	if _tunnels != null and _tunnels.handle_input(event):
		_refresh_in = 0.0
		return true
	if not _is_surface_click(event):
		for hook: Callable in _input_hooks:
			if bool(hook.call(event)):
				_refresh_in = 0.0
				return true
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
		if event.shift_pressed and _queue.is_valid() and not underground_view():
			queue_at(event.position)
		else:
			order_at(event.position)
		return true
	return false


func set_queue_handler(queue: Callable) -> void:
	"""`queue(screen: Vector2, ground: Vector2, members: PackedInt32Array) -> QueueAnswer`: Shift+right-click appends
	the order to the selection's order lists (the work board, decision 0411): whether it did, and what to say."""
	_queue = queue


func queue_at(at: Vector2) -> bool:
	"""Shift+right-click at screen point `at`: the order appended to the selection's lists (see set_queue_handler),
	marked where it landed and said in the party panel. True when something was queued."""
	var ground: Vector2 = Layers.pick_ground(_camera.project_ray_origin(at), _camera.project_ray_normal(at),
		Layers.pick_y(false, Layers.active_level))
	var answer: QueueAnswer = _queue.call(at, ground, selected())
	if ground.is_finite():
		mark(Vector3(ground.x, 0.0, ground.y), answer.ok)
	say(answer.words)
	_refresh_in = 0.0
	return answer.ok


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
		if _tunnels != null:
			_tunnels.ext.deselect_room()
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
	if hit < 0 and not underground_view() and _ground_clicked(at):
		_refresh_in = 0.0
		return
	if hit < 0:
		var tunnel_hit := _tunnels != null and _tunnels.select_tunnel_at(at)
		if not tunnel_hit and not _additive:
			clear_selection()
			if _tunnels != null:
				_tunnels.ext.actions.clear_selection()
				_tunnels.ext.deselect_room()
	elif _additive:
		_selected[hit] = 1 - _selected[hit]
	else:
		_selected.fill(0)
		_selected[hit] = 1
	_selection_revision += 1
	_refresh_in = 0.0


func _ground_clicked(at: Vector2) -> bool:
	"""Offer a left click on no resident to each ground handler in turn; true when one took it."""
	for handler: Callable in _ground_clicks:
		if bool(handler.call(at)):
			return true
	return false


func select_box(corner_a: Vector2, corner_b: Vector2, additive: bool) -> void:
	"""Select every resident whose screen position lies in the box (added to the selection when
	`additive`)."""
	_update_screen()
	if not additive:
		_selected.fill(0)
	var count := PickScript.box_members(_screen, _on_screen, corner_a, corner_b, _hits)
	for k in count:
		_selected[_hits[k]] = 1
	_selection_revision += 1
	_refresh_in = 0.0


func select(members: PackedInt32Array) -> void:
	"""Select exactly these actor indices (unknown ones are skipped)."""
	_selected.fill(0)
	for i in members:
		if i >= 0 and i < _selected.size():
			_selected[i] = 1
	_selection_revision += 1
	_refresh_in = 0.0


func clear_selection() -> void:
	"""Deselect everyone."""
	_selected.fill(0)
	_selection_revision += 1
	_refresh_in = 0.0


func selection_count() -> int:
	"""How many residents are selected."""
	return _selected.count(1)


func is_selected(actor_index: int) -> bool:
	"""Whether this resident is selected (no array is built: the village map's dots and the canopy's per-frame check)."""
	return actor_index >= 0 and actor_index < _selected.size() and _selected[actor_index] != 0


func selection_revision() -> int:
	"""Bumped whenever the selection changes: compare it with the one last seen before reading the selection again."""
	return _selection_revision


func first_selected() -> int:
	"""The first selected actor index in cast order, or -1 with none selected (per-frame safe: no array made)."""
	return _selected.find(1)


func selected_into(out: PackedInt32Array) -> int:
	"""The selected actor indices, in cast order, written into `out` (resized only when the count changed); how many.
	Per-frame safe with a kept `out`."""
	var count := _selected.count(1)
	if out.size() != count:
		out.resize(count)
	var k := 0
	for i in _selected.size():
		if _selected[i] != 0:
			out[k] = i
			k += 1
	return count


func selected() -> PackedInt32Array:
	"""The selected actor indices, in cast order (a new array: once per order or click, never per frame -- a per-frame
	reader uses `selection_revision` with `first_selected` or `selected_into`)."""
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
	"""Each resident's capsule proxy: foot position, height and body radius -- where it is seen (see
	PICKING; a proxy of radius 0 cannot be picked)."""
	var below_seen := underground_view()
	var eye := _camera.global_position if _camera.is_inside_tree() else Vector3.ZERO
	for i in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		var foot := actor.global_position if actor.is_inside_tree() else actor.position
		proxy_into(actor.brain, foot, actor.height_m, below_seen, eye, _proxy)
		_feet[i] = Vector3(_proxy[0], _proxy[1], _proxy[2])
		_heights[i] = _proxy[3]
		_radii[i] = _proxy[4]


static func proxy_into(brain: BrainScript, foot: Vector3, height: float, below_seen: bool, eye: Vector3,
		out: PackedFloat32Array) -> void:
	"""One resident's pick proxy where it is seen (see PICKING) into out: foot x, y, z, height, radius.
	On the surface, or underground in the underground view: its body where it is drawn -- except a
	resident on the surface, or on another level than the U view shows (decision 0212), which is its marker on the
	shown level's floor. Underground otherwise: a digging mole as its mound -- on the ground, the mound's drawn
	radius from `eye` -- and anyone else not at all (radius 0). Asleep inside the hall (not drawn), not at all."""
	out[0] = foot.x
	out[1] = foot.y
	out[2] = foot.z
	out[3] = height
	out[4] = brain.radius if not brain.indoors else 0.0
	if brain.indoors:
		return
	if below_seen and brain.view_level() != Layers.active_level:
		out[1] = Layers.view_floor_y()
		out[3] = MARKER_PICK_HEIGHT_M
		out[4] = DemoActorScript.MARKER_RADIUS_M + DemoActorScript.MARKER_EDGE_M
		return
	if not brain.underground or below_seen:
		return
	out[1] = 0.0
	out[3] = MOUND_PICK_HEIGHT_M
	out[4] = 0.0
	if brain.activity() == BrainScript.ACTIVITY_DIGGING:
		out[4] = OverlayScript.MOUND_RADIUS_M * OverlayScript.mound_scale(eye.distance_to(Vector3(foot.x, 0.0, foot.z)))


func _update_screen() -> void:
	"""Each resident's mid-height point on screen, and whether it is in front of the camera."""
	_update_proxies()
	for i in _feet.size():
		var mid := _feet[i] + Vector3(0.0, _heights[i] * 0.5, 0.0)
		_on_screen[i] = 0 if _camera.is_position_behind(mid) or _radii[i] <= 0.0 else 1
		_screen[i] = _camera.unproject_position(mid)


# --- orders ---------------------------------------------------------------------------------

func order_at(at: Vector2) -> bool:
	"""Order the selection to the ground under a screen point: work at a POI's spot, otherwise move.
	Marks where the order landed, or a refusal. True when accepted."""
	if not underground_view():
		for handler: Callable in _ground_orders:
			if bool(handler.call(at)):
				_refresh_in = 0.0
				return true
	return order_along(_camera.project_ray_origin(at), _camera.project_ray_normal(at))


func order_along(origin: Vector3, direction: Vector3) -> bool:
	"""Order the selection to where a unit ray meets the view's plane -- the ground, or the level's floor
	in the underground view (see PICKING). False when it misses the plane."""
	var ground: Vector2 = Layers.pick_ground(origin, direction, Layers.pick_y(underground_view(), Layers.active_level))
	if ground == Vector2.INF:
		return false
	return order_to(Vector3(ground.x, 0.0, ground.y))


func order_to(point: Vector3) -> bool:
	"""Order the selection to a ground point (see order_at)."""
	var members := selected()
	var poi := _cast.poi_at(point)
	var result := _cast.order_work(members, poi) if poi >= 0 else _cast.order_move(members, point)
	mark(result["at"] if result["ok"] else point, bool(result["ok"]))
	_refresh_in = 0.0
	return bool(result["ok"])


func set_centre(centre: Callable) -> void:
	"""`centre(point: Vector3)`: ease the camera to look at a point (demo_camera.gd `centre_on`), for `pick_member`."""
	_centre = centre


func pick_member(actor_index: int) -> void:
	"""A listed resident was picked (the party panel's member row, the Water panel's roster row): select it alone
	and centre the camera on it (decision 0391)."""
	if _cast == null or actor_index < 0 or actor_index >= _cast.actor_count():
		return
	select(PackedInt32Array([actor_index]))
	if _centre.is_valid():
		var at: Vector2 = (_cast.actor(actor_index) as DemoActorScript).brain.position
		_centre.call(Vector3(at.x, 0.0, at.y))


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
	_markers_below[i].position = Vector3(at.x, Layers.view_floor_y() + Layers.MARK_LIFT_M, at.z)
	_markers_below[i].visible = true


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
		_refresh_tool_cards()
		_panel.follow_hud()


func _place_rings() -> void:
	"""Selection rings (pulsing; still with reduced motion, decision 0471) at the selected residents' feet; the hover
	ring at the hovered one."""
	var pulse := DemoMotion.pulse(1.0 + PULSE_SCALE * sin(TAU * PULSE_HZ * _time))
	for i in _rings.size():
		_rings[i].visible = _selected[i] != 0
		_rings_below[i].visible = _rings[i].visible
		if _rings[i].visible:
			var actor := _cast.actor(i) as DemoActorScript
			_put_ring(_rings[i], actor.global_position, actor.brain, pulse)
			_put_ring_below(_rings_below[i], actor.brain, pulse)
	_hover_ring.visible = _hover >= 0 and _hover < _cast.actor_count() and _selected[_hover] == 0
	_hover_below.visible = _hover_ring.visible
	if _hover_ring.visible:
		var hovered := _cast.actor(_hover) as DemoActorScript
		_put_ring(_hover_ring, hovered.global_position, hovered.brain, 1.0)
		_put_ring_below(_hover_below, hovered.brain, 1.0)


static func ring_y_m(underground: bool, ground_y_m: float) -> float:
	"""A selection ring's height: just above the ground its resident stands on, never below the water's
	surface (SWIM_RING_FLOOR_M), and at the datum over a resident underground (the surface marks it)."""
	return MarksScript.LIFT_M + (0.0 if underground else maxf(ground_y_m, SWIM_RING_FLOOR_M))


func _put_ring(ring: MeshInstance3D, at: Vector3, brain: BrainScript, pulse: float) -> void:
	"""A ring under a resident at `at` (its actor's position) -- on the ground its `brain` stands on: a
	bank's slope, a wading bed, a bridge's deck, the water's surface for a swimmer (not a diver's depth,
	nor a bore's) -- sized to its body radius."""
	var r := (brain.radius + RING_GAP_M) * pulse
	ring.position.x = at.x
	ring.position.y = ring_y_m(brain.underground, brain.ground_y_m)
	ring.position.z = at.z
	ring.scale.x = r
	ring.scale.y = 1.0
	ring.scale.z = r


static func _put_ring_below(ring: MeshInstance3D, brain: BrainScript, pulse: float) -> void:
	"""The U view's ring under a resident: on the bore floor it stands on, or -- on the surface or another level
	than the U view shows -- round its marker on the shown level's floor (see MARKS)."""
	var r := (brain.radius + RING_GAP_M) * pulse
	var floor_y: float = brain.ground_y_m if brain.view_level() == Layers.active_level else Layers.view_floor_y()
	ring.position = Vector3(brain.position.x, floor_y + Layers.MARK_LIFT_M, brain.position.y)
	ring.scale = Vector3(r, 1.0, r)


func _age_markers(delta: float) -> void:
	"""Order markers grow a little and fade out over MARKER_S."""
	for i in MARKER_POOL:
		if not _markers[i].visible:
			continue
		_marker_age[i] += delta
		var f := _marker_age[i] / MARKER_S
		if f >= 1.0:
			_markers[i].visible = false
			_markers_below[i].visible = false
			continue
		var r := MARKER_RADIUS_M * (1.0 + MARKER_GROWTH * f)
		_fade_marker(_markers[i], r, _marker_colour[i], 1.0 - f * f)
		_fade_marker(_markers_below[i], r, _marker_colour[i], 1.0 - f * f)


static func _fade_marker(marker: MeshInstance3D, radius: float, colour: Color, alpha: float) -> void:
	"""One order marker at this radius and fade."""
	marker.scale.x = radius
	marker.scale.z = radius
	MarksScript.set_alpha(marker, colour, alpha)


func _refresh_panel() -> void:
	"""Rebuild the panel only when the selection or what a selected resident is doing changed; the notice
	line follows the selection (see say)."""
	var line: String = notice_for_selection()
	if line != _panel.notice():
		_panel.show_notice(line)
	_signature.clear()
	for i in _selected.size():
		if _selected[i] != 0:
			var brain := (_cast.actor(i) as DemoActorScript).brain
			_signature.append(i)
			_signature.append(brain.activity())
			_signature.append(brain.poi)
			_signature.append(brain.clip.hash())
			_signature.append(_dug_percent(brain))
			_signature.append(doing_text(i).hash())
			_signature.append(skills_text(i).hash())
			_signature.append(fed_text(i).hash())
			_signature.append(brain.queue_revision)
	if _signature == _shown:
		return
	_shown = _signature.duplicate()
	_panel.show_party(party_entries())


func party_entries() -> Array[Dictionary]:
	"""What the panel shows for each selected resident."""
	var entries: Array[Dictionary] = []
	for i in selected():
		var actor := _cast.actor(i) as DemoActorScript
		var brain := actor.brain
		entries.append({"index": i, "name": actor.display_name, "species": actor.species, "colour": actor.chip_colour,
			"digger": _tunnels.is_digger(i), "state": activity_text(i), "skills": skills_text(i), "fed": fed_text(i),
			"abilities": AbilitiesScript.lines_for(actor.species, actor.height_m, brain.radius, brain.can_carry()),
			"then": OrderList.items_into(brain, PackedStringArray())})
	return entries


func activity_text(actor_index: int) -> String:
	"""What a resident is doing now, in the party panel's words: its outside work (doing_text), else its walking,
	working, digging or holding state at its place (demo_party_panel.gd `state_text`). The Residents roster
	(demo/ui/demo_roster.gd, decision 0251) prints the same words, so the two never disagree."""
	var doing := doing_text(actor_index)
	if doing != "":
		return doing
	var brain := (_cast.actor(actor_index) as DemoActorScript).brain
	var place := ""
	if brain.poi >= 0:
		place = String(_cast.space().poi_names[brain.poi]).replace("_", " ")
	elif brain.order == BrainScript.ORDER_DIG:
		place = _dig_place(brain)
	if brain.activity() == BrainScript.ACTIVITY_HOLDING and brain.trip_failed():
		return PanelScript.HOLDING_REFUSED % brain.route_refusal()
	return PanelScript.state_text(brain.activity(), brain.clip, place, _dug_percent(brain))


func skills_text(actor_index: int) -> String:
	"""A resident's skills for the panel ("" with no provider): every provider's words, the long form a
	line each (the panel shows a line apiece) when it is selected alone, the short forms joined in a list."""
	var alone: bool = selection_count() <= 1
	var parts := PackedStringArray()
	for provider: Callable in _skill_texts:
		var said: String = String(provider.call(actor_index, alone))
		if not said.is_empty():
			parts.append(said)
	return ("\n" if alone else " · ").join(parts)


func _dig_place(brain: BrainScript) -> String:
	"""Where a digger is digging, in words: its room's name ("Burrow home 1"; decision 0209), else the dig site."""
	var network := _cast.space().tunnels
	var r: int = network.seg_room[brain.dig_tunnel] if brain.dig_tunnel >= 0 else -1
	if r < 0 or not network.rooms.is_room(r):
		return PanelScript.DIG_SITE
	return "%s %d" % [RoomsScript.NAMES[network.rooms.template[r]], r + 1]


func _dug_percent(brain: BrainScript) -> int:
	"""How much of the piece this resident is digging is dug (0 when it digs none)."""
	var network := _cast.space().tunnels
	return network.piece_percent(network.piece[brain.dig_tunnel]) if brain.dig_tunnel >= 0 else 0


func panel() -> PanelScript:
	"""The demo party panel."""
	return _panel


# --- what an order interrupts (decision 0332, review F44) -----------------------------------------

func add_resume_rule(rule: Callable) -> void:
	"""`rule(actor_index: int) -> int`: a job owner's answer to "if an order takes this resident from your job, does
	it go back to it?" (work_interrupt.gd's codes, NOT_MINE for a resident it has no job for)."""
	_resume_rules.append(rule)


func interrupt_text(actor_index: int) -> String:
	"""What an order given to this resident now interrupts, and whether it goes back to it after -- the action
	cards' line (demo/ui/action_card.gd): the party panel's own activity words, the brain's RESUMING rule."""
	if actor_index < 0 or actor_index >= _cast.actor_count():
		return ""
	var brain := (_cast.actor(actor_index) as DemoActorScript).brain
	return InterruptScript.text(activity_text(actor_index), InterruptScript.resume_of(brain, _resume_rules, actor_index))


func _refresh_tool_cards() -> void:
	"""The party panel's Dig tunnel and room tool buttons, each with its action card (tunnel_control.gd
	`tool_card_into`) and what its digger would stop doing -- while they show."""
	var dig := _panel.dig_button()
	if dig == null or not dig.visible or _tunnels == null:
		return
	_tool_card(dig, PanelScript.DIG_TIP)
	for k: int in PanelScript.ROOM_TIPS.size():
		var room := _panel.room_button(k)
		if room != null:
			_tool_card(room, PanelScript.ROOM_TIPS[k])


func _tool_card(button: Button, tip: String) -> void:
	"""One tool button's card: its own words (`tip`: "Name (key) — what it does") as verb and result."""
	var cut := tip.find(" — ")
	_tunnels.tool_card_into(_tool_card_data, tip.left(cut), tip.substr(cut + 3))
	if _tool_card_data.worker >= 0:
		_tool_card_data.interrupts = interrupt_text(_tool_card_data.worker)
	var said := _tool_card_data.text()
	CardScript.dress(button)
	if button.tooltip_text != said:
		button.tooltip_text = said
