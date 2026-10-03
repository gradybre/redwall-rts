extends "res://test/framework/test_case.gd"
## Exact Room authority composition. Actual storage is real; admission/contact qualification is synthetic.

const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const FurnitureWork := preload("res://scripts/core/underground_furniture_work.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const FixtureScript := preload("res://test/test_underground_furniture_work.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class RoomBindings extends FixtureScript.SyntheticBindings:
	## Actual identity/Space/Budget publication, with explicitly SYNTHETIC terrain/profile/cut-map proof.
	var arena: Budget = Budget.new()
	var arena_token: int = 0
	var replacement_token: int = 0
	var replace_at: int = 0
	var original_plan: RoomOrders.RoomPlan = null
	var deny_room_cold: bool = false
	var room_cold_held: bool = false
	var room_cold_foreign_stage: bool = false
	var room_begins: int = 0
	var room_ends: int = 0
	var pending_room: Vector2i = NULL_REF
	var pending_type: int = -1
	var pending_token: int = 0
	var block_plan: bool = false
	var block_prepared: bool = false
	var unbind_after_preparation: bool = false
	var tamper_candidate: bool = false
	var tamper_snapshot: bool = false
	var intervene_identity: bool = false
	var external_directory: PackedByteArray = PackedByteArray()
	var probe_reentry: bool = false
	var reentry_refused: bool = false
	var direct_create_refused: bool = false
	var probe_publication_binding: bool = false
	var publication_binding_calls: int = 0
	var probe_entry_binding: bool = false
	var entry_binding_calls: int = 0
	var entry_reentry_refused: bool = false
	var refuse_second_binding: bool = false
	var entry_plan: RoomOrders.RoomPlan = null
	var room_publications: int = 0
	var exact_room_windows: PackedByteArray = PackedByteArray()
	var wrong_room_windows: PackedByteArray = PackedByteArray()

	func exact_binding(buildings: Buildings, candidate: SpaceOwner, actual: Construction,
			world_ref: Vector2i) -> bool:
		"""An adversarial provider would mutate the plan if its callback leaked into Room publication."""
		var coordinator: RoomOrders = orders.get_ref() as RoomOrders if orders != null else null
		if probe_entry_binding and coordinator != null:
			entry_binding_calls += 1
			if entry_binding_calls == 1:
				entry_reentry_refused = coordinator.confirm_room(entry_plan).error == RoomOrders.REFUSE_TRANSITION
			if refuse_second_binding and entry_binding_calls == 2:
				return false
		if probe_publication_binding and coordinator != null and coordinator._publishing \
				and coordinator._stage_action == RoomOrders.ROOM_ADMISSION_STAGE:
			publication_binding_calls += 1
			coordinator._room_plan.cells[0] += 1
		if room_cold_held:
			_replace_lease(1)
		return super.exact_binding(buildings, candidate, actual, world_ref)

	func layout_budget_owner() -> Budget:
		"""The synthetic permission fixture still uses the real exact-token memory owner."""
		return arena

	func begin_room_cold(plan: RoomOrders.RoomPlan) -> StringName:
		"""Real peak admission precedes copied cells; only geometric permission remains synthetic."""
		if deny_room_cold:
			return &"SYNTHETIC_ROOM_COLD_DENIED"
		if room_cold_held or cold_action != -1:
			return &"SYNTHETIC_ROOM_COLD_BUSY"
		arena_token = arena.acquire(Budget.COLD_BYTES)
		if arena_token == 0:
			return Budget.REFUSE_BUSY
		original_plan = plan
		room_cold_held = true
		room_cold_foreign_stage = space.has_prepared()
		room_begins += 1
		return &""

	func room_cold_token() -> int:
		"""Borrow only the retained token, not a replacement acquired by an adversarial callback."""
		return arena_token

	func room_cold_refusal(plan: RoomOrders.RoomPlan, token: int) -> StringName:
		"""Actual arena, exact request and full token must remain current throughout confirmation."""
		_replace_lease(2)
		return &"" if room_cold_held and plan == original_plan and token == arena_token \
			and arena.covers(token, Budget.COLD_BYTES) else RoomOrders.REFUSE_ROOM_COLD

	func _replace_lease(boundary: int) -> void:
		"""A fresh token from the same real arena cannot authorize an already admitted copy or commit."""
		if replace_at != boundary:
			return
		replace_at = 0
		assert(arena.release(arena_token) == &"", "exact old token released")
		replacement_token = arena.acquire(Budget.COLD_BYTES)
		assert(replacement_token != arena_token and replacement_token > 0, "new lease is distinct")

	func room_plan_refusal(plan: RoomOrders.RoomPlan, room: Vector2i, token: int) -> StringName:
		"""Scope the synthetic actual-geometry proof; it is deliberately not a production cut-map provider."""
		pending_room = room
		pending_type = plan.room_type
		pending_token = token
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		exact_room_windows.append(1 if actual.is_publishing_room_admission(room, pending_type) else 0)
		if probe_reentry:
			reentry_refused = not actual.confirm_room(plan).ok
			actual.discard_transition(NULL_REF, RoomOrders.ROOM_ADMISSION_STAGE)
			direct_create_refused = not construction.buildings().designate_spatial_room_candidate(
				pending_type, actual._room_candidate).ok
		return &"SYNTHETIC_WHOLE_CUT_COVERAGE_UNPROVED" if block_plan else &""

	func room_prepared_refusal(plan: RoomOrders.RoomPlan, _room: Vector2i, _token: int) -> StringName:
		"""Inject real stale-candidate and request-drift cases after the spatial candidate was sealed."""
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		_replace_lease(3)
		if tamper_candidate:
			actual._room_candidate.persistent_id += 1
		if tamper_snapshot:
			plan.cells[0] += 1
		if intervene_identity:
			var intervening: Vector2i = construction.directory().create(Directory.KIND_BUILDING)
			assert(construction.directory().destroy(intervening), "external identity retired")
			external_directory = construction.directory().state_bytes()
		if unbind_after_preparation:
			wired = false
		return &"SYNTHETIC_ROOM_SOURCE_CHANGED" if block_prepared else &""

	func discard_room_plan(room: Vector2i, token: int) -> void:
		"""Failed early stages may own no companion yet; an existing one must match both identities."""
		assert(pending_room == NULL_REF or pending_room == room and pending_token == token, "exact companion discard")
		_clear_room_companion()

	func publish_room_plan(room: Vector2i, token: int) -> void:
		"""Record real live Room/source facts only during the exact production coordinator callback."""
		assert(room == pending_room and token == pending_token, "exact room companion publication")
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		assert(construction.buildings().is_live_room(room) and space.source_refusal(room) == &"", "actual owners already committed")
		exact_room_windows.append(1 if actual.is_publishing_room_admission(room, pending_type) else 0)
		wrong_room_windows.append(1 if actual.is_publishing_room_admission(Vector2i(room.x, room.y + 1), pending_type) else 0)
		wrong_room_windows.append(1 if actual.is_publishing_room_admission(room, (pending_type + 1) % Buildings.ROOM_TYPE_COUNT) else 0)
		room_publications += 1
		_clear_room_companion()

	func _clear_room_companion() -> void:
		"""Drop companion scratch before the provider's current shared peak is released."""
		pending_room = NULL_REF
		pending_type = -1
		pending_token = 0

	func end_room_cold() -> void:
		"""Assert copied coordinator/Space/companion scratch is already gone; preserve any foreign token."""
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		assert(room_cold_held, "exact room lease remains held")
		assert(pending_room == NULL_REF, "companion dropped before release")
		assert(not space.has_prepared() or room_cold_foreign_stage, "own geometry scratch dropped before release")
		assert(actual._room_plan.cells.is_empty() and actual._room_candidate.ref == NULL_REF, "plan/identity scratch dropped")
		room_cold_held = false
		if arena.covers(arena_token, Budget.COLD_BYTES):
			assert(arena.release(arena_token) == &"", "only retained exact lease releases")
		arena_token = 0
		original_plan = null
		room_ends += 1

class ForeignPurpose extends Contract.Owner:
	## Only an adversarial purpose-owner binding, never used for paid work or a successful quote.
	var actual: Construction = null
	var world: Vector2i = NULL_REF

	func construction_owner() -> RefCounted:
		"""Expose the exact real owner so the test reaches the already-bound-purpose refusal."""
		return actual

	func world_ref() -> Vector2i:
		"""Return the actual World; numeric mismatch is not needed to test atomic preflight."""
		return world

	func purpose() -> int:
		"""Reserve the real Furniture purpose through the actual router for the adversarial test."""
		return Construction.PURPOSE_SPATIAL_FURNITURE

var _f: FixtureScript.Fixture = null
var _room_bindings: RoomBindings = null


func before_each() -> void:
	"""Set up actual owners but leave Furniture purpose unbound for atomic composition tests."""
	_room_bindings = RoomBindings.new()
	_f = FixtureScript.Fixture.new(self, false, _room_bindings)


func after_each() -> void:
	"""Audit actual material stores and release weak reverse-link composition without leaks."""
	_f.audit()
	assert_false(_room_bindings.room_cold_held, "no retained room cold lease")
	assert_equal(_room_bindings.room_begins, _room_bindings.room_ends, "room peak releases balance")
	assert_true(_f.orders._room_plan.cells.is_empty(), "no retained copied room cells")
	assert_equal(_f.orders._room_candidate.ref, NULL_REF, "no retained future identity")
	_f = null
	_room_bindings = null


func test_default_bindings_and_refused_initializers_grant_no_geometry_or_service_permission() -> void:
	"""A typed base interface is no trusted success fallback; failed owners expose no usable binding."""
	var empty: RoomOrders = RoomOrders.new()
	assert_equal(empty.configure(null, null, null, null, null), RoomOrders.REFUSE_BINDING, "null composition refuses")
	assert_null(empty.construction_owner(), "failed initializer has no accounting owner")
	assert_equal(empty.world_ref(), NULL_REF, "failed initializer has no World identity")
	assert_true(empty.binding_refusal() != &"", "failed initializer is explicitly unavailable")
	assert_false(empty.area_of_room(Vector2i(0, 1)).ok, "unknown room area is unavailable")
	assert_true(empty.service_refusal(Vector2i(0, 1)) != &"", "unknown room is not service-ready")
	assert_false(empty.is_publishing(NULL_REF, Contract.COMMIT, NULL_REF, NULL_REF), "null publication never qualifies")
	var base: RoomOrders.Bindings = RoomOrders.Bindings.new()
	assert_equal(empty.configure(_f.router, _f.space, _f.sources, _f.catalog, base), RoomOrders.REFUSE_BINDING, "default contact binding refuses")
	assert_true(_f.buildings.spatial_authority() == _f.orders, "refusal does not replace actual authority")
	assert_null(empty.buildings_owner(), "refused preflight retains no binding")


func test_foreign_same_number_world_and_source_reader_never_match_actual_composition() -> void:
	"""Independent actual worlds intentionally reuse ref numbers; object identity still refuses."""
	var foreign: FixtureScript.Fixture = FixtureScript.Fixture.new(self, false)
	assert_equal(foreign.world, _f.world, "adversarial Worlds have identical numeric refs")
	var candidate: RoomOrders = RoomOrders.new()
	assert_equal(candidate.configure(_f.router, foreign.space, foreign.sources, _f.catalog, foreign.bindings), RoomOrders.REFUSE_BINDING, "foreign source composition refuses")
	var same_numbers: SpaceOwner.CoreSources = SpaceOwner.CoreSources.new(_f.buildings.directory(), _f.buildings, _f.construction)
	assert_equal(candidate.configure(_f.router, _f.space, same_numbers, _f.catalog, _f.bindings), RoomOrders.REFUSE_BINDING, "replacement same-world source reader refuses")
	assert_null(candidate.construction_owner(), "refused authority exposes no valid owner")
	assert_true(_f.buildings.spatial_authority() == _f.orders, "own exact Buildings binding unchanged")
	assert_true(foreign.buildings.spatial_authority() == foreign.orders, "foreign exact Buildings binding untouched")
	foreign.audit()


func test_furniture_binding_preflight_cannot_strand_a_room_authority_after_router_refusal() -> void:
	"""An existing purpose binding is discovered before publishing the second weak Room link."""
	var occupying: ForeignPurpose = ForeignPurpose.new()
	occupying.actual = _f.construction
	occupying.world = _f.world
	assert_true(_f.router.bind_owner(occupying).ok, "actual Router purpose already occupied")
	assert_true(_f.owner.configure(_f.router, _f.orders) != &"", "second purpose owner refuses")
	assert_null(_f.owner.construction_owner(), "failed unpublished Furniture wiring clears")
	assert_equal(_f.orders.furniture_owner_binding_refusal(occupying), &"", "Room link remains free after Router preflight refusal")
	assert_false(_f.orders.is_bound_furniture_owner(occupying), "no half-bound Room purpose")
	assert_true(_f.router.is_bound_owner(occupying), "original actual Router owner retained")


func test_exact_furniture_owner_binds_once_and_expired_weak_target_cannot_be_replaced() -> void:
	"""An expired owner is missing authority, never an invitation to reset retained project ownership."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual composed binding")
	assert_true(_f.orders.is_bound_furniture_owner(_f.owner), "exact live purpose attested")
	assert_true(_f.owner.binding_refusal() == &"", "actual owner ready")
	var other: FurnitureWork = FurnitureWork.new()
	assert_true(other.configure(_f.router, _f.orders) != &"", "replacement purpose refuses")
	assert_null(other.construction_owner(), "failed second owner has no partial composition")
	assert_false(_f.orders.is_bound_furniture_owner(null), "null owner never qualifies")
	_f.owner = null
	assert_true(other.configure(_f.router, _f.orders) != &"", "expired binding still cannot be replaced")
	assert_false(_f.orders.is_bound_furniture_owner(other), "new object cannot adopt old retained authority")


func test_room_area_is_exact_but_presence_never_grants_whole_room_service_validity() -> void:
	"""The actual Room identity owns positive floor area; count and service qualification stay distinct."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual purpose binding")
	var room: Vector2i = _f.make_room(Buildings.ROOM_TYPE_DORMITORY)
	var area: Buildings.OpResult = _f.orders.area_of_room(room)
	assert_true(area.ok, "actual Room receives explicit synthetic physical area")
	assert_equal(area.ref, room, "full Room generation accompanies area")
	assert_equal(area.value, 8192 * 8192, "exact units squared; zero TileLinks is not zero area")
	assert_false(_f.orders.area_of_room(Vector2i(room.x, room.y + 1)).ok, "stale area refuses")
	assert_true(_f.orders.service_refusal(room) != &"", "service physical qualification deliberately absent")
	assert_false(_f.buildings.set_room_valid(room, true).ok, "caller cannot manufacture a whole-room service flag")
	assert_false(_f.buildings.room_is_valid(room), "no usable room service published")


func test_legacy_room_removal_retyping_and_item_mutations_cannot_borrow_furniture_authority() -> void:
	"""A complete or empty Room retains its permanent purpose until real removal/rebuild owns the transition."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual Furniture purpose")
	var room: Vector2i = _f.make_room()
	var item: Vector2i = _f.pending()
	var before: PackedByteArray = _f.image()
	assert_false(_f.buildings.remove_room(room).ok, "room demolition needs its own actual physical workflow")
	assert_false(_f.buildings.reassign_furniture(item, room).ok, "pending item cannot use legacy reassignment")
	assert_false(_f.buildings.install_spatial_furniture(item).ok, "direct installed setter denied")
	assert_equal(_f.buildings.type_of_room(room).value, Buildings.ROOM_TYPE_KITCHEN, "purpose remains Kitchen")
	assert_true(_f.image() == before, "unauthorized operations change no actual owner state")


func _plan(cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1]), pitch: int = 256) -> RoomOrders.RoomPlan:
	"""Explicit finer-grid fixture, not an adopted physical height, paint pitch or cut-map provider."""
	var plan: RoomOrders.RoomPlan = RoomOrders.RoomPlan.new()
	plan.world = _f.world
	plan.space_revision = _f.space.revision()
	plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	plan.level = 0
	plan.origin_u = Vector3i(512, -4096, 1024)
	plan.cell_size_u = pitch
	plan.height_u = 896
	plan.cells = cells.duplicate()
	return plan


func _admission_image() -> PackedByteArray:
	"""Include actual allocator and every Buildings column, not only underground discriminators."""
	var out: PackedByteArray = _f.residents.directory().state_bytes()
	out.append_array(_f.image())
	for property: Dictionary in _f.buildings.get_property_list():
		var field: Variant = _f.buildings.get(property["name"])
		if field is PackedByteArray:
			out.append_array(field)
		elif field is PackedInt32Array or field is PackedInt64Array:
			out.append_array(field.to_byte_array())
	out.append_array(PackedInt64Array([_f.buildings.live_room_count(), _f.buildings.room_tile_links_used()]).to_byte_array())
	return out


func _owned_regions(room: Vector2i) -> Array[SpaceOwner.Region]:
	"""Read only real published sparse handles and full owner refs for exact marker comparisons."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_f.space.overlapping_regions_into(_f.space.domain_copy().descriptor().bounds_u, handles), &"", "actual published survey")
	var out: Array[SpaceOwner.Region] = []
	for at: int in range(0, handles.size(), 2):
		var region: SpaceOwner.Region = SpaceOwner.Region.new()
		assert_equal(_f.space.region_into(Vector2i(handles[at], handles[at + 1]), region), &"", "actual generation-qualified region")
		if region.owner == room:
			out.append(region)
	return out


func _claims_at(room: Vector2i, box: PackedInt32Array) -> int:
	"""Probe actual claim intersection without inferring a room's area from its bounding rectangle."""
	var count: int = 0
	for region: SpaceOwner.Region in _owned_regions(room):
		if region.claim_kind == SpaceOwner.CLAIM_ROOM and Space.overlaps(region.box, box):
			count += 1
	return count


func _section_record(room: Vector2i, expected_box: PackedInt32Array, level: int) -> SpaceOwner.Region:
	"""Only metadata spans the bounds; every actual fine claim retains the one full section identity."""
	var section: SpaceOwner.Region = null
	var rows: Array[SpaceOwner.Region] = _owned_regions(room)
	for region: SpaceOwner.Region in rows:
		if region.role == Space.FLOOR_DATUM:
			assert_null(section, "exactly one metadata section for this confirmation")
			section = region
	assert_true(section != null, "actual metadata section exists")
	if section == null:
		return null
	assert_equal(section.box, expected_box, "metadata bounds are exact and one unit high")
	assert_true(_f.space.is_live_region(section.section), "floor self-link is full generation-qualified handle")
	assert_equal(section.owner, room, "actual full Room owns metadata")
	assert_equal(section.claim_kind, SpaceOwner.CLAIM_NONE, "metadata is not an occupied reservation")
	assert_equal(section.claim_ref, NULL_REF, "no implicit claim over envelope or holes")
	assert_equal(section.level, level, "authored level retained")
	for region: SpaceOwner.Region in rows:
		assert_equal(region.section, section.section, "every exact claim links this full section")
		assert_equal(region.level, level, "claim and section level agree")
	return section


func _assert_exact_concave_claims(room: Vector2i, level: int) -> void:
	"""Metadata bounds and exact claim boxes deliberately have different occupancy meanings."""
	var rows: Array[SpaceOwner.Region] = _owned_regions(room)
	assert_equal(rows.size(), 3, "one metadata section plus two unchanged exact row runs")
	var boxes: Array[PackedInt32Array] = []
	for region: SpaceOwner.Region in rows:
		assert_true(region.role == Space.FLOOR_DATUM or region.role == Space.OBSTACLE, "never supported void or unfinished physical cut")
		if region.role == Space.OBSTACLE:
			assert_equal(region.claim_ref, room, "marker belongs to exact real Room")
			assert_equal(region.claim_kind, SpaceOwner.CLAIM_ROOM, "explicit typed reservation")
			boxes.append(region.box)
	assert_true(boxes.has(PackedInt32Array([512, -4096, 1024, 1024, -3200, 1280])), "first exact256u row run")
	assert_true(boxes.has(PackedInt32Array([512, -4096, 1280, 768, -3200, 1536])), "concave second row is not inflated")
	_section_record(room, PackedInt32Array([512, -4096, 1024, 1024, -4095, 1536]), level)
	assert_equal(_claims_at(room, PackedInt32Array([768, -4095, 1280, 1024, -4094, 1536])), 0, "absent concave corner remains absent")


func test_fine_concave_plan_creates_exact_room_claims_without_physical_cut_or_service() -> void:
	"""256u drawing survives byte-exactly; plan markers never count as completed1024u physical cubes."""
	var plan: RoomOrders.RoomPlan = _plan()
	var physical: PackedByteArray = _f.sites.state_bytes()
	var inventory: PackedByteArray = _f.inventory.state_bytes()
	var funding: PackedByteArray = _f.funding.state_bytes()
	var cursor: int = _f.residents.directory().next_persistent_id()
	var made: Buildings.OpResult = _f.orders.confirm_room(plan)
	assert_true(made.ok, "actual single-Room confirmation: %s" % made.error)
	assert_true(_f.buildings.is_live_room(made.ref), "actual full-generation Room")
	assert_equal(_f.residents.directory().next_persistent_id(), cursor + 1, "exactly one real identity spent")
	assert_equal(_f.buildings.room_building_ref_of(made.ref), NULL_REF, "no fake surface parent")
	assert_equal(_f.buildings.type_of_room(made.ref).value, plan.room_type, "permanent chosen purpose")
	assert_false(_f.buildings.room_is_valid(made.ref), "room remains an unbuilt plan")
	assert_equal(_f.buildings.room_tile_links_used(), 0, "no ground tile aliases")
	assert_equal(_f.construction.live_project_count(), 0, "confirmation creates no fake paid phase")
	assert_true(_f.sites.state_bytes() == physical, "no physical cut/history changed")
	assert_true(_f.inventory.state_bytes() == inventory and _f.funding.state_bytes() == funding, "no goods generated or consumed")
	_assert_exact_concave_claims(made.ref, plan.level)
	assert_equal(_room_bindings.exact_room_windows, PackedByteArray([0, 1]), "preparation closed, actual publication open")
	assert_equal(_room_bindings.wrong_room_windows, PackedByteArray([0, 0]), "wrong generation and purpose never qualify")
	assert_false(_f.orders.is_publishing_room_admission(made.ref, plan.room_type), "window closes after callback")
	assert_false(_f.buildings.remove_room(made.ref).ok, "legacy removal cannot erase accepted plan history")


func test_hole_is_preserved_by_fine_row_runs_instead_of_claiming_outer_rectangle() -> void:
	"""A permitted synthetic512u ring keeps its middle cell unclaimed; actual production hole policy still requires qualification."""
	var plan: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2]), 512)
	var made: Buildings.OpResult = _f.orders.confirm_room(plan)
	assert_true(made.ok, "exact ring confirms under explicit synthetic policy: %s" % made.error)
	assert_equal(_owned_regions(made.ref).size(), 5, "one metadata section and four runs preserve inner boundary")
	_section_record(made.ref, PackedInt32Array([512, -4096, 1024, 2048, -4095, 2560]), plan.level)
	assert_equal(_claims_at(made.ref, PackedInt32Array([1024, -4095, 1536, 1536, -4094, 2048])), 0, "middle cell unclaimed")
	assert_equal(_claims_at(made.ref, PackedInt32Array([512, -4095, 1536, 1024, -4094, 2048])), 1, "adjacent actual ring cell claimed")


func test_metadata_envelope_does_not_reserve_hole_or_grant_void_to_either_room() -> void:
	"""A distinct real Room can reserve the unclaimed ring hole; metadata overlap grants no physical work."""
	var ring: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2]), 512)
	var outer: Buildings.OpResult = _f.orders.confirm_room(ring)
	assert_true(outer.ok, "outer exact ring")
	var inner: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0]), 512)
	inner.origin_u = Vector3i(1024, -4096, 1536)
	inner.room_type = Buildings.ROOM_TYPE_DORMITORY
	var made: Buildings.OpResult = _f.orders.confirm_room(inner)
	assert_true(made.ok, "actual different Room inside unclaimed hole: %s" % made.error)
	var section: SpaceOwner.Region = _section_record(made.ref,
		PackedInt32Array([1024, -4096, 1536, 1536, -4095, 2048]), inner.level)
	assert_true(section != null, "inner Room has its own actual section")
	assert_equal(_claims_at(outer.ref, PackedInt32Array([1024, -4095, 1536, 1536, -4094, 2048])), 0, "outer bounds never become a claim")
	assert_equal(_claims_at(made.ref, PackedInt32Array([1024, -4095, 1536, 1536, -4094, 2048])), 1, "inner exact outline alone is claimed")
	assert_false(_f.buildings.room_is_valid(outer.ref), "ring has no physical completion")
	assert_false(_f.buildings.room_is_valid(made.ref), "hole Room has no physical completion")
	for room: Vector2i in [outer.ref, made.ref]:
		for region: SpaceOwner.Region in _owned_regions(room):
			assert_true(region.role == Space.FLOOR_DATUM or region.role == Space.OBSTACLE, "neither bounds nor claims create physical void")
	assert_equal(_f.construction.live_project_count(), 0, "metadata admission does not create unpaid phases")


func test_section_bounds_scan_all_rows_and_preserve_negative_painted_indices() -> void:
	"""Nonrectangular extrema need all canonical rows, without changing the exact picked world transform."""
	var plan: RoomOrders.RoomPlan = _plan(PackedInt32Array([-2, -1, -1, -1, 0, -1, -1, 0, 0, 0, -1, 1]), 256)
	plan.origin_u = Vector3i(5120, -4096, 5120)
	var made: Buildings.OpResult = _f.orders.confirm_room(plan)
	assert_true(made.ok, "negative-index exact plan: %s" % made.error)
	_section_record(made.ref, PackedInt32Array([4608, -4096, 4864, 5376, -4095, 5632]), plan.level)
	assert_equal(_owned_regions(made.ref).size(), 4, "one section plus three fine runs")
	assert_equal(_claims_at(made.ref, PackedInt32Array([4608, -4095, 5376, 4864, -4094, 5632])), 0, "absent lower-left corner stays absent")
	assert_equal(_claims_at(made.ref, PackedInt32Array([4864, -4095, 5376, 5120, -4094, 5632])), 1, "actual final row remains claimed")


func test_exact_sparse_capacity_accepts_one_section_plus_all_claims() -> void:
	"""The shared datum avoids allocating one redundant section per row without changing finite capacity."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 63:
		cells.append_array(PackedInt32Array([0, z]))
	var plan: RoomOrders.RoomPlan = _plan(cells)
	plan.origin_u = Vector3i(0, -4096, 0)
	var made: Buildings.OpResult = _f.orders.confirm_room(plan)
	assert_true(made.ok, "63 exact runs plus one section fit actual64-row owner: %s" % made.error)
	assert_equal(_owned_regions(made.ref).size(), 64, "all real sparse rows are present")
	_section_record(made.ref, PackedInt32Array([0, -4096, 0, 256, -4095, 16128]), plan.level)
	assert_false(_f.buildings.room_is_valid(made.ref), "more economical metadata does not complete shell")


func test_same_xz_different_actual_heights_do_not_alias_but_level_label_cannot_hide_overlap() -> void:
	"""Occupancy is full XYZ; the selected level is metadata, not permission to overlap another floor."""
	var first: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0]), 512)
	var lower: Buildings.OpResult = _f.orders.confirm_room(first)
	assert_true(lower.ok, "lower planned Room")
	var overlap: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0]), 512)
	overlap.level = 1
	var before: PackedByteArray = _admission_image()
	assert_false(_f.orders.confirm_room(overlap).ok, "different label with identical world volume refuses")
	assert_true(_admission_image() == before, "overlap changes no owner byte")
	var above: RoomOrders.RoomPlan = _plan(PackedInt32Array([0, 0]), 512)
	above.level = 1
	above.origin_u.y = -2048
	var higher: Buildings.OpResult = _f.orders.confirm_room(above)
	assert_true(higher.ok, "separate actual elevation can reserve independently")
	assert_true(higher.ref != lower.ref, "distinct actual Room identities")
	for region: SpaceOwner.Region in _owned_regions(higher.ref):
		assert_equal(region.box[1], -2048, "exact authored world height retained")
		assert_equal(region.level, 1, "actual selected-level identity retained")


func test_room_cold_denial_occurs_before_any_domain_or_space_copy() -> void:
	"""The scarce shared cold peak is an admission gate, not a check after expensive validation."""
	_room_bindings.deny_room_cold = true
	var stage_calls: int = _f.space.stage_calls
	var domain_calls: int = _f.space.domain_calls
	var before: PackedByteArray = _admission_image()
	assert_equal(_f.orders.confirm_room(_plan()).error, &"SYNTHETIC_ROOM_COLD_DENIED", "denied before allocation")
	assert_equal(_f.space.stage_calls, stage_calls, "no sparse copy attempted")
	assert_equal(_f.space.domain_calls, domain_calls, "no Domain copy attempted")
	assert_equal(_room_bindings.room_begins, 0, "denied lease held nothing")
	assert_true(_admission_image() == before, "no actual state changed")


func test_successful_admission_cannot_lose_its_actual_lease_before_plan_copy() -> void:
	"""The first post-admission exact-binding callback replaces a real lease with identical capacity."""
	var before: PackedByteArray = _admission_image()
	var domain_calls: int = _f.space.domain_calls
	_room_bindings.replace_at = 1
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_ROOM_COLD, "replacement refuses before copying")
	assert_equal(_f.space.domain_calls, domain_calls, "no Domain/geometry copy after lease loss")
	assert_true(_admission_image() == before, "no actual identity or geometry changed")
	assert_true(_room_bindings.arena.covers(_room_bindings.replacement_token, Budget.COLD_BYTES), "foreign replacement is retained")
	assert_equal(_room_bindings.arena.release(_room_bindings.replacement_token), &"", "test releases its own replacement")
	assert_true(_f.orders.confirm_room(_plan()).ok, "valid retry succeeds once")


func test_successful_cold_callback_cannot_lend_a_replaced_token_to_room_creation() -> void:
	"""The provider's fresh scope proof is checked against the actual pinned arena after callbacks."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.replace_at = 2
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_ROOM_COLD, "scope callback replacement refuses")
	assert_true(_admission_image() == before, "no actual row or generation spent")
	assert_false(_f.space.has_prepared(), "no staged companion stranded")
	assert_true(_room_bindings.arena.covers(_room_bindings.replacement_token, Budget.COLD_BYTES), "foreign scope remains owned")
	assert_equal(_room_bindings.arena.release(_room_bindings.replacement_token), &"", "release test-owned replacement")


func test_sealed_room_cannot_publish_after_exact_lease_replacement() -> void:
	"""Late replacement aborts the staged marker image before any actual Directory allocation."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.replace_at = 3
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_ROOM_COLD, "late replaced lease refuses")
	assert_true(_admission_image() == before, "sealed refusal preserves every live row")
	assert_false(_f.space.has_prepared(), "own staged rows discarded")
	assert_equal(_room_bindings.room_publications, 0, "no publication or misleading accepted receipt")
	assert_true(_room_bindings.arena.covers(_room_bindings.replacement_token, Budget.COLD_BYTES), "replacement lease preserved")
	assert_equal(_room_bindings.arena.release(_room_bindings.replacement_token), &"", "release test-owned replacement")


func test_room_cold_busy_and_foreign_space_stage_keep_their_existing_owners() -> void:
	"""A rejected operation cannot release a different shared lease or abort somebody else's token."""
	_room_bindings.room_cold_held = true
	var stage_calls: int = _f.space.stage_calls
	assert_equal(_f.orders.confirm_room(_plan()).error, &"SYNTHETIC_ROOM_COLD_BUSY", "existing lease refuses")
	assert_true(_room_bindings.room_cold_held, "foreign lease retained")
	assert_equal(_f.space.stage_calls, stage_calls, "busy lease prevents copy")
	_room_bindings.room_cold_held = false
	var before: PackedByteArray = _admission_image()
	var foreign: SpaceOwner.Result = _f.space.begin_stage(_f.space.revision())
	assert_equal(foreign.error, &"", "foreign actual Space stage")
	assert_false(_f.orders.confirm_room(_plan()).ok, "busy sparse owner refuses after own lease")
	assert_true(_f.space.has_prepared(), "foreign token remains owned")
	assert_equal(_room_bindings.room_begins, 1, "own room lease acquired once")
	assert_equal(_room_bindings.room_ends, 1, "only own lease released")
	_f.space.abort(foreign.token)
	assert_true(_admission_image() == before, "failed room attempt publishes nothing")


func test_missing_cut_mapping_or_changed_companion_proof_refuses_without_spending_identity() -> void:
	"""Marker geometry cannot substitute for actual paid-cut mapping/support/profile qualification."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.block_plan = true
	assert_equal(_f.orders.confirm_room(_plan()).error, &"SYNTHETIC_WHOLE_CUT_COVERAGE_UNPROVED", "physical mapping gate is mandatory")
	assert_true(_admission_image() == before, "missing mapping changes nothing")
	_room_bindings.block_plan = false
	_room_bindings.block_prepared = true
	assert_equal(_f.orders.confirm_room(_plan()).error, &"SYNTHETIC_ROOM_SOURCE_CHANGED", "late companion revision refuses")
	assert_true(_admission_image() == before, "late refusal changes nothing")
	_room_bindings.block_prepared = false
	assert_true(_f.orders.confirm_room(_plan()).ok, "fresh complete retry can publish exactly once")
	assert_equal(_room_bindings.room_publications, 1, "failed attempts never publish")


func test_tampered_candidate_or_copied_plan_is_rejected_after_seal() -> void:
	"""No stale identity or mutated fine geometry may borrow already sealed source facts."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.tamper_candidate = true
	assert_false(_f.orders.confirm_room(_plan()).ok, "changed candidate PID refuses")
	assert_true(_admission_image() == before, "candidate refusal preserves every owner")
	_room_bindings.tamper_candidate = false
	_room_bindings.tamper_snapshot = true
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_PLAN, "changed copied outline refuses")
	assert_true(_admission_image() == before, "outline mismatch preserves every owner")


func test_intervening_real_identity_history_survives_room_refusal_without_rollback() -> void:
	"""External creation/retirement invalidates the candidate; its generation/PID history remains spent."""
	var before_space: PackedByteArray = _f.space.state_bytes()
	_room_bindings.intervene_identity = true
	assert_false(_f.orders.confirm_room(_plan()).ok, "actual intervening identity invalidates future Room")
	assert_true(_f.residents.directory().state_bytes() == _room_bindings.external_directory, "external history is not rewound")
	assert_equal(_f.buildings.live_room_count(), 0, "failed operation creates no Room")
	assert_true(_f.space.state_bytes() == before_space, "failed candidate publishes no markers")
	_room_bindings.intervene_identity = false
	assert_true(_f.orders.confirm_room(_plan()).ok, "new candidate retries from actual allocator state")


func test_reentrant_confirmation_legacy_create_and_modular_discard_cannot_steal_room_stage() -> void:
	"""The one synchronous stage is exclusive even while provider callbacks call public APIs."""
	_room_bindings.probe_reentry = true
	var made: Buildings.OpResult = _f.orders.confirm_room(_plan())
	assert_true(made.ok, "outer exact operation still publishes")
	assert_true(_room_bindings.reentry_refused, "nested Room confirmation refused")
	assert_true(_room_bindings.direct_create_refused, "preparation does not expose mutation permission")
	assert_equal(_f.buildings.live_room_count(), 1, "exactly one Room created")
	assert_equal(_room_bindings.room_begins, 1, "nested calls acquire no second peak")
	assert_equal(_room_bindings.room_ends, 1, "own peak released only after outer completion")


func test_initial_exact_binding_cannot_reenter_before_room_exclusivity() -> void:
	"""The stage exists before even the first provider callback, not only before cold preparation."""
	_room_bindings.entry_plan = _plan()
	_room_bindings.probe_entry_binding = true
	var made: Buildings.OpResult = _f.orders.confirm_room(_plan())
	assert_true(made.ok, "outer single-Room confirmation succeeds")
	assert_true(_room_bindings.entry_reentry_refused, "first provider callback sees the exclusive room stage")
	assert_equal(_f.buildings.live_room_count(), 1, "nested entry cannot consume another actual identity")
	assert_equal(_room_bindings.room_begins, 1, "only outer operation acquires cold peak")
	assert_equal(_room_bindings.room_ends, 1, "only outer operation releases cold peak")


func test_second_exact_binding_refusal_clears_entry_without_calling_null_provider() -> void:
	"""A provider passing one attestation cannot force a null call or strand the exclusive room stage."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.entry_plan = _plan()
	_room_bindings.probe_entry_binding = true
	_room_bindings.refuse_second_binding = true
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_BINDING, "lost second binding refuses explicitly")
	assert_equal(_room_bindings.entry_binding_calls, 2, "nested attempt invokes no further binding callback")
	assert_true(_room_bindings.entry_reentry_refused, "first callback nested entry refused")
	assert_equal(_room_bindings.room_begins, 0, "no unavailable provider receives cold admission")
	assert_equal(_f.orders._stage_action, -1, "exclusive entry cleared after refusal")
	assert_false(_f.space.has_prepared(), "no spatial candidate allocated")
	assert_true(_admission_image() == before, "actual Directory/Space/accounting state unchanged")
	_room_bindings.probe_entry_binding = false
	_room_bindings.refuse_second_binding = false
	assert_true(_f.orders.confirm_room(_plan()).ok, "fresh valid retry is not stuck busy")


func test_publication_attestation_never_calls_a_mutating_provider_binding() -> void:
	"""A late arbitrary callback cannot change the sealed footprint after the final unchanged-plan check."""
	_room_bindings.probe_publication_binding = true
	var plan: RoomOrders.RoomPlan = _plan()
	var made: Buildings.OpResult = _f.orders.confirm_room(plan)
	assert_true(made.ok, "actual identity and sealed fine footprint publish")
	assert_equal(_room_bindings.publication_binding_calls, 0, "same-stack attestation reads only actual local identities")
	assert_equal(_claims_at(made.ref, PackedInt32Array([512, -4095, 1024, 768, -4094, 1280])), 1, "sealed original cell retained")
	assert_equal(_room_bindings.room_publications, 1, "one exact physical companion publication")


func test_late_provider_binding_loss_refuses_before_identity_publication() -> void:
	"""The final actual binding gate runs before callback-free candidate/geometry revalidation."""
	var before: PackedByteArray = _admission_image()
	_room_bindings.unbind_after_preparation = true
	assert_equal(_f.orders.confirm_room(_plan()).error, RoomOrders.REFUSE_BINDING, "late physical owner wiring loss refuses")
	assert_true(_admission_image() == before, "no live identity or claim is published")
	assert_equal(_room_bindings.room_publications, 0, "no provider publication after binding refusal")
	_room_bindings.wired = true


func test_invalid_plan_identity_dimensions_and_revision_refuse_before_cold_admission() -> void:
	"""Unknown worlds and malformed integer inputs never become a rounded or partial room."""
	var before: PackedByteArray = _admission_image()
	assert_false(_f.orders.confirm_room(null).ok, "null plan")
	for mode: int in 8:
		var plan: RoomOrders.RoomPlan = _plan()
		match mode:
			0: plan.world.y += 1
			1: plan.space_revision += 1
			2: plan.room_type = Buildings.ROOM_TYPE_COUNT
			3: plan.level = -1
			4: plan.cell_size_u = 0
			5: plan.height_u = 0
			6: plan.origin_u.y = Space.I32_MAX
			7: plan.cells = PackedInt32Array([0])
		assert_equal(_f.orders.confirm_room(plan).error, RoomOrders.REFUSE_PLAN, "malformed plan refuses")
	assert_equal(_room_bindings.room_begins, 0, "pure shape/scalar bounds precede cold allocation")
	assert_true(_admission_image() == before, "no malformed input changes actual state")


func test_disconnected_noncanonical_and_out_of_domain_shapes_never_publish_partial_claims() -> void:
	"""Boundary validation preserves exact shape rather than joining, sorting, rounding or truncating it."""
	var before: PackedByteArray = _admission_image()
	for cells: PackedInt32Array in [PackedInt32Array([0, 0, 2, 0]),
			PackedInt32Array([1, 0, 0, 0]), PackedInt32Array([0, 0, 0, 0])]:
		assert_false(_f.orders.confirm_room(_plan(cells)).ok, "invalid topology/canonical form refuses")
		assert_true(_admission_image() == before, "invalid topology leaves no partial Room")
	var outside: RoomOrders.RoomPlan = _plan()
	outside.origin_u.x = Space.I32_MAX
	assert_false(_f.orders.confirm_room(outside).ok, "overflowing far painted corner refuses")
	assert_true(_admission_image() == before, "overflow leaves no partial geometry or spent identity")
	outside = _plan()
	outside.origin_u.x = -1
	assert_false(_f.orders.confirm_room(outside).ok, "one-unit Domain escape is not rounded into bounds")
	assert_true(_admission_image() == before, "exact outside boundary refuses unchanged")


func test_sparse_capacity_failure_after_partial_staging_leaves_all_live_state_unchanged() -> void:
	"""Engineering region capacity refuses before identity spending, even after many candidate rows."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 64:
		cells.append_array(PackedInt32Array([0, z]))
	var plan: RoomOrders.RoomPlan = _plan(cells)
	plan.origin_u = Vector3i(0, -4096, 0)
	var before: PackedByteArray = _admission_image()
	assert_false(_f.orders.confirm_room(plan).ok, "64 exact claim rows plus one metadata section exceed actual64-row owner")
	assert_true(_admission_image() == before, "no truncated plan or allocator rollback")
	assert_false(_f.space.has_prepared(), "finite failed candidate is dropped")
	assert_equal(_f.buildings.live_room_count(), 0, "no Room allocated before spatial capacity proof")
