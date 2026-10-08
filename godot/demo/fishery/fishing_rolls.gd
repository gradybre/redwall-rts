extends RefCounted
## THE FISHING ROLLS: GDD §5.4's hazard roll (REQ-SET-053) and rare-quality roll, drawn from the core RNG's FISHING
## stream. Decision 1711 (the fishing revamp, #49). Presentation over integer rules; nothing here writes into the
## settlement simulation.
##
## THE STREAM. `scripts/core/rng.gd` STREAM_FISHING, seeded as ARCH-RNG-002 says from the demo world's one seed
## (care_rules.gd WORLD_SEED, the seed the infirmary's FORAGE stream already uses). This module is the stream's ONLY
## consumer ("No other system may consume these streams"). Its draw discipline is ARCH-RNG-002's: exactly ONE hazard
## roll and then ONE rare-quality roll per cycle, "closed/invalid cycles cancelled before departure consume none;
## already departed cancelled cycle retains saved rolls". So both are DRAWN when the cycle departs -- when it opens at
## the water, the moment its Expedition is created (`draw_into`) -- kept on the trip, and RESOLVED against the crew, the
## gear and the catch when it completes (`resolve_into`); a cycle called off after departure has spent its two draws,
## one never opened has spent none. Bounded draws are rng.gd's modulo, never rejection sampling. Cycles draw in the
## order they open, each keyed by the Expedition it opened with -- so the same run gives the same rolls; rendering and
## the camera never draw.
##
## THE HAZARD (§5.4): per 10000 completed cycles, `max(1, base*(1+danger) - 2*crew_skill - 4*additional_crew)` with
## base net 12, trap 8, weir 5, boat 20, ice 24 (fishing_driver.gd `injury_per_10000`, the one copy of the formula).
## A hit on net, trap or weir removes 20 health and gives a severity 1 bite; on a boat or the ice, severity 2 exposure
## and 35 (care_rules.gd NET_/BOAT_HAZARD_*, already cited from §5.4). "River pike and territorial eels are the
## encounter descriptions selected by habitat/day hash": rng.gd's stateless `hash_pair(habitat_type, day)` -- no stream
## draw -- picks which; both are hazards, never food (REQ-SET-056).
##
## THE RARE-QUALITY ROLL (§5.4): `min(1000, 100 + 30*skill)` per 10000 at the crew's skill (a boat's group skill);
## success makes 25% of the catch EXCELLENT, replacing that share (no extra biomass).

const Rng := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const CareRules := preload("res://demo/infirmary/care_rules.gd")

## The roll's denominator (§5.4: "per 10000").
const ROLL_DENOMINATOR: int = 10000
## §5.4's rare bonus: `min(1000, 100 + 30*skill)` per 10000; success makes 25% EXCELLENT.
const RARE_BASE_PER_10000: int = 100
const RARE_PER_LEVEL: int = 30
const RARE_MAX_PER_10000: int = 1000
const EXCELLENT_PERCENT: int = 25
const PERCENT: int = 100
## The encounter descriptions the habitat/day hash selects (§5.4; REQ-SET-056).
const ENCOUNTER_PIKE: int = 0
const ENCOUNTER_EEL: int = 1
const ENCOUNTER_WORDS: Array[String] = ["a pike", "a territorial eel"]

## What one completed cycle's rolls came to (caller-owned, reused).
class Outcome:
	var expedition: Vector2i = Vector2i(-1, 0)
	var hazard_per_10000: int = 0
	var hazard_roll: int = 0
	var hurt: bool = false
	var injury_kind: int = 0
	var injury_severity: int = 0
	var injury_loss: int = 0
	var encounter: int = ENCOUNTER_PIKE
	var rare_per_10000: int = 0
	var rare_roll: int = 0
	var excellent_milli: int = 0

## Totals since configure: cycles rolled, injuries, and EXCELLENT catch (milli-U).
var cycles_rolled: int = 0
var injuries: int = 0
var excellent_milli: int = 0

var _rng: Rng = Rng.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""The FISHING stream at the demo world's seed."""
	_rng.seed_world(CareRules.WORLD_SEED)


func draws() -> int:
	"""How many FISHING draws were taken (two a completed cycle)."""
	return _rng.draw_count_of(Rng.STREAM_FISHING).value


static func hazard_chance(gear: int, danger: int, crew_skill: int, crew: int) -> int:
	"""§5.4's injury chance per 10000 for a crew of `crew` (additional crew = crew - 1)."""
	return Driver.injury_per_10000(gear, danger, crew_skill, maxi(crew - 1, 0))


static func rare_chance(skill: int) -> int:
	"""§5.4's rare bonus chance per 10000: `min(1000, 100 + 30*skill)`."""
	return mini(RARE_MAX_PER_10000, RARE_BASE_PER_10000 + RARE_PER_LEVEL * maxi(skill, 0))


static func excellent_share(catch_milli: int) -> int:
	"""25% of a catch, rounded down: the EXCELLENT share a rare success makes of it."""
	@warning_ignore("integer_division") return maxi(catch_milli, 0) * EXCELLENT_PERCENT / PERCENT


static func hits(roll: int, chance: int) -> bool:
	"""Whether a draw 0..9999 succeeds against a chance per 10000: strictly below it."""
	return roll < chance


static func serious(gear: int) -> bool:
	"""Whether a hazard on this gear is §5.4's severity 2 exposure (boat, ice kit) rather than a bite."""
	return gear == Fishing.GEAR_BOAT or gear == Fishing.GEAR_ICE_KIT


static func encounter_of(habitat_type: int, day_index: int) -> int:
	"""§5.4's encounter description by habitat/day hash: ENCOUNTER_PIKE or ENCOUNTER_EEL (no stream draw)."""
	return Rng.hash_pair(habitat_type, day_index) & 1


func draw_into(expedition: Vector2i, out: Outcome) -> bool:
	"""A departing cycle's two draws, hazard then quality, into `out` (keyed by its Expedition). False (nothing drawn)
	only when the stream refuses -- it never does once seeded."""
	out.expedition = expedition
	if not _rng.draw_below_into(Rng.STREAM_FISHING, ROLL_DENOMINATOR, _read):
		return false
	out.hazard_roll = _read.value
	if not _rng.draw_below_into(Rng.STREAM_FISHING, ROLL_DENOMINATOR, _read):
		return false
	out.rare_roll = _read.value
	cycles_rolled += 1
	return true


func resolve_into(gear: int, danger: int, crew_skill: int, crew: int, catch_milli: int, out: Outcome) -> void:
	"""A completed cycle's results from the draws `out` holds: §5.4's chances for this gear and crew, the hazard and
	the EXCELLENT share of `catch_milli`; counted."""
	out.hazard_per_10000 = hazard_chance(gear, danger, crew_skill, crew)
	out.rare_per_10000 = rare_chance(crew_skill)
	settle(out, gear, catch_milli)
	injuries += 1 if out.hurt else 0
	excellent_milli += out.excellent_milli


func roll_into(expedition: Vector2i, gear: int, danger: int, crew_skill: int, crew: int, catch_milli: int,
		out: Outcome) -> bool:
	"""Draw and resolve at once (a cycle that departs and completes together). False when nothing could be drawn."""
	if not draw_into(expedition, out):
		return false
	resolve_into(gear, danger, crew_skill, crew, catch_milli, out)
	return true


static func settle(out: Outcome, gear: int, catch_milli: int) -> void:
	"""An outcome's results from its two draws and chances: the hazard (a hit strictly below its chance, with §5.4's
	injury for the gear) and the EXCELLENT share (a quarter of the catch on a rare success, else none)."""
	out.hurt = hits(out.hazard_roll, out.hazard_per_10000)
	var bad: bool = serious(gear)
	out.injury_kind = CareRules.BOAT_HAZARD_KIND if bad else CareRules.NET_HAZARD_KIND
	out.injury_severity = CareRules.BOAT_HAZARD_SEVERITY if bad else CareRules.NET_HAZARD_SEVERITY
	out.injury_loss = CareRules.BOAT_HAZARD_LOSS if bad else CareRules.NET_HAZARD_LOSS
	out.excellent_milli = excellent_share(catch_milli) if hits(out.rare_roll, out.rare_per_10000) else 0


static func hazard_words(gear: int, encounter: int) -> String:
	"""What happened, in words: 'a pike bit' / 'a territorial eel bit', or the cold water on a boat or the ice."""
	if gear == Fishing.GEAR_BOAT:
		return "went over the side into the cold water"
	if gear == Fishing.GEAR_ICE_KIT:
		return "was chilled through at the ice hole"
	return "was bitten by %s" % ENCOUNTER_WORDS[clampi(encounter, 0, 1)]
