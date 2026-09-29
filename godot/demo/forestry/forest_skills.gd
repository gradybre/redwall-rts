extends RefCounted
## Every resident's felling and sawing experience. Decision 0196 (live demo). Presentation only.
##
## LORE-P12 (docs/setting_bible.md) and DEC-041: no species job locks and no hidden bonuses -- anybeast
## can fell and saw, and anybeast gets better at it. What differs is shown: the skill level, beside
## the resident in the party panel. The beaver fells by gnawing; that is the same felling job and
## the same skill, drawn with its own look.
##
## THE ARITHMETIC IS THE GDD's (§5.3), not the demo's: XP is 10 per completed productive WU; the
## level is residents.gd's own curve (min(10, floor_sqrt(floor(xp/5000)))), and the skill factor
## 1000 + 50 x level divides the work's time (forest_rules.gd `work_usec`). Felling and sawing are
## DEMO SKILLS: §4.3's JobKind list (HAUL, BUILD, FISH, ... HEAL) names none for wood, and which of
## its twelve a tree extraction trains is not stated -- so they are kept here, apart from any
## settlement Skills row, and named as that gap.
##
## STARTING SKILL (demo): the squirrel forester and the beaver bridgewright start at level 3 felling
## (45000 XP, the Warden's starting KEEP figure in §5.1) and level 2 sawing (20000, §5.1's starting
## level); everyone else starts at 0 and learns.

const Rules := preload("res://demo/forestry/forest_rules.gd")

const SKILLED_KEYS: Array[StringName] = [&"squirrel_forester", &"beaver_bridgewright"]
const SKILLED_FELLING_XP: int = 45000
const SKILLED_SAWING_XP: int = 20000
## Who fells by gnawing (DEC-041's beaver): the same job, with no axe and a gnawed look.
const GNAWING_SPECIES: Array[String] = ["beaver"]

## XP per resident and skill: row `who * SKILL_COUNT + skill`.
var xp: PackedInt64Array = PackedInt64Array()
var gnaws: PackedByteArray = PackedByteArray()
var revision: int = 0

var _residents: int = 0


func setup(keys: Array[StringName], species: PackedStringArray) -> void:
	"""One row per resident (`keys` and `species` by actor index), with the skilled ones' start."""
	_residents = keys.size()
	xp.resize(_residents * Rules.SKILL_COUNT)
	xp.fill(0)
	gnaws.resize(_residents)
	for who: int in _residents:
		if SKILLED_KEYS.has(keys[who]):
			xp[who * Rules.SKILL_COUNT + Rules.SKILL_FELLING] = SKILLED_FELLING_XP
			xp[who * Rules.SKILL_COUNT + Rules.SKILL_SAWING] = SKILLED_SAWING_XP
		gnaws[who] = 1 if GNAWING_SPECIES.has(species[who]) else 0
	revision += 1


func is_resident(who: int) -> bool:
	"""Whether `who` has a row."""
	return who >= 0 and who < _residents


func xp_of(who: int, skill: int) -> int:
	"""A resident's XP in a skill (0 for no such resident)."""
	return xp[who * Rules.SKILL_COUNT + skill] if is_resident(who) else 0


func level_of(who: int, skill: int) -> int:
	"""A resident's level in a skill (§5.3's curve)."""
	return Rules.level_of(xp_of(who, skill))


func add_work(who: int, skill: int, wu: int) -> bool:
	"""Credit `wu` completed WU of work in `skill`: XP_PER_WU each. True when a new level was reached."""
	if not is_resident(who) or wu <= 0:
		return false
	var before: int = level_of(who, skill)
	xp[who * Rules.SKILL_COUNT + skill] += wu * Rules.XP_PER_WU
	revision += 1
	return level_of(who, skill) > before


func gnaws_wood(who: int) -> bool:
	"""Whether this resident fells by gnawing."""
	return is_resident(who) and gnaws[who] == 1


func line_of(who: int) -> String:
	"""The party panel's line: "Felling 3 · Sawing 2 · XP 45000/80000" -- the stronger skill's XP
	toward its next level, so learning shows."""
	var fell: int = level_of(who, Rules.SKILL_FELLING)
	var saw: int = level_of(who, Rules.SKILL_SAWING)
	var skill: int = Rules.SKILL_FELLING if fell >= saw else Rules.SKILL_SAWING
	var level: int = maxi(fell, saw)
	var text: String = "%s %d · %s %d" % [Rules.SKILL_NAMES[0], fell, Rules.SKILL_NAMES[1], saw]
	if level >= Rules.SKILL_LEVEL_MAX:
		return text
	return text + " · XP %d/%d" % [xp_of(who, skill), Rules.xp_of_level(level + 1)]



func short_of(who: int) -> String:
	"""The multi-selection form: "fell 3/saw 2"."""
	return "fell %d/saw %d" % [level_of(who, Rules.SKILL_FELLING), level_of(who, Rules.SKILL_SAWING)]
