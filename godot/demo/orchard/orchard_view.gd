extends Node3D
## THE ORCHARD DRAWN (decision 0671). Presentation only: it reads the model and the jobs and writes nothing they read.
##
## NO NEW ART (no paid generation; the brief): every piece is a staged model the village already has.
##   * A FRUIT TREE is the staged oak (world.make_piece, so it sits in the ground as the woods' do), drawn small: the
##     oak SAPLING model for its first half-year, then the oak at a growing share of ORCHARD_TREE_SIZE (the size a
##     mature fruit tree is drawn at -- a little over a third of a woods oak, about 4.7 m, so that crowns on §5.6's 8 m
##     blocks stand apart), the old trees a little larger. It is one of the
##     season's trees (season_view.gd OTHER OWNERS' TREES, kind season_look.gd KIND_FRUIT): fresh leaf with white or
##     pink-white blossom in spring, its autumn colour, bare boughs in winter. Its FRUIT is the tree shader's fruit
##     speckle (season_leaves.gdshaderinc `leaf_fruit`): green from late summer, red apples or yellow pears in autumn
##     until the tree is picked, fewer on a tree in poor health.
##   * THE HEDGE: the raspberry canes and the bramble are the oak's crown drawn small and let into the ground to its
##     lowest boughs (seasonal, berries as the fruit speckle while §5.5 lets them be picked), the strawberry bed the
##     staged strawberry plant.
##   * An EMPTY SITE: four brass pegs at its block's corners joined by a brass string, and a stake where its tree will
##     stand.
##   * A BASKET STAND: the staged baskets, with fruit (small spheres) heaped as its store fills.
##   * THE NURSERY: a sapling basket for each sapling it holds or grows.
##   * THE GROVE: a sage ring on the ground round it while it is protected.
##   * A carrier holds a basket on its carry walk; a load set down shows as a basket where it lies.
## The ART GAP (reported): no fruit-tree, berry-bush or fruit model is staged; these stand-ins are the oak's.
##
## Per frame it compares the model's and the jobs' revisions and the calendar's hour, and allocates nothing; on a change
## it writes each tree's size, its fruit and the stands, the nursery and the ring.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const TREE_KEY: StringName = &"oak_mature"
const SAPLING_KEY: StringName = &"oak_sapling"
const STRAWBERRY_SCENE: String = "res://demo/assets/plants/plant_strawberry.glb"
## A mature fruit tree's drawn size (a share of the woods oak's 13 m), a just-grown one's, and the old trees'.
const ORCHARD_TREE_SIZE: float = 0.36
const YOUNG_TREE_SIZE: float = 0.18
const OLD_TREE_SIZE: float = 0.4
const SAPLING_SIZES: Vector2 = Vector2(0.35, 0.9)
## A bush is the oak's crown drawn small and let down into the ground to its lowest boughs (no trunk shows).
const BUSH_SIZE: float = 0.15
const BUSH_SINK_M: float = 0.95
## The staged strawberry plant (0.84 m as modelled) drawn knee-high to a mouse.
const STRAWBERRY_SCALE: float = 0.5
const PARAM_FRUIT: StringName = &"leaf_fruit"
const PARAM_BLOSSOM_TINT: StringName = &"leaf_blossom_tint"
## Each species' blossom (apple pink-white, pear white) and ripe fruit; the bushes' berries; green unripe fruit.
## (a: the share of leaf cells in flower -- an orchard tree flowers far more thickly than an oak's catkins.)
const BLOSSOM: Array[Color] = [Color(1.0, 0.84, 0.88, 0.42), Color(0.98, 0.97, 0.93, 0.42)]
const BUSH_BLOSSOM: Color = Color(0.97, 0.95, 0.93, 0.22)
const RIPE: Array[Color] = [Color(0.72, 0.13, 0.09), Color(0.74, 0.7, 0.26)]
const BERRY: Array[Color] = [Color(0.74, 0.08, 0.16), Color(0.14, 0.05, 0.16)]
const UNRIPE: Color = Color(0.42, 0.56, 0.2)
## Fruit shows from this day of summer, swelling to UNRIPE_SHARE by its end; a tree in poor health bears fewer.
const FRUIT_FROM_DAY: float = 5.0
const UNRIPE_SHARE: float = 0.55
const HEALTH_SHOWN_MIN: float = 0.35
const PEG_H: float = 0.45
## The brass string round an empty block: its width and height off the ground.
const STRING_W: float = 0.09
const STRING_Y: float = 0.12
const STAKE_H: float = 0.9
const RING_W: float = 0.14
const FRUIT_POOL: int = 30
const NURSERY_POOL: int = 6
const LOAD_POOL: int = 4

var _model: ModelScript = null
var _jobs: JobsScript = null
var _make: Callable = Callable()
var _props: PropsScript = null
var _cast: DemoCastScript = null
var _pantry: PantryScript = null
var _calendar: CalendarScript = null
var _trees: Array[Node3D] = []
var _tree_key: Array[StringName] = []
var _tree_base: PackedFloat32Array = PackedFloat32Array()
var _bushes: Array[Node3D] = []
var _pegs: Array[Node3D] = []
var _stand_fruit: Array[MultiMeshInstance3D] = []
var _nursery: Array[MeshInstance3D] = []
var _loads: Array[MeshInstance3D] = []
var _ring: MeshInstance3D = null
var _held: Array[StringName] = []
var _holding: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _season_revision: int = 0
var _seen_model: int = -1
var _seen_jobs: int = -1
var _seen_hour: int = -1
var _scratch: IntMath.IntResult = IntMath.IntResult.new()


func configure(model: ModelScript, jobs: JobsScript, make: Callable, props: PropsScript, cast: DemoCastScript,
		pantry: PantryScript, calendar: CalendarScript) -> void:
	"""Draw `model` and `jobs` with the world's `make(key, at, yaw, size) -> Node3D`, the staged `props`, over `cast`'s
	residents, `pantry`'s stands and `calendar`'s season (any but the model may be null in a check)."""
	name = "OrchardView"
	_model = model
	_jobs = jobs
	_make = make
	_props = props
	_cast = cast
	_pantry = pantry
	_calendar = calendar
	_build_sites()
	_build_hedge()
	_build_places()
	if _cast != null:
		_held.resize(_cast.actor_count())
		_held.fill(&"")
	refresh(true)


func _build_sites() -> void:
	"""Each site's tree node slot (made in `_sync_trees`) and its empty-site pegs."""
	_trees.resize(Rules.SITE_COUNT)
	_tree_key.resize(Rules.SITE_COUNT)
	_tree_key.fill(&"")
	_tree_base.resize(Rules.SITE_COUNT)
	for site: int in Rules.SITE_COUNT:
		var pegs := Node3D.new()
		pegs.name = "SitePegs%d" % site
		var rect: Rect2 = Rules.site_rect_m(site)
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]:
			pegs.add_child(_peg(corner, PEG_H))
		pegs.add_child(_peg(Rules.site_centre_m(site), STAKE_H))
		pegs.add_child(_outline(rect))
		add_child(pegs)
		_pegs.append(pegs)


func _peg(at: Vector2, height: float) -> MeshInstance3D:
	"""A brass peg standing at `at`, `height` tall."""
	var peg := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.05
	mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.BRASS
	mesh.material = material
	peg.mesh = mesh
	peg.position = Vector3(at.x, height * 0.5, at.y)
	return peg


func _outline(rect: Rect2) -> MeshInstance3D:
	"""A brass string round an empty block, a hand's breadth off the ground (one mesh of four thin bars)."""
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.BRASS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for k: int in 4:
		_bar(mesh, corners[k], corners[(k + 1) % 4])
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return line


static func _bar(mesh: ImmediateMesh, a: Vector2, b: Vector2) -> void:
	"""One flat bar STRING_W wide from `a` to `b`, STRING_Y up (two triangles, facing up)."""
	var side: Vector2 = (b - a).normalized().orthogonal() * STRING_W * 0.5
	var quad: Array[Vector2] = [a - side, b - side, b + side, a + side]
	for k: int in [0, 1, 2, 0, 2, 3]:
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(Vector3(quad[k].x, STRING_Y, quad[k].y))


func _build_hedge() -> void:
	"""The canes and the bramble (knee-high oak saplings: seasonal, berries as their fruit speckle) and the strawberry
	bed (the staged strawberry plant, a few together)."""
	for bush: int in 2:
		var node: Node3D = _make_piece(TREE_KEY, Rules.BUSH_AT[bush], 0.6 + 1.7 * bush, BUSH_SIZE)
		if node != null:
			node.position.y -= BUSH_SINK_M
			add_child(node)
		_bushes.append(node)
	var scene: PackedScene = load(STRAWBERRY_SCENE) as PackedScene if ResourceLoader.exists(STRAWBERRY_SCENE) else null
	for k: int in 5:
		@warning_ignore("integer_division") var row: int = k / 3
		var at: Vector2 = Rules.BUSH_AT[2] + Vector2(0.45 * float(k % 3) - 0.45, 0.5 * float(row) - 0.25)
		var plant: Node3D = scene.instantiate() as Node3D if scene != null else _peg(at, 0.2)
		if scene != null:
			plant.transform = Transform3D(Basis(Vector3.UP, 1.3 * float(k)).scaled(Vector3.ONE * STRAWBERRY_SCALE),
				Vector3(at.x, 0.0, at.y))
		add_child(plant)


func _make_piece(key: StringName, at: Vector2, yaw: float, size: float) -> Node3D:
	"""A staged model from the world (null without one: a check)."""
	return _make.call(key, at, yaw, size) as Node3D if _make.is_valid() else null


func _build_places() -> void:
	"""The stands' baskets and heaped fruit, the nursery's sapling baskets, the grove's ring and the set-down loads."""
	for group: int in Rules.GROUP_COUNT:
		var at: Vector2 = Rules.STAND_AT[group]
		for k: int in 3:
			_place_prop(&"basket", at + Vector2(0.55 * float(k) - 0.55, 0.0), 0.4 * float(k))
		_stand_fruit.append(_fruit_heap(at))
	for k: int in NURSERY_POOL:
		var basket: MeshInstance3D = _place_prop(&"sapling_basket", Rules.NURSERY_AT + Vector2(0.5 * float(k) - 1.25, 0.0),
			0.3 * float(k))
		_nursery.append(basket)
	for k: int in LOAD_POOL:
		var basket: MeshInstance3D = _place_prop(&"basket", Vector2.ZERO, 0.0)
		if basket != null:
			basket.visible = false
		_loads.append(basket)
	_ring = _make_ring()


func _place_prop(key: StringName, at: Vector2, yaw: float) -> MeshInstance3D:
	"""A staged prop standing at `at` (null without the props: a check)."""
	if _props == null:
		return null
	var prop: MeshInstance3D = _props.instance(key)
	prop.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.y)) * _props.fit_of(key)
	add_child(prop)
	return prop


func _fruit_heap(at: Vector2) -> MultiMeshInstance3D:
	"""FRUIT_POOL small spheres heaped over a stand's baskets, as many shown as its store is full."""
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.17
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.6
	sphere.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = sphere
	multi.instance_count = FRUIT_POOL
	multi.visible_instance_count = 0
	for k: int in FRUIT_POOL:
		var spot := Vector2.from_angle(2.39996 * float(k)) * 0.12 * sqrt(float(k))
		@warning_ignore("integer_division") var layer: int = k / 10
		multi.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(at.x + spot.x - 0.55 + 0.55 * float(k % 3),
			0.42 + 0.08 * float(layer), at.y + spot.y * 0.6)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	add_child(node)
	return node


func _make_ring() -> MeshInstance3D:
	"""The grove's sage ring on the ground (shown while it is protected)."""
	var torus := TorusMesh.new()
	torus.inner_radius = Rules.GROVE_RADIUS_M - RING_W
	torus.outer_radius = Rules.GROVE_RADIUS_M
	torus.rings = 72
	torus.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.SAGE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.name = "GroveRing"
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.05, 1.0)), Vector3(Rules.GROVE_AT.x, 0.04,
		Rules.GROVE_AT.y))
	add_child(ring)
	return ring


# --- following the model ---------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Follow the model, the jobs and the hour (see the header)."""
	refresh(false)


func refresh(force: bool) -> void:
	"""Redraw what changed: the trees and their fruit, the stands, the nursery and the ring on a model change or a new
	hour; who holds a basket and the set-down loads on a jobs change."""
	if _model == null:
		return
	var hour: int = _calendar.hour_index() if _calendar != null else 0
	if force or _model.revision != _seen_model or hour != _seen_hour:
		_seen_model = _model.revision
		_seen_hour = hour
		_sync_trees()
		_sync_fruit()
		_sync_places()
	if _jobs != null and (force or _jobs.revision != _seen_jobs):
		_seen_jobs = _jobs.revision
		_follow_held()
		_follow_loads()
		for group: int in Rules.GROUP_COUNT:
			_heap(group)


func _sync_trees() -> void:
	"""Each site's tree drawn at its age's model and size (a model change makes a new node: the season's revision moves),
	or its pegs when it has none."""
	for site: int in Rules.SITE_COUNT:
		var has: bool = _model.has_tree(site)
		_pegs[site].visible = not has
		if not has:
			if _trees[site] != null:
				_trees[site].queue_free()
				_trees[site] = null
				_season_revision += 1
			continue
		var age: int = _model.age_of(site)
		var key: StringName = SAPLING_KEY if age < Rules.HALF_YEAR_DAYS and _model.inherited[site] == 0 else TREE_KEY
		if key != _tree_key[site] or _trees[site] == null:
			_replace_tree(site, key)
		_size_tree(site, key, tree_size(site))


func tree_size(site: int) -> float:
	"""The share of its model a tree is drawn at (see the header)."""
	if _model.inherited[site] == 1:
		return OLD_TREE_SIZE
	var age: int = _model.age_of(site)
	var species: int = _model.species_of(site)
	if age < Rules.HALF_YEAR_DAYS:
		return lerpf(SAPLING_SIZES.x, SAPLING_SIZES.y, float(age) / float(Rules.HALF_YEAR_DAYS))
	return lerpf(YOUNG_TREE_SIZE, ORCHARD_TREE_SIZE, Rules.grown_share(age, species))


func _replace_tree(site: int, key: StringName) -> void:
	"""Site `site`'s tree node made afresh as model `key` (its base scale noted)."""
	if _trees[site] != null:
		_trees[site].queue_free()
	var centre: Vector2 = Rules.site_centre_m(site)
	var node: Node3D = _make_piece(key, centre, 0.9 + 1.1 * float(site), 1.0)
	_trees[site] = node
	_tree_key[site] = key
	_tree_base[site] = node.transform.basis.get_scale().x if node != null else 1.0
	if node != null:
		add_child(node)
	_season_revision += 1


func _size_tree(site: int, key: StringName, size: float) -> void:
	"""Tree `site` drawn at `size` of its model, let into the ground as the world lets that size (world_sizes.gd)."""
	var node: Node3D = _trees[site]
	if node == null:
		return
	var centre: Vector2 = Rules.site_centre_m(site)
	var yaw: float = 0.9 + 1.1 * float(site)
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _tree_base[site] * size),
		Vector3(centre.x, -Sizes.sink_m(key, size), centre.y))


func _sync_fruit() -> void:
	"""Each tree's blossom colour and fruit speckle, each bush's berries (see the header)."""
	var now: SimClock.Calendar = _calendar.now() if _calendar != null else null
	var season: int = now.season if now != null else 0
	var day: float = LookScript.day_in_season(now.season_day, now.tick_of_day) if now != null else 0.0
	for site: int in Rules.SITE_COUNT:
		if _trees[site] == null:
			continue
		var species: int = _model.species_of(site)
		var share: float = fruit_share(site, season, day)
		var ripe: float = 1.0 if season == LookScript.AUTUMN else 0.0
		var colour: Color = UNRIPE.lerp(RIPE[species], ripe)
		_write(_trees[site], PARAM_BLOSSOM_TINT, BLOSSOM[species])
		_write(_trees[site], PARAM_FRUIT, Color(colour.r, colour.g, colour.b, share))
	var berries: float = berry_share(season)
	for bush: int in _bushes.size():
		if _bushes[bush] != null:
			_write(_bushes[bush], PARAM_BLOSSOM_TINT, BUSH_BLOSSOM)
			_write(_bushes[bush], PARAM_FRUIT, Color(BERRY[bush].r, BERRY[bush].g, BERRY[bush].b, berries))


func fruit_share(site: int, season: int, day: float) -> float:
	"""How much fruit tree `site` shows: none unless it bears this year and is not yet picked; swelling green from late
	summer, full and ripe through autumn; fewer on a tree in poor health."""
	if not _model.has_tree(site) or season == LookScript.SPRING or season == LookScript.WINTER:
		return 0.0
	var today: int = _model.today_hint
	var next: int = _model.next_harvest_day(site, today)
	if next == 0 or Hive.year_of_day(next) != Hive.year_of_day(today):
		return 0.0
	var health: float = lerpf(HEALTH_SHOWN_MIN, 1.0, float(_model.health_of(site)) / float(Hive.HEALTH_MAX))
	if season == LookScript.SUMMER:
		return UNRIPE_SHARE * smoothstep(FRUIT_FROM_DAY, LookScript.DAYS_PER_SEASON, day) * health
	return health


func berry_share(season: int) -> float:
	"""How many berries the hedge shows: its stock above the floor while §5.5 lets it be picked, none when dormant."""
	var available: int = _model.berries_available_milli(season)
	var room: int = Rules.HEDGE_CAPACITY_MILLI - Rules.berry_floor_milli()
	return clampf(float(available) / float(room), 0.0, 1.0)


static func _write(node: Node, param: StringName, value: Color) -> void:
	"""An instance parameter on every mesh at or under `node`."""
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).set_instance_shader_parameter(param, value)
	for child: Node in node.get_children():
		_write(child, param, value)


func _sync_places() -> void:
	"""The stands' heaped fruit, the nursery's sapling baskets and the grove's ring."""
	for group: int in Rules.GROUP_COUNT:
		_heap(group)
	var held: int = _model.saplings[Rules.APPLE] + _model.saplings[Rules.PEAR] \
		+ _model.plan_count(ModelScript.PLAN_GROWING) + _model.plan_count(ModelScript.PLAN_READY)
	for k: int in _nursery.size():
		if _nursery[k] != null:
			_nursery[k].visible = k < held
	if _ring != null:
		_ring.visible = _model.grove_protected


func _heap(group: int) -> void:
	"""Group `group`'s stand heaped by how full its store is, coloured by what it holds most of."""
	var multi: MultiMesh = _stand_fruit[group].multimesh
	if _pantry == null or not _pantry.storage.index_of_id_into(Rules.STAND_IDS[group], _scratch):
		multi.visible_instance_count = 0
		return
	var at: int = _scratch.value
	var used: int = _pantry.used_milli_of(at)
	multi.visible_instance_count = mini(FRUIT_POOL, ceili(float(FRUIT_POOL) * float(used) / float(Rules.STAND_CAPACITY_U * 1000)))
	var colour: Color = _stand_colour(at)
	for k: int in multi.visible_instance_count:
		multi.set_instance_color(k, colour.darkened(0.12 * float(k % 3)))


func _stand_colour(at: int) -> Color:
	"""The colour of what stand location `at` holds most of."""
	var best: int = Catalog.ITEM_APPLE
	for item: int in range(Catalog.FIRST_FRUIT, Catalog.FIRST_BERRY + Catalog.BERRY_COUNT):
		if _pantry.milli_at(item, at) > _pantry.milli_at(best, at):
			best = item
	return Catalog.ITEM_SWATCH[best]



# --- the carriers ----------------------------------------------------------------------------------------------------------

func _follow_held() -> void:
	"""Each worker with a load in hand holds a basket; whoever held one and no longer does drops it."""
	if _cast == null or _props == null:
		return
	_next.resize(0)
	for j: int in JobsScript.MAX_JOBS:
		var who: int = _jobs.worker[j]
		if _jobs.in_hand(j) and who >= 0 and who < _held.size():
			_show_held(who, &"basket")
			_next.append(who)
	for who: int in _holding:
		if not _next.has(who):
			_show_held(who, &"")
	var swap: PackedInt32Array = _holding
	_holding = _next
	_next = swap


func _show_held(who: int, key: StringName) -> void:
	"""Resident `who` holds the model `key` (&"": nothing)."""
	if _held[who] == key:
		return
	var actor := _cast.actor(who) as DemoActorScript
	if key == &"":
		actor.drop_held()
	else:
		var bound: AABB = _props.drawn_bound(key)
		actor.hold(_props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key))
	_held[who] = key


func _follow_loads() -> void:
	"""A load set down where its carrier was called away shows as a basket there."""
	var used: int = 0
	for j: int in JobsScript.MAX_JOBS:
		if used >= _loads.size() or _loads[used] == null:
			break
		if _jobs.carrying(j) and _jobs.load_at[j].is_finite():
			var at: Vector2 = _jobs.load_at[j]
			_loads[used].transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y)) * _props.fit_of(&"basket")
			_loads[used].visible = true
			used += 1
	for k: int in range(used, _loads.size()):
		if _loads[k] != null:
			_loads[k].visible = false


# --- the season's trees (season_view.gd OTHER OWNERS' TREES) -----------------------------------------------------------------

func season_tree_count() -> int:
	"""The fruit trees' and the two bushes' slots."""
	return Rules.SITE_COUNT + _bushes.size()


func season_tree_node(i: int) -> Node3D:
	"""Slot `i`'s node (null: no tree there now)."""
	return _trees[i] if i < Rules.SITE_COUNT else _bushes[i - Rules.SITE_COUNT]


func season_tree_kind(_i: int) -> int:
	"""Every one is a fruit tree (season_look.gd KIND_FRUIT)."""
	return LookScript.KIND_FRUIT


func season_tree_at(i: int) -> Vector2:
	"""Where slot `i` stands (its hash: its own pace through the seasons)."""
	return Rules.site_centre_m(i) if i < Rules.SITE_COUNT else Rules.BUSH_AT[i - Rules.SITE_COUNT]


func season_trees_revision() -> int:
	"""Bumped whenever a tree's node is made or replaced."""
	return _season_revision


func tree_node(site: int) -> Node3D:
	"""Site `site`'s tree node (checks; null: none)."""
	return _trees[site]


func pegs_shown(site: int) -> bool:
	"""Whether site `site`'s pegs are drawn (checks)."""
	return _pegs[site].visible


func heap_count(group: int) -> int:
	"""How much fruit group `group`'s stand shows (checks)."""
	return _stand_fruit[group].multimesh.visible_instance_count


func ring_shown() -> bool:
	"""Whether the grove's ring is drawn (checks)."""
	return _ring != null and _ring.visible
