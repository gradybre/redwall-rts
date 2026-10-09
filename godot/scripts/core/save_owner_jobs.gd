extends RefCounted
## Owner `jobs` joint section 4 + section 5 capture/apply bridge (ADR 1222 build step 3).
##
## Jobs is the one owner whose live bulk pair already spans BOTH sections:
## `Jobs.copy_columns_into()` / `Jobs.restore_columns()` move the thirty-eight section-4 columns
## and the four section-5 child-arena columns (coordinator ref, member head and next) together, and
## the restore validates the whole image -- including Directory resolution and both directions of
## the worker binding -- before its first write. This bridge only projects between that image and
## the two wire records, so a half-applied pair can never exist:
##
##   * `capture_into(store, record, block)` copies the live image once and writes its §4 half
##     into the section-4 FramedOwner (owner 7) and its §5 half into the section-5 Block.
##   * `apply(record, block, store)` checks both records' shapes, projects them into one
##     `Jobs.Columns` and calls `restore_columns()`, which writes nothing on refusal. A refusal
##     carries the store's exact `last_column_refusal()` code.
##
## The ordinals are Jobs' own `SECTION4_COLUMN_KEYS` / `SECTION5_COLUMN_KEYS`, which
## test_jobs_columns.gd proves equal to the canonical registry. Nothing here touches a clock,
## barrier, signal, filesystem or reflection API, and no per-row object is built.
##
## MEMORY. One transient `Jobs.Columns` image per call plus the two records, charged to the ADR
## 1222 save/load working set; never resident between ticks.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Jobs := preload("res://scripts/core/jobs.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const ChildSchema := preload("res://scripts/core/save_child_arenas_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner indexes this bridge accepts.
const OWNER_INDEX: int = 7
const OWNER_KEY: String = "jobs"
const CHILD_OWNER_INDEX: int = 3

## A capture or apply called without a live store.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"
## The section-5 block is missing, belongs to another owner or is misshaped.
const REFUSE_CHILD_SHAPE: StringName = &"SAVE_S5_ELEMENT_COUNT"

## Section 5 ordinals, in Jobs' SECTION5_COLUMN_KEYS order.
const CHILD_COORDINATOR_SLOT: int = 0
const CHILD_COORDINATOR_GENERATION: int = 1
const CHILD_MEMBER_HEAD: int = 2
const CHILD_MEMBER_NEXT: int = 3


static func _accept() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func target_refusal(record: Section.FramedOwner,
		block: ChildSection.Block) -> SaveHeader.Refusal:
	"""Both records present, owned by jobs and exactly shaped; the schema guard first."""
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	if record == null or record.owner != OWNER_INDEX or Schema.owner_key(OWNER_INDEX) != OWNER_KEY:
		return _refuse(Section.REFUSE_OWNER, "a section 4 '%s' record (owner %d) is required"
			% [OWNER_KEY, OWNER_INDEX])
	var shape: SaveHeader.Refusal = Section.owner_shape_refusal(record)
	if not shape.is_ok():
		return shape
	if block == null or block.owner != CHILD_OWNER_INDEX \
			or ChildSchema.OWNER_KEYS[CHILD_OWNER_INDEX] != OWNER_KEY:
		return _refuse(REFUSE_CHILD_SHAPE, "a section 5 '%s' block (owner %d) is required"
			% [OWNER_KEY, CHILD_OWNER_INDEX])
	var detail: String = block.shape_detail()
	if detail != "":
		return _refuse(REFUSE_CHILD_SHAPE, detail)
	return _accept()


static func capture_into(store: Jobs, record: Section.FramedOwner,
		block: ChildSection.Block) -> SaveHeader.Refusal:
	"""Capture the live forty-two-column image into both records (unspecified on refusal)."""
	var target: SaveHeader.Refusal = target_refusal(record, block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Jobs store was supplied")
	var columns: Jobs.Columns = Jobs.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(), "Jobs capture refused with %s"
			% String(store.last_column_refusal()))
	if not (_write_job_fields(columns, record) and _write_agent_fields(columns, record)):
		return _refuse(Section.REFUSE_SHAPE, "Jobs capture could not write a section 4 column")
	return _write_child_fields(columns, block)


static func apply(record: Section.FramedOwner, block: ChildSection.Block,
		store: Jobs) -> SaveHeader.Refusal:
	"""Install both halves through one `restore_columns()` call. Refusal writes nothing."""
	var target: SaveHeader.Refusal = target_refusal(record, block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Jobs store was supplied")
	var columns: Jobs.Columns = Jobs.Columns.new()
	_read_job_fields(record, columns)
	_read_agent_fields(record, columns)
	_read_child_fields(block, columns)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(), "Jobs restore refused with %s"
			% String(store.last_column_refusal()))
	return _accept()


static func _write_job_fields(c: Jobs.Columns, r: Section.FramedOwner) -> bool:
	"""Section 4 ordinals 0..24: both presence bytes and the Job columns."""
	return (r.set_u8(0, c.job_present) and r.set_u8(1, c.agent_present)
		and r.set_i32(2, c.kind) and r.set_i32(3, c.requester_slot)
		and r.set_i32(4, c.requester_generation) and r.set_i32(5, c.destination_slot)
		and r.set_i32(6, c.destination_generation) and r.set_i32(7, c.source_slot)
		and r.set_i32(8, c.source_generation) and r.set_i32(9, c.priority)
		and r.set_i32(10, c.required_skill) and r.set_i32(11, c.state)
		and r.set_i32(12, c.worker_slot) and r.set_i32(13, c.worker_generation)
		and r.set_i64(14, c.remaining_mwu) and r.set_i64(15, c.created_tick)
		and r.set_i32(16, c.job_ref_slot) and r.set_i32(17, c.job_ref_generation)
		and r.set_u8(18, c.urgency) and r.set_u8(19, c.dangerous)
		and r.set_u8(20, c.station_gate) and r.set_u8(21, c.tool_gate)
		and r.set_u8(22, c.unlock_gate) and r.set_u8(23, c.inputs_gate)
		and r.set_u8(24, c.is_coordinator))


static func _write_agent_fields(c: Jobs.Columns, r: Section.FramedOwner) -> bool:
	"""Section 4 ordinals 25..37: the JobAgent columns, the scan cursor and the buckets."""
	return (r.set_i32(25, c.agent_job_slot) and r.set_i32(26, c.agent_job_generation)
		and r.set_i32(27, c.agent_phase) and r.set_i32(28, c.agent_target_slot)
		and r.set_i32(29, c.agent_target_generation) and r.set_i32(30, c.agent_path_id)
		and r.set_i32(31, c.agent_path_cursor) and r.set_i64(32, c.agent_lease_expiry)
		and r.set_i64(33, c.agent_blocked_tick) and r.set_i64(34, c.agent_manual_until)
		and r.set_u8(35, c.agent_hazard_locked) and r.set_i32(36, c.job_scan_cursor)
		and r.set_u8(37, c.continuation_bucket))


static func _write_child_fields(c: Jobs.Columns, b: ChildSection.Block) -> SaveHeader.Refusal:
	"""The four section 5 columns, each through the Block's checked setter."""
	for refusal: SaveHeader.Refusal in [
			b.set_i32_column(CHILD_COORDINATOR_SLOT, c.coordinator_slot),
			b.set_i32_column(CHILD_COORDINATOR_GENERATION, c.coordinator_generation),
			b.set_i32_column(CHILD_MEMBER_HEAD, c.member_head),
			b.set_i32_column(CHILD_MEMBER_NEXT, c.member_next)]:
		if not refusal.is_ok():
			return refusal
	return _accept()


static func _read_job_fields(r: Section.FramedOwner, c: Jobs.Columns) -> void:
	"""Project section 4 ordinals 0..24 by assignment; `restore_columns()` copies them."""
	c.job_present = r.u8_column(0)
	c.agent_present = r.u8_column(1)
	c.kind = r.i32_column(2)
	c.requester_slot = r.i32_column(3)
	c.requester_generation = r.i32_column(4)
	c.destination_slot = r.i32_column(5)
	c.destination_generation = r.i32_column(6)
	c.source_slot = r.i32_column(7)
	c.source_generation = r.i32_column(8)
	c.priority = r.i32_column(9)
	c.required_skill = r.i32_column(10)
	c.state = r.i32_column(11)
	c.worker_slot = r.i32_column(12)
	c.worker_generation = r.i32_column(13)
	c.remaining_mwu = r.i64_column(14)
	c.created_tick = r.i64_column(15)
	c.job_ref_slot = r.i32_column(16)
	c.job_ref_generation = r.i32_column(17)
	c.urgency = r.u8_column(18)
	c.dangerous = r.u8_column(19)
	c.station_gate = r.u8_column(20)
	c.tool_gate = r.u8_column(21)
	c.unlock_gate = r.u8_column(22)
	c.inputs_gate = r.u8_column(23)
	c.is_coordinator = r.u8_column(24)


static func _read_agent_fields(r: Section.FramedOwner, c: Jobs.Columns) -> void:
	"""Project section 4 ordinals 25..37 by assignment."""
	c.agent_job_slot = r.i32_column(25)
	c.agent_job_generation = r.i32_column(26)
	c.agent_phase = r.i32_column(27)
	c.agent_target_slot = r.i32_column(28)
	c.agent_target_generation = r.i32_column(29)
	c.agent_path_id = r.i32_column(30)
	c.agent_path_cursor = r.i32_column(31)
	c.agent_lease_expiry = r.i64_column(32)
	c.agent_blocked_tick = r.i64_column(33)
	c.agent_manual_until = r.i64_column(34)
	c.agent_hazard_locked = r.u8_column(35)
	c.job_scan_cursor = r.i32_column(36)
	c.continuation_bucket = r.u8_column(37)


static func _read_child_fields(b: ChildSection.Block, c: Jobs.Columns) -> void:
	"""Decode the four section 5 columns; each getter returns a fresh array."""
	c.coordinator_slot = b.i32_column(CHILD_COORDINATOR_SLOT)
	c.coordinator_generation = b.i32_column(CHILD_COORDINATOR_GENERATION)
	c.member_head = b.i32_column(CHILD_MEMBER_HEAD)
	c.member_next = b.i32_column(CHILD_MEMBER_NEXT)
