extends RefCounted
## Who works where in the demo village: a small job routine per resident. Decision 0196. Demo data,
## not the simulation's job system (which assigns work by priorities and is not what the demo shows).
##
## Each creature has two or three HOME POIs that suit its trade, and now and then (SOCIAL_CHANCE) it
## goes to one of the village's SOCIAL spots instead. Within either list the next POI is drawn with
## weight 1 / (1 + distance / NEAR_M), so nearer spots come up more often and residents are not
## forever crossing the whole village. A creature with no row here (a placeholder, a new cast
## member) draws from every POI with the same distance weighting. POI names this world does not
## have are simply skipped.

## Homes are grouped by trade AND by neighbourhood, so a working day stays in one part of the
## village: the north-east yard (workbench, log stack, store front), the south-east stores (stockpile,
## cauldron, hall steps) and the west fields and hall (crops, well, hall table).
const HOMES: Dictionary = {
	&"mouse_keeper": [&"hall_table", &"well_drink", &"hall_steps"],
	&"mouse_fieldworker": [&"crops_cabbage", &"crops_grain", &"square_west"],
	&"squirrel_gatherer": [&"store_front", &"workbench", &"cauldron"],
	&"squirrel_forester": [&"log_stack", &"workbench", &"store_front"],
	&"otter_boatwright": [&"stockpile", &"cauldron", &"hall_steps"],
	&"otter_fisher": [&"well_drink", &"square_east", &"cauldron"],
	&"mole_digger": [&"crops_cabbage", &"crops_grain"],
	&"badger_quarryman": [&"stockpile", &"hall_steps", &"cauldron"],
	# The beaver bridgewright (DEC-041), staged once its grounded clips exist: a timber-and-water trade
	# with no special gameplay yet -- the weir, the boat landing and the log stack.
	&"beaver_bridgewright": [&"weir_work", &"boat_landing", &"log_stack"],
}
const SOCIAL: Array[StringName] = [&"square_west", &"square_east", &"hall_steps", &"well_drink"]
const SOCIAL_CHANCE: float = 0.2
const NEAR_M: float = 8.0


static func indices(names: Array, poi_names: Array[StringName]) -> PackedInt32Array:
	"""The POI indices of these names, skipping any this world does not have."""
	var out := PackedInt32Array()
	for name in names:
		var poi := poi_names.find(StringName(name))
		if poi >= 0:
			out.append(poi)
	return out


static func homes_for(key: StringName, poi_names: Array[StringName]) -> PackedInt32Array:
	"""A creature's home POIs in this world (empty when it has no routine)."""
	return indices(HOMES.get(key, []), poi_names)


static func socials_for(poi_names: Array[StringName]) -> PackedInt32Array:
	"""The village's social POIs in this world."""
	return indices(SOCIAL, poi_names)


static func weight(distance: float) -> float:
	"""How strongly a POI this far away is preferred."""
	return 1.0 / (1.0 + distance / NEAR_M)
