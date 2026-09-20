extends RefCounted
## Owner 11 (`priorities`) framed-column validation bridge (PRIORITIES-S4-VALIDATE-R01 v1,
## decision 0171).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the Priorities store's own column rules and returns a `SaveHeader.Refusal`. It builds
## no live Priorities owner, calls no store, captures nothing, applies nothing, and touches no
## clock, barrier, signal, callback, filesystem, JSON text, reflection API or per-row object.
##
## GATE ORDER, and what each gate owns:
##   1. a null record                  -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 11  -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`      -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `Priorities owner11 metadata:` so gate 4 is distinguishable from gate 3, which shares
##      the code. THE CODE ALONE DOES NOT IDENTIFY WHICH METADATA GATE FIRED.
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the four explicit `u8_column()` ordinals, in the predicate's canonical argument order
##   7. `Priorities.columns_refusal()`  -> the EXACT unwrapped column code, for example
##      COLUMN_RESERVED_PRIORITY, with a detail naming owner 11 and that same code.
## Success carries an empty code and an empty detail.
##
## NO PROJECTION IS ALLOCATED. Unlike the Needs bridge there is no `Columns` object here: the
## four accessors are passed straight into the static predicate and share the caller's frozen
## copy-on-write buffers. Nothing is duplicated, substituted, sorted or retained, so both an
## accepted and a refused call leave every caller array untouched. One framed image is
## 6144 + 3 * 512 = 7680 logical packed bytes, charged once to the caller; wrapper and native
## overhead are unmeasured, and no resident row or immutable Array row is introduced.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Cross-owner occupancy, resident identity,
## consent-dependent eligibility, REQ-SET-028's low-risk FORAGE half, lifecycle or barrier
## publication, full-file provenance, or permission to install anything into a live store. An
## all-zero frame is a valid EMPTY Priorities image. Bulk capture/apply, rebuilding present_count
## on restore and the other seventeen owners remain outstanding elsewhere.
##
## THE METADATA GUARD COMPARES THE SCHEMA TO PINNED CONTRACT LITERALS and to the owner's own
## capacity and stride constants, because this owner publishes no column tables. That is not an
## owner-publication-table parity check; the independent schema generator and source-capacity
## audit still prove the registry against the actual owner declarations.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Priorities := preload("res://scripts/core/priorities.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 11
const OWNER_KEY: String = "priorities"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 512
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 4
## SET-AMEND-001's physical 12-kind stride, cross-checked against the owner's own constant.
const OWNER_JOB_KIND_COUNT: int = 12
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Priorities owner11 metadata:"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_PRESENT: int = 0
const FIELD_JOB_PRIORITY: int = 1
const FIELD_AUTO_FALLBACK: int = 2
const FIELD_DANGEROUS_WORK: int = 3

## The pinned per-field contract: every field is u8, at exactly these element counts.
const FIELD_PRESENT_KEY: String = "_present"
const FIELD_JOB_PRIORITY_KEY: String = "_job_priority"
const FIELD_AUTO_FALLBACK_KEY: String = "_auto_fallback"
const FIELD_DANGEROUS_WORK_KEY: String = "_dangerous_work"
const FLAG_ELEMENT_COUNT: int = 512
const JOB_PRIORITY_ELEMENT_COUNT: int = 6144


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 11 block against the Priorities store's own column rules.

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
	var code: StringName = Priorities.columns_refusal(record.u8_column(FIELD_PRESENT),
		record.u8_column(FIELD_JOB_PRIORITY), record.u8_column(FIELD_AUTO_FALLBACK),
		record.u8_column(FIELD_DANGEROUS_WORK))
	if code != Priorities.REFUSE_NONE:
		return _refuse(code,
			"Priorities owner %d refuses this image with column code %s"
				% [OWNER_INDEX, String(code)])
	return _accept()


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
			or Priorities.PRIORITY_CAPACITY != OWNER_PRIMARY_COUNT \
			or Priorities.JOB_KIND_COUNT != OWNER_JOB_KIND_COUNT \
			or JOB_PRIORITY_ELEMENT_COUNT != OWNER_PRIMARY_COUNT * OWNER_JOB_KIND_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the schema declares %d fields and Priorities declares %d rows of %d kinds"
				% [METADATA_DETAIL_PREFIX, Schema.field_count(OWNER_INDEX),
					Priorities.PRIORITY_CAPACITY, Priorities.JOB_KIND_COUNT])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: four explicit ordinals, each u8 at its exact element count."""
	var present: SaveHeader.Refusal = _field_refusal(FIELD_PRESENT, FIELD_PRESENT_KEY,
		FLAG_ELEMENT_COUNT)
	if not present.is_ok():
		return present
	var job_priority: SaveHeader.Refusal = _field_refusal(FIELD_JOB_PRIORITY,
		FIELD_JOB_PRIORITY_KEY, JOB_PRIORITY_ELEMENT_COUNT)
	if not job_priority.is_ok():
		return job_priority
	var auto_fallback: SaveHeader.Refusal = _field_refusal(FIELD_AUTO_FALLBACK,
		FIELD_AUTO_FALLBACK_KEY, FLAG_ELEMENT_COUNT)
	if not auto_fallback.is_ok():
		return auto_fallback
	return _field_refusal(FIELD_DANGEROUS_WORK, FIELD_DANGEROUS_WORK_KEY, FLAG_ELEMENT_COUNT)


static func _field_refusal(field: int, key: String, count: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its u8 type code and its exact element count."""
	if Schema.field_key(OWNER_INDEX, field) != key:
		return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; the contract fixes '%s'"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field), key])
	if Schema.field_type(OWNER_INDEX, field) != Schema.TYPE_U8:
		return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
				Schema.TYPE_U8])
	if Schema.element_count(OWNER_INDEX, field) != count:
		return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field), count])
	return _accept()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Priorities column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
