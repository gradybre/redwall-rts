extends Node
## THE VILLAGE'S WORK (decision 0411): the work board (work_board.gd) over every job owner, its claims stepped on the
## cast's clock each frame, the Work screen (work_screen.gd), and Shift+right-click's order lists (work_orders.gd).
## demo_village.gd builds it once the farm, the spoil heaps, the woods and the water are built (`configure`), opens the
## screen from the HUD's Jobs command (UI-SET-029, J) and hands the command layer `queue_at`.
##
## From `configure` on, the farm's, the woods' and the bridges' own routine hand-outs stand down (`set_claimer`): the
## board claims their waiting work for any idle eligible resident, its own crew first. `add_kitchen` lists the kitchen's
## cook and drawers and keeps the board off a resident at its meal.

const BoardScript := preload("res://demo/work/work_board.gd")
const ScreenScript := preload("res://demo/work/work_screen.gd")
const OrdersScript := preload("res://demo/work/work_orders.gd")
const AnswerScript := preload("res://demo/work/queue_answer.gd")
const FarmWork := preload("res://demo/work/farm_work.gd")
const WoodsWork := preload("res://demo/work/woods_work.gd")
const BridgeWork := preload("res://demo/work/bridge_work.gd")
const TunnelWork := preload("res://demo/work/tunnel_work.gd")
const FitOutWork := preload("res://demo/work/fit_out_work.gd")
const SpoilWork := preload("res://demo/work/spoil_work.gd")
const FisheryWork := preload("res://demo/work/fishery_work.gd")
const FerryWork := preload("res://demo/work/ferry_work.gd")
const ForageWork := preload("res://demo/work/forage_work.gd")
const KitchenWork := preload("res://demo/work/kitchen_work.gd")
const StoresWork := preload("res://demo/work/stores_work.gd")
const CareWork := preload("res://demo/work/care_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const FarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const SpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const TunnelExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")

## The Jobs command's painted icon (the locked set's own "work" subject, ART-LOCK-001) and what it does.
const JOBS_ICON: String = "res://ui/painted/cmd_work.svg"
const JOBS_TOOLTIP: String = "Work: every task, who has it and why it waits; the crews and their order lists"

var board: BoardScript = BoardScript.new()
var screen: ScreenScript = ScreenScript.new()
var orders: OrdersScript = OrdersScript.new()

var _cast: DemoCastScript = null


func configure(cast: DemoCastScript, farm: FarmScript, forestry: ForestryScript, waterplay: WaterplayScript,
		spoil: SpoilScript, ext: TunnelExtScript, can_dig: Callable) -> void:
	"""The board over this cast and these owners (any owner may be null), `can_dig(who)` the tunnels' digging rule;
	the screen built hidden."""
	name = "DemoWork"
	_cast = cast
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		keys.append(actor.creature_key)
	board.bind(brains, names, keys)
	_add_owners(farm, forestry, waterplay, spoil, ext, brains, can_dig)
	orders.configure(board, farm, forestry, spoil)
	add_child(screen)
	screen.configure(board, Callable(), Callable())


func _add_owners(farm: FarmScript, forestry: ForestryScript, waterplay: WaterplayScript, spoil: SpoilScript,
		ext: TunnelExtScript, brains: Array[BrainScript], can_dig: Callable) -> void:
	"""One adapter per owner, and the claiming owners' hand-outs stood down."""
	if farm != null:
		board.add_source(FarmWork.new(farm.crew))
		farm.crew.set_claimer(board.queue_words)
		farm.garden.bind_claim_check(farm_claimable)
	if forestry != null:
		board.add_source(WoodsWork.new(forestry.crew))
		forestry.crew.set_claimer(board.queue_words)
	if waterplay != null:
		board.add_source(BridgeWork.new(waterplay.crew, waterplay.bridges))
		waterplay.crew.set_claimer()
	if ext != null:
		board.add_source(TunnelWork.new(ext.works.jobs, _cast.space().tunnels, ext.works.stores, brains, can_dig))
		board.add_source(FitOutWork.new(_cast.space().tunnels, ext.fixture_crew, brains, board.name_of))
	if spoil != null:
		board.add_source(SpoilWork.new(spoil.crew, _cast.space().tunnels, brains))


func farm_claimable(who: int) -> bool:
	"""Whether the board could give `who` farm work now: idle by its own test, and farm work not forbidden to its crew
	(the kitchen garden keeps its jobs for the cook only while this holds: farm_garden.gd `can_tend`, decision 0883)."""
	return board.idle(who) and board.crews.priority_of(who, WorkIds.ACT_FARM) != WorkIds.PRIORITY_FORBIDDEN


func add_fishery(fishery: RefCounted) -> void:
	"""WATER PART B ON THE BOARD (decision 0431): the fishery's jobs -- trips' seats, traps' collections, the rack, the mill
	and the gear (work/fishery_work.gd) -- claimed like the farm's."""
	board.add_source(FisheryWork.new(fishery))


func add_ferry(ferry: RefCounted) -> void:
	"""THE FERRY ON THE BOARD (decision 0437): the far copse's gathering, the ferried wood's hauls and the crossings' crews
	(work/ferry_work.gd) -- claimed like the farm's."""
	board.add_source(FerryWork.new(ferry))


func add_forage(trips: RefCounted) -> void:
	"""THE FORAGING TRIPS ON THE BOARD (decision 0681): each forager's seat (work/forage_work.gd) -- the Woods crew's work,
	claimed like the farm's."""
	board.add_source(ForageWork.new(trips))


func add_kitchen(kitchen: KitchenScript) -> void:
	"""THE MEALS ON THE BOARD (decision 0411 with 0381): the kitchen's cook and water drawers listed on the Work screen
	(kitchen_work.gd: the kitchen hands them out itself, so nothing is claimed), and the board keeping its hands off a
	resident the meals have (`set_needs_gate`: kitchen.gd `kept_for_meals`) -- no work handed out at mealtime."""
	var brains: Array[BrainScript] = []
	for i: int in _cast.actor_count():
		brains.append((_cast.actor(i) as DemoActorScript).brain)
	board.add_source(KitchenWork.new(kitchen, brains))
	board.set_needs_gate(kitchen.kept_for_meals)


func add_stores(haul: RefCounted, pantry: RefCounted, builders: RefCounted = null) -> void:
	"""THE FOOD STORES ON THE BOARD (decisions 0611, 0612): surplus food carried from a warmer store into a cool cellar
	(demo/stores/cellar_haul.gd) and the cellar buildings' places (cellar_builders.gd), one source
	(work/stores_work.gd), claimed like the farm's."""
	var brains: Array[BrainScript] = []
	for i: int in _cast.actor_count():
		brains.append((_cast.actor(i) as DemoActorScript).brain)
	board.add_source(StoresWork.new(haul, pantry, brains, builders))


func add_care(builders: RefCounted) -> void:
	"""THE INFIRMARY ON THE BOARD (decision 0623): the infirmary building's places (demo/infirmary/infirmary_builders.gd),
	one source (work/care_work.gd), claimed like the farm's."""
	var brains: Array[BrainScript] = []
	for i: int in _cast.actor_count():
		brains.append((_cast.actor(i) as DemoActorScript).brain)
	board.add_source(CareWork.new(builders, brains))


func set_readouts(activity: Callable, is_paused: Callable, jump: Callable, selection: Callable) -> void:
	"""What a resident is doing (`activity(who)`), whether the village is paused, the village's "Go to"
	(`jump(kind, id, point) -> bool`) and who is selected (`selection()`)."""
	screen.set_readouts(activity, is_paused, selection)
	board.set_jump(jump)


func _process(_delta: float) -> void:
	"""Step the board on the cast's clock (nothing while paused)."""
	if _cast != null:
		board.update(_cast.clock.frame_usec)


func unlock_jobs_command(shell: UiShell) -> bool:
	"""THE JOBS COMMAND (UI-SET-029, J). The game's shell draws it locked -- its job matrix (UI-SET-070) is not built,
	`ui_availability.gd` PANEL_NOT_BUILT -- so the demo unlocks the button for its Work screen, as the farm unlocks
	Food for the Pantry (farm_hud.gd `unlock_food_command`): enabled, its own painted icon, its tooltip in the command
	strip's form ("Jobs (J) — ...", the key read from the input map), and pressed -- or J, which the shell presses on an
	enabled command -- it opens the screen. False when there is no such button."""
	if shell == null:
		return false
	var jobs := shell.control_for(UiShell.ID_JOBS) as Button
	if jobs == null:
		return false
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_JOBS)
	jobs.disabled = false
	jobs.icon = load(JOBS_ICON) as Texture2D
	jobs.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index],
		JOBS_TOOLTIP, "")
	jobs.accessibility_description = JOBS_TOOLTIP
	jobs.pressed.connect(func() -> void: toggle())
	return true


func toggle() -> bool:
	"""Open or close the Work screen; whether it is now open."""
	return screen.toggle()


func queue_at(screen_point: Vector2, ground: Vector2, members: PackedInt32Array) -> AnswerScript:
	"""Shift+right-click (work_orders.gd): append to the selection's order lists. Whether it did, and what to say."""
	return orders.queue_at(screen_point, ground, members)
