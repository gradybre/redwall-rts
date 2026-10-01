extends Node
## The village's songs (decision 0442; review SOC-026, UX-030, UX-032): the repertoire (song_book.gd, songs.json), who
## sings what when (song_circle.gd), the bubbles over the singers (song_view.gd) and a soft hum (song_hum.gd). It READS
## the residents, the kitchen, the night and the work board, and writes into none of them -- songs never block work
## or meals.
##
## A RESIDENT'S CONTEXT, worked out here a few times a second (CONTEXT_HZ), first match wins:
##   NONE     not drawn on the surface (underground, indoors, hidden), or asleep;
##   SUPPER   seated at the supper table (kitchen.gd: eating, at its seat, the meal a supper);
##   WORK     actually working, not walking to it: carrying a load, working under an order (ACTIVITY_WORKING), at
##            a kitchen step, or holding a work-board task that is WORKING or HAULING -- by day only;
##   EVENING  from EVENING_FROM_HOUR to EVENING_TO_HOUR, wandering free or walking home to bed (sleep_task.gd GOING).
## Lane 1's boats and fishing (Water part B) count as WORK through the same reads when they put a resident to work.
## DEEDS for a song's slot are what the village has recorded: each bridge it has opened ("the weir bridge") and, after
## a rescue, "the swimmer saved" (`set_deeds`); none recorded, the song's own fallback is sung.
## SETTINGS: sound_mix.gd `songs_on` (the game menu's "Residents sing") switches the singing; the Songs bus is the hum's.

const BookScript := preload("res://demo/songs/song_book.gd")
const CircleScript := preload("res://demo/songs/song_circle.gd")
const ViewScript := preload("res://demo/songs/song_view.gd")
const HumScript := preload("res://demo/songs/song_hum.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const KitchenTask := preload("res://demo/kitchen/kitchen_task.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const CONTEXT_HZ: float = 4.0
const EVENING_FROM_HOUR: int = 19
const EVENING_TO_HOUR: int = 22
const DAY_FROM_HOUR: int = 6
## A bubble stands this far over a singer's head (m).
const HEAD_GAP_M: float = 0.12
const OTTER: String = "otter"

var book: BookScript = BookScript.new()
var circle: CircleScript = CircleScript.new()
var view: ViewScript = null
var hum: HumScript = null

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _calendar: CalendarScript = null
var _kitchen: KitchenScript = null
var _board: BoardScript = null
var _notices: NoticesScript = null
var _deeds: Callable = Callable()
var _contexts: PackedByteArray = PackedByteArray()
var _positions: PackedVector2Array = PackedVector2Array()
var _heard_line: PackedInt32Array = PackedInt32Array()
## Each resident's bubble words, rebuilt only when the circle's revision moves (no string work per frame).
var _texts: PackedStringArray = PackedStringArray()
var _seen_revision: int = -1
var _since_read: float = 0.0
var _task: TaskScript = TaskScript.new()
## Who holds a board task that is WORKING or HAULING, marked in one pass over the board's rows by `read_contexts`
## (`_mark_board_working`, decision 0561).
var _board_busy: PackedByteArray = PackedByteArray()
## How many phrases have been asked of the hum (a line begun by a seen singer, songs on; checks).
var hums_asked: int = 0


func configure(cast: DemoCastScript, camera: Camera3D, calendar: CalendarScript, notices: NoticesScript) -> bool:
	"""Sing among `cast`, drawn through `camera`, on `calendar`, with song news to `notices`. False (and silent) when
	the book does not load."""
	name = "DemoSongs"
	_cast = cast
	_camera = camera
	_calendar = calendar
	_notices = notices
	if not book.load_from():
		push_warning("songs: the book refused (%s); no one sings" % book.error)
		return false
	var count: int = cast.actor_count()
	var names := PackedStringArray()
	var otters := PackedByteArray()
	for i: int in count:
		var actor := cast.actor(i) as DemoActorScript
		names.append(actor.display_name)
		otters.append(1 if is_otter(actor) else 0)
	circle.configure(book, names, otters, _post, _deed_list)
	_contexts.resize(count)
	_positions.resize(count)
	_heard_line.resize(count)
	_heard_line.fill(-1)
	_texts.resize(count)
	view = ViewScript.new()
	add_child(view)
	hum = HumScript.new()
	add_child(hum)
	hum.configure(book)
	return true


static func is_otter(actor: DemoActorScript) -> bool:
	"""Whether a resident is an otter (its species, else its creature key)."""
	return actor.species.to_lower() == OTTER or String(actor.creature_key).begins_with(OTTER)


func follow(kitchen: KitchenScript, board: BoardScript) -> void:
	"""Read the kitchen (supper seats, cooks at work) and the work board (who is working) for the contexts."""
	_kitchen = kitchen
	_board = board


func set_deeds(deeds: Callable) -> void:
	"""`deeds() -> PackedStringArray`: the village's recorded deeds for a song's slot (see DEEDS)."""
	_deeds = deeds


# --- per frame -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Read the contexts a few times a second, step the singing on real time while the game runs, and draw."""
	if _cast == null or book.size() == 0:
		return
	_since_read -= delta
	if _since_read <= 0.0:
		_since_read = 1.0 / CONTEXT_HZ
		read_contexts()
	var running: bool = _cast.clock.frame_usec > 0
	if circle.enabled != SoundMix.songs_on and not SoundMix.songs_on:
		hum.stop_all()
	circle.enabled = SoundMix.songs_on
	circle.step(int(delta * 1000000.0) if running else 0, _contexts, _positions, _day())
	draw()


func read_contexts() -> void:
	"""Every resident's context and ground position now (see A RESIDENT'S CONTEXT)."""
	var hour: int = _calendar.now().hour if _calendar != null else 12
	_mark_board_working()
	for i: int in _contexts.size():
		var actor := _cast.actor(i) as DemoActorScript
		_contexts[i] = _context(actor, i, hour, true)
		_positions[i] = actor.brain.position


func _mark_board_working() -> void:
	"""Mark in `_board_busy` every resident holding a work-board task that is WORKING or HAULING, in ONE pass over the
	board's rows -- what `_board_working` answers for one resident, for all of them at once (decision 0561: a scan per
	resident was O(residents x rows), 20-30 ms a read at 100 residents)."""
	_board_busy.resize(_contexts.size())
	_board_busy.fill(0)
	if _board == null:
		return
	for source: int in WorkIds.SOURCE_COUNT:
		var src: SourceScript = _board.source(source)
		if src == null:
			continue
		for row: int in src.capacity():
			var who: int = src.worker(row) if src.live(row) else -1
			if who >= 0 and who < _board_busy.size() and _board_busy[who] == 0 and _row_busy(source, row):
				_board_busy[who] = 1


func context_of(actor: DemoActorScript, i: int, hour: int) -> int:
	"""Resident `i`'s context at `hour` (see A RESIDENT'S CONTEXT), the board read for it alone."""
	return _context(actor, i, hour, false)


func _context(actor: DemoActorScript, i: int, hour: int, marked: bool) -> int:
	"""`context_of`, the board read from `_board_busy` when `marked` (`read_contexts`), else scanned for `i`."""
	var brain: BrainScript = actor.brain
	if not actor.visible or brain.underground or brain.indoors or brain.lying:
		return BookScript.CONTEXT_NONE
	if _at_supper(i):
		return BookScript.CONTEXT_SUPPER
	var going_home: bool = brain.task is SleepTaskScript and (brain.task as SleepTaskScript).stage == SleepTaskScript.STAGE_GOING
	if not NightScript.is_night_hour(hour) and hour >= DAY_FROM_HOUR and _working(brain, i, marked):
		return BookScript.CONTEXT_WORK
	var evening: bool = hour >= EVENING_FROM_HOUR and hour < EVENING_TO_HOUR
	if evening and (going_home or brain.activity() == BrainScript.ACTIVITY_WANDERING):
		return BookScript.CONTEXT_EVENING
	return BookScript.CONTEXT_NONE


func _at_supper(i: int) -> bool:
	"""Whether resident `i` is seated at the supper table now."""
	if _kitchen == null or _kitchen.role_of(i) != KitchenTask.ROLE_EAT:
		return false
	var at_table: bool = _kitchen.step_of(i) == KitchenTask.WORK_WAIT or _kitchen.step_of(i) == KitchenTask.WORK_EAT
	return at_table and _kitchen.meal_of(i) % 2 == MealRules.MEAL_SUPPER


func _working(brain: BrainScript, i: int, marked: bool) -> bool:
	"""Whether resident `i` is actually working now, not walking to it (see WORK); the board from the mark when
	`marked`."""
	if brain.carrying or brain.activity() == BrainScript.ACTIVITY_WORKING:
		return true
	if _kitchen != null and _kitchen.role_of(i) != KitchenTask.ROLE_EAT and _kitchen.step_of(i) >= KitchenTask.WORK_FIRST:
		return true
	if marked:
		return i >= 0 and i < _board_busy.size() and _board_busy[i] == 1
	return _board_working(i)


func _board_working(who: int) -> bool:
	"""Whether `who` holds a work-board task -- any of them -- that is WORKING or HAULING now."""
	if _board == null:
		return false
	for source: int in WorkIds.SOURCE_COUNT:
		var src: RefCounted = _board.source(source)
		if src == null:
			continue
		for row: int in src.capacity():
			if src.live(row) and src.worker(row) == who and _row_busy(source, row):
				return true
	return false


func _row_busy(source: int, row: int) -> bool:
	"""Whether the board's task in `row` of `source` is WORKING or HAULING now."""
	return _board.fill(source, row, _task) \
		and (_task.state == WorkIds.STATE_WORKING or _task.state == WorkIds.STATE_HAULING)


func draw() -> void:
	"""A bubble over each singer, and a hum when a lead starts a line."""
	if circle.revision != _seen_revision:
		_seen_revision = circle.revision
		for i: int in circle.count():
			_texts[i] = circle.bubble_text(i)
	view.begin()
	for i: int in circle.count():
		var key: int = circle.song[i] * 64 + circle.line[i] if circle.song[i] >= 0 else -1
		if _texts[i].is_empty() and key == _heard_line[i]:
			continue
		var actor := _cast.actor(i) as DemoActorScript
		var head: Vector3 = actor.position + Vector3(0.0, actor.height_m + HEAD_GAP_M, 0.0)
		if not _texts[i].is_empty() and actor.visible:
			view.show_bubble(_camera, head, _texts[i])
		if key != _heard_line[i]:
			_heard_line[i] = key
			if key >= 0 and actor.visible and SoundMix.songs_on:
				hums_asked += 1
				hum.hum(circle.song[i], head)
	view.finish()


func _day() -> int:
	"""The game day now (0 on the first), for one supper news line a day."""
	return _calendar.hour_index() / 24 if _calendar != null else 0


func _post(text: String) -> void:
	"""A routine village news line (the crew's source: the history's Village group)."""
	if _notices != null:
		_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, text)


func _deed_list() -> PackedStringArray:
	"""The village's recorded deeds (see DEEDS)."""
	return _deeds.call() as PackedStringArray if _deeds.is_valid() else PackedStringArray()
