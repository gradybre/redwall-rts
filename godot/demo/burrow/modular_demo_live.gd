extends Node
## Real demo/Viewport input witness. No room, access endpoint, material or worker is seeded.

const SceneMode := preload("res://demo/burrow/modular_demo_mode.gd")
const TunnelPanel := preload("res://demo/tunnel/tunnel_panel.gd")
const Zone := preload("res://demo/ui/demo_detail_zone.gd")
var _village: Node = null
var _scene: SceneMode = null
var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _out: String = ""
var _cells: PackedInt32Array = PackedInt32Array()
var _state_before: Array[PackedByteArray] = []
var _pause_before: int = 0
var _speed_before: int = 0
var _old_pose: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	"""Normal scene startup ensures the actual autoloads exist before the demo compiles."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.gui_embed_subwindows = true
	call_deferred(&"_run")


func _process(_delta: float) -> void:
	"""The headless display server otherwise reduces its root to64×64 after startup."""
	get_tree().root.size = Vector2i(1280, 720)


func _run() -> void:
	"""Boot the actual scene, then use the same panel, pointer and keyboard paths as the player."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	add_child(_village)
	await _frames(60)
	_check(_village.prewarm().frames_left < 0, "actual demo prewarm completed")
	GameManager.pause_game()
	await _frames(2)
	_scene = _village.get("_modular_mode") as SceneMode
	_check(_scene != null, "real demo mounts planning entry")
	if _scene == null:
		_finish()
		return
	await _open_from_panel()
	if not _scene.is_active():
		_finish()
		return
	await _draw_and_check()
	await _floor_and_refusal()
	await _close_and_reopen()
	await _modal_stall()
	await _replace_world()
	_finish()


func _open_from_panel() -> void:
	"""The actual Tunnels tab and new button open the original settlement's inspector."""
	var zone: Zone = _village.get("_zone") as Zone
	_click(_centre(zone._tabs[Zone.PANEL_TUNNELS]))
	await _frames(2)
	var panel: TunnelPanel = _village.call(&"_tunnel_tool").ext.panel
	var button: Button = panel._buttons[TunnelPanel.ACTION_MODULAR_ROOM]
	_check(button.is_visible_in_tree(), "entry button visible in real Tunnels panel")
	_check(_onscreen(button), "entry button fits1280×720")
	_state_before = _state()
	_pause_before = GameManager.clock().pause_mask()
	_speed_before = GameManager.clock().requested_speed()
	_old_pose = _scene._old_rig.transform
	_click(_centre(button))
	await _frames(3)
	_check(_scene.is_active(), "real click opens actual planning")
	_check(_same_state(), "opening changes no canonical gameplay state")
	_check(GameManager.clock().pause_mask() == _pause_before, "opening preserves pause reasons")
	_check(GameManager.clock().requested_speed() == _speed_before, "opening preserves requested speed")
	if not _scene.is_active(): return
	_check(get_viewport().get_camera_3d() == _scene._rig.camera(), "planning camera is current")
	_check(_scene._mode._world == SettlementSystem.world_ref(), "original full World identity")
	_check(_scene._mode._view_floor == -4608, "authored original first floor")
	_check(_onscreen(_scene._mode._panel), "scrolling inspector fits1280×720")
	await _capture("planning-open")


func _draw_and_check() -> void:
	"""Paint a rectangle on actual dirt, then ensure the inspector intercepts its own clicks."""
	var camera: Camera3D = _scene._rig.camera()
	var first: Vector2 = camera.unproject_position(Vector3(122, -4.5, 124))
	var last: Vector2 = camera.unproject_position(Vector3(128, -4.5, 128))
	_drag(first, last)
	await _frames(2)
	_cells = _scene._mode._editor.draft.visible_cells()
	_check(not _cells.is_empty(), "Viewport drag paints actual dirt")
	_check(_scene._mode._editor.draft.confirmation_error() == &"", "drawn room is a connected valid draft")
	_check(_same_state(), "unconfirmed drawing changes no canonical state")
	_click(_scene._mode._panel.global_position + Vector2(18, 18))
	await _frames(2)
	_check(_scene._mode._editor.draft.visible_cells() == _cells, "GUI click cannot paint through inspector")
	await _capture("planning-drawing")


func _floor_and_refusal() -> void:
	"""Real dropdown keys inspect another floor without moving the plan, then a real confirm click refuses."""
	await _choose(_scene._mode._floor, 2)
	_check(_scene._mode._view_level == 2, "floor dropdown selects next level")
	_check(_scene._view._floor_u == -9728, "visible dirt uses exact next floor")
	_check(_scene._rig.focus().y == -9.5, "camera focus follows actual selected floor")
	_check(_scene._mode._editor.draft._level == 1, "draft keeps its own floor")
	_click(Vector2(600, 420))
	_check(_scene._mode._editor.draft.visible_cells() == _cells, "another floor cannot edit retained plan")
	await _capture("planning-other-floor")
	await _choose(_scene._mode._floor, 1)
	_check(_scene._mode._tool._can_draw(), "returning restores drawing on original floor")
	var confirm: Button = _scene._mode._editor._confirm
	var scroll: ScrollContainer = _scene._mode._column.get_parent() as ScrollContainer
	scroll.ensure_control_visible(confirm)
	await _frames(2)
	_check(_onscreen(confirm), "confirm reachable inside scroll panel")
	_click(_centre(confirm))
	await _frames(2)
	_check(not _scene._mode._editor._last_refusal.is_empty(), "missing access produces a visible refusal")
	_check(_scene._mode._editor.draft.visible_cells() == _cells, "refusal preserves exact draft")
	_check(_same_state(), "refusal spends no resources and creates no work")
	await _capture("planning-refused")


func _close_and_reopen() -> void:
	"""Escape cancels a held stroke first, then leaves planning; reentry retains cells and camera controls."""
	get_viewport().gui_release_focus()
	_pointer(Vector2(550, 390), true)
	_check(_scene._mode._tool._captured, "world press captures a stroke")
	_key(KEY_ESCAPE)
	_check(_scene.is_active() and not _scene._mode._tool._captured, "first Escape cancels only active gesture")
	_check(_scene._mode._editor.draft.visible_cells() == _cells, "cancelled gesture leaves old draft")
	_key(KEY_ESCAPE)
	_check(not _scene.is_active(), "second Escape returns to village")
	_check(get_viewport().get_camera_3d() == _scene._old_rig.camera(), "original camera restored")
	_check(_scene._old_rig.transform == _old_pose, "original camera pose retained")
	_check(_scene._rig.process_mode == Node.PROCESS_MODE_DISABLED, "hidden planning camera cannot consume input")
	_check(GameManager.clock().pause_mask() == _pause_before, "close preserves pause reasons")
	await _frames(2)
	var panel: TunnelPanel = _village.call(&"_tunnel_tool").ext.panel
	_check(panel.visible, "original Tunnels panel restored")
	_click(_centre(panel._buttons[TunnelPanel.ACTION_MODULAR_ROOM]))
	await _frames(2)
	_check(_scene.is_active(), "same real entry reopens planning")
	_check(_scene._mode._editor.draft.visible_cells() == _cells, "reopen preserves exact draft")
	_check(_same_state(), "complete inspection cycle is canonical read-only")
	_scene.close()


func _modal_stall() -> void:
	"""A real clock overload takes ownership of held keys, open popup Windows and GUI clicks."""
	var panel: TunnelPanel = _village.call(&"_tunnel_tool").ext.panel
	_click(_centre(panel._buttons[TunnelPanel.ACTION_MODULAR_ROOM]))
	await _frames(2)
	_check(_scene.is_active(), "planning reopened for live stall")
	get_viewport().gui_release_focus()
	var before: Vector3 = _scene._rig.focus()
	_hold_key(KEY_W, true)
	await _frames(3)
	_check(_scene._rig.focus() != before, "held camera key moves before stall")
	_click(_centre(_scene._mode._floor))
	_check(_scene._mode._floor.get_popup().visible, "floor popup is open before stall")
	var pose: Transform3D = _scene._rig.transform
	GameManager.resume_game()
	GameManager.advance_host_time(1200000)
	GameManager.advance_host_time(0)
	_check(GameManager.clock().has_pause_reason(SceneMode.Clock.CRITICAL), "actual host debt raises critical pause")
	_scene._stall.call(&"refresh")
	await _frames(3)
	_check(_scene._stall.call(&"is_shown") and _scene._shield.visible, "real banner and input shield are visible")
	_check(_scene._stall.layer > _scene._shield.layer and _scene._shield.layer > _scene._toolbar.layer,
		"banner stays above shield and planning controls")
	_check(not _scene._mode._floor.get_popup().visible, "stall dismisses the already open popup")
	_check(_scene._rig._held.count(1) == 0 and not _scene._rig.is_drag_turning(), "stall clears held camera controls")
	await _blocked_camera_inputs(pose)


func _blocked_camera_inputs(pose: Transform3D) -> void:
	"""New keys and a middle drag cannot restart the blocked rig; only actual banner acknowledgement resumes."""
	_key(KEY_E)
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_MIDDLE
	button.position = Vector2(550, 400)
	button.pressed = true
	get_viewport().push_input(button)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(640, 450)
	motion.relative = Vector2(90, 50)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	get_viewport().push_input(motion)
	await _frames(3)
	_check(_scene._rig.transform == pose, "held key and new drag cannot move camera during stall")
	_click(_centre(_scene._mode._floor))
	_check(not _scene._mode._floor.get_popup().visible, "shield prevents a new planning dropdown behind banner")
	await _blocked_keyboard_inputs()
	await _capture("planning-stalled")
	_key(KEY_ENTER)
	GameManager.pause_game()
	await _frames(3)
	_check(not GameManager.clock().has_pause_reason(SceneMode.Clock.CRITICAL) and not _scene._shield.visible,
		"Enter acknowledges actual stall and releases shield")
	_check(_scene._rig.transform == pose, "old held key stays cleared after acknowledgement")
	_hold_key(KEY_W, false)
	var original_layer: int = _scene._stall_layer
	_scene.close()
	_check(_scene._stall.layer == original_layer, "close restores original banner layer")


func _blocked_keyboard_inputs() -> void:
	"""Real focus navigation cannot reach or change any planning field behind the stall banner."""
	var old_level: int = _scene._mode._view_level
	var old_purpose: int = _scene._mode._purpose.selected
	var old_shape: int = _scene._mode._editor._shape.selected
	var stayed_in_modal: bool = true
	for backwards: bool in [false, true]:
		for _press: int in 32:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = KEY_TAB
			event.shift_pressed = backwards
			event.pressed = true
			get_viewport().push_input(event)
			event.pressed = false
			get_viewport().push_input(event)
			var focus: Control = get_viewport().gui_get_focus_owner()
			stayed_in_modal = stayed_in_modal and (focus == null or _scene._stall.is_ancestor_of(focus))
	for key: Key in [KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_LEFT, KEY_4, KEY_ESCAPE]: _key(key)
	await _frames(2)
	_check(stayed_in_modal, "Tab and Shift-Tab cannot focus controls behind modal")
	_check(_scene._mode._view_level == old_level and _scene._mode._purpose.selected == old_purpose \
		and _scene._mode._editor._shape.selected == old_shape, "blocked keyboard cannot change planning fields")
	_check(_scene._mode._editor.draft.visible_cells() == _cells and _scene.is_active(),
		"blocked keyboard retains draft and planning view")
	_check(GameManager.clock().has_pause_reason(SceneMode.Clock.CRITICAL), "navigation cannot acknowledge critical pause")


func _replace_world() -> void:
	"""The actual UI Create command retires the old view; reopening binds only the new original World."""
	var panel: TunnelPanel = _village.call(&"_tunnel_tool").ext.panel
	_click(_centre(panel._buttons[TunnelPanel.ACTION_MODULAR_ROOM]))
	await _frames(2)
	var old_world: Vector2i = _scene._mode._world
	var old_popup: PopupMenu = _scene._mode._purpose.get_popup()
	_click(_centre(_scene._mode._purpose))
	_check(old_popup.visible, "room purpose popup is open before actual World reset")
	UIManager.world_session().set_seed(20261005)
	_check(UIManager.create_world(), "actual UI World Create succeeds")
	_check(SettlementSystem.world_ref() != old_world, "new World has a distinct full identity")
	await _frames(3)
	_check(not _scene.is_active(), "World retirement closes the active planning view")
	_check(not old_popup.visible, "World retirement dismisses the old popup")
	_click(_centre(panel._buttons[TunnelPanel.ACTION_MODULAR_ROOM]))
	await _frames(3)
	_check(_scene.is_active(), "real planning button reopens after World Create")
	_check(_scene._mode._world == SettlementSystem.world_ref() and _scene._mode._world != old_world,
		"reopened view binds only the newly created original World")
	_check(_scene._mode._editor.draft.visible_cells().is_empty(), "old World's draft cannot be adopted by its replacement")
	var actual: SceneMode.Session = SettlementSystem.underground_session()
	_check(actual.room_orders() != null and actual.world_route_provider() != null,
		"new World composes its actual room and route owners on reopen")
	_scene.close()


func _hold_key(key: Key, down: bool) -> void:
	"""Dispatch a normal key transition while allowing its release to arrive after a modal."""
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	get_viewport().push_input(event)


func _choose(option: OptionButton, selected: int) -> void:
	"""Open the real dropdown and use normal navigation keys, rather than emitting its signal."""
	_click(_centre(option))
	await _frames(1)
	var popup: PopupMenu = option.get_popup()
	print("MODULAR-INPUT before selected=%d popup=%s focus=%d" % [option.selected, popup.visible, popup.get_focused_item()])
	for attempt: int in range(popup.item_count + 1):
		if popup.get_focused_item() == selected: break
		_key(KEY_DOWN)
	print("MODULAR-INPUT navigate selected=%d popup=%s focus=%d" % [option.selected, popup.visible, popup.get_focused_item()])
	_key(KEY_ENTER)
	await _frames(2)
	print("MODULAR-INPUT after selected=%d popup=%s floor=%d" % [option.selected, popup.visible, _scene._mode._view_level])


func _state() -> Array[PackedByteArray]:
	"""Compare canonical stores independently of presentation state and labels."""
	return [SettlementSystem.directory().state_bytes(), SettlementSystem.inventory().state_bytes(),
		SettlementSystem.residents().state_bytes(), SettlementSystem.jobs().state_bytes(),
		SettlementSystem.transforms().state_bytes(), SettlementSystem.construction().state_bytes(),
		SettlementSystem.reservations().state_bytes()]


func _same_state() -> bool:
	"""Name the actual changed store and first byte; never hide a failing conservation check."""
	var after: Array[PackedByteArray] = _state()
	var same: bool = true
	for index: int in after.size():
		if after[index] == _state_before[index]: continue
		same = false
		var at: int = 0
		while at < mini(after[index].size(), _state_before[index].size()) and after[index][at] == _state_before[index][at]: at += 1
		print("MODULAR-STATE-DIFF store=%d before=%d after=%d first=%d" % [index, _state_before[index].size(), after[index].size(), at])
	return same


func _frames(count: int) -> void:
	"""Allow real queued GUI layout and input handover to settle."""
	for frame: int in count: await get_tree().process_frame


func _capture(title: String) -> void:
	"""Capture the actual default backend while the player's explicit pause prevents readback clock debt."""
	if _out.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	_check(picture.get_size() == Vector2i(1280, 720), "native capture size: " + title)
	_check(picture.save_png(_out.path_join(title + ".png")) == OK, "native capture saved: " + title)


func _check(condition: bool, words: String) -> void:
	"""Print every actual result; zero exit alone never certifies this harness."""
	_checks += 1
	if not condition: _failures.append(words)
	print("MODULAR-DEMO %s: %s" % ["PASS" if condition else "FAIL", words])


func _finish() -> void:
	"""Leave cleanup to normal scene shutdown, exposing any actual leak in the child log."""
	if not _out.is_empty():
		var file: FileAccess = FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": _checks, "failures": _failures,
			"driver": RenderingServer.get_current_rendering_driver_name(), "backend": RenderingServer.get_current_rendering_method(),
			"playable_room_complete": false}, "  "))
	print("MODULAR-DEMO-SUMMARY %d checks / %d failures" % [_checks, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _onscreen(control: Control) -> bool:
	"""Every corner must be inside the actual720p viewport; clipped scroll content is checked after scrolling."""
	return Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(control.get_global_rect())


func _centre(control: Control) -> Vector2:
	"""The current actual canvas-space centre, including scroll offsets."""
	return control.get_global_transform_with_canvas() * (control.size / 2)


func _click(at: Vector2) -> void:
	"""Use Viewport input dispatch, including GUI consumption and unhandled world input."""
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion)
	_pointer(at, true)
	_pointer(at, false)


func _pointer(at: Vector2, down: bool) -> void:
	"""An actual left button transition; no script action or editor method is invoked."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(event)


func _drag(first: Vector2, last: Vector2) -> void:
	"""Relative motion is explicit: a stationary pointer is never treated as a painting move."""
	_pointer(first, true)
	var previous: Vector2 = first
	for index: int in range(1, 5):
		var event: InputEventMouseMotion = InputEventMouseMotion.new()
		event.position = first.lerp(last, float(index) / 4)
		event.relative = event.position - previous
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(event)
		previous = event.position
	_pointer(last, false)


func _key(key: Key, target: Viewport = null) -> void:
	"""Normal key press/release follows the actual GUI and unhandled-event ordering."""
	if target == null: target = get_viewport()
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		target.push_input(event)
