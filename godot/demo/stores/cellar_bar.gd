extends VBoxContainer
## THE CELLAR BUILDINGS IN THE PANTRY (decision 0612): under the Pantry's stores and why they keep food as they do, a
## line a cellar building -- its state, what is delivered and how far it has got, and while it is planned a Cancel
## button that says what it gives back (REQ-SET-126) -- and "Build a cellar…", which closes the Pantry and arms the
## placing tool (cellar_place.gd), disabled with its reason while the cellar is locked or two are planned. Presentation
## only; redrawn when the cellars change.

const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const Rules := preload("res://demo/stores/cellar_rules.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

signal build_requested
signal cancel_requested(cellar: int)

const HEADING: String = "Cellar buildings — %d U each, food keeps 2.8× as long as in the covered store"
const BUILD: String = "Build a cellar…"
const BUILD_TIP: String = "Place a cellar building: wood %s and stone %s, fetched from the stores, then %d WU of building"
const NOTE_PX: int = 14
const UNLOCK_CHECK_S: float = 1.0

var _projects: ProjectsScript = null
var _locked: Callable = Callable()
var _seen: int = -1
## The Build button's last reason, asked again every UNLOCK_CHECK_S of real time (a time-based unlock opens it).
var _refusal_seen: String = ""
var _check_s: float = 0.0
var _lines: Array[Label] = []
var _cancels: Array[Button] = []
var _build: Button = null


func configure(projects: ProjectsScript, locked: Callable) -> void:
	"""Show these cellars; `locked() -> String` says why a cellar cannot be built yet ("" when it can)."""
	name = "CellarBar"
	_projects = projects
	_locked = locked
	add_theme_constant_override(&"separation", 4)
	add_child(FarmUi.label(HEADING % Rules.capacity_u(), NOTE_PX, Palette.UMBER, true))
	for c: int in ProjectsScript.MAX_CELLARS:
		_add_line(c)
	_build = FarmUi.button(BUILD)
	_build.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_build.tooltip_text = BUILD_TIP % [ProjectsScript.units_text(Rules.cost_milli(Rules.MAT_WOOD)),
		ProjectsScript.units_text(Rules.cost_milli(Rules.MAT_STONE)), Rules.work_wu()]
	_build.pressed.connect(func() -> void: build_requested.emit())
	add_child(_build)
	refresh()


func _add_line(c: int) -> void:
	"""Cellar `c`'s line: its words and its Cancel."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var line: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	var cancel: Button = FarmUi.button("Cancel")
	cancel.pressed.connect(func() -> void: cancel_requested.emit(c))
	row.add_child(cancel)
	add_child(row)
	_lines.append(line)
	_cancels.append(cancel)


func _process(delta: float) -> void:
	"""Redraw when the cellars changed, or the unlock's answer did (asked once a second)."""
	if _projects == null or not is_visible_in_tree():
		return
	_check_s -= delta
	if _projects.revision != _seen or (_check_s <= 0.0 and build_refusal() != _refusal_seen):
		refresh()
	if _check_s <= 0.0:
		_check_s = UNLOCK_CHECK_S


func refresh() -> void:
	"""Every line and the Build button as things stand."""
	_seen = _projects.revision
	for c: int in ProjectsScript.MAX_CELLARS:
		var live: bool = _projects.state[c] != ProjectsScript.STATE_NONE
		_lines[c].get_parent().visible = live
		_lines[c].text = _projects.status_text(c) if live else ""
		_cancels[c].visible = _projects.is_active(c)
		_cancels[c].tooltip_text = "Cancel it: %s" % _projects.refund_text(c) if _projects.is_active(c) else ""
	var why: String = build_refusal()
	_refusal_seen = why
	FarmUi.set_enabled(_build, why.is_empty(), why)


func build_refusal() -> String:
	"""Why "Build a cellar…" is disabled ("" when it is not)."""
	var locked: String = String(_locked.call()) if _locked.is_valid() else ""
	if not locked.is_empty():
		return locked
	return ProjectsScript.REFUSE_FULL if _projects.free_row() == ProjectsScript.NONE else ""


func build_button() -> Button:
	"""The Build button (checks)."""
	return _build


func line_text(c: int) -> String:
	"""Cellar `c`'s line (checks)."""
	return _lines[c].text


func cancel_button(c: int) -> Button:
	"""Cellar `c`'s Cancel (checks)."""
	return _cancels[c]
