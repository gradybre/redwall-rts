extends Node
## The demo's tunnel works, run every frame on the demo clock. Decision 0196 (live demo).
## Presentation only: it moves the demo cast and the demo's own stores, never the simulation.
##
## It owns the pieces the tunnel extensions add, and joins them up:
##   weather   demo/weather/demo_weather.gd -- THE demo weather (demo_services.gd), which this only
##             reads: its surface speed is handed to the network's planner (underground_graph
##             .surface_permille) every frame, and its rain soaks the wet ground (hazards)
##   water     demo/village_water.gd -- THE village water adapter (demo_services.gd), over the real
##             water map: the ground's wetness, the flood's reach and the routes' water check
##   ground    tunnel_ground.gd -- what the village's ground is made of
##   stores    tunnel_stores.gd -- THE demo stores (demo_services.gd): wood, stone, planks and finds
##   finds     tunnel_finds.gd -- one seeded roll per metre cut
##   crew      tunnel_crew.gd -- crews, the Foremole's rate, and the digging skill (dig_skills.gd)
##   jobs      tunnel_jobs.gd -- upgrades and repairs
##   hazards   tunnel_hazards.gd -- seep and strain, floods and collapses
## Burrow homes and root cellars are the network's own rooms (underground_graph.gd ROOMS, decision 0209): each is
## a piece dug like a tunnel -- its body by a crew at the room's ROOM_FACES faces -- and said when it is dug.
##   events    demo/events/demo_events.gd -- floods and fires, and who shelters from them
## The player's orders on them are tunnel_actions.gd.
##
## EACH FRAME (`step`, with the frame's demo microseconds -- none while paused), for every SEGMENT of the
## network (underground_graph.gd, decision 0208): every dig and digging job gets its crew's rate for the
## next frame; new cuts post their finds, stone and skill; finished jobs take effect; hazards build and
## strike; walkers entering weak bores strain them; threats come and go. A dig that goes on into the next
## segment of its piece takes its crew along. After the tool adds a piece that SPLITS open segments
## (`after_splits`), the walkers, hazards and finds in them follow onto the halves. What HAPPENS is said in the tunnel panel's log and posted to the demo's one notice feed
## (demo_notices.gd): a NOTE (`say`), or a WARNING (`warn`) when it asks for a response. What the player's own
## ORDERS answer (`tell`: a refusal, a prompt, who is on the job) goes to the log and the party panel's
## notice line, beside the selection, not to the feed. Nothing here raises a HUD alert card.
##
## Nothing here allocates per frame: callables are made once, and every column is sized at setup.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const SkillsScript := preload("res://demo/tunnel/dig_skills.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const EvacuateTaskScript := preload("res://demo/events/evacuate_task.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const QueueScript := preload("res://demo/tunnel/tunnel_queue.gd")

const LOG_LINES: int = 4
const EVENT_STARTED: String = "Demo event: %s! Residents nearby are taking the tunnels to safety."
const EVENT_ENDED: String = "The %s is over — everybeast is heading home."
const SEEP_WARNING: String = "Tunnel %d: water is seeping in from the wet ground by the stream. Brace it before the rain floods it."
const STRAIN_WARNING: String = "Tunnel %d: sand is trickling from the roof. Brace it before it falls in."
const FLOODED: String = "Tunnel %d has flooded and is closed. Select it and order \"Pump out\"."
const COLLAPSED: String = "Tunnel %d: part of the roof has fallen in, and the tunnel is closed. Select it and order \"Clear the fall\"."
const CREAKING: String = "Tunnel %d is creaking — the roof holds while someone is under it."
## The short summaries of what asks for a response (see `say`).
const ALERT_ROCK: String = "Rock! The Foremole needs the badger"
const ALERT_RELIC: String = "A relic dug up — see the tunnel panel"
const ALERT_SEEP: String = "Tunnel %d is seeping — brace it"
const ALERT_STRAIN: String = "Tunnel %d's roof is creaking — brace it"
const ALERT_FLOODED: String = "Tunnel %d flooded — pump it out"
const ALERT_CREAKING: String = "Tunnel %d holds while someone is under"
const ALERT_COLLAPSED: String = "Tunnel %d's roof fell in — clear it"
const ALERT_EVENT: Array[String] = ["Flood by the stream — evacuating", "Fire at the store — evacuating"]
const ALERT_EVENT_OVER: Array[String] = ["The flood has gone down", "The fire is out"]
const ALERT_DONE: Array[String] = ["", "Tunnel %d widened", "Tunnel %d braced", "Tunnel %d lit", "Tunnel %d pumped out",
	"Tunnel %d cleared"]
const FOUND_RING: int = 12
const JOB_DONE: Array[String] = ["", "Tunnel %d widened: otters and the badger fit now.", "Tunnel %d braced: no more seeping or falling in.",
	"Tunnel %d lit: walkers go a little quicker below.", "Tunnel %d pumped out and open again.",
	"Tunnel %d cleared and open again."]
## A room dug out (decision 0209): what it is for, and its summary.
const ROOM_DUG: Array[String] = ["", "Burrow home %d dug: room for %d beds in its alcoves -- click it to fit it out.",
	"Root cellar %d dug: give it racks (click it) and the pantry stores harvests in it."]
const ALERT_ROOM_DUG: String = "%s %d dug"

var weather: WeatherScript = null
var water: WaterScript = null
var notices: NoticesScript = null
var ground: GroundScript = null
var stores: StoresScript = null
var finds: FindsScript = null
var crew: CrewScript = CrewScript.new()
var jobs: JobsScript = null
var hazards: HazardsScript = null
var events: EventsScript = null
## The last few things said, newest last (the tunnel panel shows them).
var log_lines: PackedStringArray = PackedStringArray()
## Bumped whenever something is said, so the panel redraws on change.
var log_revision: int = 0
## The newest log line as said, and how many times in a row (a repeat folds into it as "... (×3)": decision
## 0210, the notice feed's REPEATS FOLD).
var _log_said: String = ""
var _log_times: int = 0
## Where the latest finds were cut, for the dig-face drawing (tunnel_find_props.gd): a ring of
## FOUND_RING entries -- the cut's point (u), the find (FindsScript.FIND_*), its relic number (0: not
## a relic) and its tunnel -- written at found_count % FOUND_RING. found_count counts every find.
var found_x_u: PackedInt32Array = PackedInt32Array()
var found_z_u: PackedInt32Array = PackedInt32Array()
var found_kind: PackedInt32Array = PackedInt32Array()
var found_relic: PackedInt32Array = PackedInt32Array()
var found_slot: PackedInt32Array = PackedInt32Array()
var found_count: int = 0

var _space: CastSpaceScript = null
var _network: GraphScript = null
var _brains: Array[BrainScript] = []
var _notice: Callable = Callable()
var _fits: Array[Callable] = []
var _seen_cuts: PackedInt32Array = PackedInt32Array()
var _seen_stone: PackedInt64Array = PackedInt64Array()
var _seen_open: PackedByteArray = PackedByteArray()
var _seen_gen: PackedInt32Array = PackedInt32Array()
var _rock_note: PackedByteArray = PackedByteArray()
var _creaked: PackedByteArray = PackedByteArray()
var _prev_bore: PackedInt32Array = PackedInt32Array()
var _progress: PackedInt64Array = PackedInt64Array()
var _escape: PackedFloat32Array = PackedFloat32Array()


func setup(space: CastSpaceScript, brains: Array[BrainScript], species: PackedStringArray, bounds_u: Rect2i,
		notice: Callable, services: ServicesScript = null) -> void:
	"""Run the works for this cast (`brains` and `species` by resident index) over these bounds, with
	the demo's shared weather, water and notice feed (none: a fresh set of its own). `notice(text)`
	shows an order's answer in the party panel (see `tell`)."""
	name = "TunnelWorks"
	_space = space
	_network = space.tunnels
	_brains = brains
	_notice = notice
	var shared: ServicesScript = services if services != null else ServicesScript.new()
	weather = shared.weather
	water = shared.water
	notices = shared.notices
	stores = shared.stores
	events = EventsScript.new(water)
	ground = GroundScript.new(bounds_u, water)
	_network.set_ground(ground)
	finds = FindsScript.new(ground.cells.size())
	for column: PackedInt32Array in [found_x_u, found_z_u, found_kind, found_relic, found_slot]:
		column.resize(FOUND_RING)
	jobs = JobsScript.new(_network, stores)
	hazards = HazardsScript.new(_network)
	for i in brains.size():
		crew.set_resident(i, species[i])
	for slot in Rules.MAX_SEGMENTS:
		_fits.append(_fits_bore.bind(slot))
	_size_columns(brains.size())
	_network.surface_permille = weather.surface_speed_permille()


func _size_columns(residents: int) -> void:
	"""Size the per-frame scratch once."""
	_seen_cuts.resize(Rules.MAX_SEGMENTS)
	_seen_stone.resize(Rules.MAX_SEGMENTS)
	_seen_open.resize(Rules.MAX_SEGMENTS)
	_seen_gen.resize(Rules.MAX_SEGMENTS)
	_rock_note.resize(Rules.MAX_SEGMENTS)
	_creaked.resize(Rules.MAX_SEGMENTS)
	_prev_bore.resize(residents)
	_prev_bore.fill(-1)
	_progress.resize(GraphScript.P_SIZE)
	_escape.resize(4)


func _fits_bore(index: int, slot: int) -> bool:
	"""Whether resident `index` fits tunnel `slot`'s bore unloaded (made once per slot as a callable)."""
	return _network.fits_tunnel(index, slot, false)


func fits_callable(slot: int) -> Callable:
	"""The callable crew rates use to ask who fits tunnel `slot`."""
	return _fits[slot]


func brain(index: int) -> BrainScript:
	"""Resident `index`'s brain."""
	return _brains[index]


func resident_count() -> int:
	"""How many residents the works know."""
	return _brains.size()


func crew_active(slot: int) -> bool:
	"""Whether the Foremole's work on segment `slot` goes on: a dig (a DIGGING segment always has its digger;
	one called away is PAUSED), or a digging job with its worker."""
	if _network.phase[slot] == GraphScript.PHASE_DIGGING:
		return true
	var job := jobs.kind[slot]
	var mole_work := job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR
	return mole_work and jobs.has_job(slot) and jobs.worker[slot] >= 0


func crew_along(slot: int) -> float:
	"""Where the Foremole stands in segment `slot`'s bore, in metres: a dig's face (0 through an entry
	shaft, which it digs from the surface), or a job's worker's place below (0 until it is down)."""
	if _network.phase[slot] == GraphScript.PHASE_DIGGING:
		return _network.face_m(slot)
	var lead := jobs.worker[slot]
	if lead < 0 or not _brains[lead].is_in_bore(slot):
		return 0.0
	return _brains[lead].bore_along_m()


# --- saying things ------------------------------------------------------------------------

func say(text: String, summary: String = "", source: int = NoticesScript.SOURCE_TUNNELS) -> void:
	"""Something HAPPENED: `text` goes to the tunnel panel's log and to the demo's notice feed as a NOTE,
	with `summary`, its short one-line form, when one is authored."""
	_post(text, summary, source, NoticesScript.LEVEL_NOTE)


func warn(text: String, summary: String, source: int = NoticesScript.SOURCE_TUNNELS) -> void:
	"""Something that ASKS FOR A RESPONSE happened (brace it, pump it out, bring the badger, a threat):
	as `say`, but a WARNING in the feed."""
	_post(text, summary, source, NoticesScript.LEVEL_WARNING)


func _post(text: String, summary: String, source: int, level: int) -> void:
	"""Log `text` and post it to the feed at `level`."""
	if text.is_empty():
		return
	_log(text)
	notices.post(source, level, text, summary)


func tell(text: String) -> void:
	"""The answer to the player's own order (a refusal, a prompt, who is on it): the tunnel panel's log
	and the party panel's notice line, beside the selection -- not the feed."""
	if text.is_empty():
		return
	_log(text)
	if _notice.is_valid():
		_notice.call(text)


func _log(text: String) -> void:
	"""Keep `text` among the panel's last LOG_LINES lines; said again straight after, it is counted on the newest
	line instead ("... (×2)")."""
	log_revision += 1
	if text == _log_said and not log_lines.is_empty():
		_log_times += 1
		log_lines[-1] = "%s (×%d)" % [text, _log_times]
		return
	_log_said = text
	_log_times = 1
	if log_lines.size() >= LOG_LINES:
		log_lines.remove_at(0)
	log_lines.append(text)


# --- each frame ---------------------------------------------------------------------------

func step(usec: int) -> void:
	"""One frame of the works, `usec` demo microseconds long (see EACH FRAME). The weather is not run
	here: its owner keeps it on the calendar; this only reads it."""
	_network.surface_permille = weather.surface_speed_permille()
	for slot in Rules.MAX_SEGMENTS:
		_watch_opening(slot)
		_run_dig(slot)
		_run_job(slot)
		_run_hazard(slot, usec)
	_watch_crossings()
	_run_events(usec)


func _watch_opening(slot: int) -> void:
	"""A segment just opened: survey its hazards, lay out the line at a mouth it opens, take the crew on into
	the next segment of its piece, and -- the piece done -- the Foremole says so. A freed slot is
	forgotten; a split half (open when first seen) is surveyed quietly."""
	var open := _network.is_open(slot)
	var fresh := _network.generation[slot] != _seen_gen[slot]
	if open == (_seen_open[slot] == 1) and not fresh:
		return
	_seen_open[slot] = 1 if open else 0
	_seen_gen[slot] = _network.generation[slot]
	if not open:
		return
	if _network.seg_room[slot] >= 0:
		_watch_room(slot, fresh)
		return
	hazards.survey(slot)
	for end in 2:
		var m := _network.mouth_of_end(slot, end == 1)
		if m >= 0:
			_network.queue.lay_out(m, _network.mouth_at(m), -_network.mouth_inward(m), _queue_place_clear)
	var next := _network.next_in_piece(slot)
	if next >= 0 and _network.phase[next] == GraphScript.PHASE_DIGGING:
		crew.move_site(slot, next)
	elif _network.piece_done(_network.piece[slot]) and not fresh:
		say(CrewScript.LINE_OPEN)


func _watch_room(slot: int, fresh: bool) -> void:
	"""A room's segment just opened: its ramp lays out the line at its door (and the dig goes on into the body);
	its body -- the room dug out -- is said (ROOM_DUG). A room's segments have no seep or strain."""
	var m := _network.mouth_of_end(slot, false)
	if m >= 0:
		_network.queue.lay_out(m, _network.mouth_at(m), -_network.mouth_inward(m), _queue_place_clear)
	var next := _network.next_in_piece(slot)
	if next >= 0 and _network.phase[next] == GraphScript.PHASE_DIGGING:
		crew.move_site(slot, next)
	if _network.is_room_body(slot) and not fresh:
		var r: int = _network.seg_room[slot]
		var kind: int = _network.rooms.template[r]
		say(ROOM_DUG[kind] % ([r + 1, RoomsScript.BEDS_PER_HOME] if kind == RoomsScript.TEMPLATE_HOME else [r + 1]),
			ALERT_ROOM_DUG % [RoomsScript.NAMES[kind], r + 1])


func _queue_place_clear(at: Vector2) -> bool:
	"""Whether a place in a mouth's line keeps clear of obstacles and holes, inside the village."""
	var body := 0.35
	return _space.bounds.grow(-body).has_point(at) and _space.obstacle_clearance(at) > body + 0.1 \
			and not _space.on_mouth(at, body)


func _run_dig(slot: int) -> void:
	"""A tunnel being dug: its crew's rate for the next frame, the Foremole's word on rock, and the
	finds, stone and experience of every new cut."""
	if _network.phase[slot] == GraphScript.PHASE_FREE:
		_seen_cuts[slot] = 0
		_seen_stone[slot] = 0
		return
	if _network.phase[slot] == GraphScript.PHASE_OPEN and _seen_cuts[slot] >= _network.timeline_count(slot):
		return
	var cuts := _network.cut_count(slot)
	var lead := _network.digger[slot]
	if _network.phase[slot] == GraphScript.PHASE_DIGGING:
		var face := _network.quantum_kind(slot, _network.face_quantum(slot))
		var faces := RoomsScript.ROOM_FACES if _network.is_room_body(slot) else 1
		_network.set_rate(slot, crew.rate_permille(slot, lead, faces, face, _fits[slot]))
		_note_rock(slot, lead, face)
	var ticks := 0
	var layer := FindsScript.LAYER_CHAMBER if _network.is_room_body(slot) else FindsScript.LAYER_BORE
	for c in range(_seen_cuts[slot], cuts):
		var kind := _network.quantum_kind(slot, c)
		_on_cut(slot, c, layer, kind, _network.quantum_point_u(slot, c))
		ticks += GroundScript.dig_ticks(kind)
	if cuts > _seen_cuts[slot]:
		_stone_and_skill(slot, lead, ticks)
		_seen_cuts[slot] = cuts


func _stone_and_skill(slot: int, lead: int, ticks: int) -> void:
	"""Stone from the dig's new cuts goes to the stores; the crew at the face learns (dig_skills.gd)."""
	var stone := _network.stone_milli_u(slot)
	stores.add_stone(stone - _seen_stone[slot])
	_seen_stone[slot] = stone
	if crew.credit_ticks(slot, lead, ticks, _fits[slot]):
		say(CrewScript.LINE_SKILL)


func _note_rock(slot: int, lead: int, face: int) -> void:
	"""When the face reaches rock, or a breaker starts or stops cracking it, the Foremole says so."""
	var note := 0
	if face == GroundScript.ROCK:
		note = 2 if crew.breaker_present(slot, lead) else 1
	if note == _rock_note[slot]:
		return
	_rock_note[slot] = note
	if note == 1:
		warn(CrewScript.LINE_ROCK_ALONE, ALERT_ROCK)
	elif note == 2:
		say(CrewScript.LINE_ROCK_BADGER)


func _on_cut(slot: int, c: int, layer: int, kind: int, at: Vector2i) -> void:
	"""A metre cut at `at` (u) through ground `kind`: roll its find (once per metre and layer)."""
	var found := finds.dig(ground.cell_of(at.x, at.y), layer, kind)
	if found == FindsScript.FIND_NONE:
		return
	stores.add_find(found)
	_record_find(slot, at, found)
	if found == FindsScript.FIND_RELIC:
		say(FindsScript.relic_story(stores.finds[FindsScript.FIND_RELIC]), ALERT_RELIC)
	else:
		say("Tunnel %d: %s" % [slot + 1, FindsScript.find_line(found)])


func _record_find(slot: int, at: Vector2i, found: int) -> void:
	"""Remember where a find was cut (the ring's oldest entry goes)."""
	var k: int = found_count % FOUND_RING
	found_x_u[k] = at.x
	found_z_u[k] = at.y
	found_kind[k] = found
	found_relic[k] = stores.finds[FindsScript.FIND_RELIC] if found == FindsScript.FIND_RELIC else 0
	found_slot[k] = slot
	found_count += 1


func _run_job(slot: int) -> void:
	"""A job: its crew's rate, its new cuts' finds, and -- when its work is done -- its effect."""
	if not jobs.has_job(slot):
		if jobs.kind[slot] != JobsScript.JOB_NONE:
			_void_job(slot)
		return
	var job := jobs.kind[slot]
	var mole_work := job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR
	jobs.rate_permille[slot] = _job_rate(slot, job) if mole_work and jobs.worker[slot] >= 0 else Rules.PERMILLE
	var before := jobs.posted_cuts[slot]
	var fresh := jobs.post_cuts(slot)
	var ticks := 0
	for c in range(before, before + fresh):
		ticks += _on_job_cut(slot, job, c)
	if fresh > 0 and mole_work:
		crew.credit_ticks(slot, jobs.worker[slot], ticks, _fits[slot])
	if jobs.is_done(slot) and jobs.paid[slot] == 1:
		_finish_job(slot)


func _job_rate(slot: int, job: int) -> int:
	"""A mole job's crew rate: widening works five faces, clearing one."""
	var faces := JobsScript.WIDEN_FACES if job == JobsScript.JOB_WIDEN else 1
	return crew.rate_permille(slot, jobs.worker[slot], faces, _widen_face_ground(slot), _fits[slot])


func _widen_face_ground(slot: int) -> int:
	"""The ground a widening (or clearing) is working through now."""
	_network.progress_into(slot, jobs.done_ticks(slot), Rules.WIDE_EXTRA_QUANTA, _progress)
	return _network.quantum_kind(slot, int(_progress[GraphScript.P_QUANTUM]))


func _on_job_cut(slot: int, job: int, c: int) -> int:
	"""The `c`-th cut of a job: a widening rolls the metre it widens. Returns the cut's dig ticks (0 for a job
	that cuts nothing: a clearing's are counted as dug)."""
	if job == JobsScript.JOB_WIDEN:
		var k := c / Rules.WIDE_EXTRA_QUANTA
		var kind := _network.quantum_kind(slot, k)
		_on_cut(slot, c, FindsScript.LAYER_WIDEN, kind, _network.quantum_point_u(slot, k))
		return GroundScript.dig_ticks(kind)
	return GroundScript.dig_ticks(GroundScript.LOAM) if job == JobsScript.JOB_CLEAR else 0


func _finish_job(slot: int) -> void:
	"""A job's work is done: it takes effect, and is said."""
	var job := jobs.finish(slot)
	if job == JobsScript.JOB_PUMP or job == JobsScript.JOB_CLEAR:
		hazards.repaired(slot, job == JobsScript.JOB_PUMP)
	say(JOB_DONE[job] % (slot + 1), ALERT_DONE[job] % (slot + 1))
	if job == JobsScript.JOB_WIDEN:
		say(CrewScript.LINE_WIDENED)


func _void_job(slot: int) -> void:
	"""A job whose tunnel is gone: cleared."""
	jobs.clear(slot)


# --- hazards --------------------------------------------------------------------------------

func _run_hazard(slot: int, usec: int) -> void:
	"""Build segment `slot`'s pressures this frame and act on what comes of them. A stream flood soaks a
	segment it lies under at either end. A room's segments have none (decision 0209)."""
	if not _network.is_open(slot) or _network.seg_room[slot] >= 0:
		return
	var flooding := events.active and events.kind == EventsScript.KIND_FLOOD \
			and (events.covers(_network.end_at(slot, false)) or events.covers(_network.end_at(slot, true)))
	_act_on(slot, hazards.update(slot, usec, weather.is_wet(), flooding, jobs.has_job(slot)))


func _act_on(slot: int, event: int) -> void:
	"""Warn, flood or collapse, as a hazard's verdict says."""
	match event:
		HazardsScript.EVENT_SEEP_WARNING:
			warn(SEEP_WARNING % (slot + 1), ALERT_SEEP % (slot + 1))
		HazardsScript.EVENT_STRAIN_WARNING:
			warn(STRAIN_WARNING % (slot + 1), ALERT_STRAIN % (slot + 1))
		HazardsScript.EVENT_FLOODED:
			hazards.flood(slot)
			_empty_bore(slot)
			warn(FLOODED % (slot + 1), ALERT_FLOODED % (slot + 1))
		HazardsScript.EVENT_COLLAPSE_DUE:
			_try_collapse(slot)


func _try_collapse(slot: int) -> void:
	"""The roof falls -- unless someone stands under the section, when it holds (and creaks) for now."""
	for b in _brains:
		if b.is_in_bore(slot) and hazards.in_fall(slot, b.bore_along_m()):
			if _creaked[slot] == 0:
				_creaked[slot] = 1
				warn(CREAKING % (slot + 1), ALERT_CREAKING % (slot + 1))
			return
	_creaked[slot] = 0
	hazards.collapse(slot)
	_empty_bore(slot)
	warn(COLLAPSED % (slot + 1), ALERT_COLLAPSED % (slot + 1))


func _empty_bore(slot: int) -> void:
	"""A segment just closed: everyone walking it turns back to the end on their side of the closure (and on
	out by another way), and nobody waits in the line at a mouth it opens."""
	var from_m := Rules.to_m(_network.closed_from_u[slot])
	var flooded := _network.closed[slot] == GraphScript.CLOSED_FLOODED
	for b in _brains:
		if not b.is_in_bore(slot):
			continue
		var along := b.bore_along_m()
		var to_end := along > _network.length_m(slot) * 0.5 if flooded else along > from_m
		b.turn_back(slot, _network.length_m(slot) if to_end else 0.0)
	for end in 2:
		if _network.mouth_of_end(slot, end == 1) >= 0:
			_network.queue.clear_mouth(_network.mouth_of_end(slot, end == 1))


func after_splits() -> void:
	"""The tool just added a piece that split open segments (underground_graph.gd `last_splits`): the walkers
	in them, their hazards and their finds follow onto the halves; and each half's
	dig is taken as seen as it stands, so a new half's cuts are not counted again (its stone, its finds)."""
	var splits := _network.last_splits
	for i in splits.size() / 3:
		var old := splits[3 * i]
		var tail := splits[3 * i + 1]
		var split_u := splits[3 * i + 2]
		for b in _brains:
			b.repoint_split(old, tail, Rules.to_m(split_u))
		hazards.split(old, tail)
		_rebaseline(old)
		_rebaseline(tail)
	_repoint_finds(splits)


func _rebaseline(slot: int) -> void:
	"""Take segment `slot`'s dig as seen as it stands: its cuts and their stone already counted."""
	_seen_cuts[slot] = _network.cut_count(slot)
	_seen_stone[slot] = _network.stone_milli_u(slot)


func _repoint_finds(splits: PackedInt32Array) -> void:
	"""Each find cut in a segment these splits cut (`last_splits` triples) now lies in whichever of its
	halves passes nearest its place -- however many times one piece split the same segment."""
	var halves := PackedInt32Array()
	for i in splits.size() / 3:
		for k in 2:
			if not halves.has(splits[3 * i + k]):
				halves.append(splits[3 * i + k])
	for k in mini(found_count, FOUND_RING):
		if not halves.has(found_slot[k]):
			continue
		var at := Vector2(Rules.to_m(found_x_u[k]), Rules.to_m(found_z_u[k]))
		var best := found_slot[k]
		for half in halves:
			if _network.distance_to_route(half, at) < _network.distance_to_route(best, at):
				best = half
		found_slot[k] = best


func _watch_crossings() -> void:
	"""Everyone who just walked into a bore strains it (a weak, unbraced one takes it)."""
	for i in _brains.size():
		var now := _space.resident_tunnel[i]
		if now != _prev_bore[i] and now >= 0 and _network.seg_room[now] < 0 and _brains[i].state == BrainScript.State.TUNNEL:
			_act_on(now, hazards.add_crossing(now))
		_prev_bore[i] = now


# --- threats and evacuation ---------------------------------------------------------------

func _run_events(usec: int) -> void:
	"""Threats come on their own schedule; one that starts sends its residents away."""
	var change := events.advance(usec)
	if change == EventsScript.CHANGE_STARTED:
		_start_threat()
	elif change == EventsScript.CHANGE_ENDED:
		say(EVENT_ENDED % events.threat_name(), ALERT_EVENT_OVER[events.kind], NoticesScript.SOURCE_EVENTS)


func start_test_event() -> bool:
	"""The panel's "Test event (demo)": bring the next seeded threat now. False while one is under way."""
	if not events.trigger():
		return false
	_start_threat()
	return true


func _start_threat() -> void:
	"""Say what threatens, and send everyone on the surface inside it away (demo_events.gd)."""
	warn(EVENT_STARTED % events.threat_name(), ALERT_EVENT[events.kind], NoticesScript.SOURCE_EVENTS)
	for b in _brains:
		if b.underground or b.order == BrainScript.ORDER_DIG or not events.covers(b.position):
			continue
		var via := events.plan_escape(_network, b.index, b.position, _escape)
		b.order_task(EvacuateTaskScript.new(_network, _escape.duplicate(), via, events.shelter_from(b.position),
			events.centre_m(), events.threat_name(), _threat_over))


func _threat_over() -> bool:
	"""Whether the threat has cleared (an evacuee's cue to go home)."""
	return not events.active


func evacuee_count() -> int:
	"""How many residents are evacuating or sheltering now."""
	var n := 0
	for b in _brains:
		if b.task is EvacuateTaskScript:
			n += 1
	return n
