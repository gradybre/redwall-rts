extends SceneTree
## Native component fixture, NOT the village or excavation evidence. Uses real Viewport input.
## Run with -- --capture <directory> for 1280x720 evidence; no simulation owner is installed here.

const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const WoodlandSkin := preload("res://demo/ui/woodland_skin.gd")

class Board extends Control:
	var editor: Editor = null
	var cells: PackedInt32Array = PackedInt32Array()
	var loops: Array[PackedInt32Array] = []
	const CELL_PX: int = 20

	func refresh(value: PackedInt32Array, _revision: int) -> void:
		"""Render the exact cached preview boundary in this flat picking fixture."""
		cells = value
		loops = Footprint.boundary_loops(cells)
		queue_redraw()

	func _draw() -> void:
		"""Use one grid for the floor fill, boundary and pointer adapter."""
		draw_rect(Rect2(Vector2.ZERO, size), Palette.DEEP_SHADE)
		for x: int in 41:
			draw_line(Vector2(x * CELL_PX, 0), Vector2(x * CELL_PX, 520), Color(0.4, 0.5, 0.4, 0.18))
		for z: int in 27:
			draw_line(Vector2(0, z * CELL_PX), Vector2(800, z * CELL_PX), Color(0.4, 0.5, 0.4, 0.18))
		for index: int in range(0, cells.size(), 2):
			draw_rect(Rect2(cells[index] * CELL_PX, cells[index + 1] * CELL_PX, CELL_PX, CELL_PX), Color(0.52, 0.7, 0.66, 0.35))
		for loop: PackedInt32Array in loops:
			var points: PackedVector2Array = PackedVector2Array()
			for index: int in range(0, loop.size(), 2):
				points.append(Vector2(loop[index], loop[index + 1]) * CELL_PX)
			draw_polyline(points, Palette.CREAM, 2.0, true)

	func _gui_input(event: InputEvent) -> void:
		"""The fixture's own canvas handles world gestures; inspector clicks never enter it."""
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				editor.world_press(_cell(event.position))
			else:
				editor.world_release()
			accept_event()
		elif event is InputEventMouseMotion and editor.draft.drawing():
			editor.world_motion(_cell(event.position))
			accept_event()

	static func _cell(at: Vector2) -> Vector2i:
		"""Picking converts presentation pixels to explicit grid coordinates once."""
		return Vector2i(floori(at.x / CELL_PX), floori(at.y / CELL_PX))

var _ui: Control = null
var _panel: PanelContainer = null
var _editor: Editor = null
var _board: Board = null
var _steps: Array[Callable] = []
var _frames: int = 0
var _checks: int = 0
var _failures: int = 0
var _submissions: int = 0
var _reject: bool = true
var _capture_dir: String = ""
var _pending_capture: String = ""


func _initialize() -> void:
	"""Build one isolated component scene and a bounded real-input sequence."""
	root.size = Vector2i(1280, 720)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size() - 1:
		if args[index] == "--capture":
			_capture_dir = args[index + 1]
	_build()
	_steps = [_rounded_room, _history, _outside_release, _route, _fit, _invalid_island,
		_repair, _refused_order, _fit, _accepted_order]


func _process(_delta: float) -> bool:
	"""Allow layout and rendering between each real-input step, then terminate our own process."""
	root.size = Vector2i(1280, 720)
	_frames += 1
	if _frames % 4 != 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		print("MODULAR-EDITOR-SUMMARY %d checks, %d failures" % [_checks, _failures])
		_ui.queue_free()
		quit(1 if _failures else 0)
		return true
	_steps.pop_front().call()
	return false


func _build() -> void:
	"""Reuse the demo's existing woodland skin; the separate fixture is visibly labelled."""
	_ui = Control.new()
	_ui.theme = load("res://ui/theme/woodland_theme.tres") as Theme
	root.add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Palette.DEEP_SHADE
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(backdrop)
	_label("Underground room drawing", Vector2(32, 20), 26)
	_label("COMPONENT TEST · synthetic grid · no workers, materials or excavation", Vector2(32, 59), 16)
	_label("Rounded rooms, adjoining wings and bent tunnels share one blueprint.", Vector2(32, 650), 17)
	_board = Board.new()
	_board.position = Vector2(32, 108)
	_board.size = Vector2(800, 520)
	_ui.add_child(_board)
	_build_inspector()
	WoodlandSkin.apply(_ui)


func _build_inspector() -> void:
	"""Constrain the real editor to the same narrow space used at the minimum viewport."""
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WoodlandPanel"
	_panel.position = Vector2(900, 96)
	_panel.size = Vector2(348, 530)
	_ui.add_child(_panel)
	var margins: MarginContainer = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margins.add_theme_constant_override(side, 12)
	_panel.add_child(margins)
	var draft: Draft = Draft.new()
	draft.configure(2, 1, 256, 1040, Rect2i(0, 0, 40, 26), false)
	_editor = Editor.new()
	_editor.configure(draft, 6)
	margins.add_child(_editor)
	_board.editor = _editor
	_editor.preview_changed.connect(_board.refresh)
	_editor.bind_confirmation(_check_site, _submit)


func _label(text: String, at: Vector2, font_size: int) -> void:
	"""Place fixture context outside the editor so it cannot be mistaken for finished gameplay."""
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Palette.CREAM)
	_ui.add_child(label)


func _rounded_room() -> void:
	"""Real press, movement and release keep an editable rounded footprint without orders."""
	_editor.select_tool(Draft.ROUNDED, false, 3)
	_drag([Vector2i(8, 8), Vector2i(22, 18)])
	_check("rounded drag retains a connected room", _editor.draft.confirmation_error() == &"")
	_check("release submits no construction", _submissions == 0)
	_check("rounded corner is outside floor", not Footprint.contains_cell(_editor.draft.visible_cells(), 8, 8))


func _history() -> void:
	"""Actual GUI button clicks reach history without falling through to the drawing canvas."""
	_click(_button("Undo"))
	_check("Undo click clears the first stroke", _editor.draft.visible_cells().is_empty())
	_click(_button("Redo"))
	_check("Redo click restores the room", not _editor.draft.visible_cells().is_empty())
	_check("GUI clicks start no world stroke", not _editor.draft.drawing())


func _route() -> void:
	"""Connect a bent, three-cell-wide route to the retained rounded chamber."""
	_editor.select_tool(Draft.TUNNEL, false, 1)
	_drag([Vector2i(14, 8), Vector2i(14, 3), Vector2i(30, 3)])
	_check("bent tunnel joins room", _editor.draft.confirmation_error() == &"")
	_check("route reaches end", Footprint.contains_cell(_editor.draft.visible_cells(), 30, 3))
	_check("route preserves concave exterior", not Footprint.contains_cell(_editor.draft.visible_cells(), 27, 12))
	_pending_capture = "rounded_room_and_bent_tunnel"


func _outside_release() -> void:
	"""Viewport mouse capture ends a canvas gesture even when release falls over the inspector."""
	var before: Dictionary = _editor.draft.snapshot()
	_pointer(_at(Vector2i(14, 13)), true)
	_pointer(_button("Undo").get_global_rect().get_center(), false)
	_check("release outside canvas ends stroke", not _editor.draft.drawing())
	_check("outside release does not click Undo", _editor.draft.snapshot() == before)


func _fit() -> void:
	"""Check the complete live subtree against its actual 1280x720 inspector bounds."""
	_check("panel fits minimum viewport", Rect2(0, 0, 1280, 720).encloses(_panel.get_global_rect()))
	var pending: Array[Node] = [_editor]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control and node.is_visible_in_tree():
			_check("control fits inspector: %s" % node.get_class(), _panel.get_global_rect().grow(1).encloses(node.get_global_rect()))
		for child: Node in node.get_children():
			if not child is Popup:
				pending.append(child)


func _invalid_island() -> void:
	"""A disconnected edit stays visible and repairable, with written reasons and disabled order."""
	_editor.select_tool(Draft.RECTANGLE, false, 0)
	_drag([Vector2i(37, 23), Vector2i(38, 24)])
	_check("island refuses confirmation", _editor.draft.confirmation_error() == Footprint.REFUSE_DISCONNECTED)
	_click(_button("Confirm room"))
	_check("disabled Confirm submits nothing", _submissions == 0)
	_pending_capture = "disconnected_refusal"


func _repair() -> void:
	"""Undo repairs the geometry through actual GUI input."""
	_click(_button("Undo"))
	_check("Undo repairs disconnected paint", _editor.draft.confirmation_error() == &"")
	_check("floor boundary matches retained snapshot", _board.cells == _editor.draft.snapshot().cells)


func _refused_order() -> void:
	"""The fixture's synthetic coordinator refuses; the actual UI must retain the drawing."""
	_click(_button("Confirm room"))
	_check("explicit button reaches coordinator once", _submissions == 1)
	_check("owner refusal retains complete blueprint", not _editor.draft.visible_cells().is_empty())
	_pending_capture = "owner_refusal"


func _accepted_order() -> void:
	"""An explicit second click after a changed synthetic result consumes just the draft."""
	_reject = false
	_editor.refresh_site()
	_click(_button("Confirm room"))
	_check("second explicit request reaches fixture owner", _submissions == 2)
	_check("successful fixture receipt clears draft", _editor.draft.visible_cells().is_empty())
	_click(_button("Confirm room"))
	_check("empty draft cannot duplicate request", _submissions == 2)


func _check_site(_request: Dictionary) -> StringName:
	"""Only a fixture boundary check, not physical authority."""
	return &""


func _submit(_request: Dictionary) -> Dictionary:
	"""Count synthetic receipts without creating any simulated room or charging materials."""
	_submissions += 1
	return {"ok": not _reject, "error": "Stair landing occupied. Adjust the blueprint."}


func _button(text: String) -> Button:
	"""Find an actual visible action in the small inspector."""
	var pending: Array[Node] = [_editor]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Button and node.text == text:
			return node as Button
		for child: Node in node.get_children():
			pending.append(child)
	return null


func _click(button: Button) -> void:
	"""Dispatch a real GUI click through the root viewport."""
	assert(button != null)
	var at: Vector2 = button.get_global_rect().get_center()
	_pointer(at, true)
	_pointer(at, false)


func _drag(points: Array[Vector2i]) -> void:
	"""Use a pressed pointer and integer-cell centres, exercising actual GUI routing."""
	_pointer(_at(points[0]), true)
	for cell: Vector2i in points:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = _at(cell)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
	_pointer(_at(points.back()), false)


func _at(cell: Vector2i) -> Vector2:
	"""Grid-centre presentation coordinates for pointer events."""
	return _board.global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * Board.CELL_PX


func _pointer(at: Vector2, down: bool) -> void:
	"""Send only a physical button event; the scene decides which control consumes it."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event)


func _check(label: String, passed: bool) -> void:
	"""Publish check counts independently from process status."""
	_checks += 1
	if not passed:
		_failures += 1
	print("MODULAR-EDITOR %s: %s" % [label, "PASS" if passed else "FAIL"])


func _save_capture() -> void:
	"""Capture the rendered fixture only when requested on a native display."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		var path: String = _capture_dir.path_join(_pending_capture + "_1280x720.png")
		_check("native capture saved", root.get_texture().get_image().save_png(path) == OK)
	_pending_capture = ""
