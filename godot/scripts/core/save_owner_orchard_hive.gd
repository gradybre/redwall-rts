extends RefCounted
## Owner 10 (`orchard_hive`) framed-column validation and bulk capture/apply bridge (ADR 1222
## build step 2, mirroring `save_owner_priorities.gd`'s pair for the same ADR).
##
## THREE PUBLIC ENTRY POINTS.
##   * `framed_refusal()` judges one already framed section 4 owner block against
##     `OrchardHive.columns_refusal()` and returns a `SaveHeader.Refusal`. It builds no live
##     OrchardHive owner, calls no store, captures nothing and applies nothing.
##   * `capture_into(store, record)` copies the live store's 25 columns through
##     `OrchardHive.copy_columns_into()` and projects them into the record's u8/i32/i64 buckets in
##     ordinal order, then judges the written record with `framed_refusal()`, so a capture can
##     never emit an image apply would refuse.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `OrchardHive.restore_columns()`, which re-runs the same predicate, writes nothing on
##     refusal and rebuilds both active lists. A false maps to a Refusal carrying the store's
##     exact `last_column_refusal()` code.
## None of the three touches a clock, barrier, signal, callback, filesystem, JSON text,
## reflection API or per-row object; the caller owns barrier and restore-order discipline.
##
## OUT OF SCOPE, NAMED RATHER THAN SILENT. Owner 10's single §5 CHILD_ARENAS extent --
## `_link_hive_slot`/`_link_hive_generation`, ruling §3's 30720-row HivePollinationLinks table --
## is NOT one of the 25 columns this bridge projects. It round-trips through
## `OrchardHive.link_state_bytes()`/`restore_links_from_state()` and the two
## `revalidate_*_after_load()` calls, which a caller must run separately after `apply()`.
##
## GATE ORDER, and what each gate owns:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 10   -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata  -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `OrchardHive owner10 metadata:` so gate 4 is distinguishable from gate 3, which shares
##      the code. THE CODE ALONE DOES NOT IDENTIFY WHICH METADATA GATE FIRED.
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the 25 explicit `u8_column()`/`i32_column()`/`i64_column()` ordinals, in the predicate's
##      canonical argument order (the schema's owner-10 field order, fields 207..231)
##   7. `OrchardHive.columns_refusal()` -> the EXACT unwrapped column code, for example
##      COLUMN_ORCHARD_GROWTH, with a detail naming owner 10 and that same code.
## Success carries an empty code and an empty detail.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Cross-owner occupancy, directory liveness of any
## carried reference, the §5 link arena's agreement with the restored presence bytes, or
## permission to install anything into a live store. An all-zero frame is a valid EMPTY
## OrchardHive image.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const OrchardHive := preload("res://scripts/core/orchard_hive.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const ChildSchema := preload("res://scripts/core/save_child_arenas_schema.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 10
const OWNER_KEY: String = "orchard_hive"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 1024
const OWNER_CHILD_EXTENT_COUNT: int = 1
const OWNER_FIELD_COUNT: int = 25
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "OrchardHive owner10 metadata:"
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"

## Owner-local field ordinals, in the canonical order `OrchardHive.columns_refusal()` takes them.
const FIELD_O_PRESENT: int = 0
const FIELD_H_PRESENT: int = 1
const FIELD_O_SPECIES_ID: int = 2
const FIELD_O_AGE_DAYS: int = 3
const FIELD_O_HEALTH: int = 4
const FIELD_O_CHILL_DAYS: int = 5
const FIELD_O_TENDED_TODAY: int = 6
const FIELD_O_HARVESTED_YEAR: int = 7
const FIELD_O_ORIGIN_X: int = 8
const FIELD_O_ORIGIN_Z: int = 9
const FIELD_O_REF_SLOT: int = 10
const FIELD_O_REF_GENERATION: int = 11
const FIELD_H_BUILDING_SLOT: int = 12
const FIELD_H_BUILDING_GENERATION: int = 13
const FIELD_H_STRENGTH: int = 14
const FIELD_H_SERVICED_DAY: int = 15
const FIELD_H_FEED_MILLI: int = 16
const FIELD_H_HONEY_MILLI: int = 17
const FIELD_H_WAX_MILLI: int = 18
const FIELD_H_MIN_TILE_X: int = 19
const FIELD_H_MIN_TILE_Z: int = 20
const FIELD_H_MAX_TILE_X: int = 21
const FIELD_H_MAX_TILE_Z: int = 22
const FIELD_H_REF_SLOT: int = 23
const FIELD_H_REF_GENERATION: int = 24

## The pinned per-field contract: key, type and element count for all 25 fields, in ordinal order.
const FIELD_KEYS: Array[String] = ["_o_present", "_h_present", "_o_species_id", "_o_age_days",
	"_o_health", "_o_chill_days", "_o_tended_today", "_o_harvested_year", "_o_origin_x",
	"_o_origin_z", "_o_ref_slot", "_o_ref_generation", "_h_building_slot",
	"_h_building_generation", "_h_strength", "_h_serviced_day", "_h_feed_milli", "_h_honey_milli",
	"_h_wax_milli", "_h_min_tile_x", "_h_min_tile_z", "_h_max_tile_x", "_h_max_tile_z",
	"_h_ref_slot", "_h_ref_generation"]
const FIELD_U8: Array[int] = [FIELD_O_PRESENT, FIELD_H_PRESENT, FIELD_O_TENDED_TODAY,
	FIELD_O_HARVESTED_YEAR]
const FIELD_I64: Array[int] = [FIELD_H_FEED_MILLI, FIELD_H_HONEY_MILLI, FIELD_H_WAX_MILLI]
const ELEMENT_COUNT: int = 1024


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 10 block against OrchardHive's own column rules.

	Pure over its argument. See the header for the seven gates, and for everything an accepted
	result deliberately does not certify.
	"""
	var preflight: SaveHeader.Refusal = _frame_preflight(record)
	if not preflight.is_ok():
		return preflight
	var code: StringName = OrchardHive.columns_refusal(record.u8_column(FIELD_O_PRESENT),
		record.u8_column(FIELD_H_PRESENT), record.i32_column(FIELD_O_SPECIES_ID),
		record.i32_column(FIELD_O_AGE_DAYS), record.i32_column(FIELD_O_HEALTH),
		record.i32_column(FIELD_O_CHILL_DAYS), record.u8_column(FIELD_O_TENDED_TODAY),
		record.u8_column(FIELD_O_HARVESTED_YEAR), record.i32_column(FIELD_O_ORIGIN_X),
		record.i32_column(FIELD_O_ORIGIN_Z), record.i32_column(FIELD_O_REF_SLOT),
		record.i32_column(FIELD_O_REF_GENERATION), record.i32_column(FIELD_H_BUILDING_SLOT),
		record.i32_column(FIELD_H_BUILDING_GENERATION), record.i32_column(FIELD_H_STRENGTH),
		record.i32_column(FIELD_H_SERVICED_DAY), record.i64_column(FIELD_H_FEED_MILLI),
		record.i64_column(FIELD_H_HONEY_MILLI), record.i64_column(FIELD_H_WAX_MILLI),
		record.i32_column(FIELD_H_MIN_TILE_X), record.i32_column(FIELD_H_MIN_TILE_Z),
		record.i32_column(FIELD_H_MAX_TILE_X), record.i32_column(FIELD_H_MAX_TILE_Z),
		record.i32_column(FIELD_H_REF_SLOT), record.i32_column(FIELD_H_REF_GENERATION))
	if code != OrchardHive.REFUSE_NONE:
		return _refuse(code,
			"OrchardHive owner %d refuses this image with column code %s"
				% [OWNER_INDEX, String(code)])
	return _accept()


static func _frame_preflight(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Gates 1-5: a null record, the owner index, the schema, the metadata and the owner shape."""
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
	return Section.owner_shape_refusal(record)


static func capture_into(store: OrchardHive, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's 25 columns into one owner 10 record, then judge the result.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_columns_into()` (its column code is forwarded), then a typed setter refusal
	(SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: OrchardHive.Columns = OrchardHive.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(),
			"OrchardHive owner %d capture refused with %s"
				% [OWNER_INDEX, String(store.last_column_refusal())])
	if not _write_record(record, columns):
		return _refuse(Section.REFUSE_SHAPE,
			"OrchardHive owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: OrchardHive) -> SaveHeader.Refusal:
	"""Validate one owner 10 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no OrchardHive store was supplied for owner %d"
			% OWNER_INDEX)
	var columns: OrchardHive.Columns = OrchardHive.Columns.new()
	_read_record(record, columns)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(),
			"OrchardHive owner %d restore refused with %s"
				% [OWNER_INDEX, String(store.last_column_refusal())])
	return _accept()


static func _write_record(record: Section.FramedOwner, columns: OrchardHive.Columns) -> bool:
	"""Project all 25 captured columns into the record's typed buckets, in ordinal order."""
	return record.set_u8(FIELD_O_PRESENT, columns.o_present) \
		and record.set_u8(FIELD_H_PRESENT, columns.h_present) \
		and record.set_i32(FIELD_O_SPECIES_ID, columns.o_species_id) \
		and record.set_i32(FIELD_O_AGE_DAYS, columns.o_age_days) \
		and record.set_i32(FIELD_O_HEALTH, columns.o_health) \
		and record.set_i32(FIELD_O_CHILL_DAYS, columns.o_chill_days) \
		and record.set_u8(FIELD_O_TENDED_TODAY, columns.o_tended_today) \
		and record.set_u8(FIELD_O_HARVESTED_YEAR, columns.o_harvested_year) \
		and record.set_i32(FIELD_O_ORIGIN_X, columns.o_origin_x) \
		and record.set_i32(FIELD_O_ORIGIN_Z, columns.o_origin_z) \
		and record.set_i32(FIELD_O_REF_SLOT, columns.o_ref_slot) \
		and record.set_i32(FIELD_O_REF_GENERATION, columns.o_ref_generation) \
		and record.set_i32(FIELD_H_BUILDING_SLOT, columns.h_building_slot) \
		and record.set_i32(FIELD_H_BUILDING_GENERATION, columns.h_building_generation) \
		and record.set_i32(FIELD_H_STRENGTH, columns.h_strength) \
		and record.set_i32(FIELD_H_SERVICED_DAY, columns.h_serviced_day) \
		and record.set_i64(FIELD_H_FEED_MILLI, columns.h_feed_milli) \
		and record.set_i64(FIELD_H_HONEY_MILLI, columns.h_honey_milli) \
		and record.set_i64(FIELD_H_WAX_MILLI, columns.h_wax_milli) \
		and record.set_i32(FIELD_H_MIN_TILE_X, columns.h_min_tile_x) \
		and record.set_i32(FIELD_H_MIN_TILE_Z, columns.h_min_tile_z) \
		and record.set_i32(FIELD_H_MAX_TILE_X, columns.h_max_tile_x) \
		and record.set_i32(FIELD_H_MAX_TILE_Z, columns.h_max_tile_z) \
		and record.set_i32(FIELD_H_REF_SLOT, columns.h_ref_slot) \
		and record.set_i32(FIELD_H_REF_GENERATION, columns.h_ref_generation)


static func _read_record(record: Section.FramedOwner, columns: OrchardHive.Columns) -> void:
	"""Project the record's 25 typed buckets into one `Columns` object, in ordinal order."""
	columns.o_present = record.u8_column(FIELD_O_PRESENT)
	columns.h_present = record.u8_column(FIELD_H_PRESENT)
	columns.o_species_id = record.i32_column(FIELD_O_SPECIES_ID)
	columns.o_age_days = record.i32_column(FIELD_O_AGE_DAYS)
	columns.o_health = record.i32_column(FIELD_O_HEALTH)
	columns.o_chill_days = record.i32_column(FIELD_O_CHILL_DAYS)
	columns.o_tended_today = record.u8_column(FIELD_O_TENDED_TODAY)
	columns.o_harvested_year = record.u8_column(FIELD_O_HARVESTED_YEAR)
	columns.o_origin_x = record.i32_column(FIELD_O_ORIGIN_X)
	columns.o_origin_z = record.i32_column(FIELD_O_ORIGIN_Z)
	columns.o_ref_slot = record.i32_column(FIELD_O_REF_SLOT)
	columns.o_ref_generation = record.i32_column(FIELD_O_REF_GENERATION)
	columns.h_building_slot = record.i32_column(FIELD_H_BUILDING_SLOT)
	columns.h_building_generation = record.i32_column(FIELD_H_BUILDING_GENERATION)
	columns.h_strength = record.i32_column(FIELD_H_STRENGTH)
	columns.h_serviced_day = record.i32_column(FIELD_H_SERVICED_DAY)
	columns.h_feed_milli = record.i64_column(FIELD_H_FEED_MILLI)
	columns.h_honey_milli = record.i64_column(FIELD_H_HONEY_MILLI)
	columns.h_wax_milli = record.i64_column(FIELD_H_WAX_MILLI)
	columns.h_min_tile_x = record.i32_column(FIELD_H_MIN_TILE_X)
	columns.h_min_tile_z = record.i32_column(FIELD_H_MIN_TILE_Z)
	columns.h_max_tile_x = record.i32_column(FIELD_H_MAX_TILE_X)
	columns.h_max_tile_z = record.i32_column(FIELD_H_MAX_TILE_Z)
	columns.h_ref_slot = record.i32_column(FIELD_H_REF_SLOT)
	columns.h_ref_generation = record.i32_column(FIELD_H_REF_GENERATION)


static func _target_refusal(record: Section.FramedOwner, store: OrchardHive) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no OrchardHive store was supplied for owner %d"
			% OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: this owner's compiled identity, extents and the owner's own capacity constants."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA,
			"%s compiled owner '%s' version %d is not '%s' version %d"
				% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX),
					Schema.owner_version(OWNER_INDEX), OWNER_KEY, OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT \
			or Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d primaries and %d child extents are not %d and %d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), OWNER_PRIMARY_COUNT,
					OWNER_CHILD_EXTENT_COUNT])
	if Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT \
			or OrchardHive.ORCHARD_CAPACITY != OWNER_PRIMARY_COUNT \
			or OrchardHive.HIVE_CAPACITY != OWNER_PRIMARY_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the schema declares %d fields and OrchardHive declares %d/%d rows"
				% [METADATA_DETAIL_PREFIX, Schema.field_count(OWNER_INDEX),
					OrchardHive.ORCHARD_CAPACITY, OrchardHive.HIVE_CAPACITY])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: 25 explicit ordinals, each at its pinned key, type and count."""
	for field: int in OWNER_FIELD_COUNT:
		var refusal: SaveHeader.Refusal = _field_refusal(field)
		if not refusal.is_ok():
			return refusal
	return _accept()


static func _field_refusal(field: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its type code and its exact element count."""
	var key: String = FIELD_KEYS[field]
	if Schema.field_key(OWNER_INDEX, field) != key:
		return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; the contract fixes '%s'"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field), key])
	var expected_type: int = Schema.TYPE_I64 if FIELD_I64.has(field) \
		else (Schema.TYPE_U8 if FIELD_U8.has(field) else Schema.TYPE_I32)
	if Schema.field_type(OWNER_INDEX, field) != expected_type:
		return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
				expected_type])
	if Schema.element_count(OWNER_INDEX, field) != ELEMENT_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field),
				ELEMENT_COUNT])
	return _accept()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw OrchardHive column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


# --- ADR 1222 step 3: the section 5 link arena --------------------------------------------------


## The section 5 owner index of `orchard_hive` and its two link ordinals.
const CHILD_OWNER_INDEX: int = 4
const CHILD_LINK_HIVE_SLOT: int = 0
const CHILD_LINK_HIVE_GENERATION: int = 1
## The section 5 block is missing, another owner's, or misshaped.
const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_ORCHARD_HIVE_BLOCK_SHAPE"


static func _link_block_refusal(block: ChildSection.Block) -> SaveHeader.Refusal:
	"""The block is orchard_hive's section 5 block and well shaped."""
	if block == null or block.owner != CHILD_OWNER_INDEX \
			or ChildSchema.OWNER_KEYS[CHILD_OWNER_INDEX] != OWNER_KEY or block.shape_detail() != "":
		return _refuse(REFUSE_BLOCK_SHAPE,
			"a well-shaped section 5 'orchard_hive' block is required")
	return _accept()


static func capture_links_into(store: OrchardHive, block: ChildSection.Block) -> SaveHeader.Refusal:
	"""Write the 30720-row link arena into the section 5 block."""
	var target: SaveHeader.Refusal = _link_block_refusal(block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no OrchardHive store was supplied")
	var slot: PackedInt32Array = PackedInt32Array()
	var generation: PackedInt32Array = PackedInt32Array()
	slot.resize(OrchardHive.LINK_CAPACITY)
	generation.resize(OrchardHive.LINK_CAPACITY)
	if not store.copy_link_columns_into(slot, generation):
		return _refuse(store.last_column_refusal(), "OrchardHive link capture refused")
	var written: SaveHeader.Refusal = block.set_i32_column(CHILD_LINK_HIVE_SLOT, slot)
	if not written.is_ok():
		return written
	return block.set_i32_column(CHILD_LINK_HIVE_GENERATION, generation)


static func apply_links(block: ChildSection.Block, store: OrchardHive) -> SaveHeader.Refusal:
	"""Install the link arena (structure only); the caller re-proves it after hives restore."""
	var target: SaveHeader.Refusal = _link_block_refusal(block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no OrchardHive store was supplied")
	if not store.restore_link_columns(block.i32_column(CHILD_LINK_HIVE_SLOT),
			block.i32_column(CHILD_LINK_HIVE_GENERATION)):
		return _refuse(store.last_column_refusal(), "OrchardHive link restore refused with %s"
			% String(store.last_column_refusal()))
	return _accept()
