extends RefCounted
## THE FIT-OUT: what stands in each burrow home and root cellar. Decision 0210 (the underground revamp's P4, "Fit-out
## and living"; design docs/design/underground_revamp.md §2 "Living", §4 "Fit-out", §8 P4). Presentation only: the
## demo's rooms shape the demo cast's nights and the pantry demo's stores, and nothing here writes into the
## simulation -- the HUD's Beds are the simulation's.
##
## PLACES. A dug room is BARE. Its template's places (underground_rooms.gd FIXTURES: a home's three bed alcoves,
## hearth, table, rag rug, lantern and hanging stores; a cellar's two shelves, pantry rack, root bin and hanging
## stores) each take one fixture of their own kind -- the palette's fixtures go on them as on sockets. A place is
## EMPTY, PLANNED (paid for, waiting for a resident to put it in: fixture_crew.gd) or INSTALLED. Ordering a kind
## fills the first empty place of that kind; taking one out empties the last. The SUGGESTED LAYOUT fills every
## empty place of the room at once: the cozy default a player then edits.
##
## COSTS, from the demo's one stores (tunnel_stores.gd: wood, stone, planks; the design's working assumption, which
## Brendan's rulings keep), ALL OR NOTHING with the refusal in words (REASONS). Taking a fixture out gives its cost
## back. The GDD rows (§5.8: bed wood 2 + cloth 1, 20 WU; hearth stone 6, 60 WU; shelf wood 2, 16 WU; decoration
## wood 1 + wax 0.25) become planks where the GDD says worked wood and wood where it says a decoration, the demo having
## no cloth or wax:
##   kind              planks  wood  stone  install WU  cellar capacity
##   bed                  2      .     .        20            .
##   hearth               .      .     6        60            .
##   table and stools     2      .     .         8            .
##   shelf                2      .     .        16           20 U
##   rag rug              .      1     .         4            .
##   pantry rack          2      .     .        16           30 U
##   root bin             2      .     .        12           25 U
##   hanging stores       .      1     .         4           10 U
##   lantern              .      1     .         4            .
## A WU is INSTALL_USEC_PER_WU of demo time for the one resident putting it in (a demo value, a tenth of the farm's
## 1.5 s: a walk across the village takes game hours on the demo calendar, so a bed is 1.2 game hours' work, a hearth
## 3.6). A resident called away keeps its place: the place is KEPT for it (`asked`) until fixture_crew.gd lets it lapse.
##
## COMFORT (a home's readout, 0..10000 as the GDD's needs; presentation only, no GDD mechanic): FLOOR_COMFORT (the
## GDD's floor/camp 2000) for a bare home; BED_COMFORT more with a bed in it; HEARTH_COMFORT more with a hearth, so a
## bed and a hearth reach the GDD's dormitory target 6000; and DECORATION_COMFORT for each rug, table, lantern and
## string of hanging stores (the design's "rug, lantern, hanging herbs", and the table), the decorations capped at
## DECORATION_CAP (the GDD: "decorations add up to 1000"); at most 10000. The suggested layout reads 7000, "cozy".
##
## A ROOT CELLAR'S CAPACITY is the sum of its installed storage fixtures' (CAPACITY_U); a bare cellar holds nothing
## and is not a store. THE COOL RULE: a cellar is cool -- the GDD's cellar factor, 350 per mille, where a warm one is
## the pantry's 750 (§5.8) -- while it is DEEP (its floor at least COOL_DEPTH_U down), has at least one storage
## fixture, and no hearth warms it: none in a home whose void lies within HEAT_REACH_U of its void, and none in a room
## it OPENS ONTO (one whose socket a run of passages no longer than OPENS_ONTO_U, through no other room, reaches from
## one of its sockets; two ramps' runs are longer, so no such run passes a mouth).

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const EMPTY: int = 0
const PLANNED: int = 1
const INSTALLED: int = 2
const PLACES: int = RoomsScript.MAX_PLACES
const COST_PLANKS_MILLI: Array[int] = [2000, 0, 2000, 2000, 0, 2000, 2000, 0, 0]
const COST_WOOD_MILLI: Array[int] = [0, 0, 0, 0, 1000, 0, 0, 1000, 1000]
const COST_STONE_MILLI: Array[int] = [0, 6000, 0, 0, 0, 0, 0, 0, 0]
const INSTALL_WU: Array[int] = [20, 60, 8, 16, 4, 16, 12, 4, 4]
const INSTALL_USEC_PER_WU: int = 150000
const CAPACITY_U: Array[int] = [0, 0, 0, 20, 0, 30, 25, 10, 0]
const FLOOR_COMFORT: int = 2000
const BED_COMFORT: int = 2000
const HEARTH_COMFORT: int = 2000
const DECORATION_COMFORT: int = 250
const DECORATION_CAP: int = 1000
const MAX_COMFORT: int = 10000
const DECORATIONS: Array[int] = [RoomsScript.FIX_RUG, RoomsScript.FIX_TABLE, RoomsScript.FIX_LANTERN, RoomsScript.FIX_HANGING]
## The comfort words: the first whose floor the comfort reaches, from the top.
const COMFORT_FLOORS: Array[int] = [6500, 5000, 3000, 0]
const COMFORT_WORDS: Array[String] = ["cozy", "snug", "plain", "bare"]
const COOL_DEPTH_U: int = 1024
const HEAT_REACH_U: int = 3072
const OPENS_ONTO_U: int = 6144

const COOL_YES: int = 0
const COOL_SHALLOW: int = 1
const COOL_NO_RACK: int = 2
const COOL_HEARTH_NEAR: int = 3
const COOL_HEARTH_OPENS: int = 4
const COOL_WORDS: Array[String] = ["cool: deep, racked and away from any hearth", "warm: not dug deep enough to keep cool",
	"not a store yet: it needs a shelf, a rack, a bin or hanging stores",
	"warm: a hearth within 3 m of it warms it", "warm: it opens onto a room with a hearth"]

const REFUSE_NONE: int = 0
const REFUSE_NOT_DUG: int = 1
const REFUSE_NOT_HERE: int = 2
const REFUSE_FULL: int = 3
const REFUSE_SHORT: int = 4
const REFUSE_NOTHING_TO_ADD: int = 5
const REFUSE_NONE_TO_TAKE: int = 6
const REFUSE_HOLDS_FOOD: int = 7
const REASONS: Array[String] = ["", "%s is not dug out yet", "a %s has no place in a %s",
	"every place for a %s in %s is taken", "the demo stores are short: %s needs %s (they hold %s)",
	"%s is fitted out already", "%s has no %s to take out",
	"%s holds %d U of food: its racks cannot drop below that"]

## Per (room, place) -- row r * PLACES + place: its phase, who is putting it in (-1: nobody), their work so far (demo
## usec), and who it is kept for (-1: anybody) -- the one called away from it (fixture_crew.gd gives it to them, and
## to no one else until the keep lapses).
var phase: PackedByteArray = PackedByteArray()
var worker: PackedInt32Array = PackedInt32Array()
var work_usec: PackedInt64Array = PackedInt64Array()
var asked: PackedInt32Array = PackedInt32Array()
## How long each place has been kept for its keeper (demo usec; fixture_crew.gd ages it and lets the keep lapse).
var kept_usec: PackedInt64Array = PackedInt64Array()
## The room generation each room's places belong to: a room row laid again starts bare.
var _gen: PackedInt32Array = PackedInt32Array()
## Bumped on every change.
var revision: int = 0
## Scratch for the cool rule's walk (sized once).
var _dist: PackedInt32Array = PackedInt32Array()
var _queue: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Size every column once: every place empty."""
	phase.resize(RoomsScript.MAX_ROOMS * PLACES)
	worker.resize(RoomsScript.MAX_ROOMS * PLACES)
	worker.fill(-1)
	work_usec.resize(RoomsScript.MAX_ROOMS * PLACES)
	asked.resize(RoomsScript.MAX_ROOMS * PLACES)
	asked.fill(-1)
	kept_usec.resize(RoomsScript.MAX_ROOMS * PLACES)
	_gen.resize(RoomsScript.MAX_ROOMS)
	_gen.fill(-1)
	_dist.resize(Rules.MAX_NODES)


# --- the catalogue (static) -----------------------------------------------------------------

static func place_kind(template: int, f: int) -> int:
	"""The kind of fixture place `f` of `template` takes."""
	return RoomsScript.fixture_field(template, f, 0)


static func allows(template: int, kind: int) -> bool:
	"""Whether `template` has any place for a fixture of `kind`."""
	for f in RoomsScript.fixture_count(template):
		if place_kind(template, f) == kind:
			return true
	return false


static func palette(template: int) -> PackedInt32Array:
	"""The kinds `template`'s places take, each once, in the order of their first place."""
	var kinds := PackedInt32Array()
	for f in RoomsScript.fixture_count(template):
		if not kinds.has(place_kind(template, f)):
			kinds.append(place_kind(template, f))
	return kinds


static func install_usec(kind: int) -> int:
	"""How long one resident takes to put a fixture of `kind` in (demo usec)."""
	return INSTALL_WU[kind] * INSTALL_USEC_PER_WU


static func is_storage(kind: int) -> bool:
	"""Whether `kind` holds food in a cellar (a shelf, a rack, a bin, hanging stores)."""
	return CAPACITY_U[kind] > 0


static func cost_text(kind: int) -> String:
	"""What a fixture of `kind` costs, in words: "2 planks", "6 stone"."""
	return amounts_text(COST_PLANKS_MILLI[kind], COST_WOOD_MILLI[kind], COST_STONE_MILLI[kind])


static func amounts_text(planks: int, wood: int, stone: int) -> String:
	"""Whole units of planks, wood and stone in words, the ones that are not nothing ("8 planks, 2 wood")."""
	var parts := PackedStringArray()
	for pair: Array in [[planks, "planks"], [wood, "wood"], [stone, "stone"]]:
		if int(pair[0]) > 0:
			parts.append("%d %s" % [int(pair[0]) / 1000, pair[1]])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


static func refusal_text(code: int, words: Array) -> String:
	"""A refusal (REFUSE_*) in words, filled with `words` (see REASONS)."""
	return REASONS[code] % words


# --- a room's places ------------------------------------------------------------------------

func _sync(graph: RefCounted, r: int) -> void:
	"""Room row `r`'s places follow its generation: a room laid again starts bare."""
	var gen: int = graph.rooms.generation[r]
	if _gen[r] == gen:
		return
	_gen[r] = gen
	for f in PLACES:
		_clear(r * PLACES + f)
	revision += 1


func _clear(row: int) -> void:
	"""Place row `row` empty, nobody on it."""
	phase[row] = EMPTY
	worker[row] = -1
	work_usec[row] = 0
	asked[row] = -1


func phase_of(graph: RefCounted, r: int, f: int) -> int:
	"""Place `f` of room `r`: EMPTY, PLANNED or INSTALLED (a place its template lacks is never planned: EMPTY)."""
	_sync(graph, r)
	return phase[r * PLACES + f]


func count(graph: RefCounted, r: int, kind: int, at_least: int) -> int:
	"""How many of room `r`'s places of `kind` are at least `at_least` (PLANNED counts installed ones too)."""
	var template: int = graph.rooms.template[r]
	var n := 0
	for f in RoomsScript.fixture_count(template):
		if place_kind(template, f) == kind and phase_of(graph, r, f) >= at_least:
			n += 1
	return n


func _place_of(graph: RefCounted, r: int, kind: int, wanted: int, last: bool) -> int:
	"""Room `r`'s first (or last) place of `kind` in phase `wanted` (-1: none)."""
	var template: int = graph.rooms.template[r]
	var found := -1
	for f in RoomsScript.fixture_count(template):
		if place_kind(template, f) == kind and phase_of(graph, r, f) == wanted:
			found = f
			if not last:
				return f
	return found


func _last_taken(graph: RefCounted, r: int, kind: int) -> int:
	"""Room `r`'s last place of `kind` that is not empty (-1: none): planned ones go before installed ones."""
	var f := _place_of(graph, r, kind, PLANNED, true)
	return f if f >= 0 else _place_of(graph, r, kind, INSTALLED, true)


# --- ordering, taking out, the suggested layout -----------------------------------------------

func order(graph: RefCounted, r: int, kind: int, stores: RefCounted) -> int:
	"""Plan a fixture of `kind` in room `r`'s first empty place of that kind, paying its cost from `stores` all or
	nothing. REFUSE_NONE, or why not (see REASONS)."""
	var refused := _order_refusal(graph, r, kind)
	if refused != REFUSE_NONE:
		return refused
	if not stores.pay_all(COST_WOOD_MILLI[kind], COST_STONE_MILLI[kind], COST_PLANKS_MILLI[kind]):
		return REFUSE_SHORT
	_plan(r * PLACES + _place_of(graph, r, kind, EMPTY, false))
	return REFUSE_NONE


func _order_refusal(graph: RefCounted, r: int, kind: int) -> int:
	"""Why a fixture of `kind` may not be planned in room `r`, before the cost (REFUSE_NONE: it may)."""
	if not graph.rooms.is_done(graph, r):
		return REFUSE_NOT_DUG
	if not allows(graph.rooms.template[r], kind):
		return REFUSE_NOT_HERE
	if _place_of(graph, r, kind, EMPTY, false) < 0:
		return REFUSE_FULL
	return REFUSE_NONE


func _plan(row: int) -> void:
	"""Place row `row` is paid for and waits for anybody to put it in."""
	phase[row] = PLANNED
	worker[row] = -1
	work_usec[row] = 0
	asked[row] = -1
	revision += 1


func suggest(graph: RefCounted, r: int, stores: RefCounted) -> int:
	"""THE SUGGESTED LAYOUT: plan a fixture in every empty place of room `r` at once, paying for all of them or none.
	REFUSE_NONE, or why not."""
	if not graph.rooms.is_done(graph, r):
		return REFUSE_NOT_DUG
	var cost := missing_cost(graph, r)
	if cost == Vector3i.ZERO:
		return REFUSE_NOTHING_TO_ADD
	if not stores.pay_all(cost.y, cost.z, cost.x):
		return REFUSE_SHORT
	var template: int = graph.rooms.template[r]
	for f in RoomsScript.fixture_count(template):
		if phase_of(graph, r, f) == EMPTY:
			_plan(r * PLACES + f)
	return REFUSE_NONE


func missing_cost(graph: RefCounted, r: int) -> Vector3i:
	"""What the suggested layout would cost room `r` now: (planks, wood, stone) milli-U for its empty places."""
	var template: int = graph.rooms.template[r]
	var cost := Vector3i.ZERO
	for f in RoomsScript.fixture_count(template):
		if phase_of(graph, r, f) == EMPTY:
			var kind := place_kind(template, f)
			cost += Vector3i(COST_PLANKS_MILLI[kind], COST_WOOD_MILLI[kind], COST_STONE_MILLI[kind])
	return cost


func take_out(graph: RefCounted, r: int, kind: int, stores: RefCounted, stored_u: int = 0) -> int:
	"""Take room `r`'s last fixture of `kind` out (a planned one before an installed one), its cost back into
	`stores`. A cellar holding `stored_u` of food keeps racks for at least that. REFUSE_NONE, or why not."""
	var f := _last_taken(graph, r, kind)
	if f < 0:
		return REFUSE_NONE_TO_TAKE
	var row := r * PLACES + f
	if phase[row] == INSTALLED and is_storage(kind) and capacity_u(graph, r) - CAPACITY_U[kind] < stored_u:
		return REFUSE_HOLDS_FOOD
	stores.refund(COST_WOOD_MILLI[kind], COST_STONE_MILLI[kind], COST_PLANKS_MILLI[kind])
	_clear(row)
	revision += 1
	return REFUSE_NONE


# --- putting it in (fixture_crew.gd) ----------------------------------------------------------

func claim(graph: RefCounted, r: int, f: int, who: int) -> bool:
	"""Resident `who` starts on planned place `f` of room `r` (any keep on it ends: called away again, it keeps it
	afresh). False when it is not planned or has someone."""
	var row := r * PLACES + f
	if phase_of(graph, r, f) != PLANNED or worker[row] >= 0:
		return false
	worker[row] = who
	asked[row] = -1
	revision += 1
	return true


func let_go(r: int, f: int, who: int) -> void:
	"""Resident `who` leaves place `f` of room `r` (called away): its work so far is kept, and the place is kept for it
	(`asked`) to come back to."""
	var row := r * PLACES + f
	if worker[row] == who:
		worker[row] = -1
		asked[row] = who
		kept_usec[row] = 0
		revision += 1


func release_keep(row: int) -> void:
	"""Place row `row` is no longer kept for anyone (fixture_crew.gd: the keep lapsed)."""
	asked[row] = -1


func work(graph: RefCounted, r: int, f: int, who: int, usec: int) -> bool:
	"""Resident `who` works `usec` more on place `f` of room `r`; true once the fixture is in (INSTALLED)."""
	var row := r * PLACES + f
	if phase_of(graph, r, f) != PLANNED or worker[row] != who:
		return phase_of(graph, r, f) == INSTALLED
	work_usec[row] += maxi(usec, 0)
	if work_usec[row] < install_usec(place_kind(graph.rooms.template[r], f)):
		return false
	phase[row] = INSTALLED
	worker[row] = -1
	asked[row] = -1
	revision += 1
	return true


func waiting_into(graph: RefCounted, out: PackedInt32Array) -> int:
	"""Every planned place nobody is on, as rows (r * PLACES + f) into `out` (cleared first); how many. (Only a dug
	room's places are ever planned, and a room laid again starts bare.)"""
	out.clear()
	for r in RoomsScript.MAX_ROOMS:
		for f in RoomsScript.fixture_count(graph.rooms.template[r]):
			if phase_of(graph, r, f) == PLANNED and worker[r * PLACES + f] < 0:
				out.append(r * PLACES + f)
	return out.size()


# --- what the fit-out gives ---------------------------------------------------------------------

func comfort(graph: RefCounted, r: int) -> int:
	"""A home's comfort readout (see COMFORT) from its installed fixtures."""
	var decorations := 0
	for kind: int in DECORATIONS:
		decorations += count(graph, r, kind, INSTALLED)
	return comfort_of(count(graph, r, RoomsScript.FIX_BED, INSTALLED) > 0, count(graph, r, RoomsScript.FIX_HEARTH, INSTALLED) > 0,
		decorations)


static func comfort_of(bed: bool, hearth: bool, decorations: int) -> int:
	"""THE COMFORT FORMULA on its facts: a bed in, a hearth in, how many decorations (see COMFORT)."""
	var value := FLOOR_COMFORT + (BED_COMFORT if bed else 0) + (HEARTH_COMFORT if hearth else 0)
	return mini(value + mini(decorations * DECORATION_COMFORT, DECORATION_CAP), MAX_COMFORT)


static func comfort_word(value: int) -> String:
	"""Comfort in a word (see COMFORT_FLOORS)."""
	for k in COMFORT_FLOORS.size():
		if value >= COMFORT_FLOORS[k]:
			return COMFORT_WORDS[k]
	return COMFORT_WORDS[-1]


func capacity_u(graph: RefCounted, r: int) -> int:
	"""A cellar's capacity: its installed storage fixtures' (0: bare, not a store)."""
	var template: int = graph.rooms.template[r]
	var total := 0
	for f in RoomsScript.fixture_count(template):
		if phase_of(graph, r, f) == INSTALLED:
			total += CAPACITY_U[place_kind(template, f)]
	return total


func storage_count(graph: RefCounted, r: int) -> int:
	"""How many storage fixtures room `r` has installed."""
	var template: int = graph.rooms.template[r]
	var n := 0
	for f in RoomsScript.fixture_count(template):
		n += 1 if phase_of(graph, r, f) == INSTALLED and is_storage(place_kind(template, f)) else 0
	return n


func has_hearth(graph: RefCounted, r: int) -> bool:
	"""Whether room `r` has a hearth installed (only a dug room's places are)."""
	return count(graph, r, RoomsScript.FIX_HEARTH, INSTALLED) > 0


# --- the cool rule ------------------------------------------------------------------------------

static func cool_of(depth_u: int, storage: int, hearth_near: bool, hearth_opens: bool) -> int:
	"""THE COOL RULE on its facts: COOL_YES, or the first reason it is not."""
	if depth_u < COOL_DEPTH_U:
		return COOL_SHALLOW
	if storage < 1:
		return COOL_NO_RACK
	if hearth_near:
		return COOL_HEARTH_NEAR
	return COOL_HEARTH_OPENS if hearth_opens else COOL_YES


func cool(graph: RefCounted, r: int) -> int:
	"""Root cellar `r` under THE COOL RULE: COOL_YES, or why it is not cool."""
	var rooms: RoomsScript = graph.rooms
	return cool_of(Rules.level_floor_depth_u(rooms.level[r]), storage_count(graph, r), _hearth_near(graph, r),
		_hearth_opens(graph, r))


func is_cool(graph: RefCounted, r: int) -> bool:
	"""Whether root cellar `r` is cool (see THE COOL RULE)."""
	return cool(graph, r) == COOL_YES


func _hearth_near(graph: RefCounted, r: int) -> bool:
	"""Whether a home with a hearth has its void within HEAT_REACH_U of room `r`'s void."""
	var rooms: RoomsScript = graph.rooms
	for h in RoomsScript.MAX_ROOMS:
		if h == r or not has_hearth(graph, h) or rooms.level[h] != rooms.level[r]:
			continue
		if RoomsScript.voids_gap_u(rooms.template[r], rooms.centre(r), rooms.turns[r], rooms.template[h],
				rooms.centre(h), rooms.turns[h]) < HEAT_REACH_U:
			return true
	return false


func _hearth_opens(graph: RefCounted, r: int) -> bool:
	"""Whether room `r` OPENS ONTO a room with a hearth (see THE COOL RULE)."""
	_walk_from_sockets(graph, r)
	var rooms: RoomsScript = graph.rooms
	for h in RoomsScript.MAX_ROOMS:
		if h == r or not has_hearth(graph, h):
			continue
		for k in RoomsScript.socket_count(rooms.template[h]):
			var node := rooms.socket_of(h, k)
			if node >= 0 and _dist[node] <= OPENS_ONTO_U:
				return true
	return false


func _walk_from_sockets(graph: RefCounted, r: int) -> void:
	"""How far each node lies from room `r`'s sockets along open passages, through no room (u, into _dist; far beyond
	OPENS_ONTO_U: not reached). Nodes are relaxed from a queue until nothing shortens. (A way through the open air
	would go up one mouth's ramp and down another's, two ramps' runs -- longer than OPENS_ONTO_U -- so no walk it
	counts passes a mouth.)"""
	_dist.fill(OPENS_ONTO_U + 1)
	_queue.clear()
	for k in RoomsScript.socket_count(graph.rooms.template[r]):
		var node: int = graph.rooms.socket_of(r, k)
		if node >= 0:
			_dist[node] = 0
			_queue.append(node)
	var head := 0
	while head < _queue.size():
		_relax(graph, _queue[head])
		head += 1


func _relax(graph: RefCounted, node: int) -> void:
	"""Shorten the way to every node one open passage on from `node` (see `_walk_from_sockets`)."""
	for j in Rules.JUNCTION_DEGREE:
		var slot: int = graph.node_segment(node, j)
		if slot < 0 or not graph.is_open(slot) or graph.seg_room[slot] >= 0:
			continue
		var next: int = graph.other_end(slot, node)
		var d: int = _dist[node] + graph.length_u[slot]
		if d < _dist[next]:
			_dist[next] = d
			_queue.append(next)


# --- beds ---------------------------------------------------------------------------------------

func beds_into(graph: RefCounted, out: PackedInt32Array) -> int:
	"""Every installed bed (in a home, dug: only a dug room's places are installed), as (id, x, z) triples in u into `out` (cleared first), ids ascending: id =
	room * PLACES + place, so a lower id is a lower room, then a lower place (REQ-SET-132's tie order). How many."""
	out.clear()
	var rooms: RoomsScript = graph.rooms
	for r in RoomsScript.MAX_ROOMS:
		if rooms.template[r] != RoomsScript.TEMPLATE_HOME:
			continue
		for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
			if place_kind(RoomsScript.TEMPLATE_HOME, f) == RoomsScript.FIX_BED and phase_of(graph, r, f) == INSTALLED:
				var at := rooms.to_world_u(r, place_u(RoomsScript.TEMPLATE_HOME, f))
				out.append_array([r * PLACES + f, at.x, at.y])
	return out.size() / 3


static func place_u(template: int, f: int) -> Vector2i:
	"""Where place `f` of `template` stands, in the room's own frame (u)."""
	return Vector2i(RoomsScript.fixture_field(template, f, 1), RoomsScript.fixture_field(template, f, 2))


func installed_beds(graph: RefCounted) -> int:
	"""How many beds are installed in homes (only dug ones have any)."""
	var n := 0
	for r in RoomsScript.MAX_ROOMS:
		if graph.rooms.template[r] == RoomsScript.TEMPLATE_HOME:
			n += count(graph, r, RoomsScript.FIX_BED, INSTALLED)
	return n
