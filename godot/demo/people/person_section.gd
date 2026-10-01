extends VBoxContainer
## THE RESIDENT INSPECTOR'S PERSON (decision 0491, review P6): the part of the party panel's one-resident inspector that
## is about the resident as a person, under what it is doing. DEMO UI over demo_people.gd `inspector_info`.
##
## Always shown: its SKILLS, each "Felling · Level 3" over a meter of its progress toward the next level (the XP its
## real work earned, §5.3's curve; a skill at the top says so) -- the learned skill, which the panel's own abilities
## lines (what its body clears, what it may not do) keep apart. Then ONE button, "About Wenna ▸": the details stay
## optional (P6: "selection does not show every statistic at once"). Opened, it shows the person's interest, its
## evening line while that is true, its relationships (a few light lines from what actually happened), the notable
## pin, and its NOTABLE MOMENTS, newest first: each its words, wrapped whole ("Spring 4 · Built the neck bridge"), over
## "Go to" (its place) and a button for the other person in it ("Tobit Highbough") that goes to them. Rows are pooled
## and re-worded in place (a focus or a tooltip survives a refresh). Text is at least 14 px, buttons at least 32 px.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

## A moment's place or person was pressed: go to it (demo_news_jump.gd `jump`).
signal go_to(kind: int, id: int)
## The notable pin was pressed: `who` pinned (`on`) or unpinned.
signal notable_pressed(who: int, on: bool)

const BODY_PX: int = 15
const SMALL_PX: int = 14
const METER_H: float = 6.0
const SKILL: String = "%s · Level %d"
const SKILL_TOP: String = "%s · Level %d (the top)"
const SKILLS: String = "Skills"
const ABOUT_CLOSED: String = "About %s ▸"
const ABOUT_OPEN: String = "About %s ▾"
const ABOUT_TIP: String = "Who this resident is: interest, relationships and notable moments"
const PIN: String = "Pin as notable"
const PIN_TIP: String = "Mark this resident notable: ★ in the roster. Nothing about the work changes"
const UNPIN: String = "Notable ★ — unpin"
const MOMENTS: String = "Notable moments"
const NO_MOMENTS: String = "Nothing notable yet: moments are kept as they happen"
const MOMENT: String = "%s · %s"
const CHRONICLED: String = " · in the chronicle"
const GO_TO: String = "Go to"
const GO_TO_TIP: String = "Go to the place"
const PERSON_TIP: String = "Go to %s"

var about_open: bool = false
var _width: float = 260.0
var _who: int = -1
var _notable: bool = false
var _skills_head: Label = null
var _skill_box: VBoxContainer = null
var _skill_labels: Array[Label] = []
var _skill_fills: Array[ColorRect] = []
var _about: Button = null
var _about_box: VBoxContainer = null
var _interest: Label = null
var _evening: Label = null
var _relations: Label = null
var _pin: Button = null
var _moments_head: Label = null
var _moment_box: VBoxContainer = null
var _moment_texts: Array[Label] = []
var _moment_rows: Array[Button] = []
var _moment_people: Array[Button] = []
var _moment_place: PackedInt32Array = PackedInt32Array()
var _moment_other: PackedInt32Array = PackedInt32Array()
var _shown_moments: int = 0
var _first: String = ""


func build(width: float) -> void:
	"""The section's widgets at this text width (logical px), hidden until a person is shown."""
	if _about != null:
		return
	name = "Person"
	_width = width
	add_theme_constant_override(&"separation", 4)
	_skills_head = _label(SKILLS, SMALL_PX, Palette.UMBER)
	add_child(_skills_head)
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override(&"separation", 2)
	add_child(_skill_box)
	_about = FarmUi.button("", SMALL_PX)
	_about.tooltip_text = ABOUT_TIP
	_about.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_about.pressed.connect(toggle_about)
	add_child(_about)
	_build_about()
	visible = false


func _build_about() -> void:
	"""The optional details: interest, evening line, relationships, the notable pin and the moments."""
	_about_box = VBoxContainer.new()
	_about_box.add_theme_constant_override(&"separation", 4)
	_about_box.visible = false
	add_child(_about_box)
	_interest = _label("", SMALL_PX, Palette.INK)
	_evening = _label("", SMALL_PX, Palette.UMBER)
	_relations = _label("", SMALL_PX, Palette.INK)
	_pin = FarmUi.button(PIN, SMALL_PX)
	_pin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pin.pressed.connect(func() -> void: notable_pressed.emit(_who, not _notable))
	_moments_head = _label(MOMENTS, SMALL_PX, Palette.UMBER)
	_moment_box = VBoxContainer.new()
	_moment_box.add_theme_constant_override(&"separation", 1)
	for part: Control in [_interest, _evening, _relations, _pin, _moments_head, _moment_box]:
		_about_box.add_child(part)


func _label(text: String, px: int, colour: Color) -> Label:
	"""A wrapping line at the section's width."""
	var line: Label = FarmUi.label(text, px, colour)
	line.custom_minimum_size.x = _width
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func show_person(info: Dictionary) -> void:
	"""Show this person (demo_people.gd `inspector_info`); an empty one hides the section."""
	visible = not info.is_empty()
	if not visible:
		_who = -1
		return
	if int(info["who"]) != _who:
		about_open = false
	_who = int(info["who"])
	_first = String(info.get("first", ""))
	_notable = bool(info.get("notable", false))
	_show_skills(info.get("skills", []))
	_about.text = (ABOUT_OPEN if about_open else ABOUT_CLOSED) % (_first if not _first.is_empty() else "them")
	_about_box.visible = about_open
	_set_line(_interest, String(info.get("interest", "")))
	_set_line(_evening, String(info.get("evening", "")))
	_set_line(_relations, "\n".join(info.get("relations", PackedStringArray())))
	_pin.text = UNPIN if _notable else PIN
	_pin.tooltip_text = PIN_TIP
	_show_moments(info.get("moments", []))


static func _set_line(line: Label, text: String) -> void:
	"""Re-word a line only when its words changed; hidden when empty."""
	if line.text != text:
		line.text = text
	line.visible = not text.is_empty()


func _show_skills(rows: Array) -> void:
	"""Each skill's line and meter (pooled)."""
	while _skill_labels.size() < rows.size():
		_add_skill_row()
	for k: int in _skill_labels.size():
		var shown: bool = k < rows.size()
		_skill_labels[k].get_parent().visible = shown
		if not shown:
			continue
		var row: Dictionary = rows[k]
		var words: String = (SKILL_TOP if bool(row["top"]) else SKILL) % [row["name"], row["level"]]
		if _skill_labels[k].text != words:
			_skill_labels[k].text = words
		_skill_fills[k].anchor_right = float(int(row["permille"])) / 1000.0
	_skills_head.visible = not rows.is_empty()


func _add_skill_row() -> void:
	"""One skill's line over its meter: a track and its fill (anchored to the progress)."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var line: Label = _label("", SMALL_PX, Palette.INK)
	row.add_child(line)
	var track := ColorRect.new()
	track.color = Color(Palette.UMBER, 0.22)
	track.custom_minimum_size = Vector2(_width, METER_H)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.LEAF
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	track.add_child(fill)
	row.add_child(track)
	_skill_box.add_child(row)
	_skill_labels.append(line)
	_skill_fills.append(fill)


func _show_moments(moments: Array) -> void:
	"""The moments' rows (pooled): its words going to its place, and the other person's button."""
	_shown_moments = moments.size()
	_moment_place.resize(_shown_moments * 2)
	_moment_other.resize(_shown_moments)
	while _moment_rows.size() < _shown_moments:
		_add_moment_row()
	for k: int in _moment_rows.size():
		var shown: bool = k < _shown_moments
		_moment_texts[k].get_parent().visible = shown
		if shown:
			_word_moment(k, moments[k])
	_moments_head.text = MOMENTS if _shown_moments > 0 else NO_MOMENTS


func _word_moment(k: int, moment: Dictionary) -> void:
	"""Moment row `k`: "Spring 4 · Built the neck bridge", its place, and its other person (when not its place)."""
	var text: String = MOMENT % [moment["day"], moment["text"]] + (CHRONICLED if bool(moment["chronicled"]) else "")
	if _moment_texts[k].text != text:
		_moment_texts[k].text = text
	_moment_place[k * 2] = int(moment["place_kind"])
	_moment_place[k * 2 + 1] = int(moment["place_id"])
	_moment_rows[k].visible = int(moment["place_kind"]) != NoticesScript.TARGET_NONE
	var other: int = int(moment["other"])
	var same: bool = int(moment["place_kind"]) == NoticesScript.TARGET_RESIDENT and int(moment["place_id"]) == other
	_moment_other[k] = other
	_moment_people[k].visible = other >= 0 and not same
	_moment_people[k].text = String(moment["other_name"])
	_moment_people[k].tooltip_text = PERSON_TIP % moment["other_name"]


func _add_moment_row() -> void:
	"""One moment's row: its words, wrapped, over Go to (its place) and the other person's button."""
	var k: int = _moment_rows.size()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	var words: Label = _label("", SMALL_PX, Palette.INK)
	box.add_child(words)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override(&"h_separation", 6)
	buttons.add_theme_constant_override(&"v_separation", 4)
	var row: Button = FarmUi.button(GO_TO, SMALL_PX)
	row.tooltip_text = GO_TO_TIP
	row.pressed.connect(_on_place.bind(k))
	buttons.add_child(row)
	var person: Button = FarmUi.button("", SMALL_PX)
	person.pressed.connect(_on_person.bind(k))
	buttons.add_child(person)
	box.add_child(buttons)
	_moment_box.add_child(box)
	_moment_texts.append(words)
	_moment_rows.append(row)
	_moment_people.append(person)


func _on_place(k: int) -> void:
	"""Moment `k`'s row: go to its place."""
	if k < _shown_moments:
		go_to.emit(_moment_place[k * 2], _moment_place[k * 2 + 1])


func _on_person(k: int) -> void:
	"""Moment `k`'s person: go to them."""
	if k < _shown_moments and _moment_other[k] >= 0:
		go_to.emit(NoticesScript.TARGET_RESIDENT, _moment_other[k])


func toggle_about() -> void:
	"""Open or close the optional details."""
	about_open = not about_open
	_about_box.visible = about_open
	_about.text = (ABOUT_OPEN if about_open else ABOUT_CLOSED) % (_first if not _first.is_empty() else "them")


# --- checks -----------------------------------------------------------------------------------------------

func about_button() -> Button:
	"""The About toggle."""
	return _about


func pin_button() -> Button:
	"""The notable pin."""
	return _pin


func skill_line(k: int) -> String:
	"""Skill row `k`'s words ("" when not shown)."""
	return _skill_labels[k].text if k < _skill_labels.size() and _skill_labels[k].get_parent().visible else ""


func skill_fill(k: int) -> float:
	"""Skill row `k`'s meter fill (0..1)."""
	return _skill_fills[k].anchor_right if k < _skill_fills.size() else 0.0


func moment_row(k: int) -> Button:
	"""Moment `k`'s Go to (its place; null when not shown)."""
	return _moment_rows[k] if k < _shown_moments else null


func moment_text(k: int) -> String:
	"""Moment `k`'s words ("" when not shown)."""
	return _moment_texts[k].text if k < _shown_moments else ""


func moment_person(k: int) -> Button:
	"""Moment row `k`'s person button (null when not shown)."""
	return _moment_people[k] if k < _shown_moments else null


func moment_count() -> int:
	"""How many moments are listed."""
	return _shown_moments


func relations_text() -> String:
	"""The relationship lines as shown ("" when none)."""
	return _relations.text if _relations.visible else ""


func interest_text() -> String:
	"""The interest line ("" when none)."""
	return _interest.text if _interest.visible else ""
