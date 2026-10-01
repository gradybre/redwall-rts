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
##
## THE SCALE, THE PROBE AND THE COMPARED LAYER (decision 0581). A row also carries its legend's SCALE -- which swatches
## form an ordered ramp (`ramp_from`, `ramp_count`), a threshold line per ramp entry with its units (`ticks`), and what
## the ramp measures (`caption`) -- which swatches are AREAS (`areas`: the classes its probe reads and the outlines
## trace; the ramp's by default), the ground its areas are painted over (`over`, for the colour check), and an
## optional PROBE (demo/lenses/lens_probe.gd) that says what lies at a ground point: the hover readout asks the active
## lens's probe, and a lens whose probe can be outlined may be COMPARED -- `compare`, a second lens drawn only as
## outlines of its areas over the active one (demo/lenses/lens_contours.gd), never with its own marks, so the ONE
## AT A TIME rule above still holds for marks. `compare` is OFF whenever there is no active lens, when the active lens
## is a followed one (the U view draws no surface marks), when it would be the active lens itself, or when the active
## lens changes to it. A whole layer can be added as one record
## (`add_def`, demo/lenses/lens_def.gd).

const SubjectScript := preload("res://demo/lens_subject.gd")
const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const DefScript := preload("res://demo/lenses/lens_def.gd")
const Palette := preload("res://demo/lenses/lens_palette.gd")

const OFF: int = 0

## The lens shown now (OFF: none), and a count that moves whenever it or a row changes.
var active: int = OFF
var revision: int = 0
## The lens outlined over the active one (OFF: none; see THE COMPARED LAYER).
var compare: int = OFF

var _groups: PackedStringArray = PackedStringArray([""])
var _labels: PackedStringArray = PackedStringArray(["Off"])
var _questions: PackedStringArray = PackedStringArray(["No map layer: the village as it is."])
var _shows: Array[Callable] = [Callable()]
var _states: Array[Callable] = [Callable()]
var _on_cycle: PackedByteArray = PackedByteArray([1])
var _swatches: Array[PackedColorArray] = [PackedColorArray()]
var _words: Array[PackedStringArray] = [PackedStringArray()]
var _subjects: Array[SubjectScript] = [SubjectScript.new()]
var _ramp_from: PackedInt32Array = PackedInt32Array([0])
var _ramp_count: PackedInt32Array = PackedInt32Array([0])
var _ticks: Array[PackedStringArray] = [PackedStringArray()]
var _captions: PackedStringArray = PackedStringArray([""])
var _over: PackedColorArray = PackedColorArray([Palette.OVER_GRASS])
var _probes: Array[ProbeScript] = [null]
var _areas: Array[PackedInt32Array] = [PackedInt32Array()]


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
	_ramp_from.append(0)
	_ramp_count.append(0)
	_ticks.append(PackedStringArray())
	_captions.append("")
	_over.append(Palette.OVER_GRASS)
	_probes.append(null)
	_areas.append(PackedInt32Array())
	revision += 1
	return _labels.size() - 1


func add_def(def: DefScript) -> int:
	"""A whole layer from one record (demo/lenses/lens_def.gd): on V's cycle unless it follows an outside switch.
	Returns its row."""
	var lens: int = add(def.group, def.label, def.question, def.show)
	set_legend(lens, def.swatches, def.words)
	set_scale(lens, def.ramp_from, def.ramp_count, def.ticks, def.caption, def.over)
	set_probe(lens, def.probe)
	if not def.areas.is_empty():
		set_areas(lens, def.areas)
	if def.subject != null:
		set_subject(lens, def.subject)
	if def.follow.is_valid():
		follow_state(lens, def.follow)
	return lens


func find(group: String, label: String) -> int:
	"""The row of the lens with this group and label; OFF when there is none."""
	for lens: int in range(1, count()):
		if _groups[lens] == group and _labels[lens] == label:
			return lens
	return OFF


func set_scale(lens: int, ramp_from: int, ramp_count: int, ticks: PackedStringArray, caption: String,
		over: Color = Palette.OVER_GRASS) -> void:
	"""A lens's legend scale: swatches `ramp_from` .. + `ramp_count` form its ordered ramp (0: keys only), with a
	threshold line each (`ticks`) and what it measures (`caption`); `over` is the ground its areas lie on."""
	_ramp_from[lens] = ramp_from
	_ramp_count[lens] = ramp_count
	_ticks[lens] = ticks
	_captions[lens] = caption
	_over[lens] = over
	revision += 1


func set_areas(lens: int, entries: PackedInt32Array) -> void:
	"""Which of a lens's swatches are areas (the classes its probe reads); empty: its ramp's."""
	_areas[lens] = entries
	revision += 1


func set_ticks(lens: int, ticks: PackedStringArray, caption: String) -> void:
	"""Replace a lens's threshold lines and caption (a subject's own depths); unchanged ones change nothing."""
	if ticks == _ticks[lens] and caption == _captions[lens]:
		return
	_ticks[lens] = ticks
	_captions[lens] = caption
	revision += 1


func set_probe(lens: int, probe: ProbeScript) -> void:
	"""What a lens says about a ground point (null: nothing -- no readout, not comparable)."""
	_probes[lens] = probe
	_settle_compare()
	revision += 1


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


func ramp_from_of(lens: int) -> int:
	"""The first swatch of a lens's ordered ramp."""
	return _ramp_from[lens]


func ramp_count_of(lens: int) -> int:
	"""How many swatches form a lens's ordered ramp (0: keys only)."""
	return _ramp_count[lens]


func ticks_of(lens: int) -> PackedStringArray:
	"""A lens's threshold lines, one per ramp entry."""
	return _ticks[lens]


func caption_of(lens: int) -> String:
	"""What a lens's ramp measures, with its units."""
	return _captions[lens]


func over_of(lens: int) -> Color:
	"""The ground a lens's areas are painted over."""
	return _over[lens]


func area_entries(lens: int) -> PackedInt32Array:
	"""Which of a lens's swatches are areas: as set, else its ramp's."""
	if not _areas[lens].is_empty():
		return _areas[lens]
	var out := PackedInt32Array()
	for k: int in _ramp_count[lens]:
		out.append(_ramp_from[lens] + k)
	return out


func area_colours(lens: int) -> PackedColorArray:
	"""A lens's area colours, for the colour check (entries past its swatches are skipped)."""
	var out := PackedColorArray()
	for k: int in area_entries(lens):
		if k < _swatches[lens].size():
			out.append(_swatches[lens][k])
	return out


func area_words(lens: int) -> PackedStringArray:
	"""A lens's area words, one per area colour."""
	var out := PackedStringArray()
	for k: int in area_entries(lens):
		if k < _swatches[lens].size():
			out.append(_words[lens][k] if k < _words[lens].size() else "")
	return out


func probe_of(lens: int) -> ProbeScript:
	"""A lens's probe (null: none)."""
	return _probes[lens] if lens >= OFF and lens < count() else null


func can_compare(lens: int) -> bool:
	"""Whether `lens` can be outlined over another (its probe can outline)."""
	var probe: ProbeScript = probe_of(lens)
	return lens > OFF and probe != null and probe.can_outline()


func is_compare_candidate(lens: int) -> bool:
	"""Whether `lens` may be compared with the active lens now: one is shown -- not a followed lens (the Underground's
	own view hides the surface's marks) -- and `lens` is another that outlines."""
	return active != OFF and not _states[active].is_valid() and lens != active and can_compare(lens)


func set_compare(lens: int) -> int:
	"""Outline `lens` over the active one (OFF, or a lens that may not be compared now: none). Returns the compared
	lens now."""
	compare = lens if is_compare_candidate(lens) else OFF
	revision += 1
	return compare


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
	_settle_compare()
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
			_settle_compare()
			revision += 1
			return true
		if not on and active == lens:
			active = OFF
			_settle_compare()
			revision += 1
			return true
	return false


func _settle_compare() -> void:
	"""No compared lens unless it may still be compared with the active one (see THE COMPARED LAYER)."""
	if compare != OFF and not is_compare_candidate(compare):
		compare = OFF


func _hide_all_but(lens: int) -> void:
	"""Switch every lens but `lens` off."""
	for other: int in range(1, count()):
		if other != lens:
			_shows[other].call(false)
