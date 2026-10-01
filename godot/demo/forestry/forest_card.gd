extends RefCounted
## The woods' words on an action card (demo/ui/action_card.gd, decision 0332; review F33). The DECISION -- the
## refusal, who takes the job, how many wait to haul, the work at that resident's skill -- is forest_crew.gd's
## `decide` and `plan_usec`, which the orders and the work read too; this file only words it: each job's result, its
## cost from the stores the HUD reads (sawing's wood; planting's compost, the farm's store), what it needs, and the
## way to put a refusal right. The refusal words themselves are the order's own (forest_crew.gd `reason_text`).

const Rules := preload("res://demo/forestry/forest_rules.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

## The verbs as a card names them, by forest_jobs.gd KIND_*: "%s" is the tree or spot ("" for none).
const VERBS: Array[String] = ["Fell %s", "Haul logs from %s", "Gather deadfall", "Saw planks", "Plant a sapling at %s",
	"Grub out %s"]
const NEEDS: Array[String] = ["a mature tree within the village's reach; its zone's floor kept",
	"a felled trunk, or a tree being felled", "deadfall lying in the woods", "%s of wood in the stores",
	"a cleared spot within reach; %s of compost", "a stump"]
## Felling's work is the felling; the feller then hauls the trunk in, `%d` trips.
const FELL_NOTE: String = ", plus the walk; then it is hauled in (%d trips)"
## A haul's work is every trip's loading and stacking, shared by its haulers.
const HAUL_NOTE: String = ", plus the walks; shared by its haulers"
const WOOD: String = "Wood (stores)"
const COMPOST: String = "Compost (farm store)"
const FIXES: Dictionary = {
	"NOT_ENOUGH_WOOD": "Fell and Haul logs, or Gather deadfall, for wood",
	"NO_COMPOST": "Farm: Pantry (K) ▸ compost spoiled food, or clear a withered bed",
	ZonesScript.REFUSE_FLOOR: "let young trees mature, or set the zone Intensive (keeps 10%)",
	ZonesScript.REFUSE_PROTECTED: "fell outside the conservation zone, or Unmark it",
	StandScript.REFUSE_NOT_MATURE: "wait for it to mature",
	StandScript.REFUSE_NO_TRUNK: "Fell the tree first",
	StandScript.REFUSE_NOT_CLEARED: "Grub out the stump first",
	DeadfallScript.REFUSE_NO_PILE: "wait for deadfall (a pile a day; storms bring more)",
	JobsScript.REFUSE_FULL: "Cancel woods jobs",
	JobsScript.REFUSE_ENOUGH_HANDS: "wait for a hauler to finish",
	"EVERYONE_SELECTED_BUSY": "select someone free, or deselect to queue it for the crew",
}


static func verb_text(kind: int, what: String) -> String:
	"""The card's first line: "Fell the oak", "Saw planks"."""
	var verb: String = VERBS[kind]
	return (verb % what if verb.contains("%s") else verb).strip_edges()


static func fix_for(code: String) -> String:
	"""How to put a woods refusal right ('' when nothing the player does now will)."""
	return FIXES.get(code, "")


static func trips(milli: int) -> int:
	"""Carrying trips `milli` of logs takes, CARRY_LOAD_MILLI a trip (rounded up)."""
	@warning_ignore("integer_division") return (milli + Rules.CARRY_LOAD_MILLI - 1) / Rules.CARRY_LOAD_MILLI


static func fill(card: CardScript, kind: int, amount_milli: int, wood_milli: int, compost_milli: int) -> void:
	"""The card's result, cost (have / need) and needs for a woods job bringing in `amount_milli`."""
	var needs: String = NEEDS[kind]
	if needs.contains("%s"):
		needs = needs % CardScript.need_text(Rules.SAW_BATCH_MILLI if kind == JobsScript.KIND_SAW else Rules.PLANT_COMPOST_MILLI)
	card.prerequisites.append(needs)
	var amount: String = CardScript.amount_text(amount_milli)
	match kind:
		JobsScript.KIND_FELL:
			card.result = "Felled: %s of wood lies ready to haul to the log stack" % amount
		JobsScript.KIND_HAUL:
			card.result = "%s of logs carried to the log stack (%s a trip): wood in the stores" % [amount,
				CardScript.amount_text(Rules.CARRY_LOAD_MILLI)]
		JobsScript.KIND_GATHER:
			card.result = "The nearest pile (%s) gathered into the stores' wood" % amount
		JobsScript.KIND_SAW:
			card.result = "%s of logs sawn into %s of planks at the sawhorse" % [amount, amount]
			card.add_cost(WOOD, wood_milli, Rules.SAW_BATCH_MILLI)
		JobsScript.KIND_PLANT:
			card.result = "A sapling planted: a mature tree in %d days" % Rules.REGROW_DAYS
			card.add_cost(COMPOST, compost_milli, Rules.PLANT_COMPOST_MILLI)
		JobsScript.KIND_GRUB:
			card.result = "The stump dug out: the spot is cleared for planting"


static func compost_paid(card: CardScript) -> void:
	"""A planting already on the board has paid its compost (forest_crew.gd CONSERVATION: once a job, decision 0222):
	joining it takes none, so the card's compost row needs nothing."""
	for k: int in card.cost_names.size():
		if card.cost_names[k] == COMPOST:
			card.cost_need[k] = 0
	card.result += " (its compost is paid already)"
