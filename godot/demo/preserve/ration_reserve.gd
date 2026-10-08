extends RefCounted
## THE RATION RESERVE (decision 1742; Brendan's ruling of 2026-10-08 on 1741's F7 (b), "Add a ration reserve"): the
## inputs of one batch of rations held back from the kitchen's planning and from raw eating while the rations the
## village owns are below the reserve's target, so that a batch can actually be packed. Before it, no run of the year
## ever made a ration: the kitchen planned every flour, nut and grain into its meals within the hour, and hungry
## residents ate the dried fish raw (1739-1741's measurements).
##
## THE GDD'S MODEL. WorldPolicy `ration_reserve_milli:int64`, default 0 (§4.2), set by the player at M2 through
## UI-SET-099 ("Keep N rations in reserve"): `target_milli` here, 0 by default -- nothing held. REQ-SET-117 makes a
## minimum reserve a floor for ORDINARY production, which emergency meal access may break; Brendan's ruling holds this
## reserve from raw emergency meals too (a divergence 1742 records). Who may break it: §5.10's emergency action "release
## ordinary production food reserves", offered with the critical food alert and never taken by itself (REQ-SET-146) --
## `released`, set only by an order. The demo village sets a PROVISIONAL target (DEMO_TARGET_MILLI).
##
## WHAT IS HELD (`wanted_milli`), while the rations owned or being packed are below the target and the reserve is not
## released: §5.7 `ration`'s inputs for ONE batch -- dried fish 1 U, nuts 1 U, flour 2 U -- and, while the flour held
## is short of a batch, the grain of one mill batch (3 U) to grind it. Water comes from the butt (1737). Held in the
## reserve's own take in the kitchen's takes (ingredient_takes.gd), so neither the kitchen's planning nor a raw meal
## can take it (both take only food nobody has reserved); the rations' order and the mill's take it from the reserve
## (`give`). The Ready-food estimate still counts it in store (a limit 1742 records).
##
## HOW IT IS GATHERED (`top_up`, each game hour and whenever flour or dried fish is stored): food nobody has set aside
## first -- the lots that spoil LAST, so the kitchen still cooks what spoils first -- then what the kitchen planned for
## meals beyond its next one (`kitchen_give`: the rack's and the mill's rule, decisions 1739 and 1741 -- never the next
## meal's, never what the cook has in hand). Food no longer wanted goes back. No grain is gathered while a mill batch
## grinds: its flour is on the way.

const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The demo village's target: two batches of rations, 6 U. PROVISIONAL (1742's proposal; the GDD leaves it to the
## player, and BAL-SUPPLY-004's 18 winter days of rations is a full settlement's, hundreds of units).
const DEMO_TARGET_MILLI: int = 6000
## The categories it holds: the rations' three foods and the mill's grain.
const HELD: PackedInt32Array = [Catalog.CAT_DRIED_FISH, Catalog.CAT_NUTS, Catalog.CAT_FLOUR, FarmingScript.CROP_GRAIN]

## WorldPolicy `ration_reserve_milli`: the rations to keep, milli-U (0: no reserve; the GDD's default).
var target_milli: int = 0
## §5.10's emergency action taken: nothing is held until it is restored.
var released: bool = false
var pantry: PantryScript = null
var takes: TakesScript = null
## The reserve's own take (0: not configured).
var take: int = 0
## (milli, crop) -> int: the kitchen gives back that much of a category planned beyond its next meal (unbound: none).
var kitchen_give: Callable = Callable()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(p_pantry: PantryScript, p_takes: TakesScript) -> void:
	"""Hold food in `p_pantry` through a take of its own in `p_takes`."""
	pantry = p_pantry
	takes = p_takes
	take = p_takes.new_take()


func held_milli(category: int) -> int:
	"""What the reserve holds of `category`, milli-U."""
	return takes.live_milli(pantry, take, -1, category) if take != 0 else 0


func wanted_milli(category: int, rations_milli: int, milling: bool = false) -> int:
	"""What it should hold of `category` with `rations_milli` of rations owned or being packed (see WHAT IS HELD) --
	no grain while a mill batch is `milling` (its flour is on the way: the review of c9f67f16)."""
	if released or take == 0 or rations_milli >= target_milli:
		return 0
	if category == FarmingScript.CROP_GRAIN:
		var short: bool = held_milli(Catalog.CAT_FLOUR) < Recipes.input_milli(Recipes.R_RATION, Catalog.CAT_FLOUR)
		return FisheryRules.MILL_IN_MILLI if short and not milling else 0
	return Recipes.input_milli(Recipes.R_RATION, category)


func top_up(rations_milli: int, hour_index: int, milling: bool = false) -> void:
	"""Hold what is wanted of each category, flour before grain (held flour ends the grain's need; a mill batch
	`milling` too); let go the rest."""
	if take == 0:
		return
	for category: int in HELD:
		var want: int = wanted_milli(category, rations_milli, milling)
		var held: int = held_milli(category)
		if held > want:
			takes.release_milli(pantry, take, held - want, hour_index, category)
		elif held < want:
			_gather(category, want - held, hour_index)


func _gather(category: int, milli: int, hour_index: int) -> void:
	"""Hold up to `milli` more of `category`: free food first, then the kitchen's beyond its next meal."""
	var free: int = takes.free_milli_of_crop(pantry, category)
	if free < milli and kitchen_give.is_valid():
		kitchen_give.call(milli - free, category)
	takes.reserve_into(pantry, take, category, milli, hour_index, _read, true)


func give(category: int, milli: int, hour_index: int) -> int:
	"""Let go up to `milli` of `category` for the batch or mill batch it was held for; how much is free now for it."""
	return takes.release_milli(pantry, take, milli, hour_index, category) if take != 0 else 0
