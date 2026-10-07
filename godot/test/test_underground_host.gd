extends "res://test/framework/test_case.gd"
## Actual host-lifetime tests; no phase, stock, contact, or route permission is supplied by a fixture.

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
var _surface_tick: bool = true
var _surface_script: Script = null
var _surface_source_text: String = ""


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


func test_mount_requires_actual_world_and_refused_attempt_can_retry() -> void:
	"""An empty host receives neither a fabricated World nor a partially retained Session."""
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.mount_underground(_content), "missing World refuses")
	assert_equal(_host.underground_session(), null, "failed candidate released")
	assert_equal(_snapshot(), before, "all stores preserved")
	var session: Session = _generate_and_mount()
	assert_equal(session.current_refusal(), &"", "subsequent actual World works")


func test_mount_borrows_actual_owners_and_duplicate_preserves_foundation() -> void:
	"""Mounting changes no identity/economic bytes and never allocates a replacement live foundation."""
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual World")
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(_host.mount_underground(_content), "mount")
	var session: Session = _host.underground_session()
	assert_equal(session._world, _host.world(), "same World")
	assert_equal(session._gear, _host.gear(), "same Gear")
	assert_equal(session._carry, _host.haul_carry(), "same Carry")
	assert_equal(_snapshot(), before, "no store mutation")
	assert_false(_host.mount_underground(_content), "duplicate refuses")
	assert_equal(_host.underground_session(), session, "original foundation retained")
	assert_equal(_snapshot(), before, "duplicate also preserves stores")


func test_host_retains_one_actual_haul_planner_and_policy_without_new_stock_or_jobs() -> void:
	"""The existing finite modules bind once during Host construction, before any generated World exists."""
	assert_equal(_host._haul_owners_refusal(), &"", "exact original actual links")
	assert_equal(_host._haul_planner._inventory, _host.inventory(), "one Inventory")
	assert_equal(_host._haul_planner._store_policy, _host._store_policy, "one original Policy")
	assert_equal(_host._store_policy._directory, _host.directory(), "one full identity directory")
	assert_equal(_host._haul_planner.record_bytes(), 196608, "unchanged finite record bank")
	assert_equal(_host._store_policy.ledger_bytes(), 2363392, "unchanged policy columns")
	assert_equal(_host.inventory().live_lot_count(), 0, "constructor creates no lot")
	assert_equal(_host.jobs().job_count(), 0, "constructor admits no Job")
	assert_equal(_host.directory().live_count(Directory.KIND_WORLD), 0, "constructor invents no World")
	var planner: Settlement.HaulPlannerScript = _host._haul_planner
	var policy: Settlement.StorePolicyScript = _host._store_policy
	_generate_and_mount()
	assert_equal(_host._haul_planner, planner, "generation reuses original planner")
	assert_equal(_host._store_policy, policy, "generation reuses original policy")
	assert_true(_host.reset(), "actual whole World clear")
	assert_equal(_host._haul_planner, planner, "reset does not replace planner")
	assert_equal(_host._store_policy, policy, "reset does not replace policy")
	assert_equal(_host._haul_owners_refusal(), &"", "links survive canonical clearing")


func test_wrong_haul_collaborator_refuses_reset_before_any_original_store_is_cleared() -> void:
	"""A foreign same-script store cannot be silently adopted by either mounted or foundationless clearing."""
	_generate_and_mount()
	var before: Array[PackedByteArray] = _snapshot()
	var original: Settlement.StorePolicyScript = _host._store_policy
	_host._store_policy = Settlement.StorePolicyScript.new(_host.buildings(), _host.inventory())
	assert_false(_host.reset(), "different original Policy field refuses")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_HOST_HAUL_OWNER", "exact link mismatch")
	assert_equal(_snapshot(), before, "no canonical clear happened")
	_host._store_policy = original
	assert_true(_host.reset(), "restored original can retire")
	_host._haul_planner._store_policy = null
	assert_false(_host.reset(), "no Session does not bypass original haul binding")
	_host._haul_planner._store_policy = original
	assert_true(_host.reset(), "foundationless original reset remains supported")


func _ordinary_haul_source() -> Vector2i:
	"""Find actual starter wood, which can transfer between the real material stores."""
	for row: int in _host.inventory()._l_capacity:
		var lot: Vector2i = _host.inventory()._lot_ref_of(row)
		if not _host.inventory().is_lot_valid(lot) or _host.inventory().is_lot_equipped(lot): continue
		if _host.inventory().lot_item_id(lot) != _host.item_definitions().compiled_id(&"wood"): continue
		var container: Vector2i = _host.inventory().lot_container(lot)
		if not _host.inventory().is_satchel(container) \
				and _host.inventory().lot_available_milli(lot) >= 1000:
			return lot
	return Inventory.NULL_REF


func _seed_host_stock() -> void:
	"""Use the real boot Economy entry point and original generated colony; release only the test-owned Node."""
	var economy: Economy = Economy.new()
	var binding: Settlement.StarterColonyScript.StoreBinding = Settlement.StarterColonyScript.StoreBinding.new()
	assert_true(economy.bind_inventory(_host.inventory()), "original actual Inventory")
	assert_true(_host.starter_store_binding_into(binding), "actual generated colony binding")
	assert_true(economy.open_and_seed_starter_stores(binding), "actual GDD starter stock")
	economy.free()


func test_actual_settled_haul_and_policy_rows_clear_on_reset_without_reallocating() -> void:
	"""Real planner admission and policy writes retire with the same canonical stocks and reservation pool."""
	_generate_and_mount()
	_seed_host_stock()
	var planner: Settlement.HaulPlannerScript = _host._haul_planner
	var policy: Settlement.StorePolicyScript = _host._store_policy
	var lot: Vector2i = _ordinary_haul_source()
	assert_true(lot != Inventory.NULL_REF, "actual starter stock exists")
	var job: Settlement.JobsScript.OpResult = _host.jobs().create_job(Catalog.JOB_KIND.HAUL, 1, 0, 2000, 0)
	assert_true(job.ok, "actual Job allocated")
	var admitted: Inventory.OpResult = planner.admit(job.ref, _host._live_slots[0], lot, 1000, 300)
	assert_true(admitted.ok, "real ordinary haul admission: %s" % admitted.error)
	assert_true(planner.is_admitted(job.ref), "actual retained planning record")
	var building: Vector2i = _host.buildings().building_ref_of_row(0)
	var item: int = _host.inventory().lot_item_id(lot)
	assert_equal(policy.set_allowed(building, item, policy.DISALLOWED), &"", "actual policy allow write")
	assert_equal(policy.set_minimum(building, item, 1000), &"", "actual minimum write")
	assert_true(_host.reset(), "canonical reset of populated planning state")
	assert_equal(_host._haul_planner, planner, "planner object reused")
	assert_equal(_host._store_policy, policy, "policy object reused")
	assert_false(planner.is_admitted(job.ref), "old Job record retired")
	assert_equal(policy._allowed.count(policy.DISALLOWED), 0, "all filters restored")
	assert_equal(policy._minimum_milli.count(0), policy.POLICY_CELLS, "all minimums cleared")
	assert_equal(policy._bound_persistent_id.count(0), policy.BUILDING_CAPACITY, "no stale World stamp")
	assert_equal(planner.record_bytes(), 196608, "same record capacity")
	assert_equal(policy.ledger_bytes(), 2363392, "same policy capacity")


func test_held_arena_refuses_reset_before_any_store_is_cleared() -> void:
	"""A synchronous operation keeps its actual token and all gameplay state across refusal."""
	var session: Session = _generate_and_mount()
	var token: int = session._budget.acquire(64)
	assert_true(token > 0, "actual owned lease")
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(), "busy reset refuses")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_SESSION_NOT_QUIESCENT", "exact refusal")
	assert_equal(_snapshot(), before, "reset erased no store")
	assert_equal(_host.underground_session(), session, "same host lifetime")
	assert_true(session._budget.covers(token, 64), "same lease")
	assert_equal(session._budget.release(token), &"", "release this test's lease")
	assert_true(_host.reset(), "quiescent retry")


func test_prepared_space_refuses_reset_and_keeps_original_candidate() -> void:
	"""A live preparation cannot be mistaken for a quiescent foundation."""
	var session: Session = _generate_and_mount()
	var staged: Owner.Result = session._space.begin_stage(session._space.revision())
	assert_equal(staged.error, &"", "actual prepared candidate")
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(), "prepared state refuses")
	assert_equal(_snapshot(), before, "all stores retained")
	assert_equal(session._space._stage_token, staged.token, "original stage retained")
	assert_true(session._space.abort(staged.token), "abort only own candidate")
	assert_true(_host.reset(), "quiescent retry")


func test_reset_retires_borrowers_and_regeneration_gets_fresh_full_identity() -> void:
	"""A retained old Session cannot observe the new World or silently become its foundation."""
	var old: Session = _generate_and_mount()
	var original_world: Vector2i = _host.world_ref()
	var gear: Gear = _host.gear()
	assert_true(_host.reset(), "retirement then store reset")
	assert_equal(_host.underground_session(), null, "host released old foundation")
	assert_equal(old.current_refusal(), &"UNDERGROUND_SESSION_UNAVAILABLE", "old Session retired")
	assert_equal(old.space_owner(), null, "no stale foundation exposure")
	assert_equal(old.retire_foundation(), &"", "already retired is harmless")
	assert_false(_host.directory().is_valid(original_world), "old full identity invalid")
	var fresh: Session = _generate_and_mount()
	assert_true(fresh != old, "new foundation")
	assert_true(_host.world_ref() != original_world, "new generation")
	assert_equal(_host.gear(), gear, "host service is not duplicated")
	assert_equal(_host.gear().active_gear_count(), 0, "mount is not a stock producer")


func _reset_during_initialization() -> void:
	"""Negative observation exercises the public host boundary while the original Session is busy."""
	_nested_reset = _host.reset()


func test_reentrant_reset_during_mount_preserves_stores_and_refuses_outer_attempt() -> void:
	"""The candidate is host-visible before the real Profile binding observes actual Gear."""
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual World")
	var gear: ObservedGear = ObservedGear.new()
	assert_true(gear.bind_equipment(_host.inventory(), _host.directory(), _host.residents()).ok, "real gear binding")
	assert_true(_host.work().bind_gear(gear).ok, "actual Work binding")
	_host._gear = gear # Negative fixture changes the concrete host Gear before mount, never a permission stub.
	gear.observer = _reset_during_initialization
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.mount_underground(_content), "outer mount refuses poisoned initialization")
	assert_false(_nested_reset, "nested reset refused")
	assert_equal(_snapshot(), before, "all stores preserved")
	assert_equal(_host.underground_session(), null, "failed candidate released")
	assert_true(_host.mount_underground(_content), "unpoisoned retry succeeds")


func _stage_replacement() -> void:
	"""Stage a real replacement in the existing generator with the UI's explicit caller-cleared kinds."""
	_host.world().declare_externally_cleared(PackedInt32Array([Directory.KIND_RESIDENT,
		Directory.KIND_BUILDING, Directory.KIND_ROOM, Directory.KIND_FURNITURE,
		Directory.KIND_WORLD, Directory.KIND_CONSTRUCTION]))
	var request: World.RequestResult = World.bound_request(_host.item_definitions(), World.TUTORIAL_WORLD_SEED + 1)
	assert_true(request.ok, "actual catalog request")
	assert_true(_host.world().preflight(request.request).ok, "existing staged bank prepares replacement")


func test_prepared_world_remains_unavailable_except_for_explicit_retirement() -> void:
	"""The retirement-only allowance does not grant current movement/work or discard a staged plan."""
	var session: Session = _generate_and_mount()
	_stage_replacement()
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(session.current_refusal() != &"", "prepared World grants no ordinary permission")
	assert_false(_host.reset(), "ordinary reset keeps its strict World gate")
	assert_equal(_snapshot(), before, "refusal clears no store")
	assert_true(_host.world().has_prepared_plan(), "original replacement plan retained")
	assert_true(_host.reset(true), "explicit whole-World replacement retires old foundation")
	assert_true(_host.world().has_prepared_plan(), "existing banks preserve the ruled preflight/reset/seed sequence")
	assert_equal(session.current_refusal(), &"UNDERGROUND_SESSION_UNAVAILABLE", "old Session cannot be used")
	_host.world().discard_prepared_plan()


func test_retirement_allowance_still_checks_original_live_seed() -> void:
	"""A staged replacement does not permit an already changed live World to impersonate the old one."""
	var session: Session = _generate_and_mount()
	_stage_replacement()
	var published_seed: int = _host.world()._published_seed
	_host.world()._published_seed = published_seed + 1 # Explicit adverse fixture changes live source identity.
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(true), "different live seed refuses even explicit retirement")
	assert_equal(_snapshot(), before, "no store cleared")
	assert_equal(_host.underground_session(), session, "old foundation remains owned")
	_host.world()._published_seed = published_seed
	_host.world().discard_prepared_plan()
	assert_true(_host.reset(), "restore only the fixture's tamper and retire normally")


func test_prepare_keeps_populated_stores_and_stops_all_fresh_access() -> void:
	"""A private Scope retains the real mounted foundation without clearing its original population or colony."""
	var session: Session = _generate_and_mount()
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(_host.prepare_world_reset(), "original host prepare")
	assert_equal(_snapshot(), before, "prepare clears nothing")
	assert_true(session._retirement_scope != null, "private original scope")
	assert_equal(session.current_refusal(), &"UNDERGROUND_SESSION_RETIRING", "ordinary read stopped")
	assert_equal(session.space_owner(), null, "fresh Space borrow stopped")
	assert_equal(session.profile_catalog(), null, "fresh Profile borrow stopped")
	assert_equal(_host.underground_session(), null, "host exposes no new borrowed Session")
	assert_equal(_host.underground_content(), null, "content borrow stopped")
	assert_false(_host.run_tick(1), "fixed tick stopped")
	assert_false(_host.run_day_boundary(1, 0), "daily dispatch stopped")
	assert_false(_host.create_initial_settlement(), "cohort admission stopped")
	assert_false(_host.materialize_starter_colony(), "colony admission stopped")
	assert_false(_host.request_demolition(Vector2i(-1, 0)).ok, "project admission stopped")
	assert_equal(_snapshot(), before, "all blocked calls preserve authoritative stores")
	assert_true(_host.abandon_world_reset(), "unchanged live tuple may resume")
	assert_equal(session.current_refusal(), &"", "ordinary source observation restored")


func test_repeated_prepare_reuses_scope_then_actual_reset_breaks_cycle() -> void:
	"""Main/UI repeated preflight retains one snapshot and releases it before the old Session can die."""
	var session: Session = _generate_and_mount()
	assert_true(_host.prepare_world_reset(), "first")
	var scope_life: WeakRef = weakref(session._retirement_scope)
	assert_true(_host.prepare_world_reset(), "repeated same original tuple")
	assert_equal(session._retirement_scope, scope_life.get_ref(), "same exact scope")
	assert_true(_host.reset(), "actual complete clear and static release")
	assert_equal(scope_life.get_ref(), null, "private scope cycle broken")
	assert_equal(session._retirement_owners, null, "permanent packet released only after tail")
	assert_equal(_host._underground_reset_phase, 0, "stop ended after full release")
	assert_equal(_host.directory()._live_count, 0, "actual World and complete directory cleared")
	assert_equal(session._world, null, "old borrowed World dropped")
	assert_true(_generate_and_mount() != session, "new World mounts a new foundation")


func test_abandon_drops_only_scope_and_keeps_original_owners() -> void:
	"""A refused UI action can resume its original live host only before any clear has started."""
	var session: Session = _generate_and_mount()
	var owners: Session.Retirement.Owners = session._retirement_owners
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(_host.prepare_world_reset(), "prepare")
	var scope_life: WeakRef = weakref(session._retirement_scope)
	assert_true(_host.abandon_world_reset(), "original live abandon")
	assert_equal(scope_life.get_ref(), null, "no self-retaining scope")
	assert_equal(session._retirement_owners, owners, "same permanent packet")
	assert_equal(_snapshot(), before, "no authority or store mutation")
	assert_equal(_host.underground_session(), session, "original session available")
	assert_true(_host.abandon_world_reset(), "already idle is harmless")
	assert_true(_host.reset(), "later independent reset succeeds")


func _replace_host_gear_after_observation() -> void:
	"""Only the host alias changes: Session's old actual Gear still passes its own internal source reads."""
	_saved_gear = _host._gear
	_host._gear = Gear.new()


func _use_observed_world() -> ObservedWorld:
	"""Construct the same real generator over all existing host stores; no source success override."""
	var previous: World = _host.world()
	var actual: ObservedWorld = ObservedWorld.new(previous._directory, previous._nodes, previous._forage,
		previous._fishing, previous._rng, previous._farming, previous._orchards, previous._jobs, previous._commands)
	_host._world = actual
	return actual


func test_late_cold_observer_cannot_substitute_mounted_host_owner() -> void:
	"""The final mount leaf runs after real Terrain's observed World getter, before Scope publication."""
	var actual: ObservedWorld = _use_observed_world()
	var session: Session = _generate_and_mount()
	actual.observer = _replace_host_gear_after_observation
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.prepare_world_reset(), "late host owner mutation refuses")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_HOST_OWNER", "exact mounted-owner proof")
	assert_equal(session._retirement_scope, null, "no scope published after failed mount leaf")
	assert_equal(_host._underground_reset_phase, 0, "failed pre-clear attempt restored stop")
	assert_equal(_snapshot(), before, "no actual store cleared")
	_host._gear = _saved_gear # Restore only this test's deliberate alias mutation.
	assert_true(_host.reset(), "restored actual mount retires normally")


func test_unowned_authority_is_not_adopted_by_host_retirement() -> void:
	"""The private operational slots remain null; equal external weak bindings cannot register themselves."""
	var session: Session = _generate_and_mount()
	var outside: RefCounted = RefCounted.new()
	_host.buildings()._spatial_authority = weakref(outside) # Explicit negative foreign binding.
	var original: WeakRef = _host.buildings()._spatial_authority
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(), "foreign operational mount refuses")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_SESSION_AUTHORITY_LIFETIME", "no public adoption")
	assert_equal(_host.buildings()._spatial_authority, original, "original weak identity preserved")
	assert_equal(session._retirement_scope, null, "no pending scope")
	assert_equal(_snapshot(), before, "all existing stores retained")


func test_original_packet_or_owner_mutation_refuses_repeated_prepare() -> void:
	"""Private source pins do not silently become a fresh snapshot during boot's second prepare."""
	var session: Session = _generate_and_mount()
	assert_true(_host.prepare_world_reset(), "original")
	var scope: Session.Retirement.Scope = session._retirement_scope
	var original: Session.Retirement.Owners = session._retirement_owners
	var before: Array[PackedByteArray] = _snapshot()
	original.world_ref.y += 1 # Deliberate packet mutation, not an alternative authority API.
	assert_false(_host.prepare_world_reset(), "mutated full World refuses")
	assert_equal(session._retirement_scope, scope, "original snapshot remains")
	assert_false(_host.abandon_world_reset(), "cannot resume mutated identity")
	assert_equal(_snapshot(), before, "no store writes")
	original.world_ref.y -= 1
	assert_true(_host.abandon_world_reset(), "restored exact original can abandon")


func test_recursive_clear_refuses_without_clearing_twice() -> void:
	"""Clearing is distinct from repeated preparation, including before the first store clear."""
	_host.free()
	var actual: ClearingHost = ClearingHost.new()
	_host = actual
	_generate_and_mount()
	var previous: int = actual.clear_calls
	actual.recurse_on_clear = true
	assert_true(_host.reset(), "outer actual reset")
	assert_false(actual.nested_reset, "recursive reset refused")
	assert_false(actual.nested_abandon, "clear cannot be abandoned")
	assert_equal(actual.clear_calls, previous + 1, "exactly one clear tail")
	assert_equal(_host._underground_reset_phase, 0, "outer completed normally")


func test_partial_clear_cannot_resume_and_host_destruction_breaks_scope_cycle() -> void:
	"""A deliberately failed test clear cannot report rollback or reopen dispatch; destruction releases only references."""
	_host.free()
	var actual: ClearingHost = ClearingHost.new()
	_host = actual
	var session: Session = _generate_and_mount()
	actual.partial_clear = true
	assert_false(_host.reset(), "incomplete clear fails original empty-store proof")
	assert_equal(_host._underground_reset_phase, 3, "host remains stopped")
	assert_false(_host.abandon_world_reset(), "no rollback claimed")
	assert_false(_host.run_tick(1), "no tick on partially cleared stores")
	assert_false(_host.reset(), "no second clear")
	var scope_life: WeakRef = weakref(session._retirement_scope)
	_host.free()
	_host = null
	assert_equal(scope_life.get_ref(), null, "host PREDELETE breaks private Scope cycle")
	assert_equal(session.current_refusal(), &"UNDERGROUND_SESSION_UNAVAILABLE", "destruction grants no resume")


func test_settled_space_receipt_is_retired_with_its_complete_world() -> void:
	"""Whole-World retirement permits a completed metadata transaction, unlike the legacy early-drop API."""
	var session: Session = _generate_and_mount()
	var stage: Owner.Result = session._space.begin_stage(session._space.revision())
	assert_equal(stage.error, &"", "actual metadata stage")
	assert_equal(session._space.seal(stage.token), &"", "actual seal")
	session._space.publish(stage.token)
	assert_equal(session.retire_foundation(), &"UNDERGROUND_SESSION_NOT_QUIESCENT", "legacy early drop stays narrow")
	assert_true(_host.reset(), "complete actual host clear retires original source")
	assert_equal(session.current_refusal(), &"UNDERGROUND_SESSION_UNAVAILABLE", "old receipt has no live owner")


func test_reentrant_prepare_observer_cannot_clear_or_publish_a_scope() -> void:
	"""The host stop is set before the cold World observer, so a nested reset poisons the outer read."""
	var actual: ObservedWorld = _use_observed_world()
	var session: Session = _generate_and_mount()
	actual.observer = _reset_during_initialization
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.prepare_world_reset(), "outer observed prepare refuses")
	assert_false(_nested_reset, "nested reset stopped before any clear")
	assert_equal(session._retirement_scope, null, "no partial scope")
	assert_equal(_host._underground_reset_phase, 0, "pre-clear refusal returns idle")
	assert_equal(_snapshot(), before, "all authoritative bytes retained")
	assert_true(_host.reset(), "later unpoisoned attempt may complete")


func test_open_inventory_journal_refuses_host_reset_unchanged() -> void:
	"""Actual transaction ownership remains with Inventory across refused host retirement."""
	var session: Session = _generate_and_mount()
	assert_true(_host.inventory().begin().ok, "actual journal")
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(), "busy owner refuses")
	assert_equal(_snapshot(), before, "no host clear or implicit abort")
	assert_true(_host.inventory()._tx_open, "same journal still open")
	assert_equal(session._retirement_scope, null, "no retained failed candidate")
	_host.inventory().abort()
	assert_true(_host.reset(), "original owner completed its transaction")


func test_staged_world_scope_can_abandon_only_its_original_request() -> void:
	"""UI cleanup must abandon before discarding its exact preflighted request."""
	var session: Session = _generate_and_mount()
	_stage_replacement()
	assert_true(_host.prepare_world_reset(true), "explicit old-world retirement")
	assert_true(_host.prepare_world_reset(true), "same staged request repeats")
	var original: World.Request = _host.world()._prepared_request
	var replacement: World.RequestResult = World.bound_request(_host.item_definitions(), original.world_seed)
	_host.world()._prepared_request = replacement.request # Equal values are not the captured request identity.
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.abandon_world_reset(), "substituted request cannot reopen host")
	assert_equal(_host._underground_reset_phase, 2, "original Scope remains stopped")
	assert_equal(_snapshot(), before, "no store mutation on refusal")
	_host.world()._prepared_request = original
	assert_true(_host.abandon_world_reset(), "original-live cleanup first")
	_host.world().discard_prepared_plan()
	assert_equal(session.current_refusal(), &"", "ordinary source resumes after separate plan discard")
	assert_true(_host.reset(), "normal later reset succeeds")


func test_pending_scope_rejects_replaced_profile_bank_before_clear() -> void:
	"""The host's second prepare never rebinds a current-looking source owner to a different bank."""
	var session: Session = _generate_and_mount()
	assert_true(_host.prepare_world_reset(), "original source")
	var original: Session.Profiles.Bank = session._profiles._live
	session._profiles._live = Session.Profiles.Bank.new() # Deliberate rejected immutable source replacement.
	var before: Array[PackedByteArray] = _snapshot()
	assert_false(_host.reset(), "replacement profile bank refuses before clear")
	assert_false(_host.abandon_world_reset(), "replacement source cannot resume original World")
	assert_equal(_snapshot(), before, "every paid/store byte preserved")
	session._profiles._live = original
	assert_true(_host.abandon_world_reset(), "restored exact source can resume")
	assert_true(_host.reset(), "restored actual source retires")


func _surface_session() -> Session:
	"""Compose the actual current source and maximum real graph before any natural endpoint is requested."""
	_host.free()
	_host = SurfaceHost.new()
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual route owners: %s" % _host.last_refusal())
	(_host.world() as SurfaceWorld).session = weakref(session)
	return session


func _surface_create(anchor: Session.Retirement.SurfaceAnchor) -> Session.Retirement.SurfaceAnchor.Result:
	"""Find genuine unobstructed generated ground with a bounded physical fixture; no actor/profile permit is inferred."""
	var result: Session.Retirement.SurfaceAnchor.Result = null
	for offset: int in 16:
		var x: int = (60 + offset) * 2048 + 512
		var z: int = 50 * 2048 + 512
		result = anchor.create(Vector3i(x, 512, z),
			PackedInt32Array([x - 256, 512, z - 256, x + 256, 2048, z + 256]),
			PackedInt32Array([x - 256, 384, z - 256, x + 256, 512, z + 256]))
		if result.error == &"": return result
	return result


func test_actual_surface_owner_is_strong_original_idempotent_and_does_not_publish_on_bind() -> void:
	"""One actual WorldScope survives local borrows without allocating an endpoint or changing gameplay stores."""
	var session: Session = _surface_session()
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(_host.compose_underground_surface_anchor(), "actual anchor: %s" % _host.last_refusal())
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	assert_true(anchor != null, "checked actual publisher")
	if anchor == null: return
	assert_equal(session._operations_prefix, 9, "exact anchor stage")
	assert_equal(session.location_owner()._world_scope.get_ref(), anchor, "original one-way weak backlink")
	assert_equal(session.location_owner()._live.count, 0, "binding does not fabricate access")
	assert_equal(session._space._r_present.count(1), 0, "no fabricated void or footing")
	var weak: WeakRef = weakref(anchor)
	anchor = null
	assert_true(weak.get_ref() != null, "permanent Owners retains anchor")
	assert_true(_host.compose_underground_surface_anchor(), "same exact scope is idempotent")
	assert_equal(session.surface_anchor(), weak.get_ref(), "no replacement")
	assert_true(session.world_route_provider() != null, "existing route borrow preserved")
	assert_equal(_snapshot(), before, "all gameplay bytes unchanged")


func test_actual_entry_owners_compose_from_the_fixed_bundle_without_gameplay_change() -> void:
	"""ADR1195: the mounted Session reaches prefix 17 with every entry owner, and no endpoint, Job or payment."""
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual route owners: %s" % _host.last_refusal())
	assert_true(_host.compose_underground_surface_anchor(), "actual anchor: %s" % _host.last_refusal())
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(_host.compose_underground_entry_owners(), "actual entry owners: %s" % _host.last_refusal())
	assert_equal(session._operations_prefix, 17, "complete fixed entry prefix")
	assert_equal(session._operations_state, 2, "Session remains operational")
	var o: Session.Retirement.Owners = session._retirement_owners
	for owner: RefCounted in [o.placements, o.contacts, o.connector, o.workpieces, o.delivery]:
		assert_true(owner != null, "retained entry owner")
	assert_equal(o.locations._live.count, 0, "composition grants no endpoint")
	assert_true(session.surface_anchor() != null, "surface publisher still borrowable after entry composition")
	assert_true(session.location_owner() != null, "Location namespace still borrowable")
	assert_true(session.world_route_provider() != null, "route provider still borrowable")
	assert_equal(_snapshot(), before, "all gameplay bytes unchanged")
	assert_true(_host.compose_underground_entry_owners(), "completed composition is idempotent: %s" % _host.last_refusal())
	assert_equal(session._operations_prefix, 17, "no second construction")


func test_suggested_entry_site_publishes_the_whole_work_area_on_generated_ground() -> void:
	"""ADR1197 G1/G2: the read-only survey predicts real publication of all eleven endpoints and 31 paths."""
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual route owners: %s" % _host.last_refusal())
	assert_true(_host.compose_underground_surface_anchor(), "actual anchor: %s" % _host.last_refusal())
	assert_true(_host.compose_underground_entry_owners(), "actual entry owners: %s" % _host.last_refusal())
	var o: Session.Retirement.Owners = session._retirement_owners
	var frontier: RefCounted = o.room_bindings._entry_frontier
	var origin: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var before: Array[PackedByteArray] = _snapshot()
	assert_equal(EntrySite.suggest(session._terrain, frontier, o.space.revision(),
		Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512), 8, origin), &"", "a surveyed origin on generated ground")
	assert_equal(_snapshot(), before, "survey and suggestion are read-only")
	var at: Vector3i = Vector3i(origin[0], origin[1], origin[2])
	var published: EntryWorkArea.Published = EntryWorkArea.Published.new()
	assert_equal(EntryWorkArea.publish_locations(session.surface_anchor(), at, published), &"", "all eleven endpoints publish")
	assert_equal(EntryWorkArea.publish_paths(o.world_routes, o.routes, o.budget, o.space, at, published,
		o.profiles.content_revision()), &"", "all 31 paths publish")
	assert_equal(o.locations._live.count, EntryWorkArea.ENDPOINTS, "exactly the work area's endpoints")
	assert_equal(o.routes._live.edge_count, 36, "exactly the work area's paths, eight of them ADR1198/1205 haul edges")
	var plan: RefCounted = EntrySite.entry_plan(session._world_ref, o.space.revision(), at, published.endpoints[0],
		o.world_routes._catalog, frontier)
	assert_true(plan != null, "entry plan derived from the mounted bundle")
	var confirmed: RefCounted = o.rooms.confirm_entry(plan)
	assert_true(confirmed.ok, "real entry confirmation at the suggested site: %s" % confirmed.error)
	var live: int = 0
	for row: int in o.placements._capacity:
		if o.placements._is_live(o.placements._live, Vector2i(row, o.placements._live.i32[row])): live += 1
	assert_equal(live, 1, "exactly one entry Placement")


func test_live_entry_chain_publishes_confirms_then_alerts_each_missing_capability() -> void:
	"""ADR1197: real steps stay done; the first missing capability stops the chain with its gap row."""
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")
	var near: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)
	assert_false(_host.begin_underground_entry(near), "no settlement mole holds a tool yet")
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_NO_TOOLED_MOLE, "exact refusal")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G11"), "named gap row")
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_CONTAINERS, "site, work area, entry and containers are real")
	var o: Session.Retirement.Owners = session._retirement_owners
	assert_equal(o.locations._live.count, EntryWorkArea.ENDPOINTS, "published work area retained")
	_equip_first_mole(o, entry._output)
	assert_false(_host.begin_underground_entry(near), "retry resumes and meets the next gap")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_SURFACE_ARRIVAL, "mole is not on the station")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G5"), "surface arrival gap row")
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_CREW, "crew chosen; nothing republished")
	assert_equal(o.locations._live.count, EntryWorkArea.ENDPOINTS, "no second work area")


func test_fixed_ticks_drive_the_live_foreman_until_the_first_gap() -> void:
	"""ADR1210 G7/G4: run_tick alone advances the planned foreman on the real settlement. The mole walks tooled to M,
	puts the tool down and switches at rest to the tool-free rows; Delivery's admission then refuses, because the
	surface residents are not route actors and no occupancy proof can cover them (a G5 gap)."""
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")
	var near: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)
	assert_false(_host.begin_underground_entry(near), "G11 first")
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var o: Session.Retirement.Owners = session._retirement_owners
	var worker: Vector2i = _equip_first_mole(o, entry._output)
	var wood: Vector2i = _stage(o, entry._output, &"wood", 7000)
	_stage(o, entry._output, &"stone", 2000)
	assert_false(_host.begin_underground_entry(near), "G5 next")
	_stand_on_first_station(o, entry, worker)
	assert_true(_host.begin_underground_entry(near), "foreman planned: %s" % _host.last_refusal())
	var tick: int = 1
	while entry.is_running() and tick < 6000:
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	assert_false(entry.is_running(), "stopped at the first remaining gap")
	assert_equal(entry.error(), &"ROUTE_TURN_ACTOR_UNBOUND", "exact refusal")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G5"), "named gap row")
	assert_equal(o.inventory.lot_container(entry.crew().tool), entry._storage, "the tool was put down at M")
	var actor: Session.Retirement.Routes.Actor = Session.Retirement.Routes.Actor.new()
	assert_equal(o.routes.read_actor_into(worker, actor), &"", "a real route actor")
	assert_equal(actor.location, o.inventory.spatial_location_of(entry._storage), "it walked tooled to M")
	assert_equal(actor.profile_id, 31, "and switched at rest to the tool-free walk row")
	assert_equal(o.inventory.lot_reserved_milli(wood), 0, "Delivery's occupancy proof refused before any claim")


func _stage(o: Session.Retirement.Owners, container: Vector2i, key: StringName, milli: int) -> Vector2i:
	"""Surface stock staged at R's real ground-staging container (ADR1197 G4, ADR1203 shared with spoil)."""
	var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(key), milli, 1, 0, -1, 0, 0)
	assert_true(lot.ok, "staged %s: %s" % [key, lot.error])
	return lot.ref


func _stand_on_first_station(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime,
		worker: Vector2i) -> void:
	"""Test stand-in for G5 surface arrival: the crew mole is placed exactly on the first planned station."""
	var foreman: Settlement.UndergroundEntryRuntime.Foreman = Settlement.UndergroundEntryRuntime.Foreman.new()
	assert_equal(foreman.configure(entry._foreman_owners(o), entry._crew, entry._entry_placement(o)), &"", "plan read")
	var record: Session.Retirement.Locations.Record = Session.Retirement.Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	assert_equal(o.locations.read_location_into(foreman.first_station(), record), &"", "first station")
	assert_true(o.transforms.place(worker, record.point.x, record.point.y, record.point.z, foreman._tasks[0].yaw),
		"mole placed on the station")


func _equip_first_mole(o: Session.Retirement.Owners, container: Vector2i) -> Vector2i:
	"""Test stand-in for future tool gameplay: one real basic tool lot equipped by the first adult mole."""
	var residents: RefCounted = o.residents
	for slot: int in residents._present.size():
		if not residents.is_present(slot) or residents.species_key(residents.species_of(slot).value) != &"mole": continue
		var owner: Vector2i = residents.ref_of(slot)
		var lot: RefCounted = o.inventory.create_lot(container, o.items.compiled_id(&"tool"), 1000, 1, 0, -1, 0, 0)
		assert_true(lot.ok, "real tool lot: %s" % lot.error)
		assert_true(o.gear.create_gear(o.inventory, o.items, lot.ref, o.gear.MANUFACTURE_BASIC).ok, "real basic tool")
		assert_true(o.gear.equip(lot.ref, owner).ok, "mole equips it")
		return owner
	assert_true(false, "starting cohort has a mole")
	return Vector2i(-1, 0)


func test_actual_surface_publication_retires_and_remounts_without_old_scope_or_endpoint_alias() -> void:
	"""The actual publisher creates natural facts; complete host clear releases its lifetime before the next World."""
	var session: Session = _surface_session()
	assert_true(_host.compose_underground_surface_anchor(), "compose")
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	var result: Session.Retirement.SurfaceAnchor.Result = _surface_create(anchor)
	assert_equal(result.error, &"", "real generated natural endpoint")
	assert_equal(session.location_owner()._live.count, 1, "one actual endpoint")
	assert_equal(session._retirement_owners.sites._count, 0, "no cut or phase permission")
	assert_true(_host.prepare_world_reset(), "populated original preflight: %s" % _host.last_refusal())
	assert_equal(session._retirement_scope._owners.surface_anchor, anchor, "private Scope retains the exact anchor")
	assert_true(_host.reset(), "actual clear/release: %s" % _host.last_refusal())
	assert_equal(session._retirement_scope, null, "strong Scope cycle broken")
	assert_equal(_surface_create(anchor).error, Session.Retirement.SurfaceAnchor.REFUSE_BINDING, "retired anchor refuses")
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "replacement actual World")
	assert_true(_host.mount_underground(_content), "current source remount")
	assert_true(_host.compose_underground_room_owners(), "replacement Room owners")
	assert_true(_host.compose_underground_route_owners(), "replacement routes")
	assert_true(_host.compose_underground_surface_anchor(), "replacement natural publisher")
	var replacement: Session = _host.underground_session()
	assert_true(replacement.surface_anchor() != anchor, "new actual scope identity")
	assert_true(replacement.location_owner()._live.count == 0, "old endpoint is not copied")
	assert_true(replacement._world_ref != anchor._world_ref, "old full World is not reused")


func _surface_reenter() -> void:
	"""Try actual reset and fixed-tick entry during a selected real constructor observation."""
	_nested_reset = _host.prepare_world_reset()
	_surface_tick = _host.run_tick(1)


func _surface_owner_lifetimes(session: Session) -> Array[WeakRef]:
	"""Weakly observe every old private heavy owner, including the actual banks, without extending any lifetime."""
	var o: Session.Retirement.Owners = session._retirement_owners
	return [weakref(o.budget), weakref(o.space), weakref(o.sources), weakref(o.routes), weakref(o.terrain),
		weakref(o.profiles), weakref(o.profiles._live), weakref(o.levels), weakref(o.rooms), weakref(o.room_bindings),
		weakref(o.world_bindings), weakref(o.sites), weakref(o.authority), weakref(o.locations), weakref(o.locations._live),
		weakref(o.inventory_locations), weakref(o.world_routes), weakref(o.world_routes._catalog),
		weakref(o.world_routes._catalog._live), weakref(o.world_routes._movement)]


func _assert_surface_released(anchor: Session.Retirement.SurfaceAnchor) -> void:
	"""A stale external handle has only fixed scalar tombstones and empty private scratch, never old owner arenas."""
	for name: StringName in [&"_world", &"_terrain", &"_space", &"_sources", &"_locations", &"_routes", &"_budget",
			&"_ids", &"_buildings", &"_construction", &"_inventory", &"_transforms", &"_residents", &"_jobs", &"_work",
			&"_profiles", &"_bindings", &"_gear", &"_carry", &"_reservations", &"_piles"]:
		assert_equal(anchor.get(name), null, "retired own borrow released: %s" % name)
	assert_equal(anchor._record.envelope.size(), 0, "old clearance scratch released")
	assert_equal(anchor._record.support.size(), 0, "old support scratch released")
	assert_equal(anchor._region.box.size(), 0, "old region scratch released")
	assert_equal(anchor._surface_box.size(), 0, "old surface scratch released")
	assert_false(anchor._ready, "stale handle is never ready")
	assert_true(anchor._world_ref != Session.Retirement.NULL_REF, "old full World is an irreversible tombstone")


func test_stale_surface_borrow_cannot_retain_old_arenas_or_bind_the_remounted_world() -> void:
	"""Keep the actual old Anchor alive through clear and new route composition while every old private owner dies."""
	var session: Session = _surface_session()
	assert_true(_host.compose_underground_surface_anchor(), "compose actual anchor")
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	assert_equal(_surface_create(anchor).error, &"", "populated actual natural endpoint")
	var lifetimes: Array[WeakRef] = _surface_owner_lifetimes(session)
	assert_true(_host.reset(), "actual whole-World release: %s" % _host.last_refusal())
	_assert_surface_released(anchor)
	for index: int in lifetimes.size():
		assert_equal(lifetimes[index].get_ref(), null, "old private owner/bank %d is collectible" % index)
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "replacement actual World")
	assert_true(_host.mount_underground(_content), "current source remount")
	assert_true(_host.compose_underground_room_owners(), "new Room owners")
	assert_true(_host.compose_underground_route_owners(), "new route owners")
	var fresh: Session = _host.underground_session()
	assert_equal(anchor.configure(fresh._world, fresh._terrain, fresh._space, fresh._sources,
		fresh.location_owner(), fresh._budget, anchor.RESERVED_BYTES), anchor.REFUSE_BINDING, "old tombstone cannot rebind")
	assert_equal(fresh.location_owner()._world_scope, null, "stale handle did not bind the new weak scope")
	_assert_surface_released(anchor)
	assert_true(_host.compose_underground_surface_anchor(), "new actual Anchor may bind")
	assert_true(fresh.surface_anchor() != anchor, "fresh owner is distinct")
	assert_true(_host.reset(), "remounted owner retires normally")


func test_surface_release_leaf_refuses_live_world_without_dropping_any_own_pin() -> void:
	"""The public owner leaf cannot be used as gameplay unbind even with the complete real original packet."""
	var session: Session = _surface_session()
	assert_true(_host.compose_underground_surface_anchor(), "compose")
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	var before: Array[PackedByteArray] = _snapshot()
	assert_true(Session.Retirement.SurfaceAnchor.world_retirement_release_preflighted_in(anchor,
		session._retirement_owners, session._world_pid) != &"", "live World refuses owner release")
	assert_equal(_snapshot(), before, "canonical stores unchanged")
	assert_equal(Session.Retirement.surface_refusal(session._retirement_owners), &"", "every original pin retained")
	assert_equal(anchor._record.envelope.size(), 6, "scratch unchanged")
	assert_equal(_surface_create(anchor).error, &"", "original real publisher remains usable")
	assert_true(_host.reset(), "normal full reset still succeeds")


func test_surface_partial_clear_keeps_original_arenas_and_stays_stopped() -> void:
	"""A failed full-empty proof cannot release the original Anchor or reopen dispatch over partially cleared stores."""
	_host.free()
	var actual: ClearingHost = ClearingHost.new()
	_host = actual
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners(), "actual Room owners")
	assert_true(_host.compose_underground_route_owners(), "actual route owners")
	assert_true(_host.compose_underground_surface_anchor(), "actual Anchor")
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	var lifetimes: Array[WeakRef] = _surface_owner_lifetimes(session)
	actual.partial_clear = true
	assert_false(_host.reset(), "partial clear refuses final release")
	assert_equal(_host._underground_reset_phase, 3, "host remains stopped")
	assert_false(_host.abandon_world_reset(), "cannot undo partial clear")
	assert_false(_host.run_tick(1), "no tick over partial stores")
	assert_equal(session._retirement_scope._owners.surface_anchor, anchor, "original exact Scope retained")
	assert_equal(Session.Retirement.surface_refusal(session._retirement_owners), &"", "every Anchor owner still retained")
	assert_equal(anchor._record.envelope.size(), 6, "fixed buffers not cleared on refusal")
	for index: int in lifetimes.size():
		assert_true(lifetimes[index].get_ref() != null, "partial clear retains owner %d" % index)
	_host.free()
	_host = null
	assert_equal(session._retirement_scope, null, "host destruction only breaks the Scope cycle")


func test_surface_binding_reentry_retains_exact_exposed_prefix_and_can_only_reset() -> void:
	"""A late real WorldScope observer cannot lose its original one-way binding on failed Session construction."""
	var session: Session = _surface_session()
	var before: Array[PackedByteArray] = _snapshot()
	var world: SurfaceWorld = _host.world() as SurfaceWorld
	world.during_retention = true
	world.observer = _surface_reenter
	assert_false(_host.compose_underground_surface_anchor(), "late reentry refuses")
	assert_false(_nested_reset, "nested reset refused")
	assert_false(_surface_tick, "nested tick refused")
	assert_equal(session._operations_state, 3, "stopped original group")
	assert_equal(session._operations_prefix, 9, "bound candidate retained")
	assert_equal(session._retirement_owners.locations._world_scope.get_ref(),
		session._retirement_owners.surface_anchor, "same strong original")
	assert_equal(session.surface_anchor(), null, "no stopped getter")
	assert_false(_host.compose_underground_surface_anchor(), "no replacement attempt")
	assert_equal(_snapshot(), before, "gameplay unchanged")
	assert_true(_host.prepare_world_reset(), "exact failed-prefix preflight: %s" % _host.last_refusal())
	assert_equal(session._retirement_scope._constructor_prefix, 9, "private original constructor proof")
	assert_true(_host.abandon_world_reset(), "original-live abandonment")
	assert_false(_host.run_tick(1), "abandon cannot restart a failed prefix")
	assert_true(_host.reset(), "actual prefix retirement")


func _surface_replace_gear() -> void:
	"""Mutate only the host's mounted tuple after a genuine old-owner result, never return success for foreign owners."""
	_saved_gear = _host._gear
	_host._gear = Gear.new()


func test_surface_late_host_identity_change_preserves_original_binding_and_refuses_reset_until_restored() -> void:
	"""The Host final leaf still runs after a successful inner configure and retains the original stopped Session."""
	var session: Session = _surface_session()
	(_host.world() as SurfaceWorld).observer = _surface_replace_gear
	assert_false(_host.compose_underground_surface_anchor(), "late host mismatch")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_HOST_OWNER", "exact mount refusal")
	assert_equal(session._operations_state, 3, "stopped")
	assert_equal(session._operations_prefix, 9, "original one-way scope retained")
	assert_false(_host.prepare_world_reset(), "foreign host cannot retire original tuple")
	assert_equal(session._retirement_scope, null, "no fake captured Scope")
	_host._gear = _saved_gear
	_saved_gear = null
	assert_true(_host.reset(), "restored original can retire")


func _surface_source_drift() -> void:
	"""Change only an actual cached immutable consumer after the genuine source observation."""
	_surface_script = Session.Contacts
	_surface_source_text = _surface_script.source_code
	_surface_script.source_code = _surface_source_text + "\n# 1171 late source mutation\n"


func test_surface_late_source_drift_keeps_bound_scope_until_exact_source_is_restored() -> void:
	"""No same-revision source substitution may be hidden by completing the actual one-way scope binding."""
	var session: Session = _surface_session()
	var world: SurfaceWorld = _host.world() as SurfaceWorld
	world.during_retention = true
	world.observer = _surface_source_drift
	assert_false(_host.compose_underground_surface_anchor(), "actual cached-source drift")
	assert_equal(_host.last_refusal(), &"MOLE_CATALOG_SOURCE_DRIFT", "original source guard")
	assert_equal(session._operations_prefix, 9, "late bound scope retained")
	assert_equal(session._operations_state, 3, "stopped original group")
	assert_false(_host.prepare_world_reset(), "source remains mandatory during original capture")
	_surface_script.source_code = _surface_source_text
	_surface_script = null
	assert_true(_host.reset(), "exact restored source retires original")


func test_surface_captured_scope_rejects_packet_and_weak_backlink_replacement_without_clearing() -> void:
	"""Repeat preflight consumes the private original anchor; equal-shaped replacements never become its lifetime proof."""
	var session: Session = _surface_session()
	assert_true(_host.compose_underground_surface_anchor(), "compose")
	var anchor: Session.Retirement.SurfaceAnchor = session.surface_anchor()
	assert_true(_host.prepare_world_reset(), "capture")
	var scope: Session.Retirement.Scope = session._retirement_scope
	var before: Array[PackedByteArray] = _snapshot()
	session._retirement_owners.surface_anchor = Session.Retirement.SurfaceAnchor.new()
	assert_false(_host.prepare_world_reset(), "foreign packet anchor refused")
	assert_equal(scope._owners.surface_anchor, anchor, "captured original retained")
	session._retirement_owners.surface_anchor = anchor
	var weak: WeakRef = session._retirement_owners.locations._world_scope
	session._retirement_owners.locations._world_scope = null
	assert_false(_host.prepare_world_reset(), "missing original weak scope refused")
	session._retirement_owners.locations._world_scope = weak
	assert_equal(_snapshot(), before, "no canonical clear on refusal")
	assert_true(_host.prepare_world_reset(), "same original Scope can retry")
	assert_equal(session._retirement_scope, scope, "one private Scope")
	assert_true(_host.reset(), "restored tuple retires")


func test_surface_active_publication_rejects_whole_world_reset_and_keeps_its_original_lease() -> void:
	"""An actual create observation cannot let host clearing run through an active SurfaceAnchor publication."""
	var session: Session = _surface_session()
	assert_true(_host.compose_underground_surface_anchor(), "compose")
	var world: SurfaceWorld = _host.world() as SurfaceWorld
	world.during_create = true
	world.observer = _surface_reenter
	var result: Session.Retirement.SurfaceAnchor.Result = _surface_create(session.surface_anchor())
	assert_false(_nested_reset, "real active operation blocks reset")
	assert_false(_surface_tick, "real active operation blocks fixed tick")
	assert_equal(session._retirement_scope, null, "no partial retirement scope")
	assert_equal(result.error, &"", "original physical publisher completes or refuses independently")
	assert_equal(session.location_owner()._live.count, 1, "one genuine endpoint")
	assert_true(session._budget.is_quiescent(), "original cold lease released")
	assert_true(_host.reset(), "subsequent quiescent reset")
