extends "res://scripts/ui/ui_modal_frame.gd"
## UI-SET-076 Save browser, with its UI-SET-077 rows (ADR 1222 step 11; DEC-055, 2026-10-08).
##
## "Save and load settlements": three tabs, Manual / Autosave / Prewinter (§4.3). Brendan's
## choices for what §4 left open: the quicksave and the pre-demolition quicksave are rows of the
## AUTOSAVE tab; a manual save is auto-named `save_NNN` and may be renamed (its label only); a kept
## rollback checkpoint is a row marked "Recovered" in its tab; the development-only statement sits
## in the browser HEADER, under the title, on every tab.
##
## ACTIONS, all through `ui_save_session.gd` (the one path to the slots):
##   * Load (UI-SET-066, "load requires 066"): loads the selected row. It names the save and its
##     in-game date, so F9 -- which opens this browser on the quicksave with Load focused -- is
##     §5's confirmation that "names save/date; does not load without confirmation".
##   * Save (Manual tab): a new auto-named manual save, at once.
##   * Overwrite (Manual tab): "overwrite confirmation explicit" -- a second step whose own 066
##     names the save being replaced, with UI-SET-067 to keep it.
##   * Rename (Manual tab): a field for the save's name; 066 renames, 067 cancels.
## The rows repaint on the session's signals (`refresh()` is connected by the host), never by
## polling. Nothing here writes game state or a file itself.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")
const UiSaveRows := preload("res://scripts/ui/ui_save_rows.gd")
const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const UiThemeScript := preload("res://scripts/ui/ui_theme.gd")

## Emitted after a load this browser asked for finished (the host closes the modals on success).
signal load_done(code: StringName)
## The browser asked to close (the host hides it and returns focus to its opener).
signal closed

const TITLE: String = "Save and load settlements"
const DEVELOPMENT_NOTE: String = "Development saves: each one loads only in this exact build of the game."
const PREFERRED_SIZE: Vector2 = Vector2(960.0, 720.0)
const ROW_MINIMUM: Vector2 = Vector2(448.0, 64.0)
const CONFIRM_MINIMUM: Vector2 = Vector2(120.0, 44.0)
const MODE_BROWSE: int = 0
const MODE_OVERWRITE: int = 1
const MODE_RENAME: int = 2

var _session: UiSaveSession = null
var _tab: int = UiSaveRows.TAB_MANUAL
var _rows: Array[UiSaveRows.Row] = []
var _selected: int = -1
var _mode: int = MODE_BROWSE
var _tabs: Array[Button] = []
var _row_buttons: Array[Button] = []
var _status: Label = null
var _empty: Label = null
var _rename_field: LineEdit = null
var _cancel: Button = null
var _save: Button = null
var _rename: Button = null
var _overwrite: Button = null
var _confirm: Button = null
## §2.2 ROW styles with the row's text inset: [default, hover, pressed, selected], built once.
var _row_styles: Array[StyleBoxFlat] = []


func setup(session: UiSaveSession) -> void:
	"""Build the browser over `session`."""
	_session = session
	_build_row_styles()
	build(TITLE, "UI-SET-076", PREFERRED_SIZE)
	_build_header()
	_build_body_parts()
	_build_footer()
	dismiss_requested.connect(_on_dismiss)


func _build_row_styles() -> void:
	"""The four ROW backgrounds a row button switches between, each insetting its text."""
	var tokens: UiThemeScript = UiThemeScript.new()
	for state: int in [UiThemeScript.STATE_DEFAULT, UiThemeScript.STATE_HOVER,
			UiThemeScript.STATE_PRESSED, UiThemeScript.STATE_SELECTED]:
		var box: StyleBoxFlat = tokens.panel_style(UiRegistry.PROFILE_ROW, state)
		box.content_margin_left = PADDING
		box.content_margin_right = PADDING
		box.content_margin_top = GAP / 2.0
		box.content_margin_bottom = GAP / 2.0
		_row_styles.append(box)


func _paint_row(button: Button, selected: bool) -> void:
	"""§2.2 ROW: selected rows are GOLD with INK text; others PANEL, HOVER and PRESSED."""
	var base: int = 3 if selected else 0
	button.add_theme_stylebox_override(&"normal", _row_styles[base])
	button.add_theme_stylebox_override(&"hover", _row_styles[base if selected else 1])
	button.add_theme_stylebox_override(&"pressed", _row_styles[base if selected else 2])
	var ink: Color = UiThemeScript.color_of(UiThemeScript.TOKEN_INK if selected
		else UiThemeScript.TOKEN_TEXT)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color"]:
		button.add_theme_color_override(slot, ink)


func _build_header() -> void:
	"""The development-only note, the three tabs and the status line."""
	var note: Label = Label.new()
	note.name = "DevelopmentNote"
	note.text = DEVELOPMENT_NOTE
	note.theme_type_variation = &"WoodlandSecondary"
	header().add_child(note)
	var strip: HBoxContainer = HBoxContainer.new()
	strip.name = "Tabs"
	header().add_child(strip)
	for tab: int in UiSaveRows.TAB_COUNT:
		var button: Button = new_button("UI-SET-076_tab_%s" % UiSaveRows.TAB_NAMES[tab].to_lower(),
			UiSaveRows.TAB_NAMES[tab], "%s saves tab, %d of %d" % [UiSaveRows.TAB_NAMES[tab],
				tab + 1, UiSaveRows.TAB_COUNT])
		button.toggle_mode = true
		button.theme_type_variation = &"WoodlandToggle"
		button.pressed.connect(open_tab.bind(tab))
		strip.add_child(button)
		_tabs.append(button)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	header().add_child(_status)


func _build_body_parts() -> void:
	"""The empty-tab line in the body and the rename field under the header's status line (rows
	are built per tab, after the empty line)."""
	_empty = Label.new()
	_empty.name = "Empty"
	_empty.theme_type_variation = &"WoodlandSecondary"
	body().add_child(_empty)
	_rename_field = LineEdit.new()
	_rename_field.name = "UI-SET-077_rename"
	_rename_field.max_length = Slots.MAX_NAME_LENGTH
	_rename_field.custom_minimum_size = Vector2(ROW_MINIMUM.x, BUTTON_HEIGHT)
	_rename_field.accessibility_name = "UI-SET-077 Name for this save, 1 to 64 characters"
	_rename_field.text_submitted.connect(func(_text: String) -> void: _on_confirm())
	_rename_field.visible = false
	_style_field(_rename_field)
	header().add_child(_rename_field)


static func _style_field(field: LineEdit) -> void:
	"""§2.2 FIELD: INK background, MUTED border, 4 px radius; focused, a 2 px GOLD border."""
	var tokens: UiThemeScript = UiThemeScript.new()
	var normal: StyleBoxFlat = tokens.panel_style(UiRegistry.PROFILE_FIELD,
		UiThemeScript.STATE_DEFAULT)
	normal.content_margin_left = PADDING
	normal.content_margin_right = PADDING
	var focused: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focused.border_color = UiThemeScript.color_of(UiThemeScript.TOKEN_GOLD)
	focused.set_border_width_all(UiThemeScript.FOCUS_OUTLINE_WIDTH)
	field.add_theme_stylebox_override(&"normal", normal)
	field.add_theme_stylebox_override(&"focus", focused)
	field.add_theme_color_override(&"font_color", UiThemeScript.color_of(UiThemeScript.TOKEN_TEXT))


func _build_footer() -> void:
	"""UI-SET-067 on the left, the Manual tab's actions, then UI-SET-066 on the right."""
	_cancel = new_button("UI-SET-067_cancel", "Cancel", "Cancel")
	_cancel.pressed.connect(_on_dismiss)
	_save = new_button("UI-SET-066_save_new", "Save", "Save a new manual save")
	_save.pressed.connect(_on_save_new)
	_rename = new_button("UI-SET-076_rename", "Rename", "Rename the selected save")
	_rename.pressed.connect(_begin.bind(MODE_RENAME))
	_overwrite = new_button("UI-SET-076_overwrite", "Overwrite", "Overwrite the selected save")
	_overwrite.pressed.connect(_begin.bind(MODE_OVERWRITE))
	_confirm = new_button("UI-SET-066_load", "Load", "Load the selected save")
	_confirm.custom_minimum_size = CONFIRM_MINIMUM
	_confirm.pressed.connect(_on_confirm)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control: Control in [_cancel, spacer, _save, _rename, _overwrite, _confirm]:
		footer().add_child(control)


# --- opening -----------------------------------------------------------------------------------

func open(tab: int, kind: String = "", slot: String = "") -> void:
	"""Show the browser on `tab`, selecting the `kind/slot` row when given (F9: the quicksave)."""
	_mode = MODE_BROWSE
	_set_status("")
	open_tab(tab)
	var index: int = UiSaveRows.find_row(_rows, kind, slot)
	if index >= 0:
		select(index)
	elif kind == Slots.KIND_QUICK:
		_set_status(UiSaveSession.reason_for(UiSaveSession.REFUSE_NO_QUICKSAVE, true))
	show_modal(_confirm if _selected >= 0 else _first_focus())


func open_tab(tab: int) -> void:
	"""Switch to one tab and list its rows."""
	_tab = clampi(tab, 0, UiSaveRows.TAB_COUNT - 1)
	for index: int in _tabs.size():
		_tabs[index].set_pressed_no_signal(index == _tab)
	_selected = -1
	_mode = MODE_BROWSE
	refresh()


func current_tab() -> int:
	"""The tab shown."""
	return _tab


func refresh() -> void:
	"""Re-read this tab's rows from the slots and repaint (connected to the session's signals)."""
	var keep: Array[String] = _selected_identity()
	_rows = UiSaveRows.rows_for_tab(_tab)
	_selected = _index_of_identity(keep)
	_rebuild_rows()
	_paint_footer()


func _selected_identity() -> Array[String]:
	"""The selected row's kind, name and file, so a repaint keeps the selection."""
	if _selected < 0 or _selected >= _rows.size():
		return []
	var row: UiSaveRows.Row = _rows[_selected]
	return [row.kind, row.name, row.file]


func _index_of_identity(identity: Array[String]) -> int:
	"""The index of the row with this identity, or -1."""
	if identity.is_empty():
		return -1
	for index: int in _rows.size():
		if [_rows[index].kind, _rows[index].name, _rows[index].file] == identity:
			return index
	return -1


func _rebuild_rows() -> void:
	"""One UI-SET-077 button per row, in the body above the rename field."""
	for button: Button in _row_buttons:
		body().remove_child(button)
		button.free()
	_row_buttons.clear()
	for index: int in _rows.size():
		var button: Button = _row_button(_rows[index], index)
		body().add_child(button)
		_row_buttons.append(button)
	_empty.visible = _rows.is_empty()
	_empty.text = "No %s saves yet." % UiSaveRows.TAB_NAMES[_tab].to_lower()


func _row_button(row: UiSaveRows.Row, index: int) -> Button:
	"""One ROW-profile instance: title, then date, time stamp, version and validity."""
	var button: Button = new_button("UI-SET-077_%s_%s" % [row.kind, row.file.validate_node_name()],
		"%s\n%s" % [row.title, row.detail_text()], row.accessible_text())
	button.theme_type_variation = &"WoodlandRow"
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = ROW_MINIMUM
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_pressed_no_signal(index == _selected)
	_paint_row(button, index == _selected)
	button.pressed.connect(select.bind(index))
	return button


func select(index: int) -> void:
	"""Select one row (or none with -1) and repaint the footer for it."""
	_selected = index if index >= 0 and index < _rows.size() else -1
	_mode = MODE_BROWSE
	for at: int in _row_buttons.size():
		_row_buttons[at].set_pressed_no_signal(at == _selected)
		_paint_row(_row_buttons[at], at == _selected)
	_paint_footer()


func selected_row() -> UiSaveRows.Row:
	"""The selected row, or null."""
	return _rows[_selected] if _selected >= 0 else null


func rows() -> Array[UiSaveRows.Row]:
	"""The rows of the tab shown."""
	return _rows


# --- the footer --------------------------------------------------------------------------------

func _paint_footer() -> void:
	"""Show the actions this tab, row and step allow, each disabled with its reason."""
	var row: UiSaveRows.Row = selected_row()
	var manual: bool = _tab == UiSaveRows.TAB_MANUAL and _mode == MODE_BROWSE
	var ordinary_manual: bool = manual and row != null and not row.recovered
	_save.visible = manual
	_rename.visible = manual
	_overwrite.visible = manual
	_rename.disabled = not ordinary_manual
	_overwrite.disabled = not ordinary_manual
	_rename_field.visible = _mode == MODE_RENAME
	_cancel.text = "Cancel" if _mode == MODE_BROWSE else "Keep %s" % _row_title(row)
	if _mode == MODE_OVERWRITE:
		_set_status("Overwrite %s with the settlement as it is now? The save it holds is replaced." \
			% _row_title(row))
	elif _mode == MODE_RENAME:
		_set_status("A new name for %s:" % _row_title(row))
	_paint_confirm(row)
	set_focus_ring(_focus_order())


func _paint_confirm(row: UiSaveRows.Row) -> void:
	"""UI-SET-066 for the current step: load, overwrite or rename, with its reason when disabled."""
	match _mode:
		MODE_OVERWRITE:
			_set_confirm("Overwrite %s" % _row_title(row), "",
				"UI-SET-066 Overwrite %s with the settlement as it is now" % _row_title(row))
		MODE_RENAME:
			_set_confirm("Rename save", "", "UI-SET-066 Rename %s" % _row_title(row))
		_:
			_set_confirm(_load_text(row), _load_reason(row), "UI-SET-066 %s" % _load_text(row))


func _set_confirm(text: String, reason: String, accessible: String) -> void:
	"""Label UI-SET-066; a non-empty `reason` disables it and says why (§2.2)."""
	_confirm.text = text
	_confirm.disabled = reason != ""
	_confirm.tooltip_text = reason
	_confirm.accessibility_name = accessible
	_confirm.accessibility_description = reason


func _load_text(row: UiSaveRows.Row) -> String:
	"""'Load <save>, <in-game date>' -- the confirmation names the save and its date."""
	if row == null:
		return "Load"
	return "Load %s, %s" % [row.title, row.when_text]


func _load_reason(row: UiSaveRows.Row) -> String:
	"""Why Load is unavailable, or empty."""
	if row == null:
		return "Unavailable: select a save to load."
	if not row.valid:
		return "Unavailable: %s." % row.validity_text
	return ""


func _row_title(row: UiSaveRows.Row) -> String:
	"""A row's title, or an empty string."""
	return row.title if row != null else ""


func _focus_order() -> Array[Control]:
	"""Tabs, rows, the rename field, then the footer, left to right."""
	var order: Array[Control] = []
	order.append_array(_tabs)
	order.append(_rename_field)
	order.append_array(_row_buttons)
	order.append_array([_cancel, _save, _rename, _overwrite, _confirm, close_button()])
	return order


func _first_focus() -> Control:
	"""Where focus lands on opening: the first row, else Save on the Manual tab, else the tab."""
	if not _row_buttons.is_empty():
		return _row_buttons[0]
	return _save if _tab == UiSaveRows.TAB_MANUAL else _tabs[_tab]


# --- the actions -------------------------------------------------------------------------------

func _begin(mode: int) -> void:
	"""Enter the overwrite confirmation or the rename step for the selected manual save."""
	var row: UiSaveRows.Row = selected_row()
	if row == null or row.recovered:
		return
	_mode = mode
	_rename_field.text = row.label if row.label != "" else row.name
	_paint_footer()
	if mode == MODE_RENAME:
		focus_later(_rename_field)
	else:
		focus_later(_confirm)


func _on_confirm() -> void:
	"""UI-SET-066 for the current step."""
	var row: UiSaveRows.Row = selected_row()
	if _confirm.disabled or row == null:
		return
	match _mode:
		MODE_OVERWRITE:
			_report(_session.overwrite_manual(row.name), "Saved over %s." % row.title, false)
		MODE_RENAME:
			_report(_session.rename_manual(row.name, _rename_field.text), "Renamed.", false)
		_:
			_load(row)
	_mode = MODE_BROWSE
	refresh()


func _load(row: UiSaveRows.Row) -> void:
	"""Load the row (an ordinary save or a recovered checkpoint) and tell the host."""
	var refusal: SaveHeader.Refusal = _session.load_recovered(row.kind, row.file) \
		if row.recovered else _session.load_slot(row.kind, row.name)
	_report(refusal, "Loaded %s." % row.title, true)
	load_done.emit(refusal.code)


func _on_save_new() -> void:
	"""Save: a new auto-named manual save, selected once written."""
	var slot: String = Slots.next_manual_name()
	var refusal: SaveHeader.Refusal = _session.save_new_manual()
	_report(refusal, "Saved as %s." % slot, false)
	refresh()
	select(UiSaveRows.find_row(_rows, Slots.KIND_MANUAL, slot))


func _report(refusal: SaveHeader.Refusal, success: String, loading: bool) -> void:
	"""The status line: the success, or the code, plain reason and recovery (UI-SET-085's
	content; the host's notice carries it too)."""
	if refusal.is_ok():
		_set_status(success)
		return
	_set_status("%s %s %s" % [String(refusal.code), UiSaveSession.reason_for(refusal.code,
		loading), UiSaveSession.recovery_for(refusal.code, loading)])


func _set_status(text: String) -> void:
	"""The status line, shown only when it says something."""
	_status.text = text
	_status.visible = text != ""


func status_text() -> String:
	"""The status line."""
	return _status.text


func _on_dismiss() -> void:
	"""Escape, UI-SET-067 or UI-SET-093: leave a step first, else ask the host to close."""
	if _mode != MODE_BROWSE:
		_mode = MODE_BROWSE
		_set_status("")
		_paint_footer()
		focus_later(_confirm)
		return
	closed.emit()

