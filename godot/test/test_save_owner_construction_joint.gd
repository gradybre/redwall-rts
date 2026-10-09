extends "res://test/framework/test_case.gd"
## Construction's joint capture/apply pair (ADR 1222 step 3, DEC-055 Q7(a)).
##
## A store holding a partly delivered build, an open demolition and a furniture REMOVAL -- a
## purpose outside ADR 0186's frozen enum, so it travels in the `construction_extension` owner --
## is captured into the section 4 record, the section 5 delivered ledger and the two section 6
## blocks, the ledger is carried through the real section 5 codec, and everything is applied into
## a DIFFERENT store over a separately restored Directory and Building store.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_construction.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const AuxSection := preload("res://scripts/core/save_section_auxiliary.gd")
const AuxSchema := preload("res://scripts/core/save_auxiliary_state_schema.gd")

const HALL_TILE: int = 59 * 128 + 58
const WELL_TILE: int = 40 * 128 + 40
const STOCKPILE_TILE: int = 60 * 128 + 50
const START_MASK: int = 1

var _buildings: Buildings = null
var _construction: Construction = null


func before_each() -> void:
	"""A partly delivered stockpile build, an open well demolition and an open bed removal."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	var stockpile: Vector2i = _place("open_stockpile", STOCKPILE_TILE, false)
	var build: Construction.OpResult = _construction.open_build(stockpile)
	assert_true(build.ok, "the stockpile project opens (%s)" % build.error)
	assert_true(_construction.deliver_material(build.ref, 0, 1000).ok, "part of the wood")
	assert_true(_construction.open_demolition(_place("well", WELL_TILE, true)).ok, "demolition")
	var hall: Vector2i = _place("hall", HALL_TILE, true)
	var tile: int = HALL_TILE + Buildings.MAP_TILES_X + 1
	var room: Buildings.OpResult = _buildings.designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([tile]))
	assert_true(room.ok, "a room (%s)" % room.error)
	var bed: Buildings.OpResult = _buildings.place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), tile, 0)
	assert_true(bed.ok, "a bed (%s)" % bed.error)
	var removal: Construction.OpResult = _construction.open_furniture_removal(bed.ref)
	assert_true(removal.ok, "the removal opens (%s)" % removal.error)


func _place(key: String, tile: int, active: bool) -> Vector2i:
	"""Place one building; ACTIVE when asked."""
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION[key]), tile, 0, START_MASK)
	assert_true(placed.ok, "%s places (%s)" % [key, placed.error])
	if active:
		assert_true(_buildings.set_building_state(placed.ref, Construction.STATE_ACTIVE).ok, "on")
	return placed.ref


func _target() -> Construction:
	"""A different Construction over a Directory and Building store restored from the source."""
	var active: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()
	active.resize(EntityDirectory.DIRECTORY_CAPACITY)
	retired.resize(EntityDirectory.DIRECTORY_CAPACITY)
	generation.resize(EntityDirectory.DIRECTORY_CAPACITY)
	persistent_id.resize(EntityDirectory.DIRECTORY_CAPACITY)
	kind.resize(EntityDirectory.DIRECTORY_CAPACITY)
	typed_row.resize(EntityDirectory.DIRECTORY_CAPACITY)
	_buildings.directory().copy_columns_into(active, generation, retired, persistent_id, kind,
		typed_row)
	var directory: EntityDirectory = EntityDirectory.new()
	assert_true(directory.restore_columns(active, generation, retired, persistent_id, kind,
		typed_row), "section 3 restores")
	var buildings: Buildings = Buildings.new(directory)
	var columns: Buildings.Columns = Buildings.Columns.new()
	var links: Buildings.Links = Buildings.Links.new()
	assert_true(_buildings.copy_columns_into(columns, links), "buildings copy")
	assert_true(buildings.restore_columns(columns, links), "buildings restore %s"
		% buildings.last_column_refusal())
	return Construction.new(buildings)


func _captured() -> Array:
	"""[record, Blocks] captured from the source, the section 5 ledger re-decoded."""
	var record: Section.FramedOwner = Section.FramedOwner.new(Bridge.OWNER_INDEX)
	var child: ChildSection.State = ChildSection.State.new()
	var aux: AuxSection.State = AuxSection.State.new()
	var blocks: Bridge.Blocks = Bridge.Blocks.new(child.block(Bridge.CHILD_OWNER_INDEX),
		aux.block(AuxSchema.OWNER_KEYS.find(Bridge.EXTENSION_OWNER_KEY)),
		aux.block(AuxSchema.OWNER_KEYS.find(Bridge.PAID_OWNER_KEY)))
	var refusal: Variant = Bridge.capture_into(_construction, record, blocks)
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	var out: ChildSection.EncodeResult = ChildSection.EncodeResult.new()
	assert_true(ChildSection.encode_section(child, out), "section 5 encodes")
	var decoded: ChildSection.State = ChildSection.State.new()
	assert_true(ChildSection.decode_section(out.bytes, 0, out.bytes.size(), decoded).is_ok(),
		"section 5 decodes")
	blocks.delivered = decoded.block(Bridge.CHILD_OWNER_INDEX)
	return [record, blocks]


func test_capture_then_apply_into_a_different_store_is_byte_identical() -> void:
	"""Every row, both ledgers and the live count come back exactly."""
	var parts: Array = _captured()
	var target: Construction = _target()
	var refusal: Variant = Bridge.apply(parts[0], parts[1], target)
	assert_true(refusal.is_ok(), "apply: %s %s" % [refusal.code, refusal.detail])
	assert_true(target.state_bytes() == _construction.state_bytes(), "the stores agree")


func test_the_removal_travels_in_the_extension_and_the_frozen_image_stays_frozen() -> void:
	"""The section 4 record passes ADR 0186's frozen predicate; the extension holds purpose 4."""
	var parts: Array = _captured()
	assert_true(Bridge.framed_refusal(parts[0]).is_ok(), "the frozen record is accepted")
	var purposes: PackedInt32Array = parts[1].extension.i32_column(Bridge.FIELD_PURPOSE)
	assert_true(purposes.has(Construction.PURPOSE_REMOVE_FURNITURE), "the removal row")
	assert_equal(Construction.extension_refusal(_extension_of(parts[1])), Construction.REFUSE_NONE,
		"the extension predicate accepts it")


func _extension_of(blocks: Bridge.Blocks) -> Construction.Columns:
	"""Decode the extension block into a Columns image."""
	var out: Construction.Columns = Construction.Columns.new(false)
	Bridge._read_extension(blocks.extension, out)
	return out


func test_corruptions_refuse_with_their_codes_and_write_nothing() -> void:
	"""A row in both images, a delivery past a bill, and an unresolvable Directory each refuse."""
	var target: Construction = _target()
	var before: PackedByteArray = target.state_bytes()
	var parts: Array = _captured()
	var record_purpose: PackedInt32Array = parts[0].i32_column(Bridge.FIELD_PURPOSE)
	var row: int = parts[1].extension.i32_column(Bridge.FIELD_PURPOSE).find(
		Construction.PURPOSE_REMOVE_FURNITURE)
	record_purpose[row] = Construction.PURPOSE_DEMOLISH
	assert_false(Bridge.apply(parts[0], parts[1], target).is_ok(), "a row carried twice")
	parts = _captured()
	var delivered: PackedInt64Array = parts[1].delivered.i64_column(Bridge.CHILD_DELIVERED)
	delivered[delivered.size() - 1] = 5
	assert_true(parts[1].delivered.set_i64_column(Bridge.CHILD_DELIVERED, delivered).is_ok(), "x")
	assert_equal(Bridge.apply(parts[0], parts[1], target).code, Construction.REFUSE_COLUMN_LEDGER,
		"a delivery on a never-used row")
	parts = _captured()
	var empty: Construction = Construction.new(Buildings.new(EntityDirectory.new()))
	assert_equal(Bridge.apply(parts[0], parts[1], empty).code,
		Construction.REFUSE_COLUMN_DIRECTORY, "rows the Directory does not hold")
	assert_true(target.state_bytes() == before, "no refusal wrote anything")


# --- ADR 1235: the whole-column proofs must not hide a fault the row walks refuse -----------------

func test_a_delivery_on_a_never_used_middle_row_refuses_through_the_proof() -> void:
	"""The ledger proof lists the rows whose cells differ; a forged cell mid-ledger is one of them."""
	var target: Construction = _target()
	var parts: Array = _captured()
	var delivered: PackedInt64Array = parts[1].delivered.i64_column(Bridge.CHILD_DELIVERED)
	@warning_ignore("integer_division") var row: int = Construction.CONSTRUCTION_CAPACITY / 2
	delivered[row * Construction.MATERIAL_SLOTS_PER_PROJECT] = 5
	assert_true(parts[1].delivered.set_i64_column(Bridge.CHILD_DELIVERED, delivered).is_ok(), "x")
	assert_equal(Bridge.apply(parts[0], parts[1], target).code, Construction.REFUSE_COLUMN_LEDGER,
		"a delivery on a never-used middle row")


func test_a_non_flag_byte_on_a_live_construction_row_refuses() -> void:
	"""`paused = 2` on a present row passes every row gate; only the flag scan refuses it."""
	var parts: Array = _captured()
	var image: Construction.Columns = Construction.Columns.new(false)
	Bridge._project_columns(parts[0], image)
	var row: int = image.present.find(1)
	assert_true(row >= 0, "a present row")
	image.paused[row] = 2
	assert_equal(Construction.columns_refusal(image), Construction.REFUSE_COLUMN_FLAG, "refused")


func test_a_non_flag_byte_on_a_live_room_refuses() -> void:
	"""`r_valid = 2` on a present room passes every room gate; only the flag scan refuses it."""
	var image: Buildings.Columns = Buildings.Columns.new()
	var links: Buildings.Links = Buildings.Links.new()
	assert_true(_buildings.copy_columns_into(image, links), "copied")
	var row: int = image.r_present.find(1)
	assert_true(row >= 0, "a present room")
	assert_equal(Buildings.columns_refusal(image), Buildings.REFUSE_NONE, "the image is valid")
	image.r_valid[row] = 2
	assert_equal(Buildings.columns_refusal(image), Buildings.REFUSE_COLUMN_FLAG, "refused")
