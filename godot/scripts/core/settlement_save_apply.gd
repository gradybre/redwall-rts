extends RefCounted
## Apply a decoded, verified save into a cleared settlement (ADR 1222 build step 9, load step 7).
##
## `apply_all(world, staged, header)` runs under the caller's open load (`GameManager.begin_load()`
## raised the barrier) and installs the sections in dependency order:
##   section 3 with section 1's cursor; section 1's world runtime with section 10 (and the clock);
##   section 1's seven ordinary owners; section 4 (with the joint section 5/6 blocks) in the order
##   the stores depend on each other; section 1's cross-check; section 7; section 6; section 8;
##   section 9; section 11; section 12; section 13; section 14; then the settlement's own derived
##   lists. ABSENT owners (World.absent_*) are never installed: their incoming records must equal a
##   fresh capture, or the load refuses SAVE_UNSUPPORTED_STATE.
## The first refusal stops the apply; the caller rolls the world back (`settlement_save_load.gd`).
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const Owners := preload("res://scripts/core/settlement_save_owners.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const SaveIdentityRestore := preload("res://scripts/core/save_identity_restore.gd")
const RuntimeInstall := preload("res://scripts/core/save_world_runtime_install.gd")
const S01 := preload("res://scripts/core/save_section_01.gd")
const S04 := preload("res://scripts/core/save_section_component_columns.gd")
const S05 := preload("res://scripts/core/save_section_child_arenas.gd")
const S06 := preload("res://scripts/core/save_section_auxiliary.gd")
const S07 := preload("res://scripts/core/save_section_inventories.gd")
const S08 := preload("res://scripts/core/save_section_job_indexes.gd")
const S09 := preload("res://scripts/core/save_section_navigation.gd")
const S11 := preload("res://scripts/core/save_section_event_schedule.gd")
const S12 := preload("res://scripts/core/save_section_pending_commands.gd")
const S13 := preload("res://scripts/core/save_section_chronicle.gd")
const S14 := preload("res://scripts/core/save_section_name_pool.gd")
const SaveGearRestore := preload("res://scripts/core/save_gear_restore.gd")
const SaveReservationsRestore := preload("res://scripts/core/save_reservations_restore.gd")
const SaveStockAgeRestore := preload("res://scripts/core/save_stock_age_restore.gd")
const SaveClaimsRestore := preload("res://scripts/core/save_resource_claims_restore.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_ABSENT: StringName = &"SAVE_UNSUPPORTED_STATE"
## Section 4 owners in restore order: residents and their satellites, jobs, the land, the rest.
const OWNER_ORDER: Array[int] = [12, 9, 11, 14, 15, 16, 7, 0, 1, 2, 4, 5, 10, 13, 17, 3, 6, 8]
const ABSENT_FIELD_POLICY: int = 3
const ABSENT_INJURY: int = 6
const MOVEMENT: int = 8


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func _wrap(section: int, refusal: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""Prefix a refusal's detail with its section; keep its exact code."""
	if refusal.is_ok():
		return refusal
	return _no(refusal.code, "section %d: %s" % [section, refusal.detail])


static func apply_all(world: SaveWorld.World, staged: Capture.Staged,
		header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Install every section in dependency order; the first refusal stops the apply."""
	var steps: Array[Callable] = [_apply_identity, _apply_runtime, _apply_01, _apply_04,
		_apply_cross_check, _apply_07, _apply_06, _apply_08, _apply_09, _apply_11, _apply_12,
		_apply_13, _apply_14]
	for step: Callable in steps:
		var refusal: SaveHeader.Refusal = step.call(world, staged, header)
		if not refusal.is_ok():
			return refusal
	rebuild_settlement_lists(world)
	return _ok()


# --- sections 3, 1 and 10 -------------------------------------------------------------------------

static func _apply_identity(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Section 3's directory with section 1's persistent-id cursor, atomically."""
	return _wrap(3, SaveIdentityRestore.apply(staged.s03, staged.s01.next_persistent_id,
		world.directory, world.clock()))


static func _apply_runtime(world: SaveWorld.World, staged: Capture.Staged,
		header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Section 1's world runtime and section 10's streams; the clock is installed last."""
	return _wrap(10, RuntimeInstall.install(staged.s01.runtime, staged.s10, header.completed_tick,
		world.manager, world.rng))


static func _apply_01(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Section 1's seven ordinary owners (the spatial map goes into the absent store)."""
	return _wrap(1, S01.restore_section(staged.s01, Capture.stores_01(world)))


static func _apply_cross_check(world: SaveWorld.World, _staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Section 1's cross-owner inverses, now that section 4 has landed."""
	return _wrap(1, S01.cross_check_refusal(Capture.stores_01(world)))


# --- section 4 ------------------------------------------------------------------------------------

static func _apply_04(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Every section 4 owner in OWNER_ORDER, the joint blocks with their record."""
	for owner: int in OWNER_ORDER:
		var refusal: SaveHeader.Refusal = _apply_owner(world, owner, staged)
		if not refusal.is_ok():
			return _no(refusal.code, "section 4 owner %d: %s" % [owner, refusal.detail])
	return _ok()


static func _apply_owner(world: SaveWorld.World, owner: int,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""One owner through its bridge, or the absent-owner equality."""
	var record: S04.FramedOwner = staged.s04[owner]
	if owner == ABSENT_FIELD_POLICY or owner == ABSENT_INJURY \
			or (owner == MOVEMENT and world.movement_is_absent):
		return _absent_refusal(world, owner, record)
	match owner:
		0:
			return Owners.OwnerBuildings.apply(record, staged.s05.block(0),
				Owners.aux_block(staged.s06, "buildings"), world.buildings)
		1:
			return Owners.OwnerConstruction.apply(record,
				Owners.construction_blocks(staged.s05, staged.s06), world.construction)
		5:
			return Owners.OwnerForage.apply(record, staged.s05.block(2), world.forage)
		7:
			return Owners.OwnerJobs.apply(record, staged.s05.block(3), world.jobs)
		10:
			return _apply_orchard(world, record, staged)
	return _apply_simple(world, owner, record)


static func _apply_simple(world: SaveWorld.World, owner: int,
		record: S04.FramedOwner) -> SaveHeader.Refusal:
	"""The owners whose bridge moves only their section 4 record."""
	match owner:
		2: return Owners.OwnerFarming.apply(record, world.farming)
		4: return Owners.OwnerFishing.apply(record, world.fishing)
		8: return Owners.OwnerMovement.apply(record, world.movement)
		9: return Owners.OwnerNeeds.apply(record, world.needs)
		11: return Owners.OwnerPriorities.apply(record, world.priorities)
		12: return Owners.OwnerResidents.apply(record, world.residents)
		13: return Owners.OwnerResourceNodes.apply(record, world.resource_nodes)
		14: return Owners.OwnerSchedule.apply(record, world.schedule)
		15: return Owners.OwnerTransforms.apply(record, world.transforms)
		16: return Owners.OwnerWork.apply(record, world.work)
	return Owners.OwnerWorldInit.apply(record, world.world_init)


static func _apply_orchard(world: SaveWorld.World, record: S04.FramedOwner,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""The orchard/hive record, then its section 5 links (structure only; re-proved after)."""
	var refusal: SaveHeader.Refusal = Owners.OwnerOrchardHive.apply(record, world.orchard_hive)
	if not refusal.is_ok():
		return refusal
	return Owners.OwnerOrchardHive.apply_links(staged.s05.block(4), world.orchard_hive)


static func _absent_refusal(world: SaveWorld.World, owner: int,
		record: S04.FramedOwner) -> SaveHeader.Refusal:
	"""An absent owner's record must be exactly a fresh capture of its absent store."""
	var fresh: S04.FramedOwner = S04.FramedOwner.new(owner)
	var refusal: SaveHeader.Refusal = Owners._capture_simple(world, owner, fresh)
	if not refusal.is_ok():
		return refusal
	if fresh.u8_columns != record.u8_columns or fresh.i32_columns != record.i32_columns \
			or fresh.i64_columns != record.i64_columns:
		return _no(REFUSE_ABSENT, "owner %d holds state this build cannot install" % owner)
	return _ok()


# --- sections 7, 6 and 8 --------------------------------------------------------------------------

static func _apply_07(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Inventory first, then gear, reservations, stock age and both claim tables."""
	var record: S07.Record = staged.s07
	var clock: SimClockScript = world.clock()
	var steps: Array[Callable] = [
		func() -> SaveHeader.Refusal: return S07.apply_inventory(record, world.inventory,
			S07.inventory_columns_for(record)),
		func() -> SaveHeader.Refusal: return SaveGearRestore.apply(record.of(S07.OWNER_GEAR),
			world.gear, clock, world.item_definitions, world.inventory),
		func() -> SaveHeader.Refusal: return SaveReservationsRestore.apply(
			record.of(S07.OWNER_RESERVATIONS), world.reservations, clock, world.inventory),
		func() -> SaveHeader.Refusal: return SaveStockAgeRestore.apply(
			record.of(S07.OWNER_STOCK_AGE), world.stock_age, clock),
		func() -> SaveHeader.Refusal: return SaveClaimsRestore.apply_fishing(
			record.of(S07.OWNER_FISHING), world.fishing, clock),
		func() -> SaveHeader.Refusal: return SaveClaimsRestore.apply_forage(
			record.of(S07.OWNER_FORAGE), world.forage, clock)]
	for step: Callable in steps:
		var refusal: SaveHeader.Refusal = step.call()
		if not refusal.is_ok():
			return _wrap(7, refusal)
	return _ok()


static func _apply_06(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Validate every section 6 owner, then apply them (joint blocks were installed with 4)."""
	return _wrap(6, S06.apply_section(staged.s06, Owners.aux_adapters(world)))


static func _apply_08(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""The planner's service indexes."""
	return _wrap(8, S08.apply(staged.s08, world.planner, world.clock()))


# --- sections 9 to 14 -----------------------------------------------------------------------------

static func _apply_09(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Navigation must be the empty navigator; movement's cursors install or must be fresh."""
	var expected: S09.Record = S09.Record.new()
	expected.movement = staged.s09.movement.duplicate()
	if not expected.equals(staged.s09):
		return _no(REFUSE_ABSENT, "section 9: navigation holds state this build cannot install")
	if world.movement_is_absent:
		var fresh: S09.Record = S09.Record.new()
		if fresh.movement != staged.s09.movement:
			return _no(REFUSE_ABSENT, "section 9: cursors for a movement store that is absent")
		return _ok()
	if not world.movement.restore_cursor_columns(staged.s09.movement):
		return _no(world.movement.last_column_refusal(), "section 9: movement cursors")
	return _ok()


static func _apply_11(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""The absent event schedule: the incoming section must be a fresh capture."""
	var fresh: S11.Record = S11.Record.new()
	var refusal: SaveHeader.Refusal = S11.capture_into(world.absent_event_schedule, fresh)
	if not refusal.is_ok():
		return _wrap(11, refusal)
	var incoming: S11.Record = staged.s11
	if fresh.next_sequence != incoming.next_sequence or fresh.kind != incoming.kind \
			or fresh.source_id != incoming.source_id or fresh.arg0 != incoming.arg0 \
			or fresh.arg1 != incoming.arg1 or fresh.due_tick != incoming.due_tick \
			or fresh.sequence != incoming.sequence:
		return _no(REFUSE_ABSENT, "section 11: events this build cannot install")
	return _ok()


static func _apply_12(world: SaveWorld.World, staged: Capture.Staged,
		header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Both pending queues; the loader bound the commands queue to the manager's clock."""
	return _wrap(12, S12.apply(staged.s12, world.commands, world.scheduler_events(),
		header.completed_tick))


static func _apply_13(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""The absent Chronicle: the incoming section must be a fresh capture."""
	var fresh: S13.Record = S13.Record.new()
	var refusal: SaveHeader.Refusal = S13.capture_into(world.absent_chronicle, fresh)
	if not refusal.is_ok():
		return _wrap(13, refusal)
	if fresh.record_count != staged.s13.record_count \
			or fresh.rolling_digest != staged.s13.rolling_digest:
		return _no(REFUSE_ABSENT, "section 13: Chronicle records this build cannot install")
	return _ok()


static func _apply_14(world: SaveWorld.World, staged: Capture.Staged,
		_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""The resident name pool, after section 4's residents."""
	return _wrap(14, S14.apply(staged.s14, world.residents))


static func rebuild_settlement_lists(world: SaveWorld.World) -> void:
	"""The settlement's own per-tick resident list: present residents in ascending persistent id.

	`create_initial_settlement()` appends each attached resident once, in spawn order, which is
	ascending persistent id; nothing removes one. A restored world rebuilds the same order.
	"""
	var settlement: Node = world.settlement
	var ids: Array = []
	for slot: int in world.residents.RESIDENT_CAPACITY:
		if world.residents.is_present(slot):
			ids.append(Vector2i(world.residents.persistent_id_of(slot).value, slot))
	ids.sort()
	settlement._live_slots.fill(-1)
	for index: int in ids.size():
		settlement._live_slots[index] = (ids[index] as Vector2i).y
	settlement._live_count = ids.size()
