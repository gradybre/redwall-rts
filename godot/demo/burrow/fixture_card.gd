extends RefCounted
## The fit-out's action cards (demo/ui/action_card.gd, decision 0332; review F33/F44): what a palette "+", "−" or the
## Suggested layout will do in the selected room. The DECISION is room_fixtures.gd's -- `order_refusal`,
## `suggest_refusal`, `take_refusal`, the very checks `order`, `suggest` and `take_out` run -- and the refusal's words
## are room_text.gd `answer`'s, the line the order logs. Who puts a fixture in is fixture_crew.gd's rule: the first
## selected resident who can reach the room (`first_able`), else the nearest free one by day, up to three at once.

const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const FixtureCrewScript := preload("res://demo/burrow/fixture_crew.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomTextScript := preload("res://demo/burrow/room_text.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const CODES: Array[String] = ["", "NOT_DUG", "NOT_HERE", "FULL", "STORES_SHORT", "NOTHING_TO_ADD", "NONE_TO_TAKE",
	"HOLDS_FOOD", "NO_NOOK"]
## How to put a refusal right (by room_fixtures.gd REFUSE_*; '' where nothing will).
const FIXES: Array[String] = ["", "wait for the room to be dug out", "", "take one out (−) first",
	"Woods ▸ Saw planks (%s wood makes %s planks); Fell and Haul logs for wood", "", "",
	"let the cellar's food be eaten or moved first", ""]
const WHO_CAN: String = "who can reach the room"
const QUEUE: String = "the nearest free resident who can reach the room, by day (up to %d at once)"
const NOBODY_ABLE: String = " (no selected resident can reach the room)"
## A selected resident puts the room's first waiting fixture in first (`_first_waiting`).
const FIRST_WAITING: String = "; first it puts in the %s already waiting"
## `_first_waiting`'s scratch.
static var _waiting: PackedInt32Array = PackedInt32Array()


static func add_into(card: CardScript, graph: RefCounted, r: int, kind: int, stores: RefCounted, members: PackedInt32Array,
		crew: FixtureCrewScript, names: PackedStringArray) -> void:
	"""The "+" card: plan a `kind` in room `r` (order_refusal), its cost have / need, its install work and who."""
	var fit: FixturesScript = graph.fit
	card.reset("Plan a %s in %s" % [RoomsScript.FIXTURE_NAMES[kind], RoomTextScript.name_of(graph, r)])
	card.result = "Planned and paid now; a resident puts it in"
	_costs(card, stores, Vector3i(FixturesScript.COST_PLANKS_MILLI[kind], FixturesScript.COST_WOOD_MILLI[kind],
		FixturesScript.COST_STONE_MILLI[kind]))
	card.prerequisites.append("a dug room with an empty place for it")
	var code := fit.order_refusal(graph, r, kind, stores)
	if code != FixturesScript.REFUSE_NONE:
		_refuse(card, graph, r, PackedStringArray(["fit", RoomTextScript.FIT_ADD, str(kind)]), code, stores, Callable())
		return
	card.work_usec = FixturesScript.install_usec(kind)
	_who(card, r, members, crew, names)
	if card.worker >= 0:
		card.who += _first_waiting(graph, r, fit.place_for(graph, r, kind))


static func suggest_into(card: CardScript, graph: RefCounted, r: int, stores: RefCounted, members: PackedInt32Array,
		crew: FixtureCrewScript, names: PackedStringArray) -> void:
	"""The Suggested layout's card: every empty place planned at once (suggest_refusal), paid all together."""
	var fit: FixturesScript = graph.fit
	card.reset("Suggested layout for %s" % RoomTextScript.name_of(graph, r))
	card.result = "A fixture planned in every empty place, paid all together; residents put them in"
	_costs(card, stores, fit.missing_cost(graph, r))
	card.prerequisites.append("a dug room with empty places")
	var code := fit.suggest_refusal(graph, r, stores)
	if code != FixturesScript.REFUSE_NONE:
		_refuse(card, graph, r, PackedStringArray(["fit", RoomTextScript.FIT_SUGGEST]), code, stores, Callable())
		return
	var layout := PackedInt32Array()
	fit.layout_into(graph, r, layout)
	var usec := 0
	for kind: int in layout:
		usec += FixturesScript.install_usec(kind) if kind >= 0 else 0
	card.work_usec = usec
	card.work_note = ", shared by up to %d at once" % FixtureCrewScript.MAX_INSTALLERS
	_who(card, r, members, crew, names)


static func take_into(card: CardScript, graph: RefCounted, r: int, kind: int, stores: RefCounted, stored: Callable) -> void:
	"""The "−" card: room `r`'s last `kind` taken out (take_refusal), its cost given back to the stores at once."""
	card.reset("Take a %s out of %s" % [RoomsScript.FIXTURE_NAMES[kind], RoomTextScript.name_of(graph, r)])
	card.result = "Taken out at once: %s back in the stores" % FixturesScript.cost_text(kind)
	card.prerequisites.append("one planned or put in")
	var stored_u := int(stored.call(r)) if stored.is_valid() else 0
	var code: int = graph.fit.take_refusal(graph, r, kind, stored_u)
	if code != FixturesScript.REFUSE_NONE:
		_refuse(card, graph, r, PackedStringArray(["fit", RoomTextScript.FIT_TAKE, str(kind)]), code, stores, stored)


static func _first_waiting(graph: RefCounted, r: int, f_new: int) -> String:
	"""`give_selected` hands a selected resident the room's FIRST waiting fixture in place order: when one waits
	before the new one's place `f_new`, the resident puts that in first -- said so (empty when the new one is first)."""
	graph.fit.waiting_into(graph, _waiting)
	for row: int in _waiting:
		if row / FixturesScript.PLACES == r and row % FixturesScript.PLACES < f_new:
			return FIRST_WAITING % RoomsScript.FIXTURE_NAMES[graph.fit.kind_at(graph, r, row % FixturesScript.PLACES)]
	return ""


static func _costs(card: CardScript, stores: RefCounted, cost: Vector3i) -> void:
	"""Cost rows (planks, wood, stone) for the parts that are not nothing."""
	if cost.x > 0:
		card.add_cost("Planks", stores.plank_milli_u, cost.x)
	if cost.y > 0:
		card.add_cost("Wood", stores.wood_milli_u, cost.y)
	if cost.z > 0:
		card.add_cost("Stone", stores.stone_milli_u, cost.z)


static func _refuse(card: CardScript, graph: RefCounted, r: int, parts: PackedStringArray, code: int, stores: RefCounted,
		stored: Callable) -> void:
	"""The refusal in the order's own words (room_text.gd `answer`, without its "Can't: ") and its fix."""
	var words := RoomTextScript.answer(graph, r, parts, code, stores, stored)
	var batch := CardScript.amount_text(ForestRules.SAW_BATCH_MILLI)
	card.refuse(CODES[code], words.trim_prefix("Can't: "), FIXES[code] % [batch, batch] if FIXES[code].contains("%s") else FIXES[code])


static func _who(card: CardScript, r: int, members: PackedInt32Array, crew: FixtureCrewScript, names: PackedStringArray) -> void:
	"""Who puts it in: the first selected resident able to (named, with what it stops), else the free residents."""
	var who := crew.first_able(r, members) if crew != null else -1
	if who >= 0:
		card.worker = who
		card.who = CardScript.assign_first(names[who], members.size(), WHO_CAN)
		return
	card.who = "Queue for " + QUEUE % FixtureCrewScript.MAX_INSTALLERS + (NOBODY_ABLE if not members.is_empty() else "")
