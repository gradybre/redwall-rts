extends RefCounted
## Owner 1 (`construction`) column validation bridge (CONSTRUCTION-S4-VALIDATE-R01v2, ADR 0186).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the Construction store's own cold column predicate and returns a `SaveHeader.Refusal`.
## It constructs no live Construction, Buildings, BuildingDefinitions or EntityDirectory instance,
## reads no clock, takes no callback, captures nothing, restores nothing and writes no diagnostic.
##
## GATE ORDER (frozen by the accepted contract):
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 1    -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata, the pure source preflight and this bridge's own
##      INDEPENDENT out-of-file SOURCE_* anchors -> SAVE_COMPONENT_METADATA, detail beginning
##      `Construction owner1 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED, proving all 16 extents BEFORE
##      any projection or indexing
##   6. one cold `Construction.Columns.new(false)` whose SIXTEEN canonical typed columns are
##      all assigned explicitly, in declared ordinal order, through the sole static
##      `_project_columns(record, out)` helper -- callable directly by tests, no public wrapper
##   7. `Construction.columns_refusal()` -> the EXACT unwrapped column code, for example
##      COLUMN_PHASE, wrapped in a detail naming owner 1 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## THE TWO PREFIXES ARE DELIBERATELY SPELLED DIFFERENTLY. Gate 4 writes
## `Construction owner1 metadata:` and gate 7 writes `Construction owner 1 `. Do not "tidy" either.
##
## GATE 4 IS TWO SEPARATE PROTECTIONS, NOT ONE. `Construction.column_source_metadata_refusal()`
## already protects the pure predicate independently of any caller having run first. This bridge
## calls it AND SEPARATELY holds its own frozen SOURCE_* scalar, array and bill anchors, literal
## in THIS file and never derived from Construction's own SOURCE_* in-file mirror. A coherence
## attack that edits the live catalog/fact source AND Construction's own SOURCE_* mirror together
## can still pass Construction's internal self-check; it cannot pass this bridge's independent
## third copy, because that copy is compared against both the live constants and Construction's
## mirror and never assumes either already agrees with the truth.
##
## BORROWED, NOT COPIED. `Construction.Columns.new(false)` returns before a single resize or
## fill, so this bridge assigns the record's already-shaped buffers over the 16 empty members
## instead of allocating a second owner image beside the one it is judging. Nothing here calls
## `duplicate()`, resizes a packed array, serializes a byte, sorts, hashes or builds a per-row
## object.
##
## SECTION 4 LOCAL ACCEPTANCE ONLY. Directory self identity, section 5's delivered-material
## ledger, same-file provenance, loaded-tick relations, demolition economics and playable
## construction all remain CONSTRUCTION-SAVED-BINDINGS obligations and are not addressed here.
## This file makes no claim of execution, test result or product acceptance.
##
## NO FLOAT. There is no float in this file and there must never be one.

const Construction := preload("res://scripts/core/construction.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 1
const OWNER_KEY: String = "construction"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 82944
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 16
## The compiled ordinal this owner's sixteen fields begin at (bridge inspection finding B1).
const OWNER_FIELD_BEGIN: int = 29
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Construction owner1 metadata:"
## Gate 7's detail prefix, deliberately spaced, and naming no row.
const COLUMN_DETAIL_PREFIX: String = "Construction owner 1 "

## Owner-local field ordinals, in the contract's exact table order.
const FIELD_PRESENT: int = 0
const FIELD_MATERIAL_CONTAINER_SLOT: int = 1
const FIELD_MATERIAL_CONTAINER_GENERATION: int = 2
const FIELD_ASSIGNED_COUNT: int = 3
const FIELD_MAX_WORKERS: int = 4
const FIELD_REFUND_POLICY: int = 5
const FIELD_REMAINING_MWU: int = 6
const FIELD_PAUSED: int = 7
const FIELD_WORK_BEGUN: int = 8
const FIELD_REF_SLOT: int = 9
const FIELD_REF_GENERATION: int = 10
const FIELD_SUBJECT_SLOT: int = 11
const FIELD_SUBJECT_GENERATION: int = 12
const FIELD_PURPOSE: int = 13
const FIELD_TYPE_ID: int = 14
const FIELD_PHASE: int = 15

## The canonical owner-local field declarations, in registry ordinal order (field begin 29).
const FIELD_KEYS: Array[StringName] = [
	&"_present", &"_material_container_slot", &"_material_container_generation",
	&"_assigned_count", &"_max_workers", &"_refund_policy", &"_remaining_mwu",
	&"_paused", &"_work_begun", &"_ref_slot", &"_ref_generation",
	&"_subject_slot", &"_subject_generation", &"_purpose", &"_type_id", &"_phase",
]
const FIELD_TYPES: Array[int] = [
	Schema.TYPE_U8, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I64, Schema.TYPE_U8, Schema.TYPE_U8, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32,
]
const FIELD_COUNTS: Array[int] = [
	82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944,
	82944, 82944, 82944, 82944, 82944, 82944, 82944, 82944,
]

# --- independent out-of-file scalar anchors, distinct from Construction's own SOURCE_* mirror ---

const SOURCE_ROW_CAPACITY: int = 82944
const SOURCE_MATERIAL_SLOTS_PER_PROJECT: int = 4
const SOURCE_MAX_BUILDERS: int = 4
const SOURCE_DEMOLITION_WORK_NUM: int = 1
const SOURCE_DEMOLITION_WORK_DEN: int = 4
const SOURCE_INT32_MAX: int = 2147483647
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0
const SOURCE_DIRECTORY_CAPACITY: int = 352418
const SOURCE_PURPOSE_BUILD: int = 0
const SOURCE_PURPOSE_UPGRADE: int = 1
const SOURCE_PURPOSE_FURNITURE: int = 2
const SOURCE_PURPOSE_DEMOLISH: int = 3
const SOURCE_PURPOSE_COUNT: int = 4
const SOURCE_PHASE_AWAITING_MATERIALS: int = 0
const SOURCE_PHASE_READY: int = 1
const SOURCE_PHASE_WORKING: int = 2
const SOURCE_PHASE_WORK_DONE: int = 3
const SOURCE_PHASE_REFUNDING: int = 4
const SOURCE_PHASE_COUNT: int = 5
const SOURCE_REFUND_FULL: int = 0
const SOURCE_REFUND_PARTIAL: int = 1
const SOURCE_REFUND_DEMOLITION: int = 2
const SOURCE_REFUND_POLICY_COUNT: int = 3
const SOURCE_BUILDING_KIND_COUNT: int = 30
const SOURCE_FURNITURE_KIND_COUNT: int = 9
## BuildingDefinitions fact-row indexes and row widths, pinned here INDEPENDENTLY of
## Construction's own SOURCE_* mirror of the same five constants (inspection finding B2).
const SOURCE_B_WORK_MWU: int = 2
const SOURCE_B_MAX_BUILDERS: int = 9
const SOURCE_B_FIELD_COUNT: int = 10
const SOURCE_F_WORK_MWU: int = 2
const SOURCE_F_FIELD_COUNT: int = 4
const SOURCE_MATERIAL_KEY_COUNT: int = 6
const SOURCE_TIER_TWO_COUNT: int = 4

const SOURCE_MATERIAL_KEYS: Array[String] = ["wood", "stone", "cloth", "iron", "rope", "wax"]
const SOURCE_TIER_TWO_KEYS: Array[String] = ["covered_store", "hall", "residence", "workshop"]

## The ten frozen gate-consumed arrays, transcribed independently from frozen-source-facts.json
## in canonical ascending id order, compared against Construction's own COLUMN_* gate arrays.
const SOURCE_BUILDING_KEYS: Array[String] = [
	"apiary", "boathouse", "brewery", "cellar", "composter", "covered_store",
	"dirt_path", "dryer", "fence", "fisher_shelter", "forester_lodge", "gate",
	"hall", "infirmary", "kitchen", "lookout", "memorial_garden", "mill",
	"nursery", "open_stockpile", "paved_path", "preserver", "quarry_shed", "residence",
	"saltpan", "stone_wall", "weir", "well", "workbench", "workshop",
]
const SOURCE_BUILDING_WORK_MWU: Array[int] = [
	180000, 720000, 480000, 900000, 120000, 480000,
	2000, 240000, 12000, 240000, 240000, 90000,
	2400000, 1000000, 600000, 180000, 240000, 720000,
	300000, 60000, 6000, 480000, 240000, 1200000,
	240000, 30000, 480000, 240000, 180000, 720000,
]
const SOURCE_BUILDING_MAX_WORKERS: Array[int] = [
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
]
const SOURCE_BUILDING_BILL_PAIR_COUNTS: Array[int] = [
	2, 3, 3, 2, 1, 2,
	0, 2, 1, 2, 2, 2,
	3, 3, 3, 2, 2, 2,
	2, 1, 1, 3, 2, 3,
	2, 1, 3, 2, 2, 3,
]
const SOURCE_FURNITURE_KEYS: Array[String] = [
	"bed", "decoration", "hearth", "interior_door", "interior_partition",
	"kitchen_bench", "patient_bed", "seat", "shelf",
]
const SOURCE_FURNITURE_WORK_MWU: Array[int] = [
	20000, 12000, 60000, 12000, 8000, 60000, 24000, 10000, 16000,
]
const SOURCE_FURNITURE_BILL_PAIR_COUNTS: Array[int] = [
	2, 2, 1, 1, 1, 3, 2, 1, 1,
]
const SOURCE_UPGRADE_IDS: Array[int] = [5, 12, 23, 29]
const SOURCE_UPGRADE_WORK_MWU: Array[int] = [600000, 1200000, 1200000, 720000]
const SOURCE_UPGRADE_BILL_PAIR_COUNTS: Array[int] = [2, 3, 3, 2]

## Exact frozen bill dictionaries (flat key/quantity pairs), independent of BUILD_MATERIALS /
## FURNITURE_MATERIALS / UPGRADE_MATERIALS in construction.gd. Order and quantities are drift
## checks: only bill emptiness, work, max-workers and upgrade membership affect local row gates,
## but this bridge still proves the authored bill CONTENTS have not drifted from the source.
const SOURCE_BUILD_BILLS: Dictionary = {
	"apiary": ["wood", 12000, "rope", 2000],
	"boathouse": ["wood", 40000, "stone", 16000, "rope", 4000],
	"brewery": ["wood", 24000, "stone", 12000, "iron", 2000],
	"cellar": ["wood", 20000, "stone", 60000],
	"composter": ["wood", 10000],
	"covered_store": ["wood", 35000, "stone", 10000],
	"dirt_path": [],
	"dryer": ["wood", 16000, "rope", 4000],
	"fence": ["wood", 1000],
	"fisher_shelter": ["wood", 18000, "rope", 2000],
	"forester_lodge": ["wood", 20000, "stone", 8000],
	"gate": ["wood", 6000, "iron", 1000],
	"hall": ["wood", 100000, "stone", 60000, "cloth", 12000],
	"infirmary": ["wood", 40000, "stone", 30000, "cloth", 12000],
	"kitchen": ["wood", 30000, "stone", 20000, "iron", 2000],
	"lookout": ["wood", 12000, "stone", 4000],
	"memorial_garden": ["wood", 8000, "stone", 12000],
	"mill": ["wood", 25000, "stone", 30000],
	"nursery": ["wood", 16000, "stone", 8000],
	"open_stockpile": ["wood", 4000],
	"paved_path": ["stone", 1000],
	"preserver": ["wood", 20000, "stone", 24000, "iron", 2000],
	"quarry_shed": ["wood", 16000, "stone", 8000],
	"residence": ["wood", 60000, "stone", 24000, "cloth", 8000],
	"saltpan": ["wood", 8000, "stone", 16000],
	"stone_wall": ["stone", 3000],
	"weir": ["wood", 30000, "stone", 12000, "rope", 6000],
	"well": ["wood", 10000, "stone", 20000],
	"workbench": ["wood", 12000, "stone", 4000],
	"workshop": ["wood", 35000, "stone", 20000, "iron", 4000],
}
const SOURCE_FURNITURE_BILLS: Dictionary = {
	"bed": ["wood", 2000, "cloth", 1000],
	"decoration": ["wood", 1000, "wax", 250],
	"hearth": ["stone", 6000],
	"interior_door": ["wood", 2000],
	"interior_partition": ["wood", 1000],
	"kitchen_bench": ["wood", 4000, "stone", 4000, "iron", 1000],
	"patient_bed": ["wood", 2000, "cloth", 2000],
	"seat": ["wood", 1000],
	"shelf": ["wood", 2000],
}
const SOURCE_UPGRADE_BILLS: Dictionary = {
	"covered_store": ["wood", 25000, "stone", 20000],
	"hall": ["wood", 20000, "stone", 40000, "cloth", 8000],
	"residence": ["wood", 20000, "stone", 40000, "cloth", 8000],
	"workshop": ["wood", 20000, "iron", 8000],
}


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 1 block against the Construction store's own cold column rules."""
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
	var columns: Construction.Columns = Construction.Columns.new(false)
	_project_columns(record, columns)
	var code: StringName = Construction.columns_refusal(columns)
	if code != Construction.REFUSE_NONE:
		return _refuse(code, "%srefuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


# --- gate 4: compiled owner metadata, pure source preflight, independent SOURCE_* anchors -------

static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Compiled identity/fields, the pure preflight, then this bridge's own independent anchors."""
	var identity: SaveHeader.Refusal = _identity_refusal()
	if not identity.is_ok():
		return identity
	var fields: SaveHeader.Refusal = _field_parity_refusal()
	if not fields.is_ok():
		return fields
	var pure_code: StringName = Construction.column_source_metadata_refusal()
	if pure_code != Construction.REFUSE_NONE:
		return _refuse_metadata("the pure source preflight refused with %s" % String(pure_code))
	var scalars: SaveHeader.Refusal = _scalar_anchor_refusal()
	if not scalars.is_ok():
		return scalars
	var arrays: SaveHeader.Refusal = _array_anchor_refusal()
	if not arrays.is_ok():
		return arrays
	var bijection: SaveHeader.Refusal = _catalog_bijection_refusal()
	if not bijection.is_ok():
		return bijection
	return _bill_anchor_refusal()


static func _identity_refusal() -> SaveHeader.Refusal:
	"""Compiled owner key, version, primaries, child extents, field count and field begin."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY:
		return _refuse_metadata("compiled owner '%s' is not '%s'"
			% [Schema.owner_key(OWNER_INDEX), OWNER_KEY])
	if Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse_metadata("compiled owner version %d is not %d"
			% [Schema.owner_version(OWNER_INDEX), OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT:
		return _refuse_metadata("%d primaries are not %d"
			% [Schema.primary_count(OWNER_INDEX), OWNER_PRIMARY_COUNT])
	if Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT:
		return _refuse_metadata("%d child extents are not %d"
			% [Schema.child_extent_count(OWNER_INDEX), OWNER_CHILD_EXTENT_COUNT])
	if Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse_metadata("%d fields are not %d"
			% [Schema.field_count(OWNER_INDEX), OWNER_FIELD_COUNT])
	if Schema.OWNER_FIELD_BEGIN.size() != Schema.EXPECTED_STORE_COUNT:
		return _refuse_metadata("the compiled field-begin column holds %d rows, not %d"
			% [Schema.OWNER_FIELD_BEGIN.size(), Schema.EXPECTED_STORE_COUNT])
	if int(Schema.OWNER_FIELD_BEGIN[OWNER_INDEX]) != OWNER_FIELD_BEGIN:
		return _refuse_metadata("compiled field begin %d is not %d"
			% [int(Schema.OWNER_FIELD_BEGIN[OWNER_INDEX]), OWNER_FIELD_BEGIN])
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: key, type code and element count, ordinal by ordinal."""
	if FIELD_KEYS.size() != OWNER_FIELD_COUNT or FIELD_TYPES.size() != OWNER_FIELD_COUNT \
			or FIELD_COUNTS.size() != OWNER_FIELD_COUNT:
		return _refuse_metadata("this bridge pins %d/%d/%d field declarations, not %d"
			% [FIELD_KEYS.size(), FIELD_TYPES.size(), FIELD_COUNTS.size(), OWNER_FIELD_COUNT])
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field]):
			return _refuse_metadata("field %d is '%s'; owner 1 declares '%s'"
				% [field, Schema.field_key(OWNER_INDEX, field), String(FIELD_KEYS[field])])
		if Schema.field_type(OWNER_INDEX, field) != int(FIELD_TYPES[field]):
			return _refuse_metadata("field %d has type %d; %d is declared"
				% [field, Schema.field_type(OWNER_INDEX, field), int(FIELD_TYPES[field])])
		if Schema.element_count(OWNER_INDEX, field) != int(FIELD_COUNTS[field]):
			return _refuse_metadata("field %d holds %d values; %d are declared"
				% [field, Schema.element_count(OWNER_INDEX, field), int(FIELD_COUNTS[field])])
	return _accept()


static func _anchor(label: String, actual: int, expected: int) -> SaveHeader.Refusal:
	"""One explicit gate-4 scalar disagreement, in the frozen '<label> is A, not B' wording."""
	return _refuse_metadata("%s is %d, not %d" % [label, actual, expected])


static func _scalar_anchor_refusal() -> SaveHeader.Refusal:
	"""Every pinned scalar, in the frozen group order, against BOTH Construction's live constant
	and its own in-file SOURCE_* mirror, from this bridge's own independent literal. Explicit
	comparisons only: no check table is allocated, so no gate can be lost inside one."""
	var capacity: SaveHeader.Refusal = _capacity_anchor_refusal()
	if not capacity.is_ok():
		return capacity
	var references: SaveHeader.Refusal = _reference_anchor_refusal()
	if not references.is_ok():
		return references
	var purposes: SaveHeader.Refusal = _purpose_anchor_refusal()
	if not purposes.is_ok():
		return purposes
	var phases: SaveHeader.Refusal = _phase_anchor_refusal()
	if not phases.is_ok():
		return phases
	var refunds: SaveHeader.Refusal = _refund_anchor_refusal()
	if not refunds.is_ok():
		return refunds
	var domains: SaveHeader.Refusal = _domain_anchor_refusal()
	if not domains.is_ok():
		return domains
	return _fact_index_anchor_refusal()


static func _capacity_anchor_refusal() -> SaveHeader.Refusal:
	"""Row capacity, the ledger stride, the builder cap and the demolition ratio."""
	if Construction.CONSTRUCTION_CAPACITY != SOURCE_ROW_CAPACITY:
		return _anchor("row capacity", Construction.CONSTRUCTION_CAPACITY, SOURCE_ROW_CAPACITY)
	if Construction.SOURCE_ROW_CAPACITY != SOURCE_ROW_CAPACITY:
		return _anchor("row capacity mirror", Construction.SOURCE_ROW_CAPACITY, SOURCE_ROW_CAPACITY)
	if Construction.Columns.ROW_CAPACITY != SOURCE_ROW_CAPACITY:
		return _anchor("columns row capacity", Construction.Columns.ROW_CAPACITY, SOURCE_ROW_CAPACITY)
	if Construction.MATERIAL_SLOTS_PER_PROJECT != SOURCE_MATERIAL_SLOTS_PER_PROJECT:
		return _anchor("material slots", Construction.MATERIAL_SLOTS_PER_PROJECT,
			SOURCE_MATERIAL_SLOTS_PER_PROJECT)
	if Construction.SOURCE_MATERIAL_SLOTS_PER_PROJECT != SOURCE_MATERIAL_SLOTS_PER_PROJECT:
		return _anchor("material slots mirror", Construction.SOURCE_MATERIAL_SLOTS_PER_PROJECT,
			SOURCE_MATERIAL_SLOTS_PER_PROJECT)
	if Construction.MAX_BUILDERS != SOURCE_MAX_BUILDERS:
		return _anchor("max builders", Construction.MAX_BUILDERS, SOURCE_MAX_BUILDERS)
	if Construction.SOURCE_MAX_BUILDERS != SOURCE_MAX_BUILDERS:
		return _anchor("max builders mirror", Construction.SOURCE_MAX_BUILDERS, SOURCE_MAX_BUILDERS)
	if Construction.DEMOLITION_WORK_NUM != SOURCE_DEMOLITION_WORK_NUM:
		return _anchor("demolition work num", Construction.DEMOLITION_WORK_NUM,
			SOURCE_DEMOLITION_WORK_NUM)
	if Construction.SOURCE_DEMOLITION_WORK_NUM != SOURCE_DEMOLITION_WORK_NUM:
		return _anchor("demolition work num mirror", Construction.SOURCE_DEMOLITION_WORK_NUM,
			SOURCE_DEMOLITION_WORK_NUM)
	if Construction.DEMOLITION_WORK_DEN != SOURCE_DEMOLITION_WORK_DEN:
		return _anchor("demolition work den", Construction.DEMOLITION_WORK_DEN,
			SOURCE_DEMOLITION_WORK_DEN)
	if Construction.SOURCE_DEMOLITION_WORK_DEN != SOURCE_DEMOLITION_WORK_DEN:
		return _anchor("demolition work den mirror", Construction.SOURCE_DEMOLITION_WORK_DEN,
			SOURCE_DEMOLITION_WORK_DEN)
	return _accept()


static func _reference_anchor_refusal() -> SaveHeader.Refusal:
	"""The i32 boundary, the null pair and the Directory capacity, live, mirrored and gate-side."""
	if Construction.INT32_MAX != SOURCE_INT32_MAX:
		return _anchor("int32 max", Construction.INT32_MAX, SOURCE_INT32_MAX)
	if Construction.SOURCE_INT32_MAX != SOURCE_INT32_MAX:
		return _anchor("int32 max mirror", Construction.SOURCE_INT32_MAX, SOURCE_INT32_MAX)
	if Construction.NULL_REF.x != SOURCE_NULL_SLOT:
		return _anchor("null slot", Construction.NULL_REF.x, SOURCE_NULL_SLOT)
	if Construction.SOURCE_NULL_SLOT != SOURCE_NULL_SLOT:
		return _anchor("null slot mirror", Construction.SOURCE_NULL_SLOT, SOURCE_NULL_SLOT)
	if Construction.NULL_REF.y != SOURCE_NULL_GENERATION:
		return _anchor("null generation", Construction.NULL_REF.y, SOURCE_NULL_GENERATION)
	if Construction.SOURCE_NULL_GENERATION != SOURCE_NULL_GENERATION:
		return _anchor("null generation mirror", Construction.SOURCE_NULL_GENERATION,
			SOURCE_NULL_GENERATION)
	if Construction.EntityDirectory.DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _anchor("directory capacity", Construction.EntityDirectory.DIRECTORY_CAPACITY,
			SOURCE_DIRECTORY_CAPACITY)
	if Construction.SOURCE_DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _anchor("directory capacity mirror", Construction.SOURCE_DIRECTORY_CAPACITY,
			SOURCE_DIRECTORY_CAPACITY)
	if Construction.COLUMN_DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _anchor("directory capacity gate", Construction.COLUMN_DIRECTORY_CAPACITY,
			SOURCE_DIRECTORY_CAPACITY)
	return _accept()


static func _purpose_anchor_refusal() -> SaveHeader.Refusal:
	"""The four purpose ordinals and their count, live and mirrored."""
	if Construction.PURPOSE_BUILD != SOURCE_PURPOSE_BUILD:
		return _anchor("purpose build", Construction.PURPOSE_BUILD, SOURCE_PURPOSE_BUILD)
	if Construction.SOURCE_PURPOSE_BUILD != SOURCE_PURPOSE_BUILD:
		return _anchor("purpose build mirror", Construction.SOURCE_PURPOSE_BUILD,
			SOURCE_PURPOSE_BUILD)
	if Construction.PURPOSE_UPGRADE != SOURCE_PURPOSE_UPGRADE:
		return _anchor("purpose upgrade", Construction.PURPOSE_UPGRADE, SOURCE_PURPOSE_UPGRADE)
	if Construction.SOURCE_PURPOSE_UPGRADE != SOURCE_PURPOSE_UPGRADE:
		return _anchor("purpose upgrade mirror", Construction.SOURCE_PURPOSE_UPGRADE,
			SOURCE_PURPOSE_UPGRADE)
	if Construction.PURPOSE_FURNITURE != SOURCE_PURPOSE_FURNITURE:
		return _anchor("purpose furniture", Construction.PURPOSE_FURNITURE,
			SOURCE_PURPOSE_FURNITURE)
	if Construction.SOURCE_PURPOSE_FURNITURE != SOURCE_PURPOSE_FURNITURE:
		return _anchor("purpose furniture mirror", Construction.SOURCE_PURPOSE_FURNITURE,
			SOURCE_PURPOSE_FURNITURE)
	if Construction.PURPOSE_DEMOLISH != SOURCE_PURPOSE_DEMOLISH:
		return _anchor("purpose demolish", Construction.PURPOSE_DEMOLISH,
			SOURCE_PURPOSE_DEMOLISH)
	if Construction.SOURCE_PURPOSE_DEMOLISH != SOURCE_PURPOSE_DEMOLISH:
		return _anchor("purpose demolish mirror", Construction.SOURCE_PURPOSE_DEMOLISH,
			SOURCE_PURPOSE_DEMOLISH)
	if Construction.PURPOSE_COUNT != SOURCE_PURPOSE_COUNT:
		return _anchor("purpose count", Construction.PURPOSE_COUNT, SOURCE_PURPOSE_COUNT)
	if Construction.SOURCE_PURPOSE_COUNT != SOURCE_PURPOSE_COUNT:
		return _anchor("purpose count mirror", Construction.SOURCE_PURPOSE_COUNT,
			SOURCE_PURPOSE_COUNT)
	return _accept()


static func _phase_anchor_refusal() -> SaveHeader.Refusal:
	"""The awaiting, ready and working phase ordinals, live and mirrored."""
	if Construction.PHASE_AWAITING_MATERIALS != SOURCE_PHASE_AWAITING_MATERIALS:
		return _anchor("phase awaiting", Construction.PHASE_AWAITING_MATERIALS,
			SOURCE_PHASE_AWAITING_MATERIALS)
	if Construction.SOURCE_PHASE_AWAITING_MATERIALS != SOURCE_PHASE_AWAITING_MATERIALS:
		return _anchor("phase awaiting mirror", Construction.SOURCE_PHASE_AWAITING_MATERIALS,
			SOURCE_PHASE_AWAITING_MATERIALS)
	if Construction.PHASE_READY != SOURCE_PHASE_READY:
		return _anchor("phase ready", Construction.PHASE_READY, SOURCE_PHASE_READY)
	if Construction.SOURCE_PHASE_READY != SOURCE_PHASE_READY:
		return _anchor("phase ready mirror", Construction.SOURCE_PHASE_READY,
			SOURCE_PHASE_READY)
	if Construction.PHASE_WORKING != SOURCE_PHASE_WORKING:
		return _anchor("phase working", Construction.PHASE_WORKING, SOURCE_PHASE_WORKING)
	if Construction.SOURCE_PHASE_WORKING != SOURCE_PHASE_WORKING:
		return _anchor("phase working mirror", Construction.SOURCE_PHASE_WORKING,
			SOURCE_PHASE_WORKING)
	return _phase_tail_anchor_refusal()


static func _phase_tail_anchor_refusal() -> SaveHeader.Refusal:
	"""The work-done and refunding ordinals and the phase count, live and mirrored."""
	if Construction.PHASE_WORK_DONE != SOURCE_PHASE_WORK_DONE:
		return _anchor("phase work done", Construction.PHASE_WORK_DONE,
			SOURCE_PHASE_WORK_DONE)
	if Construction.SOURCE_PHASE_WORK_DONE != SOURCE_PHASE_WORK_DONE:
		return _anchor("phase work done mirror", Construction.SOURCE_PHASE_WORK_DONE,
			SOURCE_PHASE_WORK_DONE)
	if Construction.PHASE_REFUNDING != SOURCE_PHASE_REFUNDING:
		return _anchor("phase refunding", Construction.PHASE_REFUNDING,
			SOURCE_PHASE_REFUNDING)
	if Construction.SOURCE_PHASE_REFUNDING != SOURCE_PHASE_REFUNDING:
		return _anchor("phase refunding mirror", Construction.SOURCE_PHASE_REFUNDING,
			SOURCE_PHASE_REFUNDING)
	if Construction.PHASE_COUNT != SOURCE_PHASE_COUNT:
		return _anchor("phase count", Construction.PHASE_COUNT, SOURCE_PHASE_COUNT)
	if Construction.SOURCE_PHASE_COUNT != SOURCE_PHASE_COUNT:
		return _anchor("phase count mirror", Construction.SOURCE_PHASE_COUNT,
			SOURCE_PHASE_COUNT)
	return _accept()


static func _refund_anchor_refusal() -> SaveHeader.Refusal:
	"""The three refund-policy ordinals and their count, live and mirrored."""
	if Construction.REFUND_FULL != SOURCE_REFUND_FULL:
		return _anchor("refund full", Construction.REFUND_FULL, SOURCE_REFUND_FULL)
	if Construction.SOURCE_REFUND_FULL != SOURCE_REFUND_FULL:
		return _anchor("refund full mirror", Construction.SOURCE_REFUND_FULL, SOURCE_REFUND_FULL)
	if Construction.REFUND_PARTIAL != SOURCE_REFUND_PARTIAL:
		return _anchor("refund partial", Construction.REFUND_PARTIAL, SOURCE_REFUND_PARTIAL)
	if Construction.SOURCE_REFUND_PARTIAL != SOURCE_REFUND_PARTIAL:
		return _anchor("refund partial mirror", Construction.SOURCE_REFUND_PARTIAL,
			SOURCE_REFUND_PARTIAL)
	if Construction.REFUND_DEMOLITION != SOURCE_REFUND_DEMOLITION:
		return _anchor("refund demolition", Construction.REFUND_DEMOLITION,
			SOURCE_REFUND_DEMOLITION)
	if Construction.SOURCE_REFUND_DEMOLITION != SOURCE_REFUND_DEMOLITION:
		return _anchor("refund demolition mirror", Construction.SOURCE_REFUND_DEMOLITION,
			SOURCE_REFUND_DEMOLITION)
	if Construction.REFUND_POLICY_COUNT != SOURCE_REFUND_POLICY_COUNT:
		return _anchor("refund policy count", Construction.REFUND_POLICY_COUNT,
			SOURCE_REFUND_POLICY_COUNT)
	if Construction.SOURCE_REFUND_POLICY_COUNT != SOURCE_REFUND_POLICY_COUNT:
		return _anchor("refund policy count mirror", Construction.SOURCE_REFUND_POLICY_COUNT,
			SOURCE_REFUND_POLICY_COUNT)
	return _accept()


static func _domain_anchor_refusal() -> SaveHeader.Refusal:
	"""Both domain counts, the material key count and the tier-two count, live and mirrored."""
	if Construction.BUILDING_KINDS != SOURCE_BUILDING_KIND_COUNT:
		return _anchor("building kind count", Construction.BUILDING_KINDS,
			SOURCE_BUILDING_KIND_COUNT)
	if Construction.SOURCE_BUILDING_KIND_COUNT != SOURCE_BUILDING_KIND_COUNT:
		return _anchor("building kind count mirror", Construction.SOURCE_BUILDING_KIND_COUNT,
			SOURCE_BUILDING_KIND_COUNT)
	if Construction.FURNITURE_KINDS != SOURCE_FURNITURE_KIND_COUNT:
		return _anchor("furniture kind count", Construction.FURNITURE_KINDS,
			SOURCE_FURNITURE_KIND_COUNT)
	if Construction.SOURCE_FURNITURE_KIND_COUNT != SOURCE_FURNITURE_KIND_COUNT:
		return _anchor("furniture kind count mirror", Construction.SOURCE_FURNITURE_KIND_COUNT,
			SOURCE_FURNITURE_KIND_COUNT)
	if Construction.MATERIAL_KEY_COUNT != SOURCE_MATERIAL_KEY_COUNT:
		return _anchor("material key count", Construction.MATERIAL_KEY_COUNT,
			SOURCE_MATERIAL_KEY_COUNT)
	if Construction.SOURCE_MATERIAL_KEY_COUNT != SOURCE_MATERIAL_KEY_COUNT:
		return _anchor("material key count mirror", Construction.SOURCE_MATERIAL_KEY_COUNT,
			SOURCE_MATERIAL_KEY_COUNT)
	if Construction.BuildingDefinitions.TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT:
		return _anchor("tier two count", Construction.BuildingDefinitions.TIER_TWO_KEYS.size(),
			SOURCE_TIER_TWO_COUNT)
	if Construction.SOURCE_TIER_TWO_COUNT != SOURCE_TIER_TWO_COUNT:
		return _anchor("tier two count mirror", Construction.SOURCE_TIER_TWO_COUNT,
			SOURCE_TIER_TWO_COUNT)
	return _accept()


static func _fact_index_anchor_refusal() -> SaveHeader.Refusal:
	"""BuildingDefinition fact-row indexes and row width, live and mirrored (finding B2).

	Construction's own preflight compares its fact rows against ITS OWN in-file mirror of these
	indexes, so a coordinated source-and-mirror rearrangement survives it. These independent
	literals do not: they are compared against both sides and derived from neither.
	"""
	if Construction.BuildingDefinitions.B_WORK_MWU != SOURCE_B_WORK_MWU:
		return _anchor("building work index", Construction.BuildingDefinitions.B_WORK_MWU,
			SOURCE_B_WORK_MWU)
	if Construction.SOURCE_B_WORK_MWU != SOURCE_B_WORK_MWU:
		return _anchor("building work index mirror", Construction.SOURCE_B_WORK_MWU,
			SOURCE_B_WORK_MWU)
	if Construction.BuildingDefinitions.B_MAX_BUILDERS != SOURCE_B_MAX_BUILDERS:
		return _anchor("building max builders index",
			Construction.BuildingDefinitions.B_MAX_BUILDERS, SOURCE_B_MAX_BUILDERS)
	if Construction.SOURCE_B_MAX_BUILDERS != SOURCE_B_MAX_BUILDERS:
		return _anchor("building max builders index mirror", Construction.SOURCE_B_MAX_BUILDERS,
			SOURCE_B_MAX_BUILDERS)
	if Construction.BuildingDefinitions.B_FIELD_COUNT != SOURCE_B_FIELD_COUNT:
		return _anchor("building field count", Construction.BuildingDefinitions.B_FIELD_COUNT,
			SOURCE_B_FIELD_COUNT)
	if Construction.SOURCE_B_FIELD_COUNT != SOURCE_B_FIELD_COUNT:
		return _anchor("building field count mirror", Construction.SOURCE_B_FIELD_COUNT,
			SOURCE_B_FIELD_COUNT)
	return _furniture_index_anchor_refusal()


static func _furniture_index_anchor_refusal() -> SaveHeader.Refusal:
	"""FurnitureDefinition fact-row index and row width, live and mirrored (finding B2)."""
	if Construction.BuildingDefinitions.F_WORK_MWU != SOURCE_F_WORK_MWU:
		return _anchor("furniture work index", Construction.BuildingDefinitions.F_WORK_MWU,
			SOURCE_F_WORK_MWU)
	if Construction.SOURCE_F_WORK_MWU != SOURCE_F_WORK_MWU:
		return _anchor("furniture work index mirror", Construction.SOURCE_F_WORK_MWU,
			SOURCE_F_WORK_MWU)
	if Construction.BuildingDefinitions.F_FIELD_COUNT != SOURCE_F_FIELD_COUNT:
		return _anchor("furniture field count", Construction.BuildingDefinitions.F_FIELD_COUNT,
			SOURCE_F_FIELD_COUNT)
	if Construction.SOURCE_F_FIELD_COUNT != SOURCE_F_FIELD_COUNT:
		return _anchor("furniture field count mirror", Construction.SOURCE_F_FIELD_COUNT,
			SOURCE_F_FIELD_COUNT)
	return _accept()


static func _array_anchor_refusal() -> SaveHeader.Refusal:
	"""Material keys, tier two keys, then the ten frozen gate-array mirrors."""
	if SOURCE_MATERIAL_KEYS.size() != SOURCE_MATERIAL_KEY_COUNT \
			or Construction.MATERIAL_KEYS.size() != SOURCE_MATERIAL_KEY_COUNT \
			or Construction.SOURCE_MATERIAL_KEYS.size() != SOURCE_MATERIAL_KEY_COUNT:
		return _refuse_metadata("material key arrays do not all hold %d entries"
			% SOURCE_MATERIAL_KEY_COUNT)
	for i: int in SOURCE_MATERIAL_KEY_COUNT:
		if StringName(SOURCE_MATERIAL_KEYS[i]) != Construction.MATERIAL_KEYS[i] \
				or SOURCE_MATERIAL_KEYS[i] != Construction.SOURCE_MATERIAL_KEYS[i]:
			return _refuse_metadata("material key %d is not '%s'" % [i, SOURCE_MATERIAL_KEYS[i]])
	if SOURCE_TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT \
			or Construction.BuildingDefinitions.TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT \
			or Construction.SOURCE_TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_COUNT:
		return _refuse_metadata("tier two key arrays do not all hold %d entries" % SOURCE_TIER_TWO_COUNT)
	for i: int in SOURCE_TIER_TWO_COUNT:
		if SOURCE_TIER_TWO_KEYS[i] != Construction.BuildingDefinitions.TIER_TWO_KEYS[i] \
				or SOURCE_TIER_TWO_KEYS[i] != Construction.SOURCE_TIER_TWO_KEYS[i]:
			return _refuse_metadata("tier two key %d is not '%s'" % [i, SOURCE_TIER_TWO_KEYS[i]])
	return _column_array_refusal()


static func _array_anchor(label: String, frozen: Array, live: Array) -> SaveHeader.Refusal:
	"""One frozen gate array against its live COLUMN_* mirror: size first, then entry by entry.

	The single typed comparator the ten explicit anchor calls below reuse. Its two messages are
	the exact wordings the dynamic check table used, so no refusal string, comparison or
	priority changes: a size disagreement first, then the lowest disagreeing index.
	"""
	if live.size() != frozen.size():
		return _refuse_metadata("%s holds %d entries, not %d" % [label, live.size(), frozen.size()])
	for i: int in frozen.size():
		if live[i] != frozen[i]:
			return _refuse_metadata("%s entry %d does not match the frozen source" % [label, i])
	return _accept()


static func _building_array_refusal() -> SaveHeader.Refusal:
	"""Anchors 1-4: building keys, work, max workers and bill pair counts, in that order."""
	var keys: SaveHeader.Refusal = _array_anchor("building keys",
		SOURCE_BUILDING_KEYS, Construction.COLUMN_BUILDING_KEYS)
	if not keys.is_ok():
		return keys
	var work: SaveHeader.Refusal = _array_anchor("building work",
		SOURCE_BUILDING_WORK_MWU, Construction.COLUMN_BUILDING_WORK_MWU)
	if not work.is_ok():
		return work
	var workers: SaveHeader.Refusal = _array_anchor("building max workers",
		SOURCE_BUILDING_MAX_WORKERS, Construction.COLUMN_BUILDING_MAX_WORKERS)
	if not workers.is_ok():
		return workers
	return _array_anchor("building bill pair counts",
		SOURCE_BUILDING_BILL_PAIR_COUNTS, Construction.COLUMN_BUILDING_BILL_PAIR_COUNTS)


static func _furniture_array_refusal() -> SaveHeader.Refusal:
	"""Anchors 5-7: furniture keys, work and bill pair counts, in that order."""
	var keys: SaveHeader.Refusal = _array_anchor("furniture keys",
		SOURCE_FURNITURE_KEYS, Construction.COLUMN_FURNITURE_KEYS)
	if not keys.is_ok():
		return keys
	var work: SaveHeader.Refusal = _array_anchor("furniture work",
		SOURCE_FURNITURE_WORK_MWU, Construction.COLUMN_FURNITURE_WORK_MWU)
	if not work.is_ok():
		return work
	return _array_anchor("furniture bill pair counts",
		SOURCE_FURNITURE_BILL_PAIR_COUNTS, Construction.COLUMN_FURNITURE_BILL_PAIR_COUNTS)


static func _upgrade_array_refusal() -> SaveHeader.Refusal:
	"""Anchors 8-10: upgrade ids, work and bill pair counts, in that order."""
	var ids: SaveHeader.Refusal = _array_anchor("upgrade ids",
		SOURCE_UPGRADE_IDS, Construction.COLUMN_UPGRADE_IDS)
	if not ids.is_ok():
		return ids
	var work: SaveHeader.Refusal = _array_anchor("upgrade work",
		SOURCE_UPGRADE_WORK_MWU, Construction.COLUMN_UPGRADE_WORK_MWU)
	if not work.is_ok():
		return work
	return _array_anchor("upgrade bill pair counts",
		SOURCE_UPGRADE_BILL_PAIR_COUNTS, Construction.COLUMN_UPGRADE_BILL_PAIR_COUNTS)


static func _column_array_refusal() -> SaveHeader.Refusal:
	"""The ten frozen COLUMN_* arrays, in the frozen order, as explicit grouped anchor calls.

	No check table is allocated, so no anchor can be lost inside one: every array is compared by
	an explicit call, in the same order, with the same label, comparison and refusal priority as
	the table it replaces.
	"""
	var buildings: SaveHeader.Refusal = _building_array_refusal()
	if not buildings.is_ok():
		return buildings
	var furniture: SaveHeader.Refusal = _furniture_array_refusal()
	if not furniture.is_ok():
		return furniture
	return _upgrade_array_refusal()


static func _catalog_bijection_refusal() -> SaveHeader.Refusal:
	"""The canonical Catalog key-to-ordinal bijections: 30 building, 9 furniture, 4 upgrade ids."""
	if Construction.Catalog.BUILDING_DEFINITION.size() != SOURCE_BUILDING_KIND_COUNT:
		return _refuse_metadata("BUILDING_DEFINITION holds %d keys, not %d"
			% [Construction.Catalog.BUILDING_DEFINITION.size(), SOURCE_BUILDING_KIND_COUNT])
	for id: int in SOURCE_BUILDING_KIND_COUNT:
		var key: String = SOURCE_BUILDING_KEYS[id]
		if not Construction.Catalog.BUILDING_DEFINITION.has(key) \
				or typeof(Construction.Catalog.BUILDING_DEFINITION[key]) != TYPE_INT \
				or int(Construction.Catalog.BUILDING_DEFINITION[key]) != id:
			return _refuse_metadata("'%s' is not building catalog id %d" % [key, id])
	if Construction.Catalog.FURNITURE_DEFINITION.size() != SOURCE_FURNITURE_KIND_COUNT:
		return _refuse_metadata("FURNITURE_DEFINITION holds %d keys, not %d"
			% [Construction.Catalog.FURNITURE_DEFINITION.size(), SOURCE_FURNITURE_KIND_COUNT])
	for id: int in SOURCE_FURNITURE_KIND_COUNT:
		var key: String = SOURCE_FURNITURE_KEYS[id]
		if not Construction.Catalog.FURNITURE_DEFINITION.has(key) \
				or typeof(Construction.Catalog.FURNITURE_DEFINITION[key]) != TYPE_INT \
				or int(Construction.Catalog.FURNITURE_DEFINITION[key]) != id:
			return _refuse_metadata("'%s' is not furniture catalog id %d" % [key, id])
	for i: int in SOURCE_TIER_TWO_COUNT:
		var upgrade_key: String = SOURCE_TIER_TWO_KEYS[i]
		if not Construction.Catalog.BUILDING_DEFINITION.has(upgrade_key) \
				or int(Construction.Catalog.BUILDING_DEFINITION[upgrade_key]) != SOURCE_UPGRADE_IDS[i]:
			return _refuse_metadata("upgrade key '%s' is not building id %d"
				% [upgrade_key, SOURCE_UPGRADE_IDS[i]])
	return _accept()


static func _bill_matches(frozen: Array, live: Variant) -> bool:
	"""Exact key TYPE_STRING and quantity TYPE_INT/value, in order, against one frozen bill."""
	if typeof(live) != TYPE_ARRAY:
		return false
	var live_arr: Array = live
	if live_arr.size() != frozen.size():
		return false
	for i: int in frozen.size():
		if i % 2 == 0:
			if typeof(live_arr[i]) != TYPE_STRING or String(live_arr[i]) != String(frozen[i]):
				return false
		else:
			if typeof(live_arr[i]) != TYPE_INT or int(live_arr[i]) != int(frozen[i]):
				return false
	return true


static func _bill_dictionary_refusal(label: String, frozen: Dictionary,
		live: Dictionary) -> SaveHeader.Refusal:
	"""Exact size, membership and per-bill content, key by key, against one frozen dictionary."""
	if live.size() != frozen.size():
		return _refuse_metadata("%s holds %d bills, not %d" % [label, live.size(), frozen.size()])
	for key: String in frozen.keys():
		if not live.has(key):
			return _refuse_metadata("%s is missing bill '%s'" % [label, key])
		if not _bill_matches(frozen[key], live[key]):
			return _refuse_metadata("%s bill '%s' does not match the frozen contents" % [label, key])
	return _accept()


static func _bill_anchor_refusal() -> SaveHeader.Refusal:
	"""Build, furniture and upgrade bills, in that order, against Construction's own dictionaries."""
	var build_check: SaveHeader.Refusal = _bill_dictionary_refusal(
		"build bills", SOURCE_BUILD_BILLS, Construction.BUILD_MATERIALS)
	if not build_check.is_ok():
		return build_check
	var furniture_check: SaveHeader.Refusal = _bill_dictionary_refusal(
		"furniture bills", SOURCE_FURNITURE_BILLS, Construction.FURNITURE_MATERIALS)
	if not furniture_check.is_ok():
		return furniture_check
	return _bill_dictionary_refusal(
		"upgrade bills", SOURCE_UPGRADE_BILLS, Construction.UPGRADE_MATERIALS)


# --- gate 6: the sole projection helper -----------------------------------------------------------

static func _project_columns(record: Section.FramedOwner, out: Construction.Columns) -> void:
	"""Ordinals 0..15: the borrowed 82944-row image, every column assigned explicitly.

	`out` arrives from `Construction.Columns.new(false)`, so all 16 members are empty typed
	arrays until this function binds the record's own buffers. No duplicate, resize, fill or new
	buffer happens here, and no live Construction/Buildings/Definitions/Directory is constructed.
	Callable directly by tests with a shape-valid framed record and a caller-owned empty view.
	"""
	out.present = record.u8_column(FIELD_PRESENT)
	out.material_container_slot = record.i32_column(FIELD_MATERIAL_CONTAINER_SLOT)
	out.material_container_generation = record.i32_column(FIELD_MATERIAL_CONTAINER_GENERATION)
	out.assigned_count = record.i32_column(FIELD_ASSIGNED_COUNT)
	out.max_workers = record.i32_column(FIELD_MAX_WORKERS)
	out.refund_policy = record.i32_column(FIELD_REFUND_POLICY)
	out.remaining_mwu = record.i64_column(FIELD_REMAINING_MWU)
	out.paused = record.u8_column(FIELD_PAUSED)
	out.work_begun = record.u8_column(FIELD_WORK_BEGUN)
	out.ref_slot = record.i32_column(FIELD_REF_SLOT)
	out.ref_generation = record.i32_column(FIELD_REF_GENERATION)
	out.subject_slot = record.i32_column(FIELD_SUBJECT_SLOT)
	out.subject_generation = record.i32_column(FIELD_SUBJECT_GENERATION)
	out.purpose = record.i32_column(FIELD_PURPOSE)
	out.type_id = record.i32_column(FIELD_TYPE_ID)
	out.phase = record.i32_column(FIELD_PHASE)


# --- shared result helpers ------------------------------------------------------------------------

static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Construction column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _refuse_metadata(detail: String) -> SaveHeader.Refusal:
	"""Build a gate-4 refusal with the frozen 'Construction owner1 metadata:' prefix."""
	return SaveHeader.Refusal.new(Section.REFUSE_METADATA, "%s %s" % [METADATA_DETAIL_PREFIX, detail])


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
