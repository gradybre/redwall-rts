extends VBoxContainer
## Room shape controls and integer-pointer adapter. The host owns picking, modal input and
## the atomic construction coordinator. An unbound editor can preview but cannot order work.

const Draft := preload("res://demo/burrow/modular_draft.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const TOOL_NAMES: PackedStringArray = ["Rectangle", "Rounded rectangle", "Oval", "Paint", "Tunnel route"]
const TOOL_HINTS: PackedStringArray = [
	"Drag the room's opposite corners. Add adjoining sections for an L or T shape.",
	"Drag opposite corners. The rounding control sets the maximum corner radius.",
	"Drag independent width and length; the room need not be a circle.",
	"Paint a connected area. Select Erase to carve recesses or remove space.",
	"Draw the tunnel's route through bends. The width includes both sides of its centre line.",
]

signal preview_changed(cells: PackedInt32Array, revision: int)
signal room_ordered(receipt: Dictionary)
signal draft_discarded

var draft: Draft = null
var _shape: OptionButton = null
var _erase: CheckButton = null
var _radius: SpinBox = null
var _hint: Label = null
var _status: Label = null
var _confirm: Button = null
var _checker: Callable = Callable()
var _submitter: Callable = Callable()
var _last_refusal: String = ""
var _submitting: bool = false


func configure(session: Draft, max_radius_cells: int) -> void:
	"""Build a compact inspector whose shape tools all edit the same retained draft."""
	assert(session != null and max_radius_cells >= 0)
	assert(draft == null, "Configure a room inspector only once")
	draft = session
	custom_minimum_size.x = 280.0
	add_theme_constant_override(&"separation", 6)
	_build_tools(max_radius_cells)
	_build_actions()
	_sync()


func bind_confirmation(checker: Callable, submitter: Callable) -> void:
	"""Bind the actual atomic owner; a signal or valid geometry alone never authorizes work."""
	if _submitting:
		return
	_checker = checker
	_submitter = submitter
	_sync()


func world_press(cell: Vector2i) -> bool:
	"""Begin drawing only after the host has excluded UI clicks and other modal tools."""
	if draft == null or draft.drawing() or _submitting:
		return false
	_last_refusal = ""
	draft.begin_stroke(_shape.selected, cell, int(_radius.value), _erase.button_pressed)
	_sync()
	return true


func world_motion(cell: Vector2i) -> void:
	"""Update on changed integer cells; camera motion alone cannot repaint the room."""
	if draft != null and draft.drawing() and not _submitting:
		var prior: int = draft.visual_revision
		draft.extend_stroke(cell)
		if draft.visual_revision != prior:
			_sync()


func world_release() -> void:
	"""Release adds the stroke to the blueprint, never directly to construction."""
	if draft != null and draft.drawing() and not _submitting:
		_last_refusal = _words(draft.finish_stroke())
		_sync()


func cancel_stroke() -> bool:
	"""Consume one escape layer only when a current drag exists."""
	if _submitting or draft == null or not draft.cancel_stroke():
		return false
	_sync()
	return true


func select_tool(tool: int, erase: bool, radius_cells: int) -> bool:
	"""Select a tool without changing retained cells, type, level or accepted orders."""
	if _submitting or draft == null or tool < 0 or tool >= TOOL_NAMES.size() \
			or radius_cells < 0 or radius_cells > int(_radius.max_value):
		return false
	draft.cancel_stroke()
	_shape.select(tool)
	_erase.button_pressed = erase
	_radius.value = radius_cells
	_sync()
	return true


func request_confirmation() -> bool:
	"""Recheck a fresh isolated snapshot; refusal preserves every part of the player's draft."""
	if _submitting or draft == null or draft.confirmation_error() != &"" or not _bound():
		return false
	var submitted_draft: Draft = draft
	var request: Dictionary = draft.snapshot()
	_submitting = true
	var blocker: Variant = _checker.call(request.duplicate(true))
	_last_refusal = _check_refusal(blocker, submitted_draft, request.revision)
	if not _last_refusal.is_empty():
		_submitting = false
		_sync()
		return false
	var answer: Variant = _submitter.call(request.duplicate(true))
	_submitting = false
	return _accept_answer(answer, submitted_draft, request.revision)


func _check_refusal(blocker: Variant, checked_draft: Draft, checked_revision: int) -> String:
	"""A checker must return explicit words and cannot replace the reviewed drawing mid-check."""
	if not blocker is String and not blocker is StringName:
		return "The construction site could not be checked."
	if draft != checked_draft or draft.revision != checked_revision or draft.drawing():
		return "The blueprint changed. Review its new shape before confirming."
	return String(blocker)


func _accept_answer(answer: Variant, submitted_draft: Draft, submitted_revision: int) -> bool:
	"""Keep refused drafts and disable retries after an ambiguous external transaction result."""
	if not answer is Dictionary or typeof(answer.get("ok")) != TYPE_BOOL:
		_submitter = Callable()
		_last_refusal = "The order result could not be verified. Review projects before ordering again."
		_sync()
		return false
	if not answer.ok:
		_last_refusal = String(answer.get("error", "The room order was refused."))
		_sync()
		return false
	if draft == submitted_draft and draft.revision == submitted_revision and not draft.drawing():
		draft.discard()
		_last_refusal = ""
	else:
		_last_refusal = "The submitted blueprint was ordered. Your newer drawing is kept for review."
	room_ordered.emit(answer)
	_sync()
	return true


func refresh_site() -> void:
	"""The host calls this on an owner revision; no per-frame world polling lives here."""
	if _submitting:
		return
	_last_refusal = ""
	_sync()


func _build_tools(max_radius: int) -> void:
	"""Keep descriptive text and every control readable inside the detail zone at 720p."""
	add_child(_label("Draw the room on the dirt", 18))
	_shape = OptionButton.new()
	_shape.custom_minimum_size.y = 32.0
	_shape.add_theme_font_size_override(&"font_size", 16)
	for title: String in TOOL_NAMES:
		_shape.add_item(title)
	add_child(_shape)
	_shape.item_selected.connect(_tool_changed)
	_erase = CheckButton.new()
	_erase.text = "Erase planned area"
	_erase.custom_minimum_size.y = 32.0
	add_child(_erase)
	_erase.toggled.connect(_erase_changed)
	var row: HBoxContainer = HBoxContainer.new()
	var radius_label: Label = _label("Rounding / brush radius", 14)
	radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(radius_label)
	_radius = SpinBox.new()
	_radius.max_value = max_radius
	_radius.custom_minimum_size = Vector2(82.0, 32.0)
	row.add_child(_radius)
	add_child(row)
	_radius.value_changed.connect(_radius_changed)
	_hint = _label("", 14)
	add_child(_hint)


func _build_actions() -> void:
	"""Separate draft editing from the single construction-confirm action."""
	_status = _label("", 14)
	add_child(_status)
	var history: HBoxContainer = HBoxContainer.new()
	history.add_child(_button("Undo", _undo))
	history.add_child(_button("Redo", _redo))
	add_child(history)
	_confirm = _button("Confirm room", request_confirmation)
	add_child(_confirm)
	add_child(_button("Discard blueprint", _discard))


func _sync() -> void:
	"""Refresh event-driven presentation and publish copied geometry for the host's world overlay."""
	if draft == null or _confirm == null:
		return
	_hint.text = TOOL_HINTS[_shape.selected]
	_radius.editable = _shape.selected != Draft.RECTANGLE and _shape.selected != Draft.ELLIPSE
	var error: StringName = draft.preview_error() if draft.drawing() else draft.confirmation_error()
	var cells: PackedInt32Array = draft.visible_cells()
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	_status.text = "%d grid cells · No work ordered" % count
	var words: String = _last_refusal if not _last_refusal.is_empty() else _words(error)
	if not words.is_empty():
		_status.text += "\n" + words
	_confirm.disabled = draft.drawing() or error != &"" or not _bound()
	_confirm.tooltip_text = "Review and order this blueprint." if _bound() else "Preview only; construction is not connected in this view."
	preview_changed.emit(cells, draft.visual_revision)


func _bound() -> bool:
	"""Both authoritative revalidation and atomic submission must be supplied by the host."""
	return _checker.is_valid() and _submitter.is_valid()


func _tool_changed(_selected: int) -> void:
	"""Changing a tool cancels only the incomplete gesture."""
	if _submitting:
		return
	draft.cancel_stroke()
	_sync()


func _erase_changed(_enabled: bool) -> void:
	"""Switch future strokes between adding and erasing without changing previous paint."""
	_tool_changed(0)


func _radius_changed(_value: float) -> void:
	"""SpinBox stores a float for UI; only its integer step count reaches the draft."""
	_tool_changed(0)


func _undo() -> void:
	"""Undo one retained drawing edit."""
	if _submitting:
		return
	draft.undo()
	_last_refusal = ""
	_sync()


func _redo() -> void:
	"""Redo one retained drawing edit."""
	if _submitting:
		return
	draft.redo()
	_last_refusal = ""
	_sync()


func _discard() -> void:
	"""Only the explicit button discards the whole new-room blueprint."""
	if _submitting:
		return
	draft.discard()
	_last_refusal = ""
	draft_discarded.emit()
	_sync()


static func _label(text: String, font_size: int) -> Label:
	"""Use the existing woodland ink and body font with wrapping inside the HUD column."""
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Palette.INK)
	return label


static func _button(text: String, callback: Callable) -> Button:
	"""Keep action targets at least 32 logical pixels tall with keyboard focus available."""
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 32.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", 16)
	button.pressed.connect(callback)
	return button


static func _words(error: StringName) -> String:
	"""Explain geometry failures in words; colour alone never carries a refusal."""
	match error:
		&"": return ""
		&"FOOTPRINT_EMPTY": return "Draw a room, then confirm its blueprint."
		&"FOOTPRINT_DISCONNECTED": return "Join the painted areas with a continuous passage."
		&"FOOTPRINT_PINCHED_BOUNDARY": return "Widen the corner where two boundaries touch."
		&"FOOTPRINT_HOLES_NOT_ALLOWED": return "Fill the enclosed gap or open it to the outside."
		&"ROOM_OUTSIDE_PLANNING_BOUNDS": return "Keep the whole room inside the planning area."
		&"FOOTPRINT_CAPACITY", &"DRAWING_STROKE_TOO_LONG": return "This blueprint exceeds the current drawing limit. Use a smaller section."
		&"FINISH_CURRENT_STROKE": return "Release to keep this stroke in the blueprint."
	return "This shape could not be drawn. Adjust the stroke and try again."
