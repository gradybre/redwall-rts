extends RefCounted
## The fishery's words: refusals, previews, lines for the Water panel, the cards and the feed. Decision 0431 (live
## demo). Pure functions of the fishery's state; one formatter for quantities (farm_text.gd `units_text`), one for game
## time (action_card.gd `hours_text`), so a figure reads the same everywhere.

const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]

## fishing_driver.gd / fishing.gd refusal codes, in the player's words.
const DRIVER_WORDS: Dictionary = {
	&"SPECIES_CLOSED": "%s is closed to fishing (a spawning closure)",
	&"SPECIES_UNAVAILABLE": "%s is not running this season",
	&"RESTOCKING": "%s is restocking: below 30%% of the water's stock until it is back over 40%%",
	&"BELOW_STOCK_FLOOR": "%s is at the conservation floor",
	&"QUOTA_REACHED": "today's quota for this water is taken (%s)",
	&"EFFORT_SLOTS_FULL": "every fishing place on this water is taken (%s)",
	&"GEAR_CANNOT_TAKE_SPECIES": "a trap takes only dace, perch and carp (%s)",
	&"GEAR_NOT_AT_SITE": "that method is not used there (%s)",
	&"ICE_COVERS_THE_LAKE": "ice covers the pond: only ice fishing (%s)",
	&"LAKE_NOT_FROZEN": "the pond is not frozen: ice fishing waits for winter ice (%s)",
}


static func units(milli: int) -> String:
	"""A quantity as the panels print it ('9.6 U', '<0.1 U', '0 U')."""
	return FarmText.units_text(milli)


static func species_label(key: StringName) -> String:
	"""A species key as a word ('trout')."""
	return String(key).replace("_", " ")


static func driver_words(code: StringName, species: StringName) -> String:
	"""A driver refusal in words, naming the species or the place it is about."""
	if not DRIVER_WORDS.has(code):
		return "can't fish now (%s)" % String(code)
	var words: String = DRIVER_WORDS[code]
	var name: String = species_label(species)
	return words % (name.capitalize() if words.begins_with("%s") else name)


static func date_text(season: int, day: int) -> String:
	"""'spring 8'."""
	return "%s %d" % [SEASON_NAMES[clampi(season, 0, 3)], day]


static func risk_text(per_10000: int) -> String:
	"""§5.4's injury chance, numerically (REQ-SET-055): '12 in 10000 (0.12%) a cycle'."""
	return "%d in 10000 (%d.%02d%%) a cycle" % [per_10000, per_10000 / 100, per_10000 % 100]


static func stock_line(p: Driver.Preview) -> String:
	"""REQ-SET-055's stock and quota: 'Perch: 720.0 / 900.0 U (80%) · quota left 25.5 / 52.5 U today'."""
	var percent: int = p.stock_milli * 100 / maxi(p.capacity_milli, 1)
	var state: String = " · restocking" if p.restocking else ""
	return "%s: %s / %s (%d%%)%s · quota left %s / %s today" % [species_label(p.species_key).capitalize(),
		units(p.stock_milli), units(p.capacity_milli), percent, state, units(p.remaining_quota_milli),
		units(p.quota_milli)]


static func closure_line(p: Driver.Preview) -> String:
	"""REQ-SET-055's closure dates: '' while open, else 'Closed: reopens summer 1'."""
	if not p.closed and p.availability_per_1000 > 0:
		return ""
	return "Closed now: reopens %s" % date_text(p.reopen_season, p.reopen_day)


static func gear_line(kind_name: String, durability: int, cycles: int) -> String:
	"""REQ-SET-055's gear condition: 'Gear: hand net 940/1000 (47 cycles left)'."""
	return "Gear: %s %d/1000 (%d cycles left)" % [kind_name, durability, cycles]


static func method_title(method: int, site: int, species: StringName) -> String:
	"""A trip's card title: 'Fish the pond by boat for perch'."""
	match method:
		Rules.METHOD_NET:
			return "Net %s at %s" % [species_label(species), Rules.SITE_NAMES[site]]
		Rules.METHOD_TRAP:
			return "Trap %s at %s" % [species_label(species), Rules.SITE_NAMES[site]]
		Rules.METHOD_BOAT:
			return "Fish %s by boat for %s" % [Rules.SITE_NAMES[site], species_label(species)]
	return "Ice-fish %s for %s" % [Rules.SITE_NAMES[site], species_label(species)]


static func catch_text(milli: int, item: int) -> String:
	"""'9.6 U of perch'."""
	return "%s of %s" % [units(milli), Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_pantry_item(item) else "fish"]
