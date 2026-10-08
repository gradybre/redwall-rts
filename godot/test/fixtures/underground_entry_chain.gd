extends RefCounted
## Test fixture (ADR 1228): a generated settlement with its underground Session mounted, every owner
## composed and the first entry begun exactly as `test_underground_host.gd`'s live chain begins it --
## one basic tool equipped by the first adult mole and 7 wood and 2 stone staged at R. Nothing here
## is a production path; it builds the state the save body must carry.

const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")

## The live chain's suggested entry site (`test_underground_host.gd`).
const NEAR: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)


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
	"""The G11 refusal, the tooled mole and the staged stock, then the entry's real start."""
	host.begin_underground_entry(NEAR)
	var o: Session.Retirement.Owners = host.underground_session()._retirement_owners
	var output: Vector2i = host.underground_entry()._output
	var code: StringName = _equip_first_mole(o, output)
	if code == &"": code = _stage(o, output, &"wood", 7000)
	if code == &"": code = _stage(o, output, &"stone", 2000)
	if code == &"" and not host.begin_underground_entry(NEAR):
		code = host.last_refusal()
	return code


static func _stage(o: Session.Retirement.Owners, container: Vector2i, key: StringName,
		milli: int) -> StringName:
	"""One staged lot at R's ground-staging container."""
	return o.inventory.create_lot(container, o.items.compiled_id(key), milli, 1, 0, -1, 0, 0).error


static func _equip_first_mole(o: Session.Retirement.Owners, container: Vector2i) -> StringName:
	"""One real basic tool lot equipped by the first present mole."""
	var residents: RefCounted = o.residents
	for slot: int in residents._present.size():
		if not residents.is_present(slot) or residents.species_key(residents.species_of(slot).value) != &"mole":
			continue
		var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(&"tool"), 1000, 1, 0, -1, 0, 0)
		if not lot.ok:
			return lot.error
		var made: RefCounted = o.gear.create_gear(o.inventory, o.items, lot.ref, o.gear.MANUFACTURE_BASIC)
		if not made.ok:
			return made.error
		return o.gear.equip(lot.ref, residents.ref_of(slot)).error
	return &"FIXTURE_NO_MOLE"


static func run_ticks(host: Node, first: int, last: int) -> int:
	"""`run_tick` for every tick in [first, last] while the entry runs; the next tick to run, or
	-tick on the first tick the settlement refuses."""
	var tick: int = first
	while tick <= last and host.underground_entry().is_running():
		if not host.run_tick(tick):
			return -tick
		tick += 1
	return tick
