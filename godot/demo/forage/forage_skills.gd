extends RefCounted
## Every resident's FORAGE skill (GDD §5.3's FORAGE job kind). Decision 0681 (foraging trips). Presentation only.
##
## LORE-P12: no species lock and no hidden bonus -- anybeast forages and gets better at it by foraging. XP is §5.3's 10 a
## completed productive WU, the level residents.gd's own curve (forest_rules.gd `level_of`). Nobody starts skilled: the
## demo seeds no FORAGE level (no document names a forager's trade). The level enters §5.5's work per U --
## (1000 + 40 x FORAGE) in its denominator -- and REQ-SET-068's injury chance, never a work speed.

const Rules := preload("res://demo/forage/forage_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

## XP per resident.
var xp: PackedInt64Array = PackedInt64Array()
## Milli-WU done but not yet a whole WU, per resident (XP is awarded on whole WU).
var _mwu_carry: PackedInt64Array = PackedInt64Array()
var revision: int = 0


func setup(residents: int) -> void:
	"""One row per resident, every one at 0."""
	xp.resize(residents)
	xp.fill(0)
	_mwu_carry.resize(residents)
	_mwu_carry.fill(0)
	revision += 1


func is_resident(who: int) -> bool:
	"""Whether `who` has a row."""
	return who >= 0 and who < xp.size()


func level_of(who: int) -> int:
	"""A resident's FORAGE level 0..10 (0 for no such resident)."""
	return ForestRules.level_of(xp[who]) if is_resident(who) else 0


func add_work(who: int, mwu: int) -> void:
	"""Credit `mwu` milli-WU of productive foraging: 10 XP per whole WU, the part-WU carried."""
	if not is_resident(who) or mwu <= 0:
		return
	_mwu_carry[who] += mwu
	@warning_ignore("integer_division") var whole: int = _mwu_carry[who] / Rules.MILLI_PER_U
	_mwu_carry[who] -= whole * Rules.MILLI_PER_U
	if whole > 0:
		xp[who] += whole * Rules.XP_PER_WU
		revision += 1


func line_of(who: int) -> String:
	"""The party panel's skill line: 'Foraging 1'."""
	return "Foraging %d" % level_of(who) if is_resident(who) else ""
