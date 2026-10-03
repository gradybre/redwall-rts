extends "res://test/framework/test_case.gd"
## UG07 A: real Directory identities and service exclusion; spatial proof is explicitly synthetic.

const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TILE_AREA: int = 4194304

class Authority extends Buildings.SpatialAuthority:
	## Test-only exact-operation permit. No demo or production composition binds this fixture.
	var owner: WeakRef = null
	var action: int = -1
	var subject: Vector2i = NULL_REF
	var related: Vector2i = NULL_REF
	var value: int = 0
	var rotation: int = 0
	var area_room: Vector2i = NULL_REF
	var area: int = 0
	var service_room: Vector2i = NULL_REF
	var candidate: Directory.CreateCandidate = null
	var candidate_type: int = -1
	var publishing_room: bool = false

	func buildings_owner() -> RefCounted:
		"""Compare actual store objects even when another Directory reuses the same numbers."""
		return owner.get_ref() if owner != null else null

	func mutation_refusal(p_action: int, p_subject: Vector2i, p_related: Vector2i,
			p_value: int, p_rotation: int) -> StringName:
		"""Only the exact test operation is admitted; no blanket permissive authority exists."""
		return &"" if p_action == action and p_subject == subject and p_related == related \
			and p_value == value and p_rotation == rotation else Buildings.REFUSE_SPATIAL_COMMAND

	func area_of_room(room: Vector2i) -> Buildings.OpResult:
		"""Return a deliberately explicit synthetic floor area under its actual Room identity."""
		return Buildings.OpResult.new(room == area_room, &"", area, area_room)

	func room_candidate_refusal(p_candidate: Directory.CreateCandidate, room_type: int) -> StringName:
		"""This explicit synthetic future-room permit supplements the real allocator validation."""
		return &"" if candidate != null and p_candidate == candidate and room_type == candidate_type \
			else Buildings.REFUSE_SPATIAL_COMMAND

	func is_publishing_room_admission(room: Vector2i, room_type: int) -> bool:
		"""Only one exact fixture publication call may create the selected candidate."""
		return publishing_room and candidate != null and room == candidate.ref and room_type == candidate_type

	func service_refusal(room: Vector2i) -> StringName:
		"""Synthetic service qualification is separate from the persisted validity flag."""
		return &"" if room == service_room else &"SYNTHETIC_SHELL_INCOMPLETE"

	func allow(p_action: int, p_subject: Vector2i, p_related: Vector2i,
			p_value: int = 0, p_rotation: int = 0) -> void:
		"""Pin every argument to one operation before invoking the owner in the test."""
		action = p_action
		subject = p_subject
		related = p_related
		value = p_value
		rotation = p_rotation

	func reset() -> void:
		"""End the synthetic operation's permit."""
		action = -1

var _store: Buildings = null
var _authority: Authority = null


func before_each() -> void:
	"""A fresh actual identity store, with only this test's explicit spatial authority."""
	_store = Buildings.new()
	_authority = Authority.new()
	_authority.owner = weakref(_store)
	assert_true(_store.bind_spatial_authority(_authority).ok, "exact store binds once")


func after_each() -> void:
	"""The production wiring and fixture both hold their reverse references weakly."""
	_authority = null
	_store = null


func _room(kind: int = Buildings.ROOM_TYPE_DORMITORY) -> Vector2i:
	"""Allocate an actual Room identity through one explicitly scoped synthetic operation."""
	_authority.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, kind)
	var made: Buildings.OpResult = _store.designate_spatial_room(kind)
	_authority.reset()
	assert_true(made.ok, "actual spatial Room creates: %s" % made.error)
	return made.ref


func _pending(room: Vector2i, key: String = "bed", rotation: int = 0) -> Vector2i:
	"""Reserve actual Furniture capacity without installed service presence."""
	var type_id: int = int(Catalog.FURNITURE_DEFINITION[key])
	_authority.allow(Buildings.SPATIAL_FURNITURE_CREATE, NULL_REF, room, type_id, rotation)
	var made: Buildings.OpResult = _store.stage_spatial_furniture(room, type_id, rotation)
	_authority.reset()
	assert_true(made.ok, "actual pending Furniture creates: %s" % made.error)
	return made.ref


func _install(piece: Vector2i) -> void:
	"""Test only the owner boundary; the real paid coordinator is a following increment."""
	_authority.allow(Buildings.SPATIAL_FURNITURE_INSTALL, piece, NULL_REF)
	assert_true(_store.install_spatial_furniture(piece).ok, "exact synthetic installation publishes")
	_authority.reset()


func _valid(room: Vector2i) -> void:
	"""Set a valid flag only during its scoped synthetic owner operation."""
	_authority.allow(Buildings.SPATIAL_ROOM_VALID, room, NULL_REF, 1)
	assert_true(_store.set_room_valid(room, true).ok, "owner records shell validity")
	_authority.reset()
	_authority.service_room = room


func _remove_piece(piece: Vector2i) -> void:
	"""A following physical coordinator must supply the proof this fixture scopes explicitly."""
	_authority.allow(Buildings.SPATIAL_FURNITURE_REMOVE, piece, NULL_REF)
	assert_true(_store.remove_furniture(piece).ok, "scoped removal retires actual identity")
	_authority.reset()


func _remove_room(room: Vector2i) -> void:
	"""Test the identity retirement gate without claiming real backfill completion."""
	_authority.allow(Buildings.SPATIAL_ROOM_REMOVE, room, NULL_REF)
	assert_true(_store.remove_room(room).ok, "scoped empty Room removal succeeds")
	_authority.reset()


func _image() -> PackedByteArray:
	"""Capture all packed owner columns and the actual Directory for refusal atomicity checks."""
	var out: PackedByteArray = _store.directory().state_bytes()
	for property: Dictionary in _store.get_property_list():
		var field: Variant = _store.get(property["name"])
		if field is PackedByteArray:
			out.append_array(field)
		elif field is PackedInt32Array or field is PackedInt64Array:
			out.append_array(field.to_byte_array())
	out.append_array(PackedInt64Array([_store.live_building_count(), _store.live_room_count(),
		_store.live_furniture_count(), _store.room_tile_links_used()]).to_byte_array())
	return out


func _surface_room() -> Vector2i:
	"""Use an actual legacy hall and one actual interior ground tile."""
	var hall: Buildings.OpResult = _store.place_building(int(Catalog.BUILDING_DEFINITION["hall"]), 0, 0, 1)
	assert_true(hall.ok, "surface hall places")
	var room: Buildings.OpResult = _store.designate_room(hall.ref, Buildings.ROOM_TYPE_DORMITORY,
		PackedInt32Array([129, 130, 131]))
	assert_true(room.ok, "surface room places")
	return room.ref


func test_authority_binding_refuses_unbound_foreign_replacement_and_expiration() -> void:
	"""Coincident numeric identity spaces cannot replace exact owner wiring."""
	var unbound: Buildings = Buildings.new()
	var baseline: PackedByteArray = unbound.directory().state_bytes()
	assert_equal(unbound.spatial_room_admission_refusal(0), Buildings.REFUSE_SPATIAL_AUTHORITY, "unbound refuses")
	assert_false(unbound.designate_spatial_room(0).ok, "no fallback surface identity")
	assert_equal(unbound.directory().state_bytes(), baseline, "refusal allocates no Directory row")
	assert_false(unbound.bind_spatial_authority(_authority).ok, "foreign owner cannot bind")
	assert_true(_store.bind_spatial_authority(_authority).ok, "same live binding is idempotent")
	var replacement: Authority = Authority.new()
	replacement.owner = weakref(_store)
	assert_false(_store.bind_spatial_authority(replacement).ok, "second authority cannot replace the first")
	_authority = null
	assert_null(_store.spatial_authority(), "expired binding reads null")
	assert_false(_store.bind_spatial_authority(replacement).ok, "expired binding cannot be silently replaced")
	assert_false(_store.designate_spatial_room(0).ok, "expiration fails closed")


func test_room_identity_is_real_permanent_and_not_limited_to_sixteen_surface_rooms() -> void:
	"""No surrogate Building or duplicate flat tile claim is needed for actual spatial Rooms."""
	var ground: PackedInt32Array = _store._room_slot.duplicate()
	var refs: Array[Vector2i] = []
	for index: int in 20:
		var room: Vector2i = _room(Buildings.ROOM_TYPE_KITCHEN)
		refs.append(room)
		assert_true(_store.directory().is_valid_of_kind(room, Directory.KIND_ROOM), "actual Room namespace")
		assert_equal(_store.room_building_ref_of(room), NULL_REF, "no invented exterior parent")
		assert_equal(_store.spatial_kind_of_room(room).value, Buildings.ROOM_SPACE_UNDERGROUND, "explicit domain")
		assert_equal(_store.type_of_room(room).value, Buildings.ROOM_TYPE_KITCHEN, "accepted purpose is permanent")
	assert_equal(_store.live_room_count(), 20, "the managed-building sixteen limit is inapplicable")
	assert_equal(_store.room_tile_links_used(), 0, "no flat TileLinks are consumed")
	assert_equal(_store._room_slot, ground, "no underground Room occupies a ground-grid alias")
	assert_equal(_store.tile_count_of_room(refs[0]).error, Buildings.REFUSE_SPATIAL_COORDINATE, "zero links is not area")
	assert_equal(_store.tile_offset_of_room(refs[0]).error, Buildings.REFUSE_SPATIAL_COORDINATE, "no ground offset")
	assert_equal(_store.room_tile_at(refs[0], 0).error, Buildings.REFUSE_SPATIAL_COORDINATE, "no flattening")


func _candidate(kind: int = Buildings.ROOM_TYPE_KITCHEN) -> Directory.CreateCandidate:
	"""Prepare exact actual allocator scratch while the synthetic publication window stays closed."""
	var candidate: Directory.CreateCandidate = Directory.CreateCandidate.new()
	assert_equal(_store.directory().peek_create_into(Directory.KIND_ROOM, candidate), &"", "future actual Room")
	_authority.candidate = candidate
	_authority.candidate_type = kind
	return candidate


func test_candidate_preflight_never_creates_until_exact_publication_window() -> void:
	"""Sealable future facts and permission to spend an identity are separate boundaries."""
	var candidate: Directory.CreateCandidate = _candidate()
	var before: PackedByteArray = _image()
	assert_equal(_store.spatial_room_candidate_refusal(Buildings.ROOM_TYPE_KITCHEN, candidate), &"", "cold candidate qualifies")
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate).ok, "preparation is not publication")
	assert_false(_store.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN).ok, "candidate cannot open legacy create")
	assert_equal(_image(), before, "all pre-publication calls unchanged")
	_authority.publishing_room = true
	var made: Buildings.OpResult = _store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate)
	_authority.publishing_room = false
	assert_true(made.ok, "exact publication succeeds")
	assert_equal(made.ref, candidate.ref, "exact sealed identity")
	assert_equal(made.value, candidate.typed_row, "exact typed row")
	assert_equal(_store.directory().get_persistent_id(made.ref), candidate.persistent_id, "exact PID")
	assert_equal(_store.spatial_kind_of_room(made.ref).value, Buildings.ROOM_SPACE_UNDERGROUND, "real underground kind")
	assert_equal(_store.room_building_ref_of(made.ref), NULL_REF, "no fake parent")
	assert_false(_store.room_is_valid(made.ref), "planned identity does not complete shell")
	assert_equal(_store.room_tile_links_used(), 0, "no surface alias")
	before = _image()
	_authority.publishing_room = true
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate).ok, "spent candidate refuses")
	assert_equal(_image(), before, "duplicate spends nothing")


func test_candidate_wrong_kind_foreign_owner_and_wrong_type_leave_both_stores_unchanged() -> void:
	"""Exact authority arguments cannot bypass real Directory and Room-type gates."""
	var candidate: Directory.CreateCandidate = _candidate()
	_authority.publishing_room = true
	var before: PackedByteArray = _image()
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_DORMITORY, candidate).ok, "wrong permanent purpose")
	assert_false(_store.designate_spatial_room_candidate(-1, candidate).ok, "unknown purpose")
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, null).ok, "null packet")
	_store.directory().peek_create_into(Directory.KIND_FURNITURE, candidate)
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate).ok, "non-Room typed capacity")
	var foreign: Directory = Directory.new()
	foreign.peek_create_into(Directory.KIND_ROOM, candidate)
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate).ok, "identical foreign numbers")
	assert_equal(_image(), before, "all real columns/heaps unchanged")
	assert_equal(foreign.total_live_count(), 0, "foreign Directory unchanged")


func test_candidate_stale_after_intervening_allocation_cannot_roll_back_identity_history() -> void:
	"""The pending Room may retry only with a newly prepared full identity and spatial candidate."""
	var candidate: Directory.CreateCandidate = _candidate()
	var intervening: Vector2i = _store.directory().create(Directory.KIND_BUILDING)
	assert_true(_store.directory().destroy(intervening), "intervening allocation retired")
	_authority.publishing_room = true
	var before: PackedByteArray = _image()
	assert_false(_store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate).ok, "stale candidate refuses")
	assert_equal(_image(), before, "neither generation nor PID is rolled back")
	candidate = _candidate()
	var made: Buildings.OpResult = _store.designate_spatial_room_candidate(Buildings.ROOM_TYPE_KITCHEN, candidate)
	assert_true(made.ok, "freshly prepared candidate publishes")
	assert_equal(made.ref.y, 2, "actual new generation")
	assert_equal(_store.directory().get_persistent_id(made.ref), 2, "actual new PID")


func test_unknown_type_wrong_permit_and_stale_identity_refuse_without_writes() -> void:
	"""Admission and later identity readers validate every full generation and operation argument."""
	var before: PackedByteArray = _image()
	assert_equal(_store.spatial_room_admission_refusal(999), Buildings.REFUSE_UNKNOWN_ROOM_TYPE, "unknown purpose refuses")
	assert_false(_store.designate_spatial_room(0).ok, "an idle authority supplies no permit")
	assert_equal(_image(), before, "room refusal is byte-identical")
	var room: Vector2i = _room()
	var stale: Vector2i = Vector2i(room.x, room.y + 1)
	before = _image()
	assert_false(_store.spatial_kind_of_room(stale).ok, "generation reader refuses")
	assert_false(_store.spatial_furniture_admission_refusal(stale, 0, 0).is_empty(), "stale room cannot own furniture")
	assert_false(_store.stage_spatial_furniture(room, 0, 0).ok, "idle furniture admission refuses")
	assert_false(_store.stage_spatial_furniture(room, 999, 0).ok, "unknown catalog type refuses")
	assert_false(_store.stage_spatial_furniture(room, 0, 4).ok, "unknown orientation refuses")
	assert_equal(_image(), before, "all denied operations preserve owner and Directory bytes")


func test_pending_bed_reserves_identity_membership_but_supplies_no_presence_or_use() -> void:
	"""A placed blueprint cannot supply an installed bed or evade room removal's membership gate."""
	var room: Vector2i = _room()
	var bed: Vector2i = _pending(room, "bed", 3)
	var type_id: int = int(Catalog.FURNITURE_DEFINITION["bed"])
	assert_true(_store.directory().is_valid_of_kind(bed, Directory.KIND_FURNITURE), "actual Furniture namespace")
	assert_true(_store.is_live_furniture(bed), "pending identity counts as allocated")
	assert_false(_store.is_furniture_installed(bed), "installation remains unpaid")
	assert_equal(_store.live_furniture_count(), 1, "finite identity is reserved")
	assert_equal(_store.live_furniture_of_kind(type_id), 0, "HUD service count excludes the plan")
	assert_equal(_store.count_furniture_of_kind(room, type_id).value, 0, "room service count excludes it")
	assert_equal(_store.furniture_mask_of(room).value, 0, "pending bed has no presence bit")
	assert_equal(_store.furniture_rows_in_room(room).size(), 1, "membership still prevents orphaning")
	assert_equal(_store.origin_tile_of_furniture(bed).error, Buildings.REFUSE_SPATIAL_COORDINATE, "no false ground pose")
	assert_equal(_store.rotation_of_furniture(bed).value, 3, "authored orientation remains actual state")
	var resident: Vector2i = _store.directory().create(Directory.KIND_RESIDENT)
	assert_equal(_store.set_furniture_user(bed, resident).error, Buildings.REFUSE_NOT_INSTALLED, "resident cannot use a plan")
	_authority.allow(Buildings.SPATIAL_ROOM_REMOVE, room, NULL_REF)
	assert_equal(_store.remove_room(room).error, Buildings.REFUSE_ROOM_HAS_FURNITURE, "pending membership blocks removal")


func test_installation_is_owner_scoped_idempotent_and_generation_safe() -> void:
	"""Only an exact installation callback publishes masks and counters, once."""
	var room: Vector2i = _room()
	var first: Vector2i = _pending(room)
	var second: Vector2i = _pending(room)
	var before: PackedByteArray = _image()
	assert_false(_store.install_spatial_furniture(first).ok, "direct unpaid completion refuses")
	assert_equal(_image(), before, "refused installation changes no bytes")
	_install(first)
	assert_true(_store.is_furniture_installed(first), "first actual installation is present")
	assert_equal(_store.count_furniture_of_kind(room, 0).value, 1, "pending sibling does not double count")
	assert_equal(_store.furniture_mask_of(room).value, 1, "bed presence is installed-only")
	before = _image()
	assert_equal(_store.install_spatial_furniture(first).error, Buildings.REFUSE_ALREADY_INSTALLED, "duplicate refuses")
	assert_equal(_image(), before, "duplicate cannot increment counters")
	_install(second)
	_remove_piece(first)
	assert_equal(_store.furniture_mask_of(room).value, 1, "remaining installed sibling retains bit")
	assert_false(_store.is_furniture_installed(first), "retired generation cannot inherit another piece")
	assert_equal(_store.live_furniture_of_kind(0), 1, "installed count decrements once")
	assert_true(_store.verify_room_masks().ok, "actual mask cross-check remains exact")


func test_pending_pantry_and_kitchen_furniture_grant_no_service_capacity() -> void:
	"""Existing service readers require both actual installation and fresh room qualification."""
	var pantry: Vector2i = _room(Buildings.ROOM_TYPE_PANTRY)
	var shelf: Vector2i = _pending(pantry, "shelf")
	_valid(pantry)
	assert_equal(_store.pantry_capacity_g_of_room(pantry).value, 0, "pending shelf stores nothing")
	_install(shelf)
	assert_equal(_store.pantry_capacity_g_of_room(pantry).value, 50000, "installed shelf supplies the existing catalog amount")
	_authority.service_room = NULL_REF
	assert_false(_store.room_is_valid(pantry), "service loss overrides the old valid bit")
	assert_equal(_store.pantry_capacity_g_of_room(pantry).error, Buildings.REFUSE_ROOM_NOT_VALID, "stale shell cannot store goods")
	var kitchen: Vector2i = _room(Buildings.ROOM_TYPE_KITCHEN)
	var bench: Vector2i = _pending(kitchen, "kitchen_bench")
	_valid(kitchen)
	assert_equal(_store.kitchen_bench_slots_of_room(kitchen).value, 0, "pending bench grants no work slot")
	_install(bench)
	assert_equal(_store.kitchen_bench_slots_of_room(kitchen).value, 1, "installed bench retains one actual slot")
	_authority = null
	assert_false(_store.room_is_valid(kitchen), "expired authority cannot supply live services")


func test_area_and_countable_rules_use_actual_floor_identity_without_rounding_up() -> void:
	"""An underground room has owner-proved area; pending beds and fractional thresholds fail."""
	var room: Vector2i = _room()
	assert_equal(_store.area_units_squared_of_room(room).error, Buildings.REFUSE_SPATIAL_AREA, "unproved area is not zero")
	_authority.area_room = room
	_authority.area = 3 * TILE_AREA
	var bed: Vector2i = _pending(room)
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "an uninstalled bed cannot validate the room")
	_install(bed)
	assert_equal(_store.area_units_squared_of_room(room).value, 3 * TILE_AREA, "actual integer area reads exactly")
	assert_equal(_store.room_meets_countable_rules(room).value, 1, "installed bed at the exact GDD threshold")
	_authority.area -= 1
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "one fixed squared unit short never rounds up")
	_authority.area_room = Vector2i(room.x, room.y + 1)
	assert_false(_store.area_units_squared_of_room(room).ok, "another generation's area cannot count")


func test_legacy_mutators_cannot_reassign_remove_or_validate_spatial_rows() -> void:
	"""Legacy doors are not an alternate route around coordinator ownership."""
	var room: Vector2i = _room()
	var other: Vector2i = _room(Buildings.ROOM_TYPE_KITCHEN)
	var bed: Vector2i = _pending(room)
	var before: PackedByteArray = _image()
	assert_false(_store.place_furniture(room, 0, 0, 0).ok, "legacy direct furnishing cannot bypass installation")
	assert_false(_store.reassign_furniture(bed, other).ok, "room style cannot be bypassed by reassigning a piece")
	assert_false(_store.remove_furniture(bed).ok, "no direct unpaid/refundless removal")
	assert_false(_store.remove_room(other).ok, "empty room still needs physical retirement proof")
	assert_false(_store.set_room_valid(room, true).ok, "validity setter requires owner")
	assert_false(_store.set_room_occupants(room, 1).ok, "occupants setter requires owner")
	assert_false(_store.set_room_temperature_tenths(room, 200).ok, "heat setter requires owner")
	assert_false(_store.set_furniture_condition(bed, 123).ok, "condition setter requires owner")
	assert_equal(_image(), before, "denied legacy paths leave every row and identity unchanged")


func test_exact_installed_user_condition_and_temperature_publications_remain_available() -> void:
	"""The coordinator gate permits real scoped service updates, not just blanket rejection."""
	var room: Vector2i = _room()
	var bed: Vector2i = _pending(room)
	_install(bed)
	var resident: Vector2i = _store.directory().create(Directory.KIND_RESIDENT)
	_authority.allow(Buildings.SPATIAL_FURNITURE_USER, bed, resident)
	assert_true(_store.set_furniture_user(bed, resident).ok, "exact installed user binds")
	assert_equal(_store.user_ref_of_furniture(bed), resident, "full resident identity is retained")
	_authority.allow(Buildings.SPATIAL_FURNITURE_REMOVE, bed, NULL_REF)
	assert_equal(_store.remove_furniture(bed).error, Buildings.REFUSE_FURNITURE_IN_USE, "scoped removal still respects use")
	_authority.allow(Buildings.SPATIAL_FURNITURE_USER, bed, NULL_REF)
	assert_true(_store.set_furniture_user(bed, NULL_REF).ok, "actual user releases")
	_authority.allow(Buildings.SPATIAL_FURNITURE_CONDITION, bed, NULL_REF, 47)
	assert_true(_store.set_furniture_condition(bed, 47).ok, "condition can be published by its actual owner")
	assert_equal(_store.condition_of_furniture(bed).value, 47, "condition is preserved exactly")
	_authority.allow(Buildings.SPATIAL_ROOM_TEMPERATURE, room, NULL_REF, -30)
	assert_true(_store.set_room_temperature_tenths(room, -30).ok, "temperature can be published by its actual owner")
	assert_equal(_store.temperature_tenths_of_room(room).value, -30, "signed integer temperature remains unchanged")


func test_late_foreign_owner_rewiring_blocks_mutations_and_service_reads() -> void:
	"""A once-valid bridge cannot later lend numerically identical foreign world state."""
	var room: Vector2i = _room(Buildings.ROOM_TYPE_PANTRY)
	var shelf: Vector2i = _pending(room, "shelf")
	_install(shelf)
	_valid(room)
	_authority.area_room = room
	_authority.area = 4 * TILE_AREA
	var foreign: Buildings = Buildings.new()
	_authority.owner = weakref(foreign)
	_authority.allow(Buildings.SPATIAL_FURNITURE_REMOVE, shelf, NULL_REF)
	var before: PackedByteArray = _image()
	assert_equal(_store.remove_furniture(shelf).error, Buildings.REFUSE_SPATIAL_AUTHORITY, "live actual owner mismatch refuses")
	assert_false(_store.room_is_valid(room), "foreign owner cannot preserve service qualification")
	assert_false(_store.pantry_capacity_g_of_room(room).ok, "foreign owner supplies no pantry capacity")
	assert_equal(_store.area_units_squared_of_room(room).error, Buildings.REFUSE_SPATIAL_AUTHORITY, "foreign area cannot count")
	assert_equal(_image(), before, "late foreign rewiring mutates no actual owner state")


func test_spatial_removal_requires_occupants_released_and_new_purpose_gets_fresh_identity() -> void:
	"""Clearing furniture never retypes a room; accepted removal is the identity boundary."""
	var kitchen: Vector2i = _room(Buildings.ROOM_TYPE_KITCHEN)
	_authority.allow(Buildings.SPATIAL_ROOM_OCCUPANTS, kitchen, NULL_REF, 1)
	assert_true(_store.set_room_occupants(kitchen, 1).ok, "scoped occupant publication")
	_authority.allow(Buildings.SPATIAL_ROOM_REMOVE, kitchen, NULL_REF)
	assert_equal(_store.remove_room(kitchen).error, Buildings.REFUSE_ROOM_OCCUPIED, "inhabited room cannot disappear")
	_authority.allow(Buildings.SPATIAL_ROOM_OCCUPANTS, kitchen, NULL_REF, 0)
	assert_true(_store.set_room_occupants(kitchen, 0).ok, "actual occupancy releases")
	assert_equal(_store.type_of_room(kitchen).value, Buildings.ROOM_TYPE_KITCHEN, "empty kitchen stays kitchen")
	_remove_room(kitchen)
	var bedroom: Vector2i = _room(Buildings.ROOM_TYPE_DORMITORY)
	assert_equal(bedroom.x, kitchen.x, "finite Directory slot may be reused")
	assert_true(bedroom.y != kitchen.y, "new purpose is a fresh full-generation identity")
	assert_false(_store.is_live_room(kitchen), "old kitchen ref remains stale")
	assert_equal(_store.furniture_mask_of(bedroom).value, 0, "new room starts empty")


func test_surface_and_spatial_slot_reuse_initializes_both_new_columns() -> void:
	"""No pending or underground discriminator can leak into a legacy row that reuses the slot."""
	var underground: Vector2i = _room()
	var pending: Vector2i = _pending(underground)
	_remove_piece(pending)
	_remove_room(underground)
	assert_equal(_store.legacy_save_refusal(), Buildings.REFUSE_VERSIONED_CODEC,
		"retired spatial furniture retains non-surface pose history until reuse or whole-world clear")
	var surface: Vector2i = _surface_room()
	assert_equal(_store.spatial_kind_of_room(surface).value, Buildings.ROOM_SPACE_SURFACE, "surface row resets domain")
	var installed: Buildings.OpResult = _store.place_furniture(surface, 0, 129, 0)
	assert_true(installed.ok, "legacy bed remains direct installed placement")
	assert_true(_store.is_furniture_installed(installed.ref), "reused pending row is initialized installed")
	assert_false(_store.is_furniture_installed(pending), "old pending reference cannot inherit flag")
	assert_true(_store.remove_furniture(installed.ref).ok, "surface removal remains allowed")
	assert_true(_store.remove_room(surface).ok, "surface room removal remains allowed")
	var new_room: Vector2i = _room()
	var new_piece: Vector2i = _pending(new_room)
	assert_false(_store.is_furniture_installed(new_piece), "surface-to-spatial reuse resets paid status")
	assert_equal(_store.furniture_mask_of(new_room).value, 0, "surface's retired mask never survives")
	assert_equal(_store.spatial_state_bytes().size(), 98304, "exact approved fixed allocation bytes")


func test_clear_resets_pending_flags_and_preserves_only_weak_owner_wiring() -> void:
	"""Whole-world reset retires actual identities and zeroes every new packed flag."""
	var room: Vector2i = _room()
	var piece: Vector2i = _pending(room)
	_store.clear()
	assert_false(_store.is_live_room(room), "Room identity retires on whole-world reset")
	assert_false(_store.is_live_furniture(piece), "pending Furniture identity also retires")
	assert_equal(_store.live_room_count(), 0, "no remaining Room rows")
	assert_equal(_store.live_furniture_count(), 0, "no remaining pending rows")
	assert_equal(_store.spatial_state_bytes().count(0), 98304, "all discriminator bytes reset")
	assert_true(_store.spatial_authority() == _authority, "weak composition wiring is preserved")
	assert_equal(_store.legacy_save_refusal(), &"", "a reset surface-only owner can be captured")


func test_legacy_capture_and_restore_refuse_spatial_or_unknown_state_atomically() -> void:
	"""A legacy ground-grid codec cannot erase new authoritative flags to appear compatible."""
	var room: Vector2i = _room()
	_pending(room)
	var first: PackedInt32Array = _store._building_slot.duplicate()
	var second: PackedInt32Array = _store._room_slot.duplicate()
	var third: PackedInt32Array = _store._furniture_slot.duplicate()
	var before: PackedByteArray = _image()
	assert_equal(_store.legacy_save_refusal(), Buildings.REFUSE_VERSIONED_CODEC, "explicit composed-codec refusal")
	assert_false(_store.copy_section_1_columns_into(first, second, third), "capture does not omit spatial state")
	assert_equal(_store.section_1_cross_check_refusal(), Buildings.REFUSE_VERSIONED_CODEC, "legacy cross-check refuses")
	assert_false(_store.restore_section_1_columns(first, second, third), "restore cannot erase spatial identity")
	assert_equal(_image(), before, "refused capture/load preserves all source rows")
	assert_equal(first, _store._building_slot, "destination is unchanged on capture refusal")
	assert_equal(second, _store._room_slot, "room output unchanged")
	assert_equal(third, _store._furniture_slot, "furniture output unchanged")


func test_legacy_restore_explicitly_initializes_old_live_furniture_and_rejects_unknowns() -> void:
	"""An old surface image has no installed column; its live legacy rows were already installed."""
	var room: Vector2i = _surface_room()
	var piece: Buildings.OpResult = _store.place_furniture(room, 0, 129, 0)
	assert_true(piece.ok, "legacy bed exists")
	_store._f_installed.fill(0)
	assert_equal(_store.legacy_save_refusal(), Buildings.REFUSE_VERSIONED_CODEC, "capture cannot silently drop pending flags")
	assert_true(_store.restore_section_1_columns(_store._building_slot, _store._room_slot,
		_store._furniture_slot), "known old surface image initializes the additive column")
	assert_true(_store.is_furniture_installed(piece.ref), "old live surface row is installed")
	assert_equal(_store.legacy_save_refusal(), &"", "initialized legacy owner can save")
	_store._f_installed[_store.directory().get_typed_row(piece.ref)] = 2
	var before: PackedByteArray = _image()
	assert_false(_store.restore_section_1_columns(_store._building_slot, _store._room_slot,
		_store._furniture_slot), "unknown installed flag cannot be normalized away")
	assert_equal(_image(), before, "unknown flag refusal preserves bytes")
	_store._f_installed.fill(0)
	_store._r_spatial_kind[_store.directory().get_typed_row(room)] = 2
	assert_false(_store.spatial_kind_of_room(room).ok, "unknown spatial domain refuses")
	assert_false(_store.room_is_valid(room), "unknown domain grants no service")
	assert_false(_store.restore_section_1_columns(_store._building_slot, _store._room_slot,
		_store._furniture_slot), "unknown room flag also cannot be normalized away")
