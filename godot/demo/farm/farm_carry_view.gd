extends RefCounted
## Harvests carried as themselves. Decision 0196 (live demo). Presentation only.
##
## A harvest job's load (farm_jobs.gd `load_item` / `load_milli`) is carried from the bed to its store
## on the carry walk; this puts that item's own model (farm_goods.gd) in the carrier's hands instead of
## the log (demo_actor.gd `hold()`), and takes it away when the load is delivered -- it then shows on
## the store's shelf (farm_stock_view.gd). An item with no model is carried as the log.
##
## Polled every frame: one look at each resident's job, and the actor is touched only when what it
## should hold changed.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const REFUSE_NO_JOB: String = "NOT_ON_A_JOB"
const REFUSE_NO_LOAD: String = "NO_HARVEST_IN_HAND"

var _cast: DemoCastScript = null
var _jobs: JobsScript = null
var _goods: GoodsScript = null
## Per actor: the item it is drawn holding (Catalog.NO_ITEM: none).
var _held: PackedInt32Array = PackedInt32Array()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(cast: DemoCastScript, jobs: JobsScript, goods: GoodsScript) -> void:
	"""Watch this cast's harvest carries on this job board."""
	_cast = cast
	_jobs = jobs
	_goods = goods
	_held.resize(cast.actor_count())
	_held.fill(Catalog.NO_ITEM)


static func harvest_in_hand_into(jobs: JobsScript, who: int, out: IntMath.IntResult) -> bool:
	"""The item resident `who` has in hand, into `out`: a harvest job's load, not yet delivered.
	Refuses NOT_ON_A_JOB or NO_HARVEST_IN_HAND."""
	if not jobs.job_of_worker_into(who, out):
		return out.refuse(REFUSE_NO_JOB)
	var row: int = out.value
	if jobs.kind[row] != JobsScript.KIND_HARVEST or jobs.load_milli[row] <= 0 or not Catalog.is_item(jobs.load_item[row]):
		return out.refuse(REFUSE_NO_LOAD)
	return out.succeed(jobs.load_item[row])


func refresh() -> void:
	"""Give each carrier its harvest's model, and take it back once delivered."""
	for who: int in _held.size():
		var item: int = Catalog.NO_ITEM
		if harvest_in_hand_into(_jobs, who, _read) and _goods.has_model(_read.value):
			item = _read.value
		if item == _held[who]:
			continue
		_held[who] = item
		var actor := _cast.actor(who) as DemoActorScript
		if item == Catalog.NO_ITEM:
			actor.drop_held()
		else:
			actor.hold(_goods.props.mesh_of(Catalog.ITEM_PROP[item]), _goods.hand_fit(item))


func held_item(who: int) -> int:
	"""The item resident `who` is drawn holding (Catalog.NO_ITEM: none; tests)."""
	return _held[who]
