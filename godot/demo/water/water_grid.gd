extends RefCounted
## The grid the water's meshes are built on: fine (0.5 m) where there is water or bank, coarse far
## from it, and one field sample per vertex. Decision 0196 (live demo), water foundation.
##
## PRESENTATION. The grid is a tensor product of X lines and Z lines, so every mesh built on it --
## the carved ground, the bank skirt, the water surfaces -- shares vertices exactly and has no
## T-junction cracks. Each vertex is sampled ONCE from the integer map (`WaterMap.sample_into`), and
## far vertices (`is_near_water` false) are flat and dry without a field evaluation. Built once, at
## `DemoWater.build()`; nothing here runs per frame.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")

## Grid spacing in metres: fine by the water, coarser along the far stream, coarse elsewhere.
const FINE_M: float = 0.5
const FAR_FINE_M: float = 1.0
const COARSE_M: float = 8.0
## Beyond this |z| (m) the fine spacing relaxes to FAR_FINE_M: the stream far into the woods.
const NEAR_Z_M: float = 45.0

var xs: PackedFloat32Array = PackedFloat32Array()
var zs: PackedFloat32Array = PackedFloat32Array()
## Per vertex, index `j * xs.size() + i`: the field in u.
var margin_u: PackedInt32Array = PackedInt32Array()
var depth_u: PackedInt32Array = PackedInt32Array()
var ground_u: PackedInt32Array = PackedInt32Array()
var body: PackedInt32Array = PackedInt32Array()
var flow_x: PackedInt32Array = PackedInt32Array()
var flow_z: PackedInt32Array = PackedInt32Array()


func build(map: WaterMapScript, half_size_m: float) -> void:
	"""Lay the grid over [-half_size_m, half_size_m]^2 and sample `map` at every vertex."""
	var x_bands: Array[Vector2] = []
	var z_bands: Array[Vector2] = []
	_bands(map, x_bands, z_bands)
	xs = _lines(-half_size_m, half_size_m, x_bands, false)
	zs = _lines(-half_size_m, half_size_m, z_bands, true)
	var count: int = xs.size() * zs.size()
	margin_u.resize(count)
	depth_u.resize(count)
	ground_u.resize(count)
	body.resize(count)
	flow_x.resize(count)
	flow_z.resize(count)
	_sample(map)


func index(i: int, j: int) -> int:
	"""The vertex index of X line `i` and Z line `j`."""
	return j * xs.size() + i


func position_m(i: int, j: int) -> Vector2:
	"""Vertex (i, j) in metres (x, z)."""
	return Vector2(xs[i], zs[j])


func _bands(map: WaterMapScript, x_bands: Array[Vector2], z_bands: Array[Vector2]) -> void:
	"""The merged X and Z extents (m) of every primitive's reach, where the grid is fine."""
	for i: int in map.segment_count():
		var s: PackedInt32Array = map.segment(i)
		var reach: float = Rules.to_m(maxi(s[4], s[5]) + map.bank_run_u()) + 1.0
		_merge(x_bands, Vector2(Rules.to_m(mini(s[0], s[2])) - reach, Rules.to_m(maxi(s[0], s[2])) + reach))
		_merge(z_bands, Vector2(Rules.to_m(mini(s[1], s[3])) - reach, Rules.to_m(maxi(s[1], s[3])) + reach))


static func _merge(bands: Array[Vector2], band: Vector2) -> void:
	"""Add `band` (lo, hi) to `bands`, merging every band it overlaps, and keep them sorted."""
	var merged := band
	for k: int in range(bands.size() - 1, -1, -1):
		if bands[k].y >= merged.x and bands[k].x <= merged.y:
			merged = Vector2(minf(merged.x, bands[k].x), maxf(merged.y, bands[k].y))
			bands.remove_at(k)
	bands.append(merged)
	bands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)


static func _lines(lo: float, hi: float, bands: Array[Vector2], relax_far: bool) -> PackedFloat32Array:
	"""Grid lines from `lo` to `hi`: every band edge is a line, FINE_M inside a band (FAR_FINE_M
	beyond NEAR_Z_M when `relax_far`), COARSE_M between bands."""
	var out := PackedFloat32Array()
	var at: float = lo
	out.append(at)
	while at < hi - 0.001:
		var step: float = COARSE_M
		var next_edge: float = hi
		for band: Vector2 in bands:
			if at >= band.x - 0.001 and at < band.y - 0.001:
				step = FAR_FINE_M if relax_far and absf(at) > NEAR_Z_M else FINE_M
				next_edge = minf(next_edge, band.y)
			elif band.x > at + 0.001:
				next_edge = minf(next_edge, band.x)
		at = minf(at + step, next_edge)
		out.append(at)
	return out


func _sample(map: WaterMapScript) -> void:
	"""One field sample per vertex; far vertices are flat and dry without evaluating the field."""
	var sample := WaterMapScript.Sample.new()
	for j: int in zs.size():
		for i: int in xs.size():
			var k: int = index(i, j)
			var p := Vector2i(Rules.to_u(xs[i]), Rules.to_u(zs[j]))
			if map.is_near_water(p) and map.sample_into(p, sample):
				margin_u[k] = sample.margin_u
				depth_u[k] = sample.depth_u
				ground_u[k] = sample.ground_u
				body[k] = sample.body
				flow_x[k] = sample.flow.x
				flow_z[k] = sample.flow.y
			else:
				margin_u[k] = -WaterMapScript.FAR_U
				depth_u[k] = 0
				ground_u[k] = 0
				body[k] = 0
				flow_x[k] = 0
				flow_z[k] = 0
