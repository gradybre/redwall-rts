extends RefCounted
## The live demo's EVENT MAP: which completed gameplay and presentation events make which sound. Decision 0351
## (review F43, P8, UX-029). Presentation only: it READS the demo's models once a frame and writes nothing to
## them -- so no sound, and no animation, can award anything (P8: "Animation events never award resources").
##
## It does not hook the models' code. Each source is watched for an EDGE in state the model has already
## committed, and only that edge sounds:
##   pickup / drop     a resident's carry starting / ending (resident_brain.gd `carrying`): the load is in its
##                     arms / has left them
##   water_in / out    a resident entering / leaving the water (`in_water`)
##   splash            a resident starting to swim or dive (swim_state.gd `mode`)
##   step_*            each STRIDE_M actually walked, by the ground under it: tunnel (below), wade (wading),
##                     wood (on a bridge's crossing leg), dirt (a worn path, world_layout.gd), else grass; none
##                     while swimming
##   chop / gnaw / dig / saw   each whole STRIKE_USEC / STROKE_USEC of a woods work step that has begun
##                     (forest_jobs.gd `issued`) -- felling, grubbing a stump, sawing; never a walk to it
##   tree_fall         a tree gone from standing to a stump (felled) or straight to cleared (blown down:
##                     forest_stand.gd `blow_down_into`)
##   dig               each dig quantum CUT (underground_graph.gd `cut_count`), at the digger, below
##   complete          a tunnel or room segment opening (DIGGING -> OPEN), a bridge opening (PLANNED -> OPEN)
##   warning           a NEW announced row in the notice feed of the NORMAL or URGENT tier (demo_notices.gd: a new
##                     entry id, `is_new_since`); a repeat it folds or groups into an existing row (×2) is not new,
##                     so it does not chime again (UI §7), and a row the toast budget or a snooze kept quiet does not
##                     chime -- or a CRITICAL incident raised or come back (demo_incidents.gd `incident_cue`,
##                     CUE_CRITICAL_RAISED; decision 0331's sound hook), which a merged repeat never sends. One chime a
##                     frame at most, so an incident that also posts its warning row is heard once. THE TIERS SOUND
##                     APART (decision 0591), from the cues the table has: INFO is silent (UI §7's chime is optional),
##                     NORMAL chimes once, URGENT -- a critical incident, or an urgent row -- chimes and chimes again
##                     URGENT_ECHO_MSEC later (just past the cue's own gap, so the voice takes it).
## Ambience is a level, not an edge: wind and rain from the weather's condition, the stream from the nearest
## bank to the listener; read every AMBIENCE_MS.
##
## OUTPUT. `poll` writes its events into fixed columns (`event_count` of them, at most MAX_EVENTS a frame) for
## the director (sound_director.gd) to play; nothing is allocated per frame. A source left unbound (null) is
## skipped, so a suite can watch one source alone.

const SoundTable := preload("res://demo/sound/sound_table.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const SkillsScript := preload("res://demo/forestry/forest_skills.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WorldLayout := preload("res://demo/world/world_layout.gd")

## The cues the map sounds, by C_* (resolved to table rows by `bind_table`; a cue missing from the table is
## simply never sounded).
const CUE_IDS: Array[StringName] = [&"chop", &"gnaw", &"saw", &"dig", &"tree_fall", &"pickup", &"drop",
	&"step_grass", &"step_dirt", &"step_wood", &"step_tunnel", &"step_wade", &"splash", &"water_in", &"water_out",
	&"warning", &"complete"]
const C_CHOP: int = 0
const C_GNAW: int = 1
const C_SAW: int = 2
const C_DIG: int = 3
const C_TREE_FALL: int = 4
const C_PICKUP: int = 5
const C_DROP: int = 6
const C_STEP_GRASS: int = 7
const C_STEP_DIRT: int = 8
const C_STEP_WOOD: int = 9
const C_STEP_TUNNEL: int = 10
const C_STEP_WADE: int = 11
const C_SPLASH: int = 12
const C_WATER_IN: int = 13
const C_WATER_OUT: int = 14
const C_WARNING: int = 15
const C_COMPLETE: int = 16

const MAX_EVENTS: int = 64
## An urgent notice's second chime, this long (real milliseconds) after its first (see warning).
const URGENT_ECHO_MSEC: int = 1600
## A footstep every this many metres walked (demo: a mouse's stride at the walk clip).
const STRIDE_M: float = 0.45
## A move longer than this in one frame is a placement, not a walk: no footsteps for it.
const JUMP_M: float = 3.0
## A felling or grubbing strike every this much demo time of the work; a saw stroke every STROKE_USEC.
const STRIKE_USEC: int = 650000
const STROKE_USEC: int = 800000
const AMBIENCE_MS: int = 250
## The nearest bank (a search of every shore sample, ~0.1 ms) is found again only once the listener has moved
## this far since it was last found.
const BANK_REFRESH_M: float = 1.0
## The worn paths as a grid of GROUND_CELL_M cells over ±GROUND_HALF_M (built once, in the boot prewarm:
## world_layout.gd's `path_distance` costs a few microseconds a call, too dear for every footstep of a crowd).
const GROUND_HALF_M: float = 24.0
const GROUND_CELL_M: float = 0.75
const GROUND_SIDE: int = 64
## Ambience levels (per mille of each loop's table volume) by the weather's condition (COND_*).
const WIND_BY_CONDITION: PackedInt32Array = [300, 550, 600, 250]
const RAIN_SHOWER: int = 700
const RAIN_DOWNPOUR: int = 1000

var brains: Array[BrainScript] = []
var swim: SwimStateScript = null
var jobs: JobsScript = null
var skills: SkillsScript = null
var stand: StandScript = null
var network: GraphScript = null
var bridges: BridgesScript = null
var notices: NoticesScript = null
var incidents: IncidentsScript = null
var weather: WeatherScript = null
var water_map: WaterMapScript = null
## Water part B's fishery (demo/fishery/fishery.gd; decision 0431): its committed splashes (a net or trap set, a boat
## pushing off, a hole cut in the ice) and its boats' oars -- a wood knock (the existing `step_wood` cue: oar on
## rowlock) every OAR_STROKE_U a boat rows. Untyped, so the sound owns no dependency on the fishery.
var fishery: RefCounted = null
## A boat's oars knock once every this much rowing (u, 1.2 m: a stroke).
const OAR_STROKE_U: int = 1229
var _oar_u: PackedInt32Array = PackedInt32Array()
var _oar_progress: PackedInt32Array = PackedInt32Array()

## This frame's events: cue row, where (world metres), whether below ground.
var event_count: int = 0
var event_row: PackedInt32Array = PackedInt32Array()
var event_at: PackedVector3Array = PackedVector3Array()
var event_below: PackedByteArray = PackedByteArray()
## Events past MAX_EVENTS in a frame (dropped; the cost report).
var overflow: int = 0
## Ambience levels (per mille) and where the stream is heard from.
var wind_permille: int = 0
var rain_permille: int = 0
var stream_permille: int = 0
var stream_at: Vector3 = Vector3.ZERO

var _cue: PackedInt32Array = PackedInt32Array()
var _was_carrying: PackedByteArray = PackedByteArray()
var _was_in_water: PackedByteArray = PackedByteArray()
var _was_mode: PackedByteArray = PackedByteArray()
var _walked_m: PackedFloat32Array = PackedFloat32Array()
var _last_at: PackedVector2Array = PackedVector2Array()
var _job_step: PackedInt32Array = PackedInt32Array()
var _job_beats: PackedInt64Array = PackedInt64Array()
var _tree_state: PackedByteArray = PackedByteArray()
var _stand_revision: int = -1
var _seg_phase: PackedByteArray = PackedByteArray()
var _seg_generation: PackedInt32Array = PackedInt32Array()
var _seg_done: PackedInt32Array = PackedInt32Array()
var _seg_cuts: PackedInt32Array = PackedInt32Array()
var _bridge_phase: PackedByteArray = PackedByteArray()
var _bridge_generation: PackedInt32Array = PackedInt32Array()
var _notice_rows: int = 0
## A critical incident was raised since the last poll (`_on_incident_cue`).
var _incident_alarm: bool = false
## When an urgent notice's second chime is due (real milliseconds; -1: none).
var _echo_at_msec: int = -1
var _ambience_msec: int = -1000000
var _at: Vector3 = Vector3.ZERO
var _bank: WaterMapScript.Bank = WaterMapScript.Bank.new()
var _bank_from: Vector2 = Vector2.INF
## Per ground cell: 1 on a worn path (empty until `build_ground`).
var _dirt: PackedByteArray = PackedByteArray()
var _bank_found: bool = false


func _init() -> void:
	"""Size the event columns once."""
	event_row.resize(MAX_EVENTS)
	event_at.resize(MAX_EVENTS)
	event_below.resize(MAX_EVENTS)
	_cue.resize(CUE_IDS.size())
	_cue.fill(-1)


func bind_table(table: SoundTable) -> void:
	"""Resolve every C_* cue to its table row (-1: not in the table, never sounded)."""
	for c: int in CUE_IDS.size():
		_cue[c] = table.row(CUE_IDS[c])


func cue_row(c: int) -> int:
	"""C_* `c`'s table row (-1: none)."""
	return _cue[c]


func watch() -> void:
	"""Take every bound source's state as it stands, as the baseline: nothing that was already so sounds."""
	_watch_brains()
	_watch_jobs()
	_watch_trees()
	_watch_segments()
	_watch_bridges()
	_notice_rows = notices.rows_posted if notices != null else 0
	_watch_incidents()


func poll(now_msec: int, listener_ground: Vector2) -> int:
	"""This frame's events into the columns (see OUTPUT), and every AMBIENCE_MS the ambience levels. Returns
	how many events."""
	event_count = 0
	_poll_brains()
	_poll_jobs()
	_poll_trees()
	_poll_segments()
	_poll_bridges()
	_poll_notices(now_msec)
	_poll_fishery()
	if now_msec - _ambience_msec >= AMBIENCE_MS:
		_ambience_msec = now_msec
		_poll_ambience(listener_ground)
	return event_count


func _emit(c: int, x: float, y: float, z: float, below: bool) -> void:
	"""Add one event for C_* `c` at (x, y, z), if its cue is in the table and the frame has room."""
	if _cue[c] < 0:
		return
	if event_count >= MAX_EVENTS:
		overflow += 1
		return
	_at.x = x
	_at.y = y
	_at.z = z
	event_row[event_count] = _cue[c]
	event_at[event_count] = _at
	event_below[event_count] = 1 if below else 0
	event_count += 1


func _poll_fishery() -> void:
	"""The fishery's committed splashes, and a knock each OAR_STROKE_U a boat rows (see `fishery`)."""
	if fishery == null:
		return
	var splashes: PackedVector2Array = fishery.get(&"sound_at")
	for at: Vector2 in splashes:
		_emit(C_SPLASH, at.x, -0.18, at.y, false)
	if not splashes.is_empty():
		fishery.call(&"clear_sounds")
	var fleet: RefCounted = fishery.get(&"fleet")
	var progress: PackedInt32Array = fleet.get(&"progress_u")
	if _oar_u.size() != progress.size():
		_oar_u.resize(progress.size())
		_oar_progress = progress.duplicate()
	for boat: int in progress.size():
		_oar_u[boat] += absi(progress[boat] - _oar_progress[boat])
		_oar_progress[boat] = progress[boat]
		if _oar_u[boat] >= OAR_STROKE_U:
			_oar_u[boat] -= OAR_STROKE_U
			var at: Vector2 = fleet.call(&"position_m", boat)
			_emit(C_STEP_WOOD, at.x, -0.1, at.y, false)


func _emit_flat(c: int) -> void:
	"""Add one event for a flat cue (no place)."""
	_emit(c, 0.0, 0.0, 0.0, false)


# --- residents: carry, water, footsteps ------------------------------------------------------------

func _watch_brains() -> void:
	"""Every resident's carry, water and position as the baseline."""
	var n: int = brains.size()
	for column: PackedByteArray in [_was_carrying, _was_in_water, _was_mode]:
		column.resize(n)
	_walked_m.resize(n)
	_last_at.resize(n)
	for i: int in n:
		_was_carrying[i] = 1 if brains[i].carrying else 0
		_was_in_water[i] = 1 if brains[i].in_water else 0
		_was_mode[i] = _mode_of(i)
		_walked_m[i] = 0.0
		_last_at[i] = brains[i].position


func _mode_of(i: int) -> int:
	"""Resident `i`'s water mode (swim_state.gd MODE_*; MODE_LAND with no swim state)."""
	return swim.mode[i] if swim != null and i < swim.count else SwimStateScript.MODE_LAND


func _poll_brains() -> void:
	"""Each resident's carry and water edges, and its footsteps."""
	if _last_at.size() != brains.size():
		_watch_brains()
	for i: int in brains.size():
		var brain: BrainScript = brains[i]
		_carry_edge(i, brain)
		_water_edge(i, brain)
		_footstep(i, brain)


func _carry_edge(i: int, brain: BrainScript) -> void:
	"""pickup as a carry begins, drop as it ends."""
	var now: int = 1 if brain.carrying else 0
	if now != _was_carrying[i]:
		_was_carrying[i] = now
		_emit(C_PICKUP if now == 1 else C_DROP, brain.position.x, brain.ground_y_m, brain.position.y, brain.underground)


func _water_edge(i: int, brain: BrainScript) -> void:
	"""water_in / water_out on the in-water edge; splash as swimming or diving begins."""
	var wet: int = 1 if brain.in_water else 0
	if wet != _was_in_water[i]:
		_was_in_water[i] = wet
		_emit(C_WATER_IN if wet == 1 else C_WATER_OUT, brain.position.x, brain.ground_y_m, brain.position.y, false)
	var mode: int = _mode_of(i)
	if mode != _was_mode[i]:
		if _swimming(mode) and not _swimming(_was_mode[i]):
			_emit(C_SPLASH, brain.position.x, brain.ground_y_m, brain.position.y, false)
		_was_mode[i] = mode


static func _swimming(mode: int) -> bool:
	"""Whether a water mode is swimming, treading or diving (in deep water)."""
	return mode == SwimStateScript.MODE_SWIM or mode == SwimStateScript.MODE_TREAD or mode == SwimStateScript.MODE_DIVE


func _footstep(i: int, brain: BrainScript) -> void:
	"""Add the distance walked this frame; a footstep for each whole STRIDE_M, by the ground underfoot."""
	var moved: float = brain.position.distance_to(_last_at[i])
	_last_at[i] = brain.position
	if moved > JUMP_M:
		return
	_walked_m[i] += moved
	if _walked_m[i] < STRIDE_M:
		return
	_walked_m[i] = fmod(_walked_m[i], STRIDE_M)
	var c: int = _surface_cue(i, brain)
	if c >= 0:
		_emit(c, brain.position.x, brain.ground_y_m, brain.position.y, brain.underground)


func _surface_cue(i: int, brain: BrainScript) -> int:
	"""The footstep cue for the ground under resident `i` (-1: swimming, no footstep)."""
	if brain.underground:
		return C_STEP_TUNNEL
	if _mode_of(i) == SwimStateScript.MODE_WADE:
		return C_STEP_WADE
	if brain.in_water or _swimming(_mode_of(i)):
		return -1
	if brain.state == BrainScript.State.CROSS:
		return C_STEP_WOOD
	return C_STEP_DIRT if is_dirt(brain.position) else C_STEP_GRASS


func build_ground() -> int:
	"""Grid the worn paths (see GROUND_CELL_M), once. Returns the cells on a path."""
	if not _dirt.is_empty():
		return 0
	_dirt.resize(GROUND_SIDE * GROUND_SIDE)
	var on_path: int = 0
	for cell: int in _dirt.size():
		var x: float = (float(cell % GROUND_SIDE) + 0.5) * GROUND_CELL_M - GROUND_HALF_M
		@warning_ignore("integer_division") var z: float = (float(cell / GROUND_SIDE) + 0.5) * GROUND_CELL_M - GROUND_HALF_M
		_dirt[cell] = 1 if WorldLayout.path_distance(Vector2(x, z)) < 0.0 else 0
		on_path += _dirt[cell]
	return on_path


func is_dirt(at: Vector2) -> bool:
	"""Whether `at` is on a worn path: the grid's cell, or (outside the grid) the paths themselves."""
	if _dirt.is_empty():
		build_ground()
	var ix: int = floori((at.x + GROUND_HALF_M) / GROUND_CELL_M)
	var iz: int = floori((at.y + GROUND_HALF_M) / GROUND_CELL_M)
	if ix < 0 or iz < 0 or ix >= GROUND_SIDE or iz >= GROUND_SIDE:
		return WorldLayout.path_distance(at) < 0.0
	return _dirt[iz * GROUND_SIDE + ix] == 1


# --- the woods: strikes, strokes, falls ------------------------------------------------------------

func _watch_jobs() -> void:
	"""Every job row's step as the baseline, with its strikes so far."""
	_job_step.resize(JobsScript.MAX_JOBS)
	_job_beats.resize(JobsScript.MAX_JOBS)
	for row: int in JobsScript.MAX_JOBS:
		_job_step[row] = -1
		_job_beats[row] = 0
		if jobs != null and jobs.is_live(row):
			_job_step[row] = jobs.current_step(row)
			_job_beats[row] = _beats_of(row)


func _beats_of(row: int) -> int:
	"""Whole strikes (or strokes) job `row`'s work step has done so far (0: not a struck step, or not begun)."""
	if jobs.issued[row] == 0 or jobs.worker[row] == JobsScript.NOBODY:
		return 0
	match jobs.current_step(row) - JobsScript.STEP_WORK:
		JobsScript.WORK_FELL, JobsScript.WORK_GRUB:
			@warning_ignore("integer_division") return jobs.elapsed_usec[row] / STRIKE_USEC
		JobsScript.WORK_SAW:
			@warning_ignore("integer_division") return jobs.elapsed_usec[row] / STROKE_USEC
	return 0


func _poll_jobs() -> void:
	"""A strike for each job whose work has done another whole beat (one a frame per job at most)."""
	if jobs == null:
		return
	if _job_step.size() != JobsScript.MAX_JOBS:
		_watch_jobs()
	for row: int in JobsScript.MAX_JOBS:
		var code: int = jobs.current_step(row) if jobs.is_live(row) else -1
		if code != _job_step[row]:
			_job_step[row] = code
			_job_beats[row] = 0
		if code < 0:
			continue
		var beats: int = _beats_of(row)
		if beats < _job_beats[row]:
			_job_beats[row] = beats  # the work began again on this row (a reused row, a step taken back)
		elif beats > _job_beats[row]:
			_job_beats[row] = beats
			_strike(row, code - JobsScript.STEP_WORK)


func _strike(row: int, work: int) -> void:
	"""Job `row`'s worker strikes: the axe (or the beaver's teeth) felling, the spade grubbing, the saw."""
	var who: int = jobs.worker[row]
	if who < 0 or who >= brains.size():
		return
	var c: int = C_SAW
	if work == JobsScript.WORK_GRUB:
		c = C_DIG
	elif work == JobsScript.WORK_FELL:
		c = C_GNAW if skills != null and skills.gnaws_wood(who) else C_CHOP
	var brain: BrainScript = brains[who]
	_emit(c, brain.position.x, brain.ground_y_m, brain.position.y, false)


func _watch_trees() -> void:
	"""Every tree's state as the baseline."""
	if stand == null:
		return
	_tree_state.resize(StandScript.MAX_TREES)
	for t: int in stand.count():
		_tree_state[t] = stand.state_of(t)
	_stand_revision = stand.revision


func _poll_trees() -> void:
	"""tree_fall for each tree gone from standing to a stump since the stand last changed."""
	if stand == null or stand.revision == _stand_revision:
		return
	if _tree_state.size() != StandScript.MAX_TREES:
		_watch_trees()
		return
	_stand_revision = stand.revision
	for t: int in stand.count():
		var state: int = stand.state_of(t)
		if _tree_state[t] == StandScript.STATE_MATURE and (state == StandScript.STATE_STUMP
				or state == StandScript.STATE_CLEARED):
			_emit(C_TREE_FALL, stand.at[t].x, 0.0, stand.at[t].y, false)
		_tree_state[t] = state


# --- the tunnels and the bridges -------------------------------------------------------------------

func _watch_segments() -> void:
	"""Every tunnel segment's phase, generation and cuts as the baseline."""
	if network == null:
		return
	for column: PackedInt32Array in [_seg_generation, _seg_done, _seg_cuts]:
		column.resize(TunnelRules.MAX_SEGMENTS)
	_seg_phase.resize(TunnelRules.MAX_SEGMENTS)
	for slot: int in TunnelRules.MAX_SEGMENTS:
		_seg_phase[slot] = network.phase[slot]
		_seg_generation[slot] = network.generation[slot]
		var dug: bool = network.phase[slot] == GraphScript.PHASE_DIGGING or network.phase[slot] == GraphScript.PHASE_PAUSED
		_seg_done[slot] = network.done(slot) if dug else 0
		_seg_cuts[slot] = network.cut_count(slot) if _seg_done[slot] > 0 else 0


func _poll_segments() -> void:
	"""dig for each new cut of a segment being dug; complete as one opens."""
	if network == null:
		return
	if _seg_phase.size() != TunnelRules.MAX_SEGMENTS:
		_watch_segments()
	for slot: int in TunnelRules.MAX_SEGMENTS:
		var phase: int = network.phase[slot]
		if network.generation[slot] != _seg_generation[slot]:
			_seg_generation[slot] = network.generation[slot]
			_seg_cuts[slot] = 0
			_seg_done[slot] = 0
		elif phase == GraphScript.PHASE_OPEN and _seg_phase[slot] == GraphScript.PHASE_DIGGING:
			_emit_flat(C_COMPLETE)
		_seg_phase[slot] = phase
		if phase == GraphScript.PHASE_DIGGING:
			_poll_cuts(slot)


func _poll_cuts(slot: int) -> void:
	"""A dig event when segment `slot`'s dig has cut another quantum (read only when its dig time moved)."""
	var done: int = network.done(slot)
	if done == _seg_done[slot]:
		return
	_seg_done[slot] = done
	var cuts: int = network.cut_count(slot)
	if cuts <= _seg_cuts[slot]:
		return
	_seg_cuts[slot] = cuts
	var d: int = network.digger[slot]
	if d >= 0 and d < brains.size():
		_emit(C_DIG, brains[d].position.x, brains[d].ground_y_m, brains[d].position.y, true)


func _watch_bridges() -> void:
	"""Every bridge's phase and generation as the baseline."""
	if bridges == null:
		return
	_bridge_phase.resize(BridgesScript.MAX_BRIDGES)
	_bridge_generation.resize(BridgesScript.MAX_BRIDGES)
	for row: int in BridgesScript.MAX_BRIDGES:
		_bridge_phase[row] = bridges.phase[row]
		_bridge_generation[row] = bridges.generation[row]


func _poll_bridges() -> void:
	"""complete as a planned bridge opens (the same bridge: its generation unchanged)."""
	if bridges == null:
		return
	if _bridge_phase.size() != BridgesScript.MAX_BRIDGES:
		_watch_bridges()
	for row: int in BridgesScript.MAX_BRIDGES:
		var phase: int = bridges.phase[row]
		if phase == BridgesScript.PHASE_OPEN and _bridge_phase[row] == BridgesScript.PHASE_PLANNED \
				and bridges.generation[row] == _bridge_generation[row]:
			_emit_flat(C_COMPLETE)
		_bridge_phase[row] = phase
		_bridge_generation[row] = bridges.generation[row]


# --- notices and ambience --------------------------------------------------------------------------

func _poll_notices(now_msec: int) -> void:
	"""warning for the loudest new announced row since the last poll, or a critical incident raised -- once a frame;
	an urgent one's second chime when it is due (see warning)."""
	var loudest: int = maxi(_new_tier(), NoticesScript.TIER_URGENT if _incident_alarm else -1)
	_incident_alarm = false
	var chime: bool = loudest >= NoticesScript.TIER_NORMAL
	if _echo_at_msec >= 0 and now_msec >= _echo_at_msec:
		_echo_at_msec = -1
		chime = true
	if loudest == NoticesScript.TIER_URGENT:
		_echo_at_msec = now_msec + URGENT_ECHO_MSEC
	if chime:
		_emit_flat(C_WARNING)


func _new_tier() -> int:
	"""The highest tier among the rows the feed wrote since the last poll and announced (-1: none)."""
	if notices == null or notices.rows_posted == _notice_rows:
		return -1
	var loudest: int = -1
	for k: int in notices.count():
		if notices.is_new_since(k, _notice_rows) and notices.is_announced(k):
			loudest = maxi(loudest, notices.tier(k))
	_notice_rows = notices.rows_posted
	return loudest


func _watch_incidents() -> void:
	"""Hear the incidents' sound hook (none already raised sounds, and no second chime is owed)."""
	_incident_alarm = false
	_echo_at_msec = -1
	if incidents != null and not incidents.incident_cue.is_connected(_on_incident_cue):
		incidents.incident_cue.connect(_on_incident_cue)


func _on_incident_cue(cue: int, _serial: int, _severity: int) -> void:
	"""A critical incident raised or come back: the next poll's warning. A resolution is not sounded yet (the
	table has no cue for it)."""
	if cue == IncidentsScript.CUE_CRITICAL_RAISED:
		_incident_alarm = true


func _poll_ambience(listener_ground: Vector2) -> void:
	"""Wind and rain from the weather's condition; the stream heard from the bank nearest the listener."""
	if weather != null:
		var condition: int = clampi(weather.condition(), 0, WIND_BY_CONDITION.size() - 1)
		wind_permille = WIND_BY_CONDITION[condition]
		rain_permille = 0
		if condition == WeatherScript.COND_RAIN:
			rain_permille = RAIN_DOWNPOUR if weather.rain() >= WeatherScript.DOWNPOUR_RAIN else RAIN_SHOWER
	_poll_stream(listener_ground)


func _poll_stream(listener_ground: Vector2) -> void:
	"""The stream heard from the bank nearest the listener (found again once it has moved BANK_REFRESH_M)."""
	if water_map == null:
		stream_permille = 0
		return
	if listener_ground.distance_to(_bank_from) >= BANK_REFRESH_M:
		_bank_from = listener_ground
		_bank_found = water_map.nearest_bank(
			Vector2i(TunnelRules.to_u(listener_ground.x), TunnelRules.to_u(listener_ground.y)), _bank)
		stream_at.x = TunnelRules.to_m(_bank.x)
		stream_at.z = TunnelRules.to_m(_bank.z)
	stream_permille = 1000 if _bank_found else 0
