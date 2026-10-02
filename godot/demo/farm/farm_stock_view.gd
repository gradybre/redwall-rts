extends Node3D
## The pantry's stores, stocked as they fill. Decision 0196 (live demo). Presentation only.
##
## The covered store gets a shelf (demo/props/store_shelf.gd), standing outside it against its side wall --
## the store is a closed barn, and its front is its work spot -- facing the camera's usual side, showing the
## store's fullness as jars and its most-stocked goods on its boards. A root cellar's stock shows on its own
## racks, shelves, bin and hanging stores below ground instead (decision 0210: demo/burrow/fixture_view.gd, fed
## by demo_farm.gd `cellar_fill`), so its location here has no shelf.
##
## OTHER SHELVES (decision 0883): a store that is a shelf standing in the open -- the kitchen garden's work shelf -- is
## added with `add_shelf(id, transform)`: drawn there, stocked the same way, while a storage location of that id exists.
##
## Refreshed at the panels' cadence (demo_farm.gd), not per frame: each shelf reads its location's
## load and the items there, into columns allocated once.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const ShelfScript := preload("res://demo/props/store_shelf.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const STORE_ID: StringName = &"store"
## The covered store's shelf, in the store's own frame (+Z its front, toward the square): just past
## its +X side's footprint (3.74 m from its centre at drawn size, world_sizes.gd), a little toward the
## front, turned to face out from that side -- which, with the store turned to the square, faces the
## camera's usual side.
const STORE_SHELF_LOCAL: Vector3 = Vector3(3.95, 0.0, 0.9)
const STORE_SHELF_TURN: float = PI * 0.5

var _pantry: PantryScript = null
var _goods: GoodsScript = null
var _shelves: Array[ShelfScript] = []
var _order: PackedInt32Array = PackedInt32Array()
var _milli: PackedInt64Array = PackedInt64Array()
var _keys: Array[StringName] = []
## OTHER SHELVES: their storage ids and shelves.
var _extra_ids: Array[StringName] = []
var _extra_shelves: Array[ShelfScript] = []
var _location_read: IntMath.IntResult = IntMath.IntResult.new()


func configure(pantry: PantryScript, goods: GoodsScript) -> void:
	"""Stock this pantry's stores with these goods; the covered store's shelf is built now."""
	name = "FarmStockView"
	_pantry = pantry
	_goods = goods
	_order.resize(Catalog.ITEM_COUNT)
	_milli.resize(Catalog.ITEM_COUNT)
	_shelf(0).transform = store_shelf_transform()


func register(prewarm: PrewarmScript) -> void:
	"""What a store's shelf draws -- the shelf, its jars and every good a shelf can set out -- for the
	underground view's prewarm (decision 0206)."""
	prewarm.add_mesh(_goods.props.mesh_of(ShelfScript.SHELF_KEY))
	prewarm.add_mesh(_goods.props.mesh_of(ShelfScript.JARS_KEY))
	for item: int in Catalog.ITEM_COUNT:
		if _goods.has_model(item):
			prewarm.add_mesh(_goods.props.mesh_of(Catalog.ITEM_PROP[item]))


static func store_shelf_transform() -> Transform3D:
	"""The covered store's shelf in the world: STORE_SHELF_LOCAL in the store's placed frame."""
	for p: Dictionary in Layout.placements():
		if p["id"] == STORE_ID:
			var at: Vector2 = p["at"]
			var yaw: float = p["yaw"]
			return Transform3D(Basis(Vector3.UP, yaw + STORE_SHELF_TURN),
				Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * STORE_SHELF_LOCAL)
	assert(false, "the farm's stock view needs the store (world_layout.gd BUILDINGS)")
	return Transform3D.IDENTITY


func _shelf(location: int) -> ShelfScript:
	"""The shelf of storage location `location`, built the first time it is needed."""
	while _shelves.size() <= location:
		var shelf := ShelfScript.new()
		shelf.name = "Shelf%d" % _shelves.size()
		shelf.build(_goods.props)
		shelf.visible = false
		add_child(shelf)
		_shelves.append(shelf)
	return _shelves[location]


func refresh() -> void:
	"""Stock the covered store's shelf, and every OTHER SHELF whose store exists. A cellar's location has none: its stock
	shows on its racks (see the header)."""
	var shelf: ShelfScript = _shelf(0)
	shelf.visible = true
	shelf.show_stock(fill_permille(0), _stock_keys(0))
	for k: int in _extra_ids.size():
		var there: bool = _pantry.storage.index_of_id_into(_extra_ids[k], _location_read)
		_extra_shelves[k].visible = there
		if there:
			_extra_shelves[k].show_stock(fill_permille(_location_read.value), _stock_keys(_location_read.value))


func add_shelf(id: StringName, xf: Transform3D) -> void:
	"""Draw the store `id` as a shelf at `xf` while it exists (OTHER SHELVES)."""
	var made := ShelfScript.new()
	made.name = "Shelf_%s" % id
	made.build(_goods.props)
	made.transform = xf
	made.visible = false
	add_child(made)
	_extra_ids.append(id)
	_extra_shelves.append(made)


func extra_shelf(k: int) -> ShelfScript:
	"""The k-th OTHER SHELF (checks)."""
	return _extra_shelves[k]


func fill_permille(location: int) -> int:
	"""How full a location is, per mille of its capacity."""
	var capacity: int = _pantry.storage.capacity_milli_of(location)
	return 0 if capacity <= 0 else _pantry.used_milli_of(location) * 1000 / capacity


func _stock_keys(location: int) -> Array[StringName]:
	"""The model keys of the goods at `location`, most first (items with none held there left out)."""
	var count: int = 0
	for item: int in Catalog.ITEM_COUNT:
		var milli: int = _pantry.milli_at(item, location)
		if milli <= 0:
			continue
		var at: int = count
		while at > 0 and _milli[at - 1] < milli:
			_milli[at] = _milli[at - 1]
			_order[at] = _order[at - 1]
			at -= 1
		_milli[at] = milli
		_order[at] = item
		count += 1
	_goods.shelf_keys(_order, count, _keys)
	return _keys


func shelf(location: int) -> ShelfScript:
	"""Location `location`'s shelf (tests and the scripted check)."""
	return _shelf(location)
