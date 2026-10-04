extends "res://test/framework/test_case.gd"
## Real RoomOrders/Directory/Space/Sites admission. Terrain/frontier/Placement permission is synthetic.
## This component does not qualify a playable entrance, routing, physical work or resource consumption.

const Orders := preload("res://scripts/core/underground_room_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const RoomTests := preload("res://test/test_underground_room_orders.gd")
const FurnitureTests := preload("res://test/test_underground_furniture_work.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class EntryBindings extends RoomTests.RoomBindings:

	var original_entry: EntryPlan.Request = null
	var section: Vector2i = NULL_REF
	var published_section: Vector2i = NULL_REF
	var scopes: int = 0
	var publication_scopes: int = 0
	var cold_mutation: bool = false
	var property_to_change: StringName = &""
	var changed_value: Variant = null
	var change_private: bool = false
	var entry_reentry: bool = false
	var flat_reentry: bool = false
	var observed_pure: bool = false
	var refuse_final: bool = false
	var mutate_final: bool = false

	func begin_entry_cold(plan: EntryPlan.Request) -> StringName:
		"""Use the actual arena and exclusive coordinator stage, before any private packet is allocated."""
		var actual: Orders = orders.get_ref() as Orders
		assert(actual.entry_admission_refusal(plan, self) == &"", "exact typed request stage")
		assert(actual.room_admission_refusal(Orders.RoomPlan.new(), self) != &"", "flat stage unavailable")
		assert(actual._entry_plan == null, "no private allocation precedes admission")
		if deny_room_cold:
			return &"SYNTHETIC_ENTRY_COLD_DENIED"
		arena_token = arena.acquire(Budget.COLD_BYTES)
		if arena_token == 0:
			return Budget.REFUSE_BUSY
		original_entry = plan
		room_cold_held = true
		room_cold_foreign_stage = space.has_prepared()
		room_begins += 1
		if cold_mutation:
			plan.claims.append(1)
		return &""

	func entry_cold_refusal(plan: EntryPlan.Request, token: int) -> StringName:
		"""An adversarial callback can revoke its original lease; the coordinator must catch replacement."""
		scopes += 1
		_replace_lease(2)
		return &"" if room_cold_held and plan == original_entry and token == arena_token \
			and arena.covers(token, Budget.COLD_BYTES) else Orders.REFUSE_ROOM_COLD

	func entry_plan_refusal(_plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
			section_ref: Vector2i, token: int) -> StringName:
		"""Only geometric/frontier permission is synthetic; exact future Room/Space proof is real."""
		pending_room = candidate.ref
		pending_type = Buildings.ROOM_TYPE_CORRIDOR
		pending_token = token
		section = section_ref
		var actual: Orders = orders.get_ref() as Orders
		assert(not construction.buildings().is_live_room(pending_room), "Room not allocated yet")
		assert(actual.room_companion_refusal(pending_room, pending_type, token,
			arena_token, space, arena) == &"", "exact future companion stage")
		if probe_reentry:
			entry_reentry = not actual.confirm_entry(original_entry).ok
			flat_reentry = not actual.confirm_room(Orders.RoomPlan.new()).ok
			actual.discard_transition(NULL_REF, Orders.ROOM_ADMISSION_STAGE)
			direct_create_refused = not construction.buildings().designate_spatial_room_candidate(
				pending_type, candidate).ok
		return &"SYNTHETIC_FRONTIER_UNQUALIFIED" if block_plan else &""

	func entry_prepared_refusal(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
			_section: Vector2i, _token: int) -> StringName:
		"""Inject external input/source changes after the actual sparse geometry candidate was sealed."""
		_replace_lease(3)
		if property_to_change != &"":
			(plan if change_private else original_entry).set(property_to_change, changed_value)
		if tamper_candidate:
			candidate.persistent_id += 1
		if unbind_after_preparation:
			wired = false
		return &"SYNTHETIC_FRONTIER_CHANGED" if block_prepared else &""

	func discard_entry_plan(room: Vector2i, token: int) -> void:
		"""Discard only the exact failed entry companion, without publishing identity or claims."""
		assert(pending_room == NULL_REF or pending_room == room and pending_token == token, "exact discard")
		section = NULL_REF
		_clear_room_companion()

	func entry_final_refusal(_plan: EntryPlan.Request, _candidate: Directory.CreateCandidate,
			_section: Vector2i, _token: int) -> StringName:
		"""Final companion permission is explicit and follows the real Sites observation boundary."""
		var actual: Orders = orders.get_ref() as Orders
		assert(actual._room_claim_batch != null, "Sites prepared before final companion proof")
		if mutate_final:
			original_entry.source_digests[1] += 1
		return &"SYNTHETIC_FINAL_COMPANION_STALE" if refuse_final else &""

	func publish_entry_plan(room: Vector2i, token: int) -> void:
		"""Observe the real same-stack Room receipt after identity, unique Sites and sparse claims publish."""
		assert(room == pending_room and token == pending_token, "exact entry publication")
		var actual: Orders = orders.get_ref() as Orders
		var reads: int = binding_reads
		assert(actual.is_publishing_room_admission(room, Buildings.ROOM_TYPE_CORRIDOR), "actual Room receipt")
		assert(not actual.is_publishing_room_admission(room, Buildings.ROOM_TYPE_KITCHEN), "purpose fixed")
		assert(actual.room_companion_refusal(room, pending_type, token, arena_token, space, arena) == &"", "same companion")
		observed_pure = reads == binding_reads
		publication_scopes = scopes
		published_section = section
		room_publications += 1
		section = NULL_REF
		_clear_room_companion()

	func end_entry_cold() -> void:
		"""Copied packets and private Sites cursor must be gone before releasing the exact original lease."""
		var actual: Orders = orders.get_ref() as Orders
		assert(room_cold_held and pending_room == NULL_REF, "companion released first")
		assert(not space.has_prepared() or room_cold_foreign_stage, "own Space stage discarded")
		assert(actual._entry_plan == null and actual._entry_claim_input == null, "entry copies discarded")
		assert(actual._room_claim_batch == null and actual._room_candidate.ref == NULL_REF, "claim and identity dropped")
		room_cold_held = false
		if arena.covers(arena_token, Budget.COLD_BYTES):
			assert(arena.release(arena_token) == &"", "only original token released")
		arena_token = 0
		original_entry = null
		room_ends += 1

class ObservedOrders extends FurnitureTests.SyntheticRegistration:

	var late_fault: int = 0
	var saved_batch: Sites.RoomClaimBatch = null
	var premature_publish: StringName = &""
	var premature_kernel: StringName = &""
	var refuse_after_identity: bool = false
	var post_identity_observers: int = 0
	var mutate_last_candidate: bool = false
	var final_candidate_observers: int = 0

	func is_publishing_room_admission(room: Vector2i, room_type: int) -> bool:
		"""A dispatch after identity but before the bank swap would make atomic admission fallible."""
		if _post_identity_observer():
			return false
		return super.is_publishing_room_admission(room, room_type)

	func room_candidate_refusal(candidate: Directory.CreateCandidate, room_type: int) -> StringName:
		"""The entry tail must use retained typed facts, not re-enter this abstract authority interface."""
		if _publishing and _space.has_prepared() and not _buildings.is_live_room(_stage_room):
			final_candidate_observers += 1
			if mutate_last_candidate:
				_entry_request.claims[0] += 1
		return &"SYNTHETIC_POST_IDENTITY_OBSERVER" if _post_identity_observer() \
			else super.room_candidate_refusal(candidate, room_type)

	func _post_identity_observer() -> bool:
		"""The later companion callback observes a complete publication, outside this prohibited window."""
		if not _buildings.is_live_room(_stage_room) or not _space.has_prepared():
			return false
		post_identity_observers += 1
		return refuse_after_identity

	func _prepare_room_claims() -> StringName:
		"""Production admission remains unchanged; faults happen after its actual Sites preparation."""
		var code: StringName = super._prepare_room_claims()
		if code != &"" or not _entry_mode:
			return code
		saved_batch = _room_claim_batch
		premature_publish = _room_sites.publish_room_claim_batch(saved_batch)
		premature_kernel = Sites.publish_entry_claim_preflighted(_room_sites, saved_batch, self)
		if late_fault == 1:
			_entry_claim_input.base_level += 1
		elif late_fault == 2:
			_entry_request.source_digests[0] += 1
		elif late_fault == 3:
			_entry_plan.opening_targets[0] += 1
		elif late_fault == 4:
			_room_candidate.persistent_id += 1
		return code

class ObservedBuildings extends Buildings:

	var late_receipt_observers: int = 0
	var revoke_on_receipt: bool = false

	func room_identity_into(room: Vector2i, out: PackedInt32Array) -> StringName:
		"""Reproduce a legitimate observation interface invalidating the original arena after allocation."""
		var actual: Orders = spatial_authority() as Orders
		if actual != null and actual._entry_mode and actual._publishing and actual._space.has_prepared():
			late_receipt_observers += 1
			if revoke_on_receipt:
				assert(actual._room_budget.release(actual._room_cold_token) == &"", "adversarial lease release")
		return super.room_identity_into(room, out)

class Fixture extends FurnitureTests.Fixture:

	func _create_buildings() -> Buildings:
		"""Keep the actual shared Directory and all Buildings storage, with one observed receipt interface."""
		return ObservedBuildings.new(residents.directory())

	func _configure_space() -> void:
		"""Swap the observed subclass before once-only binding; all storage and admission code stays real."""
		super._configure_space()
		orders = ObservedOrders.new()
		bindings.orders = weakref(orders)

var _f: Fixture = null
var _bindings: EntryBindings = null
var _orders: ObservedOrders = null


func before_each() -> void:
	"""Create fresh actual stores and explicitly synthetic geometric permission for each case."""
	_bindings = EntryBindings.new()
	_f = Fixture.new(self, false, _bindings)
	_orders = _f.orders as ObservedOrders


func after_each() -> void:
	"""Refused and successful transactions must drop all entry scratch and leave no leaked arena lease."""
	_f.audit()
	assert_false(_bindings.room_cold_held, "no entry lease escaped")
	assert_equal(_bindings.room_begins, _bindings.room_ends, "acquire/release balanced")
	assert_null(_orders._entry_plan, "no retained private entry packet")
	assert_null(_orders._entry_request, "caller no longer retained")
	assert_null(_f.sites._current_claim_batch(), "no retained Sites cursor")
	assert_equal(_orders._stage_action, -1, "coordinator returned idle")
	if _bindings.replacement_token > 0:
		assert_equal(_bindings.arena.release(_bindings.replacement_token), &"", "test releases foreign replacement")
	_orders = null
	_f = null
	_bindings = null


func _plan() -> EntryPlan.Request:
	"""Three varying-height overlapping boxes describe three unique cubes and retain an unclaimed gap."""
	var plan: EntryPlan.Request = EntryPlan.Request.new()
	plan.world = _f.world
	plan.space_revision = _f.space.revision()
	plan.base_level = 0
	plan.origin_u = Vector3i(0, -4096, 0)
	plan.rotation = 0
	plan.anchor = Vector2i(0, 1)
	plan.catalog_row = 0
	plan.catalog_revision = 1
	plan.variant_revision = 1
	plan.grouping_revision = 1
	plan.recipe_revision = 1
	plan.frontier_revision = 1
	plan.source_digests.resize(EntryPlan.SOURCE_BYTES)
	plan.source_digests.fill(17)
	plan.claims = PackedInt32Array([0, -4096, 0, 512, -3072, 512,
		256, -3840, 256, 1024, -2816, 1024, 1024, -3072, 1024, 1536, -2560, 1536])
	plan.opening_targets = PackedInt32Array([-1, 0, -1, 0, -1, 0, -1, 0])
	return plan


func _image() -> PackedByteArray:
	"""Compare all live identities, Room columns, spatial claims, Sites history and accounting stores."""
	var image: PackedByteArray = _f.residents.directory().state_bytes()
	image.append_array(_f.image())
	image.append_array(_f.sites.state_bytes())
	for property: Dictionary in _f.buildings.get_property_list():
		var value: Variant = _f.buildings.get(property["name"])
		if value is PackedByteArray:
			image.append_array(value)
		elif value is PackedInt32Array or value is PackedInt64Array:
			image.append_array(value.to_byte_array())
	return image


func _assert_refused(plan: EntryPlan.Request, label: String) -> void:
	"""A rejection must preserve exact authoritative bytes, not merely the Room count."""
	var before: PackedByteArray = _image()
	assert_false(_orders.confirm_entry(plan).ok, label)
	assert_true(_image() == before, "all live bytes unchanged: " + label)


func test_nonflat_entry_allocates_one_corridor_and_only_unique_solid_sites() -> void:
	"""Admission has permanent purpose but grants no excavation, labor, goods or traversable air."""
	var goods: PackedByteArray = _f.inventory.state_bytes()
	var room: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(room.ok, "actual entry transaction: %s" % room.error)
	assert_equal(_f.buildings.type_of_room(room.ref).value, Buildings.ROOM_TYPE_CORRIDOR, "permanent Corridor")
	assert_equal(_f.buildings.live_room_count(), 1, "one actual Room identity")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "three distinct paid physical keys")
	for origin: Vector3i in [Vector3i(0, -4096, 0), Vector3i(0, -3072, 0), Vector3i(1024, -3072, 1024)]:
		var site: Vector2i = _f.sites.site_at(origin)
		assert_true(_f.sites.phase_into(site, _f.math), "exact physical cut reserved")
		assert_equal(_f.math.value, Sites.SOLID, "unexcavated")
		assert_equal(Vector2i(_f.sites._room_slot[site.x], _f.sites._room_generation[site.x]), room.ref, "full Corridor identity")
	assert_equal(_f.sites.site_at(Vector3i(1024, -4096, 1024)), NULL_REF, "gap below higher box remains solid/unclaimed")
	assert_equal(_f.sites.virgin_sourced_milli(), 0, "no free spoil")
	assert_true(_f.inventory.state_bytes() == goods, "no material charge or produced lot")
	assert_equal(_bindings.room_publications, 1, "one same-stack companion publication")
	assert_true(_bindings.observed_pure, "publication proof observes no binding callbacks")
	assert_equal(_bindings.scopes, _bindings.publication_scopes, "no post-receipt cold observer")


func test_section_is_metadata_and_exact_claim_boxes_keep_all_heights() -> void:
	"""The union's empty bounding-box corners must not become obstacles, usable floors or excavated volume."""
	var plan: EntryPlan.Request = _plan()
	var room: Buildings.OpResult = _orders.confirm_entry(plan)
	assert_true(room.ok, "actual varying-height Corridor")
	var region: SpaceOwner.Region = SpaceOwner.Region.new()
	assert_equal(_f.space.region_into(_bindings.published_section, region), &"", "actual metadata section")
	assert_equal(region.role, Space.FLOOR_DATUM, "metadata only")
	assert_equal(region.owner, room.ref, "exact owner")
	assert_equal(region.box, PackedInt32Array([0, -4096, 0, 1536, -4095, 1536]), "explicit datum, no filled air")
	var rows: PackedInt32Array = PackedInt32Array()
	assert_equal(_f.space.overlapping_regions_into(PackedInt32Array([0, -4096, 0, 1536, -2560, 1536]), rows), &"", "real sparse lookup")
	var claims: int = 0
	for offset: int in range(0, rows.size(), 2):
		assert_equal(_f.space.region_into(Vector2i(rows[offset], rows[offset + 1]), region), &"", "actual row")
		if region.role != Space.OBSTACLE:
			continue
		assert_equal(region.claim_kind, SpaceOwner.CLAIM_ROOM, "reservation only")
		assert_equal(region.claim_ref, room.ref, "reserved by exact Corridor")
		assert_equal(region.box, plan.claims.slice(claims * 6, (claims + 1) * 6), "box preserved without flattening")
		claims += 1
	assert_equal(claims, 3, "each submitted box retained exactly")


func test_request_shape_refuses_before_cold_admission() -> void:
	"""Missing digests, malformed boxes and incomplete destination tuples never allocate a private packet."""
	_assert_refused(null, "null packet")
	var malformed: Array[Dictionary] = [
		{"world": NULL_REF}, {"base_level": -1}, {"rotation": 4}, {"anchor": NULL_REF},
		{"catalog_row": -1}, {"catalog_revision": 0}, {"variant_revision": 0}, {"grouping_revision": 0},
		{"recipe_revision": 0}, {"frontier_revision": 0}, {"source_digests": PackedByteArray()},
		{"claims": PackedInt32Array()}, {"claims": PackedInt32Array([0, 0, 0, 1, 1])},
		{"claims": PackedInt32Array([0, 0, 0, 0, 1, 1])}, {"opening_targets": PackedInt32Array()},
		{"opening_targets": PackedInt32Array([-1, 0, 0, 1])}]
	for change: Dictionary in malformed:
		var plan: EntryPlan.Request = _plan()
		for key: String in change:
			plan.set(key, change[key])
		_assert_refused(plan, "malformed field %s" % change.keys()[0])
	assert_equal(_bindings.room_begins, 0, "no cold lease/copy for malformed input")
	assert_equal(_f.space.stage_calls, 0, "no sparse candidate copied")


func test_stale_world_or_space_revision_never_borrows_another_namespace() -> void:
	"""A full generation and exact observed topology revision identify this entry's physical namespace."""
	var plan: EntryPlan.Request = _plan()
	plan.world.y += 1
	_assert_refused(plan, "foreign World generation")
	plan = _plan()
	plan.space_revision += 1
	_assert_refused(plan, "stale Space revision")
	assert_equal(_bindings.room_begins, 0, "mismatched owner refused before cold acquisition")


func test_default_entry_binding_refuses_without_fallback_to_flat_geometry() -> void:
	"""Existing flat providers do not implicitly grant new non-flat frontier or Placement authority."""
	var actual: FurnitureTests.Fixture = FurnitureTests.Fixture.new(self, false)
	var plan: EntryPlan.Request = _plan()
	plan.world = actual.world
	plan.space_revision = actual.space.revision()
	var before: PackedByteArray = actual.residents.directory().state_bytes()
	assert_false(actual.orders.confirm_entry(plan).ok, "unbound entry provider refuses")
	assert_true(actual.residents.directory().state_bytes() == before, "no entry identity spent")
	assert_equal(actual.space.stage_calls, 0, "no flat fallback")
	actual.audit()


func test_cold_denial_and_callback_growth_precede_any_copied_claims() -> void:
	"""Revalidate after admission observers, even if the initial request shape was legal."""
	_bindings.deny_room_cold = true
	_assert_refused(_plan(), "cold arena denied")
	_bindings.deny_room_cold = false
	_bindings.cold_mutation = true
	_assert_refused(_plan(), "callback appended malformed box")
	assert_equal(_f.space.stage_calls, 0, "no candidate copies under denied/malformed lease")
	_bindings.cold_mutation = false
	assert_true(_orders.confirm_entry(_plan()).ok, "fresh retry after released rejected scope")


func test_every_source_and_placement_pin_is_rechecked_after_preparation() -> void:
	"""Caller changes cannot be laundered through unchanged boxes or a matching numeric token."""
	var mutations: Dictionary = {"world": Vector2i(100, 1), "space_revision": 2, "base_level": 1,
		"origin_u": Vector3i(1, -4096, 0), "rotation": 1, "anchor": Vector2i(1, 1), "catalog_row": 1,
		"catalog_revision": 2, "variant_revision": 2, "grouping_revision": 2, "recipe_revision": 2,
		"frontier_revision": 2, "source_digests": PackedByteArray(), "claims": PackedInt32Array(),
		"opening_targets": PackedInt32Array([0, 1, 0, 1])}
	for key: String in mutations:
		_bindings.property_to_change = StringName(key)
		_bindings.changed_value = mutations[key]
		_assert_refused(_plan(), "changed request field " + key)
	_bindings.property_to_change = &""
	assert_true(_orders.confirm_entry(_plan()).ok, "untampered fresh packet retries")


func test_private_packet_and_future_candidate_mutation_refuse_without_spending_identity() -> void:
	"""Provider-visible copies and the exact Directory candidate cannot be replaced or mutated late."""
	_bindings.change_private = true
	_bindings.property_to_change = &"rotation"
	_bindings.changed_value = 1
	_assert_refused(_plan(), "private rotation changed")
	_bindings.property_to_change = &""
	_bindings.tamper_candidate = true
	_assert_refused(_plan(), "future persistent identity changed")
	_bindings.tamper_candidate = false
	assert_true(_orders.confirm_entry(_plan()).ok, "same unspent next Room slot can succeed")


func test_unqualified_or_changed_frontier_publishes_nothing() -> void:
	"""A legal box union is insufficient when the actual frontier/Placement source denies admission."""
	_bindings.block_plan = true
	_assert_refused(_plan(), "frontier unqualified")
	_bindings.block_plan = false
	_bindings.block_prepared = true
	_assert_refused(_plan(), "frontier changed after preparation")
	_bindings.block_prepared = false
	_bindings.unbind_after_preparation = true
	_assert_refused(_plan(), "actual provider unbound")
	_bindings.wired = true
	_bindings.unbind_after_preparation = false
	assert_true(_orders.confirm_entry(_plan()).ok, "fresh qualified synthetic proof retries")


func test_reentry_and_direct_future_room_creation_cannot_steal_the_entry_stage() -> void:
	"""Neither flat confirmation nor another entry can nest inside an exclusive prospective Room."""
	_bindings.probe_reentry = true
	assert_true(_orders.confirm_entry(_plan()).ok, "outer exact entry still succeeds")
	assert_true(_bindings.entry_reentry, "nested entry refused")
	assert_true(_bindings.flat_reentry, "nested flat room refused")
	assert_true(_bindings.direct_create_refused, "future identity cannot be spent inside observer")
	assert_equal(_f.buildings.live_room_count(), 1, "only authorized outer Corridor")


func test_replaced_original_lease_is_not_released_or_used_for_publication() -> void:
	"""A second token from the real arena is a different operation, even when it covers the same bytes."""
	for boundary: int in [1, 2, 3]:
		_bindings.replace_at = boundary
		_assert_refused(_plan(), "original lease replaced at %d" % boundary)
		assert_true(_bindings.arena.covers(_bindings.replacement_token, Budget.COLD_BYTES), "foreign lease survives")
		assert_equal(_bindings.arena.release(_bindings.replacement_token), &"", "test releases replacement")
		_bindings.replacement_token = 0
	assert_true(_orders.confirm_entry(_plan()).ok, "new independent operation can then acquire")


func test_final_pure_guard_catches_mutation_after_sites_preparation() -> void:
	"""No source observer separates whole-request/claim/candidate proof from actual identity allocation."""
	for fault: int in [1, 2, 3, 4]:
		_orders.late_fault = fault
		_assert_refused(_plan(), "late input/candidate mutation %d" % fault)
	_orders.late_fault = 0
	assert_true(_orders.confirm_entry(_plan()).ok, "fresh untampered operation retries")


func test_future_and_consumed_claim_batches_cannot_publish_twice() -> void:
	"""Retaining a batch object does not retain authority or its cold packed buffers."""
	assert_true(_orders.confirm_entry(_plan()).ok, "actual entry confirmation")
	assert_true(_orders.premature_publish != &"", "cannot publish before identity receipt")
	assert_true(_orders.premature_kernel != &"", "entry kernel also requires actual identity receipt")
	assert_true(_orders.saved_batch._boxes.is_empty() and _orders.saved_batch._entry_cursor == null, "scratch dropped")
	var before: PackedByteArray = _image()
	assert_true(_f.sites.publish_room_claim_batch(_orders.saved_batch) != &"", "cannot reuse consumed batch")
	assert_true(Sites.publish_entry_claim_preflighted(_f.sites, _orders.saved_batch, _orders) != &"", "kernel cannot reuse consumed batch")
	assert_true(_image() == before, "no second claim set or duplicate identity")


func test_entry_publication_never_reenters_authority_after_identity() -> void:
	"""A late refusing authority interface must be unreachable, not tolerated after spending a Room PID."""
	_orders.refuse_after_identity = true
	assert_true(_orders.confirm_entry(_plan()).ok, "receipt-only entry tail completes")
	assert_equal(_orders.post_identity_observers, 0, "no abstract authority observers after allocation")
	assert_equal(_f.buildings.live_room_count(), 1, "one complete identity")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "all exact claims published")
	assert_equal(_bindings.room_publications, 1, "prepared companion publishes after Space")
	assert_false(_f.space.has_prepared(), "complete sparse bank swap")
	assert_equal(_f.space.revision(), 2, "single geometry publication")


func test_entry_final_guard_and_receipt_use_concrete_facts_without_observer_dispatch() -> void:
	"""Late input mutation or lease revocation cannot run between the last proof and its permanent writes."""
	_orders.mutate_last_candidate = true
	var buildings: ObservedBuildings = _f.buildings as ObservedBuildings
	buildings.revoke_on_receipt = true
	var plan: EntryPlan.Request = _plan()
	var first_x: int = plan.claims[0]
	assert_true(_orders.confirm_entry(plan).ok, "concrete final leaf and publication complete")
	assert_equal(plan.claims[0], first_x, "no final authority dispatch can mutate the caller")
	assert_equal(_orders.final_candidate_observers, 0, "no candidate observer after last input proof")
	assert_equal(buildings.late_receipt_observers, 0, "no Buildings receipt observer after allocation")
	assert_equal(_f.buildings.live_room_count(), 1, "one complete identity")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "complete actual claim set")
	assert_false(_f.space.has_prepared(), "no half-published geometry")


func test_final_companion_refusal_and_mutation_leave_prepared_sites_unpublished() -> void:
	"""Sites callbacks cannot bypass the last actual prepared Placement/source proof before Room allocation."""
	_bindings.refuse_final = true
	_assert_refused(_plan(), "final prepared companion became stale")
	_bindings.refuse_final = false
	_bindings.mutate_final = true
	_assert_refused(_plan(), "final observer changed pinned original input")
	_bindings.mutate_final = false
	assert_true(_orders.confirm_entry(_plan()).ok, "fresh exact companion and packet can retry")


func test_out_of_domain_claim_or_metadata_refuses_atomically() -> void:
	"""The claim and explicit section datum must both fit the actual finite World domain."""
	var plan: EntryPlan.Request = _plan()
	plan.claims[0] = -1
	_assert_refused(plan, "claim extends outside World")
	plan = _plan()
	plan.origin_u.y = Space.I32_MAX
	_assert_refused(plan, "metadata datum addition overflows")
	plan = _plan()
	plan.origin_u.y = -8193
	_assert_refused(plan, "metadata below actual World bounds")


func test_another_confirmed_room_cannot_capture_reserved_entry_volume() -> void:
	"""A second Corridor over an admitted staircase is refused without another Room identity or paid keys."""
	assert_true(_orders.confirm_entry(_plan()).ok, "first Corridor reserves exact volume")
	_assert_refused(_plan(), "overlapping second Corridor")
	assert_equal(_f.buildings.live_room_count(), 1, "sole original identity")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "sole original paid cut union")


func test_entry_packet_copies_all_fields_without_aliasing_packed_inputs() -> void:
	"""Cold packet accounting counts exact scalar/hash/array payload and rejects partial target tuples."""
	var original: EntryPlan.Request = _plan()
	var pinned: EntryPlan.Request = EntryPlan.Request.new()
	EntryPlan.copy_into(original, pinned)
	assert_true(EntryPlan.same(original, pinned), "every entry field copied")
	assert_equal(EntryPlan.payload_bytes(pinned), 100 + 128 + 72 + 32, "one complete payload")
	assert_equal(Orders.entry_packet_cold_bytes(pinned), Sites.entry_claim_cold_bytes(3) + 3 * 160 + 2048, "cold packet peak")
	original.claims[0] += 1
	assert_false(EntryPlan.same(original, pinned), "claim bytes separately pinned")
	assert_equal(pinned.claims[0], 0, "private claims not aliased")
	original.source_digests[0] += 1
	assert_equal(pinned.source_digests[0], 17, "private digests not aliased")
	original.opening_targets[0] = 0
	assert_equal(pinned.opening_targets[0], -1, "private targets not aliased")
