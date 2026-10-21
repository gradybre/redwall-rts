extends RefCounted
## Test fixture (ADR 1228): a generated settlement with its underground Session mounted, every owner
## composed and the first entry begun exactly as `test_underground_host.gd`'s live chain begins it,
## with 7 wood and 2 stone staged at R. Nothing here is a production path; it builds the state the
## save body must carry.

const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")

## The live chain's suggested entry site (`test_underground_host.gd`).
const NEAR: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)
## Decision 2044: the whole-flight stand-ins (`sustain`). Every 20 ticks the needs are refilled; every 50 ticks a
## staged input below 3,000 milli gets 3,000. The generated cohort has no kitchen or stores yet (G9).
const SUSTAIN_NEEDS_EVERY: int = 20
const SUSTAIN_STOCK_EVERY: int = 50
const SUSTAIN_STOCK_MILLI: int = 3000


static func load_content() -> Content:
	"""The production actor image, or null when it does not load."""
	var content: Content = Content.new()
	if content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
			Session.PRESENTATION_BYTES) != &"":
		return null
	return content


static func mount_and_compose(host: Node, content: Content) -> StringName:
	"""Generate the world, mount the Session and run all four composer steps."""
	if not host.create_generated_settlement(host.item_definitions()):
		return &"FIXTURE_GENERATE"
	if not (host.mount_underground(content) and host.compose_underground_room_owners()
			and host.compose_underground_route_owners() and host.compose_underground_surface_anchor()
			and host.compose_underground_entry_owners()):
		return host.last_refusal()
	return &""


static func begin_entry(host: Node) -> StringName:
	"""The entry's real start (ADR 1217 step 5: the claw crew needs no tool), then 7 wood and 2 stone
	staged at R's ground-staging container, as the host suite's live chain does."""
	if not host.begin_underground_entry(NEAR):
		return host.last_refusal()
	var o: Session.Retirement.Owners = host.underground_session()._retirement_owners
	var output: Vector2i = host.underground_entry()._output
	var code: StringName = _stage(o, output, &"wood", 7000)
	return code if code != &"" else _stage(o, output, &"stone", 2000)


static func _stage(o: Session.Retirement.Owners, container: Vector2i, key: StringName,
		milli: int) -> StringName:
	"""One staged lot at R's ground-staging container."""
	return o.inventory.create_lot(container, o.items.compiled_id(key), milli, 1, 0, -1, 0, 0).error


static func run_ticks(host: Node, first: int, last: int) -> int:
	"""`run_tick` for every tick in [first, last] while the entry runs; the next tick to run, or
	-tick on the first tick the settlement refuses."""
	var tick: int = first
	while tick <= last and host.underground_entry().is_running():
		if not host.run_tick(tick):
			return -tick
		tick += 1
	return tick


static func eligible_moles(o: Session.Retirement.Owners) -> Array[Vector2i]:
	"""Every living adult mole holding no Job and no tool, by resident slot: the runtime's crew order (DEC-052).
	`underground_host_case.gd` reads the same list."""
	var residents: RefCounted = o.residents
	var found: Array[Vector2i] = []
	for slot: int in residents._present.size():
		if not residents.is_alive(slot) or residents.life_stage_code_of(slot) != Residents.LIFE_STAGE_ADULT \
				or residents.species_key(residents.species_of(slot).value) != &"mole" or residents.has_equipped_tool(slot) \
				or o.jobs.job_of(slot) != Jobs.NULL_REF: continue
		found.append(residents.ref_of(slot))
	return found


static func bench_all_but(host: Node, keep: Array[Vector2i]) -> StringName:
	"""Equip a real basic tool, staged at R's container, on every eligible mole outside `keep` (DEC-052: the claw
	rows take no tool, so the runtime passes a tooled mole over), as `underground_host_case._bench_moles()` does."""
	var o: Session.Retirement.Owners = host.underground_session()._retirement_owners
	var container: Vector2i = host.underground_entry()._output
	for mole: Vector2i in eligible_moles(o):
		if mole in keep: continue
		var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(&"tool"), 1000, 1, 0, -1, 0, 0)
		if not lot.ok or not o.gear.create_gear(o.inventory, o.items, lot.ref, o.gear.MANUFACTURE_BASIC).ok:
			return &"FIXTURE_TOOL"
		if not o.gear.equip(lot.ref, mole).ok:
			return &"FIXTURE_BENCH"
	return &""


static func begin_with_spare(host: Node) -> StringName:
	"""`underground_host_case._live_with_spare()`: the entry begun as `begin_entry()` begins it, then every eligible
	mole benched except the crew and the next one in crew order, the spare that replaces a lost crew."""
	var code: StringName = begin_entry(host)
	if code != &"":
		return code
	var crew: Vector2i = host.underground_entry().crew().worker
	var others: Array[Vector2i] = eligible_moles(host.underground_session()._retirement_owners)
	others.erase(crew)
	if others.is_empty():
		return &"FIXTURE_NO_SPARE"
	return bench_all_but(host, [crew, others[0]])


static func spare_of(host: Node) -> Vector2i:
	"""The spare of a `begin_with_spare()` chain: the one living adult mole other than the crew without a tool
	(every other mole was benched by one), or (-1, 0) when there is not exactly one."""
	var o: Session.Retirement.Owners = host.underground_session()._retirement_owners
	var crew: Vector2i = host.underground_entry().crew().worker
	var residents: RefCounted = o.residents
	var found: Array[Vector2i] = []
	for slot: int in residents._present.size():
		if residents.is_alive(slot) and residents.life_stage_code_of(slot) == Residents.LIFE_STAGE_ADULT \
				and residents.species_key(residents.species_of(slot).value) == &"mole" \
				and not residents.has_equipped_tool(slot) and residents.ref_of(slot) != crew:
			found.append(residents.ref_of(slot))
	return found[0] if found.size() == 1 else Vector2i(-1, 0)


static func sustain(o: Session.Retirement.Owners, output: Vector2i, tick: int) -> StringName:
	"""Decision 2044: the whole-flight stand-ins, run before tick `tick`: every present resident's hunger and rest
	refilled, and R's staged wood and stone topped up (`output` is R's ground-staging container). Decision 2045: a free
	Needs row is left zero, as the save requires (a spawn writes the whole row, so the run is the same)."""
	if tick % SUSTAIN_NEEDS_EVERY == 0:
		var needs: RefCounted = o.residents.needs()
		for slot: int in needs._present.size():
			if needs._present[slot] == 0: continue
			needs._need_value[slot * Needs.NEED_COUNT + Needs.NEED_HUNGER] = Needs.NEED_MAX
			needs._need_value[slot * Needs.NEED_COUNT + Needs.NEED_REST] = Needs.NEED_MAX
	if tick % SUSTAIN_STOCK_EVERY != 1: return &""
	for key: StringName in [&"wood", &"stone"]:
		if staged_milli(o, output, o.items.compiled_id(key)) < SUSTAIN_STOCK_MILLI:
			var code: StringName = _stage(o, output, key, SUSTAIN_STOCK_MILLI)
			if code != &"": return code
	return &""


static func staged_milli(o: Session.Retirement.Owners, container: Vector2i, item: int) -> int:
	"""Unreserved milli of `item` in `container`."""
	var total: int = 0
	var lot: Vector2i = o.inventory.container_first_lot(container)
	while lot != Vector2i(-1, 0):
		if o.inventory.lot_item_id(lot) == item: total += o.inventory.lot_available_milli(lot)
		lot = o.inventory.container_next_lot(lot)
	return total
