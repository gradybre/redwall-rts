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
const OwnerFixture := preload("res://test/test_underground_space_owner.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const RoomOrderTests := preload("res://test/test_underground_room_orders.gd")
const RoomFixture := preload("res://test/test_underground_furniture_work.gd")
const TestCase := preload("res://test/framework/test_case.gd")
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


func test_prepared_endpoint_reader_requires_seal_and_preserves_bank_isolation() -> void:
	"""Topology can bind an unborn endpoint only through this owner's still-valid sealed transaction."""
	var cold: int = _cold.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	var added: Locations.Result = _locations.stage_add(token, _record())
	assert_equal(added.error, &"", "actual prepared endpoint")
	var out: Locations.Record = _record(1024)
	assert_equal(_locations.prepared_location_into(token, added.location, out), &"LOCATION_TOKEN_STALE", "unsealed refuses")
	assert_equal(out.point.x, 1024, "refused output remains unchanged")
	assert_equal(_locations.seal(token), &"", "actual current seal")
	assert_equal(_locations.prepared_location_into(token + 1, added.location, out), &"LOCATION_TOKEN_STALE", "foreign token")
	assert_equal(_locations.prepared_location_into(token, added.location, out), &"", "copy exact sealed endpoint")
	assert_equal(out.point, Vector3i(-512, 0, 512), "prepared actual coordinates")
	assert_false(_locations.is_live_location(added.location), "prepared endpoint is not public")
	out.envelope[0] = 999
	out.point.x = 999
	assert_equal(_locations.prepared_location_into(token, added.location, out), &"", "caller edits do not change stage")
	assert_equal(out.envelope[0], -768, "copied envelope never aliases stage storage")
	assert_equal(out.point.x, -512, "scalar output restored from actual stage")
	assert_true(_locations.abort(token), "aborted transaction publishes nothing")
	assert_equal(_locations.prepared_location_into(token, added.location, out), &"LOCATION_TOKEN_STALE", "expired token")
	assert_equal(_cold.release(cold), &"", "no charged output survives")


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


class RetainedGraph extends Locations.Retention:
	## Synthetic retention-only observer; full Routes composition is tested in its own suite.
	var actual: Locations = null
	var retained: Vector2i = NULL_REF
	var reenter: bool = false
	var token: int = 0
	var inventory: Inventory = null
	var trigger: Vector2i = NULL_REF
	var create_at: Vector2i = NULL_REF
	var created: Vector2i = NULL_REF
	var cold: Budget = null
	var cold_token: int = 0
	var released: bool = false

	func exact_binding(locations: RefCounted) -> bool:
		"""The actual endpoint object remains part of the local-ref namespace."""
		return locations == actual

	func retains(location: Vector2i) -> bool:
		"""Attempted observer-side abort must not destroy an otherwise valid candidate."""
		if reenter:
			actual.abort(token)
		if location == trigger and inventory != null and created == NULL_REF:
			created = inventory.create_spatial_ground_staging(create_at).ref
		if location == trigger and cold != null and not released:
			released = cold.release(cold_token) == &""
		return location == retained


func test_graph_retention_preserves_live_endpoints_at_all_publication_boundaries() -> void:
	"""An edge or resident retained after sealing prevents removal without modifying live bytes."""
	var location: Vector2i = _add()
	var before: PackedByteArray = _image()
	var graph: RetainedGraph = RetainedGraph.new()
	graph.actual = _locations
	assert_equal(_locations.bind_retention(graph), &"", "exact weak graph binding")
	var cold: int = _cold.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	graph.retained = location
	assert_equal(_locations.stage_remove(token, location), &"LOCATION_ROUTE_RETAINED", "live edge keeps endpoint")
	graph.retained = NULL_REF
	assert_equal(_locations.stage_remove(token, location), &"", "unretained candidate removal")
	assert_equal(_locations.seal(token), &"", "exact prepared removal")
	graph.retained = location
	assert_equal(_locations.prepared_refusal(token), &"LOCATION_ROUTE_RETAINED", "post-seal edge checked")
	assert_false(_locations.publish(token), "cannot strand an actor or retained path")
	assert_true(_locations.abort(token), "normal caller abort remains usable")
	_cold.release(cold)
	assert_equal(_image(), before, "all live bytes retained")


func test_graph_retention_refuses_load_that_removes_or_recycles_a_live_location() -> void:
	"""A prior canonical image cannot erase graph references even with no Inventory pile."""
	var empty: PackedByteArray = _image()
	var location: Vector2i = _add()
	var before: PackedByteArray = _image()
	var graph: RetainedGraph = RetainedGraph.new()
	graph.actual = _locations
	graph.retained = location
	assert_equal(_locations.bind_retention(graph), &"", "actual endpoint namespace")
	var cold: int = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.restore_state_bytes(cold, empty), &"LOCATION_ROUTE_RETAINED", "canonical absence still retained")
	_cold.release(cold)
	assert_equal(_image(), before, "load preserves actual retained identity")


func test_expired_foreign_and_reentrant_graph_observers_fail_closed() -> void:
	"""Weak observer expiration never silently grants retirement, and reentry cannot consume a token."""
	var location: Vector2i = _add()
	var foreign: RetainedGraph = RetainedGraph.new()
	assert_equal(_locations.bind_retention(foreign), &"LOCATION_RETENTION_BINDING", "wrong namespace")
	foreign.actual = _locations
	assert_equal(_locations.bind_retention(foreign), &"", "same actual owner")
	var cold: int = _cold.acquire(COLD_BYTES)
	foreign.token = _locations.begin_prepare(cold).token
	foreign.reenter = true
	assert_equal(_locations.stage_remove(foreign.token, location), &"LOCATION_RETENTION_BINDING", "callback abort poisoned")
	foreign.reenter = false
	assert_equal(_locations.stage_remove(foreign.token, location), &"", "same caller token survives")
	assert_equal(_locations.seal(foreign.token), &"", "retry remains possible")
	var token: int = foreign.token
	foreign = null
	assert_equal(_locations.prepared_refusal(token), &"LOCATION_RETENTION_BINDING", "expired required observer")
	assert_false(_locations.publish(token), "cannot publish after owner disappears")
	assert_true(_locations.abort(token), "caller can discard incomplete candidate")
	_cold.release(cold)
	assert_true(_locations.is_live_location(location), "original endpoint still lives")


func test_actual_endpoint_capacity_reader_never_infers_a_smaller_namespace() -> void:
	"""Graph scratch must cover every full Location row before any allocation."""
	assert_false(Locations.new().allocation_within(CAPACITY), "unbound has no admitted arena")
	assert_false(_locations.allocation_within(-1), "negative bound")
	assert_false(_locations.allocation_within(CAPACITY - 1), "undersized graph lookup")
	assert_true(_locations.allocation_within(CAPACITY), "exact capacity")
	assert_true(_locations.allocation_within(CAPACITY + 1), "conservative larger lookup")


func test_later_retention_callback_cannot_strand_earlier_actual_inventory_endpoint() -> void:
	"""The last pure Inventory pass follows every observer, including a callback for a later row."""
	var first: Vector2i = _add(_record(-512))
	var second: Vector2i = _add(_record(512))
	var before: PackedByteArray = _image()
	var graph: RetainedGraph = RetainedGraph.new()
	graph.actual = _locations
	assert_equal(_locations.bind_retention(graph), &"", "real namespace")
	var cold: int = _cold.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	assert_equal(_locations.stage_remove(token, first), &"", "first initially unretained")
	assert_equal(_locations.stage_remove(token, second), &"", "second initially unretained")
	assert_equal(_locations.seal(token), &"", "both initially removable")
	graph.inventory = _inventory
	graph.trigger = second
	graph.create_at = first
	assert_equal(_locations.prepared_refusal(token), &"LOCATION_INVENTORY_RETAINED", "later callback retained earlier row")
	assert_true(_inventory.is_container_valid(graph.created), "actual container was created")
	assert_false(_locations.publish(token), "no orphaned actual container")
	assert_true(_locations.abort(token), "discard")
	_cold.release(cold)
	assert_equal(_image(), before, "both full endpoints preserved")
	assert_true(_inventory.audit().ok, "actual Inventory still resolves endpoint")


func test_observer_released_cold_lease_refuses_final_publication() -> void:
	"""A callback cannot spend another operation's now-unreserved preparation image."""
	var location: Vector2i = _add()
	var graph: RetainedGraph = RetainedGraph.new()
	graph.actual = _locations
	assert_equal(_locations.bind_retention(graph), &"", "exact graph")
	var cold: int = _cold.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	assert_equal(_locations.stage_remove(token, location), &"", "initially removable")
	assert_equal(_locations.seal(token), &"", "ready candidate")
	graph.cold = _cold
	graph.cold_token = cold
	graph.trigger = location
	assert_false(_locations.publish(token), "released lease cannot publish")
	assert_true(graph.released, "adversarial observer reached actual Budget")
	assert_true(_locations.is_live_location(location), "live identity remains")
	assert_true(_locations.abort(token), "caller cleanup is still possible")


func test_restore_rechecks_actual_inventory_and_lease_after_observer_callbacks() -> void:
	"""A load cannot discard real goods or publish after a callback releases its reserved image."""
	var empty: PackedByteArray = _image()
	var location: Vector2i = _add()
	var graph: RetainedGraph = RetainedGraph.new()
	graph.actual = _locations
	graph.trigger = location
	graph.inventory = _inventory
	graph.create_at = location
	assert_equal(_locations.bind_retention(graph), &"", "exact graph")
	var cold: int = _cold.acquire(COLD_BYTES)
	assert_equal(_locations.restore_state_bytes(cold, empty), &"LOCATION_INVENTORY_RETAINED", "load callback creates real retention")
	assert_true(_inventory.is_container_valid(graph.created), "actual retained staging container")
	assert_true(_locations.is_live_location(location), "load never dropped it")
	graph.cold = _cold
	graph.cold_token = cold
	assert_equal(_locations.restore_state_bytes(cold, empty), &"LOCATION_COLD_CAPACITY", "observer releases actual lease")
	assert_true(graph.released, "callback ran")
	assert_true(_locations.is_live_location(location), "load still preserves location")
	assert_true(_inventory.audit().ok, "retained container remains valid")


class DoorwayFixture extends RefCounted:
	## Real Room/Sites identities with explicitly synthetic adjacent finished shell geometry.
	var commands: OwnerFixture.SyntheticRoomCommands = null
	var physical: OwnerFixture.SiteFixture = null
	var rooms: Array[Vector2i] = []
	var floors: Array[Vector2i] = []
	var voids: Array[Vector2i] = []
	var supports: Array[Vector2i] = []


func _doorway(claim_sites: bool = true) -> DoorwayFixture:
	"""Each root belongs to one exact Room while its complete body can straddle the shared doorway."""
	var fixture: DoorwayFixture = DoorwayFixture.new()
	fixture.commands = OwnerFixture.SyntheticRoomCommands.new()
	fixture.commands.owner = weakref(_buildings)
	assert_true(_buildings.bind_spatial_authority(fixture.commands).ok, "actual Buildings authority")
	for room_type: int in [Buildings.ROOM_TYPE_KITCHEN, Buildings.ROOM_TYPE_DORMITORY]:
		fixture.commands.permit(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, room_type)
		fixture.rooms.append(_buildings.designate_spatial_room(room_type).ref)
	fixture.physical = OwnerFixture.SiteFixture.new(_construction, _buildings, _domain)
	assert_equal(_locations.bind_sites(fixture.physical.sites), &"", "same actual paid-key owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	for index: int in 2:
		var x: int = (index - 1) * 1024
		if claim_sites:
			assert_true(fixture.physical.sites.claim_quantum(Vector3i(x, -2048, 0), fixture.rooms[index]).ok, "actual Room key")
		_doorway_room_rows(token, fixture, index, x)
	assert_equal(_owner.seal(token), &"", "separate actual synthetic finished shells")
	_owner.publish(token)
	return fixture


func _doorway_room_rows(token: int, fixture: DoorwayFixture, index: int, x: int) -> void:
	"""The fixture explicitly publishes support and clear volume; metadata or Sites keys alone grant neither."""
	var room: Vector2i = fixture.rooms[index]
	assert_equal(_owner.stage_source(token, room), &"", "actual underground source")
	var floor_ref: Vector2i = _doorway_piece(token, room, NULL_REF,
		[x, -2048, 0, x + 1024, -2047, 1024], Space.FLOOR_DATUM)
	fixture.floors.append(floor_ref)
	fixture.voids.append(_doorway_piece(token, room, floor_ref,
		[x, -2048, 0, x + 1024, -1024, 1024], Space.SUPPORTED_VOID))
	fixture.supports.append(_doorway_piece(token, room, floor_ref,
		[x, -2304, 0, x + 1024, -2048, 1024], Space.SUPPORT))
	_doorway_piece(token, room, floor_ref, [x, -2048, 0, x + 1024, -1024, 1024], Space.OBSTACLE, true)


func _doorway_piece(token: int, room: Vector2i, section: Vector2i, box: Array[int], role: int,
		claim: bool = false) -> Vector2i:
	"""No test geometry bypasses the production source/section validation or substitutes an invented ref."""
	var row: Owner.Region = Owner.Region.new()
	row.box = PackedInt32Array(box)
	row.role = role
	row.owner = room
	row.section = section
	row.level = 1
	row.claim_kind = Owner.CLAIM_ROOM if claim else Owner.CLAIM_NONE
	row.claim_ref = room if claim else NULL_REF
	var result: Owner.Result = _owner.stage_add(token, row)
	assert_equal(result.error, &"", "actual typed room region")
	return result.handle


func _doorway_record(fixture: DoorwayFixture, side: int) -> Locations.Record:
	"""The root is64u inside its own Room while a512u body/support footprint spans both sides."""
	var record: Locations.Record = _record(-64 if side == 0 else 64, -2048, 512)
	record.room = fixture.rooms[side]
	record.section = fixture.floors[side]
	record.level = 1
	record.role = Locations.ROLE_TRANSIT
	return record


func _endpoint_refusal(record: Locations.Record) -> StringName:
	"""One bounded refused or accepted candidate is always discarded without changing endpoint state."""
	var cold: int = _cold.acquire(COLD_BYTES)
	var prepared: Locations.Result = _locations.begin_prepare(cold)
	assert_equal(prepared.error, &"", "current geometry and actual lease")
	var code: StringName = _locations.stage_add(prepared.token, record).error
	assert_true(_locations.abort(prepared.token), "discard test candidate")
	assert_equal(_cold.release(cold), &"", "release only after discarded survey")
	return code


func test_transit_doorway_spans_adjacent_rooms_but_placement_keeps_whole_section_rule() -> void:
	"""Only a transit body's boundary crossing uses complete supported physical union across Room markers."""
	var fixture: DoorwayFixture = _doorway()
	for side: int in 2:
		var record: Locations.Record = _doorway_record(fixture, side)
		assert_true(_locations.is_live_location(_add(record)), "both directions have a real supported endpoint")
		for role: int in [Locations.ROLE_STORAGE, Locations.ROLE_WORK]:
			record.role = role
			assert_equal(_endpoint_refusal(record), &"LOCATION_SECTION_CONTAINMENT", "placement still wholly fits own section")
	var outside: Locations.Record = _doorway_record(fixture, 1)
	outside.point.x = -1
	assert_equal(_endpoint_refusal(outside), &"LOCATION_SECTION_CONTAINMENT", "root cannot borrow adjacent Room identity")
	outside = _doorway_record(fixture, 0)
	outside.room = fixture.rooms[1]
	assert_equal(_endpoint_refusal(outside), &"LOCATION_ROOM_STALE", "full owning section/Room pair remains exact")


func test_transit_without_actual_site_or_with_changed_paid_domain_refuses() -> void:
	"""A doorway survey never replaces the full real Sites owner, root key and immutable domain proof."""
	var fixture: DoorwayFixture = _doorway(false)
	var record: Locations.Record = _doorway_record(fixture, 0)
	assert_equal(_endpoint_refusal(record), &"LOCATION_PAID_SITE_MISSING", "metadata and void do not invent a key")
	assert_true(fixture.physical.sites.claim_quantum(Vector3i(-1024, -2048, 0), fixture.rooms[1]).ok, "actual foreign Room owns key")
	assert_equal(_endpoint_refusal(record), &"LOCATION_PAID_SITE_MISSING", "same coordinates are not the correct Room")
	var other: Locations.Record = _doorway_record(fixture, 1)
	assert_true(fixture.physical.sites.claim_quantum(Vector3i(0, -2048, 0), fixture.rooms[1]).ok, "actual matching key")
	assert_equal(_endpoint_refusal(other), &"", "exact real source and domain")
	var shifted: Space.Domain = Space.Domain.new()
	assert_equal(shifted.configure(_world, Vector3i(1024, 0, 0), Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 64, 64, 100000), &"", "different synthetic paid datum")
	fixture.physical.spatial.domain = shifted
	assert_equal(_endpoint_refusal(other), &"SPACE_SITE_DOMAIN", "complete real domain proof remains mandatory")


func test_transit_doorway_retains_actual_walls_unfinished_and_support_holes() -> void:
	"""Room markers alone may omit; same-Room physical blockers and missing footing must still refuse."""
	var fixture: DoorwayFixture = _doorway()
	var record: Locations.Record = _doorway_record(fixture, 0)
	for role: int in [Space.OBSTACLE, Space.UNFINISHED, Space.PROTECTED_ACCESS]:
		var token: int = _owner.begin_stage(_owner.revision()).token
		var blocker: Vector2i = _doorway_piece(token, fixture.rooms[0], fixture.floors[0],
			[-128, -2048, 400, -1, -1536, 624], role)
		assert_equal(_owner.seal(token), &"", "actual physical blocker")
		_owner.publish(token)
		assert_equal(_endpoint_refusal(record), &"LOCATION_ENVELOPE_BLOCKED", "physical role%d remains" % role)
		token = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_remove(token, blocker), &"", "remove actual fixture obstruction")
		assert_equal(_owner.seal(token), &"", "restore doorway")
		_owner.publish(token)
	var support_token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_remove(support_token, fixture.supports[1]), &"", "neighbouring side loses support")
	assert_equal(_owner.seal(support_token), &"", "publish actual support loss")
	_owner.publish(support_token)
	assert_equal(_endpoint_refusal(record), &"LOCATION_COVERAGE_MISSING", "root footing alone is insufficient")


func test_transit_pending_neighbour_claim_does_not_create_clear_volume() -> void:
	"""A still-planned neighbouring Room stays physically unavailable even when its reservation is omitted."""
	var fixture: DoorwayFixture = _doorway()
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_remove(token, fixture.voids[1]), &"", "actual neighbour has no completed cut")
	assert_equal(_owner.seal(token), &"", "planned claim and metadata remain")
	_owner.publish(token)
	assert_equal(_endpoint_refusal(_doorway_record(fixture, 0)), &"LOCATION_COVERAGE_MISSING", "unpaid/unbuilt half cannot pass")


func test_location_receipt_requires_exact_success_and_load_never_restores_it() -> void:
	"""Unsealed, refused or aborted candidates cannot stand in for a published immutable endpoint bank."""
	assert_equal(_locations.last_published_token(), 0, "unpublished owner")
	var lease: int = _cold.acquire(COLD_BYTES)
	var first: int = _locations.begin_prepare(lease).token
	assert_equal(_locations.stage_add(first, _record()).error, &"", "candidate endpoint")
	assert_false(_locations.publish(first), "unsealed refuses")
	assert_equal(_locations.last_published_token(), 0, "no partial receipt")
	assert_equal(_locations.seal(first), &"", "sealed first candidate")
	assert_true(_locations.publish(first), "actual bank swap")
	assert_equal(_locations.last_published_token(), first, "exact completed candidate")
	var second: int = _locations.begin_prepare(lease).token
	assert_equal(_locations.seal(second), &"", "sealed no-op candidate")
	assert_false(_locations.publish(second + 1), "wrong exact token")
	assert_equal(_locations.last_published_token(), first, "wrong token earns nothing")
	assert_true(_locations.abort(second), "discard invisible candidate")
	assert_equal(_locations.last_published_token(), first, "abort preserves last success")
	var image: PackedByteArray = PackedByteArray()
	assert_equal(_locations.capture_state_into(lease, image), &"", "actual wire capture")
	assert_equal(_locations.restore_state_bytes(lease, PackedByteArray()), &"LOCATION_IMAGE_SHAPE", "refused load")
	assert_equal(_locations.last_published_token(), first, "refused load preserves receipt")
	assert_equal(_locations.restore_state_bytes(lease, image), &"", "actual same-image restore")
	assert_equal(_locations.last_published_token(), 0, "load invalidates unsaved receipt")
	image.clear()
	assert_equal(_cold.release(lease), &"", "all charged output discarded")


class ObservedRoomOrders extends RoomFixture.SyntheticRegistration:
	## Real pure admission reader with adversarial callback effects, never synthetic identity success.
	var endpoints: WeakRef = null
	var reenter: bool = false
	var replace: bool = false
	var replacement: int = 0
	var nested_refused: bool = false

	func room_companion_refusal(room: Vector2i, room_type: int, space_token: int,
			cold_token: int, space: Owner, budget: Budget) -> StringName:
		"""Preserve the real scope check while probing mutation and replacement inside its caller guard."""
		var code: StringName = super.room_companion_refusal(room, room_type, space_token, cold_token, space, budget)
		if reenter:
			reenter = false
			nested_refused = (endpoints.get_ref() as Locations).begin_prepare(cold_token).error != &""
		if replace:
			replace = false
			var released: StringName = budget.release(cold_token)
			assert(released == &"", "replace the real originally held lease")
			replacement = budget.acquire(Budget.COLD_BYTES)
		return code


class RoomLocationBindings extends RoomOrderTests.RoomBindings:
	## Real Orders/Space/Locations publication; the inherited terrain/profile admission is synthetic.
	var endpoints: Locations = null
	var endpoint_refs: Array[Vector2i] = []
	var candidate: int = 0
	var before_seal_refused: bool = false
	var outside_publish_refused: bool = false
	var publication_ok: bool = false
	var restricted_mutations: bool = false
	var fail_after_seal: bool = false
	var skip_last: bool = false
	var probe_arguments: bool = false
	var arguments_refused: bool = false
	var probe_receipt: bool = false
	var receipt_refused: bool = false
	var mutate_request: bool = false
	var reenter_after_seal: bool = false
	var replace_after_seal: bool = false
	var remove_support: Vector2i = NULL_REF

	func room_plan_refusal(plan: RoomOrders.RoomPlan, room: Vector2i, token: int) -> StringName:
		"""The actual coordinator calls this BEFORE sealing; endpoint preparation must refuse here."""
		var code: StringName = super.room_plan_refusal(plan, room, token)
		before_seal_refused = endpoints.begin_room_prepare(arena_token, token, room, plan.room_type).error != &""
		if code == &"" and remove_support != NULL_REF:
			code = space.stage_remove(token, remove_support)
		return code

	func room_prepared_refusal(plan: RoomOrders.RoomPlan, room: Vector2i, token: int) -> StringName:
		"""Refresh completed endpoints in the real post-seal callback and retain the candidate to publication."""
		var code: StringName = super.room_prepared_refusal(plan, room, token)
		if code != &"":
			return code
		if probe_arguments:
			_probe_arguments(plan, room, token)
		_arm_callback_probe()
		var begun: Locations.Result = endpoints.begin_room_prepare(arena_token, token, room, plan.room_type)
		if begun.error != &"":
			return begun.error
		candidate = begun.token
		code = _refresh_endpoints()
		if code == &"":
			code = endpoints.seal(candidate)
		if code != &"":
			return code
		outside_publish_refused = not endpoints.publish(candidate)
		if mutate_request:
			original_plan.origin_u.x += 256
		return &"SYNTHETIC_LATE_ADMISSION_REFUSAL" if fail_after_seal else endpoints.prepared_refusal(candidate)

	func _arm_callback_probe() -> void:
		"""Arm only the post-seal attempt; the intentionally refused pre-seal observation is a separate probe."""
		var observed: ObservedRoomOrders = orders.get_ref() as ObservedRoomOrders
		observed.reenter = reenter_after_seal
		observed.replace = replace_after_seal
		reenter_after_seal = false
		replace_after_seal = false

	func _probe_arguments(plan: RoomOrders.RoomPlan, room: Vector2i, token: int) -> void:
		"""Every candidate parameter belongs to this exact real operation, not merely this World."""
		arguments_refused = endpoints.begin_room_prepare(arena_token + 1, token, room, plan.room_type).error != &"" \
			and endpoints.begin_room_prepare(arena_token, token + 1, room, plan.room_type).error != &"" \
			and endpoints.begin_room_prepare(arena_token, token, Vector2i(room.x, room.y + 1), plan.room_type).error != &"" \
			and endpoints.begin_room_prepare(arena_token, token, room, (plan.room_type + 1) % Buildings.ROOM_TYPE_COUNT).error != &""

	func _refresh_endpoints() -> StringName:
		"""Only proof refresh is legal; adding/removing even an otherwise valid existing contact is refused."""
		var record: Locations.Record = Locations.Record.new()
		record.envelope.resize(6)
		record.support.resize(6)
		var code: StringName = endpoints.read_location_into(endpoint_refs[0], record)
		if code != &"":
			return code
		restricted_mutations = endpoints.stage_add(candidate, record).error == &"LOCATION_ROOM_REFRESH_ONLY" \
			and endpoints.stage_remove(candidate, endpoint_refs[0]) == &"LOCATION_ROOM_REFRESH_ONLY" \
			and endpoints.restore_state_bytes(arena_token, PackedByteArray()) != &""
		for index: int in endpoint_refs.size() - (1 if skip_last else 0):
			code = endpoints.stage_refresh(candidate, endpoint_refs[index])
			if code != &"":
				return code
		return &""

	func discard_room_plan(room: Vector2i, token: int) -> void:
		"""The actual Room refusal discards its Location companion before the original lease is released."""
		if candidate != 0:
			var aborted: bool = endpoints.abort(candidate)
			assert(aborted, "actual retained Location candidate discarded")
			candidate = 0
		super.discard_room_plan(room, token)

	func publish_room_plan(room: Vector2i, token: int) -> void:
		"""Actual Room and exact Space already exist; only this real same-stack callback may swap endpoints."""
		if probe_receipt:
			var actual_receipt: int = space._last_published_token
			space._last_published_token = actual_receipt + 1
			receipt_refused = not endpoints.publish(candidate)
			space._last_published_token = actual_receipt
		publication_ok = endpoints.publish(candidate)
		candidate = 0
		super.publish_room_plan(room, token)


class RoomLocationFixture extends RoomFixture.Fixture:
	## Real stores and the actual confirmation callback order; initial surface geometry is synthetic.
	var locations: Locations = null
	var ground_floor: Vector2i = NULL_REF
	var ground_support: Vector2i = NULL_REF
	var transforms: Transforms = null
	var adapter: Locations.InventoryLocations = null
	var refs: Array[Vector2i] = []

	func _init(test_case: TestCase) -> void:
		"""Bind the shared real arena and create only pre-existing completed endpoint fixtures."""
		super(test_case, false, RoomLocationBindings.new())
		_seed_ground()
		transforms = Transforms.new(buildings.directory())
		locations = Locations.new()
		var rooms: RoomLocationBindings = bindings as RoomLocationBindings
		check(locations.configure(buildings.directory(), buildings, transforms, inventory,
			space, sources, rooms.arena, 4, 228 * 4 + 256) == &"", "actual endpoint composition")
		check(locations.bind_room_orders(orders) == &"", "actual sole Room authority")
		adapter = Locations.InventoryLocations.new(locations)
		check(inventory.bind_spatial_locations(adapter, 4).ok, "actual retained Inventory namespace")
		rooms.endpoints = locations
		(orders as ObservedRoomOrders).endpoints = weakref(locations)
		_seed_endpoints(rooms)

	func _configure_space() -> void:
		"""Replace only the fixture's authority with a real-reader observation subclass before actual binding."""
		orders = ObservedRoomOrders.new()
		super._configure_space()

	func _ground_region(token: int, box: PackedInt32Array, role: int) -> Vector2i:
		"""Explicit fixture World-owned geometry is not a production natural-surface qualification."""
		var region: Owner.Region = Owner.Region.new()
		region.owner = world
		region.level = 0
		region.role = role
		region.box = box
		var added: Owner.Result = space.stage_add(token, region)
		check(added.error == &"", "actual surface fixture region")
		return added.handle

	func _seed_ground() -> void:
		"""A completed World floor is already real before the virgin lower Room is confirmed."""
		var token: int = space.begin_stage(space.revision()).token
		ground_floor = _ground_region(token, PackedInt32Array([0, 0, 0, 4096, 1, 4096]), Space.FLOOR_DATUM)
		_ground_region(token, PackedInt32Array([0, 0, 0, 4096, 2048, 4096]), Space.SUPPORTED_VOID)
		ground_support = _ground_region(token, PackedInt32Array([0, -256, 0, 4096, 0, 4096]), Space.SUPPORT)
		check(space.seal(token) == &"", "actual completed surface fixture")
		space.publish(token)

	func _seed_endpoints(rooms: RoomLocationBindings) -> void:
		"""Publish actual local handles before starting any Room request; no unborn contact is borrowed."""
		var cold: int = rooms.arena.acquire(Budget.COLD_BYTES)
		var token: int = locations.begin_prepare(cold).token
		for x: int in [512, 2560]:
			var row: Locations.Record = Locations.Record.new()
			row.point = Vector3i(x, 0, 512)
			row.section = ground_floor
			row.role = Locations.ROLE_STORAGE
			row.level = 0
			row.envelope = PackedInt32Array([x - 128, 0, 384, x + 128, 512, 640])
			row.support = PackedInt32Array([x - 128, -128, 384, x + 128, 0, 640])
			var added: Locations.Result = locations.stage_add(token, row)
			check(added.error == &"", "existing completed endpoint")
			refs.append(added.location)
		check(locations.seal(token) == &"", "existing endpoint proof")
		check(locations.publish(token), "actual endpoint publication")
		check(rooms.arena.release(cold) == &"", "seed images dropped")
		rooms.endpoint_refs = refs

	func plan() -> RoomOrders.RoomPlan:
		"""The pending lower Room is separate from the already completed surface contacts."""
		var out: RoomOrders.RoomPlan = RoomOrders.RoomPlan.new()
		out.world = world
		out.space_revision = space.revision()
		out.room_type = Buildings.ROOM_TYPE_KITCHEN
		out.level = 1
		out.origin_u = Vector3i(512, -4096, 1024)
		out.cell_size_u = 256
		out.height_u = 1024
		out.cells = PackedInt32Array([0, 0, 1, 0, 0, 1])
		return out

	func location_image() -> PackedByteArray:
		"""An explicit test-only retained image supports byte-exact refusal assertions."""
		var arena: Budget = (bindings as RoomLocationBindings).arena
		var token: int = arena.acquire(Budget.COLD_BYTES)
		var out: PackedByteArray = PackedByteArray()
		check(locations.capture_state_into(token, out) == &"", "actual location wire")
		check(arena.release(token) == &"", "test image lifetime is separate from production admission")
		return out

	func close() -> void:
		"""Release outer test references after every actual owner and arena was checked."""
		audit()
		check((bindings as RoomLocationBindings).arena.is_quiescent(), "actual room arena released")
		(bindings as RoomLocationBindings).endpoints = null
		locations = null
		adapter = null
		transforms = null


func test_room_confirmation_refreshes_existing_contacts_in_actual_callback_order() -> void:
	"""Actual Room publication preserves real retained Inventory endpoints while lower claims remain only plans."""
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	rooms.probe_arguments = true
	rooms.probe_receipt = true
	var container: Inventory.OpResult = fixture.inventory.create_spatial_ground_staging(fixture.refs[0])
	assert_true(container.ok, "actual goods endpoint retained before room confirmation")
	var result: Buildings.OpResult = fixture.orders.confirm_room(fixture.plan())
	assert_true(result.ok, "actual pending Room and companions: %s" % result.error)
	assert_true(rooms.before_seal_refused, "pre-seal callback cannot allocate future endpoint proof")
	assert_true(rooms.arguments_refused, "original token, source token, full Room and permanent purpose exact")
	assert_true(rooms.restricted_mutations, "refresh cannot create or retire endpoints")
	assert_true(rooms.outside_publish_refused and rooms.receipt_refused, "window and exact publication receipt required")
	assert_true(rooms.publication_ok, "matching same-stack publication succeeds")
	for ref: Vector2i in fixture.refs:
		assert_equal(fixture.locations.storage_endpoint_refusal(ref), &"", "current proof after marker revision")
		assert_equal(fixture.locations.location_revision(ref), 1, "immutable payload remains")
	assert_true(fixture.inventory.has_spatial_location(fixture.refs[0], 1), "real retained endpoint unchanged")
	assert_true(fixture.inventory.audit().ok, "actual retained container audit")
	fixture.close()


func test_room_companion_requires_every_existing_endpoint_refresh_before_identity() -> void:
	"""An omitted endpoint refuses the whole Room before Directory allocation; a complete retry succeeds."""
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	var before: PackedByteArray = fixture.image()
	var endpoints_before: PackedByteArray = fixture.location_image()
	rooms.skip_last = true
	var refused: Buildings.OpResult = fixture.orders.confirm_room(fixture.plan())
	assert_equal(refused.error, &"LOCATION_ROOM_REFRESH_REQUIRED", "all live contacts need current proofs")
	assert_true(fixture.image() == before, "no physical, material or identity mutation")
	assert_true(fixture.location_image() == endpoints_before, "no partial endpoint publication")
	rooms.skip_last = false
	assert_true(fixture.orders.confirm_room(fixture.plan()).ok, "same real owners retry complete refresh")
	assert_true(rooms.publication_ok, "actual retry published")
	fixture.close()


func test_room_companion_late_refusal_and_request_drift_preserve_live_state() -> void:
	"""Late proof failures discard sealed companions and retain the prior exact endpoint receipt."""
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	var before: PackedByteArray = fixture.image()
	var endpoints_before: PackedByteArray = fixture.location_image()
	var receipt: int = fixture.locations.last_published_token()
	rooms.fail_after_seal = true
	assert_false(fixture.orders.confirm_room(fixture.plan()).ok, "post-seal refusal")
	rooms.fail_after_seal = false
	rooms.mutate_request = true
	assert_false(fixture.orders.confirm_room(fixture.plan()).ok, "original request changed after Location seal")
	assert_true(fixture.image() == before, "all actual physical/economic state unchanged")
	assert_true(fixture.location_image() == endpoints_before, "both refused endpoint candidates invisible")
	assert_equal(fixture.locations.last_published_token(), receipt, "no receipt from refused confirmation")
	rooms.mutate_request = false
	assert_true(fixture.orders.confirm_room(fixture.plan()).ok, "exact retry after both refusals")
	fixture.close()


func test_room_companion_reentry_and_replaced_lease_cannot_publish() -> void:
	"""A pure identity callback cannot smuggle another transaction or replacement budget into this operation."""
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	var orders: ObservedRoomOrders = fixture.orders as ObservedRoomOrders
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	var before: PackedByteArray = fixture.image()
	var endpoints_before: PackedByteArray = fixture.location_image()
	rooms.reenter_after_seal = true
	assert_false(fixture.orders.confirm_room(fixture.plan()).ok, "callback reentry poisons preparation")
	assert_true(orders.nested_refused, "nested endpoint preparation refused")
	rooms.replace_after_seal = true
	assert_false(fixture.orders.confirm_room(fixture.plan()).ok, "replaced actual lease refuses")
	assert_true(rooms.arena.covers(orders.replacement, Budget.COLD_BYTES), "unrelated replacement remains held")
	assert_equal(rooms.arena.release(orders.replacement), &"", "external test owner releases replacement")
	assert_true(fixture.image() == before, "actual owners unchanged across callback refusals")
	assert_true(fixture.location_image() == endpoints_before, "neither callback copied usable endpoint state")
	assert_true(fixture.orders.confirm_room(fixture.plan()).ok, "clean exact request retries")
	fixture.close()


func test_room_companion_rechecks_complete_support_in_sealed_future() -> void:
	"""A room marker transaction cannot erase the real existing floor and refresh a contact by revision alone."""
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	var before: PackedByteArray = fixture.image()
	var endpoints_before: PackedByteArray = fixture.location_image()
	rooms.remove_support = fixture.ground_support
	assert_false(fixture.orders.confirm_room(fixture.plan()).ok, "complete future footing is still mandatory")
	assert_true(fixture.image() == before, "failed future support removal never publishes")
	assert_true(fixture.location_image() == endpoints_before, "old endpoint proof preserved")
	rooms.remove_support = NULL_REF
	assert_true(fixture.orders.confirm_room(fixture.plan()).ok, "unchanged complete footing permits retry")
	fixture.close()


func test_room_endpoint_binding_refuses_unbound_foreign_and_active_owners() -> void:
	"""Only the once-bound actual authority can later supply an exact Room confirmation scope."""
	assert_equal(_locations.bind_room_orders(null), &"LOCATION_ROOM_OWNER", "null authority")
	assert_equal(_locations.bind_room_orders(RoomOrders.new()), &"LOCATION_ROOM_OWNER", "unconfigured authority")
	var fixture: RoomLocationFixture = RoomLocationFixture.new(self)
	assert_equal(_locations.bind_room_orders(fixture.orders), &"LOCATION_ROOM_OWNER", "foreign actual Buildings authority")
	assert_equal(fixture.locations.bind_room_orders(fixture.orders), &"LOCATION_ROOM_OWNER", "one-time binding")
	var rooms: RoomLocationBindings = fixture.bindings as RoomLocationBindings
	var cold: int = rooms.arena.acquire(Budget.COLD_BYTES)
	assert_true(fixture.locations.begin_room_prepare(cold, 1, Vector2i(1, 1), Buildings.ROOM_TYPE_KITCHEN).error != &"", "no retained Room admission")
	assert_equal(rooms.arena.release(cold), &"", "failed attempt retains caller lease")
	fixture.close()
