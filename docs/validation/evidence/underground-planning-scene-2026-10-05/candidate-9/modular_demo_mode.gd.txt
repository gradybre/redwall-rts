extends Node3D
## Actual settlement planning presentation, mounted by DemoVillage; never a second simulation.

const Host := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const RoomMode := preload("res://demo/burrow/modular_room_mode.gd")
const WorldView := preload("res://demo/burrow/modular_world_view.gd")
const Rig := preload("res://demo/camera/demo_camera.gd")
const Look := preload("res://demo/world/world_look.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const SURFACE_LAYER: int = 64
const SECTION_LAYER: int = 128
const MARKS_LAYER: int = 256
const MAX_LEGACY_NODES: int = 65536
const THEME: Theme = preload("res://ui/theme/woodland_theme.tres")

class GuardedRig extends Rig:
	## The original camera mechanics, with the planning modal checked before input and held motion.
	var guard: Callable = Callable()

	func _allowed() -> bool:
		"""Fail closed and discard held movement and easing when any modal takes ownership."""
		var denied: Variant = guard.call() if guard.is_valid() else true
		if typeof(denied) == TYPE_BOOL and not denied: return true
		_held.fill(0)
		_drag_turning = false
		_edge_strafe = 0
		_edge_advance = 0
		_target_focus = _focus
		_target_yaw = _yaw
		_target_pitch = _pitch
		_target_distance = _distance
		return false

	func _input(event: InputEvent) -> void:
		"""An active modal owns even a drag started before it appeared."""
		if _allowed(): super._input(event)

	func _unhandled_input(event: InputEvent) -> void:
		"""Do not collect camera presses or zoom behind the modal."""
		if _allowed(): super._unhandled_input(event)

	func _process(delta: float) -> void:
		"""Check the actual hold before advancing previously held keys, regardless of node order."""
		if _allowed(): super._process(delta)

var _host: WeakRef = null
var _legacy: Node = null
var _stall: CanvasLayer = null
var _old_rig: Rig = null
var _old_camera: Camera3D = null
var _passive: Array[Node] = []
var _passive_flags: PackedByteArray = PackedByteArray()
var _inputs: Array[Node] = []
var _input_flags: PackedByteArray = PackedByteArray()
var _layers: Array[CanvasLayer] = []
var _layer_flags: PackedByteArray = PackedByteArray()
var _external_blocked: Callable = Callable()
var _mode: RoomMode = null
var _view: WorldView = null
var _rig: Rig = null
var _sun: DirectionalLight3D = null
var _toolbar: CanvasLayer = null
var _shield: CanvasLayer = null
var _stall_layer: int = 0
var _modal_blocked: bool = false
var _stock: Label = null
var _clock_words: Label = null
var _pause: Button = null
var _active: bool = false
var _framed: bool = false
var _refresh_in: float = 0.0
var _bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])


func configure(host: Host, legacy: Node, old_rig: Rig, stall: CanvasLayer,
		passive: Array[Node], blocked: Callable) -> StringName:
	"""Capture the scene's presentation handover; all authoritative ownership remains with the host."""
	if _host != null or host == null or not is_instance_valid(legacy) or not is_instance_valid(old_rig) \
			or not is_instance_valid(stall) or not blocked.is_valid(): return &"ROOM_SCENE_BINDING"
	_host = weakref(host)
	_legacy = legacy
	_old_rig = old_rig
	_stall = stall
	_passive = passive.duplicate()
	_external_blocked = blocked
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = legacy.process_priority + 1
	visible = false
	set_process(false)
	return &""


func open() -> StringName:
	"""Open only over the original composed World; no order or access endpoint is fabricated."""
	if _active: return &""
	if GameManager.clock().has_pause_reason(Clock.CRITICAL) or not _external_blocked.is_valid() \
			or bool(_external_blocked.call()): return &"ROOM_SCENE_MODAL"
	var code: StringName = _prepare()
	if code != &"": return code
	code = _capture_legacy()
	if code != &"": return code
	return _activate()


func _prepare() -> StringName:
	"""Recompose a newly created World's missing owners before replacing any old presentation."""
	var host: Host = _host.get_ref() as Host if _host != null else null
	if host == null: return RoomMode.REFUSE_OWNER
	var actual: Session = host.underground_session()
	if actual == null: return RoomMode.REFUSE_OWNER
	var current: StringName = actual.current_refusal()
	if current != &"": return current
	if actual.room_orders() == null and not host.compose_underground_room_owners(): return host.last_refusal()
	if actual.world_route_provider() == null and not host.compose_underground_route_owners(): return host.last_refusal()
	if _mode != null and _mode._live_session() == null: _drop_view()
	if _mode == null:
		var code: StringName = _mount(actual)
		if code != &"":
			_drop_view()
			return code
	return _view.set_floor(_mode._view_level)


func _activate() -> StringName:
	"""Hand over the camera and UI only after the actual floor and original owner tuple pass."""
	_old_camera = get_viewport().get_camera_3d()
	_clear_camera_keys(_old_rig)
	_active = true
	_stall.layer = 63
	_hold_legacy()
	visible = true
	_toolbar.visible = true
	_rig.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_rig.make_current()
	if not _mode.set_active(true) or not _active:
		close()
		return RoomMode.REFUSE_OWNER
	_refresh_toolbar()
	_refresh_modal()
	return &""


func is_active() -> bool:
	"""The shared demo host uses this presentation state for its dismissal ladder."""
	return _active


func close() -> void:
	"""Restore only recorded presentation/input state; all draft cells and the game clock are retained."""
	if not _active: return
	_active = false
	_dismiss_popups()
	_mode.set_active(false)
	_clear_camera_keys(_rig)
	_rig.process_mode = Node.PROCESS_MODE_DISABLED
	_toolbar.visible = false
	_shield.visible = false
	_modal_blocked = false
	visible = false
	set_process(false)
	_restore_legacy()
	if is_instance_valid(_old_camera) and _old_camera.is_inside_tree(): _old_camera.make_current()
	_old_camera = null
	if is_inside_tree(): get_viewport().gui_release_focus()


func _mount(actual: Session) -> StringName:
	"""Borrow the original retained Domain, Levels and World for actual-coordinate presentation."""
	var code: StringName = actual.current_refusal()
	if code != &"": return code
	var guarded: GuardedRig = GuardedRig.new()
	guarded.guard = _blocked
	_rig = guarded
	add_child(_rig)
	_rig.camera().cull_mask = SURFACE_LAYER | SECTION_LAYER | MARKS_LAYER
	_rig.camera().environment = Look._environment()
	_view = WorldView.new()
	add_child(_view)
	code = _view.configure(actual._world, actual._world_ref, actual._domain, actual._levels,
		SURFACE_LAYER, SECTION_LAYER)
	if code != &"" or not _view.bounds_into(_bounds): return code if code != &"" else RoomMode.REFUSE_OWNER
	_sun = Look.make_sun()
	_sun.light_cull_mask = SURFACE_LAYER | SECTION_LAYER | MARKS_LAYER
	add_child(_sun)
	_mode = RoomMode.new()
	add_child(_mode)
	code = _mode.configure(actual, _rig.camera(), _blocked, MARKS_LAYER)
	if code != &"": return code
	_mode.close_requested.connect(close)
	_mode.floor_changed.connect(_select_floor)
	_build_toolbar()
	_build_modal_shield()
	_rig.process_mode = Node.PROCESS_MODE_DISABLED
	return &""


func _select_floor(level_id: int, floor_u: int) -> void:
	"""Use the exact selected floor for both visible dirt and the existing RTS camera's focus plane."""
	if _view.set_floor(level_id) != &"":
		close()
		return
	var previous: Vector3 = _rig.focus()
	var focus: Vector3 = Vector3(float(_bounds[0] + _bounds[3]) / 2048.0, float(floor_u) / 1024.0,
		float(_bounds[2] + _bounds[5]) / 2048.0) if not _framed else Vector3(previous.x, float(floor_u) / 1024.0, previous.z)
	var yaw: float = _rig.target_yaw_degrees()
	var pitch: float = _rig.target_pitch_degrees()
	var distance: float = _rig.target_distance()
	_rig.configure(AABB(Vector3(float(_bounds[0]) / 1024.0, focus.y, float(_bounds[2]) / 1024.0),
		Vector3(float(_bounds[3] - _bounds[0]) / 1024.0, 0, float(_bounds[5] - _bounds[2]) / 1024.0)), focus)
	_rig.aim(focus, yaw, pitch, distance)
	_rig.snap()
	_framed = true


func _capture_legacy() -> StringName:
	"""Bound one cold tree scan; store only input owners and canvas layers, not a second scene."""
	_inputs.clear()
	_input_flags.clear()
	_layers.clear()
	_layer_flags.clear()
	_stall_layer = _stall.layer
	var pending: Array[Node] = [_legacy]
	var count: int = 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node == self or node == _stall: continue
		count += 1
		if count > MAX_LEGACY_NODES: return &"ROOM_SCENE_UI_CAPACITY"
		var flags: int = int(node.is_processing_input()) | (int(node.is_processing_unhandled_input()) << 1) \
			| (int(node.is_processing_unhandled_key_input()) << 2)
		if flags != 0:
			_inputs.append(node)
			_input_flags.append(flags)
		if node is CanvasLayer:
			_layers.append(node)
			_layer_flags.append(int(node.visible))
		pending.append_array(node.get_children())
	_passive_flags.resize(_passive.size())
	for index: int in _passive.size():
		_passive_flags[index] = int(_passive[index].is_processing()) if is_instance_valid(_passive[index]) else 0
	return &""


func _hold_legacy() -> void:
	"""Keep legacy overlays/input out of the active viewport while their simulation callbacks continue."""
	for node: Node in _inputs:
		if is_instance_valid(node): _set_input_flags(node, 0)
	for layer: CanvasLayer in _layers:
		if is_instance_valid(layer): layer.visible = false
	for node: Node in _passive:
		if is_instance_valid(node): node.set_process(false)


func _restore_legacy() -> void:
	"""Each old input/visibility flag is restored to its recorded value, including originally hidden panels."""
	for index: int in _inputs.size():
		if is_instance_valid(_inputs[index]): _set_input_flags(_inputs[index], _input_flags[index])
	for index: int in _layers.size():
		if is_instance_valid(_layers[index]): _layers[index].visible = _layer_flags[index] == 1
	for index: int in _passive.size():
		if is_instance_valid(_passive[index]): _passive[index].set_process(_passive_flags[index] == 1)
	if is_instance_valid(_stall): _stall.layer = _stall_layer
	_inputs.clear()
	_input_flags.clear()
	_layers.clear()
	_layer_flags.clear()


static func _set_input_flags(node: Node, flags: int) -> void:
	"""Change input dispatch only; no simulation processing or pause state is changed."""
	node.set_process_input((flags & 1) != 0)
	node.set_process_unhandled_input((flags & 2) != 0)
	node.set_process_unhandled_key_input((flags & 4) != 0)


static func _clear_camera_keys(rig: Rig) -> void:
	"""Explicit releases prevent hidden camera keys or a drag from sticking across view handover."""
	if not is_instance_valid(rig): return
	for action: StringName in Rig.HELD_ACTIONS:
		var release: InputEventAction = InputEventAction.new()
		release.action = action
		release.pressed = false
		rig.handle_input(release)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = false
	rig.drag_input(mouse)
	rig.set_edge_push(0, 0)


func _blocked() -> bool:
	"""The shared stall-recovery banner owns interaction until the player acknowledges it."""
	return not _active or GameManager.clock().has_pause_reason(Clock.CRITICAL) \
		or not _external_blocked.is_valid() or bool(_external_blocked.call())


func _build_modal_shield() -> void:
	"""Keep mouse input below the original recovery banner and above every planning control."""
	_shield = CanvasLayer.new()
	_shield.layer = 62
	add_child(_shield)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.visible = false


func _dismiss_popups() -> void:
	"""Owned popup Windows cannot remain above a modal or survive the planning view's close."""
	if _mode == null or _mode._editor == null: return
	for option: OptionButton in [_mode._floor, _mode._purpose, _mode._editor._shape]:
		if is_instance_valid(option): option.get_popup().hide()


func _refresh_modal() -> void:
	"""Take GUI ownership once per transition; no missed key release can leak through the banner."""
	if not _active: return
	var blocked: bool = _blocked()
	if blocked == _modal_blocked: return
	_modal_blocked = blocked
	_shield.visible = blocked
	if blocked:
		_dismiss_popups()
		get_viewport().gui_release_focus()


func _input(event: InputEvent) -> void:
	"""Keep focus/navigation inside the modal while its original banner owns acknowledgement."""
	_refresh_modal()
	if not _active or not _modal_blocked or event is InputEventMouse: return
	if event is InputEventKey and _stall.call(&"is_shown") and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	"""Only presentation is updated here; actual construction remains on the host's fixed tick."""
	if not _active: return
	if _mode._live_session() == null or _view.owner_refusal() != &"":
		close()
		return
	_hold_legacy()
	_refresh_modal()
	_refresh_in -= delta
	if _refresh_in <= 0:
		_refresh_in = 0.2
		_refresh_toolbar()


func _unhandled_key_input(event: InputEvent) -> void:
	"""Use the existing time actions only after GUI controls decline the key."""
	if not _active or _blocked(): return
	if event.is_action_pressed(&"time_pause"):
		GameManager.toggle_pause()
	else:
		var matched: bool = false
		for speed: int in [1, 2, 4]:
			if event.is_action_pressed(StringName("time_speed_%d" % speed)):
				GameManager.set_speed(speed)
				matched = true
		if not matched: return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	"""After the dirt tool has cancelled a captured gesture, the next Escape closes without discarding."""
	if _active and not _blocked() and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build_toolbar() -> void:
	"""Actual resources and existing clock commands stay available above the world drawing surface."""
	_toolbar = CanvasLayer.new()
	_toolbar.layer = 61
	add_child(_toolbar)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme = THEME
	panel.theme_type_variation = &"WoodlandPanel"
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size.x = 380
	_toolbar.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	_stock = RoomMode._label("", 14)
	column.add_child(_stock)
	_clock_words = RoomMode._label("", 14)
	column.add_child(_clock_words)
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	_pause = RoomMode._button("Pause", _toggle_pause)
	buttons.add_child(_pause)
	for speed: int in [1, 2, 4]: buttons.add_child(RoomMode._button("%dx" % speed, _set_speed.bind(speed)))
	_toolbar.visible = false


func _refresh_toolbar() -> void:
	"""Read the original economy and clock, never the legacy demonstration's private goods/calendar."""
	_stock.text = "Settlement stores · Wood %d U · Stone %d U" % [EconomySystem.stock_units(&"wood"), EconomySystem.stock_units(&"stone")]
	_clock_words.text = "%s · %dx" % [GameManager.get_calendar_text(), GameManager.get_speed()]
	_pause.text = "Resume" if GameManager.clock().has_pause_reason(Clock.PLAYER) else "Pause"
	_pause.tooltip_text = "Player pause only. %s" % ", ".join(GameManager.get_pause_reason_names())


func _toggle_pause() -> void:
	"""Only a player's explicit button click changes their pause reason."""
	if _active and not _blocked(): GameManager.toggle_pause()


func _set_speed(speed: int) -> void:
	"""Request an existing allowed speed through the same scheduler owner as the HUD."""
	if _active and not _blocked(): GameManager.set_speed(speed)


func _drop_view() -> void:
	"""After close or failed mount, release this presentation without clearing canonical construction."""
	for child: Node in [_mode, _view, _rig, _sun, _toolbar, _shield]:
		if is_instance_valid(child): child.free()
	_mode = null
	_view = null
	_rig = null
	_sun = null
	_toolbar = null
	_shield = null
	_framed = false


func _exit_tree() -> void:
	"""Restore surviving legacy widgets before this presentation is removed."""
	close()
