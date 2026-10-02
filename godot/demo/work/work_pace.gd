extends RefCounted
## THE WORK PACE: how fast each resident's productive work goes, as a product of FACTORS other owners supply.
## Decision 0622 (herbalist and infirmary). Presentation only; integer per mille throughout.
##
## WHY ONE REGISTRY. Several owners slow a resident's work for their own reasons -- an injury's health factor (GDD §5.2:
## 600 below 40 health, 850 below 70; demo/infirmary/), a winter chill -- and the GDD composes such factors by
## multiplying them (§5.2: "total work factor = clamp(floor(skill x mood x health / 1000000), 300, 1800)"). So each owner
## ADDS a factor here, `(who: int) -> int` per mille, and every reader asks `permille(who)` for their product. No owner
## knows of another, and adding one changes no other: factors are applied in the order added, each as
## `pace = pace x factor / 1000` (floored), so with every factor 1000 the pace is exactly 1000.
##
## READERS. A work owner that credits a resident's work multiplies by `permille(who)` (or calls `scale(who, amount)`).
## The infirmary's HEAL work reads it (care_rules.gd `care_factor`); the other job owners can read it the same way.
## The demo has no mood, so no mood factor is added.

const PERMILLE: int = 1000

var _names: PackedStringArray = PackedStringArray()
var _factors: Array[Callable] = []


func add_factor(factor_name: String, factor: Callable) -> bool:
	"""Add one owner's factor, `factor(who: int) -> int` per mille, under a name its reader can show. Refuses (false)
	an invalid callable or a name already added."""
	if not factor.is_valid() or factor_name.is_empty() or _names.has(factor_name):
		return false
	_names.append(factor_name)
	_factors.append(factor)
	return true


func count() -> int:
	"""How many factors are added."""
	return _factors.size()


func name_of(k: int) -> String:
	"""Factor `k`'s name ("" out of range)."""
	return _names[k] if k >= 0 and k < _names.size() else ""


func factor_of(k: int, who: int) -> int:
	"""Factor `k` for resident `who`, per mille, never below 0 (PERMILLE out of range)."""
	if k < 0 or k >= _factors.size():
		return PERMILLE
	return maxi(int(_factors[k].call(who)), 0)


func permille(who: int) -> int:
	"""The product of every factor for resident `who`, per mille (PERMILLE with none)."""
	var pace: int = PERMILLE
	for k: int in _factors.size():
		@warning_ignore("integer_division")
		pace = pace * factor_of(k, who) / PERMILLE
	return pace


func scale(who: int, amount: int) -> int:
	"""`amount` of work (any unit) at resident `who`'s pace, floored."""
	@warning_ignore("integer_division")
	return amount * permille(who) / PERMILLE


func slowed_text(who: int) -> String:
	"""The factors below 1000 for `who`, in words: "work at 85% (health 85%)" ("" when none slows it)."""
	var parts := PackedStringArray()
	for k: int in _factors.size():
		var f: int = factor_of(k, who)
		if f != PERMILLE:
			@warning_ignore("integer_division")
			parts.append("%s %d%%" % [_names[k], f / 10])
	if parts.is_empty():
		return ""
	@warning_ignore("integer_division")
	return "work at %d%% (%s)" % [permille(who) / 10, ", ".join(parts)]
