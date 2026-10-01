extends "res://test/framework/test_case.gd"
## The village's songs (decision 0442; review SOC-026, UX-030, UX-032): the repertoire's data and its rules (an id per
## song, 4-8 lines, no line past the bubble's limit, original text), who sings what in which context, learning,
## supper's one table, the songs switch and the Songs bus, the hum's synthesis and the residents' contexts. No scene
## tree and no staged assets.

const BookScript := preload("res://demo/songs/song_book.gd")
const CircleScript := preload("res://demo/songs/song_circle.gd")
const HumScript := preload("res://demo/songs/song_hum.gd")
const SongsScript := preload("res://demo/songs/demo_songs.gd")
const ViewScript := preload("res://demo/songs/song_view.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const SettingsScript := preload("res://demo/sound/sound_settings_ui.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const KitchenTask := preload("res://demo/kitchen/kitchen_task.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")

const NONE: int = BookScript.CONTEXT_NONE
const WORK: int = BookScript.CONTEXT_WORK
const SUPPER: int = BookScript.CONTEXT_SUPPER
const EVENING: int = BookScript.CONTEXT_EVENING
const LINE: int = CircleScript.LINE_USEC
## Names that belong to the books the setting draws on: none may appear in the village's own songs (the originality
## rule's guard -- the rule itself is decision 0442's: every line is written for this demo).
const CANON_NAMES: Array[String] = ["redwall", "mossflower", "salamandastron", "martin", "mattimeo", "cluny",
	"skipper", "lutra", "marlfox", "noonvale", "brockhall", "loamhedge", "mariel", "gonff", "badgerlord"]

## One work-board task, held by `who` in `state` (the board's own adapter shape, work_source.gd).
class StubSource extends "res://demo/work/work_source.gd":
	var who: int = -1
	var state: int = 0

	func capacity() -> int:
		"""One row."""
		return 1

	func live(_row: int) -> bool:
		"""Always live."""
		return true

	func worker(_row: int) -> int:
		"""Its holder."""
		return who

	func fill(task: TaskScript, row: int) -> void:
		"""Its record: the state given."""
		task.reset(id, row)
		task.state = state


var _news: PackedStringArray = PackedStringArray()
var _nodes: Array[Node] = []


func before_each() -> void:
	"""Fresh news and the default mix."""
	_news.clear()
	SoundMix.reset()


func after_each() -> void:
	"""Free every node built; the default mix back."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	SoundMix.reset()


func _book() -> BookScript:
	"""The village's book, loaded."""
	var book := BookScript.new()
	assert_true(book.load_from(), "the book loads: %s" % book.error)
	return book


func _song_of(book: BookScript, context: int) -> int:
	"""The first song of `context`."""
	var out := PackedInt32Array()
	book.songs_for(context, out)
	return out[0]


func _circle(otters: PackedByteArray) -> CircleScript:
	"""A circle over the book among residents r0..rN, `otters[i]` 1 for an otter; news into `_news`; every first rest
	already over."""
	var names := PackedStringArray()
	for i: int in otters.size():
		names.append("r%d" % i)
	var circle := CircleScript.new()
	circle.configure(_book(), names, otters, func(text: String) -> void: _news.append(text))
	return circle


func _step(circle: CircleScript, usec: int, contexts: Array[int], day: int = 0) -> void:
	"""Step the circle with these contexts, everyone at the same spot."""
	var at := PackedVector2Array()
	at.resize(contexts.size())
	circle.step(usec, PackedByteArray(contexts), at, day)


func _settle(circle: CircleScript, contexts: Array[int]) -> void:
	"""Run past every first rest (a minute, in one step) with these contexts."""
	_step(circle, 60000000, contexts)


# --- the repertoire ------------------------------------------------------------------------------------------

func test_the_book_has_an_id_per_song_and_every_line_fits_the_bubble() -> void:
	"""Four original songs, each with its own id and title, 4-8 lines, every line within line_limit with its slot
	filled by the longest deed; a work, a supper and an evening song among them."""
	var book := _book()
	assert_equal(book.size(), 4, "four songs")
	var seen: Array[StringName] = []
	for song: int in book.size():
		assert_false(book.ids[song] == &"", "song %d has an id" % song)
		assert_false(seen.has(book.ids[song]), "%s is unique" % book.ids[song])
		seen.append(book.ids[song])
		assert_false(book.titles[song].is_empty(), "%s has a title" % book.ids[song])
		assert_true(book.line_count(song) >= 4 and book.line_count(song) <= 8, "%s: 4-8 lines" % book.ids[song])
		for k: int in book.line_count(song):
			var longest: String = book.line_text(song, k, "x".repeat(book.deed_limit))
			assert_true(longest.length() <= book.line_limit, "%s line %d fits: %d" % [book.ids[song], k + 1, longest.length()])
			assert_true(book.line_text(song, k).length() <= book.line_limit, "and with its fallback")
	for context: int in [WORK, SUPPER, EVENING]:
		var out := PackedInt32Array()
		assert_true(book.songs_for(context, out) >= 1, "a %s song" % BookScript.CONTEXT_KEYS[context])
	assert_equal(book.line_limit, 44, "the bubble's limit")


func test_no_song_names_anyone_or_anywhere_from_the_books() -> void:
	"""The originality rule's guard: no title or line carries a name from the books."""
	var book := _book()
	for song: int in book.size():
		var words: String = (book.titles[song] + " " + " ".join(book.lines[song])).to_lower()
		for name: String in CANON_NAMES:
			assert_false(words.contains(name), "%s does not name %s" % [book.ids[song], name])


func test_a_broken_book_is_refused_and_says_where() -> void:
	"""A line past the limit, a repeated id, a slot with no fallback, an unknown context or too few lines: refused,
	nothing kept."""
	var lines: Array = ["One", "Two", "Three", "Four"]
	var good := {"id": "a", "title": "A", "context": "work", "tune": [0], "beats": [1], "lines": lines}
	var book := BookScript.new()
	assert_true(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [good]}), "a good book")
	var long := good.duplicate()
	long["lines"] = ["One", "Two", "Three", "Four and more"]
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [long]}), "too long")
	assert_equal(book.error, "a line 4: 13 characters with the slot filled (limit 10)", "says where")
	assert_equal(book.size(), 0, "nothing kept")
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [good, good]}), "a repeated id")
	var slot := good.duplicate()
	slot["lines"] = ["One", "Two", "Three", "To {deed}"]
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [slot]}), "a slot with no fallback")
	slot["deed_fallback"] = "you"
	assert_true(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [slot]}), "with one: 3 + 4 fits")
	slot["deed_limit"] = 9
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 9, "songs": [slot]}), "a long deed would not fit")
	var where := good.duplicate()
	where["context"] = "battle"
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [where]}), "an unknown context")
	where.erase("context")
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [where]}), "no context")
	var short := good.duplicate()
	short["lines"] = ["One", "Two", "Three"]
	assert_false(book.load_data({"line_limit": 10, "deed_limit": 4, "songs": [short]}), "three lines")


func test_a_slot_takes_a_recorded_deed_or_the_song_s_own_fallback() -> void:
	"""Supper's last line: a recorded deed when there is one (and short enough), else 'the cook'."""
	var book := _book()
	var supper: int = _song_of(book, SUPPER)
	var last: int = book.line_count(supper) - 1
	assert_equal(book.line_text(supper, last, "the weir bridge"), "A cup for the weir bridge!", "a deed")
	assert_equal(book.line_text(supper, last), "A cup for the cook!", "the fallback")
	assert_equal(book.line_text(supper, last, "x".repeat(book.deed_limit + 1)), "A cup for the cook!", "too long: fallback")


# --- who sings, and when ----------------------------------------------------------------------------------------

func test_an_otter_sings_a_work_song_only_while_working() -> void:
	"""Rested and working, the otter leads a work song a line at a time; the mouse beside it, who knows none, does not;
	the moment the otter stops working, the song stops."""
	var circle := _circle(PackedByteArray([1, 0]))
	_settle(circle, [NONE, NONE])
	assert_equal(circle.bubble_text(0), "", "not working: silent")
	_step(circle, 1, [WORK, WORK])
	var song: int = circle.song[0]
	assert_true(song >= 0, "the otter sings")
	assert_equal(_book().contexts[song], WORK, "a work song")
	assert_equal(circle.song[1], CircleScript.NO_SONG, "the mouse knows none")
	assert_true(circle.bubble_text(0).begins_with("♪ "), "a bubble")
	_step(circle, LINE, [WORK, WORK])
	assert_equal(circle.line[0], 1, "the next line after LINE_USEC")
	_step(circle, 1, [NONE, NONE])
	assert_equal(circle.song[0], CircleScript.NO_SONG, "stopped working: the song stops")
	assert_equal(circle.bubble_text(0), "", "no bubble")


func test_each_context_sings_its_own_songs_and_never_another_s() -> void:
	"""Supper sings the supper song, evening the evening song; a song moved into another context stops."""
	var book := _book()
	for context: int in [WORK, SUPPER, EVENING]:
		var circle := _circle(PackedByteArray([1]))
		_settle(circle, [NONE])
		_step(circle, 1, [context])
		assert_equal(book.contexts[circle.song[0]], context, "%s sings its own" % BookScript.CONTEXT_KEYS[context])
		var other: int = WORK if context != WORK else SUPPER
		_step(circle, 1, [other])
		assert_equal(circle.song[0], CircleScript.NO_SONG, "%s's song stops elsewhere" % BookScript.CONTEXT_KEYS[context])


func test_nothing_is_sung_while_paused_or_out_of_context() -> void:
	"""No time (paused): a song holds its line. No context: nobody starts, however rested."""
	var circle := _circle(PackedByteArray([1]))
	_settle(circle, [NONE])
	assert_equal(circle.leads(), 0, "nobody in no context")
	_step(circle, 1, [WORK])
	_step(circle, 0, [WORK])
	_step(circle, 0, [WORK])
	assert_equal(circle.line[0], 0, "paused: the line holds")
	assert_true(circle.song[0] >= 0, "and the song stays")


func test_a_song_runs_to_its_end_then_rests() -> void:
	"""Each line LINE_USEC; after the last the singer rests at least REST_USEC before another."""
	var circle := _circle(PackedByteArray([1]))
	_settle(circle, [NONE])
	_step(circle, 1, [WORK])
	var song: int = circle.song[0]
	for k: int in _book().line_count(song):
		_step(circle, LINE, [WORK])
	assert_equal(circle.song[0], CircleScript.NO_SONG, "ended")
	_step(circle, CircleScript.REST_USEC - 1, [WORK])
	assert_equal(circle.song[0], CircleScript.NO_SONG, "still resting")


func test_at_most_two_lead_at_once() -> void:
	"""Four otters at work: two lead, two wait."""
	var circle := _circle(PackedByteArray([1, 1, 1, 1]))
	_settle(circle, [NONE, NONE, NONE, NONE])
	_step(circle, 1, [WORK, WORK, WORK, WORK])
	assert_equal(circle.leads(), CircleScript.MAX_LEADS, "two")


func test_supper_is_one_table_others_join_and_it_is_news_once_a_day() -> void:
	"""Two otters and a mouse at supper: one leads, the other otter joins ('♪ ♪'), the mouse (who does not know it) only
	listens; one news line for the day's first supper song, none for the second."""
	var circle := _circle(PackedByteArray([1, 1, 0]))
	_settle(circle, [NONE, NONE, NONE])
	_step(circle, 1, [SUPPER, SUPPER, SUPPER], 3)
	assert_equal(circle.leads(), 1, "one lead")
	assert_equal(circle.bubble_text(1), "♪ ♪", "the other otter joins")
	assert_equal(circle.bubble_text(2), "", "the mouse listens")
	assert_equal(_news, PackedStringArray(["At supper r0 led “Set the Board”, and the table joined in."]), "the news")
	for k: int in 7:
		_step(circle, LINE, [SUPPER, SUPPER, SUPPER], 3)
	assert_equal(circle.leads(), 0, "the song is over")
	assert_equal(circle.bubble_text(1), "", "and the joiner stops with it")
	_step(circle, 60000000, [SUPPER, SUPPER, SUPPER], 3)
	_step(circle, 1, [SUPPER, SUPPER, SUPPER], 3)
	assert_true(circle.leads() == 1, "a second supper song")
	assert_equal(_news.size(), 1, "the same day: no second supper line (and the mouse has heard it only once)")


func test_hearing_a_song_to_its_end_twice_teaches_it() -> void:
	"""In the evening (one evening song) the mouse 2 m from the otter hears it to its end once -- not yet learned --
	then twice, and learns it: a news line. The squirrel 30 m off learns nothing; a song cut short teaches nobody."""
	var circle := _circle(PackedByteArray([1, 0, 0]))
	var evening: int = _song_of(_book(), EVENING)
	var at := PackedVector2Array([Vector2.ZERO, Vector2(2.0, 0.0), Vector2(30.0, 0.0)])
	var out := PackedByteArray([EVENING, EVENING, EVENING])
	var none := PackedByteArray([NONE, NONE, NONE])
	circle.step(60000000, none, at, 0)
	circle.step(1, out, at, 0)
	assert_equal(circle.song[0], evening, "the otter sings the evening song")
	circle.step(LINE, none, at, 0)
	assert_equal(circle.song[0], CircleScript.NO_SONG, "cut short")
	for round: int in 2:
		circle.step(CircleScript.REST_USEC + CircleScript.REST_SPREAD_USEC, none, at, 0)
		circle.step(1, out, at, 0)
		assert_equal(circle.song[0], evening, "sung again (%d)" % round)
		for k: int in _book().line_count(evening):
			circle.step(LINE, out, at, 0)
		assert_equal(circle.song[0], CircleScript.NO_SONG, "to its end (%d)" % round)
		assert_equal(circle.knows_song(1, evening), round == 1, "learned only on the second hearing (%d)" % round)
	assert_false(circle.knows_song(2, evening), "the squirrel was too far")
	assert_equal(_news, PackedStringArray(["r1 has learned “The Heron's Hour” from the otters."]), "one news line")


func test_a_learner_sings_what_it_learned() -> void:
	"""A non-otter that knows the evening song leads it in the evening."""
	var circle := _circle(PackedByteArray([0]))
	var evening: int = _song_of(_book(), EVENING)
	circle.knows[0] = 1 << evening
	_settle(circle, [NONE])
	_step(circle, 1, [EVENING])
	assert_equal(circle.song[0], evening, "sung")
	_step(circle, 1, [WORK])
	_step(circle, CircleScript.CUT_REST_USEC, [WORK])
	_step(circle, 1, [WORK])
	assert_equal(circle.song[0], CircleScript.NO_SONG, "no work song learned: none at work")


func test_songs_off_silences_everyone_and_makes_no_news() -> void:
	"""The switch off: a song in progress stops, nobody starts, and supper makes no news."""
	var circle := _circle(PackedByteArray([1, 1]))
	_settle(circle, [NONE, NONE])
	_step(circle, 1, [WORK, NONE])
	assert_true(circle.song[0] >= 0, "singing")
	circle.enabled = false
	_step(circle, 1, [WORK, SUPPER])
	assert_equal(circle.bubble_text(0), "", "stopped")
	_step(circle, 60000000, [SUPPER, SUPPER])
	assert_equal(circle.leads(), 0, "nobody starts")
	assert_true(_news.is_empty(), "no news")


func test_the_settings_switch_and_the_songs_bus() -> void:
	"""The Settings' 'Residents sing' toggle switches SoundMix.songs_on; the Songs bus is the sixth, with its own volume
	(50 Balanced, 25 Quiet focus, 65 Atmosphere) and mute; the hum plays on it."""
	var settings := SettingsScript.new()
	_nodes.append(settings)
	assert_true(settings.songs_button().button_pressed, "on by default")
	settings.songs_button().toggled.emit(false)
	assert_false(SoundMix.songs_on, "off")
	settings.refresh()
	assert_equal(settings.songs_button().text, SettingsScript.SONGS_OFF_TEXT, "says off")
	assert_equal(SoundMix.BUS_NAMES[SoundMix.BUS_SONGS], &"Songs", "the bus")
	assert_equal(SoundMix.BALANCED_PERCENTS[SoundMix.BUS_SONGS], 50, "balanced")
	assert_equal(SoundMix.QUIET_PERCENTS[SoundMix.BUS_SONGS], 25, "quiet")
	assert_equal(SoundMix.ATMOSPHERE_PERCENTS[SoundMix.BUS_SONGS], 65, "atmosphere")
	assert_true(SoundMix.set_muted(SoundMix.BUS_SONGS, true), "the Songs bus mutes")
	assert_equal(SoundMix.muted[SoundMix.BUS_SONGS], 1, "muted")
	settings.mute_button(SoundMix.BUS_SONGS).toggled.emit(false)
	assert_equal(SoundMix.muted[SoundMix.BUS_SONGS], 0, "its row's Mute")
	SoundMix.reset()
	assert_true(SoundMix.songs_on, "reset: on")
	SoundMix.new().ensure_buses()
	var hum := HumScript.new()
	_nodes.append(hum)
	hum.configure(_book())
	assert_equal(hum.voice(0).bus, &"Songs", "the hum's bus")
	assert_equal(hum.warm(), 4, "the prewarm makes the four phrases (a count, as demo_prewarm.gd's steps return)")
	assert_true(hum.stream_of(0).data.size() > 0, "made")


# --- the hum, the bubbles and the contexts --------------------------------------------------------------------

func test_the_hum_is_synthesised_from_the_tune() -> void:
	"""A phrase of the tune's beats: its length in 16-bit samples, not silent, never clipped."""
	var wav: AudioStreamWAV = HumScript.synthesise(PackedInt32Array([0, 7]), PackedInt32Array([2, 1]))
	var samples: int = int(2.0 * HumScript.EIGHTH_S * HumScript.MIX_RATE) + int(1.0 * HumScript.EIGHTH_S * HumScript.MIX_RATE)
	assert_equal(wav.data.size(), samples * 2, "16-bit mono, the beats' length")
	assert_equal(wav.mix_rate, HumScript.MIX_RATE, "its rate")
	var loudest: int = 0
	for n: int in range(0, samples, 7):
		loudest = maxi(loudest, absi(wav.data.decode_s16(n * 2)))
	assert_true(loudest > 3000, "audible: %d" % loudest)
	assert_true(loudest < 32767, "not clipped")
	assert_equal(wav.data.decode_s16(0), 0, "it eases in from silence")


func test_the_bubbles_show_nothing_they_cannot_place() -> void:
	"""No camera in the tree: no bubble; `finish` hides the whole unused pool."""
	var view := ViewScript.new()
	_nodes.append(view)
	var camera := Camera3D.new()
	_nodes.append(camera)
	view.begin()
	assert_false(view.show_bubble(null, Vector3.ZERO, "x"), "no camera, no bubble")
	assert_false(view.show_bubble(camera, Vector3(0, 0, -5), "x"), "a camera out of the tree, none")
	view.finish()
	assert_equal(view.shown(), PackedStringArray(), "none shown")
	assert_equal(view.layer, -1, "under every panel")


func test_a_resident_s_context_follows_what_it_is_doing() -> void:
	"""Carrying by day: WORK; the same at 23:00: NONE (night); wandering at 20:00: EVENING; walking home to bed at
	21:00: EVENING; underground: NONE; an otter is known by its species."""
	var songs := SongsScript.new()
	_nodes.append(songs)
	var actor := DemoActorScript.new()
	_nodes.append(actor)
	actor.brain = BrainScript.new()
	actor.species = "Otter"
	assert_true(SongsScript.is_otter(actor), "an otter")
	actor.brain.carrying = true
	assert_equal(songs.context_of(actor, 0, 10), WORK, "carrying by day")
	assert_equal(songs.context_of(actor, 0, 23), NONE, "not at night")
	actor.brain.carrying = false
	assert_equal(songs.context_of(actor, 0, 10), NONE, "idle by day")
	assert_equal(songs.context_of(actor, 0, 20), EVENING, "wandering in the evening")
	var sleep := SleepTaskScript.new(func() -> bool: return false, func() -> bool: return false)
	sleep.stage = SleepTaskScript.STAGE_GOING
	actor.brain.task = sleep
	actor.brain.order = BrainScript.ORDER_TASK
	assert_equal(songs.context_of(actor, 0, 21), EVENING, "walking home to bed")
	sleep.stage = SleepTaskScript.STAGE_ASLEEP
	actor.brain.lying = true
	assert_equal(songs.context_of(actor, 0, 21), NONE, "asleep")
	actor.brain.task = null
	actor.brain.order = BrainScript.ORDER_NONE
	assert_equal(songs.context_of(actor, 0, 20), NONE, "lying down, even free in the evening")
	actor.brain.lying = false
	actor.brain.task = null
	actor.brain.underground = true
	actor.brain.carrying = true
	assert_equal(songs.context_of(actor, 0, 10), NONE, "underground: nobody sees a bubble")


func test_supper_seats_and_working_board_tasks_are_read_as_contexts() -> void:
	"""The kitchen's own columns: eating, at its seat, a supper key -> SUPPER; the same at breakfast -> not; walking to
	the seat -> not. The work board: a task held WORKING -> WORK, TRAVELLING -> not, a second task hauling -> WORK; the
	cook at the pot -> WORK."""
	var songs := SongsScript.new()
	_nodes.append(songs)
	var actor := DemoActorScript.new()
	_nodes.append(actor)
	actor.brain = BrainScript.new()
	var kitchen := KitchenScript.new()
	for column: PackedInt32Array in [kitchen._role, kitchen._step, kitchen._meal]:
		column.resize(1)
	kitchen._role[0] = KitchenTask.ROLE_EAT
	kitchen._step[0] = KitchenTask.WORK_EAT
	kitchen._meal[0] = 2 * 4 + 1
	var board := BoardScript.new()
	var brains: Array[BrainScript] = [actor.brain]
	board.bind(brains, PackedStringArray(["r0"]), [&"otter_fisher"] as Array[StringName])
	songs.follow(kitchen, board)
	assert_equal(songs.context_of(actor, 0, 18), SUPPER, "seated at supper")
	kitchen._meal[0] = 2 * 4
	assert_equal(songs.context_of(actor, 0, 8), NONE, "breakfast is not supper")
	kitchen._meal[0] = 2 * 4 + 1
	kitchen._step[0] = KitchenTask.WALK_SEAT
	assert_equal(songs.context_of(actor, 0, 18), NONE, "walking to the table is not at it")
	kitchen._role[0] = 0
	var farm_task := StubSource.new()
	farm_task.id = 0
	farm_task.who = 0
	farm_task.state = WorkIds.STATE_WORKING
	board.add_source(farm_task)
	assert_equal(songs.context_of(actor, 0, 10), WORK, "a working board task")
	farm_task.state = WorkIds.STATE_TRAVELLING
	assert_equal(songs.context_of(actor, 0, 10), NONE, "travelling to it is not working")
	var haul := StubSource.new()
	haul.id = 1
	haul.who = 0
	haul.state = WorkIds.STATE_HAULING
	board.add_source(haul)
	assert_equal(songs.context_of(actor, 0, 10), WORK, "any of its tasks hauling")
	haul.state = WorkIds.STATE_TRAVELLING
	kitchen._role[0] = KitchenTask.ROLE_COOK
	kitchen._step[0] = KitchenTask.WORK_COOK
	assert_equal(songs.context_of(actor, 0, 16), WORK, "the cook at the pot")


func test_a_line_begun_asks_the_hum_once_and_never_with_songs_off() -> void:
	"""Over the placeholder cast: a line begun asks one phrase; the same line again, none; the next line, one more;
	songs off, none."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	var camera := Camera3D.new()
	_nodes.append(camera)
	var songs := SongsScript.new()
	_nodes.append(songs)
	assert_true(songs.configure(cast, camera, null, null), "configured")
	songs.circle.song[0] = 0
	songs.circle.revision += 1
	songs.draw()
	assert_equal(songs.hums_asked, 1, "the first line")
	songs.draw()
	assert_equal(songs.hums_asked, 1, "not again for the same line")
	songs.circle.line[0] = 1
	songs.circle.revision += 1
	songs.draw()
	assert_equal(songs.hums_asked, 2, "the next line")
	SoundMix.songs_on = false
	songs.circle.line[0] = 2
	songs.circle.revision += 1
	songs.draw()
	assert_equal(songs.hums_asked, 2, "songs off: no hum")


func test_the_songs_bus_is_muffled_underground_like_the_world_above() -> void:
	"""The U view low-passes the Songs bus with the world above; off again above."""
	var mix := SoundMix.new()
	mix.ensure_buses()
	mix.underground = true
	mix.apply()
	assert_true(SoundMix.filtered(&"Songs"), "muffled in the U view")
	mix.underground = false
	mix.apply()
	assert_false(SoundMix.filtered(&"Songs"), "clear above")


func test_a_learner_teaches_in_its_own_name() -> void:
	"""A mouse who knows the evening song sings it to its end twice beside a squirrel: the squirrel learns it from the
	mouse, by name -- not 'from the otters'."""
	var circle := _circle(PackedByteArray([0, 0]))
	var evening: int = _song_of(_book(), EVENING)
	circle.knows[0] = 1 << evening
	var at := PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0)])
	var none := PackedByteArray([NONE, NONE])
	var out := PackedByteArray([EVENING, NONE])
	var listening := PackedByteArray([EVENING, EVENING])
	circle.step(60000000, none, at, 0)
	for round: int in 2:
		circle.step(1, out, at, 0)
		for k: int in _book().line_count(evening):
			circle.step(LINE, listening, at, 0)
		circle.step(CircleScript.REST_USEC + CircleScript.REST_SPREAD_USEC, none, at, 0)
	assert_true(circle.knows_song(1, evening), "learned")
	assert_equal(_news, PackedStringArray(["r1 has learned “The Heron's Hour” from r0."]), "from the mouse, by name")
