extends "res://test/live/demo_input_live.gd"
## Real village, real dirt/camera/input. Construction remains unbound: this qualifies only UG19/D29.

const WorldTool := preload("res://demo/burrow/modular_world_tool.gd")
const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const WoodlandSkin := preload("res://demo/ui/woodland_skin.gd")

var _world_tool: WorldTool = null
var _editor: Editor = null
var _panel: PanelContainer = null
var _tunnels: Node3D = null
var _retained: PackedInt32Array = PackedInt32Array()
var _datum: Vector3i = Vector3i.ZERO
var _ui: CanvasLayer = null
var _old_templates: PackedByteArray = PackedByteArray()


func _initialize() -> void:
	"""Reuse real scene boot and evidence helpers, replacing only the bounded walkthrough steps."""
	super()
	_steps = [_setup_world_editor, _paint_on_dirt, _inspect_world_alignment, _camera_does_not_paint,
		_gui_does_not_paint, _release_over_gui, _escape_only_cancels_stroke, _level_switch,
		_return_to_level, _modal_cancels_stroke, _close_modal, _lost_focus_cancels, _no_free_order, _finish_capture]


func _setup_world_editor() -> void:
	"""Mount the new tool in the actual village. Legacy level heights are fixture inputs, not new rules."""
	_tunnels = _command().call(&"tunnels") as Node3D
	_old_templates = _tunnels.network.rooms.template.duplicate()
	_key(KEY_U)
	var rig: Node3D = _village.get("_camera")
	rig.call(&"centre_on", Vector3.ZERO)
	rig.call(&"snap")
	_datum = Vector3i(1024, Rules.to_u(Layers.floor_y(1)), -2048)
	_build_panel()
	_world_tool = WorldTool.new()
	_village.add_child(_world_tool)
	_check("world binding uses existing camera and selected floor", _world_tool.configure(_tunnels._camera,
		_editor, _datum, Layers.marks(1), _input_blocked, _view_context) == &"")
	_world_tool.set_active(true)
	_check("real underground dirt is visible", _tunnels.view.on)
	_check("world preview is not a drawing canvas", _world_tool.overlay is Node3D)


func _build_panel() -> void:
	"""Use a narrow side inspector; all drawing events go into the real world behind it."""
	_ui = CanvasLayer.new()
	_ui.layer = 60
	_village.add_child(_ui)
	_panel = PanelContainer.new()
	_panel.theme = load("res://ui/theme/woodland_theme.tres") as Theme
	_panel.theme_type_variation = &"WoodlandPanel"
	_panel.position = Vector2(940, 92)
	_panel.size = Vector2(324, 540)
	_ui.add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	_panel.add_child(margin)
	var draft: Draft = Draft.new()
	draft.configure(2, 1, 256, 16384, Rect2i(-160, -160, 320, 320), false)
	_editor = Editor.new()
	_editor.configure(draft, 8)
	margin.add_child(_editor)
	var context: Label = Label.new()
	context.text = "World drawing test\nConstruction binding in progress"
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(context)
	WoodlandSkin.apply(_panel)
	_gate().add_region("Room drawing", [_panel])


func _input_blocked() -> bool:
	"""Read the actual village modal owner rather than a test-provided placement permission."""
	return _gate().modal_open()


func _view_context() -> Vector3i:
	"""Read the actual view synchronously, including changes between two events in the same frame."""
	return Vector3i(_tunnels.view.level, Rules.to_u(_tunnels.view.pick_y()), 1 if _tunnels.view.on else 0)


func _paint_on_dirt() -> void:
	"""Drag opposite room corners on dirt using the same events as a real pointer."""
	_editor.select_tool(Draft.ROUNDED, false, 3)
	_draw(Vector2(730, 482), Vector2(845, 558))
	_retained = _editor.draft.visible_cells()
	_check("drag paints a retained room at the world location", not _retained.is_empty(), str(_editor.draft.preview_error()) + " / " + str(_editor.draft.confirmation_error()) + " / " + str(_world_tool._view_matches))
	_check("release ends the gesture without excavation", not _editor.draft.drawing())
	_check("selected room purpose stays Kitchen", _editor.draft.snapshot().room_type == 2)
	_check("room confirm awaits the actual construction owner", not _editor.request_confirmation())
	_capture("direct_dirt_room_plan")


func _inspect_world_alignment() -> void:
	"""World vertices, the shader grid and input all use the same nonzero integer datum."""
	_check("inspector fits1280x720", Rect2(Vector2.ZERO, Vector2(_size)).encloses(_panel.get_global_rect()))
	_check("preview contains exactly the retained cells", _world_tool.overlay._cells == _retained)
	var cell: Vector2i = Vector2i(_retained[0], _retained[1]) if not _retained.is_empty() else Vector2i.ZERO
	var corner: Vector3 = _world_tool.overlay.world_corner(cell)
	var camera: Camera3D = _tunnels._camera
	var hit: WorldTool.Pick = _world_tool.pick(camera.unproject_position(corner + Vector3(0.125, 0, 0.125)))
	_check("rendered cell picks back to the same integer cell", hit.ok and hit.cell == cell)
	_check("same floor height for cap picking and overlay", is_equal_approx(corner.y, _tunnels.view.pick_y()))
	_check("grid datum includes world origin offset", _world_tool.datum_u() == _datum)


func _camera_does_not_paint() -> void:
	"""Camera pan/zoom never rebuild or move an already drawn world footprint."""
	var draws: int = _world_tool.overlay.rebuilds
	var rig: Node3D = _village.get("_camera")
	var focus: Vector3 = rig.call(&"focus")
	rig.call(&"centre_on", focus + Vector3(2, 0, 1))
	rig.call(&"snap")
	_check("camera movement preserves room cells", _editor.draft.visible_cells() == _retained)
	_check("camera movement reuses preview geometry", _world_tool.overlay.rebuilds == draws)
	_capture("direct_dirt_camera_pan")


func _gui_does_not_paint() -> void:
	"""A click on the inspector cannot begin a world gesture or alter the room."""
	_click(_centre(_editor._erase))
	_check("GUI click does not draw a room cell", _editor.draft.visible_cells() == _retained)
	_check("GUI click leaves no captured stroke", not _editor.draft.drawing())
	_editor.select_tool(Draft.RECTANGLE, false, 0)


func _release_over_gui() -> void:
	"""A world drag released over Confirm ends at its last world cell and cannot click Confirm."""
	_press(Vector2(730, 482))
	_check("world press captures the gesture", _editor.draft.drawing())
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.position = _centre(_editor._confirm)
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release)
	_check("release over GUI clears capture", not _editor.draft.drawing())
	_check("release over GUI cannot discard the retained room", not _editor.draft.visible_cells().is_empty())
	_retained = _editor.draft.visible_cells()


func _escape_only_cancels_stroke() -> void:
	"""Escape cancels one transient gesture, preserving earlier painting."""
	_press(Vector2(718, 478))
	_key(KEY_ESCAPE)
	_check("Escape cancels the stroke", not _editor.draft.drawing())
	_check("Escape preserves completed strokes", _editor.draft.visible_cells() == _retained)
	_check("Escape is not also the pause menu", not _menu().visible)


func _level_switch() -> void:
	"""The real level changes before another same-frame click; no paint lands on the wrong floor."""
	_press(Vector2(718, 478))
	_key(KEY_PAGEDOWN)
	_click(Vector2(740, 480))
	_check("actual view reaches lower level", _tunnels.view.level == 2)
	_check("level switch cancels a transient stroke", not _editor.draft.drawing())
	_check("level switch preserves existing plan", _editor.draft.visible_cells() == _retained)
	_check("other floor cannot show this room preview", not _world_tool.overlay.visible)
	_capture("direct_dirt_other_level")


func _return_to_level() -> void:
	"""Returning to the original floor restores the plan at its original world coordinates."""
	_key(KEY_PAGEUP)
	_world_tool._process(0)
	_check("returning shows the original room", _world_tool.overlay.visible)
	_check("floor switch never changes room identity or datum", _editor.draft.snapshot().level == 1 and _world_tool.datum_u() == _datum)


func _modal_cancels_stroke() -> void:
	"""The actual pantry modal interrupts painting without changing accepted cells."""
	_press(Vector2(718, 478))
	_key(KEY_K)
	_click(Vector2(750, 480))
	_world_tool._process(0)
	_check("Pantry modal owns input", _gate().modal_open())
	_check("modal opening cancels gesture", not _editor.draft.drawing())
	_check("modal clicks cannot paint on dirt", _editor.draft.visible_cells() == _retained)


func _close_modal() -> void:
	"""One Escape goes through the existing modal dismissal stack."""
	_key(KEY_ESCAPE)
	_check("modal closes normally", not _gate().modal_open())
	_check("modal dismissal preserves room plan", _editor.draft.visible_cells() == _retained)


func _lost_focus_cancels() -> void:
	"""Losing application focus cannot leave a held stroke waiting to commit on return."""
	_press(Vector2(718, 478))
	_world_tool.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus loss cancels gesture", not _editor.draft.drawing())
	_check("focus loss preserves prior strokes", _editor.draft.visible_cells() == _retained)


func _no_free_order() -> void:
	"""A drawn room remains a plan until the real coordinator is connected and accepts it."""
	_check("no fake submitter is installed", not _editor.request_confirmation())
	_check("old template graph did not allocate the arbitrary room", _tunnels.network.rooms.template == _old_templates)
	_capture("direct_dirt_preserved_plan")


func _finish_capture() -> void:
	"""Allow the inherited loop to flush the final requested image before it terminates."""
	_check("all pending captures completed", _pending_capture.is_empty())


func _save_capture() -> void:
	"""Native evidence must actually save, not merely exit0 after printing an engine error."""
	var error: Error = DirAccess.make_dir_recursive_absolute(_capture_dir)
	if error == OK:
		error = root.get_texture().get_image().save_png(_capture_dir.path_join(
			"%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_check("save capture " + _pending_capture, error == OK)
	_pending_capture = ""
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _press(at: Vector2) -> void:
	"""A real left press with no test-side grid coordinate injection."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


func _draw(from: Vector2, to: Vector2) -> void:
	"""Pointer deltas matter: camera motion without pointer motion is deliberately not a stroke."""
	_press(from)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.position = to
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release)
