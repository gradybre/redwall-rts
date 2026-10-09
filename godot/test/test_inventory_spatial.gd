extends "res://test/framework/test_case.gd"
## Actual Inventory transaction tests with explicitly synthetic location geometry.
## No fixture attests actual underground support, routes or playable world qualification.

const Inventory := preload("res://scripts/core/inventory.gd")
const Locations := preload("res://scripts/core/inventory_spatial_contract.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const LOWER: Vector2i = Vector2i(0, 1)
const UPPER: Vector2i = Vector2i(1, 1)
const ALIAS: Vector2i = Vector2i(2, 1)
const OTHER: Vector2i = Vector2i(3, 1)

class GeometryFixture extends Locations:
	var inventory: WeakRef = null
	var directory: Directory = null
	var world: Vector2i = NULL_REF
	var live: bool = true
	var revision: int = 1
	var blocked: bool = false
	var reenter: bool = false
	var reentry_error: StringName = &""
	var reentry_action: StringName = &""

	func exact_binding(actual: RefCounted, identity: Vector2i) -> bool:
		"""Require actual object identity even though the location coordinates are a labeled fixture."""
		return live and inventory != null and inventory.get_ref() == actual and identity == world \
			and directory.is_valid_of_kind(world, Directory.KIND_WORLD)

	func world_ref() -> Vector2i:
		"""One actual generational World, not an arbitrary owner pair."""
		return world

	func storage_endpoint_refusal(location: Vector2i) -> StringName:
		"""Distinct fixture sections can stack; the actual Inventory still owns all goods and rollback."""
		if reenter:
			var store: Inventory = inventory.get_ref() as Inventory
			reentry_error = store.create_container(world, 1, -1, 0, true).error
		if reentry_action != &"":
			_attempt_reentry(inventory.get_ref() as Inventory)
		return &"SYNTHETIC_LOCATION_BLOCKED" if blocked else \
			(&"" if location_revision(location) > 0 else &"SYNTHETIC_LOCATION_STALE")

	func _attempt_reentry(store: Inventory) -> void:
		"""Deliberately violate the borrowed-provider contract through real public mutation doors."""
		match reentry_action:
			&"commit":
				reentry_error = store.commit().error
			&"abort":
				store.abort()
			&"clear":
				store.clear()
			&"begin":
				reentry_error = store.begin().error
			&"register":
				reentry_error = store.register_item(1, 1000, 0).error
			&"ground":
				reentry_error = store.set_ground_pile_authority(null).error
			&"seed":
				reentry_error = store.set_seed_expiry_authority(null).error
			&"equipment":
				reentry_error = store.set_equipment_authority(null).error
			&"spatial":
				reentry_error = store.bind_spatial_locations(self, 3).error

	func location_revision(location: Vector2i) -> int:
		"""Expose an explicit immutable fixture payload revision; reused generations refuse."""
		return revision if live and location.y == 1 and location.x >= 0 and location.x < 8 else 0

	func same_storage_cell(first: Vector2i, second: Vector2i) -> bool:
		"""Rows0/2 alias one actual fixture placement cell; row1 has the same X/Z on another floor."""
		if location_revision(first) <= 0 or location_revision(second) <= 0:
			return false
		var a: int = 0 if first.x == 2 else first.x
		var b: int = 0 if second.x == 2 else second.x
		return a == b

class WiringFixture extends RefCounted:
	func ground_pile_tile_refusal(_tile: int) -> StringName:
		"""This non-production authority denies every surface placement."""
		return &"SYNTHETIC_NO_SURFACE"

	func ground_pile_owner_ref() -> Vector2i:
		"""This fixture grants no World owner for creating surface goods."""
		return NULL_REF

	func refuses_seed_consumption(_lot: Vector2i) -> bool:
		"""Retain an observable non-null seed authority through attempted callback unbinding."""
		return true

	func is_equipped_record(_lot: Vector2i) -> bool:
		"""No fixture lot is physically equipped."""
		return false

var _inventory: Inventory = null
var _authority: GeometryFixture = null
var _directory: Directory = null
var _world: Vector2i = NULL_REF
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Use a real finite Inventory, actual World identity and exactly three admitted endpoint rows."""
	_directory = Directory.new()
	_world = _directory.create(Directory.KIND_WORLD)
	_inventory = Inventory.new(16, 16)
	assert_true(_inventory.register_item(0, 1000, 0).ok, "real finite mass definition")
	_authority = GeometryFixture.new()
	_authority.inventory = weakref(_inventory)
	_authority.directory = _directory
	_authority.world = _world
	assert_true(_inventory.bind_spatial_locations(_authority, 3).ok, "actual store/provider composition")


func after_each() -> void:
	"""Every completed test leaves the real container/lot/endpoint accounting auditable."""
	assert_true(_inventory.audit().ok, "actual Inventory and sparse endpoint audit")
	_authority = null
	_inventory = null
	_directory = null


func _stage(location: Vector2i = LOWER) -> Vector2i:
	"""Create only real World-owned finite output staging, through the new exact location door."""
	var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(location)
	assert_true(made.ok, "real spatial staging: %s" % made.error)
	return made.ref


func _pile(location: Vector2i = LOWER, quantity: int = 2000) -> Vector2i:
	"""Output creation and promotion share the real existing Inventory transaction."""
	var container: Vector2i = _stage(location)
	assert_true(_inventory.begin().ok, "actual output transaction")
	assert_true(_inventory.create_lot(container, 0, quantity, 0, 0, -1, 0, 0).ok, "actual finite output lot")
	assert_true(_inventory.promote_to_spatial_ground_pile(container, location).ok, "same actual staging row promotes")
	assert_true(_inventory.commit().ok, "atomic actual output commit")
	return container


func test_stacked_floors_hold_distinct_piles_without_aliasing_surface_tiles() -> void:
	"""Two actual container identities occupy equal fixture X/Z on different floor sections."""
	var lower: Vector2i = _pile(LOWER)
	var upper: Vector2i = _pile(UPPER)
	assert_true(lower != upper, "separate actual containers")
	assert_equal(_inventory.spatial_location_of(lower), LOWER, "lower full location")
	assert_equal(_inventory.spatial_location_of(upper), UPPER, "upper full location")
	assert_equal(_inventory.spatial_ground_container_at(LOWER), lower, "lower exact placement")
	assert_equal(_inventory.spatial_ground_container_at(UPPER), upper, "upper exact placement")
	assert_equal(_inventory.ground_pile_at_tile(0), NULL_REF, "surface map untouched")
	assert_equal(_inventory.total_live_milli(0), 4000, "two conserved physical outputs")


func test_duplicate_location_handles_cannot_own_the_same_placement_cell() -> void:
	"""An aliased endpoint is a duplicate even before the first staged output becomes a pile."""
	var container: Vector2i = _stage()
	var before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_inventory.create_spatial_ground_staging(ALIAS).error, Inventory.REFUSE_GROUND_PILE_TILE_TAKEN, "actual duplicate placement")
	assert_equal(_inventory.state_bytes(), before, "no new container or endpoint generation")
	assert_equal(_inventory.spatial_ground_container_at(ALIAS), container, "alias resolves existing real endpoint")


func test_endpoint_exhaustion_and_full_generation_reuse_are_atomic() -> void:
	"""The explicit sparse arena never turns exhaustion into truncation or stale container aliases."""
	var first: Vector2i = _stage(LOWER)
	_stage(UPPER)
	_stage(OTHER)
	var before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_inventory.create_spatial_ground_staging(Vector2i(4, 1)).error, Inventory.REFUSE_SPATIAL_CAPACITY, "three admitted rows exhausted")
	assert_equal(_inventory.state_bytes(), before, "exhaustion consumes no container generation")
	assert_true(_inventory.destroy_container(first).ok, "unused staging releases its endpoint")
	assert_false(_inventory.has_spatial_location(LOWER, 1), "retirement lease releases")
	var replacement: Vector2i = _stage(Vector2i(4, 1))
	assert_true(first != replacement, "reused row has a different actual generation")
	assert_equal(_inventory.spatial_location_of(first), NULL_REF, "stale container cannot address replacement")
	assert_equal(_inventory.spatial_endpoint_bytes(), 72, "exact24C live packed bytes")


func test_actual_capacity_never_exceeds_the_adopted_finite_ground_pile_bound() -> void:
	"""A spatial address grants no extra mass or future-output credit."""
	var container: Vector2i = _pile(LOWER, Inventory.GROUND_PILE_MAX_MASS_G)
	var before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_inventory.create_lot(container, 0, 1, 0, 0, -1, 0, 0).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "full actual400kg pile")
	assert_equal(_inventory.state_bytes(), before, "extra output is not minted")
	assert_false(_inventory.reduce_container_capacity(container, 1).ok, "fixed capacity cannot be rewritten")
	assert_equal(_inventory.container_max_mass_g(container), Inventory.GROUND_PILE_MAX_MASS_G, "actual bound retained")


func test_output_and_promotion_abort_restore_every_container_lot_and_endpoint_byte() -> void:
	"""A failure after output creation and promotion rolls back the same existing journal."""
	var container: Vector2i = _stage()
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "actual explicit transaction")
	assert_true(_inventory.create_lot(container, 0, 2000, 0, 0, -1, 0, 0).ok, "real output created provisionally")
	assert_true(_inventory.promote_to_spatial_ground_pile(container, LOWER).ok, "real provisional promotion")
	assert_false(_inventory.create_lot(container, 0, 500000, 0, 0, -1, 0, 0).ok, "later real capacity refusal")
	assert_false(_inventory.commit().ok, "poisoned output transaction aborts")
	assert_equal(_inventory.state_bytes(), before, "all actual owner bytes restored")
	assert_false(_inventory.is_ground_pile(container), "staging identity restored")
	assert_true(_inventory.has_spatial_location(LOWER, 1), "original contact ownership retained")


func test_staging_create_and_destroy_rollback_restore_the_sparse_row_with_container() -> void:
	"""Both endpoint admission and retirement roll back alongside allocator generations."""
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "actual creation transaction")
	var created: Vector2i = _stage()
	_inventory.abort()
	assert_equal(_inventory.state_bytes(), before, "creation rollback includes endpoint")
	assert_false(_inventory.is_container_valid(created), "rolled-back container is not live")
	created = _stage()
	before = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "actual retirement transaction")
	assert_true(_inventory.destroy_container(created).ok, "provisional endpoint retirement")
	_inventory.abort()
	assert_equal(_inventory.state_bytes(), before, "retirement rollback includes sparse endpoint")
	assert_true(_inventory.has_spatial_location(LOWER, 1), "ownership restored exactly")


func test_empty_pile_auto_retirement_releases_only_its_actual_floor_endpoint() -> void:
	"""Final goods removal cannot leave a zero-lot pile or free another floor's identity."""
	var lower: Vector2i = _pile(LOWER)
	var upper: Vector2i = _pile(UPPER)
	var lot: Vector2i = _inventory.container_first_lot(lower)
	assert_true(_inventory.sink_lot_quantity(lot, 2000).ok, "actual last output leaves")
	assert_false(_inventory.is_container_valid(lower), "empty pile reclaimed by the real commit")
	assert_false(_inventory.has_spatial_location(LOWER, 1), "lower location lease released")
	assert_equal(_inventory.spatial_ground_container_at(UPPER), upper, "upper floor unaffected")
	assert_true(_inventory.has_spatial_location(UPPER, 1), "upper contact remains owned")


func test_flat_authority_readers_and_legacy_codec_cannot_reinterpret_spatial_locations() -> void:
	"""Refusal carries zero instead of returning a plausible surface tile or dropping location state."""
	var container: Vector2i = _stage()
	_math.succeed(99)
	assert_false(_inventory.container_anchor_tile_into(container, _math), "flat authoritative reader refuses")
	assert_equal(_math.value, 0, "no plausible tile leaks through refusal")
	assert_equal(_math.error, String(Inventory.REFUSE_SPATIAL_REQUIRED), "explicit namespace reason")
	assert_false(_inventory.set_container_anchor(container, 3).ok, "ordinary setter cannot move actual ground endpoint")
	var columns: Inventory.CanonicalColumns = Inventory.CanonicalColumns.new(16, 16)
	assert_true(_inventory.copy_canonical_columns_into(columns), "ADR 1228: section 7 captures the anchored container")
	assert_equal(columns.c_anchor_tile[container.x], -2, "anchored at its endpoint row; section 6 carries the arena")
	assert_false(_inventory.restore_canonical_columns(columns), "restore cannot erase a retained endpoint")
	assert_equal(_inventory.canonical_detail(), String(Inventory.REFUSE_SPATIAL_CODEC), "the arena must be empty first")


func test_stale_existing_endpoint_and_late_foreign_binding_refuse_before_admission() -> void:
	"""Missing old location proof cannot make a duplicate location look unoccupied."""
	_stage()
	var before: PackedByteArray = _inventory.state_bytes()
	_authority.revision = 2
	assert_equal(_inventory.create_spatial_ground_staging(OTHER).error, Inventory.REFUSE_SPATIAL_LOCATION, "old exact payload changed")
	assert_equal(_inventory.state_bytes(), before, "stale endpoint retains every real good/claim")
	assert_true(_inventory.has_spatial_location(LOWER, 1), "retirement query still sees stale retained ownership")
	_authority.revision = 1
	_authority.live = false
	assert_equal(_inventory.create_spatial_ground_staging(OTHER).error, Inventory.REFUSE_SPATIAL_BINDING, "actual composition invalidated")
	assert_equal(_inventory.state_bytes(), before, "no late permissive fallback")
	_authority.live = true


func test_reentrant_authority_poison_aborts_before_container_or_endpoint_publication() -> void:
	"""The borrowed geometry callback cannot recursively mutate the actual Inventory transaction."""
	_authority.reenter = true
	var before: PackedByteArray = _inventory.state_bytes()
	assert_false(_inventory.create_spatial_ground_staging(LOWER).ok, "reentry prevents publication")
	assert_equal(_authority.reentry_error, Inventory.REFUSE_ATTESTATION_REENTRY, "existing reentry guard retained")
	assert_equal(_inventory.state_bytes(), before, "all stores byte identical after nested refusal")
	_authority.reenter = false


func test_reentrant_lifecycle_cannot_publish_discard_or_reset_prior_provisional_goods() -> void:
	"""Each lifecycle callback preserves the open journal until the real caller rolls all goods back."""
	var container: Vector2i = _inventory.create_container(_world, 4000, -1, 0, true).ref
	for action: StringName in [&"commit", &"abort", &"clear", &"begin"]:
		var before: PackedByteArray = _inventory.state_bytes()
		assert_true(_inventory.begin().ok, "actual outer transaction")
		var lot: Inventory.OpResult = _inventory.create_lot(container, 0, 1000, 0, 0, -1, 0, 0)
		assert_true(lot.ok, "real provisional good before callback")
		_authority.reentry_action = action
		assert_false(_inventory.create_spatial_ground_staging(LOWER).ok, "lifecycle reentry refuses: %s" % action)
		assert_true(_inventory.is_transaction_open(), "callback cannot close the caller's journal")
		assert_true(_inventory.is_transaction_poisoned(), "outer caller must abort all provisional goods")
		assert_true(_inventory.is_lot_valid(lot.ref), "callback has not prematurely rolled back or reset rows")
		_authority.reentry_action = &""
		assert_equal(_inventory.commit().error, Inventory.REFUSE_ATTESTATION_REENTRY, "first refusal survives until rollback")
		assert_equal(_inventory.state_bytes(), before, "container, goods, ledger and endpoint bytes restored")


func test_read_callback_cannot_open_close_or_clear_a_transaction() -> void:
	"""A read outside a transaction still protects existing physical goods and location history."""
	var container: Vector2i = _pile()
	var before: PackedByteArray = _inventory.state_bytes()
	for action: StringName in [&"commit", &"abort", &"clear", &"begin"]:
		_authority.reentry_action = action
		assert_equal(_inventory.spatial_location_of(container), LOWER, "unchanged location remains readable")
		assert_false(_inventory.is_transaction_open(), "callback cannot leave a hidden transaction open")
		assert_equal(_inventory.state_bytes(), before, "outside-transaction reentry has no mutation: %s" % action)
	_authority.reentry_action = &""


func test_read_callback_cannot_rewire_catalog_or_authorities_outside_a_transaction() -> void:
	"""Non-journaled catalog and provider bindings are protected even during a cold spatial read."""
	var wiring: WiringFixture = WiringFixture.new()
	assert_true(_inventory.set_ground_pile_authority(wiring).ok, "retained surface authority")
	assert_true(_inventory.set_seed_expiry_authority(wiring).ok, "retained seed authority")
	assert_true(_inventory.set_equipment_authority(wiring).ok, "retained equipment authority")
	var container: Vector2i = _stage()
	var before: PackedByteArray = _inventory.state_bytes()
	for action: StringName in [&"register", &"ground", &"seed", &"equipment", &"spatial"]:
		_authority.reentry_action = action
		assert_equal(_inventory.spatial_location_of(container), LOWER, "provider reads unchanged geometry")
		assert_equal(_authority.reentry_error, Inventory.REFUSE_ATTESTATION_REENTRY, "wiring reentry refused: %s" % action)
		assert_equal(_inventory.state_bytes(), before, "catalog and endpoint arrays unchanged")
		assert_false(_inventory.is_item_registered(1), "callback has not inserted an unjournaled item")
		assert_true(_inventory.has_ground_pile_authority(), "surface guard retained")
		assert_true(_inventory.has_seed_expiry_authority(), "seed guard retained")
		assert_true(_inventory.has_equipment_authority(), "equipment guard retained")
	_authority.reentry_action = &""
	assert_true(_inventory.set_ground_pile_authority(null).ok, "release test fixture binding")
	assert_true(_inventory.set_seed_expiry_authority(null).ok, "release test fixture binding")
	assert_true(_inventory.set_equipment_authority(null).ok, "release test fixture binding")


func test_flat_complete_footprint_query_refuses_without_partial_output_when_spatial_goods_exist() -> void:
	"""A demolition scan cannot treat a surface-only list as proof that every floor is clear."""
	var surface: Vector2i = _inventory.create_container(_world, 4000, -1, 0, true, 0).ref
	var lower: Vector2i = _stage()
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(_inventory.anchor_query_mask_bytes())
	mask[0] = 1
	var pairs: PackedInt32Array = PackedInt32Array([17, 19, 23, 29])
	var before: PackedInt32Array = pairs.duplicate()
	_math.succeed(77)
	assert_false(_inventory.containers_anchored_in_into(mask, pairs, _math), "flat complete query must refuse")
	assert_equal(_math.error, String(Inventory.REFUSE_SPATIAL_REQUIRED), "caller requires multilevel proof")
	assert_equal(_math.value, 0, "no misleading partial count")
	assert_equal(pairs, before, "no partial buffer publication")
	assert_equal(_inventory.next_container_anchored_in(-1, mask), surface, "candidate iterator remains surface-only")
	assert_true(_inventory.destroy_container(lower).ok, "resolve actual lower-floor endpoint")
	assert_true(_inventory.containers_anchored_in_into(mask, pairs, _math), "surface proof works after all spatial ownership is retired")
	assert_equal(_math.value, 1, "real complete surface count")
	assert_equal(Vector2i(pairs[0], pairs[1]), surface, "exact actual surface container")


func test_empty_claimed_spatial_pile_refuses_goods_removal_without_releasing_ownership() -> void:
	"""The existing empty-pile claim invariant applies on every actual floor."""
	var container: Vector2i = _pile()
	var lot: Vector2i = _inventory.container_first_lot(container)
	assert_true(_inventory.reserve_container_mass(container, 2000).ok, "actual independent output claim")
	var before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_inventory.sink_lot_quantity(lot, 2000).error, Inventory.REFUSE_GROUND_PILE_EMPTY_WITH_CLAIM, "claimed empty pile cannot commit")
	assert_equal(_inventory.state_bytes(), before, "lot, reservation and floor endpoint remain intact")
	assert_true(_inventory.has_spatial_location(LOWER, 1), "geometry retirement remains blocked")


func test_journal_exhaustion_aborts_new_endpoint_and_preserves_existing_state() -> void:
	"""The actual shared journal bounds transactions that mix endpoint and ordinary container changes."""
	var ordinary: Vector2i = _inventory.create_container(_world, 1, -1, 0, true).ref
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "actual shared transaction")
	_stage()
	var code: StringName = &""
	for index: int in Inventory.JOURNAL_CAPACITY:
		var changed: Inventory.OpResult = _inventory.set_container_reachable(ordinary, index % 2 == 0)
		if not changed.ok:
			code = changed.error
			break
	assert_equal(code, Inventory.REFUSE_JOURNAL_FULL, "actual fixed journal exhausted")
	assert_false(_inventory.commit().ok, "entire mixed transaction aborts")
	assert_equal(_inventory.state_bytes(), before, "new endpoint, container generation and old reachability roll back")
	assert_false(_inventory.has_spatial_location(LOWER, 1), "no leaked geometry lease")


func test_foreign_provider_or_oversized_configuration_cannot_replace_existing_history() -> void:
	"""Once-bound exact composition and finite capacity cannot be reset to bypass ownership."""
	var foreign: Inventory = Inventory.new(16, 16)
	assert_equal(foreign.bind_spatial_locations(_authority, 3).error, Inventory.REFUSE_SPATIAL_BINDING, "coincident other Inventory refused")
	assert_equal(foreign.spatial_endpoint_bytes(), 0, "foreign refusal allocates no arena")
	_stage()
	var before: PackedByteArray = _inventory.state_bytes()
	assert_false(_inventory.bind_spatial_locations(_authority, 3).ok, "existing binding cannot reset rows")
	assert_equal(_inventory.state_bytes(), before, "existing history unchanged")
	assert_equal(foreign.bind_spatial_locations(_authority, Inventory.SPATIAL_ENDPOINT_CAPACITY + 1).error, Inventory.REFUSE_SPATIAL_CAPACITY, "oversize refuses before allocation")
	assert_equal(foreign.spatial_endpoint_bytes(), 0, "no silent clamped allocation")


func test_promotion_revalidates_the_exact_location_after_output_is_staged() -> void:
	"""A newly blocked endpoint rolls back real output instead of relocating it or leaving a fake pile."""
	var container: Vector2i = _stage()
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "actual output transaction")
	assert_true(_inventory.create_lot(container, 0, 2000, 0, 0, -1, 0, 0).ok, "actual provisional output")
	_authority.blocked = true
	assert_equal(_inventory.promote_to_spatial_ground_pile(container, LOWER).error, &"SYNTHETIC_LOCATION_BLOCKED", "fresh physical refusal")
	assert_false(_inventory.commit().ok, "full output candidate aborts")
	assert_equal(_inventory.state_bytes(), before, "paid caller can retry the exact staging container")
	_authority.blocked = false
