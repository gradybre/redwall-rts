extends RefCounted
## The orchard's words (decision 0671): every refusal, outcome, doing line and readout the jobs, the panel and the
## village news say, in one place. Presentation only.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")

const KIND_NAMES: Array[String] = ["Tend", "Harvest", "Pick berries", "Haul baskets", "Plant", "Propagate", "Observe",
	"Tend the bees", "Feed the bees", "Recolonise the hive"]
const OTHER_JOB: String = "has another orchard job"
const CANT_REACH: String = "can't reach it — %s"
const NO_ROOM_HEAD: String = "no room"
const NO_BERRIES: String = "the hedge has no berries to pick now (none in spring or winter, and §5.5 keeps a fifth)"
const NOTHING_TO_HAUL: String = "the baskets hold nothing to send on"
const NOTHING_TO_PICK: String = "there is nothing to pick"
const HOLDS_FULL: String = "the pantry's reservations are all in use — it waits for a harvest or a haul to finish"
const DROUGHT_DRY: String = "%s went untended in the drought: the butt ran dry"
const BEARS_NOTHING: String = "it bears nothing this year (its health is spent: tend it next spring)"
const NO_COMPOST: String = "no compost to hand (%s needed)"
const NO_FRUIT: String = "the pantry holds under %s of %s"
const NO_WATER: String = "the butt holds under %s of water"
const PLAN_GONE: String = "the plan is no longer waiting"
const THE_STAND: String = "the baskets"
const BOARD_FULL: String = "the orchard's job board is full"
const GONE: String = "that task is no longer on the board"
const CARRYING: String = "%s is carrying the load — it finishes the delivery first"
const DELIVERY_GOES_ON: String = "a delivery always finishes: its fruit is already picked"
const DEST_WORDS: Array[String] = ["the kitchen pantry", "any store"]
## ECO-015's seasonal sightings: insects and the trees' own year (mammals and birds are never targets or pest icons).
const SIGHTINGS: Array[String] = [
	"bees working the catkins; the first beetles in the leaf litter",
	"butterflies in the clearing; hoverflies over the bracken",
	"wasps at the windfalls; spiders' webs on every bough",
	"the hollow asleep; moss greening on the north sides of the trunks",
]


static func cap(words: String) -> String:
	"""`words` with its first letter a capital (only the first: "The old apple", not "The Old Apple")."""
	return words if words.is_empty() else words.substr(0, 1).to_upper() + words.substr(1)


static func a_species(species: int) -> String:
	"""A species with its article: "an apple", "a pear"."""
	return ("an %s" if species == Rules.APPLE else "a %s") % Rules.SPECIES_NAMES[species]


static func units(milli: int) -> String:
	"""A quantity in the Pantry's one form ("5.1 U")."""
	return FarmText.units_text(milli)


static func day_text(day: int) -> String:
	"""Absolute day `day` as the calendar prints it: "Y2 Autumn 3"."""
	if day < Hive.MIN_CALENDAR_DAY:
		return "—"
	return "Y%d %s %d" % [Hive.year_of_day(day), CalendarScript.SEASON_TITLES[Hive.season_of_day(day)],
		Hive.season_day_of_day(day)]


static func tree_name(model: ModelScript, site: int) -> String:
	"""A tree in words: "the old apple", "the young pear at east site 1", "east site 2" (no tree)."""
	var species: int = model.species_of(site)
	if species < 0:
		return Rules.SITE_NAMES[site]
	if model.inherited[site] == 1:
		return "the old %s" % Rules.SPECIES_NAMES[species]
	return "the %s at %s" % [Rules.SPECIES_NAMES[species], Rules.SITE_NAMES[site]]


static func tend_refusal(model: ModelScript, site: int, season: int, drought: bool, stores: RefCounted) -> String:
	"""Why a tree needs no tending now ("" when it does): §5.6's care is in spring and summer, once a day."""
	if not model.has_tree(site):
		return "no tree stands there"
	if not Hive.is_growing_season(season):
		return "no care needed in autumn or winter (§5.6: spring and summer)"
	if model.tended_today(site):
		return "it has been tended today"
	if drought and stores != null and int(stores.get(&"water_milli_u")) < Hive.CARE_DROUGHT_WATER_MILLI:
		return "a drought: tending needs %s of water from the butt" % units(Hive.CARE_DROUGHT_WATER_MILLI)
	return ""


static func harvest_words(code: String) -> String:
	"""A harvest refusal code in words ("" stays "")."""
	match code:
		"":
			return ""
		String(Hive.REFUSE_OUTSIDE_HARVEST_WINDOW):
			return "it is not its picking time (apples Autumn 1–6, pears Autumn 3–8)"
		String(Hive.REFUSE_NOT_MATURE):
			return "it is too young to bear (fruit from its first full year)"
		String(Hive.REFUSE_ALREADY_HARVESTED_THIS_YEAR):
			return "it has been picked this year"
	return "no tree stands there"


static func plant_words(code: String) -> String:
	"""A planting refusal code in words ("" stays "")."""
	match code:
		"":
			return ""
		"SITE_TAKEN":
			return "a tree already stands there"
		"SITE_PLANNED":
			return "the nursery has promised this site another sapling"
		"NO_SAPLING":
			return "the nursery has no sapling of that kind (propagate one)"
	return "the block cannot be planted (%s)" % code.to_lower().replace("_", " ")


static func no_room(milli: int, item: int, where: String) -> String:
	"""A full store, as the farm says it: "no room for 5.1 U of apple at ... — make room in the Pantry (K)"."""
	return "%s for %s of %s at %s — make room in the Pantry (K)" % [NO_ROOM_HEAD, units(milli),
		Catalog.ITEM_LABELS[item].to_lower(), where]


static func short_haul(milli: int, item: int) -> String:
	"""A haul that could not set all its basket down (the store had shrunk, its lot had gone): the rest stays put."""
	return "%s of %s stayed at the baskets: the store could not take it all" % [units(milli),
		Catalog.ITEM_LABELS[item].to_lower()]


static func cannot(jobs: RefCounted, j: int, why: String) -> String:
	"""A player's order that could not go ahead: "Can't plant at east site 1: ..."."""
	return "Can't %s %s: %s" % [KIND_NAMES[int(jobs.get(&"kind")[j])].to_lower(), target_words(jobs, j), why]


static func gave_up(jobs: RefCounted, j: int) -> String:
	"""A job nobody could reach."""
	return "Nobody could reach %s to %s: given up" % [target_words(jobs, j),
		KIND_NAMES[int(jobs.get(&"kind")[j])].to_lower()]


static func target_words(jobs: RefCounted, j: int) -> String:
	"""What a job is on, for the Work screen: "the old apple", "the raspberry canes", "the old orchard's baskets"."""
	var model: ModelScript = jobs.get(&"model")
	var t: int = int(jobs.get(&"target")[j])
	match int(jobs.get(&"kind")[j]):
		Rules.K_TEND, Rules.K_HARVEST, Rules.K_PLANT:
			return tree_name(model, t)
		Rules.K_PICK:
			return "the %s" % BUSH_WORDS[t]
		Rules.K_HAUL:
			return "%s's baskets" % Rules.GROUP_NAMES[t].to_lower()
		Rules.K_PROPAGATE:
			return "%s sapling for %s" % [a_species(model.plan_species[t]), Rules.SITE_NAMES[model.plan_site[t]]]
		Rules.K_SERVICE, Rules.K_FEED, Rules.K_RECOLONIZE:
			return HiveRules.APIARY_NAMES[t]
	return Rules.GROVE_NAME


const BUSH_WORDS: Array[String] = ["raspberry canes", "blackberry bramble", "strawberry bed"]
## What each bush bears (all of it stored as the pantry's one `berries` item, decision 0676).
const BUSH_FRUIT: Array[String] = ["raspberries", "blackberries", "strawberries"]


static func doing(jobs: RefCounted, j: int) -> String:
	"""What a worker is doing, for the party panel: "Picking the old apple", "Carrying 12.0 U of apple to the baskets"."""
	var carried: int = int(jobs.get(&"load_milli")[j])
	var item: int = int(jobs.get(&"load_item")[j])
	if carried > 0 and item >= 0:
		return "Carrying %s of %s to %s" % [units(carried), Catalog.ITEM_LABELS[item].to_lower(),
			"the store" if int(jobs.get(&"kind")[j]) == Rules.K_HAUL else THE_STAND]
	return "%s — %s" % [KIND_NAMES[int(jobs.get(&"kind")[j])], target_words(jobs, j)]


static func picked(model: ModelScript, site: int, milli: int) -> String:
	"""A tree picked: "The old apple was picked: 31.2 U of apple"."""
	var item: int = Catalog.item_of_orchard_species(model.species_of(site))
	if milli <= 0:
		return "%s bore nothing this year" % cap(tree_name(model, site))
	return "%s was picked: %s of %s" % [cap(tree_name(model, site)), units(milli),
		Catalog.ITEM_LABELS[item].to_lower()]


static func planted(model: ModelScript, site: int, day: int) -> String:
	"""A planting, with REQ-SET-081's first harvest days (decision 0672's early one first)."""
	var species: int = model.species_of(site)
	var early: int = model.first_early_day(species, day)
	var full: int = model.store.first_eligible_harvest_day(species, day).value
	return "%s was planted at %s: first fruit %s, full crops from %s" % [cap(a_species(species)),
		Rules.SITE_NAMES[site], day_text(early) if early > 0 else day_text(full), day_text(full)]


static func propagated(model: ModelScript, plan: int) -> String:
	"""A propagation: its sapling and when it is ready."""
	return "The nursery set %s sapling for %s: ready %s" % [a_species(model.plan_species[plan]),
		Rules.SITE_NAMES[model.plan_site[plan]], day_text(model.plan_ready_day[plan])]


static func observation(season: int, standing: int, protected: bool) -> String:
	"""What the grove's observer saw (ECO-015): the season's sighting and the trees standing (the news stamps its date;
	the record adds it: `dated`)."""
	return "%s: %s; %d trees standing%s" % [cap(Rules.GROVE_NAME), SIGHTINGS[posmod(season, 4)], standing,
		"" if protected else " (not protected)"]


static func dated(calendar: CalendarScript, line: String) -> String:
	"""A record line with the calendar's date before it ("Y1 Autumn 4, 09:00 · ...")."""
	return "%s · %s" % [calendar.date_text(), line] if calendar != null else line


static func plan_line(model: ModelScript, plan: int) -> String:
	"""A nursery plan's row (ECO-009): its sapling, its site, its state, and its first producing season if planted
	when ready (a waiting plan: if propagated today)."""
	var species: int = model.plan_species[plan]
	var state: int = model.plan_state[plan]
	var head: String = "%s for %s — %s" % [cap(Rules.SPECIES_NAMES[species]), Rules.SITE_NAMES[model.plan_site[plan]],
		ModelScript.PLAN_STATE_NAMES[state]]
	var ready: int = model.plan_ready_day[plan]
	if state == ModelScript.PLAN_GROWING:
		head += " (ready %s)" % day_text(ready)
	var from: int = ready if state != ModelScript.PLAN_WAITING else model.today_hint + Hive.NURSERY_WAIT_DAYS
	from = maxi(from, model.today_hint)
	var early: int = model.first_early_day(species, from)
	return head + " · first fruit %s" % day_text(early if early > 0 else model.store.first_eligible_harvest_day(species,
		from).value)


static func fruit_words(species: int) -> String:
	"""A species' fruit and yield, from §5.6's table: "apple: 80 U a year from 96 days, Autumn 1–6"."""
	@warning_ignore("integer_division") var yield_u: int = Hive.SPECIES_YIELD_MILLI[species] / 1000
	return "%s: %d U a year once mature (%d days), Autumn %d–%d" % [Rules.SPECIES_NAMES[species], yield_u,
		Hive.SPECIES_MATURITY_DAYS[species],
		Hive.SPECIES_HARVEST_FIRST_DAY[species], Hive.SPECIES_HARVEST_LAST_DAY[species]]


static func guide_fields(item: int, made_into: String = "") -> Array:
	"""The field guide's entry for an orchard item (demo/guide/field_guide.gd's goods): [summary, fields]; `made_into`
	is what the stations make of it (preserve_text.gd made_into_text), said instead of "no demo dish cooks it yet"."""
	var shelf: int = Catalog.shelf_hours_of(item)
	if Catalog.category_of(item) == Catalog.CAT_FRUIT:
		var species: int = Catalog.ORCHARD_SPECIES_ITEM.find(item)
		return ["Picked from the orchard's trees", PackedStringArray([
			"Fruit (§5.7): eaten raw by a hungry resident when a meal is missed (900 NP a unit). %s" % (made_into
				if not made_into.is_empty() else "No demo dish cooks it yet."),
			cap(fruit_words(species)) + "; a young tree gives a fifth of that from its first full year.",
			"The nursery turns 4 U into a sapling (with compost 2 and water 2).",
			"Keeps %d game hours in store; the Pantry (K) lists it." % shelf])]
	return ["Picked from the berry hedge", PackedStringArray([
		"Berries (§5.7): raspberries, blackberries and strawberries alike; eaten raw by a hungry resident when a meal is " \
			+ "missed (700 NP a unit); kept for the cordials, tarts and preserves still to come.",
		"The hedge fruits in summer and less in autumn (§5.5); none in spring or winter.",
		"Picked by the basket at 4 WU a unit, never below a fifth of the hedge.",
		"Keeps %d game hours in store; the Pantry (K) lists it." % shelf])]
