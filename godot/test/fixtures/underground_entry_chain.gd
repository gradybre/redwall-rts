extends RefCounted
## Test fixture (ADR 1228): a generated settlement with its underground Session mounted, every owner
## composed and the first entry begun exactly as `test_underground_host.gd`'s live chain begins it,
## with 7 wood and 2 stone staged at R. Nothing here is a production path; it builds the state the
## save body must carry.

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
