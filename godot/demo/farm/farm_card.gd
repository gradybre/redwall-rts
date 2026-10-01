extends RefCounted
## The farm's words on an action card (demo/ui/action_card.gd, decision 0332; review F33): what each verb does to the
## bed, what it takes from which store, what it needs, and -- refused -- the refusal in the player's words and the
## way to put it right. The DECISION (refusal, assignment, work) is farm_crew.gd's `decide`, which the order reads
## too; this file only words it. The refusal words here are also the order's own ("Can't drain: the bed is not too
## wet"), farm_crew.gd `reason_text`, so a card and the answer to pressing it say the same thing.
##
## COSTS. Compost takes COMPOST_MILLI_PER_TILE (2 U) from the farm's compost store when it holds enough, else from a
## spoil heap (farm_jobs.gd `compost_source`); raising and banking take SPOIL_PER_JOB_MILLI off one heap. The have is
## the farm's compost store and the fullest heap -- the very figures `refusal_for` compares. Seed is not stocked in
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
	&"NO_TUNNEL_SPOIL": "no spoil heap holds %s",
	&"NOT_ENOUGH_COMPOST": "not enough compost: %s from the store or a spoil heap",
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
}
## How to put a refusal right, where something can.
const FIXES: Dictionary = {
	&"NOTHING_GROWING": "Plant… a crop first",
	&"NO_CROP_STANDING": "Plant… a crop first",
	&"NO_TUNNEL_SPOIL": "Dig tunnel (B): its spoil heaps up at the mouth",
	&"NOT_ENOUGH_COMPOST": "Pantry (K) ▸ compost spoiled food, or dig a tunnel (B) for spoil",
	&"COMPOST_NOT_ELIGIBLE": "wait for the next season",
	&"BED_RESTING_FALLOW": "Unrest the bed first",
	&"NO_ITEM_CHOSEN": "Plant… and pick a crop",
	&"PLOT_NOT_EMPTY": "harvest or clear the bed first",
	&"SOIL_INCOMPATIBLE": "pick a crop for this soil (Plant…)",
	&"OUTSIDE_PLANT_WINDOW": "pick a crop sown now (Plant…)",
	&"NOT_RIPE": "wait: the bed says when it ripens",
	&"JOB_BOARD_FULL": "Cancel jobs on a bed",
}
## What each verb needs (by farm_jobs.gd KIND_*).
const NEEDS: Array[String] = ["an empty bed, not resting; the crop's soil and sowing season",
	"a growing crop", "a ripe crop", "a withered or blighted crop", "once a season a bed; %s of compost or spoil",
	"a crop standing, not yet covered", "%s of tunnel spoil on one heap", "%s of tunnel spoil on one heap",
	"a wet or waterlogged bed"]
const COMPOST_STORE: String = "Compost (store)"
const SPOIL_HEAP: String = "Tunnel spoil (one heap)"


static func reason_words(code: StringName) -> String:
	"""A refusal code in the player's words (see WORDS), a dose stated from its own constant."""
	if WORDS.has(code):
		var words: String = WORDS[code]
		return words % CardScript.amount_text(dose_milli(code == &"NOT_ENOUGH_COMPOST")) if words.contains("%s") else words
	return String(code).to_lower().replace("_", " ")


static func dose_milli(compost: bool) -> int:
	"""The dose a verb takes: compost's REQ-SET-076 dose, or the spoil a raise, bank or spoil compost takes off a heap."""
	return FarmingScript.COMPOST_MILLI_PER_TILE if compost else JobsScript.SPOIL_PER_JOB_MILLI


static func fix_for(code: StringName) -> String:
	"""How to put a refusal right ('' when nothing the player does now will)."""
	return FIXES.get(code, "")


static func fill(card: CardScript, sim: SimScript, kind: int, bed: int, spoil_milli: int, read: IntMath.IntResult,
		sow_item: int = Catalog.NO_ITEM) -> void:
	"""The card's result, costs and needs for `kind` on `bed` (spoil_milli: the fullest heap, as `refusal_for`;
	sow_item: a picker row's crop, else the chosen one)."""
	card.result = result_text(sim, kind, bed, read, sow_item)
	var needs: String = NEEDS[kind]
	card.prerequisites.append(needs % CardScript.amount_text(dose_milli(kind == JobsScript.KIND_COMPOST)) if needs.contains("%s") else needs)
	match kind:
		JobsScript.KIND_COMPOST:
			var need: int = sim.farming().compost_milli_per_tile()
			if JobsScript.compost_source(sim, bed) == JobsScript.SOURCE_STORE or spoil_milli < JobsScript.SPOIL_PER_JOB_MILLI:
				card.add_cost(COMPOST_STORE, sim.compost_milli, need)
			if JobsScript.compost_source(sim, bed) == JobsScript.SOURCE_SPOIL:
				card.add_cost(SPOIL_HEAP, spoil_milli, JobsScript.SPOIL_PER_JOB_MILLI)
		JobsScript.KIND_RAISE, JobsScript.KIND_BANK:
			card.add_cost(SPOIL_HEAP, spoil_milli, JobsScript.SPOIL_PER_JOB_MILLI)


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
			return "Raise with tunnel spoil: the bed drains and is warmer at night"
	return "Bank with tunnel spoil: the bed keeps half of each day's drying"
