extends "res://test/framework/test_case.gd"
## Actual host-lifetime tests; no phase, stock, contact, or route permission is supplied by a fixture.

const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const World := preload("res://scripts/core/world_init.gd")

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

var _host: Settlement = null
var _content: Content = null
var _nested_reset: bool = true


func before_each() -> void:
	"""Load the exact production image against a test-owned actual settlement."""
	_host = Settlement.new()
	_content = Content.new()
	assert_equal(_content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
		Session.PRESENTATION_BYTES), &"", "actual source")
	_nested_reset = true


func after_each() -> void:
	"""Free only this suite's host; its foundation has no externally bound authority."""
	if _host.gear() is ObservedGear:
		(_host.gear() as ObservedGear).observer = Callable()
	_host.free()
	_host = null
	_content = null


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
