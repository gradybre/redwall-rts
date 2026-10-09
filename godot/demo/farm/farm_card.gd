extends RefCounted
## The farm's words on an action card (demo/ui/action_card.gd, decision 0332; review F33): what each verb does to the
## bed, what it takes from which store, what it needs, and -- refused -- the refusal in the player's words and the
## way to put it right. The DECISION (refusal, assignment, work) is farm_crew.gd's `decide`, which the order reads
## too; this file only words it. The refusal words here are also the order's own ("Can't drain: the bed is not too
## wet"), farm_crew.gd `reason_text`, so a card and the answer to pressing it say the same thing.
##
## COSTS. Compost takes COMPOST_MILLI_PER_TILE (2 U) from the farm's compost store, which only plant waste fills
## (decision 0401); raising and banking take EARTH_PER_JOB_MILLI of earth from one source -- a spoil heap or the stores
## (farm_tunnels.gd SOURCES). The have is the compost store and the fullest source -- the very figures `refusal_for`
## compares. Seed is not stocked in
## the demo (farm_sim.gd), so sowing shows no cost; water comes from the well.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## Refusal codes in the player's words (an unknown code falls back to its own words, lower case).
const WORDS: Dictionary = {
	&"NOT_RIPE": "the crop is not ripe yet",
	&"NOTHING_GROWING": "nothing is growing to water",
	&"NO_EARTH": "no spoil heap or store holds %s of earth",
	&"NOT_ENOUGH_COMPOST": "not enough compost: %s from the compost store",
	&"COMPOST_NOT_ELIGIBLE": "this bed has had its compost this season",
	&"ALREADY_DONE": "it is done on this bed already",
	&"NO_CROP_STANDING": "there is no crop to cover",
	&"NOT_TOO_WET": "the bed is not too wet",
	&"NOTHING_TO_CLEAR": "nothing withered or blighted to clear",
	&"BED_RESTING_FALLOW": "the bed is resting fallow",
	&"NO_ITEM_CHOSEN": "no crop is chosen",
	&"PLOT_NOT_EMPTY": "the bed is not empty",
	&"SOIL_INCOMPATIBLE": "the crop does not grow in this soil",
	&"OUTSIDE_PLANT_WINDOW": "it is not the season to sow it",
	&"JOB_BOARD_FULL": "the farm's job board is full",
	&"NOT_LAID_OUT": "no bed is laid out on this garden site",
	&"NO_TUNNEL_UNDER": "no finished tunnel runs under this bed",
	&"NO_OUTLET_FITTED": "no outlet is fitted to this bed",
	&"BED_IN_USE": "something stands in the bed",
}
## How to put a refusal right, where something can.
const FIXES: Dictionary = {
	&"NOTHING_GROWING": "Plant… a crop first",
	&"NO_CROP_STANDING": "Plant… a crop first",
	&"NO_EARTH": "Dig tunnel (B): its earth heaps up at the mouth",
	&"NOT_ENOUGH_COMPOST": "Pantry (K) ▸ compost spoiled food, or clear a withered bed",
	&"COMPOST_NOT_ELIGIBLE": "wait for the next season",
	&"BED_RESTING_FALLOW": "Unrest the bed first",
	&"NO_ITEM_CHOSEN": "Plant… and pick a crop",
	&"PLOT_NOT_EMPTY": "harvest or clear the bed first",
	&"SOIL_INCOMPATIBLE": "pick a crop for this soil (Plant…)",
	&"OUTSIDE_PLANT_WINDOW": "pick a crop sown now (Plant…)",
	&"NOT_RIPE": "wait: the bed says when it ripens",
	&"JOB_BOARD_FULL": "Cancel jobs on a bed",
	&"NOT_LAID_OUT": "Lay out a bed here first (the garden site's panel)",
	&"NO_TUNNEL_UNDER": "Dig tunnel (B) under the bed first",
	&"NO_OUTLET_FITTED": "Fit outlet first",
	&"BED_IN_USE": "harvest or clear the bed first",
}
## What each verb needs (by farm_jobs.gd KIND_*).
const NEEDS: Array[String] = ["an empty bed, not resting; the crop's soil and sowing season",
	"a growing crop", "a ripe crop", "a withered or blighted crop", "once a season a bed; %s of compost",
	"a crop standing, not yet covered", "%s of earth on one heap or in the stores",
	"%s of earth on one heap or in the stores",
	"a wet or waterlogged bed", "a finished tunnel under the bed, no outlet fitted yet"]
const COMPOST_STORE: String = "Compost (store)"
const EARTH: String = "Earth (one heap or the stores)"


static func reason_words(code: StringName) -> String:
	"""A refusal code in the player's words (see WORDS), a dose stated from its own constant."""
	if WORDS.has(code):
		var words: String = WORDS[code]
		return words % CardScript.amount_text(dose_milli(code == &"NOT_ENOUGH_COMPOST")) if words.contains("%s") else words
	return String(code).to_lower().replace("_", " ")


static func dose_milli(compost: bool) -> int:
	"""The dose a verb takes: compost's REQ-SET-076 dose, or the earth a raise or a bank takes from one source."""
	return FarmingScript.COMPOST_MILLI_PER_TILE if compost else JobsScript.EARTH_PER_JOB_MILLI


static func fix_for(code: StringName) -> String:
	"""How to put a refusal right ('' when nothing the player does now will)."""
	return FIXES.get(code, "")


static func fill(card: CardScript, sim: SimScript, kind: int, bed: int, earth_milli: int, read: IntMath.IntResult,
		sow_item: int = Catalog.NO_ITEM) -> void:
	"""The card's result, costs and needs for `kind` on `bed` (earth_milli: the fullest earth source, as `refusal_for`;
	sow_item: a picker row's crop, else the chosen one)."""
	card.result = result_text(sim, kind, bed, read, sow_item)
	var needs: String = NEEDS[kind]
	card.prerequisites.append(needs % CardScript.amount_text(dose_milli(kind == JobsScript.KIND_COMPOST)) if needs.contains("%s") else needs)
	match kind:
		JobsScript.KIND_COMPOST:
			card.add_cost(COMPOST_STORE, &"compost", sim.compost_milli, sim.farming().compost_milli_per_tile())
		JobsScript.KIND_RAISE, JobsScript.KIND_BANK:
			card.add_cost(EARTH, &"earth", earth_milli, JobsScript.EARTH_PER_JOB_MILLI)


static func result_text(sim: SimScript, kind: int, bed: int, read: IntMath.IntResult,
		sow_item: int = Catalog.NO_ITEM) -> String:
	"""What the verb does when done, in the farm panel's own words where it has them (farm_text.gd)."""
	match kind:
		JobsScript.KIND_SOW:
			var item: int = sow_item if Catalog.is_item(sow_item) else sim.chosen_of(bed)
			return "Sow: " + (Text.pick_row(sim, bed, item) if Catalog.is_item(item) else "pick a crop, then it is sown")
		JobsScript.KIND_WATER, JobsScript.KIND_DRAIN, JobsScript.KIND_COMPOST:
			return Text.verb_tip(sim, bed, kind)
		JobsScript.KIND_HARVEST:
			var line: String = Text.yield_line(sim, bed, read)
			return (line if not line.is_empty() else "Harvest the crop") + ", carried to the store"
		JobsScript.KIND_CLEAR:
			return "Clear: the bed is empty again (+%s compost to the store)" % CardScript.amount_text(
				FarmingScript.CLEARING_COMPOST_MILLI)
		JobsScript.KIND_COVER:
			return "Cover with straw: frost spares the crop tonight (off at 06:00)"
		JobsScript.KIND_RAISE:
			return "Raise with tunnel earth: the bed drains and is warmer at night (earth adds no fertility)"
		JobsScript.KIND_FIT_OUTLET:
			return "Fit outlet: a boarded outlet down to the tunnel under the bed, shut (transport only) until you set it"
	return "Bank with tunnel earth: the bed keeps half of each day's drying (earth adds no fertility)"
