extends RefCounted
## Every resident's digging skill. Decision 0208 (the underground revamp's P2; DEC-041's follow-up,
## LORE-P12). Presentation only.
##
## NO SPECIES LOCK. LORE-P12 (docs/setting_bible.md) and DEC-041: no species job locks and no hidden
## bonuses. Anybeast whose body fits a standard bore can dig one -- the rule is the body's (tunnel_rules.gd
## `fits_bore`, MOVE-REQ-005), not the species' -- and everyone gets better at it. What differs is shown:
## the skill level, beside the resident in the party panel (`line_of`, `short_of`). Moles start skilled
## (the design's working assumption, §10 ruling 5), as the forester and the bridgewright start at theirs.
##
## THE ARITHMETIC IS THE GDD's (§5.3), as the woods' and the bridges' are: XP_PER_WU (10) per completed
## productive WU, a WU "one game minute of base-speed productive labor" -- 12.5 of the settlement's 30 Hz
## ticks (750 an hour) -- so a quantum cut earns its dig ticks x 10 x 60 / 750 XP (a loam quantum's 113
## ticks: 90). The level is residents.gd's curve (forest_rules.gd `level_of`), and the skill factor
## 1000 + 50 x level scales the digging crew's rate (tunnel_crew.gd), in place of the old demo's
## "experience" bonus. Digging is a DEMO SKILL: §4.3's JobKind list names none for excavation, so it is kept
## here, apart from any settlement Skills row, and named as that gap.
##
## STARTING SKILL (demo): moles at level 3 (45000 XP, as the forester starts felling); everyone else at 0.
## Whoever works a face learns: the Foremole and every crew member at its post who fits the bore.

const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## A WU is one game minute: this many fixed ticks.
const TICKS_PER_HOUR: int = SimClock.TICKS_PER_HOUR
const MINUTES_PER_HOUR: int = 60
const SKILLED_LEVEL: int = 3
const NAME: String = "Digging"

## XP per resident index; bumped on any change.
var xp: PackedInt64Array = PackedInt64Array()
var revision: int = 0


func setup(species: PackedStringArray) -> void:
	"""One row per resident (by index), moles starting skilled."""
	xp.resize(species.size())
	for who in species.size():
		xp[who] = ForestRules.xp_of_level(SKILLED_LEVEL) if TunnelRules.is_digger(species[who]) else 0
	revision += 1


func set_resident(who: int, species: String) -> void:
	"""Know one more resident (setup only: the column grows here)."""
	if xp.size() <= who:
		xp.resize(who + 1)
	xp[who] = ForestRules.xp_of_level(SKILLED_LEVEL) if TunnelRules.is_digger(species) else 0
	revision += 1


func is_resident(who: int) -> bool:
	"""Whether `who` has a row."""
	return who >= 0 and who < xp.size()


static func xp_of_ticks(ticks: int) -> int:
	"""The XP a stretch of face work earns (see THE ARITHMETIC): its WU (ticks over a game minute's) x 10."""
	@warning_ignore("integer_division") return ticks * ForestRules.XP_PER_WU * MINUTES_PER_HOUR / TICKS_PER_HOUR


func level_of(who: int) -> int:
	"""A resident's digging level (§5.3's curve; 0 for no such resident)."""
	return ForestRules.level_of(xp[who]) if is_resident(who) else 0


func factor_permille(who: int) -> int:
	"""A resident's skill factor, per mille: 1000 + 50 x level (§5.3)."""
	return ForestRules.skill_factor_permille(level_of(who))


func add_ticks(who: int, ticks: int) -> bool:
	"""Credit `who` with `ticks` of face work. True when it reached a new level."""
	if not is_resident(who) or ticks <= 0:
		return false
	var before := level_of(who)
	xp[who] += xp_of_ticks(ticks)
	revision += 1
	return level_of(who) > before


func line_of(who: int) -> String:
	"""The party panel's line: "Digging 3 · XP 45000/80000" (the XP toward the next level, so learning
	shows)."""
	var level := level_of(who)
	var text := "%s %d" % [NAME, level]
	if level >= ForestRules.SKILL_LEVEL_MAX:
		return text
	return text + " · XP %d/%d" % [xp[who] if is_resident(who) else 0, ForestRules.xp_of_level(level + 1)]


func short_of(who: int) -> String:
	"""The multi-selection form: "dig 3"."""
	return "dig %d" % level_of(who)
