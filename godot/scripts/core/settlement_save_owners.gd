extends RefCounted
## The per-owner half of the settlement save (ADR 1222 build steps 8-9): which bridge or adapter
## moves each section 4, 5 and 6 owner, for capture and for apply.
##
## SECTION 4 owners are captured into eighteen FramedOwner records in owner order. The joint owners
## fill their section 5 / section 6 blocks in the same call (buildings, construction, forage, jobs;
## orchard_hive's links separately). Owners production does not compose (field_policy, injury and,
## unmounted, movement) are captured from the World's fresh instances; on load their records must
## equal a fresh capture (`absent_owner_refusal()`), DEC-055 Q9.
##
## SECTION 6 owners are moved by `save_aux_adapters.gd` and, for the underground Session,
## `save_underground_adapters.gd` (ADR 1228); the joint owners' blocks are only shape-checked
## there. Production composes no RoomLayout, RoomProjects or SpoilTips instance: those blocks stay
## canonical empty through `UnsupportedAdapter`, which still refuses an instance holding state.
## A load applies section 6 in `AUX_APPLY_ORDER`: the surface owners, then the underground group in
## dependency order (ADR 1221's, with Sites first; the Space owner is restored first, by the
## orchestrator).
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const S04 := preload("res://scripts/core/save_section_component_columns.gd")
const S04Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const S05 := preload("res://scripts/core/save_section_child_arenas.gd")
const S06 := preload("res://scripts/core/save_section_auxiliary.gd")
const S06Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveAux := preload("res://scripts/core/save_aux_adapters.gd")
const SaveUnderground := preload("res://scripts/core/save_underground_adapters.gd")
const OwnerBuildings := preload("res://scripts/core/save_owner_buildings.gd")
const OwnerConstruction := preload("res://scripts/core/save_owner_construction.gd")
const OwnerFarming := preload("res://scripts/core/save_owner_farming.gd")
const OwnerFieldPolicy := preload("res://scripts/core/save_owner_field_policy.gd")
const OwnerFishing := preload("res://scripts/core/save_owner_fishing.gd")
const OwnerForage := preload("res://scripts/core/save_owner_forage.gd")
const OwnerInjury := preload("res://scripts/core/save_owner_injury.gd")
const OwnerJobs := preload("res://scripts/core/save_owner_jobs.gd")
const OwnerMovement := preload("res://scripts/core/save_owner_movement.gd")
const OwnerNeeds := preload("res://scripts/core/save_owner_needs.gd")
const OwnerOrchardHive := preload("res://scripts/core/save_owner_orchard_hive.gd")
const OwnerPriorities := preload("res://scripts/core/save_owner_priorities.gd")
const OwnerResidents := preload("res://scripts/core/save_owner_residents.gd")
const OwnerResourceNodes := preload("res://scripts/core/save_owner_resource_nodes.gd")
const OwnerSchedule := preload("res://scripts/core/save_owner_schedule.gd")
const OwnerTransforms := preload("res://scripts/core/save_owner_transforms.gd")
const OwnerWork := preload("res://scripts/core/save_owner_work.gd")
const OwnerWorldInit := preload("res://scripts/core/save_owner_world_init.gd")

const OWNER_COUNT_4: int = 18
## The ADR 1221 wire owners and the declared column owners of the underground Session.
const WIRE_AUX_KEYS: Array[String] = ["underground_connector_contacts",
	"underground_connector_placements", "underground_connector_workpieces", "underground_locations",
	"underground_routes", "underground_world_routes"]
const DECLARED_AUX_KEYS: Array[String] = ["excavation_inventory", "excavation_sites", "modular_projects"]
## Section 6 apply order: the surface owners, then the underground group, opened by section 1's
## Space block (`UNDERGROUND_FIRST_AUX_KEY`): funding, Sites and the Router first (they read only
## Construction and Jobs, and Locations' survey reads Sites); Placements and Workpieces (Locations'
## installed endpoints are proved from the Placements' installed prefixes; the Placements' anchors are
## proved by `SaveUnderground.cross_audit_refusal()` once Locations is restored); Locations; the
## spatial endpoints that read them; Routes; WorldRoutes; Contacts; the Planner, whose admissions may
## name a spatial store. The entry record is applied by the orchestrator after every section.
const AUX_APPLY_ORDER: Array[String] = ["buildings", "command_dispatch", "construction_extension",
	"construction_paid_ledger", "crop_weather", "demolition_admissions", "demolition_work", "ecology",
	"room_layout", "room_projects", "spoil_tips", "store_policy", "underground_mount",
	"excavation_inventory", "excavation_sites", "modular_projects", "underground_connector_placements",
	"underground_connector_workpieces", "underground_locations", "inventory", "underground_routes",
	"underground_world_routes", "underground_connector_contacts", "haul_planner",
	"underground_entry_progress"]
const UNDERGROUND_FIRST_AUX_KEY: String = "excavation_inventory"
const JOINT_AUX_KEYS: Array[String] = ["buildings", "construction_extension",
	"construction_paid_ledger"]
const REFUSE_ABSENT_OWNER: StringName = &"SAVE_UNSUPPORTED_STATE"


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


static func aux_block(state: S06.State, key: String) -> S06.Block:
	"""One section 6 owner's block by key."""
	return state.block(S06Schema.OWNER_KEYS.find(key))


static func construction_blocks(s05: S05.State, s06: S06.State) -> OwnerConstruction.Blocks:
	"""Construction's section 5 ledger block and its two section 6 blocks."""
	return OwnerConstruction.Blocks.new(s05.block(OwnerConstruction.CHILD_OWNER_INDEX),
		aux_block(s06, OwnerConstruction.EXTENSION_OWNER_KEY),
		aux_block(s06, OwnerConstruction.PAID_OWNER_KEY))


# --- capture --------------------------------------------------------------------------------------

static func capture_all(world: SaveWorld.World, out: Array[S04.FramedOwner], s05: S05.State,
		s06: S06.State) -> SaveHeader.Refusal:
	"""All eighteen section 4 records in owner order, filling the joint section 5/6 blocks."""
	var records: Array[S04.FramedOwner] = []
	for owner: int in OWNER_COUNT_4:
		var record: S04.FramedOwner = S04.FramedOwner.new(owner)
		var refusal: SaveHeader.Refusal = _capture_owner(world, owner, record, s05, s06)
		if not refusal.is_ok():
			return SaveHeader.Refusal.new(refusal.code, "owner '%s': %s"
				% [S04Schema.owner_key(owner), refusal.detail])
		records.append(record)
	var links: SaveHeader.Refusal = OwnerOrchardHive.capture_links_into(world.orchard_hive,
		s05.block(OwnerOrchardHive.CHILD_OWNER_INDEX))
	if not links.is_ok():
		return links
	out.assign(records)
	return _ok()


static func _capture_owner(world: SaveWorld.World, owner: int, record: S04.FramedOwner,
		s05: S05.State, s06: S06.State) -> SaveHeader.Refusal:
	"""One section 4 owner through its bridge."""
	match owner:
		0:
			return OwnerBuildings.capture_into(world.buildings, record,
				s05.block(OwnerBuildings.CHILD_OWNER_INDEX), aux_block(s06, "buildings"))
		1:
			return OwnerConstruction.capture_into(world.construction, record,
				construction_blocks(s05, s06))
		5:
			return OwnerForage.capture_into(world.forage, record,
				s05.block(OwnerForage.CHILD_OWNER_INDEX))
		7:
			return OwnerJobs.capture_into(world.jobs, record,
				s05.block(OwnerJobs.CHILD_OWNER_INDEX))
	return _capture_simple(world, owner, record)


static func _capture_simple(world: SaveWorld.World, owner: int,
		record: S04.FramedOwner) -> SaveHeader.Refusal:
	"""The fourteen owners whose bridge moves only their section 4 record."""
	match owner:
		2: return OwnerFarming.capture_into(world.farming, record)
		3: return OwnerFieldPolicy.capture_into(world.absent_field_policy, record)
		4: return OwnerFishing.capture_into(world.fishing, record)
		6: return OwnerInjury.capture_into(world.absent_injury, record)
		8: return OwnerMovement.capture_into(world.movement, record)
		9: return OwnerNeeds.capture_into(world.needs, record)
		10: return OwnerOrchardHive.capture_into(world.orchard_hive, record)
		11: return OwnerPriorities.capture_into(world.priorities, record)
		12: return OwnerResidents.capture_into(world.residents, record)
		13: return OwnerResourceNodes.capture_into(world.resource_nodes, record)
		14: return OwnerSchedule.capture_into(world.schedule, record)
		15: return OwnerTransforms.capture_into(world.transforms, record)
		16: return OwnerWork.capture_into(world.work, record)
	return OwnerWorldInit.capture_into(world.world_init, record)


static func capture_aux(world: SaveWorld.World, s06: S06.State) -> SaveHeader.Refusal:
	"""Every non-joint section 6 owner through its adapter, in owner order."""
	var adapters: S06.Adapters = aux_adapters(world)
	for owner: int in S06Schema.OWNER_COUNT:
		if JOINT_AUX_KEYS.has(S06Schema.OWNER_KEYS[owner]):
			continue
		var refusal: SaveHeader.Refusal = adapters.adapter_of(owner).capture(s06.block(owner))
		if not refusal.is_ok():
			return refusal
	return _ok()


static func aux_adapters(world: SaveWorld.World) -> S06.Adapters:
	"""The section 6 adapter registry over `world`'s live stores."""
	var adapters: S06.Adapters = S06.Adapters.new()
	for owner: int in S06Schema.OWNER_COUNT:
		adapters.register(owner, _aux_adapter_for(world, S06Schema.OWNER_KEYS[owner], owner))
	return adapters


static func _aux_adapter_for(world: SaveWorld.World, key: String, owner: int) -> Object:
	"""The adapter that moves one section 6 owner."""
	if JOINT_AUX_KEYS.has(key):
		return SaveAux.JointAdapter.new(key)
	if WIRE_AUX_KEYS.has(key):
		return SaveUnderground.WireAdapter.new(world, key)
	if DECLARED_AUX_KEYS.has(key):
		return SaveUnderground.DeclaredAdapter.new(world, key)
	match key:
		"command_dispatch": return SaveAux.CommandDispatchAdapter.new(world.dispatch)
		"crop_weather": return SaveAux.CropWeatherAdapter.new(world.crop_weather)
		"ecology": return SaveAux.EcologyAdapter.new(world.ecology)
		"haul_planner": return SaveAux.HaulPlannerAdapter.new(world.haul_planner)
		"inventory": return SaveUnderground.SpatialAdapter.new(world)
		"store_policy": return SaveAux.ColumnsAdapter.new(world.store_policy, key)
		"demolition_admissions": return SaveAux.ColumnsAdapter.new(world.admissions, key)
		"demolition_work": return SaveAux.ColumnsAdapter.new(world.demolition_work, key)
		"underground_mount": return SaveUnderground.MountAdapter.new(world)
		"underground_entry_progress": return SaveUnderground.EntryAdapter.new(world)
		"spoil_tips": return S06.UnsupportedAdapter.new(owner,
			func() -> bool: return world.underground != null and world.underground.tips != null)
	# room_layout, room_projects: no production instance exists, so nothing can hold their state.
	return S06.UnsupportedAdapter.new(owner, func() -> bool: return false)
