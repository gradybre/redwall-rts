extends RefCounted
## Owner 17 (`world_init`) framed-column validation bridge (FAUNA-S4-VALIDATE-R01 v1, ADR 0174;
## bulk capture/apply per ADR 1222 build step 2).
##
## THREE PUBLIC ENTRY POINTS.
##   * `framed_refusal()` judges one already framed section 4 owner 17 block against WorldInit's
##     reserved-fauna rules and returns a `SaveHeader.Refusal`. It NEVER constructs a WorldInit or
##     any collaborator -- that constructor allocates both map buffers and stages mask data, none
##     of which belongs in save validation -- captures nothing, applies nothing, and touches no
##     live store, catalog, clock, barrier, signal, callback, filesystem, reflection API,
##     diagnostic field, projection or repair path.
##   * `capture_into(store, record)` copies the live store's nine reserved fauna columns through
##     `WorldInit.copy_fauna_columns_into()` and projects them into the record's typed buckets in
##     ordinal order -- the exact inverse of the projection below -- then judges the written
##     record with `framed_refusal()`, so a capture can never emit an image apply would refuse. A
##     refused capture leaves the record's contents unspecified; the caller discards it.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `WorldInit.restore_fauna_columns()`, which re-runs the same predicate and writes nothing on
##     refusal. A false maps to a Refusal carrying the store's exact `last_fauna_column_refusal()`
##     code. Section 1's columns and scalars are untouched by either call.
##
## GATE ORDER for `framed_refusal()`, and what each gate owns:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 17   -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata  -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `WorldInit owner17 metadata:`, because gate 3 shares the code and keeps its own detail
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the nine explicit typed accessors, ordinals 0..7 i32 and ordinal 8 i64, in the
##      predicate's canonical argument order
##   7. `WorldInit.fauna_columns_refusal()` -> the EXACT unwrapped column code, COLUMN_FAUNA_SHAPE
##      or COLUMN_FAUNA_RESERVED, in a detail naming owner 17 and that same code, never a row.
## `capture_into()` and `apply()` additionally gate on a null store -> REFUSE_NULL_STORE, ahead of
## the schema and metadata guards for `capture_into()` and after `framed_refusal()` for `apply()`.
## Success carries an empty code and an empty detail.
##
## THE RESERVED IMAGE IS NOT ALL ZERO. REQ-SET-059 pins every zone reference at (-1,0), so a raw
## zero frame is REFUSED rather than normalised; a correctly filled empty image is the only
## locally admissible one. The metadata gate pins WorldInit's own row and column constants AND
## both EntityDirectory null sentinels BEFORE any column is evaluated, so an altered sentinel is
## reported as a metadata fault and can never be mistaken for a column-data defect.
##
## NO PROJECTION IS ALLOCATED BY `framed_refusal()`. Its nine accessor values are passed straight
## into the static predicate and share the caller's frozen copy-on-write buffers; nothing is
## duplicated, sorted, substituted or retained, so an accepted and a refused call alike leave
## every caller array untouched. The caller must hold its record frozen for this synchronous
## read. `capture_into()` and `apply()` each allocate one `WorldInit.FaunaColumns`, which
## `restore_fauna_columns()` takes its own private copies of. One framed image is
## 384 * (8 * 4 + 8) = 15360 logical packed value bytes, already inside the caller's streamed
## owner allowance; native and wrapper overhead is unmeasured.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Section 1 world publication, combined section 1/4
## restoration, owner publication, full-file provenance, or permission to install anything into a
## live store. The metadata guard is NOT an owner-publication-table comparison: the independent
## schema generator and the source-capacity audit still prove the registry against the actual
## owner declarations.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const WorldInit := preload("res://scripts/core/world_init.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 17
const OWNER_KEY: String = "world_init"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 384
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 9
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "WorldInit owner17 metadata:"
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_ZONE_SLOT: int = 0
const FIELD_ZONE_GENERATION: int = 1
const FIELD_SPECIES_ID: int = 2
const FIELD_POPULATION: int = 3
const FIELD_CAPACITY: int = 4
const FIELD_TRACKS: int = 5
const FIELD_HARVEST_TODAY: int = 6
const FIELD_MIGRATION_LINK: int = 7
const FIELD_BIRTH_REMAINDER: int = 8

## The pinned per-field contract: exact owner-local key, type code and element count.
const FIELD_ZONE_SLOT_KEY: String = "_fauna_zone_slot"
const FIELD_ZONE_GENERATION_KEY: String = "_fauna_zone_generation"
const FIELD_SPECIES_ID_KEY: String = "_fauna_species_id"
const FIELD_POPULATION_KEY: String = "_fauna_population"
const FIELD_CAPACITY_KEY: String = "_fauna_capacity"
const FIELD_TRACKS_KEY: String = "_fauna_tracks"
const FIELD_HARVEST_TODAY_KEY: String = "_fauna_harvest_today"
const FIELD_MIGRATION_LINK_KEY: String = "_fauna_migration_link"
const FIELD_BIRTH_REMAINDER_KEY: String = "_fauna_birth_remainder"
const ROW_ELEMENT_COUNT: int = 384
## The owner's own source constants this bridge cross-checks, per the contract.
const OWNER_I32_COLUMNS: int = 8
const OWNER_I64_COLUMNS: int = 1
const OWNER_NULL_SLOT: int = -1
const OWNER_NULL_GENERATION: int = 0


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 17 block against WorldInit's reserved-fauna column rules.

	Pure over its argument. See the header for the seven gates, and for everything an accepted
	result deliberately does not certify.
	"""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	var metadata: SaveHeader.Refusal = _metadata_refusal()
	if not metadata.is_ok():
		return metadata
	var shape: SaveHeader.Refusal = Section.owner_shape_refusal(record)
	if not shape.is_ok():
		return shape
	var code: StringName = WorldInit.fauna_columns_refusal(
		record.i32_column(FIELD_ZONE_SLOT), record.i32_column(FIELD_ZONE_GENERATION),
		record.i32_column(FIELD_SPECIES_ID), record.i32_column(FIELD_POPULATION),
		record.i32_column(FIELD_CAPACITY), record.i32_column(FIELD_TRACKS),
		record.i32_column(FIELD_HARVEST_TODAY), record.i32_column(FIELD_MIGRATION_LINK),
		record.i64_column(FIELD_BIRTH_REMAINDER))
	if code != WorldInit.REFUSE_NONE:
		return _refuse(code, "WorldInit owner %d refuses this image with column code %s"
			% [OWNER_INDEX, String(code)])
	return _accept()


static func capture_into(store: WorldInit, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's nine fauna columns into one owner 17 record, then judge it.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_fauna_columns_into()` (its column code is forwarded), a typed setter
	refusal (SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: WorldInit.FaunaColumns = WorldInit.FaunaColumns.new()
	if not store.copy_fauna_columns_into(columns):
		return _refuse(store.last_fauna_column_refusal(),
			"WorldInit owner %d capture refused with %s"
				% [OWNER_INDEX, String(store.last_fauna_column_refusal())])
	if not (record.set_i32(FIELD_ZONE_SLOT, columns.zone_slot)
			and record.set_i32(FIELD_ZONE_GENERATION, columns.zone_generation)
			and record.set_i32(FIELD_SPECIES_ID, columns.species_id)
			and record.set_i32(FIELD_POPULATION, columns.population)
			and record.set_i32(FIELD_CAPACITY, columns.capacity)
			and record.set_i32(FIELD_TRACKS, columns.tracks)
			and record.set_i32(FIELD_HARVEST_TODAY, columns.harvest_today)
			and record.set_i32(FIELD_MIGRATION_LINK, columns.migration_link)
			and record.set_i64(FIELD_BIRTH_REMAINDER, columns.birth_remainder)):
		return _refuse(Section.REFUSE_SHAPE,
			"WorldInit owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: WorldInit) -> SaveHeader.Refusal:
	"""Validate one owner 17 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_fauna_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no WorldInit store was supplied for owner %d"
			% OWNER_INDEX)
	var columns: WorldInit.FaunaColumns = WorldInit.FaunaColumns.new()
	columns.zone_slot = record.i32_column(FIELD_ZONE_SLOT)
	columns.zone_generation = record.i32_column(FIELD_ZONE_GENERATION)
	columns.species_id = record.i32_column(FIELD_SPECIES_ID)
	columns.population = record.i32_column(FIELD_POPULATION)
	columns.capacity = record.i32_column(FIELD_CAPACITY)
	columns.tracks = record.i32_column(FIELD_TRACKS)
	columns.harvest_today = record.i32_column(FIELD_HARVEST_TODAY)
	columns.migration_link = record.i32_column(FIELD_MIGRATION_LINK)
	columns.birth_remainder = record.i64_column(FIELD_BIRTH_REMAINDER)
	if not store.restore_fauna_columns(columns):
		return _refuse(store.last_fauna_column_refusal(),
			"WorldInit owner %d restore refused with %s"
				% [OWNER_INDEX, String(store.last_fauna_column_refusal())])
	return _accept()


static func _target_refusal(record: Section.FramedOwner, store: WorldInit) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no WorldInit store was supplied for owner %d"
			% OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled identity and extents, then the owner's own pinned source constants.

	The two null sentinels are pinned HERE, ahead of every column read, so a changed source
	sentinel is a metadata fault rather than an apparently noncanonical reserved row.
	"""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA,
			"%s compiled owner '%s' version %d is not '%s' version %d"
				% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX),
					Schema.owner_version(OWNER_INDEX), OWNER_KEY, OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT \
			or Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT \
			or Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d primaries, %d child extents and %d fields are not %d, %d and %d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), Schema.field_count(OWNER_INDEX),
					OWNER_PRIMARY_COUNT, OWNER_CHILD_EXTENT_COUNT, OWNER_FIELD_COUNT])
	if WorldInit.FAUNA_STOCK_ROWS != OWNER_PRIMARY_COUNT \
			or WorldInit.FAUNA_I32_COLUMNS != OWNER_I32_COLUMNS \
			or WorldInit.FAUNA_I64_COLUMNS != OWNER_I64_COLUMNS \
			or OWNER_I32_COLUMNS + OWNER_I64_COLUMNS != OWNER_FIELD_COUNT \
			or WorldInit.EntityDirectory.NULL_SLOT != OWNER_NULL_SLOT \
			or WorldInit.EntityDirectory.NULL_GENERATION != OWNER_NULL_GENERATION:
		return _refuse(Section.REFUSE_METADATA,
			"%s WorldInit declares %d rows of %d i32 and %d i64 columns with null reference (%d,%d)"
				% [METADATA_DETAIL_PREFIX, WorldInit.FAUNA_STOCK_ROWS, WorldInit.FAUNA_I32_COLUMNS,
					WorldInit.FAUNA_I64_COLUMNS, WorldInit.EntityDirectory.NULL_SLOT,
					WorldInit.EntityDirectory.NULL_GENERATION])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: nine explicit ordinals, eight i32 then one i64, all 384 long."""
	var slot: SaveHeader.Refusal = _field_refusal(FIELD_ZONE_SLOT, FIELD_ZONE_SLOT_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not slot.is_ok():
		return slot
	var generation: SaveHeader.Refusal = _field_refusal(FIELD_ZONE_GENERATION,
		FIELD_ZONE_GENERATION_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not generation.is_ok():
		return generation
	var species: SaveHeader.Refusal = _field_refusal(FIELD_SPECIES_ID, FIELD_SPECIES_ID_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not species.is_ok():
		return species
	var population: SaveHeader.Refusal = _field_refusal(FIELD_POPULATION, FIELD_POPULATION_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not population.is_ok():
		return population
	var capacity: SaveHeader.Refusal = _field_refusal(FIELD_CAPACITY, FIELD_CAPACITY_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not capacity.is_ok():
		return capacity
	var tracks: SaveHeader.Refusal = _field_refusal(FIELD_TRACKS, FIELD_TRACKS_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not tracks.is_ok():
		return tracks
	var harvest: SaveHeader.Refusal = _field_refusal(FIELD_HARVEST_TODAY,
		FIELD_HARVEST_TODAY_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not harvest.is_ok():
		return harvest
	var migration: SaveHeader.Refusal = _field_refusal(FIELD_MIGRATION_LINK,
		FIELD_MIGRATION_LINK_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not migration.is_ok():
		return migration
	return _field_refusal(FIELD_BIRTH_REMAINDER, FIELD_BIRTH_REMAINDER_KEY, Schema.TYPE_I64,
		ROW_ELEMENT_COUNT)


static func _field_refusal(field: int, key: String, type_code: int,
		count: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its declared type code and its exact extent."""
	if Schema.field_key(OWNER_INDEX, field) != key:
		return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; the contract fixes '%s'"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field), key])
	if Schema.field_type(OWNER_INDEX, field) != type_code:
		return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field), type_code])
	if Schema.element_count(OWNER_INDEX, field) != count:
		return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field), count])
	return _accept()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw WorldInit column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
