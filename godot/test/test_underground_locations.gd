extends "res://test/framework/test_case.gd"
## Actual packed space/Inventory identities with explicit synthetic surface geometry. This
## proves endpoint ownership and transactions, not production terrain or traversal profiles.

const Budget := preload("res://scripts/core/underground_budget.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CAPACITY: int = 4
const COLD_BYTES: int = 1048576

var _buildings: Buildings = null
var _construction: Construction = null
var _transforms: Transforms = null
var _inventory: Inventory = null
var _items: Items = null
var _world: Vector2i = NULL_REF
var _sources: Owner.CoreSources = null
var _owner: Owner = null
var _domain: Space.Domain = null
var _cold: Budget = null
var _locations: Locations = null
var _adapter: Locations.InventoryLocations = null
var _floor_ref: Vector2i = NULL_REF
var _void_ref: Vector2i = NULL_REF
var _support_ref: Vector2i = NULL_REF


func before_each() -> void:
	"""Real shared generations and finite goods owners; test-only geometry is labelled above."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_transforms = Transforms.new(_buildings.directory())
	_inventory = Inventory.new(16, 16)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual adopted item definitions")
	_world = _buildings.directory().create(Directory.KIND_WORLD)
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction)
	_domain = Space.Domain.new()
	assert_equal(_domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 64, 64, 100000), &"", "bounded synthetic domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain, 64, 16), &"", "actual packed owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	_floor_ref = _put(token, [-4096, 0, -4096, 4096, 1, 4096], Space.FLOOR_DATUM)
	_void_ref = _put(token, [-4096, 0, -4096, 4096, 2048, 4096], Space.SUPPORTED_VOID)
	_support_ref = _put(token, [-4096, -256, -4096, 4096, 0, 4096], Space.SUPPORT)
	assert_equal(_owner.seal(token), &"", "actual initial geometry")
	_owner.publish(token)
	_cold = Budget.new()
	_locations = Locations.new()
	assert_equal(_configure(_locations, CAPACITY, 228 * CAPACITY + 256), &"", "explicit jointly reserved endpoint arena")
	_adapter = Locations.InventoryLocations.new(_locations)
	assert_true(_inventory.bind_spatial_locations(_adapter, 4).ok, "actual Inventory adapter")


func after_each() -> void:
	"""Drop weak adapters and borrowed owners in an acyclic order."""
	assert_true(_cold.is_quiescent(), "all borrowed cold leases released")
	_adapter = null
	_locations = null
	_cold = null
	_owner = null
	_sources = null
	_domain = null
	_inventory = null
	_items = null
	_transforms = null
	_construction = null
	_buildings = null


func _configure(locations: Locations, capacity: int, bytes: int) -> StringName:
	"""Every endpoint owner borrows the same exact real collaborators."""
	return locations.configure(_buildings.directory(), _buildings, _transforms, _inventory,
		_owner, _sources, _cold, capacity, bytes)


func _put(token: int, box: Array[int], role: int) -> Vector2i:
	"""Write actual region records; these fixture dimensions are not the production content catalog."""
	var row: Owner.Region = Owner.Region.new()
	row.box = PackedInt32Array(box)
	row.role = role
	row.owner = _world
	row.level = 0
	var result: Owner.Result = _owner.stage_add(token, row)
	assert_equal(result.error, &"", "actual region: %s" % result.error)
	return result.handle


func _record(x: int = -512, y: int = 0, z: int = 512) -> Locations.Record:
	"""Explicit integer storage envelope, floor and whole-footprint support."""
	var record: Locations.Record = Locations.Record.new()
	record.point = Vector3i(x, y, z)
	record.section = _floor_ref
	record.level = 0
	record.role = Locations.ROLE_STORAGE
	record.envelope = PackedInt32Array([x - 256, y, z - 256, x + 256, y + 512, z + 256])
	record.support = PackedInt32Array([x - 256, y - 128, z - 256, x + 256, y, z + 256])
	return record


func _add(record: Locations.Record = null) -> Vector2i:
	"""Commit real endpoint metadata only after full supported-void validation."""
	var cold: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(cold)
	assert_equal(prepared.error, &"", "location preparation")
	var added: Locations.Result = _locations.stage_add(prepared.token, record if record != null else _record())
	assert_equal(added.error, &"", "supported endpoint: %s" % added.error)
	assert_equal(_locations.seal(prepared.token), &"", "sealed metadata")
	assert_true(_locations.publish(prepared.token), "publish metadata")
	assert_equal(_cold.release(cold), &"", "consume cold output before release")
	return added.location


func _image() -> PackedByteArray:
	"""One cold image whose lifetime is explicit in each caller's test scope."""
	var lease: int = _cold.acquire(COLD_BYTES)
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(_locations.capture_state_into(lease, bytes), &"", "local endpoint image")
	assert_equal(_cold.release(lease), &"", "test retains image within its separately generous fixture budget")
	return bytes


func test_exact_real_binding_and_full_local_refs() -> void:
	"""Foreign stores with coincident numeric World refs cannot supply an endpoint authority."""
	var location: Vector2i = _add()
	assert_true(_locations.is_bound_world(_buildings.directory(), _world, _owner), "actual owner")
	assert_true(_adapter.exact_binding(_inventory, _world), "actual Inventory")
	assert_false(_adapter.exact_binding(Inventory.new(16, 16), _world), "foreign Inventory")
	assert_false(_locations.is_live_location(Vector2i(location.x, location.y + 1)), "reused local generation")
	assert_true(_locations.is_bound_budget(_cold), "the exact shared Budget instance")
	assert_false(_locations.is_bound_budget(Budget.new()), "matching capacity does not bind a foreign arena")
	assert_false(_locations.is_bound_budget(null), "no unbound cold consumer")
	assert_equal(_adapter.location_revision(location), 1, "immutable payload")
	assert_equal(_adapter.storage_endpoint_refusal(location), &"", "actual support proof")
	assert_equal(_locations.configure(null, null, null, null, null, null, null, 1, 512),
		&"LOCATION_ALREADY_BOUND", "no collaborator rebind")


func test_actual_shared_budget_blocks_capture_overlap_and_foreign_tokens() -> void:
	"""Captured output keeps the one actual reservation; another consumer cannot allocate beside it."""
	var foreign: Budget = Budget.new()
	var unrelated: int = foreign.acquire(COLD_BYTES)
	assert_true(unrelated > 0, "foreign world can independently reserve its own budget")
	assert_equal(_locations.begin_prepare(unrelated).error, &"LOCATION_COLD_CAPACITY",
		"numeric token coincidence does not activate this world's unreserved Budget")
	assert_equal(foreign.release(unrelated), &"", "release unrelated operation")
	var cold: int = _cold.acquire(_locations.wire_bytes())
	var image: PackedByteArray = PackedByteArray()
	assert_equal(_locations.capture_state_into(cold, image), &"", "real borrowed capture reservation")
	assert_equal(_cold.acquire(_locations.cold_peak_bytes()), 0, "captured image excludes unrelated operations")
	assert_equal(_locations.begin_prepare(cold).error, &"LOCATION_COLD_CAPACITY", "wire-only charge cannot fund a survey")
	assert_equal(_cold.extend(cold, _locations.cold_peak_bytes()), &"", "nested work must explicitly reserve coexistence")
	assert_equal(_locations.restore_state_bytes(cold, image), &"", "same lease accounts for retained input plus validation")
	image.clear()
	assert_equal(_cold.release(cold), &"", "release only after charged image is discarded")


func test_arena_and_cold_admission_refuse_before_allocation() -> void:
	"""Technical capacity is explicit; no over-budget implicit default is allocated."""
	var other: Locations = Locations.new()
	assert_equal(_configure(other, CAPACITY, 228 * CAPACITY + 255), &"LOCATION_ARENA_CAPACITY", "one byte short")
	assert_equal(other.packed_memory_bytes(), 0, "no partial bank allocation")
	assert_equal(_locations.packed_memory_bytes(), 228 * CAPACITY + 256, "both banked heaps/indexes counted")
	assert_equal(_locations.wire_bytes(), 106 * CAPACITY + 128, "exact one-bank wire")
	assert_equal(_locations.begin_prepare(0).error, &"LOCATION_COLD_CAPACITY", "no anonymous cold work")
	var lease: int = _cold.acquire(1)
	assert_equal(_locations.begin_prepare(lease).error, &"LOCATION_COLD_CAPACITY", "undersized lease")
	assert_equal(_cold.acquire(COLD_BYTES), 0, "one operation at a time")
	assert_equal(_cold.release(lease), &"", "release own token")
	assert_equal(_cold.release(lease), Budget.REFUSE_TOKEN, "no duplicate release")


func test_reads_do_not_alias_packed_geometry() -> void:
	"""One caller-owned packet can be reused without mutating immutable locations."""
	var location: Vector2i = _add()
	var output: Locations.Record = Locations.Record.new()
	assert_equal(_locations.read_location_into(location, output), &"LOCATION_OUTPUT_SHAPE", "no hidden hot allocation")
	output.envelope.resize(6)
	output.support.resize(6)
	assert_equal(_locations.read_location_into(location, output), &"", "actual identity and geometry")
	assert_equal(output.world, _world, "exact World")
	assert_equal(output.point, Vector3i(-512, 0, 512), "integer location")
	output.envelope.fill(9)
	assert_equal(_locations.read_location_into(location, output), &"", "copy again")
	assert_equal(output.envelope[0], -768, "no mutable alias")


func test_negative_cells_and_stacked_sections_do_not_alias() -> void:
	"""Mathematical floor at a negative coordinate differs from truncation toward zero."""
	var first: Vector2i = _add(_record(-1))
	var alias: Vector2i = _add(_record(-1024))
	var next: Vector2i = _add(_record(0))
	assert_true(_locations.same_storage_cell(first, alias), "same negative 2m cell")
	assert_false(_locations.same_storage_cell(first, next), "zero is a different cell")
	var token: int = _owner.begin_stage(_owner.revision()).token
	var upper: Vector2i = _put(token, [-4096, 4096, -4096, 4096, 4097, 4096], Space.FLOOR_DATUM)
	_put(token, [-4096, 4096, -4096, 4096, 6144, 4096], Space.SUPPORTED_VOID)
	_put(token, [-4096, 3840, -4096, 4096, 4096, 4096], Space.SUPPORT)
	assert_equal(_owner.seal(token), &"", "actual upper floor")
	_owner.publish(token)
	var record: Locations.Record = _record(-1, 4096)
	record.section = upper
	var raised: Vector2i = _add(record)
	assert_false(_locations.same_storage_cell(first, raised), "same X/Z, distinct full sections")


func test_support_hole_refuses_despite_supported_corners() -> void:
	"""Exact union coverage catches a central unsupported strip."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_remove(token, _support_ref), &"", "replace support with two separated slabs")
	_put(token, [-4096, -256, -4096, -600, 0, 4096], Space.SUPPORT)
	_put(token, [-500, -256, -4096, 4096, 0, 4096], Space.SUPPORT)
	assert_equal(_owner.seal(token), &"", "valid actual support facts")
	_owner.publish(token)
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_add(prepared.token, _record()).error, &"LOCATION_COVERAGE_MISSING", "hole cannot inherit support")
	assert_true(_locations.abort(prepared.token), "no partial location")
	assert_equal(_cold.release(lease), &"", "release cold operation")


func test_water_unfinished_obstacle_and_boundary_refuse() -> void:
	"""No actual obstruction or outside edge can be converted into storage just by naming a floor."""
	var record: Locations.Record = _record()
	record.envelope[3] = 8193
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_add(prepared.token, record).error, &"LOCATION_GEOMETRY_FORMAT", "domain outside")
	_locations.abort(prepared.token)
	_cold.release(lease)
	for role: int in [Space.WATER, Space.UNFINISHED, Space.OBSTACLE]:
		var token: int = _owner.begin_stage(_owner.revision()).token
		var block: Vector2i = _put(token, [-700, 0, 400, -600, 128, 500], role)
		assert_equal(_owner.seal(token), &"", "actual obstructing row")
		_owner.publish(token)
		lease = _cold.acquire(COLD_BYTES)
		prepared = _locations.begin_prepare(lease)
		assert_equal(_locations.stage_add(prepared.token, _record()).error, &"LOCATION_ENVELOPE_BLOCKED", "obstruction remains")
		_locations.abort(prepared.token)
		_cold.release(lease)
		token = _owner.begin_stage(_owner.revision()).token
		_owner.stage_remove(token, block)
		assert_equal(_owner.seal(token), &"", "remove test obstruction")
		_owner.publish(token)


func test_stale_geometry_requires_explicit_refresh_without_payload_change() -> void:
	"""An unrelated actual edit invalidates a proof but never invalidates Inventory's retained revision."""
	var location: Vector2i = _add()
	var revision: int = _locations.location_revision(location)
	var token: int = _owner.begin_stage(_owner.revision()).token
	_put(token, [3000, 0, 3000, 3100, 128, 3100], Space.OBSTACLE)
	assert_equal(_owner.seal(token), &"", "unrelated geometry change")
	_owner.publish(token)
	assert_equal(_locations.storage_endpoint_refusal(location), &"LOCATION_GEOMETRY_STALE", "read refuses rather than refreshes")
	assert_equal(_locations.location_revision(location), revision, "payload identity retained")
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_refresh(prepared.token, location), &"", "explicit cold refresh")
	assert_equal(_locations.seal(prepared.token), &"", "new proof prepared")
	assert_true(_locations.publish(prepared.token), "new proof published")
	_cold.release(lease)
	assert_equal(_locations.storage_endpoint_refusal(location), &"", "current support proof")
	assert_equal(_locations.location_revision(location), revision, "no replacement payload")


func test_actual_inventory_promotion_and_retirement_guard() -> void:
	"""Real finite ground-pile promotion retains the actual full location while conserving goods."""
	var location: Vector2i = _add()
	var staging: Inventory.OpResult = _inventory.create_spatial_ground_staging(location)
	assert_true(staging.ok, "actual spatial staging")
	assert_true(_inventory.begin().ok, "actual transaction")
	assert_true(_inventory.create_lot(staging.ref, _items.compiled_id(&"excavated_earth"), 2000,
		int(Catalog.QUALITY["PLAIN"]), Catalog.PROVENANCE_EXCAVATION, -1, 0, 0).ok, "actual earth output")
	assert_true(_inventory.promote_to_spatial_ground_pile(staging.ref, location).ok, "same row promotes")
	assert_true(_inventory.commit().ok, "real output commits")
	assert_equal(_inventory.spatial_location_of(staging.ref), location, "full local generation")
	assert_true(_inventory.container_anchor_tile(staging.ref) < Inventory.UNPLACED_TILE, "dedicated non-surface endpoint")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 2000, "no lost goods")
	assert_true(_inventory.audit().ok, "actual endpoint and goods audit")
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_remove(prepared.token, location), &"LOCATION_INVENTORY_RETAINED", "real container keeps location")
	_locations.abort(prepared.token)
	_cold.release(lease)


func test_abort_and_stale_seal_do_not_publish_locations() -> void:
	"""A geometry edit between validation and publication cannot authorize an obsolete endpoint."""
	var before: PackedByteArray = _image()
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	var added: Locations.Result = _locations.stage_add(prepared.token, _record())
	assert_equal(added.error, &"", "candidate only")
	assert_false(_locations.is_live_location(added.location), "not live before seal/publish")
	assert_equal(_locations.seal(prepared.token), &"", "sealed metadata")
	var token: int = _owner.begin_stage(_owner.revision()).token
	_put(token, [3000, 0, 3000, 3100, 128, 3100], Space.OBSTACLE)
	assert_equal(_owner.seal(token), &"", "later geometry")
	_owner.publish(token)
	assert_false(_locations.publish(prepared.token), "stale sealed candidate cannot publish")
	assert_true(_locations.abort(prepared.token), "abort exact token")
	_cold.release(lease)
	assert_equal(_image(), before, "live bytes unchanged")


func test_exhaustion_reuse_and_wire_round_trip() -> void:
	"""Deterministic lowest-slot reuse increments full generations; canonical images round-trip."""
	var refs: Array[Vector2i] = []
	for index: int in CAPACITY:
		refs.append(_add(_record(-512 + index * 512)))
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_add(prepared.token, _record()).error, &"LOCATION_ARENA_FULL", "finite technical exhaustion")
	assert_equal(_locations.stage_remove(prepared.token, refs[1]), &"", "unretained endpoint removal")
	var replacement: Locations.Result = _locations.stage_add(prepared.token, _record(512))
	assert_equal(replacement.location, Vector2i(refs[1].x, refs[1].y + 1), "lowest free row, new generation")
	assert_equal(_locations.seal(prepared.token), &"", "seal reuse")
	assert_true(_locations.publish(prepared.token), "publish reuse")
	_cold.release(lease)
	assert_false(_locations.is_live_location(refs[1]), "old generation stale")
	var bytes: PackedByteArray = _image()
	lease = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.restore_state_bytes(lease, bytes), &"", "streamed bounded local restore")
	_cold.release(lease)
	assert_equal(_image(), bytes, "canonical local image equality")


func test_malformed_image_and_foreign_floor_preserve_live_bytes() -> void:
	"""Wire parsing checks explicit schemas, full section generation and unknown role values."""
	var location: Vector2i = _add()
	var before: PackedByteArray = _image()
	for field: int in [Locations.SECTION_GENERATION, Locations.ROLE]:
		var corrupt: PackedByteArray = before.duplicate()
		corrupt.encode_s32(128 + (field * CAPACITY + location.x) * 4, 12345)
		var lease: int = _cold.acquire(COLD_BYTES)
		assert_true(_locations.restore_state_bytes(lease, corrupt) != &"", "malformed full payload refuses")
		_cold.release(lease)
		assert_equal(_image(), before, "no partial restore")


func test_unqualified_transit_role_never_grants_storage() -> void:
	"""A supported contact or transit point alone cannot become a pile endpoint."""
	var record: Locations.Record = _record()
	record.role = Locations.ROLE_TRANSIT
	var location: Vector2i = _add(record)
	assert_equal(_locations.storage_endpoint_refusal(location), &"LOCATION_NOT_STORAGE", "role explicit")
	assert_false(_inventory.create_spatial_ground_staging(location).ok, "actual Inventory refuses")


func test_load_cannot_repoint_a_live_immutable_handle() -> void:
	"""Even an unretained local handle cannot acquire another position at the same generation."""
	var location: Vector2i = _add()
	var before: PackedByteArray = _image()
	var changed: PackedByteArray = before.duplicate()
	changed.encode_s32(128 + (Locations.X * CAPACITY + location.x) * 4, -511)
	var lease: int = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.restore_state_bytes(lease, changed), &"LOCATION_IMMUTABLE_PAYLOAD", "valid geometry is not identity permission")
	_cold.release(lease)
	assert_equal(_image(), before, "no changed live payload")


func test_load_requires_canonical_generation_exhaustion() -> void:
	"""An exhausted absent slot cannot disguise itself as free or revive through the free heap."""
	var before: PackedByteArray = _image()
	var changed: PackedByteArray = before.duplicate()
	changed.encode_s32(128, Space.I32_MAX)
	var lease: int = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.restore_state_bytes(lease, changed), &"LOCATION_IMAGE_LIFECYCLE", "exhaustion flag required")
	_cold.release(lease)
	assert_equal(_image(), before, "malformed lifecycle refused atomically")


func test_future_location_requires_actual_sites_binding() -> void:
	"""A sealed geometry token alone supplies no permission to publish a future endpoint."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	_put(token, [3000, 0, 3000, 3100, 128, 3100], Space.OBSTACLE)
	assert_equal(_owner.seal(token), &"", "real sealed candidate")
	var lease: int = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.begin_prepare(lease, token, Vector2i(0, 1), 2, 2).error,
		&"LOCATION_SITE_OWNER", "coincident numeric site is not the actual phase owner")
	_cold.release(lease)
	_owner.abort(token)


func test_post_seal_inventory_retention_prevents_location_retirement() -> void:
	"""A real container created against still-live metadata after sealing cannot lose its location."""
	var location: Vector2i = _add()
	var before: PackedByteArray = _image()
	var lease: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(lease)
	assert_equal(_locations.stage_remove(prepared.token, location), &"", "currently unretained endpoint")
	assert_equal(_locations.seal(prepared.token), &"", "sealed retirement candidate")
	assert_equal(_locations.prepared_refusal(prepared.token), &"", "pre-retention preflight")
	var container: Inventory.OpResult = _inventory.create_spatial_ground_staging(location)
	assert_true(container.ok, "actual Inventory may bind still-live endpoint")
	assert_equal(_locations.prepared_refusal(prepared.token), &"LOCATION_INVENTORY_RETAINED", "final preflight sees new ownership")
	assert_false(_locations.publish(prepared.token), "publication rechecks even without caller preflight")
	assert_true(_locations.is_live_location(location), "retained location remains")
	assert_equal(_inventory.spatial_location_of(container.ref), location, "real container keeps exact ref")
	assert_true(_inventory.audit().ok, "retained endpoint audit")
	assert_true(_locations.abort(prepared.token), "discard refused candidate only")
	_cold.release(lease)
	assert_equal(_image(), before, "live endpoint bytes unchanged")
