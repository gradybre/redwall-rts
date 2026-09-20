extends RefCounted
## Owner 6 (`injury`) framed-column validation bridge (INJURY-S4-VALIDATE-R01 v1, ADR 0177).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the Injury store's own column rules and returns a `SaveHeader.Refusal`. It constructs
## no Injury, Needs, Directory or catalog store, consults no live owner, reads no clock, captures
## nothing, applies nothing, normalises nothing and writes no diagnostic.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 6    -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned Injury source constants ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `Injury owner6 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the eleven explicit canonical typed accessors: u8 at ordinals 0..4, i32 at 5..7 and
##      i64 at 8..10
##   7. `Injury.columns_refusal()`      -> the EXACT unwrapped column code, for example
##      COLUMN_FLAGS, in a detail naming owner 6 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## BRIDGES VALIDATE, THEY DO NOT RESTORE. An accepted result certifies owner 6 scalar-domain
## validation only. Saved Needs and resident presence, health and injury-state agreement,
## Directory patient and rescuer kind and identity -- without rejecting lawful stale generations
## -- self-rescue, the movement care context, same-file provenance, bulk capture/restore and
## derived counts all remain downstream INJURY-SAVED-BINDINGS obligations.
##
## THE METADATA GUARD compares the compiled schema to pinned contract literals and the Injury
## source constants to their pinned values, read as constant chains that instantiate no owner.
## That is not an owner-publication-table parity claim; the independent schema generator and the
## source-capacity audit still prove the registry. A source mismatch refuses BEFORE any typed
## column is read.
##
## SECTION 4's `injury` IS VERSION 1 WITH 512 ROWS, NO CHILDREN AND ELEVEN FIELDS. The version
## and extent pins below are what make a differently shaped `injury` block a refusal rather than
## a silent acceptance.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Injury := preload("res://scripts/core/injury.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 6
const OWNER_KEY: String = "injury"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 512
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 11
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Injury owner6 metadata:"
## Gate 7's detail prefix. It names the owner and the code, and never a row.
const COLUMN_DETAIL_PREFIX: String = "Injury owner 6"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_PRESENT: int = 0
const FIELD_KIND: int = 1
const FIELD_AIRLESS_EPISODE: int = 2
const FIELD_EXHAUSTION_LATCH: int = 3
const FIELD_CARE_CONTEXT_BLOCKED: int = 4
const FIELD_SEVERITY: int = 5
const FIELD_RESCUER_SLOT: int = 6
const FIELD_RESCUER_GENERATION: int = 7
const FIELD_UNTREATED_TICKS: int = 8
const FIELD_CARE_PROGRESS_MWU: int = 9
const FIELD_LAST_INCIDENT_ORDINAL: int = 10

## The pinned per-field contract: exact owner-local keys, and the one exact element count.
const FIELD_PRESENT_KEY: String = "_present"
const FIELD_KIND_KEY: String = "_kind"
const FIELD_AIRLESS_EPISODE_KEY: String = "_airless_episode"
const FIELD_EXHAUSTION_LATCH_KEY: String = "_exhaustion_latch"
const FIELD_CARE_CONTEXT_BLOCKED_KEY: String = "_care_context_blocked"
const FIELD_SEVERITY_KEY: String = "_severity"
const FIELD_RESCUER_SLOT_KEY: String = "_rescuer_slot"
const FIELD_RESCUER_GENERATION_KEY: String = "_rescuer_generation"
const FIELD_UNTREATED_TICKS_KEY: String = "_untreated_ticks"
const FIELD_CARE_PROGRESS_MWU_KEY: String = "_care_progress_mwu"
const FIELD_LAST_INCIDENT_ORDINAL_KEY: String = "_last_incident_ordinal"
const ROW_ELEMENT_COUNT: int = 512

## The Injury source constants this bridge pins as contract before it reads a column.
const SOURCE_ROW_CAPACITY: int = 512
const SOURCE_NEEDS_ROW_CAPACITY: int = 512
const SOURCE_KIND_NONE: int = 0
const SOURCE_KIND_CUT: int = 1
const SOURCE_KIND_BITE: int = 2
const SOURCE_KIND_FALL: int = 3
const SOURCE_KIND_EXPOSURE: int = 4
const SOURCE_KIND_EXHAUSTION: int = 5
const SOURCE_KIND_COUNT: int = 6
const SOURCE_SEVERITY_NONE: int = 0
const SOURCE_SEVERITY_MINOR: int = 1
const SOURCE_SEVERITY_SERIOUS: int = 2
const SOURCE_DIRECTORY_CAPACITY: int = 352418
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 6 block against the Injury store's own column rules.

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
	var code: StringName = Injury.columns_refusal(
		record.u8_column(FIELD_PRESENT), record.u8_column(FIELD_KIND),
		record.u8_column(FIELD_AIRLESS_EPISODE), record.u8_column(FIELD_EXHAUSTION_LATCH),
		record.u8_column(FIELD_CARE_CONTEXT_BLOCKED), record.i32_column(FIELD_SEVERITY),
		record.i32_column(FIELD_RESCUER_SLOT), record.i32_column(FIELD_RESCUER_GENERATION),
		record.i64_column(FIELD_UNTREATED_TICKS), record.i64_column(FIELD_CARE_PROGRESS_MWU),
		record.i64_column(FIELD_LAST_INCIDENT_ORDINAL))
	if code != Injury.REFUSE_NONE:
		return _refuse(code, "%s refuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned Injury source constants."""
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
	var source: SaveHeader.Refusal = _source_refusal()
	if not source.is_ok():
		return source
	return _field_parity_refusal()


static func _source_refusal() -> SaveHeader.Refusal:
	"""Gate 4's source half: the two row capacities, the kind domain and the severity domain."""
	if Injury.RESIDENT_CAPACITY != SOURCE_ROW_CAPACITY \
			or Injury.Needs.RESIDENT_CAPACITY != SOURCE_NEEDS_ROW_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s Injury declares %d rows against the needs store's %d"
				% [METADATA_DETAIL_PREFIX, Injury.RESIDENT_CAPACITY,
					Injury.Needs.RESIDENT_CAPACITY])
	if Injury.KIND_NONE != SOURCE_KIND_NONE or Injury.KIND_CUT != SOURCE_KIND_CUT \
			or Injury.KIND_BITE != SOURCE_KIND_BITE or Injury.KIND_FALL != SOURCE_KIND_FALL \
			or Injury.KIND_EXPOSURE != SOURCE_KIND_EXPOSURE \
			or Injury.KIND_EXHAUSTION != SOURCE_KIND_EXHAUSTION \
			or Injury.KIND_COUNT != SOURCE_KIND_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the InjuryKind domain is not the pinned six-member numbering"
				% METADATA_DETAIL_PREFIX)
	if Injury.SEVERITY_NONE != SOURCE_SEVERITY_NONE \
			or Injury.SEVERITY_MINOR != SOURCE_SEVERITY_MINOR \
			or Injury.SEVERITY_SERIOUS != SOURCE_SEVERITY_SERIOUS:
		return _refuse(Section.REFUSE_METADATA,
			"%s the severity domain is %d/%d/%d, not %d/%d/%d"
				% [METADATA_DETAIL_PREFIX, Injury.SEVERITY_NONE, Injury.SEVERITY_MINOR,
					Injury.SEVERITY_SERIOUS, SOURCE_SEVERITY_NONE, SOURCE_SEVERITY_MINOR,
					SOURCE_SEVERITY_SERIOUS])
	return _source_handle_refusal()


static func _source_handle_refusal() -> SaveHeader.Refusal:
	"""Gate 4's handle half: the global directory capacity and both spellings of the null pair."""
	if Injury.EntityDirectory.DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s the global directory holds %d slots, not %d"
				% [METADATA_DETAIL_PREFIX, Injury.EntityDirectory.DIRECTORY_CAPACITY,
					SOURCE_DIRECTORY_CAPACITY])
	if Injury.EntityDirectory.NULL_SLOT != SOURCE_NULL_SLOT \
			or Injury.EntityDirectory.NULL_GENERATION != SOURCE_NULL_GENERATION \
			or Injury.NULL_SLOT != SOURCE_NULL_SLOT \
			or Injury.NULL_GENERATION != SOURCE_NULL_GENERATION \
			or Injury.NULL_REF.x != SOURCE_NULL_SLOT \
			or Injury.NULL_REF.y != SOURCE_NULL_GENERATION:
		return _refuse(Section.REFUSE_METADATA, "%s the null handle is (%d, %d), not (%d, %d)"
			% [METADATA_DETAIL_PREFIX, Injury.NULL_REF.x, Injury.NULL_REF.y, SOURCE_NULL_SLOT,
				SOURCE_NULL_GENERATION])
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: eleven explicit ordinals, five u8 columns, three i32 and three i64."""
	var head: SaveHeader.Refusal = _field_head_refusal()
	if not head.is_ok():
		return head
	return _field_tail_refusal()


static func _field_head_refusal() -> SaveHeader.Refusal:
	"""Ordinals 0..4: the occupancy byte, the kind byte and the three latch/input bytes."""
	var present: SaveHeader.Refusal = _field_refusal(FIELD_PRESENT, FIELD_PRESENT_KEY,
		Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not present.is_ok():
		return present
	var kind: SaveHeader.Refusal = _field_refusal(FIELD_KIND, FIELD_KIND_KEY, Schema.TYPE_U8,
		ROW_ELEMENT_COUNT)
	if not kind.is_ok():
		return kind
	var airless: SaveHeader.Refusal = _field_refusal(FIELD_AIRLESS_EPISODE,
		FIELD_AIRLESS_EPISODE_KEY, Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not airless.is_ok():
		return airless
	var exhaustion: SaveHeader.Refusal = _field_refusal(FIELD_EXHAUSTION_LATCH,
		FIELD_EXHAUSTION_LATCH_KEY, Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not exhaustion.is_ok():
		return exhaustion
	return _field_refusal(FIELD_CARE_CONTEXT_BLOCKED, FIELD_CARE_CONTEXT_BLOCKED_KEY,
		Schema.TYPE_U8, ROW_ELEMENT_COUNT)


static func _field_tail_refusal() -> SaveHeader.Refusal:
	"""Ordinals 5..10: severity, the split rescuer reference and the three i64 counters."""
	var severity: SaveHeader.Refusal = _field_refusal(FIELD_SEVERITY, FIELD_SEVERITY_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not severity.is_ok():
		return severity
	var rescuer_slot: SaveHeader.Refusal = _field_refusal(FIELD_RESCUER_SLOT,
		FIELD_RESCUER_SLOT_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not rescuer_slot.is_ok():
		return rescuer_slot
	var rescuer_generation: SaveHeader.Refusal = _field_refusal(FIELD_RESCUER_GENERATION,
		FIELD_RESCUER_GENERATION_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not rescuer_generation.is_ok():
		return rescuer_generation
	var untreated: SaveHeader.Refusal = _field_refusal(FIELD_UNTREATED_TICKS,
		FIELD_UNTREATED_TICKS_KEY, Schema.TYPE_I64, ROW_ELEMENT_COUNT)
	if not untreated.is_ok():
		return untreated
	var care: SaveHeader.Refusal = _field_refusal(FIELD_CARE_PROGRESS_MWU,
		FIELD_CARE_PROGRESS_MWU_KEY, Schema.TYPE_I64, ROW_ELEMENT_COUNT)
	if not care.is_ok():
		return care
	return _field_refusal(FIELD_LAST_INCIDENT_ORDINAL, FIELD_LAST_INCIDENT_ORDINAL_KEY,
		Schema.TYPE_I64, ROW_ELEMENT_COUNT)


static func _field_refusal(field: int, key: String, type_code: int,
		count: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its declared type and its exact extent."""
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
	"""Build a refusal carrying an exact code: a section code, or a raw Injury column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
