extends RefCounted
## The settlement save's view of one live world (ADR 1222 build steps 8-9).
##
## `World` names every store a save captures from and a load restores into, read once from a
## SettlementSystem and its GameManager. Owners the settlement does not compose in production --
## the static spatial map, field policy, injury, the event schedule, the Chronicle, and, while no
## underground Session is mounted, movement -- are bound to FRESH instances (`absent_*`). Their
## captures are therefore the canonical empty images, and a load proves the incoming records equal
## a fresh capture rather than installing them anywhere (DEC-055 Q9). A mounted Session's Space
## owner and movement are read from the Session's retirement owners (ADR 1222's owner map).
##
## Stateless apart from the bindings; nothing here captures, encodes or restores.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const HaulPlannerScript := preload("res://scripts/core/haul_planner.gd")
const StorePolicyScript := preload("res://scripts/core/store_policy.gd")
const DemolitionAdmissionsScript := preload("res://scripts/core/demolition_admissions.gd")
const DemolitionWorkScript := preload("res://scripts/core/demolition_work.gd")
const UndergroundSessionScript := preload("res://scripts/core/underground_session.gd")
const SpaceOwnerScript := preload("res://scripts/core/underground_space_owner.gd")
const FieldPolicyScript := preload("res://scripts/core/field_policy.gd")
const InjuryScript := preload("res://scripts/core/injury.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const EventScheduleScript := preload("res://scripts/core/event_schedule.gd")
const ChronicleScript := preload("res://scripts/core/chronicle.gd")


class World:
	"""Every store the fifteen sections read or write, bound from one settlement."""
	var settlement: Node = null
	var manager: Node = null
	var directory: EntityDirectoryScript = null
	var residents: ResidentsScript = null
	var needs: NeedsScript = null
	var priorities: PrioritiesScript = null
	var schedule: ScheduleScript = null
	var jobs: JobsScript = null
	var work: WorkScript = null
	var transforms: TransformsScript = null
	var buildings: BuildingsScript = null
	var construction: ConstructionScript = null
	var farming: FarmingScript = null
	var weather: WeatherScript = null
	var crop_weather: CropWeatherScript = null
	var ecology: EcologyScript = null
	var resource_nodes: ResourceNodesScript = null
	var forage: ForageScript = null
	var fishing: FishingScript = null
	var orchard_hive: OrchardHiveScript = null
	var world_init: WorldInitScript = null
	var rng: RngScript = null
	var commands: CommandsScript = null
	var dispatch: CommandDispatchScript = null
	var planner: JobPlannerScript = null
	var inventory: InventoryScript = null
	var item_definitions: ItemDefinitionsScript = null
	var gear: GearScript = null
	var reservations: ReservationsScript = null
	var stock_age: StockAgeScript = null
	var haul_planner: HaulPlannerScript = null
	var store_policy: StorePolicyScript = null
	var admissions: DemolitionAdmissionsScript = null
	var demolition_work: DemolitionWorkScript = null
	var session: UndergroundSessionScript = null
	var space_owner: SpaceOwnerScript = null
	var movement: MovementScript = null
	var absent_spatial_world: SpatialWorldScript = null
	var absent_field_policy: FieldPolicyScript = null
	var absent_injury: InjuryScript = null
	var absent_event_schedule: EventScheduleScript = null
	var absent_chronicle: ChronicleScript = null
	var movement_is_absent: bool = true

	func clock() -> SimClockScript:
		"""The GameManager's live clock (re-read every call: `start_game()` replaces it)."""
		return manager.clock()

	func scheduler_events() -> SchedulerEventsScript:
		"""The GameManager's live scheduler queue."""
		return manager.scheduler_events()


static func bind(settlement: Node, manager: Node) -> World:
	"""Bind every store of `settlement` and `manager`, and fresh instances for the absent owners."""
	var world: World = World.new()
	world.settlement = settlement
	world.manager = manager
	_bind_people(world, settlement)
	_bind_land(world, settlement)
	_bind_economy(world, settlement)
	_bind_absent(world)
	_bind_underground(world, settlement)
	return world


static func _bind_people(world: World, s: Node) -> void:
	"""Directory, residents and every per-resident store."""
	world.directory = s.directory()
	world.residents = s.residents()
	world.needs = s.needs()
	world.priorities = s.priorities()
	world.schedule = s.schedule()
	world.jobs = s.jobs()
	world.work = s.work()
	world.transforms = s.transforms()
	world.commands = s.commands()
	world.dispatch = s.command_dispatch()
	world.planner = s.job_planner()
	world.rng = s.rng()


static func _bind_land(world: World, s: Node) -> void:
	"""Buildings, construction, the world map and the ecology owners."""
	world.buildings = s.buildings()
	world.construction = s.construction()
	world.farming = s.farming()
	world.weather = s.weather()
	world.crop_weather = s.crop_weather()
	world.ecology = s.ecology()
	world.resource_nodes = world.ecology.resource_nodes()
	world.forage = world.ecology.forage()
	world.fishing = world.ecology.fishing()
	world.orchard_hive = world.ecology.orchard_hive()
	world.world_init = s.world()


static func _bind_economy(world: World, s: Node) -> void:
	"""Inventory, its satellites and the demolition and policy owners."""
	world.inventory = s.inventory()
	world.item_definitions = s.item_definitions()
	world.gear = s.gear()
	world.reservations = s.reservations()
	world.stock_age = s.stock_age()
	world.haul_planner = s._haul_planner
	world.store_policy = s._store_policy
	world.admissions = s.demolition_admissions()
	world.demolition_work = s.demolition_work()


static func _bind_absent(world: World) -> void:
	"""Fresh instances for every owner production does not compose."""
	world.absent_spatial_world = SpatialWorldScript.new()
	world.absent_field_policy = FieldPolicyScript.new(world.farming, world.forage)
	world.absent_injury = InjuryScript.new()
	world.absent_event_schedule = EventScheduleScript.new()
	world.absent_chronicle = ChronicleScript.new()


static func _bind_underground(world: World, s: Node) -> void:
	"""The mounted Session's Space owner and movement, or a fresh movement while unmounted."""
	world.session = s.underground_session()
	if world.session != null:
		world.space_owner = world.session._space
		world.movement = world.session._retirement_owners.world_routes._movement
		world.movement_is_absent = false
		return
	var spatial: SpatialWorldScript = world.absent_spatial_world
	world.movement = MovementScript.new(world.directory, spatial,
		NavigationScript.new(world.directory, spatial), world.transforms, world.residents)
	world.movement_is_absent = true
