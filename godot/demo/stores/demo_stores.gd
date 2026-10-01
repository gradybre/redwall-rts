extends Node
## THE VILLAGE'S FOOD STORES AT WORK (decision 0611): the cool cellar's hauling (cellar_haul.gd) stepped on the cast's
## clock -- surplus food carried from a warmer store into a cool root cellar, its moves on the work board as HAULING
## (demo/work/stores_work.gd). demo_village.gd builds it after the farm, the kitchen and the tunnels (`configure`) and
## hands its board to the work board. Presentation only.

const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

var haul: HaulScript = HaulScript.new()

var _cast: DemoCastScript = null


func configure(cast: DemoCastScript, network: GraphScript, pantry: PantryScript, free_of: Callable,
		hour_of: Callable, goods: GoodsScript) -> void:
	"""Move this pantry's surplus with this cast into this network's cellars (cellar_haul.gd `configure`)."""
	name = "DemoStores"
	_cast = cast
	haul.configure(cast, network, pantry, free_of, hour_of, goods)


func _process(_delta: float) -> void:
	"""Plan and carry the moves on the demo clock (nothing while paused)."""
	if _cast != null:
		haul.update(_cast.clock.frame_usec)
