extends RefCounted
## THE PEOPLE'S TAPS: which committed happenings become the residents' memories, and which shared experiences grow
## their affinity. Decision 0491 (review group T: P6, SOC-001, SOC-014, SOC-028). Presentation only.
##
## As the sound's event map (demo/sound/sound_taps.gd, decision 0351), it READS the owners' committed state once a
## frame and writes only the ledger (people_ledger.gd) -- an owner's own code is not hooked. A deed is recorded at the
## EDGE where its owner has committed it, and only then:
##   bridge     a bridge row going PLANNED -> OPEN in the same generation (demo/waterplay/bridges.gd): everyone seen
##              as its builder while LOADING, CARRYING or BUILDING it (bridge_crew.gd STEP_*). A row whose generation
##              moves on (another bridge in it) forgets them. (A planned bridge cannot be cancelled in the demo.)
##   tunnel     a live piece of the tunnel network becoming done (underground_graph.gd `piece_done`): every lead whose
##   / room     segment of it was CUT while it led, and every crew member at its post there while a cut was made. A
##              piece dropped before it was done (its generation moves on) forgets them.
##   rescue     a new row in the rescue's ASSISTANCE LOG (rescue.gd: a victim a rescuer brought ashore -- never one the
##              water washed ashore): the rescuer's KIND_RESCUE and the victim's KIND_RESCUED, one deed; affinity +8.
##   harvest    a new row in the farm crew's HARVEST LOG (farm_crew.gd: a harvest put in store whole): the worker's
##              FIRST harvest only.
##   skill      a skill's level rising (the woods', the tunnels' and the bridges' XP, read through `add_skill`); the
##              levels at `watch()` are the baseline, so a starting level is no deed.
##   meal       a meal FINALIZED with everyone fed (kitchen.gd THE MEAL FINALIZED: its event published once every bowl
##              of it was eaten or given back, `without` 0; decision 0997, Brendan's ruling on review R05): each cook of
##              its batches' FIRST such meal; and at a finalized supper, every pair of its committed diners (who ate a
##              portion of it) shared a supper.
## Shared work: every SHARE_POLL_TICKS of calendar time, two residents of the same crew both on a task of the work board
## within NEAR_M of each other, or both at work on the same dig, worked those ticks together (affinity per whole hour).
## A board row holds one worker, so "the same job" side by side is the same crew's work at the same place.
##
## A source left unbound (null) is skipped, so a suite can watch one source alone. `new_deeds` lists the deeds the
## last poll recorded, for the spotlight (demo_people.gd).

const Ledger := preload("res://demo/people/people_ledger.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelCrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const KitchenWords := preload("res://demo/kitchen/kitchen_text.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

## Shared work and skills are looked at this often (calendar ticks: two game minutes).
const SHARE_POLL_TICKS: int = 25
const SKILL_POLL_TICKS: int = 25
## A bridge's builder counts from these steps (bridge_crew.gd STEP_*): the material handled, the bridge worked.
const BUILDING_STEPS: PackedInt32Array = [BridgeCrewScript.STEP_LOAD, BridgeCrewScript.STEP_CARRY,
	BridgeCrewScript.STEP_WORK]
## The way down a link piece is (tunnel_rules.gd LINK_*).
const LINK_WORDS: Array[String] = ["tunnel %d", "the ramp down (tunnel %d)", "the stairs down (tunnel %d)"]
## Two crew-mates on board tasks this close (m) are working side by side (demo value: a work site's reach).
const NEAR_M: float = 8.0
## Residents a contributor mask holds (one bit each).
const MAX_MASK_RESIDENTS: int = 62

var ledger: Ledger = null
var calendar: CalendarScript = null
var cast: DemoCastScript = null
var bridges: BridgesScript = null
var bridge_crew: BridgeCrewScript = null
var rescue: RescueScript = null
var network: GraphScript = null
var tunnel_crew: TunnelCrewScript = null
var farm_crew: FarmCrewScript = null
var kitchen: KitchenScript = null
var board: BoardScript = null
## The deeds the last poll recorded.
var new_deeds: PackedInt32Array = PackedInt32Array()

var _skill_names: PackedStringArray = PackedStringArray()
var _skill_xp: Array[Callable] = []
var _skill_level: PackedInt32Array = PackedInt32Array()
var _bridge_phase: PackedByteArray = PackedByteArray()
var _bridge_gen: PackedInt32Array = PackedInt32Array()
var _bridge_hands: PackedInt64Array = PackedInt64Array()
var _piece_gen: PackedInt32Array = PackedInt32Array()
var _piece_done: PackedByteArray = PackedByteArray()
var _piece_hands: PackedInt64Array = PackedInt64Array()
var _seg_cuts: PackedInt32Array = PackedInt32Array()
## Each segment's dig progress (with its phase: `_progress_key`) and generation as last read: its cuts are counted again
## only when either moved (an open segment's timeline is long, and it can gain no cut).
var _seg_usec: PackedInt64Array = PackedInt64Array()
var _seg_gen: PackedInt32Array = PackedInt32Array()
var _graph_revision: int = -1
var _assists: int = 0
var _harvests: int = 0
## The kitchen's last meal-finalized event looked at (its serial; 0: none yet).
var _last_final: int = 0
var _share_tick: int = 0
var _skill_tick: int = 0
var _day: int = 0
var _task_of: PackedInt32Array = PackedInt32Array()
var _site_of: PackedInt32Array = PackedInt32Array()
var _at: PackedVector2Array = PackedVector2Array()
var _chain: PackedInt32Array = PackedInt32Array()
var _when: SimClock.Calendar = SimClock.Calendar.new(0)


func add_skill(label: String, xp_of: Callable) -> void:
	"""Watch a skill's level: `xp_of(who) -> int` (its XP on §5.3's curve, forest_rules.gd `level_of`)."""
	_skill_names.append(label)
	_skill_xp.append(xp_of)


func skill_count() -> int:
	"""How many skills are watched."""
	return _skill_names.size()


func skill_name(s: int) -> String:
	"""Watched skill `s`'s name."""
	return _skill_names[s]


func skill_xp(s: int, who: int) -> int:
	"""Resident `who`'s XP in watched skill `s`."""
	return int(_skill_xp[s].call(who))


func residents() -> int:
	"""How many residents the ledger knows."""
	return ledger.resident_count() if ledger != null else 0


func watch() -> void:
	"""Take every bound source as it stands as the baseline: nothing already so is a deed."""
	var n: int = residents()
	_skill_level.resize(n * _skill_names.size())
	for s: int in _skill_names.size():
		for who: int in n:
			_skill_level[s * n + who] = ForestRules.level_of(skill_xp(s, who))
	_watch_bridges()
	_watch_pieces()
	_assists = rescue.assists if rescue != null else 0
	_harvests = farm_crew.harvests if farm_crew != null else 0
	_last_final = kitchen.finals_published if kitchen != null else 0
	_task_of.resize(n)
	_site_of.resize(n)
	_at.resize(n)
	if calendar != null:
		_share_tick = calendar.tick
		_skill_tick = calendar.tick
		_day = _calendar_now().absolute_day


func _calendar_now() -> SimClock.Calendar:
	"""The calendar now, decoded into the reused instant (never the calendar's own, which its callers reuse)."""
	SimClock.calendar_at_into(calendar.tick if calendar != null else 0, _when)
	return _when


func season_index() -> int:
	"""The absolute season now: 0 for the first spring, counting on through the years."""
	var at: SimClock.Calendar = _calendar_now()
	return (at.year - 1) * 4 + at.season


func poll() -> int:
	"""Record this frame's committed deeds and shared experience; returns how many deeds."""
	new_deeds.clear()
	if ledger == null:
		return 0
	_poll_day()
	_poll_bridges()
	_poll_pieces()
	_poll_rescues()
	_poll_harvests()
	_poll_meals()
	_poll_skills()
	_poll_shared_work()
	return new_deeds.size()


func _tick() -> int:
	"""The calendar's tick (0 unbound)."""
	return calendar.tick if calendar != null else 0


func _begin(kind: int, lead: int) -> int:
	"""A deed now, told of `lead` first; noted for the spotlight."""
	var deed: int = ledger.begin_deed(kind, _tick(), season_index(), lead)
	if deed >= 0:
		new_deeds.append(deed)
	return deed


func _poll_day() -> void:
	"""Each midnight passed since the last look: the ledger's daily decay (§5.3), one day at a time."""
	if calendar == null:
		return
	var day: int = _calendar_now().absolute_day
	while _day < day:
		_day += 1
		ledger.midnight(_day)


# --- bridges ---------------------------------------------------------------------------------------------

func _watch_bridges() -> void:
	"""The bridges' phases as they stand; no builders yet."""
	_bridge_phase.resize(BridgesScript.MAX_BRIDGES)
	_bridge_gen.resize(BridgesScript.MAX_BRIDGES)
	_bridge_hands.resize(BridgesScript.MAX_BRIDGES)
	_bridge_hands.fill(0)
	if bridges == null:
		return
	for row: int in BridgesScript.MAX_BRIDGES:
		_bridge_phase[row] = bridges.phase[row]
		_bridge_gen[row] = bridges.generation[row]


func _poll_bridges() -> void:
	"""Builders seen at work while PLANNED; the bridge opening in the same generation is their deed."""
	if bridges == null or _bridge_phase.size() != BridgesScript.MAX_BRIDGES:
		return
	for row: int in BridgesScript.MAX_BRIDGES:
		var phase: int = bridges.phase[row]
		if bridges.generation[row] != _bridge_gen[row]:
			_bridge_gen[row] = bridges.generation[row]
			_bridge_hands[row] = 0
		elif phase == BridgesScript.PHASE_OPEN and _bridge_phase[row] == BridgesScript.PHASE_PLANNED:
			_record_hands(Ledger.KIND_BRIDGE, _bridge_hands[row], NoticesScript.TARGET_BRIDGE, row, bridges.names[row])
			_bridge_hands[row] = 0
		_bridge_phase[row] = phase
		if phase == BridgesScript.PHASE_PLANNED and bridge_crew != null:
			var who: int = bridge_crew.builder[row]
			if who >= 0 and BUILDING_STEPS.has(bridge_crew.step[row]):
				_bridge_hands[row] |= _bit(who)


static func _bit(who: int) -> int:
	"""Resident `who`'s bit in a contributor mask (0 past MAX_MASK_RESIDENTS)."""
	return 1 << who if who >= 0 and who < MAX_MASK_RESIDENTS else 0


func _record_hands(kind: int, hands: int, place_kind: int, place_id: int, subject: String) -> void:
	"""One deed of `kind` for everyone in mask `hands`, lowest index first."""
	var deed: int = -1
	for who: int in mini(residents(), MAX_MASK_RESIDENTS):
		if hands & _bit(who) == 0:
			continue
		if deed < 0:
			deed = _begin(kind, who)
		ledger.add_event(deed, kind, who, Ledger.NOBODY, place_kind, place_id, subject)


# --- tunnels and rooms -----------------------------------------------------------------------------------

func _watch_pieces() -> void:
	"""The pieces as they stand: those done already are no deed; no contributors yet."""
	_piece_gen.resize(TunnelRules.MAX_PIECES)
	_piece_done.resize(TunnelRules.MAX_PIECES)
	_piece_hands.resize(TunnelRules.MAX_PIECES)
	_piece_hands.fill(0)
	_seg_cuts.resize(TunnelRules.MAX_SEGMENTS)
	_seg_cuts.fill(0)
	_seg_usec.resize(TunnelRules.MAX_SEGMENTS)
	_seg_gen.resize(TunnelRules.MAX_SEGMENTS)
	if network == null:
		return
	for p: int in TunnelRules.MAX_PIECES:
		_piece_gen[p] = network.piece_gen[p]
		_piece_done[p] = 1 if network.piece_live[p] == 1 and network.piece_done(p) else 0
	for slot: int in TunnelRules.MAX_SEGMENTS:
		_seg_cuts[slot] = network.cut_count(slot) if network.phase[slot] != GraphScript.PHASE_FREE else 0
		_seg_usec[slot] = _progress_key(slot)
		_seg_gen[slot] = network.generation[slot]
	_graph_revision = network.revision


func _poll_pieces() -> void:
	"""Contributors: a lead whose segment was cut since the last look, and the crew at their posts there; a piece
	done since the graph last changed is their deed."""
	if network == null or _piece_gen.size() != TunnelRules.MAX_PIECES:
		return
	for slot: int in TunnelRules.MAX_SEGMENTS:
		if network.generation[slot] != _seg_gen[slot]:
			_seg_gen[slot] = network.generation[slot]
			_seg_cuts[slot] = 0
			_seg_usec[slot] = -1
		if network.phase[slot] == GraphScript.PHASE_FREE or _progress_key(slot) == _seg_usec[slot]:
			continue
		_seg_usec[slot] = _progress_key(slot)
		var cuts: int = network.cut_count(slot)
		if cuts > _seg_cuts[slot]:
			_piece_hands[network.piece[slot]] |= _bit(network.digger[slot]) | _crew_mask(slot)
		_seg_cuts[slot] = cuts
	if network.revision == _graph_revision:
		return
	_graph_revision = network.revision
	for p: int in TunnelRules.MAX_PIECES:
		_settle_piece(p)


func _progress_key(slot: int) -> int:
	"""Segment `slot`'s dig progress and phase in one number: it changes whenever a cut could have been made."""
	return network.dig_usec[slot] * 8 + network.phase[slot]


func _crew_mask(slot: int) -> int:
	"""The crew at their posts on segment `slot` (none unbound)."""
	var mask: int = 0
	if tunnel_crew == null:
		return mask
	for who: int in mini(tunnel_crew.member_site.size(), MAX_MASK_RESIDENTS):
		if tunnel_crew.member_site[who] == slot and tunnel_crew.member_present[who] == 1:
			mask |= _bit(who)
	return mask


func _settle_piece(p: int) -> void:
	"""Piece `p` after a graph change: a new generation forgets its contributors; done now, it is their deed."""
	if network.piece_gen[p] != _piece_gen[p]:
		_piece_gen[p] = network.piece_gen[p]
		_piece_hands[p] = 0
		_piece_done[p] = 0
	if _piece_done[p] == 1 or network.piece_live[p] != 1 or not network.piece_done(p):
		return
	_piece_done[p] = 1
	network.piece_segments_into(p, _chain)
	if _chain.is_empty():
		return
	var room: int = network.piece_room[p]
	var kind: int = Ledger.KIND_ROOM if room >= 0 else Ledger.KIND_TUNNEL
	_record_hands(kind, _piece_hands[p], NoticesScript.TARGET_TUNNEL, _chain[0], piece_words(p, _chain[0]))
	_piece_hands[p] = 0


func piece_words(p: int, first: int) -> String:
	"""A piece as its deed names it: "Burrow home 1", "tunnel 3", "the stairs down (tunnel 5)"."""
	var room: int = network.piece_room[p]
	if room >= 0 and network.rooms.is_room(room):
		return "%s %d" % [RoomsScript.NAMES[network.rooms.template[room]], room + 1]
	var link: int = network.seg_link[first] if network.seg_kind[first] == GraphScript.SEG_LINK else 0
	return LINK_WORDS[clampi(link, 0, LINK_WORDS.size() - 1)] % (first + 1)


# --- rescues, harvests, meals --------------------------------------------------------------------------------

func _poll_rescues() -> void:
	"""Each new assistance: the rescuer's and the victim's rows of one deed, and REQ-SET-036's affinity."""
	if rescue == null or rescue.assists == _assists:
		return
	var log_size: int = rescue.assisted_by.size()
	for k: int in range(maxi(log_size - (rescue.assists - _assists), 0), log_size):
		var rescuer: int = rescue.assisted_by[k]
		var victim: int = rescue.assisted_victim[k]
		var deed: int = _begin(Ledger.KIND_RESCUE, rescuer)
		ledger.add_event(deed, Ledger.KIND_RESCUE, rescuer, victim, NoticesScript.TARGET_RESIDENT, victim, "")
		ledger.add_event(deed, Ledger.KIND_RESCUED, victim, rescuer, NoticesScript.TARGET_RESIDENT, rescuer, "")
		ledger.add_rescue(rescuer, victim, _day)
	_assists = rescue.assists


func _poll_harvests() -> void:
	"""Each new harvest in store: its worker's first harvest, once."""
	if farm_crew == null or farm_crew.harvests == _harvests:
		return
	var log_size: int = farm_crew.harvested_by.size()
	for k: int in range(maxi(log_size - (farm_crew.harvests - _harvests), 0), log_size):
		var who: int = farm_crew.harvested_by[k]
		if not ledger.is_resident(who) or ledger.has_kind(who, Ledger.KIND_FIRST_HARVEST):
			continue
		var bed: int = farm_crew.harvested_bed[k]
		var item: int = farm_crew.harvested_item[k]
		var what: String = Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "a crop"
		var deed: int = _begin(Ledger.KIND_FIRST_HARVEST, who)
		ledger.add_event(deed, Ledger.KIND_FIRST_HARVEST, who, Ledger.NOBODY, NoticesScript.TARGET_BED, bed,
			"%s from bed %d" % [what, bed + 1])
	_harvests = farm_crew.harvests


func _poll_meals() -> void:
	"""Each meal the kitchen has finalized since the last look (its MEAL FINALIZED event): shared suppers, and a cook's
	first meal for everyone -- from its committed diners, never the provisional tally at its serving's end."""
	if kitchen == null or kitchen.finals_published == _last_final:
		return
	for final: KitchenScript.MealFinal in kitchen.finals:
		if final.serial <= _last_final:
			continue
		if posmod(final.key, 2) == 1:
			_shared_supper(final.diners)
		if final.without == 0 and not final.diners.is_empty():
			_cooked_for_all(final.key)
	_last_final = kitchen.finals_published


func _shared_supper(diners: PackedInt32Array) -> void:
	"""Every pair of a supper's committed diners (who ate a portion of it) shared it."""
	var n: int = residents()
	for x: int in diners.size():
		for y: int in range(x + 1, diners.size()):
			if diners[x] < n and diners[y] < n:
				ledger.add_supper(mini(diners[x], diners[y]), maxi(diners[x], diners[y]), _day)


func _cooked_for_all(key: int) -> void:
	"""Meal `key` fed everyone: each cook of its batches, at its first such meal, did it."""
	var cooks := PackedInt32Array()
	for b: int in kitchen.cooked_keys.size():
		if kitchen.cooked_keys[b] == key and b < kitchen.cooked_by.size() and not cooks.has(kitchen.cooked_by[b]):
			cooks.append(kitchen.cooked_by[b])
	for who: int in cooks:
		if ledger.is_resident(who) and not ledger.has_kind(who, Ledger.KIND_MEAL):
			var deed: int = _begin(Ledger.KIND_MEAL, who)
			ledger.add_event(deed, Ledger.KIND_MEAL, who, Ledger.NOBODY, NoticesScript.TARGET_NONE, -1,
				KitchenWords.meal_title(key).to_lower())


# --- skills ----------------------------------------------------------------------------------------------

func _poll_skills() -> void:
	"""Every SKILL_POLL_TICKS: a skill's level risen since the last look is a deed (one per level reached)."""
	var n: int = residents()
	if _skill_names.is_empty() or _skill_level.size() != n * _skill_names.size() or _tick() - _skill_tick < SKILL_POLL_TICKS:
		return
	_skill_tick = _tick()
	for s: int in _skill_names.size():
		for who: int in n:
			var level: int = ForestRules.level_of(skill_xp(s, who))
			while _skill_level[s * n + who] < level:
				_skill_level[s * n + who] += 1
				var deed: int = _begin(Ledger.KIND_SKILL, who)
				ledger.add_event(deed, Ledger.KIND_SKILL, who, Ledger.NOBODY, NoticesScript.TARGET_RESIDENT, who,
					_skill_names[s], _skill_level[s * n + who])


# --- shared work ----------------------------------------------------------------------------------------

func _poll_shared_work() -> void:
	"""Every SHARE_POLL_TICKS: each pair at work together over that time (see the header) shares those ticks."""
	var ticks: int = _tick() - _share_tick
	if ticks < SHARE_POLL_TICKS or _task_of.size() != residents():
		return
	_share_tick = _tick()
	_read_contexts()
	var n: int = residents()
	for a: int in n:
		for b: int in range(a + 1, n):
			if together(a, b):
				ledger.add_shared_work(a, b, ticks, _day)


func together(a: int, b: int) -> bool:
	"""Whether residents `a` and `b` are at work together now (as of the last `_read_contexts`)."""
	if _site_of[a] >= 0 and _site_of[a] == _site_of[b]:
		return true
	if _task_of[a] < 0 or _task_of[b] < 0 or board.crews.crew_of[a] != board.crews.crew_of[b]:
		return false
	return _at[a].distance_to(_at[b]) <= NEAR_M


func _read_contexts() -> void:
	"""Each resident's board task (source x 4096 + row; -1 none) and the dig it works (its segment; -1 none)."""
	_task_of.fill(-1)
	_site_of.fill(-1)
	if board != null:
		for id: int in WorkIds.SOURCE_COUNT:
			var src: SourceScript = board.source(id)
			if src == null:
				continue
			for row: int in src.capacity():
				var who: int = src.worker(row) if src.live(row) else -1
				if who >= 0 and who < _task_of.size():
					_task_of[who] = id * 4096 + row
					_at[who] = board.brain_of(who).position
	if network != null:
		for slot: int in TunnelRules.MAX_SEGMENTS:
			var lead: int = network.digger[slot]
			if network.phase[slot] == GraphScript.PHASE_DIGGING and lead >= 0 and lead < _site_of.size():
				_site_of[lead] = slot
	if tunnel_crew != null:
		for who: int in mini(tunnel_crew.member_site.size(), _site_of.size()):
			if tunnel_crew.member_site[who] >= 0 and tunnel_crew.member_present[who] == 1:
				_site_of[who] = tunnel_crew.member_site[who]
