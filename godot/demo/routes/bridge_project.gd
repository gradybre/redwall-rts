extends RefCounted
## A bridge as a PROJECT, in the Water panel's words (decision 0461; review P5's project/woodland detail): what a site
## still lacks before it can be built, a planned bridge's materials -- delivered, reserved or being carried -- and its
## work, and an open bridge's route and condition in place of construction controls. Presentation only: read from the
## Build button's own action card (decision 0332), the bridge table (bridges.gd) and its crew (bridge_crew.gd).
##
## NOTHING IS MISSING ONCE PLANNED: the demo pays a bridge all or nothing when it is planned (demo_waterplay.gd
## `_pay`), so a planned bridge's material is reserved at its source until its builder loads it, carried, then
## delivered at the site; what may be missing is said only before -- from the card's have / need.

const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const MATERIALS: String = "Materials: %s — paid when it was planned, nothing missing; %s"
const ROUTE: String = "Route across: %s, carrying — no swimming%s"
const CONDITION: String = "Condition: sound — the demo's bridges need no upkeep"


static func shortage_line(kind: int, card: CardScript) -> String:
	"""What a `kind` bridge lacks, from its Build card's have / need: "Plank footbridge: missing 5 planks" ("" when
	nothing is short)."""
	var missing := PackedStringArray()
	for k: int in card.cost_names.size():
		if card.cost_need[k] > card.cost_have[k]:
			missing.append(card.short_text(k))
	if missing.is_empty():
		return ""
	var what: String = SwimRules.KIND_NAMES[kind]
	return "%s: missing %s" % [what.left(1).to_upper() + what.substr(1), ", ".join(missing)]


static func material_words(bridges: BridgesScript, row: int) -> String:
	"""What a planned bridge was paid with, as its cost was stated ("5 planks and 2 logs", "a trunk of 6 logs")."""
	if bridges.kind[row] == SwimRules.KIND_LOG:
		return SwimRules.log_words()
	var planks: String = Measures.need(&"planks", SwimRules.plank_milli(bridges.deck_u[row]))
	var wood: int = bridges.piers[row] * SwimRules.PIER_WOOD_MILLI
	return planks if wood == 0 else "%s and %s" % [planks, Measures.need(&"wood", wood)]


static func where_words(crew: CrewScript, row: int) -> String:
	"""Where a planned bridge's material is: delivered at the site, being carried there, or reserved at its source."""
	if crew.at_site[row] == 1:
		return "delivered at the site"
	if crew.builder[row] >= 0 and crew.step[row] == CrewScript.STEP_CARRY:
		return "being carried to the site by %s" % crew.name_of(crew.builder[row])
	return "reserved at %s" % CrewScript.SOURCE_WORDS[crew.source[row]]


static func planned_lines(bridges: BridgesScript, crew: CrewScript, row: int) -> String:
	"""A planned bridge: its materials (see NOTHING IS MISSING ONCE PLANNED), each stage's work, its builder."""
	var work := PackedStringArray()
	for stage: int in SwimRules.STAGE_COUNT:
		@warning_ignore("integer_division") work.append("%s %d%%" % [SwimRules.STAGE_NAMES[stage], bridges.stage_permille(row, stage) / 10])
	return "\n".join(PackedStringArray([MATERIALS % [material_words(bridges, row), where_words(crew, row)],
		"Work: " + " · ".join(work), "Builder: " + crew.job_text(row)]))
