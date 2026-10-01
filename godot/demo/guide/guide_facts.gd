extends RefCounted
## THE OUTCOME LEDGER of the first-village guide (decision 0481; review F49, P7, UX-017): what has REALLY happened in
## the village, latched the moment it is seen and never unlatched. The guide's objectives complete on these facts and
## on nothing else -- never on a button pressed or a timer -- so an objective done before its card came up is already
## done when it does (P7: "completed-before-prompt objectives recognize real state"), and skipping or reopening the
## guide changes nothing here.
##
## `observe(world)` runs every frame (cheap: nine residents, six beds, six bridges), from the session's first frame,
## whether the guide is shown, hidden or finished:
##   * MET        a resident has been selected (the party panel then inspects it);
##   * HARVESTED  a delivery has shelved food in a store (farm_pantry.gd `delivered_milli`: a harvest carried and put
##                on the shelf -- an order given, a crop cut, a load in hand are not yet a harvest in store);
##   * SUPPER     a supper was tallied with someone having eaten a cooked portion (kitchen.gd's meal log: at the meal's
##                end, with those holding their portion counted as served -- never the plan, the pot or the call);
##   * BRIDGE     someone walked over the middle of an OPEN bridge's deck (on its crossing leg, out of the water);
##   * TUNNEL     someone went below at one place and came up at another at least WALKED_THROUGH_M away, without
##                digging on the way: a tunnel dug AND walked as a route (a dig crew comes up where it went down);
##   * FIELD      a bed with a crop standing is covered, raised, banked, ditched (Drain) or drained by a tunnel.
## The three last are objective 4's three ways; `choice` is the first done.

const WorldScript := preload("res://demo/guide/guide_world.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")

const CHOICE_NONE: int = -1
const CHOICE_BRIDGE: int = 0
const CHOICE_TUNNEL: int = 1
const CHOICE_FIELD: int = 2
const CHOICE_COUNT: int = 3
## A walk below counts as a route walked when it comes up this far from where it went down (demo value: a tunnel is at
## least 8 m mouth to mouth, tunnel_rules.gd; a dig crew or a home's own door comes up within a few metres).
const WALKED_THROUGH_M: float = 6.0
## The middle of a deck: over the water, whichever way the walker goes (the share of the deck from each end).
const DECK_MIDDLE_FROM: float = 0.3
const DECK_MIDDLE_TO: float = 0.7
## How far off a deck's centre line a walker on it may be, metres.
const DECK_HALF_WIDTH_M: float = 1.0
const NOBODY: int = -1
const FIELD_HOW: Array[String] = ["covered", "raised", "banked", "ditched", "drained by a tunnel"]

var met: bool = false
var met_who: int = NOBODY
var harvested_milli: int = 0
var harvested_item: int = Catalog.NO_ITEM
var supper_eaten: bool = false
## Every supper tallied with someone having eaten a cooked portion (a project's "suppers eaten" measure).
var suppers_eaten: int = 0
var supper_line: String = ""
## The latest supper tallied with nobody eating (its day; 0 for none).
var supper_missed_day: int = 0
var choice: int = CHOICE_NONE
var bridge_walker: int = NOBODY
var tunnel_walker: int = NOBODY
var field_bed: int = -1
var field_how: String = ""
## Bumped whenever a fact latches (the card redraws on a change).
var revision: int = 0

var _below_from: PackedVector2Array = PackedVector2Array()
var _was_below: PackedByteArray = PackedByteArray()
var _dug_below: PackedByteArray = PackedByteArray()
var _meals_seen: int = 0


func observe(world: WorldScript) -> void:
	"""Look at the village once (see the header); latch whatever has now happened."""
	_observe_met(world)
	_observe_harvest(world)
	_observe_suppers(world)
	_observe_walkers(world)
	_observe_field(world)


func done_choice(which: int) -> bool:
	"""Whether objective 4's way `which` (CHOICE_*) has happened."""
	match which:
		CHOICE_BRIDGE: return bridge_walker != NOBODY
		CHOICE_TUNNEL: return tunnel_walker != NOBODY
		CHOICE_FIELD: return field_bed >= 0
	return false


func _latch_choice(which: int) -> void:
	"""Record way `which` as objective 4's choice when it is the first done."""
	if choice == CHOICE_NONE:
		choice = which
	revision += 1


func _observe_met(world: WorldScript) -> void:
	"""MET: a resident is selected."""
	if met:
		return
	var chosen: PackedInt32Array = world.selection()
	if chosen.is_empty():
		return
	met = true
	met_who = chosen[0]
	revision += 1


func _observe_harvest(world: WorldScript) -> void:
	"""HARVESTED: the pantry's delivered total has grown."""
	if world.pantry == null or world.pantry.delivered_milli <= harvested_milli:
		return
	harvested_milli = world.pantry.delivered_milli
	harvested_item = world.pantry.last_delivered_item
	revision += 1


func _observe_suppers(world: WorldScript) -> void:
	"""SUPPER: each meal tallied since the last look; the first supper someone ate latches it, one nobody ate is
	remembered (the card says when the next one is)."""
	if world.kitchen == null:
		return
	var log_size: int = world.kitchen.meal_keys.size()
	if log_size < _meals_seen:
		_meals_seen = 0
	for k: int in range(_meals_seen, log_size):
		var key: int = world.kitchen.meal_keys[k]
		if key % 2 != Rules.MEAL_SUPPER:
			continue
		if world.kitchen.meal_ate[k] > 0:
			suppers_eaten += 1
		if world.kitchen.meal_ate[k] > 0 and not supper_eaten:
			supper_eaten = true
			supper_line = Words.tally_line(key, world.kitchen.meal_ate[k] + world.kitchen.meal_raw[k],
				world.kitchen.meal_without[k])
			revision += 1
		elif world.kitchen.meal_ate[k] <= 0:
			supper_missed_day = key / 2 + 1
			revision += 1
	_meals_seen = log_size


func _observe_walkers(world: WorldScript) -> void:
	"""BRIDGE and TUNNEL, resident by resident."""
	if _was_below.size() != world.brains.size():
		_track(world.brains.size())
	for i: int in world.brains.size():
		var brain: BrainScript = world.brains[i]
		if bridge_walker == NOBODY and _on_deck_middle(world, brain):
			bridge_walker = i
			_latch_choice(CHOICE_BRIDGE)
		_follow_below(i, brain)


func _track(count: int) -> void:
	"""Size the per-resident walk-below tracks."""
	_below_from.resize(count)
	_was_below.resize(count)
	_dug_below.resize(count)
	_was_below.fill(0)
	_dug_below.fill(0)


func _follow_below(i: int, brain: BrainScript) -> void:
	"""Where resident `i` went below, whether it dug there, and -- coming up far enough away -- TUNNEL."""
	var below: bool = brain.underground
	if below and _was_below[i] == 0:
		_below_from[i] = brain.position
		_dug_below[i] = 0
	if below and brain.activity() == BrainScript.ACTIVITY_DIGGING:
		_dug_below[i] = 1
	if not below and _was_below[i] == 1 and _dug_below[i] == 0 and tunnel_walker == NOBODY \
			and brain.position.distance_to(_below_from[i]) >= WALKED_THROUGH_M:
		tunnel_walker = i
		_latch_choice(CHOICE_TUNNEL)
	_was_below[i] = 1 if below else 0


static func _on_deck_middle(world: WorldScript, brain: BrainScript) -> bool:
	"""Whether `brain` is crossing over the middle of an open bridge's deck."""
	if world.bridges == null or brain.state != BrainScript.State.CROSS or brain.in_water:
		return false
	for row: int in BridgesScript.MAX_BRIDGES:
		if not world.bridges.is_open(row):
			continue
		var a: Vector2 = world.bridges.deck_end(row, false)
		var along: Vector2 = world.bridges.deck_end(row, true) - a
		if along.length_squared() <= 0.0:
			continue
		var t: float = (brain.position - a).dot(along) / along.length_squared()
		var off: float = (brain.position - (a + along * t)).length()
		if t >= DECK_MIDDLE_FROM and t <= DECK_MIDDLE_TO and off <= DECK_HALF_WIDTH_M:
			return true
	return false


func _observe_field(world: WorldScript) -> void:
	"""FIELD: the first bed with a crop standing that is readied (see FIELD_HOW)."""
	if field_bed >= 0 or world.sim == null:
		return
	for bed: int in Catalog.BED_COUNT:
		var how: String = readied_how(world.sim, bed)
		if not how.is_empty():
			field_bed = bed
			field_how = how
			_latch_choice(CHOICE_FIELD)
			return


static func readied_how(sim: SimScript, bed: int) -> String:
	"""How bed `bed` is readied against frost and wet ('' when it is not, or has no crop standing to protect)."""
	var stage: int = sim.stage_of(bed)
	if stage < SimScript.STAGE_SOWN or stage > SimScript.STAGE_RIPE:
		return ""
	var flags: Array[bool] = [sim.is_covered(bed), sim.is_raised(bed), sim.is_banked(bed), sim.is_ditched(bed),
		sim.is_drained(bed)]
	for k: int in flags.size():
		if flags[k]:
			return FIELD_HOW[k]
	return ""
