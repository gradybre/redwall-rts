extends VBoxContainer
## THE PROJECTS' PAGE (decision 0481; review UX-020) in the village guide: the pinned projects -- each its name, its
## goal, how far it has come, Go to for each place it is about, and Remove -- and, while fewer than three are pinned,
## a new one: a name, a measure (◀ ▶), a target (− +), the places selected now, and Pin. A refusal is said in words.
## It shows and asks; projects.gd decides and the village's figures measure. DEMO UI.

const ProjectsScript := preload("res://demo/guide/projects.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const FactsScript := preload("res://demo/guide/guide_facts.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const EMPTY: String = "No projects yet. Name one below: what you want the village to reach, and where."
const NEW_TITLE: String = "A new project"
const FULL: String = "Three projects are pinned: remove one to start another."
const NAME_HINT: String = "Its name -- e.g. \"Wood for winter\""
const PLACES_NONE: String = "Places: none selected (select a bed, a tunnel or residents first to link them)."
const PLACES_SOME: String = "Places: %s"
const PIN_TEXT: String = "Pin project"
const REMOVE_TEXT: String = "Remove"
const GO_TO: String = "Go to %s"
const ROW: String = "%s %s -- %s"
const PROGRESS: String = "%s of %s"

var projects: ProjectsScript = null
var world: WorldScript = null
var facts: FactsScript = null
## `places_into(kinds: Array[Vector3i], names: PackedStringArray)`: what is selected now (the host's).
var places_into: Callable = Callable()
## `go_to(kind, id)`: the news's own Go to (the host's).
var go_to: Callable = Callable()

var _rows: VBoxContainer = null
var _form: VBoxContainer = null
var _name: LineEdit = null
var _measure: Label = null
var _target: Label = null
var _places: Label = null
var _said: Label = null
var _pin: Button = null
var _measure_k: int = ProjectsScript.MEASURE_WOOD
var _target_value: int = ProjectsScript.FIRST_TARGETS[ProjectsScript.MEASURE_WOOD]
var _drawn: int = -1
var _width: float = 520.0


func _init() -> void:
	"""The pinned rows and the new-project form."""
	name = "ProjectsPage"
	add_theme_constant_override(&"separation", 8)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	add_child(_rows)
	_build_form()


func _build_form() -> void:
	"""Name, measure, target, places, Pin and the refusal line."""
	_form = VBoxContainer.new()
	_form.add_theme_constant_override(&"separation", 4)
	add_child(_form)
	_form.add_child(FarmUi.label(NEW_TITLE, FarmUi.BODY_PX, Palette.INK, true))
	_name = GuideUi.field(NAME_HINT, ProjectsScript.NAME_MAX)
	_form.add_child(_name)
	_measure = _stepper(_form, step_measure.bind(-1), step_measure.bind(1), "◀", "▶")
	_target = _stepper(_form, step_target.bind(-1), step_target.bind(1), "−", "+")
	_places = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	_form.add_child(_places)
	_pin = FarmUi.button(PIN_TEXT, FarmUi.BODY_PX)
	_pin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pin.pressed.connect(pin)
	_form.add_child(_pin)
	_said = FarmUi.label("", FarmUi.SMALL_PX, Palette.CLAY)
	_form.add_child(_said)


func _stepper(parent: Control, less: Callable, more: Callable, less_text: String, more_text: String) -> Label:
	"""A row: a button, a label between, a button."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
	var down: Button = FarmUi.button(less_text, FarmUi.BODY_PX)
	down.pressed.connect(less)
	row.add_child(down)
	var shown: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	shown.autowrap_mode = TextServer.AUTOWRAP_OFF
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shown)
	var up: Button = FarmUi.button(more_text, FarmUi.BODY_PX)
	up.pressed.connect(more)
	row.add_child(up)
	return shown


func step_measure(by: int) -> void:
	"""The next or previous measure, its target back to its first value."""
	_measure_k = posmod(_measure_k + by, ProjectsScript.MEASURE_COUNT)
	_target_value = ProjectsScript.FIRST_TARGETS[_measure_k]
	refresh()


func step_target(by: int) -> void:
	"""The target a step up or down (never below one step)."""
	var step: int = ProjectsScript.STEPS[_measure_k]
	_target_value = maxi(step, _target_value + by * step)
	refresh()


func pin() -> void:
	"""Pin the project as the form says, with the places selected now; say why not when refused."""
	if projects == null:
		return
	var places: Array[Vector3i] = []
	var names := PackedStringArray()
	if places_into.is_valid():
		places_into.call(places, names)
	var refused: String = projects.add(_name.text, _measure_k, _target_value, world, facts, places, names)
	_said.text = refused
	if refused.is_empty():
		_name.text = ""
	refresh()


func refresh() -> void:
	"""The rows (redrawn when a project changed) and the form's figures."""
	if projects != null and projects.revision != _drawn:
		_drawn = projects.revision
		_draw_rows()
	_measure.text = ProjectsScript.MEASURE_NAMES[_measure_k]
	_target.text = "Target: %s" % ProjectsScript.amount_text(_measure_k, _target_value)
	_places.text = _places_text()
	var full: bool = projects != null and projects.is_full()
	_form.visible = not full
	_progress_lines()


func _places_text() -> String:
	"""The places a new project would link: what is selected now."""
	if not places_into.is_valid():
		return PLACES_NONE
	var places: Array[Vector3i] = []
	var names := PackedStringArray()
	places_into.call(places, names)
	return PLACES_NONE if names.is_empty() else PLACES_SOME % ", ".join(names)


func _draw_rows() -> void:
	"""One row a project: its line, a Go to a place, Remove."""
	GuideUi.clear(_rows)
	if projects.projects.is_empty():
		_rows.add_child(GuideUi.line(EMPTY, FarmUi.SMALL_PX, Palette.UMBER, _width))
	if projects.is_full():
		_rows.add_child(GuideUi.line(FULL, FarmUi.SMALL_PX, Palette.UMBER, _width))
	for k: int in projects.projects.size():
		_rows.add_child(_row(k))


func _row(k: int) -> VBoxContainer:
	"""Project `k`'s row."""
	var project: ProjectsScript.Project = projects.projects[k]
	var row := VBoxContainer.new()
	row.add_child(GuideUi.line("", FarmUi.BODY_PX, Palette.INK, _width, true))
	var verbs: HFlowContainer = GuideUi.row(6)
	row.add_child(verbs)
	for p: int in project.place_kinds.size():
		var go: Button = FarmUi.button(GO_TO % project.place_names[p], FarmUi.SMALL_PX)
		go.pressed.connect(_go.bind(project.place_kinds[p], project.place_ids[p]))
		verbs.add_child(go)
	var remove: Button = FarmUi.button(REMOVE_TEXT, FarmUi.SMALL_PX)
	remove.pressed.connect(func() -> void: projects.remove(k); refresh())
	verbs.add_child(remove)
	return row


func _progress_lines() -> void:
	"""Each row's heading: done or not, its name, its goal and how far it has come (the village's figures now)."""
	if projects == null or world == null or facts == null:
		return
	var k: int = 0
	for row: Node in _rows.get_children():
		if k >= projects.projects.size() or not (row is VBoxContainer) or row.is_queued_for_deletion():
			continue
		var project: ProjectsScript.Project = projects.projects[k]
		var mark: String = "✓" if project.done else "◻"
		var so_far: String = PROGRESS % [ProjectsScript.amount_text(project.measure,
			projects.progress(project, world, facts)), ProjectsScript.amount_text(project.measure, project.target)]
		(row.get_child(0) as Label).text = ROW % [mark, project.name, ProjectsScript.goal_text(project.measure,
			project.target)] + " (" + ("done" if project.done else so_far) + ")"
		k += 1


func _go(kind: int, id: int) -> void:
	"""Go to one of a project's places."""
	if go_to.is_valid():
		go_to.call(kind, id)


func set_text_width(width: float) -> void:
	"""Wrap at `width`."""
	_width = width
	for line: Label in [_places, _said]:
		line.custom_minimum_size.x = width


func name_field() -> LineEdit:
	"""The new project's name field (checks)."""
	return _name


func said() -> String:
	"""The last refusal ('' when the last pin took; checks)."""
	return _said.text
