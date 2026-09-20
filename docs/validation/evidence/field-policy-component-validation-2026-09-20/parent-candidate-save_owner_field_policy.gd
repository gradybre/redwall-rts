extends RefCounted
## Owner 3 (`field_policy`) column validation bridge (FIELD-POLICY-S4-VALIDATE-R01 v1, ADR 0179).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the FieldPolicy store's own saved column predicate and returns a `SaveHeader.Refusal`.
## It constructs no live FieldPolicy, Farming, Forage or Directory owner, captures nothing,
## restores nothing, copies nothing and writes no diagnostic.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 3    -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned FieldPolicy source constants ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `FieldPolicy owner3 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. one cold `FieldPolicy.Columns` whose TWENTY canonical typed accessors are all assigned
##      explicitly, in declared ordinal order
##   7. `FieldPolicy.columns_refusal()` -> the EXACT unwrapped column code, for example
##      COLUMN_OPEN_COUNTS, in a detail naming owner 3 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## LOCAL ACCEPTANCE IS NOT PUBLICATION. An accepted result certifies owner-3 local column domains
## only. Same-file Directory and Forage zone identity, unique policy-zone ownership, FarmPlot row
## lifetime and enrolment joins, and loaded-world consistency remain saved-bindings obligations,
## as does installing anything live. FieldPolicy bulk capture and apply do not exist.
##
## MEMORY, CONDITIONALLY. The projection SHARES the caller's packed buffers by assignment: no
## `duplicate()` runs here. The contract's conservative figure is 90112 logical packed bytes --
## the 44288-byte caller image, the default Columns buffers and the predicate's three 128-entry
## int32 scratch columns -- below the 6417408-byte stream allowance. That is allocation
## arithmetic, not a measured resident set.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const FieldPolicy := preload("res://scripts/core/field_policy.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 3
const OWNER_KEY: String = "field_policy"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 128
const OWNER_CHILD_EXTENT_COUNT: int = 1
## The one declared child extent: farming.gd's FarmPlot capacity, carried by the ledger columns.
const OWNER_PLOT_COUNT: int = 4096
const OWNER_FIELD_COUNT: int = 20
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "FieldPolicy owner3 metadata:"
## Gate 7's detail prefix. It names the owner and the code, and never a row.
const COLUMN_DETAIL_PREFIX: String = "FieldPolicy owner 3"

## The canonical owner-local field declarations, in registry ordinal order.
const FIELD_KEYS: Array[StringName] = [
	&"_field_present", &"_zone_slot", &"_zone_generation", &"_rotation_ids",
	&"_rotation_cursor", &"_auto_rotation", &"_seed_reserve", &"_cycle_ordinal",
	&"_participants", &"_resolved", &"_withdrawn", &"_completed_cycles",
	&"_cancelled_cycles", &"_requested_crop", &"_cycle_state", &"_close_reason",
	&"_request_state", &"_plot_field_slot", &"_plot_cycle", &"_plot_outcome",
]
const FIELD_TYPES: Array[int] = [
	Schema.TYPE_U8, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_U8, Schema.TYPE_U8, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_U8,
	Schema.TYPE_U8, Schema.TYPE_U8, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_U8,
]
const FIELD_COUNTS: Array[int] = [
	128, 128, 128, 384, 128, 128, 128, 128, 128, 128,
	128, 128, 128, 128, 128, 128, 128, 4096, 4096, 4096,
]

## Owner-local field ordinals, in the order the canonical registry publishes them.
const FIELD_PRESENT: int = 0
const FIELD_ZONE_SLOT: int = 1
const FIELD_ZONE_GENERATION: int = 2
const FIELD_ROTATION_IDS: int = 3
const FIELD_ROTATION_CURSOR: int = 4
const FIELD_AUTO_ROTATION: int = 5
const FIELD_SEED_RESERVE: int = 6
const FIELD_CYCLE_ORDINAL: int = 7
const FIELD_PARTICIPANTS: int = 8
const FIELD_RESOLVED: int = 9
const FIELD_WITHDRAWN: int = 10
const FIELD_COMPLETED_CYCLES: int = 11
const FIELD_CANCELLED_CYCLES: int = 12
const FIELD_REQUESTED_CROP: int = 13
const FIELD_CYCLE_STATE: int = 14
const FIELD_CLOSE_REASON: int = 15
const FIELD_REQUEST_STATE: int = 16
const FIELD_PLOT_FIELD_SLOT: int = 17
const FIELD_PLOT_CYCLE: int = 18
const FIELD_PLOT_OUTCOME: int = 19

## The FieldPolicy source constants this bridge pins as contract before it reads a column.
const SOURCE_FIELD_CAPACITY: int = 128
const SOURCE_PLOT_CAPACITY: int = 4096
const SOURCE_ROTATION_LENGTH: int = 3
const SOURCE_NO_FIELD: int = -1
const SOURCE_NO_CROP: int = -1
const SOURCE_NO_CYCLE: int = 0
const SOURCE_FIRST_CYCLE: int = 1
const SOURCE_MAX_CYCLE: int = 2147483647
const SOURCE_CYCLE_IDLE: int = 0
const SOURCE_CYCLE_OPEN: int = 1
const SOURCE_CYCLE_CLOSED: int = 2
const SOURCE_CYCLE_STATE_COUNT: int = 3
const SOURCE_CLOSE_NONE: int = 0
const SOURCE_CLOSE_COMPLETED: int = 1
const SOURCE_CLOSE_CANCELLED: int = 2
const SOURCE_CLOSE_ABANDONED: int = 3
const SOURCE_CLOSE_REASON_COUNT: int = 4
const SOURCE_OUTCOME_UNRESOLVED: int = 0
const SOURCE_OUTCOME_HARVESTED: int = 1
const SOURCE_OUTCOME_CLEARED: int = 2
const SOURCE_OUTCOME_WITHDRAWN: int = 3
const SOURCE_OUTCOME_COUNT: int = 4
const SOURCE_REQUEST_NONE: int = 0
const SOURCE_REQUEST_READY: int = 1
const SOURCE_REQUEST_WINDOW_FUTURE: int = 2
const SOURCE_REQUEST_WINDOW_MISSED: int = 3
const SOURCE_REQUEST_ENTRY_NOT_CONFIGURED: int = 4
const SOURCE_REQUEST_NO_LEGAL_WINDOW: int = 5
const SOURCE_REQUEST_STATE_COUNT: int = 6
const SOURCE_CROP_NONE: int = -1
const SOURCE_CROP_COUNT: int = 5
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0
## The GLOBAL Directory capacity, not Transform's 87552: the zone pair rule is bounded by it.
const SOURCE_DIRECTORY_CAPACITY: int = 352418


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 3 block against the FieldPolicy store's own saved column rules."""
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
	var columns: FieldPolicy.Columns = FieldPolicy.Columns.new()
	_project_field_rows(record, columns)
	_project_plot_ledger(record, columns)
	var code: StringName = FieldPolicy.columns_refusal(columns)
	if code != FieldPolicy.REFUSE_NONE:
		return _refuse(code, "%s refuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned FieldPolicy constants."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA,
			"%s compiled owner '%s' version %d is not '%s' version %d"
				% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX),
					Schema.owner_version(OWNER_INDEX), OWNER_KEY, OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT \
			or Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT \
			or Schema.child_extent(OWNER_INDEX, 0) != OWNER_PLOT_COUNT \
			or Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d primaries, %d child extents, first extent %d and %d fields are not %d/%d/%d/%d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), Schema.child_extent(OWNER_INDEX, 0),
					Schema.field_count(OWNER_INDEX), OWNER_PRIMARY_COUNT,
					OWNER_CHILD_EXTENT_COUNT, OWNER_PLOT_COUNT, OWNER_FIELD_COUNT])
	if FIELD_KEYS.size() != OWNER_FIELD_COUNT or FIELD_TYPES.size() != OWNER_FIELD_COUNT \
			or FIELD_COUNTS.size() != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s this bridge pins %d/%d/%d field declarations, not %d"
				% [METADATA_DETAIL_PREFIX, FIELD_KEYS.size(), FIELD_TYPES.size(),
					FIELD_COUNTS.size(), OWNER_FIELD_COUNT])
	var source: SaveHeader.Refusal = _source_refusal()
	if not source.is_ok():
		return source
	return _field_parity_refusal()


static func _source_refusal() -> SaveHeader.Refusal:
	"""Gate 4's source half: the three capacities and the cycle and empty-id sentinels."""
	if FieldPolicy.FIELD_CAPACITY != SOURCE_FIELD_CAPACITY \
			or FieldPolicy.PLOT_CAPACITY != SOURCE_PLOT_CAPACITY \
			or FieldPolicy.ROTATION_LENGTH != SOURCE_ROTATION_LENGTH:
		return _refuse(Section.REFUSE_METADATA,
			"%s FieldPolicy declares %d fields, %d plots and a %d-entry rotation, not %d/%d/%d"
				% [METADATA_DETAIL_PREFIX, FieldPolicy.FIELD_CAPACITY,
					FieldPolicy.PLOT_CAPACITY, FieldPolicy.ROTATION_LENGTH,
					SOURCE_FIELD_CAPACITY, SOURCE_PLOT_CAPACITY, SOURCE_ROTATION_LENGTH])
	if FieldPolicy.NO_CYCLE != SOURCE_NO_CYCLE \
			or FieldPolicy.FIRST_CYCLE != SOURCE_FIRST_CYCLE \
			or FieldPolicy.MAX_CYCLE != SOURCE_MAX_CYCLE \
			or FieldPolicy.NO_FIELD != SOURCE_NO_FIELD \
			or FieldPolicy.NO_CROP != SOURCE_NO_CROP:
		return _refuse(Section.REFUSE_METADATA,
			"%s the cycle sentinels are not %d/%d/%d with NO_FIELD %d and NO_CROP %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_NO_CYCLE, SOURCE_FIRST_CYCLE,
					SOURCE_MAX_CYCLE, SOURCE_NO_FIELD, SOURCE_NO_CROP])
	return _source_enum_refusal()


static func _source_enum_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the cycle state, close reason and plot outcome ordinals and their counts."""
	if FieldPolicy.CYCLE_IDLE != SOURCE_CYCLE_IDLE \
			or FieldPolicy.CYCLE_OPEN != SOURCE_CYCLE_OPEN \
			or FieldPolicy.CYCLE_CLOSED != SOURCE_CYCLE_CLOSED \
			or FieldPolicy.CYCLE_STATE_COUNT != SOURCE_CYCLE_STATE_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the cycle state domain is not the pinned 0/1/2 numbering bounded by %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_CYCLE_STATE_COUNT])
	if FieldPolicy.CLOSE_NONE != SOURCE_CLOSE_NONE \
			or FieldPolicy.CLOSE_COMPLETED != SOURCE_CLOSE_COMPLETED \
			or FieldPolicy.CLOSE_CANCELLED != SOURCE_CLOSE_CANCELLED \
			or FieldPolicy.CLOSE_ABANDONED != SOURCE_CLOSE_ABANDONED \
			or FieldPolicy.CLOSE_REASON_COUNT != SOURCE_CLOSE_REASON_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the close reason domain is not the pinned 0/1/2/3 numbering bounded by %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_CLOSE_REASON_COUNT])
	if FieldPolicy.OUTCOME_UNRESOLVED != SOURCE_OUTCOME_UNRESOLVED \
			or FieldPolicy.OUTCOME_HARVESTED != SOURCE_OUTCOME_HARVESTED \
			or FieldPolicy.OUTCOME_CLEARED != SOURCE_OUTCOME_CLEARED \
			or FieldPolicy.OUTCOME_WITHDRAWN != SOURCE_OUTCOME_WITHDRAWN \
			or FieldPolicy.OUTCOME_COUNT != SOURCE_OUTCOME_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the plot outcome domain is not the pinned 0/1/2/3 numbering bounded by %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_OUTCOME_COUNT])
	return _source_request_refusal()


static func _source_request_refusal() -> SaveHeader.Refusal:
	"""Gate 4's last half: the six request states, the crop domain and the Directory pair."""
	if FieldPolicy.REQUEST_NONE != SOURCE_REQUEST_NONE \
			or FieldPolicy.REQUEST_READY != SOURCE_REQUEST_READY \
			or FieldPolicy.REQUEST_WINDOW_FUTURE != SOURCE_REQUEST_WINDOW_FUTURE \
			or FieldPolicy.REQUEST_WINDOW_MISSED != SOURCE_REQUEST_WINDOW_MISSED \
			or FieldPolicy.REQUEST_ENTRY_NOT_CONFIGURED != SOURCE_REQUEST_ENTRY_NOT_CONFIGURED \
			or FieldPolicy.REQUEST_NO_LEGAL_WINDOW != SOURCE_REQUEST_NO_LEGAL_WINDOW \
			or FieldPolicy.REQUEST_STATE_COUNT != SOURCE_REQUEST_STATE_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the request domain is not the pinned 0..5 numbering bounded by %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_REQUEST_STATE_COUNT])
	var crops: SaveHeader.Refusal = _source_crop_refusal()
	if not crops.is_ok():
		return crops
	if FieldPolicy.EntityDirectory.NULL_SLOT != SOURCE_NULL_SLOT \
			or FieldPolicy.EntityDirectory.NULL_GENERATION != SOURCE_NULL_GENERATION \
			or FieldPolicy.EntityDirectory.DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s the null handle is not (%d, %d) over a %d-row global Directory"
				% [METADATA_DETAIL_PREFIX, SOURCE_NULL_SLOT, SOURCE_NULL_GENERATION,
					SOURCE_DIRECTORY_CAPACITY])
	return _accept()


static func _source_crop_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the fixed five-crop domain and every named crop ordinal, not gameplay defaults."""
	if FieldPolicy.FarmingScript.CROP_NONE != SOURCE_CROP_NONE \
			or FieldPolicy.FarmingScript.CROP_COUNT != SOURCE_CROP_COUNT \
			or FieldPolicy.FarmingScript.CROP_BEANS != 0 \
			or FieldPolicy.FarmingScript.CROP_CABBAGE != 1 \
			or FieldPolicy.FarmingScript.CROP_FLAX != 2 \
			or FieldPolicy.FarmingScript.CROP_GRAIN != 3 \
			or FieldPolicy.FarmingScript.CROP_ROOTS != 4:
		return _refuse(Section.REFUSE_METADATA,
			"%s Farming crop sentinels or bean/cabbage/flax/grain/root ordinals differ"
				% METADATA_DETAIL_PREFIX)
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: key, type code and element count, ordinal by ordinal."""
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; owner 3 declares '%s'"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field),
					String(FIELD_KEYS[field])])
		if Schema.field_type(OWNER_INDEX, field) != int(FIELD_TYPES[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; %d is declared"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
					int(FIELD_TYPES[field])])
		if Schema.element_count(OWNER_INDEX, field) != int(FIELD_COUNTS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; %d are declared"
				% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field),
					int(FIELD_COUNTS[field])])
	return _accept()


static func _project_field_rows(record: Section.FramedOwner, columns: FieldPolicy.Columns) -> void:
	"""Ordinals 0..16: the 128-row policy image, including the 384-entry rotation list."""
	columns.field_present = record.u8_column(FIELD_PRESENT)
	columns.zone_slot = record.i32_column(FIELD_ZONE_SLOT)
	columns.zone_generation = record.i32_column(FIELD_ZONE_GENERATION)
	columns.rotation_ids = record.i32_column(FIELD_ROTATION_IDS)
	columns.rotation_cursor = record.i32_column(FIELD_ROTATION_CURSOR)
	columns.auto_rotation = record.u8_column(FIELD_AUTO_ROTATION)
	columns.seed_reserve = record.u8_column(FIELD_SEED_RESERVE)
	columns.cycle_ordinal = record.i32_column(FIELD_CYCLE_ORDINAL)
	columns.participants = record.i32_column(FIELD_PARTICIPANTS)
	columns.resolved = record.i32_column(FIELD_RESOLVED)
	columns.withdrawn = record.i32_column(FIELD_WITHDRAWN)
	columns.completed_cycles = record.i32_column(FIELD_COMPLETED_CYCLES)
	columns.cancelled_cycles = record.i32_column(FIELD_CANCELLED_CYCLES)
	columns.requested_crop = record.i32_column(FIELD_REQUESTED_CROP)
	columns.cycle_state = record.u8_column(FIELD_CYCLE_STATE)
	columns.close_reason = record.u8_column(FIELD_CLOSE_REASON)
	columns.request_state = record.u8_column(FIELD_REQUEST_STATE)


static func _project_plot_ledger(record: Section.FramedOwner, columns: FieldPolicy.Columns) -> void:
	"""Ordinals 17..19: the 4096-row enrolment ledger, each assigned explicitly like the rest."""
	columns.plot_field_slot = record.i32_column(FIELD_PLOT_FIELD_SLOT)
	columns.plot_cycle = record.i32_column(FIELD_PLOT_CYCLE)
	columns.plot_outcome = record.u8_column(FIELD_PLOT_OUTCOME)


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw FieldPolicy column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
