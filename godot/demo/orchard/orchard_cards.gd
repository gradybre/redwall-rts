extends RefCounted
## What the Orchard panel says (decision 0671): the standing line, each selection's title, readout and verbs, each verb's
## ACTION CARD (decision 0332: filled from the same check the order makes -- orchard_jobs.gd `order_refusal` -- so the
## card and the order cannot disagree), the group's policy, the nursery and the grove. Presentation only.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
const HiveText := preload("res://demo/hives/hive_text.gd")

## demo_orchard.gd's selection kinds (SEL_*), mirrored so this file needs no cycle back to the node.
const SEL_SITE: int = 1
const SEL_BUSH: int = 2
const SEL_STAND: int = 3
const SEL_NURSERY: int = 4
const SEL_GROVE: int = 5
## The apiary's skep (decision 1601).
const SEL_APIARY: int = 6
const JOB_OF_ACTION: Dictionary = {
	&"tend": Rules.K_TEND, &"harvest": Rules.K_HARVEST, &"pick": Rules.K_PICK, &"haul": Rules.K_HAUL,
	&"plant_apple": Rules.K_PLANT, &"plant_pear": Rules.K_PLANT, &"observe": Rules.K_OBSERVE,
	&"service": Rules.K_SERVICE, &"feed": Rules.K_FEED, &"recolonize": Rules.K_RECOLONIZE,
	&"move": Rules.K_MOVE, &"cart": Rules.K_CART,
}
const RECORD_SHOWN: int = 4

var compost_left: Callable = Callable()
var _model: ModelScript = null
var _jobs: JobsScript = null
var _command: DemoCommandScript = null
var _card: CardScript = CardScript.new()


func configure(model: ModelScript, jobs: JobsScript, command: DemoCommandScript) -> void:
	"""Read `model` and `jobs`; name residents through `command` (null in a check)."""
	_model = model
	_jobs = jobs
	_command = command


# --- the standing lines ----------------------------------------------------------------------------------------------------

func status_line() -> String:
	"""Today, the picking windows, and what has been picked."""
	return "%s · apples Autumn %d–%d, pears Autumn %d–%d · picked: %s apple, %s pear, %s berries" % [
		Text.day_text(_model.today_hint), Hive.SPECIES_HARVEST_FIRST_DAY[0], Hive.SPECIES_HARVEST_LAST_DAY[0],
		Hive.SPECIES_HARVEST_FIRST_DAY[1], Hive.SPECIES_HARVEST_LAST_DAY[1], Text.units(_model.fruit_picked_milli[0]),
		Text.units(_model.fruit_picked_milli[1]), Text.units(_model.berries_picked_milli)]


func jobs_line() -> String:
	"""The orchard's jobs on the board."""
	var live: int = 0
	var waiting: int = 0
	for j: int in JobsScript.MAX_JOBS:
		if _jobs.is_live(j):
			live += 1
			waiting += 1 if _jobs.worker[j] < 0 else 0
	return "Orchard jobs on the Work screen (J): %d (%d waiting for a hand)" % [live, waiting]


# --- the selection ---------------------------------------------------------------------------------------------------------

func title(kind: int, id: int) -> String:
	"""The selected thing's name ("" for nothing)."""
	match kind:
		SEL_SITE:
			return Text.cap(Text.tree_name(_model, id))
		SEL_BUSH:
			return Text.cap(Text.BUSH_WORDS[id])
		SEL_STAND:
			return Rules.STAND_LABELS[id]
		SEL_NURSERY:
			return "The nursery"
		SEL_GROVE:
			return Text.cap(Rules.GROVE_NAMES[id])
		SEL_APIARY:
			return Text.cap(HiveRules.APIARY_NAMES[id])
	return ""


func text(kind: int, id: int) -> String:
	"""The selected thing's readout."""
	match kind:
		SEL_SITE:
			return tree_text(id) if _model.has_tree(id) else site_text(id)
		SEL_BUSH:
			return bush_text()
		SEL_STAND:
			return stand_text(id)
		SEL_NURSERY:
			return "Saplings for the orchard: §5.6 propagation is fruit 4 U, compost 2 U, water 2 U and 120 WU, then 12 days."
		SEL_GROVE:
			return "A rest and observation spot: its trees are never felled while it is protected, someone looks in once a " \
				+ "season, and foraging trips leave its %s a reserve." % Text.grove_forage_words(id)
		SEL_APIARY:
			return apiary_text(id)
	return ""


func apiary_text(apiary: int) -> String:
	"""The apiary's readout (decision 1601): its state, REQ-SET-083's deficits, its stock and winter feed (ECO-012), and
	the crops it pollinates (ECO-011)."""
	var hives := _model.apiary
	var day: int = _model.today_hint
	return "\n".join(PackedStringArray([HiveText.state_line(hives, apiary, day), HiveText.deficit_line(hives, apiary, day),
		HiveText.stock_line(hives, apiary), _pollination_text(apiary),
		"Service: 20 WU a day spring to autumn; its honey goes to the old orchard's baskets once the winter feed is put by."]))


func _pollination_text(apiary: int) -> String:
	"""ECO-011's "which crops benefit": the orchard trees and the field beds whose tiles lie within its 12 m."""
	var trees := PackedStringArray()
	for site: int in Rules.SITE_COUNT:
		var origin: Vector2i = Rules.SITE_ORIGIN[site]
		if _model.has_tree(site) and _model.apiary.reaches(apiary, origin, origin + Vector2i.ONE * (Hive.BLOCK_SIZE - 1)):
			trees.append(Text.tree_name(_model, site))
	var beds := PackedStringArray()
	for bed: int in Catalog.BED_COUNT:
		var tile: Vector2i = HiveRules.tile_of_m(Catalog.bed_centre_m(bed))
		if _model.apiary.reaches(apiary, tile, tile):
			beds.append("bed %d" % (bed + 1))
	return HiveText.pollination_line(trees, beds, _model.apiary.is_healthy(apiary))


func tree_text(site: int) -> String:
	"""A tree's readout: its stage and age, health and care, its next picking and what it would give, and REQ-SET-081's
	first harvest days for a young tree."""
	var lines := PackedStringArray()
	var stage: int = _model.stage_of(site)
	var age: int = _model.age_of(site)
	@warning_ignore("integer_division") var percent: int = _model.health_of(site) / 100
	lines.append("%s · %d days old · health %d%% · %s" % [Rules.STAGE_NAMES[stage], age, percent,
		"tended today" if _model.tended_today(site) else "not tended today"])
	var next: int = _model.next_harvest_day(site, _model.today_hint)
	var why: String = _model.harvest_refusal(site, _model.today_hint)
	if why.is_empty():
		lines.append("Ready to pick now: about %s" % Text.units(_model.expected_yield_milli(site)))
	elif next > 0:
		lines.append("Next picking: %s%s" % [Text.day_text(next), _crop_words(site)])
	lines.append(Text.cap(Text.fruit_words(_model.species_of(site))))
	lines.append("Care: 20 WU a day in spring and summer; each untended day costs a hundredth of its health.")
	lines.append(move_line(site))
	return "\n".join(lines)


func move_line(site: int) -> String:
	"""Whether the tree may be moved (decision 1721): settling after its move, moved once, or still a sapling."""
	if _model.settle_days[site] > 0:
		return "Moved here: settling, %d days before it grows again." % _model.settle_days[site]
	if _model.moved[site] == 1:
		return "Moved once already: it stays here."
	if _model.inherited[site] == 0 and Rules.is_movable_age(_model.age_of(site)):
		return "A sapling: it may be moved once, to a free site, until it is %d days old (it then settles %d days)." % [
			Rules.HALF_YEAR_DAYS, Rules.MOVE_SETTLE_DAYS]
	return "Too big to move: it stays where it stands."


func _crop_words(site: int) -> String:
	"""What its next picking gives: a full crop, or decision 0672's early fifth."""
	if _model.is_mature(site) or _model.age_of(site) >= Hive.SPECIES_MATURITY_DAYS[_model.species_of(site)]:
		return " (a full crop at its health)"
	return " (an early crop: a fifth of a full one)"


func site_text(site: int) -> String:
	"""An empty site: REQ-SET-081's preview for each species planted today -- its block and its first harvest days."""
	var o: Vector2i = Rules.SITE_ORIGIN[site]
	var lines := PackedStringArray(["An empty block, tiles %d,%d to %d,%d (8 m square)." % [o.x, o.y, o.x + 3, o.y + 3]])
	for species: int in Hive.SPECIES_COUNT:
		var early: int = _model.first_early_day(species, _model.today_hint)
		var full: int = _model.store.first_eligible_harvest_day(species, _model.today_hint).value
		lines.append("%s planted today: first fruit %s, full crops from %s." % [Text.cap(Text.a_species(species)),
			Text.day_text(early if early > 0 else full), Text.day_text(full)])
	var plan: int = _model.plan_for_site(site)
	if plan != ModelScript.NONE:
		lines.append("Promised: " + Text.plan_line(_model, plan))
	lines.append("The nursery holds %d apple and %d pear saplings." % [_model.saplings[Rules.APPLE], _model.saplings[Rules.PEAR]])
	return "\n".join(lines)


func bush_text() -> String:
	"""The hedge's readout: its one §5.5 Berries patch, its season, what may be picked."""
	var season: int = Hive.season_of_day(_model.today_hint)
	var available: int = _model.berries_available_milli(season)
	var state: String = "in fruit" if Rules.berry_availability(season) > 0 else "not fruiting (berries in summer and autumn)"
	return "The hedge holds %s of berries, %s; %s may be picked now (a fifth is always left)." % [
		Text.units(_model.hedge_milli), state, Text.units(available)]


func stand_text(group: int) -> String:
	"""A stand's readout: what waits in its baskets, its room, and where its group sends them."""
	var parts := PackedStringArray()
	var at: int = _jobs.stand_location(group)
	if at < 0:
		return "No baskets here."
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var milli: int = _jobs.pantry.milli_at(item, at)
		if milli > 0:
			parts.append("%s %s" % [Catalog.ITEM_LABELS[item], Text.units(milli)])
	return "In the baskets: %s · room %s · %s · %s" % ["nothing" if parts.is_empty() else ", ".join(parts),
		Text.units(_jobs.pantry.room_milli_of(at)), share_words(group), cart_words(group)]


func share_words(group: int) -> String:
	"""The group's fresh-table share and how it went this year (decision 1721)."""
	return "%d%% wanted on the fresh table, %d%% sent there this year" % [_model.group_fresh_pct[group],
		_model.kitchen_share_pct(group)]


func cart_words(group: int) -> String:
	"""Whether the group has its handcart (decision 1721)."""
	if _model.has_cart(group):
		return "a handcart: %s a haul" % Text.units(Rules.CART_LOAD_MILLI)
	return "no cart: a basket's %s a haul" % Text.units(Rules.HAUL_LOAD_MILLI)


func shown_actions(kind: int, id: int) -> Array[StringName]:
	"""The verbs the selected thing shows."""
	match kind:
		SEL_SITE:
			if _model.has_tree(id):
				return [&"tend", &"harvest", &"move"]
			if _model.plan_for_site(id) != ModelScript.NONE:
				return [&"plant_apple", &"plant_pear", &"drop_plan"]
			return [&"plant_apple", &"plant_pear", &"plan_apple", &"plan_pear"]
		SEL_BUSH:
			return [&"pick"]
		SEL_STAND:
			return [&"haul", &"cart"]
		SEL_GROVE:
			return [&"observe"]
		SEL_APIARY:
			return [&"service", &"feed", &"recolonize"]
	return []


func job_of(action: StringName, kind: int, id: int) -> Vector3i:
	"""The job an action orders: (kind, target, species); kind -1 for none."""
	if not JOB_OF_ACTION.has(action):
		return Vector3i(-1, -1, -1)
	var species: int = Rules.APPLE if action == &"plant_apple" else (Rules.PEAR if action == &"plant_pear" else -1)
	return Vector3i(JOB_OF_ACTION[action], id if kind >= 0 else -1, species)


func refusal(action: StringName, kind: int, id: int) -> String:
	"""Why an action would be refused now ("" when it would be taken): the order's own check."""
	match action:
		&"plan_apple", &"plan_pear":
			return Text.plant_words("SITE_PLANNED" if _model.plan_for_site(id) != ModelScript.NONE else "")
		&"drop_plan":
			var plan: int = _model.plan_for_site(id)
			return "" if plan != ModelScript.NONE and _model.plan_state[plan] == ModelScript.PLAN_WAITING \
				else "its sapling is already growing: it goes on to this site"
		&"move":
			return _jobs.move_order_refusal(id)
	var job: Vector3i = job_of(action, kind, id)
	return _jobs.order_refusal(job.x, job.y, job.z) if job.x >= 0 else ""


func pressing(kind: int, id: int) -> StringName:
	"""The selected thing's most pressing verb for a right click (&"": nothing to do now)."""
	for action: StringName in _pressing_order(kind, id):
		if refusal(action, kind, id).is_empty():
			return action
	return &""


func _pressing_order(kind: int, id: int) -> Array[StringName]:
	"""The verbs a right click tries, most pressing first."""
	if kind == SEL_SITE and _model.has_tree(id):
		return [&"harvest", &"tend"]
	if kind == SEL_STAND:
		return [&"haul"]
	if kind == SEL_SITE:
		var plan: int = _model.plan_for_site(id)
		if plan != ModelScript.NONE:
			return [&"plant_apple" if _model.plan_species[plan] == Rules.APPLE else &"plant_pear"]
		return [&"plant_apple", &"plant_pear"]
	return shown_actions(kind, id)


func nothing_to_do(kind: int, id: int) -> String:
	"""What a right click says when the thing has no work now."""
	var actions: Array[StringName] = _pressing_order(kind, id)
	if actions.is_empty():
		return "Nothing to do here now."
	return "Nothing to do here now: %s" % refusal(actions[0], kind, id)


# --- the action cards --------------------------------------------------------------------------------------------------------

func card_text(action: StringName, kind: int, id: int, members: PackedInt32Array, why: String) -> String:
	"""The action's card (decision 0332): the verb, the refusal and its fix, the result, the costs, the work, who."""
	_card.reset("%s — %s" % [Text.KIND_NAMES[JOB_OF_ACTION[action]] if JOB_OF_ACTION.has(action)
		else Text.cap(String(action).replace("_", " ")), title(kind, id).to_lower()])
	if not why.is_empty():
		_card.refuse(why, why, _fix_of(why))
	_card.result = _result_of(action, kind, id)
	_costs_of(action)
	var job: Vector3i = job_of(action, kind, id)
	if job.x >= 0:
		_card.work_usec = Rules.work_usec(_work_of(job.x, id))
		_card.who = _who(members)
	return _card.text()


func _fix_of(why: String) -> String:
	"""How to put a refusal right, where a panel does it."""
	if why.begins_with(Text.NO_ROOM_HEAD):
		return "the Pantry (K), or send the baskets on"
	if why.contains("compost"):
		return "compost spoiled food in the Pantry (K)"
	if why.contains("of wood"):
		return "fell a tree in the woods (the Woods panel)"
	if why.contains("sapling"):
		return "plan one here: the nursery propagates it from fruit"
	return ""


func _result_of(action: StringName, kind: int, id: int) -> String:
	"""What the action does when it is done."""
	match action:
		&"tend":
			return "Today's care: +50 health at midnight instead of -100"
		&"harvest":
			return "About %s picked into the group's baskets" % Text.units(_model.expected_yield_milli(id))
		&"pick":
			return "A basket of up to %s of %s, as berries" % [Text.units(Rules.PICK_LOAD_MILLI), Text.BUSH_FRUIT[id]]
		&"haul", &"move", &"cart":
			return _remainder_result(action, id)
		&"plant_apple", &"plant_pear":
			return "A new tree on this block (REQ-SET-081: see its first harvest above)"
		&"plan_apple", &"plan_pear":
			return "The nursery promises a sapling to this block and propagates it when it has the fruit"
		&"observe":
			return "This season's line in the grove's record"
		&"service":
			return "Today's service (no strength lost); the honey made goes to the winter feed first, the rest to the baskets"
		&"feed":
			return "The hive's winter feed made up from the stores' free honey"
		&"recolonize":
			return "A swarm settles %d days after the work: the hive back at 80%% strength" % HiveRules.RECOLONIZE_WAIT_DAYS
	return "" if kind >= 0 else ""


func _remainder_result(action: StringName, id: int) -> String:
	"""Decision 1721's results: a haul by basket or cart and its share, a move, a cart."""
	match action:
		&"haul":
			return "Up to %s carried on (%s; %d%% wanted on the fresh table)" % [Text.units(_model.haul_load_milli(id)),
				"by handcart" if _model.has_cart(id) else "a basket", _model.group_fresh_pct[id]]
		&"move":
			var dest: int = _jobs.move_target(id)
			return "Lifted and replanted at %s; it settles %d days before it grows again, and is never moved twice" % [
				Rules.SITE_NAMES[dest] if dest >= 0 else "a free site", Rules.MOVE_SETTLE_DAYS]
	return "A handcart at the baskets: each haul carries up to %s instead of %s" % [Text.units(Rules.CART_LOAD_MILLI),
		Text.units(Rules.HAUL_LOAD_MILLI)]


func _costs_of(action: StringName) -> void:
	"""The action's costs, have / need."""
	var compost: int = int(compost_left.call()) if compost_left.is_valid() else 0
	match action:
		&"plant_apple", &"plant_pear":
			var species: int = Rules.APPLE if action == &"plant_apple" else Rules.PEAR
			_card.add_cost("%s saplings" % Text.cap(Rules.SPECIES_NAMES[species]), Rules.SAPLING_GOODS[species], _model.saplings[species] * 1000,
				Hive.PLANT_SAPLING_MILLI)
			_card.add_cost("Compost", &"compost", compost, Hive.PLANT_COMPOST_MILLI)
		&"move":
			_card.add_cost("Compost", &"compost", compost, Rules.MOVE_COMPOST_MILLI)
		&"cart":
			_card.add_cost("Wood", &"wood", _jobs.stores.wood_milli_u if _jobs.stores != null else 0, Rules.CART_WOOD_MILLI)
		&"recolonize":
			_card.add_cost("Honey (free)", &"honey", _jobs.hive_honey_free(), HiveRules.RECOLONIZE_HONEY_MILLI)
			_card.add_cost("Wood", &"wood", _jobs.stores.wood_milli_u if _jobs.stores != null else 0, HiveRules.RECOLONIZE_WOOD_MILLI)


func _work_of(job_kind: int, id: int) -> int:
	"""The milli-WU the job's work takes."""
	match job_kind:
		Rules.K_TEND:
			return Rules.CARE_MWU
		Rules.K_HARVEST:
			return Rules.HARVEST_MWU if _model.is_mature(id) else Rules.EARLY_HARVEST_MWU
		Rules.K_PICK:
			return Rules.pick_mwu(Rules.PICK_LOAD_MILLI)
		Rules.K_HAUL:
			return Rules.HAUL_LOAD_MWU + Rules.HAUL_UNLOAD_MWU
		Rules.K_PLANT:
			return Rules.PLANT_MWU
		Rules.K_SERVICE:
			return HiveRules.SERVICE_MWU
		Rules.K_FEED:
			return HiveRules.FEED_MWU
		Rules.K_RECOLONIZE:
			return HiveRules.RECOLONIZE_MWU
		Rules.K_MOVE:
			return Rules.MOVE_LIFT_MWU + Rules.MOVE_REPLANT_MWU
		Rules.K_CART:
			return Rules.CART_BUILD_MWU
	return Rules.OBSERVE_MWU


func _who(members: PackedInt32Array) -> String:
	"""Who will do it: the nearest selected resident, else the board's Field crew."""
	if members.is_empty() or _command == null:
		return "Queued for the Field crew (the Work screen hands it out)"
	return "Assign selected: the nearest of %d" % members.size()


# --- the group, the nursery and the grove ------------------------------------------------------------------------------------

func group_of(kind: int, id: int) -> int:
	"""The group the selected thing belongs to (-1: none)."""
	match kind:
		SEL_SITE:
			return Rules.SITE_GROUP[id]
		SEL_BUSH:
			return Rules.BUSH_GROUP
		SEL_STAND:
			return id
	return -1


func group_text(group: int) -> String:
	"""A group's readout: its trees' windows, its baskets and its policy in words (ECO-010)."""
	if group < 0:
		return ""
	var trees := PackedStringArray()
	for site: int in Rules.SITE_COUNT:
		if Rules.SITE_GROUP[site] == group and _model.has_tree(site):
			trees.append(Text.tree_name(_model, site))
	return "Its trees: %s. Picked fruit gathers at its baskets and is sent on by the Haulers: %s; %s." % [
		"none yet" if trees.is_empty() else ", ".join(trees), share_words(group), cart_words(group)]


func timing_word(group: int) -> String:
	"""The group's timing, short for its button (the card says it in full)."""
	return Rules.TIMING_SHORT[_model.group_timing[group]] if group >= 0 else ""


func dest_word(group: int) -> String:
	"""The group's fresh-table share, short for its button (decision 1721)."""
	return "fresh %d%%" % _model.group_fresh_pct[group] if group >= 0 else ""


func keep_word(group: int) -> String:
	"""What the group keeps for the nursery, short for its button."""
	return Text.units(_model.group_keep[group]) if group >= 0 else ""


func nursery_text() -> String:
	"""The nursery: its free saplings and its plans (ECO-009), each with its first fruiting season."""
	var lines := PackedStringArray(["Saplings: %d apple, %d pear (the M3 grant, held from the start)." % [
		_model.saplings[Rules.APPLE], _model.saplings[Rules.PEAR]]])
	for plan: int in Rules.MAX_PLANS:
		if _model.plan_state[plan] != ModelScript.PLAN_FREE:
			lines.append(Text.plan_line(_model, plan))
	if lines.size() == 1:
		lines.append("No plans: select an empty site to promise it a sapling.")
	return "\n".join(lines)


func grove_text(grove: int) -> String:
	"""Grove `grove`: its rule, its forage reserve (decision 1721) and its latest record lines (ECO-015)."""
	var protected: bool = _model.is_grove_protected(grove)
	var lines := PackedStringArray(["Its trees are %s; someone looks in once a season. %s" % [
		"never felled while it is protected" if protected else "NOT protected: forestry may fell them",
		Text.reserve_words(grove, protected)]])
	var record: PackedStringArray = _model.grove_record[grove]
	for k: int in mini(RECORD_SHOWN, record.size()):
		lines.append(record[k])
	return "\n".join(lines)


func policy_tip(action: StringName, group: int) -> String:
	"""A policy button's card: what it is set to and what pressing it does (ECO-010, ECO-015). `group` is the group, or
	for &"protect" the grove."""
	match action:
		&"timing":
			return CardScript.wrap_lines(PackedStringArray(["Harvest timing: %s" % Rules.TIMING_NAMES[_model.group_timing[group]],
				"As each ripens: every tree picked as its window opens (apples Autumn 1, pears Autumn 3).",
				"All together: the group's trees picked on the first day all of them may be: one big picking.",
				"Press: switch."]))
		&"dest":
			return CardScript.wrap_lines(PackedStringArray([
				"Fresh-table share: %d%% of the hauls to the kitchen pantry, the rest to the best keeping store" % \
					_model.group_fresh_pct[group],
				"Each haul goes where the share is furthest behind, and to the other when that has no room: a wish, not a promise.",
				"This year: %d%% sent to the kitchen pantry." % _model.kitchen_share_pct(group),
				"Press: 0, 25, 50, 75 or 100%."]))
		&"keep":
			return CardScript.wrap_lines(PackedStringArray(["Kept at the baskets for the nursery: %s of each fruit" % Text.units(
				_model.group_keep[group]), "4.0 U of fruit makes one sapling (with compost 2 U and water 2 U).",
				"Press: 0, 4.0 or 8.0 U."]))
	var grove: int = maxi(group, 0)
	return CardScript.wrap_lines(PackedStringArray(["%s: %s" % [Text.cap(Rules.GROVE_NAMES[grove]),
		"protected" if _model.is_grove_protected(grove) else "not protected"],
		"Protected: no tree in it is felled -- not by order, a zone's routine or the winter's firewood.",
		"Press: switch."]))
