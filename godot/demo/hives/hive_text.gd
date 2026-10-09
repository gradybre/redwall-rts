extends RefCounted
## What the apiary says (decision 1601): the keeper's jobs' refusals, the apiary's readout -- its strength and season,
## REQ-SET-083's service and feed deficits before abandonment, the winter feed (ECO-012), and which crops it pollinates
## (ECO-011). Presentation only. Honey is in jars and halves, wax in cakes and pieces (goods_measures.gd, decision 1801).

const Rules := preload("res://demo/hives/hive_rules.gd")
const ApiaryScript := preload("res://demo/hives/apiary_model.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const ABANDONED: String = "the hive is abandoned: recolonise it in spring"
const WINTER_REST: String = "winter: the bees need no tending, only their feed (%s put by)"
const TENDED_TODAY: String = "the bees were tended today"
const FEED_FROM_OWN: String = "the hive puts by its winter feed of %s from its own honey first (%s put by so far)"
const FEED_LASTS: String = "its feed lasts the winter (%s put by)"
const NO_FREE_HONEY: String = "the stores hold no free honey (%s wanted)"
const NOT_ABANDONED: String = "the hive is alive: only an abandoned hive is recolonised"
const UNDER_WAY: String = "a swarm is already on its way"
const NOT_SPRING: String = "a swarm is taken in spring, with its 3-day wait ending in spring"
const NEEDS_HONEY: String = "it needs %s of free honey (the stores hold %s)"
const NEEDS_WOOD: String = "it needs %s (the stores hold %s)"
## The field guide's honey (field_guide.gd `_hive_goods`).
const GUIDE_SUMMARY: String = "From the apiary's skep"
const SEASON_WORDS: Array[String] = ["spring: the bees are building up", "summer: the bees are at their busiest",
	"autumn: the last flow before the winter", "winter: the cluster rests on its stores"]


static func recolonize_words(code: String) -> String:
	"""apiary_model.gd's recolonisation refusal in words ("" stays "")."""
	match code:
		ApiaryScript.REFUSE_NOT_ABANDONED:
			return NOT_ABANDONED
		ApiaryScript.REFUSE_UNDER_WAY:
			return UNDER_WAY
		ApiaryScript.REFUSE_NOT_SPRING:
			return NOT_SPRING
	return code


static func service_refusal(model: ApiaryScript, apiary: int, day: int) -> String:
	"""Why the keeper cannot tend apiary `apiary` on `day` ("" when the service is owed)."""
	if model.is_abandoned(apiary):
		return ABANDONED
	if Hive.season_of_day(day) == Hive.SEASON_WINTER:
		return WINTER_REST % Measures.amount(&"honey", model.feed(apiary))
	return "" if model.service_due(apiary, day) else TENDED_TODAY


static func feed_refusal(model: ApiaryScript, apiary: int, day: int, free_honey: int) -> String:
	"""Why nobody need carry honey to apiary `apiary` on `day` ("" when its winter feed falls short and the stores have
	free honey to make it up)."""
	if model.is_abandoned(apiary):
		return ABANDONED
	if Hive.season_of_day(day) != Hive.SEASON_WINTER:
		return FEED_FROM_OWN % [Measures.exact(&"honey", Rules.WINTER_FEED_MILLI),
			Measures.amount_cell(&"honey", model.feed(apiary))]
	var short: int = model.feed_shortfall_milli(apiary, day)
	if short <= 0:
		return FEED_LASTS % Measures.amount(&"honey", model.feed(apiary))
	return NO_FREE_HONEY % Measures.need(&"honey", short) if free_honey <= 0 else ""


static func recolonize_refusal(model: ApiaryScript, apiary: int, day: int, free_honey: int, wood: int) -> String:
	"""Why apiary `apiary` cannot be recolonised on `day` ("" when it can): §5.6's season and its honey 4 and wood 2."""
	var why: String = recolonize_words(model.recolonize_refusal(apiary, day))
	if not why.is_empty():
		return why
	if free_honey < Rules.RECOLONIZE_HONEY_MILLI:
		return NEEDS_HONEY % [Measures.need_cell(&"honey", Rules.RECOLONIZE_HONEY_MILLI),
			Measures.amount_cell(&"honey", free_honey)]
	if wood < Rules.RECOLONIZE_WOOD_MILLI:
		return NEEDS_WOOD % [Measures.need(&"wood", Rules.RECOLONIZE_WOOD_MILLI), Measures.amount_cell(&"wood", wood)]
	return ""


static func state_line(model: ApiaryScript, apiary: int, day: int) -> String:
	"""The hive at a glance: its strength, health and season."""
	@warning_ignore("integer_division") var percent: int = model.strength(apiary) / 100
	if model.is_abandoned(apiary):
		var swarm: int = model.recolonize_day[apiary]
		return "Abandoned · %s" % ("a swarm settles on day %d" % swarm if swarm > 0 else "recolonise it in spring")
	return "Strength %d%% · %s · %s" % [percent, "healthy: it pollinates" if model.is_healthy(apiary)
		else "weak: below 50%, it pollinates nothing", SEASON_WORDS[Hive.season_of_day(day)]]


static func deficit_line(model: ApiaryScript, apiary: int, day: int) -> String:
	"""REQ-SET-083: the service and feed deficits, shown before the hive is lost."""
	if model.is_abandoned(apiary):
		return "No deficits: the hive is empty."
	var parts := PackedStringArray()
	var unserved: int = model.service_deficit_days(apiary, day)
	if Hive.season_of_day(day) != Hive.SEASON_WINTER and unserved > 0:
		parts.append("not tended for %d day%s (each costs 2%% strength)" % [unserved, "" if unserved == 1 else "s"])
	var short: int = model.feed_shortfall_milli(apiary, day)
	if short > 0:
		parts.append("winter feed short by %s (each unfed day costs 5%%)" % Measures.need(&"honey", short))
	return "Deficits: none." if parts.is_empty() else "Deficits: " + "; ".join(parts) + "."


static func stock_line(model: ApiaryScript, apiary: int) -> String:
	"""What the hive holds and what it has given (ECO-012's winter feed first), each beside its name: 'In the hive: honey
	3 jars, wax ½ cake · winter feed 4 of 6 jars · wax on the shelf 2 cakes'."""
	return "In the hive: honey %s, wax %s · winter feed %s · wax on the shelf %s" % [
		Measures.amount_cell(&"honey", model.honey_in_hive(apiary)), Measures.amount_cell(&"wax", model.wax_in_hive(apiary)),
		Measures.have_need(&"honey", model.feed(apiary), Rules.WINTER_FEED_MILLI),
		Measures.amount_cell(&"wax", model.wax_shelf_milli)]


static func pollination_line(trees: PackedStringArray, beds: PackedStringArray, healthy: bool) -> String:
	"""ECO-011: which crops benefit -- the orchard trees and the field beds within 12 m (beans grown there)."""
	var reach: String = "Pollinates within 12 m (x1.10 yield): %s; beans in %s." % [
		"no orchard tree" if trees.is_empty() else ", ".join(trees), "no field bed" if beds.is_empty() else ", ".join(beds)]
	return reach if healthy else reach + " Not while it is weak."


static func guide_fields(dishes: String, raw_np: int, shelf_hours: int) -> PackedStringArray:
	"""The field guide's honey: what takes it, how the apiary makes it, its alternatives, how long it keeps. Its food value
	is per jar, honey's measure (a jar is one catalogue unit, so `raw_np` per U is per jar)."""
	return PackedStringArray([
		"%s Eaten raw by a hungry resident when a meal is missed (%d NP a jar)." % [dishes, raw_np],
		"The apiary's bees: up to %s a day from spring to autumn at full strength, for 20 WU of tending a day; a whole winter's feed (%s) is kept in the hive first, and the rest goes to the old orchard's baskets." % [
			Measures.exact(&"honey", Hive.HIVE_HONEY_MILLI_PER_DAY), Measures.exact(&"honey", Rules.WINTER_FEED_MILLI)],
		"Berries and fruit are the other sweet things; honey keeps far longer.",
		"Keeps %d game hours in store." % shelf_hours])
