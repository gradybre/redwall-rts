extends RefCounted
## THE "LIGHT-TOUCH" SCRIPTED PLAYER of the balance harness (decision 0911). Each morning at 06:00 it queues the work a
## sensible player would, through the same verbs the panels call with NOBODY selected -- so every order goes on the
## work board for the crews, exactly as the player's Farm, Woods and Water panels queue it. It never moves a resident,
## never time-skips, and never touches a stock.
##
## THE MORNING (06:00):
##   farm   every RIPE bed harvested; every WATERLOGGED bed drained; every DRY or LOW growing bed watered; every EMPTY
##          bed sown with the first crop of its preference list that its soil and today's planting window allow
##          (even beds roots first, odd beds grain first: the kitchen's soup and porridge), when one is;
##   woods  planks sawn when fewer than PLANKS_LOW are in store and the wood allows; the North stand's auto-fell
##          switched on below WOOD_LOW and off again above WOOD_HIGH; one deadfall pile gathered while below WOOD_LOW;
##   water  one fishing trip authorised when none is open and the pantry holds under FISH_STOCK_HIGH of fresh fish (more
##          would only spoil: fresh fish keeps 48 h): the first of hand net, trap, then ice that the water, the
##          weather, the gear and the crew allow, at the first site and species that do.
## THE AFTERNOON (13:00): a bed with a living crop that a frost is due on (announced from noon the day before) is
## covered --
## the player reading the farm's frost warning.
## Every order is skipped when the same job is already on the board. Orders are counted by verb for the day's record.

const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FishRules := preload("res://demo/fishery/fishery_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MORNING_HOUR: int = 6
const AFTERNOON_HOUR: int = 13
const PLANKS_LOW: int = 4000
const WOOD_LOW: int = 30000
const WOOD_HIGH: int = 60000
## Planks are sawn from 2 U of logs (forest_rules.gd); keep a margin for the kitchen's fire.
const WOOD_FOR_SAWING: int = 10000
## No new fishing trip while this much fresh fish is in store.
const FISH_STOCK_HIGH: int = 4000
const ROOTS_FIRST: Array[StringName] = [&"carrot", &"turnip", &"radish", &"beetroot", &"parsnip", &"onion", &"wheat",
	&"barley", &"oats"]
const GRAIN_FIRST: Array[StringName] = [&"wheat", &"barley", &"oats", &"carrot", &"turnip", &"radish", &"beetroot",
	&"parsnip", &"onion"]
const FISHING_METHODS: Array[int] = [FishRules.METHOD_NET, FishRules.METHOD_TRAP, FishRules.METHOD_ICE]
const SITES: int = 3
const SPECIES_PER_SITE: int = 3

var _farm: DemoFarmScript = null
var _forestry: ForestryScript = null
var _fishery: FisheryScript = null
var _stores: StoresScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _nobody: PackedInt32Array = PackedInt32Array()
var _orders: Dictionary = {}
## The fresh fish over which no trip is authorised: FISH_STOCK_HIGH unless the run's `--fish-high` says otherwise (the
## balance rerun's P6 measurement, decision 1738).
var fish_stock_high: int = FISH_STOCK_HIGH


func bind(farm: DemoFarmScript, forestry: ForestryScript, fishery: FisheryScript, stores: StoresScript) -> void:
	"""The panels' owners this player orders through (the forestry and fishery may be null: that part is skipped)."""
	_farm = farm
	_forestry = forestry
	_fishery = fishery
	_stores = stores


func on_hour(hour_of_day: int) -> void:
	"""The calendar reached `hour_of_day` (0-23): the morning's or the afternoon's round when it is theirs."""
	if hour_of_day == MORNING_HOUR:
		_farm_round()
		_woods_round()
		_water_round()
	elif hour_of_day == AFTERNOON_HOUR:
		_cover_round()


func take_orders() -> Dictionary:
	"""The orders given since the last call, by verb; then forgotten."""
	var out: Dictionary = _orders.duplicate()
	_orders.clear()
	return out


func _farm_round() -> void:
	"""Harvest, drain, water and sow each bed as THE MORNING says."""
	var sim: SimScript = _farm.sim
	for bed: int in Catalog.BED_COUNT:
		var stage: int = sim.stage_of(bed)
		if stage == SimScript.STAGE_RIPE:
			_farm_order(FarmJobs.KIND_HARVEST, bed)
		elif stage == SimScript.STAGE_EMPTY:
			_sow(bed)
		if sim.band_of(bed) == SimScript.BAND_WATERLOGGED:
			_farm_order(FarmJobs.KIND_DRAIN, bed)
		elif sim.band_of(bed) <= SimScript.BAND_LOW:
			_farm_order(FarmJobs.KIND_WATER, bed)


func _cover_round() -> void:
	"""Cover every bed with a crop a frost is due on (not raised above it)."""
	var sim: SimScript = _farm.sim
	if not FarmWeather.frost_due(sim.season(), sim.season_day(), AFTERNOON_HOUR):
		return
	for bed: int in Catalog.BED_COUNT:
		var stage: int = sim.stage_of(bed)
		if not sim.is_raised(bed) and stage != SimScript.STAGE_EMPTY and stage != SimScript.STAGE_WITHERED:
			_farm_order(FarmJobs.KIND_COVER, bed)


func _sow(bed: int) -> void:
	"""Choose the first crop of the bed's preference list that may be sown now, and order its sowing (a sowing already
	on the board keeps its crop)."""
	var sim: SimScript = _farm.sim
	if _farm.crew.jobs.job_on_bed_into(FarmJobs.KIND_SOW, bed, _read):
		return
	var prefer: Array[StringName] = ROOTS_FIRST if bed % 2 == 0 else GRAIN_FIRST
	for key: StringName in prefer:
		var item: int = Catalog.ITEM_KEYS.find(key)
		if item >= 0 and sim.sow_refusal(bed, item) == SimScript.REFUSE_NONE:
			if sim.choose(bed, item).ok:
				_farm_order(FarmJobs.KIND_SOW, bed)
			return


func _farm_order(kind: int, bed: int) -> void:
	"""Queue `kind` on `bed` for the crew unless it is on the board already or the bed refuses it."""
	if _farm.crew.jobs.job_on_bed_into(kind, bed, _read):
		return
	if FarmJobs.refusal_for(_farm.sim, kind, bed, _farm.crew.most_earth()) != &"":
		return
	_count(FarmJobs.KIND_NAMES[kind], _farm.crew.order(kind, bed, _nobody, FarmJobs.ORIGIN_PLAYER))


func _woods_round() -> void:
	"""Planks, the auto-fell switch and deadfall, as THE MORNING says."""
	if _forestry == null or not _forestry.disabled_reason.is_empty():
		return
	if _stores.plank_milli_u < PLANKS_LOW and _stores.wood_milli_u >= WOOD_FOR_SAWING \
			and _forestry.crew.jobs.on_target(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET) == 0:
		_count("Saw planks", _forestry.crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, _nobody,
			ForestJobs.ORIGIN_PLAYER))
	var zone: int = _forestry_zone()
	if zone >= 0 and _stores.wood_milli_u < WOOD_LOW and _forestry.zones.auto_fell[zone] == 0:
		_forestry.zones.set_auto(zone, true)
		_count("Auto-fell on", "")
	elif zone >= 0 and _stores.wood_milli_u > WOOD_HIGH and _forestry.zones.auto_fell[zone] == 1:
		_forestry.zones.set_auto(zone, false)
		_count("Auto-fell off", "")
	if _stores.wood_milli_u < WOOD_LOW:
		_gather_one()


func _forestry_zone() -> int:
	"""The first forestry zone (the North stand), or -1."""
	for z: int in ZonesScript.MAX_ZONES:
		if _forestry.zones.is_zone(z) and _forestry.zones.kind[z] == ZonesScript.KIND_FORESTRY:
			return z
	return -1


func _gather_one() -> void:
	"""Gather the first deadfall pile lying, unless a gathering is already on the board."""
	for pile: int in _forestry.deadfall.live.size():
		if _forestry.deadfall.live[pile] != 1:
			continue
		if _forestry.crew.jobs.on_target(ForestJobs.KIND_GATHER, pile) > 0:
			return
		_count("Gather deadfall", _forestry.crew.order(ForestJobs.KIND_GATHER, pile, _forestry.deadfall.generation[pile],
			_nobody, ForestJobs.ORIGIN_PLAYER))
		return


func _water_round() -> void:
	"""One fishing trip, when none is open (see THE MORNING)."""
	if _fishery == null or _open_trips() > 0 or _fresh_fish_milli() >= fish_stock_high:
		return
	for method: int in FISHING_METHODS:
		for site: int in SITES:
			for species: int in SPECIES_PER_SITE:
				if _fishery.trip_refusal(method, site, species, _nobody).is_empty():
					_count("Fish (%s)" % FishRules.METHOD_SHORT[method], _fishery.authorise(method, site, species, _nobody))
					return


func _fresh_fish_milli() -> int:
	"""Fresh fish in the pantry (every species), milli-U."""
	var milli: int = 0
	for item: int in range(Catalog.FIRST_CATCH, Catalog.FIRST_CATCH + Catalog.CATCH_COUNT):
		milli += _farm.pantry.milli_of(item)
	return milli


func _open_trips() -> int:
	"""Trips the fishery holds open."""
	var n: int = 0
	for t: int in _fishery.tables.t_live.size():
		n += _fishery.tables.t_live[t]
	return n


func _count(verb: String, said: String) -> void:
	"""Count an order by verb (one the verb refused -- "Can't ..." -- is counted under "refused")."""
	var key: String = "refused" if said.begins_with("Can't") else verb
	_orders[key] = int(_orders.get(key, 0)) + 1
