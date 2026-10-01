extends RefCounted
## The village's map layers ("lenses"), one question each, one shown at a time. Decision 0292 (the
## review's F47 and UX-009). Presentation only: it switches what is drawn and writes no game state.
##
## A LENS is a row: its group (the planning question it belongs to -- Growing, Getting there, Woods,
## Underground), its label, its ONE question, a small legend (swatches and words), an optional subject
## (demo/lens_subject.gd: whose water range), and its switch `show(on: bool)`. Row 0 is OFF.
##
## ONE AT A TIME. `select(lens)` switches every other lens off first and then that one on, so no two
## layers' marks ever share the map (no crop + water + forest text at once). The picker
## (demo/ui/demo_lens_picker.gd) selects directly; V (demo_farm.gd) steps the same `active` through the
## lenses on V's cycle (`cycle`): off -> each cycle lens in order -> off. A lens with an outside switch of
## its own (Underground: U toggles the view) is FOLLOWED (`follow_state`): it is off V's cycle, and
## `sync` adopts what its switch says -- U pressed makes it the active lens and turns the others off; U
## pressed again leaves no lens. V from such a lens goes to the first cycle lens. So the picker, V and U
## always agree on the one active lens.

const SubjectScript := preload("res://demo/lens_subject.gd")

const OFF: int = 0

## The lens shown now (OFF: none), and a count that moves whenever it or a row changes.
var active: int = OFF
var revision: int = 0

var _groups: PackedStringArray = PackedStringArray([""])
var _labels: PackedStringArray = PackedStringArray(["Off"])
var _questions: PackedStringArray = PackedStringArray(["No map layer: the village as it is."])
var _shows: Array[Callable] = [Callable()]
var _states: Array[Callable] = [Callable()]
var _on_cycle: PackedByteArray = PackedByteArray([1])
var _swatches: Array[PackedColorArray] = [PackedColorArray()]
var _words: Array[PackedStringArray] = [PackedStringArray()]
var _subjects: Array[SubjectScript] = [SubjectScript.new()]


func add(group: String, label: String, question: String, show: Callable) -> int:
	"""A lens on V's cycle, after those already added: `show(on: bool)` switches its marks. Returns its
	row."""
	_groups.append(group)
	_labels.append(label)
	_questions.append(question)
	_shows.append(show)
	_states.append(Callable())
	_on_cycle.append(1)
	_swatches.append(PackedColorArray())
	_words.append(PackedStringArray())
	_subjects.append(_subjects[OFF])
	revision += 1
	return _labels.size() - 1


func set_legend(lens: int, swatches: PackedColorArray, words: PackedStringArray) -> void:
	"""A lens's legend: one word or phrase per swatch (a swatch with alpha 0 is words only)."""
	_swatches[lens] = swatches
	_words[lens] = words
	revision += 1


func set_subject(lens: int, subject: SubjectScript) -> void:
	"""Whom a lens is drawn for (see demo/lens_subject.gd)."""
	_subjects[lens] = subject
	revision += 1


func follow_state(lens: int, state: Callable) -> void:
	"""A lens with its own outside switch (`state() -> bool` says whether it is on): off V's cycle, and
	followed by `sync` (see ONE AT A TIME)."""
	_states[lens] = state
	_on_cycle[lens] = 0
	revision += 1


func count() -> int:
	"""How many rows, OFF included."""
	return _labels.size()


func label_of(lens: int) -> String:
	"""A lens's own label ('Water range')."""
	return _labels[lens]


func group_of(lens: int) -> String:
	"""A lens's group: the planning question it answers ('Getting there')."""
	return _groups[lens]


func title_of(lens: int) -> String:
	"""'Getting there: Water range' (OFF: 'Off')."""
	return _labels[lens] if _groups[lens].is_empty() else "%s: %s" % [_groups[lens], _labels[lens]]


func question_of(lens: int) -> String:
	"""A lens's one question."""
	return _questions[lens]


func swatches_of(lens: int) -> PackedColorArray:
	"""A lens's legend swatches."""
	return _swatches[lens]


func words_of(lens: int) -> PackedStringArray:
	"""A lens's legend words, one per swatch."""
	return _words[lens]


func subject_of(lens: int) -> SubjectScript:
	"""Whom a lens is drawn for (the base subject: nobody in particular)."""
	return _subjects[lens]


func is_on_cycle(lens: int) -> bool:
	"""Whether V reaches this lens."""
	return _on_cycle[lens] == 1


func select(lens: int) -> int:
	"""Show `lens` alone (anything not a row: OFF): every other lens off first, then it on. Returns the
	lens now active."""
	var chosen: int = lens if lens > OFF and lens < count() else OFF
	_hide_all_but(chosen)
	if chosen != OFF:
		_shows[chosen].call(true)
	active = chosen
	revision += 1
	return active


func turn_off() -> void:
	"""No lens."""
	select(OFF)


func cycle() -> int:
	"""V: the next lens on V's cycle after the active one (from OFF or a followed lens: the first), back to
	OFF after the last. Returns the lens now active."""
	var start: int = active if is_on_cycle(active) else OFF
	var next: int = (start + 1) % count()
	while next != OFF and not is_on_cycle(next):
		next = (next + 1) % count()
	return select(next)


func sync() -> bool:
	"""Adopt what each followed lens's own switch says (see ONE AT A TIME). Returns whether the active lens
	changed."""
	for lens: int in count():
		if not _states[lens].is_valid():
			continue
		var on: bool = _states[lens].call()
		if on and active != lens:
			_hide_all_but(lens)
			active = lens
			revision += 1
			return true
		if not on and active == lens:
			active = OFF
			revision += 1
			return true
	return false


func _hide_all_but(lens: int) -> void:
	"""Switch every lens but `lens` off."""
	for other: int in range(1, count()):
		if other != lens:
			_shows[other].call(false)
