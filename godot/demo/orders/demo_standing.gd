extends Node
## THE STANDING ORDERS IN THE VILLAGE (decision 0711): the book (standing_orders.gd) over the village's own owners --
## the woods' crew and the stores for planks and wood, the farm's crew, beds and pantry for a crop, the kitchen for days
## of meals -- kept on the game hour, its blocked notices raised in the village's incidents, and its section on the
## Work screen (standing_view.gd). demo_village.gd builds it with the work board, before the winter binds its built-in
## Firewood order into the same book (demo_winter.gd `bind_work`).
##
## EACH FRAME only the calendar's hour index is compared (no allocation); when it has moved -- one hour or a skip's many
## -- every player order is kept ONCE, on the hour the calendar is at now (raising work for hours already gone would
## only double it).

const BookScript := preload("res://demo/orders/standing_orders.gd")
const ViewScript := preload("res://demo/orders/standing_view.gd")
const PlanksGoal := preload("res://demo/orders/goal_planks.gd")
const WoodGoal := preload("res://demo/orders/goal_wood.gd")
const CropGoal := preload("res://demo/orders/goal_crop.gd")
const MealsGoal := preload("res://demo/orders/goal_meals.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")

var book: BookScript = BookScript.new()
## Hours the book was kept on (checks).
var hours_kept: int = 0

var _calendar: CalendarScript = null
var _incidents: IncidentsScript = null
var _board: BoardScript = null
var _hour_seen: int = -1


func configure(services: ServicesScript, board: BoardScript, forestry: ForestryScript, farm_crew: FarmCrewScript,
		sim: SimScript, pantry: PantryScript, kitchen: KitchenScript, fuel_urgent: Callable = Callable()) -> void:
	"""The book over these owners (the farm's or the kitchen's may be null: their goods are then not offered);
	`fuel_urgent() -> bool` the winter's fuel-days under two (wood's food/fuel bucket)."""
	name = "StandingOrders"
	_calendar = services.calendar
	_incidents = services.incidents
	_board = board
	_hour_seen = _calendar.hour_index()
	book.bind_board(board)
	book.set_reporter(report_blocked)
	if forestry != null:
		book.set_goal(PlanksGoal.new(forestry.crew, services.stores))
		var wood := WoodGoal.new(forestry.crew, services.stores, forestry.deadfall, forestry.stand)
		wood.set_fuel_urgent(fuel_urgent)
		book.set_goal(wood)
	if farm_crew != null:
		var food_days: Callable = kitchen.days_of_meals_milli if kitchen != null else Callable()
		book.set_goal(CropGoal.new(farm_crew, sim, pantry, food_days))
		if kitchen != null:
			book.set_goal(MealsGoal.new(farm_crew, sim, pantry, kitchen))


func _process(_delta: float) -> void:
	"""Each frame: keep the book when the game hour has moved."""
	tick()


func tick() -> bool:
	"""Keep every player order once if the calendar's hour has moved since the last keep; whether it had."""
	if _calendar == null:
		return false
	var hour: int = _calendar.hour_index()
	if hour == _hour_seen:
		return false
	_hour_seen = hour
	hours_kept += 1
	book.on_hour()
	return true


func report_blocked(key: String, text: String, watch: Callable) -> void:
	"""A blocked order's notice: a Village warning incident, resolved by its watch (demo_incidents.gd `report`)."""
	if _incidents != null:
		_incidents.report(key, NoticesScript.SOURCE_VILLAGE, IncidentsScript.SEVERITY_WARNING, text, "",
			NoticesScript.TARGET_NONE, -1, watch)


func make_view() -> ViewScript:
	"""The Work screen's Standing orders section over this book and board (the screen adds it: work_screen.gd
	`set_standing`)."""
	var view := ViewScript.new()
	view.configure(book, _board)
	return view
