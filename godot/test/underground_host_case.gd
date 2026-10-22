extends "res://test/framework/test_case.gd"
## Shared host fixture of the test_underground_host* suites: the actual settlement, the mounted Session and
## the live entry chain helpers. Not a suite (no test_ prefix); the three suites extend it so CI can run the
## longest live-chain tests on separate shards (decision 1243).

const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const EntrySite := preload("res://scripts/core/underground_entry_site.gd")
const EntryWorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const World := preload("res://scripts/core/world_init.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Economy := preload("res://scripts/systems/economy_system.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const RouteFixture := preload("res://test/test_underground_world_routes.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Recipes := preload("res://test/fixtures/checkpoint_recipes.gd")
const Store := preload("res://test/fixtures/checkpoint_store.gd")
## ADR1227 (G14): with Contacts' Region scans charged one check per slot plus the row's own checks per present row,
## T0's paid FUND fits its operation budget and the live chain runs the whole first-entry prefix: L0 installed, T0's
## six cuts settled, T0 installed. The foreman is then done; nothing past the prefix is planned (ADR1197 G9: the
## Kitchen's own cuts wait on Brendan's choice in ADR1208).
## The tick the uninterrupted live chain finishes the first-entry prefix on (T0 installed), asserted by both the plain
## and the restored chain. ADR1217 step 5: 4630 -> 4670 on the claw and paw rows (new motion timings: the claw walk's
## 44-key loop, the walk-on past the blocked fade keys, the 32-tick dig and tap loops); every Work amount, bill and
## hauled unit is unchanged (DEC-052). ADR1229 increment 6b: the chain then carries on down the descent; these
## suites stop at the prefix (PREFIX_INSTALLS), and one suite runs the whole flight to its last sill.
## DEC-059: 4670 -> 4382 with brace/cut/finish x 0.47 (P3) -> 3462 with one claw entry and recovery a cube (P2).
## Decision 2044 (M2): 3463, the tick T0's installation settles (the stage hand-over below).
const DONE_TICK: int = 3463
## [task index, cut Work mWU, hauled whole units, installation Work mWU, groups INSTALLED] at the end of the prefix:
## L0's twelve phases, T0's six cuts, both installations' fastening (32,000 + 12,000 mWU). Decision 2044: the index
## is the next stage's first task (0).
const DONE_LEDGER: Array = [0, 25380, 9, 44000, 2] # DEC-059: six cubes x 4,230
## ADR1229: the prefix is L0 and T0 installed. Decision 2044 (P-2044-7 (a)): the foreman plans one stage at a time
## (L0's, then T0's, then the next ones), so the prefix ends on the tick T0's installation settles and the runtime
## plans the next stage, not at a fixed task index.
const PREFIX_INSTALLS: int = 2
## ADR1229 increment 6b: the whole descent on the flexible schedule (every hour ANYTHING, GDD 5.3), from the same
## start: the eight descent cubes (33,840 mWU since DEC-059), T1-T6 down the stair (6 x 5,640 mWU, one hauled unit each).
## DEC-059: on the DEFAULT schedule since P2 (P3 12,474 and P1 10,484 were on the flexible one), 8348.
## Decision 2044 (the M2 interim, P-2044-15): the whole flight is two modules, fifteen groups and 34 cubes, and takes
## past the first work block and the cohort's means. The generated cohort has two adult moles and no kitchen (G9):
## near tick 12,000 both reach their GDD 5.2 seek thresholds, DEC-059's shift change finds no rested idle mole, and
## the crew waits at rest. So the whole-flight suites keep every resident's hunger and rest full and R's staged stock
## topped up (`_sustain`), stand-ins for the kitchen and stores the settlement does not have yet.
## Decision 2045 (M5): five modules, 36 groups, each landing's deep stage first; the flight finishes on tick 92,559
## (the committed underground_flight checkpoint's finish, test/fixtures/checkpoint_recipes.gd).
const DESCENT_DONE_TICK: int = 92559
## [task index, cut Work, hauled units, installation Work, groups INSTALLED] at the finish. Decision 2044 (M2) was
## [37, 143820, 36, 123680, 15]. Decision 2045 (M5, read from the flight's finish): the last stage's 37 tasks, 154
## cubes x 4,230, 117 hauled units and 261,200 mWU fastening 36 groups (L0 and five modules of T0..T6).
const DESCENT_LEDGER: Array = [37, 651420, 117, 261200, 36]
## The groups the prefix and module 0 install (L0, T0..T6).
const MODULE_ZERO_INSTALLS: int = 8
## ADR1221: the live chain's route owners are cold-restored this often (ticks; prime).
const ROUTE_RESTORE_EVERY: int = 23
## ADR1218 runtime wire: header, step, code, origin, section, endpoint count and the work area's endpoints (nineteen
## since ADR1229), then M's container.
const AT_RUNTIME_STORAGE: int = 12 + 4 + Progress.CODE_BYTES + 12 + 8 + 4 + EntryWorkArea.ENDPOINTS * 8
## ADR1219 walk ticks left, arrival yaw and H's anchor point follow M's and R's containers.
const AT_RUNTIME_WALK: int = AT_RUNTIME_STORAGE + 16

class ObservedGear extends Gear:
	var observer: Callable = Callable()

	func equipment_binding_matches(inventory: Inventory, directory: Directory, residents: Residents) -> bool:
		"""One real observation can attempt an adverse host reset during Session initialization."""
		var answer: bool = super.equipment_binding_matches(inventory, directory, residents)
		if observer.is_valid():
			var action: Callable = observer
			observer = Callable()
			action.call()
		return answer

class ObservedWorld extends World:
	var observer: Callable = Callable()

	func is_published() -> bool:
		"""Return the genuine published state and then run one adverse cold observation."""
		var answer: bool = super.is_published()
		if observer.is_valid():
			var action: Callable = observer
			observer = Callable()
			action.call()
		return answer


class ClearingHost extends Settlement:
	var recurse_on_clear: bool = false
	var partial_clear: bool = false
	var nested_reset: bool = true
	var nested_abandon: bool = true
	var clear_calls: int = 0

	func _clear_stores() -> void:
		"""Exercise the actual host tail, including a refusal after deliberately incomplete test clearing."""
		clear_calls += 1
		if recurse_on_clear:
			nested_reset = reset()
			nested_abandon = abandon_world_reset()
		if partial_clear:
			_residents.clear()
		else:
			super._clear_stores()


class SurfaceWorld extends World:
	var session: WeakRef = null
	var observer: Callable = Callable()
	var during_retention: bool = false
	var during_create: bool = false

	func is_published() -> bool:
		"""Observe the real result only at the selected actual anchor constructor or active publication boundary."""
		var answer: bool = super.is_published()
		var owner: Session = session.get_ref() as Session if session != null else null
		if owner == null or not observer.is_valid(): return answer
		var selected: bool = owner._operations_state == 1 and owner._operations_prefix == 8
		if during_retention: selected = selected and owner._retirement_owners.locations._in_retention
		if during_create:
			selected = owner._retirement_owners.surface_anchor != null and owner._retirement_owners.surface_anchor._busy
		if selected:
			var action: Callable = observer
			observer = Callable()
			action.call()
		return answer


class SurfaceHost extends Settlement:
	func _compose_ground_piles() -> void:
		"""Install a real negative-only observed World before its original host/stock owners bind it."""
		var original: World = _world
		_world = SurfaceWorld.new(original._directory, original._nodes, original._forage, original._fishing,
			original._rng, original._farming, original._orchards, original._jobs, original._commands)
		super._compose_ground_piles()


var _host: Settlement = null
var _content: Content = null
var _nested_reset: bool = true
var _saved_gear: Gear = null
var _surface_script: Script = null
var _surface_source_text: String = ""
var _checkpoint_loaded: bool = false


func before_each() -> void:
	"""Load the exact production image against a test-owned actual settlement."""
	_host = Settlement.new()
	_content = Content.new()
	assert_equal(_content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
		Session.PRESENTATION_BYTES), &"", "actual source")
	_nested_reset = true


func after_each() -> void:
	"""Free only this suite's host; its foundation has no externally bound authority."""
	if _host != null and _host.gear() is ObservedGear:
		(_host.gear() as ObservedGear).observer = Callable()
	if _host != null:
		if _host.world() is ObservedWorld:
			(_host.world() as ObservedWorld).observer = Callable()
		if _host.world() is SurfaceWorld:
			(_host.world() as SurfaceWorld).observer = Callable()
		_host.free()
	if _surface_script != null: _surface_script.source_code = _surface_source_text
	_surface_script = null
	_surface_source_text = ""
	_host = null
	_content = null
	_saved_gear = null
	if _checkpoint_loaded:
		_checkpoint_loaded = false
		assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _generate_and_mount() -> Session:
	"""Use the same generation and foundation entry points as the actual boot/demo."""
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual generated World")
	assert_true(_host.mount_underground(_content), "mount: %s" % _host.last_refusal())
	return _host.underground_session()


func _snapshot() -> Array[PackedByteArray]:
	"""Independent test snapshots cover the identity, economy, work and pose stores reset would erase."""
	return [_host.directory().state_bytes(), _host.inventory().state_bytes(),
		_host.residents().state_bytes(), _host.jobs().state_bytes(), _host.transforms().state_bytes(),
		_host.construction().state_bytes(), _host.reservations().state_bytes()]


func _prefix_done(entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""ADR1229: the foreman has finished the prefix (T0 installed) and moved on to the next stage."""
	return entry._foreman != null and _installed_groups(entry) >= PREFIX_INSTALLS \
		and entry._foreman.planned_installations() > PREFIX_INSTALLS


func _installed_groups(entry: Settlement.UndergroundEntryRuntime) -> int:
	"""Groups the entry's Placement has INSTALLED (DONE_LEDGER's last field)."""
	var placements: RefCounted = entry._foreman._owners.placements
	return placements._get32(placements._live, placements.INSTALLED, 0)


func _assert_prefix_done(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, worker: Vector2i) -> void:
	"""ADR1227: past G6, G12, G13 and G14. The crew hauled every unit, settled every L0 phase, installed L0, settled
	T0's six cut phases and installed T0, each group exactly once, with no refusal; ADR1229: the chain runs on into
	the descent. The crew stays the only route actor (ADR1219 section 4) and never held a tool (DEC-052)."""
	assert_true(entry.is_running(), "the chain runs on into the descent")
	assert_equal(entry.error(), &"", "with no refusal")
	var foreman: RefCounted = entry._foreman
	assert_true(not foreman.is_done() and foreman.error() == &"", "the descent is planned, no refusal: %s" % foreman.error())
	assert_equal(_done_ledger(o, foreman), DONE_LEDGER, "both installations and every cut with their exact Work, once")
	assert_equal(entry.crew().tool, Vector2i(-1, 0), "the claw crew has no tool")
	assert_equal(o.work.tool_lot_of(o.residents.directory().get_typed_row(worker)), Vector2i(-1, 0), "and claimed none")
	var actors: int = 0
	for row: int in Session.Retirement.Routes.RESIDENT_CAPACITY:
		if o.routes._resident_ref(row) != Session.Retirement.Routes.NULL_REF: actors += 1
	assert_equal(actors, 1, "only the crew mole is registered; every other resident stayed on the surface")


func _done_ledger(o: Session.Retirement.Owners, foreman: RefCounted) -> Array:
	"""[task index, cut Work, hauled units, installation Work, groups INSTALLED] (DONE_LEDGER's shape)."""
	return [foreman._index, foreman.accepted_mwu(), foreman.haul_trips(), foreman.install_mwu(),
		o.placements._get32(o.placements._live, o.placements.INSTALLED, 0)]


func _sustain(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, tick: int) -> void:
	"""Decision 2044: the whole-flight stand-ins (see DESCENT_DONE_TICK, `Chain.sustain`), run before each tick."""
	var code: StringName = Chain.sustain(o, entry._output, tick)
	if code != &"": assert_equal(code, &"", "the stand-ins before tick %d" % tick)


func _staged_milli(o: Session.Retirement.Owners, container: Vector2i, item: int) -> int:
	"""Unreserved milli of `item` in `container`."""
	var total: int = 0
	var lot: Vector2i = o.inventory.container_first_lot(container)
	while lot != Vector2i(-1, 0):
		if o.inventory.lot_item_id(lot) == item: total += o.inventory.lot_available_milli(lot)
		lot = o.inventory.container_next_lot(lot)
	return total


func _stage(o: Session.Retirement.Owners, container: Vector2i, key: StringName, milli: int) -> Vector2i:
	"""Surface stock staged at R's real ground-staging container (ADR1197 G4, ADR1203 shared with spoil)."""
	var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(key), milli, 1, 0, -1, 0, 0)
	assert_true(lot.ok, "staged %s: %s" % [key, lot.error])
	return lot.ref


func _eligible_moles(o: Session.Retirement.Owners) -> Array[Vector2i]:
	"""Every living adult mole holding no Job and no tool, by resident slot: the runtime's crew order (DEC-052)."""
	return Chain.eligible_moles(o)


func _first_mole(o: Session.Retirement.Owners) -> Vector2i:
	"""The mole the runtime will choose as the crew."""
	var found: Array[Vector2i] = _eligible_moles(o)
	assert_false(found.is_empty(), "the starting cohort has an idle adult mole")
	return found[0] if not found.is_empty() else Vector2i(-1, 0)


func _bench_moles(o: Session.Retirement.Owners, container: Vector2i, keep: Array[Vector2i]) -> Array[Vector2i]:
	"""Equip a real basic tool on every eligible mole outside `keep`: DEC-052's claw rows take no tool, so the runtime
	passes a tooled mole over. Returns the benched moles, in crew order."""
	var benched: Array[Vector2i] = []
	for mole: Vector2i in _eligible_moles(o):
		if mole in keep: continue
		var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(&"tool"), 1000, 1, 0, -1, 0, 0)
		assert_true(lot.ok and o.gear.create_gear(o.inventory, o.items, lot.ref, o.gear.MANUFACTURE_BASIC).ok, "basic tool")
		assert_true(o.gear.equip(lot.ref, mole).ok, "the mole is benched by its tool")
		benched.append(mole)
	return benched


func _begin_live_entry(configure: Callable = Callable()) -> Array:
	"""[owners, runtime, crew worker] of a live chain begun with the G4 staged-stock stand-in (no tool: DEC-052);
	`configure(owners, worker)` runs on the crew before the entry begins."""
	_generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")
	var near: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	var worker: Vector2i = _first_mole(o)
	if configure.is_valid(): configure.call(o, worker)
	assert_true(_host.begin_underground_entry(near), "foreman planned and the walk begun: %s" % _host.last_refusal())
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	_stage(o, entry._output, &"wood", 7000)
	_stage(o, entry._output, &"stone", 2000)
	return [o, entry, worker]


func _run_until(entry: Settlement.UndergroundEntryRuntime, from: int, done: Callable) -> int:
	"""run_tick from `from` until `done.call()` holds or the chain stops; returns the next tick to run."""
	var tick: int = from
	while entry.is_running() and not done.call() and tick < 8000:
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	return tick


func _kill(o: Session.Retirement.Owners, worker: Vector2i) -> void:
	"""The crew dies (health to zero)."""
	assert_true(o.residents.needs().apply_health_event(o.residents.directory().get_typed_row(worker), -100).ok, "dies")


func _live_with_spare() -> Array:
	"""[owners, runtime, crew, spare mole] of a live chain with exactly two eligible moles: the first is the crew, the
	second the replacement; every other mole is benched by a tool (DEC-052: the claw rows take none)."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var others: Array[Vector2i] = _eligible_moles(o)
	others.erase(live[2])
	assert_false(others.is_empty(), "the starting cohort has two adult moles")
	if others.is_empty(): return [o, entry, live[2], Vector2i(-1, 0)]
	_bench_moles(o, entry._output, [live[2], others[0]])
	return [o, entry, entry.crew().worker, others[0]]


func _spare_from_checkpoint(point: String) -> Array:
	"""[owners, runtime, crew, spare, next tick to run] of `_live_with_spare()`'s chain at `point` of the committed
	`underground_spare` checkpoint (decision 1895; test_checkpoint_equivalence.gd proves it equals the replay from
	tick 1), or [] when it did not load."""
	_checkpoint_loaded = true
	var refusal: String = Store.load_into(_host, GameManager, Recipes.SPARE, point, _content)
	assert_equal(refusal, "", "the underground_spare %s checkpoint loads" % point)
	if refusal != "": return []
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var spare: Vector2i = Chain.spare_of(_host)
	assert_true(spare != Vector2i(-1, 0), "exactly one spare mole besides the crew")
	return [_host.underground_session()._retirement_owners, entry, entry.crew().worker, spare,
		GameManager.clock().completed_tick() + 1]


func _replace_entry_with_its_record(session: Session, tick: int) -> bool:
	"""Capture the host's entry runtime and swap in a fresh runtime restored from that record."""
	var bytes: PackedByteArray = PackedByteArray()
	var fresh: Settlement.UndergroundEntryRuntime = Settlement.UndergroundEntryRuntime.new()
	var code: StringName = _host.underground_entry().capture(bytes)
	if code == &"": code = fresh.restore(bytes, session)
	if code != &"":
		assert_equal(code, &"", "round trip before tick %d" % tick)
		return false
	_host._underground_entry = fresh
	return true


func _first_trip_done(entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""The foreman's haul has delivered its first whole unit."""
	return entry._foreman._hauler != null and entry._foreman._hauler.trips() == 1


func _finished_entry() -> Array:
	"""[owners, runtime, crew worker, its resident row, next tick] of the live entry at its finishing tick: the committed
	underground_flight checkpoint's finish (decision 2045: test_underground_flight_<k>.gd prove every point of it equals
	the sustained flight replayed from tick 0), or [] when it did not load."""
	_checkpoint_loaded = true
	var refusal: String = Store.load_into(_host, GameManager, Recipes.FLIGHT, Recipes.FINISH_POINT, _content)
	assert_equal(refusal, "", "the underground_flight finish checkpoint loads")
	if refusal != "": return []
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var worker: Vector2i = entry.crew().worker
	assert_equal(GameManager.clock().completed_tick(), DESCENT_DONE_TICK, "the entry finished on its own tick")
	return [o, entry, worker, o.residents.directory().get_typed_row(worker), GameManager.clock().completed_tick() + 1]


func _pose(o: Session.Retirement.Owners, worker: Vector2i) -> Transforms.Pose:
	"""The resident's current Transform."""
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(o.transforms.read_into(worker, pose), "the crew has a Transform")
	return pose


func _cold_restore_routes(o: Session.Retirement.Owners, tick: int) -> bool:
	"""ADR1221: the Session's Routes, WorldRoutes, Contacts, Delivery, arena and the host Planner captured, blanked
	as a fresh Session's and cold-restored."""
	var code: StringName = RouteFixture.cold_restore_route_owners(o.routes, o.world_routes, o.space, o.budget)
	assert_equal(code, &"", "route owners cold-restore before tick %d" % tick)
	if code == &"":
		code = o.connector.save_quiescence_refusal()
		assert_equal(code, &"", "ConnectorWork quiescent before tick %d" % tick)
	if code == &"":
		code = RouteFixture.cold_restore_entry_owners(o.contacts, o.delivery, o.budget)
		assert_equal(code, &"", "Contacts, Delivery, arena and Planner cold-restore before tick %d" % tick)
	return code == &""
