extends RefCounted
## THE GROUND UNDER EACH PAINTED CELL in the demo (decision 1912, slice C1): the build panel's ground reader
## (build_cell_validity.gd `bind_ground`) over the settlement's ACTUAL underground -- read only, never written.
##
## A cell on underground level L is the column of excavation quanta from the level's floor (the level catalog's
## `floor_y_u`) up to the height actually dug there (`dug_u`: the clear height capped by DEC-054, decision 1911 P-C3).
##   FINISHED   every quantum of the column is an excavation Site in SUPPORTED_VOID (dug, braced, finished)
##   OCCUPIED   some quantum is already claimed by a Site (a confirmed room or the entry)
##   WATER / PROTECTED   the terrain survey refuses digging there (`underground_terrain.gd dig_refusal`), mapped as the
##              order route maps it (demo_build_orders.gd NEVER_HERE): water, or protected ground
##   OK         none of these
## Codes are cached per level, one byte a cell (5 × 65536 bytes for the level pack's square), and dropped whenever the
## space owner's or the terrain's revision moves; `revision()` then moves too, so the batch judges every cell again.
## With no underground composed in the run, every cell reads OK and nothing is finished (the order route then says
## why nothing can be ordered).
## THE PROOF OF CONCEPT'S CELLS (decision 1912, demo_build_works.gd) come first: a cell it has ordered or dug reads
## FINISHED (a way in for the cells beside it, "occupied" under a new stroke) -- but a sloped way's run (decision
## 2021: solid earth it cuts through) reads OCCUPIED, never a way in -- and its revision moves this one.

const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")

const PITCH_U: int = 1024
const LEVELS: int = 5
const UNKNOWN: int = 255
## The terrain survey's refusals that are the SITE's (as the order route reads them), and what each is called.
const TERRAIN_CODES: Dictionary = {
	Terrain.REFUSE_WATER: Cells.CELL_WATER,
	Terrain.REFUSE_RESOURCE: Cells.CELL_PROTECTED,
	Terrain.REFUSE_FOUNDATION: Cells.CELL_PROTECTED,
	Terrain.REFUSE_BODY: Cells.CELL_PROTECTED,
	Terrain.REFUSE_DRY: Cells.CELL_PROTECTED,
}

var _terrain: WeakRef = null
var _sites: WeakRef = null
var _space: WeakRef = null
var _datum: Vector3i = Vector3i.ZERO
var _bounds: Rect2i = Rect2i()
## Per level: the floor (u) and the dug height (u); a level with no floor is never read.
var _floors: PackedInt32Array = PackedInt32Array()
var _heights: PackedInt32Array = PackedInt32Array()
var _cache: Array[PackedByteArray] = []
var _seen: Vector2i = Vector2i(-1, -1)
var _works: Works = null
var _seen_works: int = -1
var _revision: int = 0
var _phase: IntMath.IntResult = IntMath.IntResult.new()
var _box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
## Cells read from the owners (not the cache), for checks.
var reads: int = 0


func configure(datum: Vector3i, bounds: Rect2i) -> void:
	"""The cells' frame: cell (0, 0) at `datum`'s x and z, on `bounds`; every level unread until `set_level`."""
	_datum = datum
	_bounds = bounds
	_floors.resize(LEVELS)
	_floors.fill(0)
	_heights.resize(LEVELS)
	_heights.fill(0)
	_cache.clear()
	for level: int in LEVELS:
		_cache.append(PackedByteArray())
	_drop_cache()


func bind(terrain: Object, sites: Object, space: Object) -> void:
	"""The settlement's terrain survey, excavation Sites and space owner (weakly held; any may be null)."""
	_terrain = weakref(terrain) if terrain != null else null
	_sites = weakref(sites) if sites != null else null
	_space = weakref(space) if space != null else null
	_drop_cache()


func bind_works(works: Works) -> void:
	"""The proof of concept's ordered and dug cells, read first (see the header)."""
	_works = works


func set_level(level: int, floor_u: int, dug_u: int) -> void:
	"""Level `level`'s floor and the height dug there (0: not paintable)."""
	if level <= 0 or level >= LEVELS:
		return
	_floors[level] = floor_u
	_heights[level] = dug_u
	_cache[level] = PackedByteArray()


func bound() -> bool:
	"""Whether the terrain survey and the Sites are bound and alive."""
	return _owner(_terrain) != null and _owner(_sites) != null


func readable() -> bool:
	"""Whether it reads anything at all: the settlement's ground, or the proof of concept's cells."""
	return bound() or _works != null


func revision() -> int:
	"""Moves whenever a reading may have (the space owner's or the terrain's revision moved)."""
	var now: Vector2i = _owner_revisions()
	if now != _seen:
		_seen = now
		_drop_cache()
	if _works != null and _works.revision != _seen_works:
		_seen_works = _works.revision
		_revision += 1
	return _revision


func ground(level: int, cell: Vector2i) -> int:
	"""Cell `cell`'s ground code on `level` (build_cell_validity.gd CELL_*), cached until `revision` moves."""
	if _works != null and _works.state(level, cell) != Works.EARTH:
		return Cells.CELL_OCCUPIED if _works.type_of(level, cell) == Works.TYPE_WAY else Cells.CELL_FINISHED
	if level <= 0 or level >= LEVELS or _heights[level] <= 0 or not _bounds.has_point(cell) or not bound():
		return Cells.CELL_OK
	var index: int = (cell.y - _bounds.position.y) * _bounds.size.x + cell.x - _bounds.position.x
	var cache: PackedByteArray = _cache[level]
	if cache.is_empty():
		cache.resize(_bounds.size.x * _bounds.size.y)
		cache.fill(UNKNOWN)
		_cache[level] = cache
	if cache[index] == UNKNOWN:
		cache[index] = _read(level, cell)
	return cache[index]


func _read(level: int, cell: Vector2i) -> int:
	"""The owners' answer for one cell column (uncached)."""
	reads += 1
	var x: int = _datum.x + cell.x * PITCH_U
	var z: int = _datum.z + cell.y * PITCH_U
	var site: int = _column_sites(x, _floors[level], z, _heights[level])
	if site != Cells.CELL_OK:
		return site
	_box[0] = x
	_box[1] = _floors[level]
	_box[2] = z
	_box[3] = x + PITCH_U
	_box[4] = _floors[level] + _heights[level]
	_box[5] = z + PITCH_U
	var code: StringName = (_owner(_terrain) as Terrain).dig_refusal(_box)
	return int(TERRAIN_CODES.get(code, Cells.CELL_OK))


func _column_sites(x: int, floor_u: int, z: int, height: int) -> int:
	"""FINISHED when every quantum of the column is a SUPPORTED_VOID Site, OCCUPIED when any is a Site, else OK."""
	var sites: Sites = _owner(_sites) as Sites
	var claimed: int = 0
	var finished: int = 0
	for y: int in range(floor_u, floor_u + height, PITCH_U):
		var site: Vector2i = sites.site_at(Vector3i(x, y, z))
		if site == Sites.NULL_REF:
			continue
		claimed += 1
		if sites.phase_into(site, _phase) and _phase.value == Sites.SUPPORTED_VOID:
			finished += 1
	@warning_ignore("integer_division") var quanta: int = height / PITCH_U
	if claimed == 0:
		return Cells.CELL_OK
	return Cells.CELL_FINISHED if finished == quanta else Cells.CELL_OCCUPIED


func _owner_revisions() -> Vector2i:
	"""The space owner's and the terrain's revisions now ((-1, -1) unbound)."""
	var space: Object = _owner(_space)
	var terrain: Terrain = _owner(_terrain) as Terrain
	return Vector2i(int(space.call(&"revision")) if space != null else -1,
		terrain.content_revision() if terrain != null else -1)


func _drop_cache() -> void:
	"""Every level's cached codes forgotten; the revision moves."""
	for level: int in _cache.size():
		_cache[level] = PackedByteArray()
	_revision += 1


static func _owner(handle: WeakRef) -> Object:
	"""A weakly held owner, or null once it is gone."""
	return handle.get_ref() if handle != null else null
