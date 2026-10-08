extends "res://tools/balance/light_touch_policy.gd"
## THE "PROVISIONING" SCRIPTED PLAYER of the balance harness (decision 1731): the light-touch player's every round,
## unchanged, plus a STORES ROUND each morning -- the preserving and brewing that no routine does on its own (decisions
## 1611 P3 and 1621 P6: "ordered by the player" from the Water panel). It orders through the same verbs the panel's
## buttons call, with NOBODY selected, so every batch goes on the work board for the crews. It never moves a resident,
## never touches a stock and never orders anything the panel would refuse.
##
## THE STORES ROUND (06:00, after the light-touch rounds):
##   nuts     one forager sent when a batch waits on nuts alone, no foraging trip is out and the woods allow it
##            (forage_trips.gd `trip_refusal`) -- nuts come only from a trip. A batch waits on nuts alone when its nuts
##            are short and every other input is free (no planned meal holds it): the nut cheese (decision 1625), or any
##            row like it; and rations once their dried fish is free (their flour is ground after the nuts, below);
##   flour    rations' inputs are gathered in their chain's order, each only once every input before it is free, so
##            nothing is taken for a batch that cannot be made: dried fish from the rack's own row (below), then the nuts
##            (above), then one mill batch when the free flour is short and the mill takes it (`mill_refusal`). The mill
##            grinds grain the kitchen would cook, so it waits until a batch of rations is otherwise possible;
##   recipes  every row of the stations' recipe table (preserve_rules.gd, in its own order: dried fish, dried fruit,
##            rations, mead, cordial, and whatever rows are appended after them) gets a batch ordered when the fishery
##            would take it (`batch_refusal` is empty) and no batch of that row is waiting to be worked. A passive batch
##            curing in its slot or vat has closed its job, so several of one row may be curing at once; the slots
##            bound them. A row not ordered is counted under "Not ordered: <verb> (<the fishery's refusal code>)".
## The refusals are the game's: a batch takes only food no planned meal holds (the kitchen reserves its next two days'
## meals first), needs its water in the butt, room for its output and a free rack slot or vat. So this player
## preserves the surplus a meal would not use; it does not take what the village would cook.
## Orders are counted by verb, as the light-touch player's are.

const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const ForageRules := preload("res://demo/forage/forage_rules.gd")
const TripsScript := preload("res://demo/forage/forage_trips.gd")

## The nuts' row among a foraging trip's kinds (forage_rules.gd KIND_WORDS).
const NUTS_KIND: int = 0

var _trips: TripsScript = null


func bind_forage(trips: TripsScript) -> void:
	"""The woods' foraging trips this player sends for nuts (null: that part is skipped)."""
	_trips = trips


func on_hour(hour_of_day: int) -> void:
	"""The light-touch rounds, then the stores round at 06:00."""
	super(hour_of_day)
	if hour_of_day == MORNING_HOUR:
		_stores_round()


func _stores_round() -> void:
	"""Rations' inputs in their chain's order, then a batch of every recipe the stations would take (see THE STORES
	ROUND)."""
	if _fishery == null:
		return
	_gather_nuts()
	if ration_input_free(Catalog.CAT_DRIED_FISH) and ration_input_free(Catalog.CAT_NUTS) \
			and not ration_input_free(Catalog.CAT_FLOUR) and _fishery.mill_refusal().is_empty():
		_count("Grind flour", _fishery.order_mill(_nobody))
	for recipe: int in Recipes.RECIPE_COUNT:
		if open_batches(recipe) > 0:
			continue
		if _fishery.batch_refusal(recipe).is_empty():
			_count(Recipes.VERB[recipe], _fishery.order_batch(recipe, _nobody))
		else:
			_count("Not ordered: %s (%s)" % [Recipes.VERB[recipe], _fishery.refused_code], "")


func _gather_nuts() -> void:
	"""One forager for nuts while a batch waits on nuts alone, no trip is out and the woods allow it."""
	if _trips == null or _trips.trip_count() > 0 or not wants_nuts():
		return
	if _trips.trip_refusal(NUTS_KIND, ForageRules.PARTY_MIN).is_empty():
		_count("Forage (nuts)", _trips.order_trip(NUTS_KIND, ForageRules.PARTY_MIN, _nobody))


func wants_nuts() -> bool:
	"""Whether a batch waits on nuts alone: rations once their dried fish is free (their flour waits on the nuts), or any
	row whose nuts are short and every other input free (see THE STORES ROUND)."""
	if ration_input_free(Catalog.CAT_DRIED_FISH) and not ration_input_free(Catalog.CAT_NUTS):
		return true
	for recipe: int in Recipes.RECIPE_COUNT:
		if waits_only_on(recipe, Catalog.CAT_NUTS):
			return true
	return false


func waits_only_on(recipe: int, category: int) -> bool:
	"""Whether `recipe`'s inputs of `category` are short while every other input is free (false when it takes none)."""
	var short: bool = false
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		var free: bool = _fishery.takes.free_milli_of_crop(_fishery.pantry, Recipes.IN_CATEGORY[input]) \
				>= Recipes.IN_MILLI[input]
		if Recipes.IN_CATEGORY[input] == category:
			short = short or not free
		elif not free:
			return false
	return short


func ration_input_free(category: int) -> bool:
	"""Whether the pantry holds, free of every reservation, what a batch of rations takes of `category` (true for a
	category rations do not take)."""
	for k: int in Recipes.IN_COUNT[Recipes.R_RATION]:
		var input: int = Recipes.IN_FIRST[Recipes.R_RATION] + k
		if Recipes.IN_CATEGORY[input] == category:
			return _fishery.takes.free_milli_of_crop(_fishery.pantry, category) >= Recipes.IN_MILLI[input]
	return true


func open_batches(recipe: int) -> int:
	"""The fishery's live jobs that will hang or make a batch of `recipe` (KIND_DRY, KIND_BATCH): a passive batch
	curing in its slot has closed its job, and a take-down is not a new batch -- neither is counted. 0 with no fishery."""
	if _fishery == null:
		return 0
	var n: int = 0
	for j: int in Tables.MAX_JOBS:
		if _fishery.tables.j_live[j] == 1 and _fishery.tables.j_recipe[j] == recipe \
				and (_fishery.tables.j_kind[j] == Tables.KIND_DRY or _fishery.tables.j_kind[j] == Tables.KIND_BATCH):
			n += 1
	return n
