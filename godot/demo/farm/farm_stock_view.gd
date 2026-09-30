extends Node3D
## The pantry's stores, stocked as they fill. Decision 0196 (live demo). Presentation only.
##
## Each storage location the pantry has (farm_storage.gd) gets a shelf (demo/props/store_shelf.gd):
## the covered store's stands outside it against its side wall -- the store is a closed barn, and its
## front is its work spot -- facing the camera's usual side; a root cellar's stands in the cellar's first
## shelf place below ground (decision 0209: underground_rooms.gd FIXTURES; room_view.gd leaves it for this),
## on the underground layer the U view draws (decision 0206: put there when the cellar is stocked, never when
## the view switches). Each shows the store's fullness as jars and its most-stocked goods on its boards. A
## cellar is found from its storage id (farm_cellars.gd: "root_cellar:<slot>:<generation>") in the rooms.
##
## Refreshed at the panels' cadence (demo_farm.gd), not per frame: each shelf reads its location's
## load and the items there, into columns allocated once.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const ShelfScript := preload("res://demo/props/store_shelf.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")

const STORE_ID: StringName = &"store"
## The covered store's shelf, in the store's own frame (+Z its front, toward the square): just past
## its +X side's footprint (3.74 m from its centre at drawn size, world_sizes.gd), a little toward the
## front, turned to face out from that side -- which, with the store turned to the square, faces the
## camera's usual side.
const STORE_SHELF_LOCAL: Vector3 = Vector3(3.95, 0.0, 0.9)
const STORE_SHELF_TURN: float = PI * 0.5
## A cellar's shelf stands this far over its floor.
const CELLAR_FLOOR_LIFT_M: float = 0.04
const CELLAR_PREFIX: String = "root_cellar:"

var _pantry: PantryScript = null
var _goods: GoodsScript = null
var _rooms: RoomsScript = null
var _shelves: Array[ShelfScript] = []
## Per shelf, the layer it was last put on (0: not yet).
var _shelf_layer: PackedInt32Array = PackedInt32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _milli: PackedInt64Array = PackedInt64Array()
var _keys: Array[StringName] = []


func configure(pantry: PantryScript, goods: GoodsScript) -> void:
	"""Stock this pantry's stores with these goods; the covered store's shelf is built now."""
	name = "FarmStockView"
	_pantry = pantry
	_goods = goods
	_order.resize(Catalog.ITEM_COUNT)
	_milli.resize(Catalog.ITEM_COUNT)
	_shelf(0).transform = store_shelf_transform()


func follow_rooms(rooms: RoomsScript) -> void:
	"""Find root cellars in these rooms."""
	_rooms = rooms


func register(prewarm: PrewarmScript) -> void:
	"""What a cellar's shelf draws -- the shelf, its jars and every good a shelf can set out -- for the
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
		_shelf_layer.append(0)
	return _shelves[location]


func refresh() -> void:
	"""Place and stock every location's shelf; hide the shelves of locations that are gone."""
	var storage: StorageScript = _pantry.storage
	for location: int in storage.count():
		var shelf: ShelfScript = _shelf(location)
		shelf.visible = _place(shelf, location, storage)
		if shelf.visible:
			_layer(location, Layers.SURFACE if location == 0 else Layers.UNDERGROUND)
			shelf.show_stock(fill_permille(location), _stock_keys(location))
	for gone: int in range(storage.count(), _shelves.size()):
		_shelves[gone].visible = false


func _place(shelf: ShelfScript, location: int, storage: StorageScript) -> bool:
	"""Put a location's shelf where it belongs; whether it shows now."""
	if location == 0:
		return true
	var id: String = String(storage.id_of(location))
	if _rooms == null or not id.begins_with(CELLAR_PREFIX):
		return false
	var parts: PackedStringArray = id.trim_prefix(CELLAR_PREFIX).split(":")
	var slot: int = int(parts[0])
	if not _rooms.is_ref(slot, int(parts[1])):
		return false
	shelf.transform = cellar_shelf_transform(_rooms, slot)
	return true


static func cellar_shelf_transform(rooms: RoomsScript, r: int) -> Transform3D:
	"""Where the pantry's shelf stands in cellar `r`: its first shelf place, on its floor, facing into the
	cellar (underground_rooms.gd FIXTURES)."""
	var kind: int = rooms.template[r]
	for f in RoomsScript.fixture_count(kind):
		if RoomsScript.fixture_field(kind, f, 0) != RoomsScript.FIX_SHELF:
			continue
		var at := rooms.to_world_u(r, Vector2i(RoomsScript.fixture_field(kind, f, 1), RoomsScript.fixture_field(kind, f, 2)))
		var face := RoomsScript.rotate_u(Vector2i(RoomsScript.fixture_field(kind, f, 3), RoomsScript.fixture_field(kind, f, 4)), rooms.turns[r])
		return Transform3D(Basis(Vector3.UP, atan2(float(face.x), float(face.y))),
			Vector3(Rules.to_m(at.x), Layers.FLOOR_Y_M + CELLAR_FLOOR_LIFT_M, Rules.to_m(at.y)))
	var middle := rooms.centre_m(r)
	return Transform3D(Basis.IDENTITY, Vector3(middle.x, Layers.FLOOR_Y_M, middle.y))


func _layer(location: int, layer: int) -> void:
	"""Put a location's shelf -- the shelf, its jars and every good's place -- on `layer`, once."""
	if _shelf_layer[location] != layer:
		_shelf_layer[location] = layer
		Layers.set_layers(_shelves[location], layer)


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
