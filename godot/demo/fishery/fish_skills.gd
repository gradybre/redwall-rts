extends RefCounted
## Every resident's FISH skill (GDD §5.3's FISH job kind). Decision 0431 (live demo). Presentation only.
##
## LORE-P12: no species lock and no hidden bonus -- anybeast may fish, net, row or ice-fish, and gets better at it by
## doing it. XP is §5.3's 10 a completed productive WU, the level residents.gd's own curve (forest_rules.gd `level_of`).
## The seeds are fishery_rules.gd FISH_SEED_* (DEMO, by trade): the otter fisher starts at level 4, the otter
## boatwright at 2, everyone else at 0. A boat's helm needs level HELM_MIN_LEVEL; anyone may take its second seat and
## learn there.

const Rules := preload("res://demo/fishery/fishery_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

## XP per resident.
var xp: PackedInt64Array = PackedInt64Array()
## Milli-WU done but not yet a whole WU, per resident (XP is awarded on whole WU).
var _mwu_carry: PackedInt64Array = PackedInt64Array()
var revision: int = 0


func setup(keys: Array[StringName]) -> void:
	"""One row per resident (`keys` by actor index), seeded by trade."""
	xp.resize(keys.size())
	xp.fill(0)
	_mwu_carry.resize(keys.size())
	_mwu_carry.fill(0)
	for who: int in keys.size():
		var seed: int = Rules.FISH_SEED_KEYS.find(keys[who])
		if seed >= 0:
			xp[who] = ForestRules.xp_of_level(Rules.FISH_SEED_LEVELS[seed])
	revision += 1


func is_resident(who: int) -> bool:
	"""Whether `who` has a row."""
	return who >= 0 and who < xp.size()


func level_of(who: int) -> int:
	"""A resident's FISH level 0..10 (0 for no such resident)."""
	return ForestRules.level_of(xp[who]) if is_resident(who) else 0


func can_helm(who: int) -> bool:
	"""Whether `who` may take a boat's helm (FISH >= HELM_MIN_LEVEL)."""
	return level_of(who) >= Rules.HELM_MIN_LEVEL


func add_work(who: int, mwu: int) -> void:
	"""Credit `mwu` milli-WU of productive fishing work: 10 XP per whole WU, the part-WU carried."""
	if not is_resident(who) or mwu <= 0:
		return
	_mwu_carry[who] += mwu
	var whole: int = _mwu_carry[who] / Rules.MILLI_PER_U
	_mwu_carry[who] -= whole * Rules.MILLI_PER_U
	if whole > 0:
		xp[who] += whole * Rules.XP_PER_WU
		revision += 1


static func group_level(levels: PackedInt32Array) -> int:
	"""§5.4: "Group boat skill is floor(mean crew FISH levels)" (0 for no crew)."""
	if levels.is_empty():
		return 0
	var total: int = 0
	for level: int in levels:
		total += level
	return total / levels.size()


func line_of(who: int) -> String:
	"""The party panel's skill line: "Fishing 4 (otter: rows and nets)" style, kept short."""
	if not is_resident(who):
		return ""
	var level: int = level_of(who)
	return "Fishing %d%s" % [level, " · can take a boat's helm" if level >= Rules.HELM_MIN_LEVEL else " · learning"]
