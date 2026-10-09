extends RefCounted
## Capture of one live settlement into the fifteen section bodies (ADR 1222 build step 8).
##
## `capture_body(world, out)` reads every owner through its own validated capture entry point and
## encodes each section with its own codec, filling a `SaveFile.Body`: bytes, the descriptor's
## schema version and row count, and the header's redundant scalars. A refusal leaves `out`
## unchanged and names the first owner that refused; there is no partial body.
##
## SECTION 15 is computed LAST, by `settlement_save_digest.gd`, from the staged records of the
## other fourteen, so the digest covers exactly what the file carries.
##
## DESCRIPTOR FACTS THE RULINGS LEAVE OPEN (recorded in ADR 1222's build notes): section 3 and
## section 10 are written at schema 1; section 7's row count is the sum of its six owners' primary
## counts; section 10's is its nine streams; section 14's is its 512 name rows; section 15's is 1.
##
## QUIESCENCE. The caller captures only at a completed tick boundary (`GameManager` not inside a
## tick); every owner capture also checks its own boundary and refuses otherwise.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveIdentity := preload("res://scripts/core/save_identity_hashes.gd")
const WorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const S01 := preload("res://scripts/core/save_section_01.gd")
const CatalogIds := preload("res://scripts/core/catalog_ids.gd")
const S03 := preload("res://scripts/core/save_section_directory.gd")
const S04 := preload("res://scripts/core/save_section_component_columns.gd")
const S04Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const S05 := preload("res://scripts/core/save_section_child_arenas.gd")
const S06 := preload("res://scripts/core/save_section_auxiliary.gd")
const S06Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const S07 := preload("res://scripts/core/save_section_inventories.gd")
const S08 := preload("res://scripts/core/save_section_job_indexes.gd")
const S09 := preload("res://scripts/core/save_section_navigation.gd")
const S10 := preload("res://scripts/core/save_section_rng.gd")
const S11 := preload("res://scripts/core/save_section_event_schedule.gd")
const S12 := preload("res://scripts/core/save_section_pending_commands.gd")
const S13 := preload("res://scripts/core/save_section_chronicle.gd")
const S14 := preload("res://scripts/core/save_section_name_pool.gd")
const SaveAux := preload("res://scripts/core/save_aux_adapters.gd")
const OwnerRecords := preload("res://scripts/core/settlement_save_owners.gd")
const SaveGearRestore := preload("res://scripts/core/save_gear_restore.gd")
const SaveReservationsRestore := preload("res://scripts/core/save_reservations_restore.gd")
const SaveStockAgeRestore := preload("res://scripts/core/save_stock_age_restore.gd")
const SaveClaimsRestore := preload("res://scripts/core/save_resource_claims_restore.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SECTION_3_SCHEMA_VERSION: int = 1
const SECTION_10_SCHEMA_VERSION: int = 1
const SECTION_15_SCHEMA_VERSION: int = 1
const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_CAPTURE: StringName = &"SAVE_CAPTURE_REFUSED"


class Staged:
	"""The decoded-form records the capture builds, kept for section 15's adapters."""
	var s01: S01.State = S01.State.new()
	var s03: S03.Record = S03.Record.new()
	var s04: Array[S04.FramedOwner] = []
	var s05: S05.State = S05.State.new()
	var s06: S06.State = S06.State.new()
	var s07: S07.Record = S07.Record.new()
	var s08: S08.Record = S08.Record.new()
	var s09: S09.Record = S09.Record.new()
	var s10: S10.Record = S10.Record.new()
	var s11: S11.Record = S11.Record.new()
	var s12: S12.Record = S12.Record.new()
	var s13: S13.Record = S13.Record.new()
	var s14: S14.Record = S14.Record.new()


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func _wrap(section: int, refusal: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""Prefix a refusal's detail with the section it came from; keep its exact code."""
	if refusal.is_ok():
		return refusal
	return _no(refusal.code, "section %d: %s" % [section, refusal.detail])


static func capture_body(world: SaveWorld.World, staged: Staged,
		out: SaveFile.Body) -> SaveHeader.Refusal:
	"""Capture sections 1-14 into `out` and `staged` in dependency order (15 is separate)."""
	var body: SaveFile.Body = SaveFile.Body.new()
	var steps: Array[Callable] = [_capture_01, _capture_02, _capture_03, _capture_04_05_06,
		_capture_07, _capture_08, _capture_09, _capture_10, _capture_11, _capture_12,
		_capture_13, _capture_14]
	for step: Callable in steps:
		var refusal: SaveHeader.Refusal = step.call(world, staged, body)
		if not refusal.is_ok():
			return refusal
	body.completed_tick = staged.s01.runtime.completed_tick
	_adopt(body, out)
	return _ok()


static func _adopt(body: SaveFile.Body, out: SaveFile.Body) -> void:
	"""Publish a fully captured body."""
	out.sections = body.sections
	out.schema_versions = body.schema_versions
	out.row_counts = body.row_counts
	out.completed_tick = body.completed_tick
	out.chronicle_record_count = body.chronicle_record_count
	out.economic_next_high = body.economic_next_high
	out.economic_next_low = body.economic_next_low


# --- section 1 and 2 ------------------------------------------------------------------------------

static func stores_01(world: SaveWorld.World) -> S01.Stores:
	"""Section 1's eight stores (the spatial map is the absent owner) and the optional Space."""
	var stores: S01.Stores = S01.Stores.new()
	stores.directory = world.directory
	stores.buildings = world.buildings
	stores.farming = world.farming
	stores.forage = world.forage
	stores.resource_nodes = world.resource_nodes
	stores.spatial_world = world.absent_spatial_world
	stores.weather = world.weather
	stores.world_init = world.world_init
	stores.space_owner = world.space_owner
	return stores


static func _capture_01(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""World runtime from the clock and RNG, provenance from the published world, then section 1."""
	var world_seed: IntMath.IntResult = world.rng.world_seed_value()
	if not world_seed.ok:
		return _no(REFUSE_CAPTURE, "section 1: the RNG holds no world seed")
	var runtime: WorldRuntime.Record = WorldRuntime.Record.new()
	var refusal: SaveHeader.Refusal = WorldRuntime.capture_into(world.clock(), world_seed.value,
		world.rng.is_seeded(), runtime)
	if not refusal.is_ok():
		return _wrap(1, refusal)
	var provenance: SaveIdentity.ProvenanceResult = SaveIdentity.provenance_of(world.world_init,
		world.rng)
	if not provenance.ok:
		return _no(provenance.error, "section 1: " + provenance.detail)
	refusal = S01.capture_into(stores_01(world), runtime, provenance.provenance.scenario_version,
		provenance.provenance.map_generator_schema, provenance.provenance.authored_map_digest,
		staged.s01)
	if not refusal.is_ok():
		return _wrap(1, refusal)
	var encoded: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	if not S01.encode_section(staged.s01, encoded):
		return _no(encoded.refusal, "section 1: " + encoded.detail)
	body.set_section(1, encoded.bytes, S01.SECTION_SCHEMA_VERSION,
		S01.DESCRIPTOR_ROW_COUNTS[staged.s01.space_layout])
	return _ok()


static func _capture_02(_world: SaveWorld.World, _staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The compiled catalog's canonical artifact (verified on load, never applied)."""
	var built: CatalogIds.BuildResult = CatalogIds.build()
	if not built.ok:
		return _no(REFUSE_CAPTURE, "section 2: " + built.detail)
	body.set_section(CatalogIds.SAVE_SECTION_ID, CatalogIds.save_section_payload(built.artifact),
		CatalogIds.SAVE_SECTION_SCHEMA_VERSION, built.artifact.row_count)
	return _ok()


static func _capture_03(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The entity directory's six columns."""
	var refusal: SaveHeader.Refusal = S03.capture_into(world.directory, staged.s03)
	if not refusal.is_ok():
		return _wrap(3, refusal)
	var encoded: S03.EncodeResult = S03.EncodeResult.new()
	if not S03.encode_record(staged.s03, encoded):
		return _no(encoded.refusal, "section 3: " + encoded.detail)
	body.set_section(3, encoded.bytes, SECTION_3_SCHEMA_VERSION, S03.descriptor_row_count())
	return _ok()


# --- sections 4, 5 and 6 together -----------------------------------------------------------------

static func _capture_04_05_06(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""Every section 4 owner (filling the joint section 5/6 blocks), then section 5 and 6."""
	var refusal: SaveHeader.Refusal = OwnerRecords.capture_all(world, staged.s04, staged.s05,
		staged.s06)
	if not refusal.is_ok():
		return _wrap(4, refusal)
	var section4: PackedByteArray = PackedByteArray()
	refusal = _encode_04(staged.s04, section4)
	if not refusal.is_ok():
		return _wrap(4, refusal)
	body.set_section(4, section4, S04Schema.SECTION_SCHEMA_VERSION, S04Schema.DESCRIPTOR_ROW_COUNT)
	refusal = OwnerRecords.capture_aux(world, staged.s06)
	if not refusal.is_ok():
		return _wrap(6, refusal)
	var encoded5: S05.EncodeResult = S05.EncodeResult.new()
	if not S05.encode_section(staged.s05, encoded5):
		return _no(encoded5.refusal, "section 5: " + encoded5.detail)
	body.set_section(5, encoded5.bytes, S05.Schema.SECTION_SCHEMA_VERSION, S05.OWNER_COUNT)
	var encoded6: S06.EncodeResult = S06.EncodeResult.new()
	if not S06.encode_section(staged.s06, encoded6):
		return _no(encoded6.refusal, "section 6: " + encoded6.detail)
	body.set_section(6, encoded6.bytes, S06Schema.SECTION_SCHEMA_VERSION, S06.OWNER_COUNT)
	return _ok()


static func _encode_04(records: Array[S04.FramedOwner], out: PackedByteArray) -> SaveHeader.Refusal:
	"""Stream the eighteen already captured records through section 4's encode cursor."""
	var cursor: S04.EncodeCursor = S04.EncodeCursor.new(S04Schema.SECTION_SCHEMA_VERSION,
		S04Schema.DESCRIPTOR_ROW_COUNT)
	var chunk: S04.WireChunk = S04.WireChunk.new()
	while cursor.has_more():
		if cursor.needs_owner():
			var bound: SaveHeader.Refusal = cursor.bind_owner(records[cursor.owner_index()])
			if not bound.is_ok():
				return bound
		if not cursor.next_chunk_into(chunk):
			return cursor.refusal()
		out.append_array(chunk.bytes)
	return cursor.finish()


# --- sections 7 to 14 -----------------------------------------------------------------------------

static func _capture_07(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The six inventory and lease owners, sized from the live tables."""
	var record: S07.Record = S07.Record.new()
	var capacities: Vector2i = world.inventory.canonical_capacities()
	record.owners[S07.OWNER_GEAR] = S07.OwnerRecord.new(S07.OWNER_GEAR,
		world.gear.row_capacity(), PackedInt64Array())
	record.owners[S07.OWNER_RESERVATIONS] = S07.OwnerRecord.new(S07.OWNER_RESERVATIONS,
		world.reservations.row_capacity(), PackedInt64Array())
	record.owners[S07.OWNER_INVENTORY] = S07.OwnerRecord.new(S07.OWNER_INVENTORY, capacities.x,
		PackedInt64Array([capacities.y]))
	S07.fill_empty(record)
	var refusal: SaveHeader.Refusal = _capture_07_owners(world, record)
	if not refusal.is_ok():
		return _wrap(7, refusal)
	var encoded: S07.EncodeResult = S07.EncodeResult.new()
	if not S07.encode_record(record, encoded):
		return _no(encoded.refusal, "section 7: " + encoded.detail)
	staged.s07 = record
	body.set_section(7, encoded.bytes, S07.SECTION_SCHEMA_VERSION, section_7_rows(record))
	return _ok()


static func section_7_rows(record: S07.Record) -> int:
	"""Section 7's descriptor row count: the sum of its six owners' primary counts."""
	var rows: int = 0
	for owner: int in S07.OWNER_COUNT:
		rows += record.of(owner).primary_count
	return rows


static func _capture_07_owners(world: SaveWorld.World, record: S07.Record) -> SaveHeader.Refusal:
	"""Inventory first, then gear, reservations, stock age and both claim tables."""
	var refusals: Array[Callable] = [
		func() -> SaveHeader.Refusal: return S07.capture_inventory_into(record, world.inventory,
			S07.inventory_columns_for(record)),
		func() -> SaveHeader.Refusal: return SaveGearRestore.capture_into(world.gear,
			record.of(S07.OWNER_GEAR), world.item_definitions, world.inventory),
		func() -> SaveHeader.Refusal: return SaveReservationsRestore.capture_into(
			world.reservations, record.of(S07.OWNER_RESERVATIONS), world.inventory),
		func() -> SaveHeader.Refusal: return SaveStockAgeRestore.capture_into(world.stock_age,
			record.of(S07.OWNER_STOCK_AGE)),
		func() -> SaveHeader.Refusal: return SaveClaimsRestore.capture_fishing_into(world.fishing,
			record.of(S07.OWNER_FISHING)),
		func() -> SaveHeader.Refusal: return SaveClaimsRestore.capture_forage_into(world.forage,
			record.of(S07.OWNER_FORAGE))]
	for step: Callable in refusals:
		var refusal: SaveHeader.Refusal = step.call()
		if not refusal.is_ok():
			return refusal
	return _ok()


static func _capture_08(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The job planner's service indexes."""
	var refusal: SaveHeader.Refusal = S08.capture_into(world.planner, staged.s08)
	if not refusal.is_ok():
		return _wrap(8, refusal)
	var encoded: S08.EncodeResult = S08.EncodeResult.new()
	if not S08.encode_section(staged.s08, encoded):
		return _no(encoded.refusal, "section 8: " + encoded.detail)
	body.set_section(8, encoded.bytes, S08.SECTION_SCHEMA_VERSION, S08.descriptor_row_count())
	return _ok()


static func _capture_09(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""Movement's nine cursor columns over the empty navigator production composes none of."""
	var cursors: PackedInt32Array = PackedInt32Array()
	cursors.resize(world.movement.CURSOR_COLUMN_COUNT * world.movement.MOTION_CAPACITY)
	if not world.movement.copy_cursor_columns_into(cursors):
		return _no(world.movement.last_column_refusal(), "section 9: movement cursors")
	var refusal: SaveHeader.Refusal = S09.set_movement_columns(staged.s09, cursors)
	if not refusal.is_ok():
		return _wrap(9, refusal)
	var encoded: S09.EncodeResult = S09.EncodeResult.new()
	if not S09.encode_record(staged.s09, encoded):
		return _no(encoded.refusal, "section 9: " + encoded.detail)
	body.set_section(9, encoded.bytes, S09.SECTION_SCHEMA_VERSION, S09.descriptor_row_count())
	return _ok()


static func _capture_10(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The nine RNG streams."""
	var refusal: SaveHeader.Refusal = S10.capture_into(world.rng, staged.s10)
	if not refusal.is_ok():
		return _wrap(10, refusal)
	var encoded: S10.EncodeResult = S10.EncodeResult.new()
	if not S10.encode_record(staged.s10, encoded):
		return _no(encoded.refusal, "section 10: " + encoded.detail)
	body.set_section(10, encoded.bytes, SECTION_10_SCHEMA_VERSION, S10.STREAM_COUNT)
	return _ok()


static func _capture_11(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The event schedule (the absent owner: always the empty schedule today)."""
	var refusal: SaveHeader.Refusal = S11.capture_into(world.absent_event_schedule, staged.s11)
	if not refusal.is_ok():
		return _wrap(11, refusal)
	var rows: IntMath.IntResult = IntMath.IntResult.new()
	if not S11.descriptor_row_count_into(staged.s11, rows):
		return _no(REFUSE_CAPTURE, "section 11: no row count")
	var encoded: S11.EncodeResult = S11.EncodeResult.new()
	if not S11.encode_section(staged.s11, encoded):
		return _no(encoded.refusal, "section 11: " + encoded.detail)
	body.set_section(11, encoded.bytes, S11.SECTION_SCHEMA_VERSION, rows.value)
	return _ok()


static func _capture_12(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""Both pending queues, and the economic allocator the header redeclares."""
	var refusal: SaveHeader.Refusal = S12.capture_into(world.commands, world.scheduler_events(),
		staged.s12)
	if not refusal.is_ok():
		return _wrap(12, refusal)
	var encoded: S12.EncodeResult = S12.EncodeResult.new()
	if not S12.encode_record(staged.s12, encoded):
		return _no(encoded.refusal, "section 12: " + encoded.detail)
	body.set_section(12, encoded.bytes, S12.SECTION_SCHEMA_VERSION,
		S12.descriptor_row_count(staged.s12))
	body.economic_next_high = staged.s12.economic_next_sequence_high
	body.economic_next_low = staged.s12.economic_next_sequence_low
	return _ok()


static func _capture_13(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The Chronicle's count and rolling digest (the absent owner: empty today)."""
	var refusal: SaveHeader.Refusal = S13.capture_into(world.absent_chronicle, staged.s13)
	if not refusal.is_ok():
		return _wrap(13, refusal)
	var encoded: S13.EncodeResult = S13.EncodeResult.new()
	if not S13.encode_section(staged.s13, PackedByteArray(), encoded):
		return _no(encoded.refusal, "section 13: " + encoded.detail)
	body.set_section(13, encoded.bytes, S13.SECTION_SCHEMA_VERSION, staged.s13.record_count)
	body.chronicle_record_count = staged.s13.record_count
	return _ok()


static func _capture_14(world: SaveWorld.World, staged: Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""The resident name pool."""
	var refusal: SaveHeader.Refusal = S14.capture_into(world.residents, staged.s14)
	if not refusal.is_ok():
		return _wrap(14, refusal)
	var encoded: S14.EncodeResult = S14.EncodeResult.new()
	if not S14.encode_record(staged.s14, encoded):
		return _no(encoded.refusal, "section 14: " + encoded.detail)
	body.set_section(14, encoded.bytes, S14.SCHEMA_VERSION, S14.PRIMARY_COUNT)
	return _ok()
