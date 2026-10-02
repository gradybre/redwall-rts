extends "res://test/framework/test_case.gd"
## The seasons on the woods and the ground (demo/seasons/, decision 0551): the season-to-look sampling, the blend
## window and the stagger hash, the evergreen kind, the ground's value groups, the bare boughs, and the view --
## dressing, the calendar and the preview, reduced motion, and no allocation per frame. No staged assets: the
## trees here are small textured meshes made by the suite (a green leaf half, a brown bark half).

const LookScript := preload("res://demo/seasons/season_look.gd")
const SeasonViewScript := preload("res://demo/seasons/season_view.gd")
const BoughsScript := preload("res://demo/seasons/bare_boughs.gd")
const LeavesScript := preload("res://demo/seasons/falling_leaves.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const CanopyScript := preload("res://demo/camera/canopy_clear.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WorldLook := preload("res://demo/world/world_look.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const LabScript := preload("res://demo/ui/demo_lab.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const FADE_SHADER := preload("res://demo/camera/canopy_fade.gdshader")
const IN_LEAF_SHADER := preload("res://demo/seasons/season_tree.gdshader")

const WOOD: int = 60
const EPS: float = 0.0001
const KINDS: Array[int] = [LookScript.KIND_OAK, LookScript.KIND_BEECH, LookScript.KIND_YOUNG_OAK]
const LEAF_SRGB: Color = Color(0.27, 0.33, 0.13)
const BARK_SRGB: Color = Color(0.23, 0.21, 0.16)

var _nodes: Array[Object] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _look: LookScript = LookScript.new()
var _sample: LookScript.Sample = LookScript.Sample.new()
var _materials: Dictionary = {}
var _tree_mesh: ArrayMesh = null


func after_each() -> void:
	"""Free every node a test made; motion back to full."""
	DemoMotion.reduced = false
	for k: int in range(_nodes.size() - 1, -1, -1):
		if is_instance_valid(_nodes[k]) and _nodes[k] is Node:
			_nodes[k].free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


# --- the hash -------------------------------------------------------------------------------------------------

func test_a_trees_hash_is_a_stable_function_of_its_spot() -> void:
	"""The same spot hashes the same, every time and from a copy; spots a few cm apart hash apart."""
	var at := Vector2(-18.25, 7.5)
	assert_equal(LookScript.tree_hash(at), 353071123, "pinned: a change would re-colour every tree")
	assert_true(LookScript.tree_hash(at) != LookScript.tree_hash(at + Vector2(0.05, 0.0)), "5 cm apart: another")
	assert_true(LookScript.tree_hash(at) >= 0 and LookScript.tree_hash(at) <= LookScript.MASK32, "32 bits")


func test_the_hashes_draws_spread_over_the_whole_range() -> void:
	"""Over a grid of spots each of the three draws covers 0..1 in every quarter, and no two draws move together."""
	var quarters: Array[PackedInt32Array] = [PackedInt32Array([0, 0, 0, 0]), PackedInt32Array([0, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0])]
	var same: int = 0
	for x: int in 20:
		for z: int in 20:
			var bits: int = LookScript.tree_hash(Vector2(float(x) * 3.1 - 30.0, float(z) * 2.7 - 25.0))
			for part: int in 3:
				var u: float = LookScript.unit(bits, part)
				assert_true(u >= 0.0 and u < 1.0, "in 0..1")
				quarters[part][int(u * 4.0)] += 1
			same += 1 if absf(LookScript.unit(bits, 0) - LookScript.unit(bits, 1)) < 0.01 else 0
	for part: int in 3:
		for q: int in 4:
			assert_true(quarters[part][q] > 60, "draw %d quarter %d: %d of 400" % [part, q, quarters[part][q]])
	assert_less_than(float(same), 20.0, "the draws are independent")


# --- the trees' looks -------------------------------------------------------------------------------------------

func _at(kind: int, bits: int, season: int, day: float) -> LookScript.Sample:
	"""The suite's sample of one tree."""
	_look.sample_into(kind, bits, season, day, _sample)
	return _sample


func _bits_with_stagger(share: float) -> int:
	"""A hash whose stagger draw is `share` of STAGGER_DAYS (the other draws 0)."""
	return int(share * 1024.0) & 0x3FF


func test_summer_is_the_texture_as_authored() -> void:
	"""Once summer's blend is past, every deciduous tree draws untouched: no tint, no leaf down, no blossom."""
	for kind: int in KINDS:
		for day: float in [5.0, 8.0, 11.9]:
			var look: LookScript.Sample = _at(kind, 123456, LookScript.SUMMER, day)
			assert_equal(look.tint.a, 0.0, "kind %d day %.1f: no tint" % [kind, day])
			assert_equal(look.bare, 0.0, "no leaf down")
			assert_equal(look.blossom, 0.0, "no blossom")


func test_spring_is_fresh_green_with_the_oaks_catkins() -> void:
	"""Mid-spring: the fresh tint on every deciduous kind; catkins on the oaks (old and young), none on the beech."""
	for kind: int in KINDS:
		var look: LookScript.Sample = _at(kind, 0, LookScript.SPRING, 6.0)
		assert_almost_equal(look.tint.a, LookScript.SPRING_MIX, "kind %d takes the fresh green" % kind)
		assert_true(look.tint.g > look.tint.r and look.tint.g > look.tint.b, "a green hue")
		assert_equal(look.bare, 0.0, "in leaf")
	assert_almost_equal(_at(LookScript.KIND_OAK, 0, LookScript.SPRING, 6.0).blossom, 1.0, "the oak's catkins")
	assert_almost_equal(_at(LookScript.KIND_YOUNG_OAK, 0, LookScript.SPRING, 6.0).blossom, 0.6, "fewer on the young")
	assert_equal(_at(LookScript.KIND_BEECH, 0, LookScript.SPRING, 6.0).blossom, 0.0, "none on the beech")
	assert_equal(_at(LookScript.KIND_OAK, 0, LookScript.SPRING, 11.5).blossom, 0.0, "over by spring's end")


func test_autumn_turns_each_tree_its_own_colour_at_its_own_pace() -> void:
	"""Through autumn the tint rises from none toward AUTUMN_MIX, never falls, and its crown stays whole; trees differ
	in colour and in how far they have turned on the same day."""
	var bits: int = LookScript.tree_hash(Vector2(4.0, -9.0))
	var last: float = -1.0
	for step: int in 25:
		var look: LookScript.Sample = _at(LookScript.KIND_OAK, bits, LookScript.AUTUMN, float(step) * 0.5)
		assert_true(look.tint.a >= last - EPS, "day %.1f: the turn never goes back" % (float(step) * 0.5))
		assert_equal(look.bare, 0.0, "the crown is whole")
		last = look.tint.a
	assert_almost_equal(last, LookScript.AUTUMN_MIX, "fully turned by autumn's end")
	var colours: Dictionary = {}
	var turns: Dictionary = {}
	for k: int in 40:
		var other: int = LookScript.tree_hash(Vector2(float(k) * 1.7, float(k) * -2.3))
		colours[LookScript.autumn_colour(LookScript.KIND_BEECH, other)] = true
		turns[snappedf(_at(LookScript.KIND_BEECH, other, LookScript.AUTUMN, 4.0).tint.a, 0.05)] = true
	assert_true(colours.size() >= 3, "several colours across the woods: %d" % colours.size())
	assert_true(turns.size() >= 4, "and several stages on one day: %d" % turns.size())


func test_a_trees_pace_draw_sets_how_fast_it_turns() -> void:
	"""Two trees alike but for their pace draw: on autumn's day 4 the quick one has turned further."""
	var quick: int = 0
	var slow: int = 0x3FF << 20
	assert_true(_at(LookScript.KIND_OAK, quick, LookScript.AUTUMN, 4.0).tint.a
		> _at(LookScript.KIND_OAK, slow, LookScript.AUTUMN, 4.0).tint.a + 0.1, "the quick one ahead")


func test_blossom_eases_in_with_springs_blend() -> void:
	"""Inside spring's blend the catkins are the blend of none (winter's end) and spring's own."""
	var day: float = 1.5
	var own: float = _at(LookScript.KIND_OAK, 0, LookScript.SPRING, LookScript.BLEND_DAYS + 3.0).blossom
	assert_true(own > 0.9, "spring's own: full")
	var expected: float = lerpf(0.0, LookScript.BLOSSOM_PEAK[LookScript.KIND_OAK] * 0.5, LookScript.blend_weight(day))
	assert_almost_equal(_at(LookScript.KIND_OAK, 0, LookScript.SPRING, day).blossom, expected, "blended at day 1.5")


func test_the_autumn_colours_include_red_only_for_a_few() -> void:
	"""RED is the top RED_SHARE of the colour draw; the rest are the kind's own three."""
	assert_equal(LookScript.autumn_colour(LookScript.KIND_OAK, 0x3FF << 10), LookScript.RED, "the top draw: red")
	assert_equal(LookScript.autumn_colour(LookScript.KIND_OAK, 0), LookScript.AUTUMN_OAK[0], "the bottom: the oak's first")
	assert_equal(LookScript.autumn_colour(LookScript.KIND_BEECH, 0), LookScript.AUTUMN_BEECH[0], "the beech's first")
	var just_below: int = int((1.0 - LookScript.RED_SHARE) * 1024.0 - 2.0) << 10
	assert_equal(LookScript.autumn_colour(LookScript.KIND_OAK, just_below), LookScript.AUTUMN_OAK[2], "below red: the last")


func test_winter_is_bare_but_for_the_trees_that_keep_dry_leaves() -> void:
	"""Mid-winter: bare (every leaf down) unless the tree's draw keeps its dry leaves (marcescence), which keep
	MARCESCENT_KEEP of them; most young oaks keep theirs, few old oaks."""
	var bare_bits: int = 0x3FF << 10
	for kind: int in KINDS:
		assert_equal(_at(kind, bare_bits, LookScript.WINTER, 6.0).bare, 1.0, "kind %d: bare" % kind)
		assert_almost_equal(_at(kind, bare_bits, LookScript.WINTER, 6.0).tint.a, 1.0, "what is left is dry")
	assert_almost_equal(_at(LookScript.KIND_YOUNG_OAK, 0, LookScript.WINTER, 6.0).bare, 1.0 - LookScript.MARCESCENT_KEEP,
		"a keeping tree keeps some")
	var keeping: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for k: int in 200:
		var bits: int = LookScript.tree_hash(Vector2(float(k) * 0.9, float(k % 13) * 1.3))
		for i: int in 3:
			keeping[i] += 1 if _at(KINDS[i], bits, LookScript.WINTER, 6.0).bare < 1.0 else 0
	assert_true(keeping[0] < keeping[1] and keeping[1] < keeping[2], "oak < beech < young oak: %s" % keeping)


func test_the_thaw_leafs_the_woods_out_by_springs_first_day() -> void:
	"""Winter's last days ease bare into spring's first look, so spring opens in leaf; spring's own blend then
	changes nothing (THE THAW)."""
	for k: int in 30:
		var bits: int = LookScript.tree_hash(Vector2(float(k) * 2.1, 3.0))
		assert_equal(_at(LookScript.KIND_OAK, bits, LookScript.WINTER, LookScript.THAW_FROM_DAY).bare,
			_at(LookScript.KIND_OAK, bits, LookScript.WINTER, 6.0).bare, "tree %d: still bare at the thaw's start" % k)
		var opening: LookScript.Sample = _at(LookScript.KIND_OAK, bits, LookScript.SPRING, 0.0)
		assert_equal(opening.bare, 0.0, "tree %d: in leaf on Spring 1" % k)
		assert_almost_equal(opening.tint.a, LookScript.SPRING_MIX, "and fresh green")
	var first: int = _bits_with_stagger(0.0)
	var mid_thaw: float = _at(LookScript.KIND_OAK, first, LookScript.WINTER, LookScript.THAW_FROM_DAY + LookScript.THAW_DAYS * 0.5).bare
	assert_true(mid_thaw > 0.0 and mid_thaw < 1.0, "half way through the thaw, half bare: %.2f" % mid_thaw)


func test_a_season_blends_in_over_its_window_from_the_last_seasons_end() -> void:
	"""Summer's first days: a tree starts from spring's end look and reaches summer's own by BLEND_DAYS after its
	staggered start, never a swap; the blend weight is 0 before the start and 1 after the window."""
	var bits: int = _bits_with_stagger(0.0)
	assert_almost_equal(_at(LookScript.KIND_BEECH, bits, LookScript.SUMMER, 0.0).tint.a, LookScript.SPRING_MIX,
		"day 0: still spring's fresh green")
	var last: float = 2.0
	for step: int in 11:
		var a: float = _at(LookScript.KIND_BEECH, bits, LookScript.SUMMER, float(step) * LookScript.BLEND_DAYS / 10.0).tint.a
		assert_true(a <= last + EPS, "step %d: it eases out" % step)
		assert_true(step == 0 or step == 10 or (a > 0.0 and a < LookScript.SPRING_MIX), "step %d: between" % step)
		last = a
	assert_equal(last, 0.0, "summer's own by the window's end")
	assert_equal(LookScript.blend_weight(-0.5), 0.0, "before the start")
	assert_equal(LookScript.blend_weight(LookScript.BLEND_DAYS + 0.01), 1.0, "after the window")
	assert_almost_equal(LookScript.blend_weight(LookScript.BLEND_DAYS * 0.5), 0.5, "eased about the middle")


func test_the_stagger_starts_each_trees_blend_by_its_hash() -> void:
	"""Two trees whose stagger draws differ by half reach the same point of winter's blend STAGGER_DAYS/2 apart."""
	var early: int = _bits_with_stagger(0.0) | (0x3FF << 10)
	var late: int = _bits_with_stagger(0.5) | (0x3FF << 10)
	var shift: float = LookScript.STAGGER_DAYS * 0.5
	for day: float in [0.3, 1.0, 1.7]:
		assert_almost_equal(_at(LookScript.KIND_OAK, late, LookScript.WINTER, day + shift).bare,
			_at(LookScript.KIND_OAK, early, LookScript.WINTER, day).bare, "day %.1f: the same, %.2f d later" % [day, shift])
	assert_true(_at(LookScript.KIND_OAK, late, LookScript.WINTER, 1.0).bare < _at(LookScript.KIND_OAK, early,
		LookScript.WINTER, 1.0).bare, "the late one is behind")
	var last_start: float = LookScript.STAGGER_DAYS * 1023.0 / 1024.0
	assert_equal(_at(LookScript.KIND_OAK, 0x3FF | (0x3FF << 10), LookScript.WINTER, last_start + LookScript.BLEND_DAYS).bare,
		1.0, "the latest tree is through by STAGGER_DAYS + BLEND_DAYS")


func test_evergreens_keep_their_summer_look_all_year() -> void:
	"""The evergreen kind: every season, every day, every hash -- no tint, no leaf down, no blossom."""
	for season: int in 4:
		for step: int in 13:
			for k: int in 5:
				var look: LookScript.Sample = _at(LookScript.KIND_EVERGREEN, LookScript.tree_hash(Vector2(float(k), 1.0)),
					season, float(step))
				assert_true(look.tint.a == 0.0 and look.bare == 0.0 and look.blossom == 0.0,
					"season %d day %d tree %d: unaffected" % [season, step, k])


func test_tints_mix_by_how_much_each_is_taken() -> void:
	"""A blend from the summer tint (amount 0) keeps the other's hue throughout; amounts lerp."""
	var autumn: Color = LookScript.hue(LookScript.GOLD, LookScript.AUTUMN_LIFT, 0.8)
	var half: Color = LookScript.mix_tints(Color(1.0, 1.0, 1.0, 0.0), autumn, 0.5)
	assert_almost_equal(half.a, 0.4, "half the amount")
	assert_true(Color(half.r, half.g, half.b).is_equal_approx(Color(autumn.r, autumn.g, autumn.b)), "the gold's own hue")
	var none: Color = LookScript.mix_tints(Color(1.0, 1.0, 1.0, 0.0), Color(0.2, 0.3, 0.4, 0.0), 0.5)
	assert_true(none.is_equal_approx(Color(1.0, 1.0, 1.0, 0.0)), "two summers: white, no amount")


func test_a_hue_carries_its_colour_at_unit_luminance_times_the_lift() -> void:
	"""hue(): linear rgb over its own luminance, times the lift; the amount in alpha."""
	var tint: Color = LookScript.hue(LookScript.RUSSET, 1.5, 0.3)
	assert_almost_equal(0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b, 1.5, "luminance = the lift")
	assert_almost_equal(tint.a, 0.3, "the amount")
	assert_true(tint.r > tint.g and tint.g > tint.b, "russet: red over green over blue")


# --- the ground ---------------------------------------------------------------------------------------------------

func test_every_seasons_ground_colours_stay_in_their_value_groups() -> void:
	"""DEC-038 (decision 0301): through the whole year, the grass colours stay mid, the litter dark, and the fallen
	leaves' colour (on the grass) mid -- on every day of every season."""
	var ground: LookScript.Ground = LookScript.Ground.new()
	var targets: Dictionary = WorldLook.ground_targets()
	for season: int in 4:
		for step: int in 13:
			_look.ground_into(season, float(step), ground)
			for name: StringName in [&"grass_color", &"grass_sun_color"]:
				var value: float = WorldLook.value_of(LookScript.grass_target(targets[name], ground))
				var group: Vector2 = WorldLook.value_group_of(name)
				assert_true(value >= group.x and value <= group.y, "%s season %d day %d: %.3f" % [name, season, step, value])
			var litter: float = WorldLook.value_of(LookScript.litter_target(targets[&"litter_color"], ground))
			assert_true(litter <= WorldLook.VALUE_DARK.y, "litter season %d day %d: %.3f" % [season, step, litter])
	var fallen: float = WorldLook.value_of(LookScript.FALLEN_LEAVES)
	assert_true(fallen >= WorldLook.VALUE_MID.x and fallen <= WorldLook.VALUE_MID.y, "fallen leaves: mid, with the grass")


func test_the_ground_targets_move_by_their_set_shares() -> void:
	"""grass_target: fresh moves FRESH_GRASS_MIX toward FRESH_GRASS, dry DRY_GRASS_MIX toward DRY_GRASS; the litter
	half way to russet under a full fall of leaves."""
	var ground: LookScript.Ground = LookScript.Ground.new()
	var base := Color(0.3, 0.4, 0.2)
	ground.set_to(1.0, 0.0, 0.0)
	assert_true(LookScript.grass_target(base, ground).is_equal_approx(base.lerp(LookScript.FRESH_GRASS,
		LookScript.FRESH_GRASS_MIX)), "fresh")
	ground.set_to(0.0, 1.0, 1.0)
	assert_true(LookScript.grass_target(base, ground).is_equal_approx(base.lerp(LookScript.DRY_GRASS,
		LookScript.DRY_GRASS_MIX)), "dry")
	assert_true(LookScript.litter_target(base, ground).is_equal_approx(base.lerp(LookScript.LITTER_RUSSET, 0.5)), "litter")


func test_the_ground_eases_from_the_last_seasons_end() -> void:
	"""Summer's first day: the ground is still spring's (fresh); by the blend's end, summer's own."""
	var ground: LookScript.Ground = LookScript.Ground.new()
	_look.ground_into(LookScript.SUMMER, 0.0, ground)
	assert_equal(ground.fresh, 1.0, "day 0: spring's fresh")
	_look.ground_into(LookScript.SUMMER, LookScript.BLEND_DAYS * 0.5, ground)
	assert_almost_equal(ground.fresh, 0.5, "half way")
	_look.ground_into(LookScript.SUMMER, LookScript.BLEND_DAYS, ground)
	assert_equal(ground.fresh, 0.0, "summer's own")


func test_the_grounds_season_follows_the_calendar() -> void:
	"""Spring fresh, summer as authored, autumn's leaves piling up, winter dry with old leaves; the thaw freshens it
	by spring; the tufts' multiply white in summer."""
	var ground: LookScript.Ground = LookScript.Ground.new()
	_look.ground_into(LookScript.SUMMER, 6.0, ground)
	assert_true(ground.fresh == 0.0 and ground.dry == 0.0 and ground.leaves == 0.0, "summer: as authored")
	assert_true(LookScript.tuft_multiply(ground).is_equal_approx(Color.WHITE), "the tufts as authored")
	_look.ground_into(LookScript.SPRING, 6.0, ground)
	assert_equal(ground.fresh, 1.0, "spring: fresh")
	_look.ground_into(LookScript.AUTUMN, 3.0, ground)
	var early: float = ground.leaves
	_look.ground_into(LookScript.AUTUMN, 11.0, ground)
	assert_true(ground.leaves > early and ground.leaves <= LookScript.AUTUMN_LEAVES_MAX, "leaves pile up through autumn")
	_look.ground_into(LookScript.WINTER, 6.0, ground)
	assert_true(ground.dry == 1.0 and absf(ground.leaves - LookScript.WINTER_LEAVES) < EPS, "winter: dry, old leaves")
	_look.ground_into(LookScript.WINTER, 11.99, ground)
	assert_true(ground.fresh > 0.95, "thawed by winter's end")


func test_leaves_fall_from_mid_autumn_into_winters_first_days() -> void:
	"""leaf_drop: none in spring and summer, rising through autumn, dying away early in winter."""
	for day: float in [0.0, 6.0, 11.0]:
		assert_equal(LookScript.leaf_drop(LookScript.SPRING, day), 0.0, "spring")
		assert_equal(LookScript.leaf_drop(LookScript.SUMMER, day), 0.0, "summer")
	assert_equal(LookScript.leaf_drop(LookScript.AUTUMN, 2.0), 0.0, "not in autumn's first days")
	assert_equal(LookScript.leaf_drop(LookScript.AUTUMN, 10.0), 1.0, "late autumn: full")
	assert_equal(LookScript.leaf_drop(LookScript.WINTER, 0.0), 1.0, "winter's first day")
	assert_equal(LookScript.leaf_drop(LookScript.WINTER, 6.0), 0.0, "mid-winter: none")


# --- the bare boughs and the materials ----------------------------------------------------------------------------

func _leaf_bark_texture() -> ImageTexture:
	"""An 8x8 albedo: the left half leaf, the right half bark."""
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y: int in 8:
		for x: int in 8:
			image.set_pixel(x, y, LEAF_SRGB if x < 4 else BARK_SRGB)
	return ImageTexture.create_from_image(image)


func _two_triangle_mesh() -> ArrayMesh:
	"""One mesh, one textured material, a leaf triangle (UVs in the left half) and a bark one (the right)."""
	if _tree_mesh != null:
		return _tree_mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 3, 0), Vector3(1, 3, 0), Vector3(0, 4, 0),
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.05, 0.1), Vector2(0.4, 0.1), Vector2(0.05, 0.9),
		Vector2(0.6, 0.1), Vector2(0.95, 0.1), Vector2(0.6, 0.9)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	_tree_mesh = ArrayMesh.new()
	_tree_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _leaf_bark_texture()
	_tree_mesh.surface_set_material(0, material)
	return _tree_mesh


func test_bare_boughs_keep_the_bark_triangles_and_the_material() -> void:
	"""bark_only: the leaf triangle goes, the bark one stays, the material is the model's own; an untextured mesh
	has none."""
	var bare: ArrayMesh = BoughsScript.bark_only(_two_triangle_mesh())
	assert_not_null(bare, "made")
	var index: PackedInt32Array = bare.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	assert_equal(Array(index), [3, 4, 5], "only the bark triangle")
	assert_true(bare.surface_get_material(0) == _two_triangle_mesh().surface_get_material(0), "the same material")
	var plain := ArrayMesh.new()
	plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _two_triangle_mesh().surface_get_arrays(0))
	plain.surface_set_material(0, StandardMaterial3D.new())
	assert_null(BoughsScript.bark_only(plain), "no texture: none")
	assert_null(BoughsScript.bark_only(null), "no mesh: none")


func test_moss_on_the_roots_is_never_taken_for_leaf() -> void:
	"""A leaf-coloured triangle wholly in the model's bottom ROOTS_SHARE is kept (moss on the roots); just above it,
	it goes."""
	var image: Image = _leaf_bark_texture().get_image()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1.1, 0),
		Vector3(0, 1.3, 0), Vector3(1, 1.3, 0), Vector3(0, 2, 0), Vector3(0, 10, 0), Vector3(0, 10, 1), Vector3(1, 10, 0)])
	var leaf_uv := PackedVector2Array()
	for k: int in 9:
		leaf_uv.append(Vector2(0.1 + 0.02 * float(k % 3), 0.5))
	arrays[Mesh.ARRAY_TEX_UV] = leaf_uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8])
	assert_almost_equal(BoughsScript.roots_top_y(arrays[Mesh.ARRAY_VERTEX]), 1.2, "12 % of 0..10")
	assert_equal(Array(BoughsScript.bark_triangles(arrays, image)), [0, 1, 2], "the root triangle only")


func test_a_triangle_is_bark_unless_its_centre_or_two_corners_are_leaf() -> void:
	"""is_bark: one leaf corner is kept (bark painted at a leaf's edge); a leaf centre or two leaf corners are not."""
	var image: Image = _leaf_bark_texture().get_image()
	var bark := Vector2(0.8, 0.5)
	var leaf := Vector2(0.1, 0.5)
	assert_true(BoughsScript.is_bark(image, bark, bark + Vector2(0.1, 0.0), bark + Vector2(0.0, 0.3)), "all bark")
	assert_true(BoughsScript.is_bark(image, leaf, Vector2(0.9, 0.2), Vector2(0.9, 0.8)), "one leaf corner: kept")
	assert_false(BoughsScript.is_bark(image, leaf, leaf + Vector2(0.0, 0.3), Vector2(0.9, 0.5)), "two: leaf")
	assert_false(BoughsScript.is_bark(image, leaf, leaf + Vector2(0.2, 0.0), leaf + Vector2(0.0, 0.3)), "all leaf")
	assert_true(BoughsScript.is_leaf(image, Vector2(1.1, 0.5)), "UVs wrap")
	assert_true(BoughsScript.is_bark(image, Vector2(0.95, 0.5), Vector2(0.9, 0.2), Vector2(0.9, 0.8)), "bark")
	assert_false(BoughsScript.is_bark(image, Vector2(0.45, 0.2), Vector2(0.45, 0.8), Vector2(0.95, 0.5)),
		"two leaf corners, a bark centre: leaf")


func test_a_leaf_centre_alone_makes_a_triangle_leaf() -> void:
	"""On a leaf stripe down the middle, a triangle with one corner in it and its centre in it is leaf."""
	var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y: int in 10:
		for x: int in 10:
			image.set_pixel(x, y, LEAF_SRGB if x >= 4 and x <= 5 else BARK_SRGB)
	assert_false(BoughsScript.is_bark(image, Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.5, 0.9)), "leaf")


func test_a_blue_texel_is_not_leaf() -> void:
	"""Green over red is not enough: green must also be over blue (a blue-grey texel is not leaf)."""
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6))
	assert_false(BoughsScript.is_leaf(image, Vector2(0.5, 0.5)), "blue over green: not leaf")
	image.fill(Color(0.2, 0.4, 0.3))
	assert_true(BoughsScript.is_leaf(image, Vector2(0.5, 0.5)), "green over both: leaf")


static func _instance_uniforms(path: String) -> PackedStringArray:
	"""A shader's `instance uniform` names in declaration order, its includes expanded where they stand."""
	var names := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("#include"):
			names.append_array(_instance_uniforms(text.get_slice("\"", 1)))
		elif text.begins_with("instance uniform "):
			names.append(text.get_slice(" ", 3).get_slice(":", 0).get_slice("=", 0).strip_edges())
	return names


func test_both_tree_shaders_declare_the_same_instance_uniforms_in_order() -> void:
	"""The per-tree numbers live on the instance and must survive the swap between the two shaders: the same names
	in the same order (Godot gives instance uniforms their slots by declaration order)."""
	var fade: PackedStringArray = _instance_uniforms(FADE_SHADER.resource_path)
	var leafy: PackedStringArray = _instance_uniforms(IN_LEAF_SHADER.resource_path)
	assert_true(fade.has("leaf_tint") and fade.has("fade") and fade.has("crown_base_y"), "read: %s" % fade)
	assert_equal(leafy, fade, "the same, in order")


func test_a_tree_material_carries_its_sources_roughness() -> void:
	"""make_fade_material: the source's roughness lands on `roughness_scale` (the cover include owns `roughness`)."""
	var source := StandardMaterial3D.new()
	source.roughness = 0.37
	var material: ShaderMaterial = CanopyScript.make_fade_material(source)
	assert_almost_equal(float(material.get_shader_parameter(&"roughness_scale")), 0.37, "carried")


func test_each_models_roots_mask_is_its_own_bound() -> void:
	"""Every tree material gets its model's roots mask (bare_boughs.gd roots_mask), in the model's own units, so a
	small, young or fallen tree is masked as a standing one."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var expected: Vector2 = BoughsScript.roots_mask(_two_triangle_mesh())
	assert_almost_equal(expected.x, 0.48, "12 % up a 0..4 bound")
	assert_almost_equal(expected.y, 0.32, "easing over 8 %")
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 10.0, 1.0)
	assert_almost_equal(BoughsScript.roots_mask(box).x, -3.8, "from the bound's foot: 12 % up -5..5")
	for material: ShaderMaterial in view.tree_materials():
		assert_true((material.get_shader_parameter(SeasonViewScript.PARAM_ROOTS) as Vector2).is_equal_approx(expected),
			"set on %s" % material.shader.resource_path)


func test_the_in_leaf_variant_takes_the_tree_shaders_parameters() -> void:
	"""season_tree.gdshader and canopy_fade.gdshader declare the same parameters, so one maker fills both and a tree
	changes variant without a seam."""
	var names: Array[PackedStringArray] = []
	for shader: Shader in [FADE_SHADER, IN_LEAF_SHADER]:
		var list := PackedStringArray()
		for row: Dictionary in shader.get_shader_uniform_list(true):
			list.append(String(row["name"]))
		list.sort()
		names.append(list)
	assert_true(names[0].size() > 10, "parameters read: %d" % names[0].size())
	assert_equal(names[1], names[0], "the same parameters")
	assert_true(names[0].has("snow_cover") and names[0].has("blossom_color"), "the season's own among them")


func test_wear_follows_the_leaves_down() -> void:
	"""wear_for: in leaf -> the in-leaf variant; some down -> the tree shader; all down -> the bare boughs, if made."""
	assert_equal(SeasonViewScript.wear_for(0.0, true), SeasonViewScript.WEAR_LEAFY, "in leaf")
	assert_equal(SeasonViewScript.wear_for(0.3, true), SeasonViewScript.WEAR_FULL, "some down")
	assert_equal(SeasonViewScript.wear_for(1.0, true), SeasonViewScript.WEAR_BARE, "all down")
	assert_equal(SeasonViewScript.wear_for(1.0, false), SeasonViewScript.WEAR_FULL, "all down, no boughs made")
	assert_equal(SeasonViewScript.wear_for(0.9999, true), SeasonViewScript.WEAR_FULL, "not quite all")


# --- the view -----------------------------------------------------------------------------------------------------

func _tree_node() -> Node3D:
	"""A staged-like tree: a node holding one mesh of the suite's two-triangle model."""
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = _two_triangle_mesh()
	root.add_child(mesh)
	return root


func _material_for(mesh: MeshInstance3D) -> ShaderMaterial:
	"""The tree material of `mesh`'s model, one per model (as canopy_clear.gd `fade_material_for`)."""
	var own: Material = CanopyScript.own_material(mesh)
	if not _materials.has(own):
		_materials[own] = CanopyScript.make_fade_material(own as BaseMaterial3D)
	return _materials[own]


static func tick_at(season: int, day: float) -> int:
	"""The calendar tick `day` days into `season` of year 1."""
	return roundi((float(season * SimClock.DAYS_PER_SEASON) + day) * float(SimClock.TICKS_PER_DAY)) - SimClock.CALENDAR_OFFSET_TICKS


func _seasons(calendar: CalendarScript) -> Array:
	"""[view, stand, forest view, tree nodes]: an oak, a beech and a sapling, staged-like, dressed for `calendar`."""
	var trees: Array[Dictionary] = [
		{"key": &"oak_mature", "at": Vector2(-30.0, -4.0), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(-30.0, 8.0), "yaw": 0.0, "size": 1.0},
		{"key": &"oak_sapling", "at": Vector2(-24.0, 20.0), "yaw": 0.0, "size": 1.0},
	]
	var stand := StandScript.new()
	assert_true(stand.bind_into(trees, WOOD, 1, _read), "bound")
	var nodes: Array[Node3D] = []
	for p: Dictionary in trees:
		nodes.append(_keep(_tree_node()) as Node3D)
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var forest := _keep(ViewScript.new()) as ViewScript
	forest.configure(stand, func(p: int) -> Node3D: return nodes[p], world.make_piece, ServicesScript.new().props)
	forest.sync(1, 7)
	var view := _keep(SeasonViewScript.new()) as SeasonViewScript
	view.configure(calendar, null, null, stand, forest, null, _material_for)
	return [view, stand, forest, nodes]


func _mesh_of(node: Node3D) -> MeshInstance3D:
	"""A suite tree's mesh."""
	return node.get_child(0) as MeshInstance3D


func test_every_staged_tree_is_dressed_once_in_its_models_materials() -> void:
	"""Three trees, three dressed meshes, each with its kind and its spot's hash, wearing the in-leaf variant as its
	surface override; one tree material and one in-leaf variant for the one model."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var stand: StandScript = fixture[1]
	var nodes: Array[Node3D] = fixture[3]
	assert_equal(view.dressed_count(), 3, "three meshes")
	var kinds: Array[int] = [LookScript.KIND_OAK, LookScript.KIND_BEECH, LookScript.KIND_YOUNG_OAK]
	for i: int in 3:
		assert_true(view.dressed(i) == _mesh_of(nodes[i]), "tree %d's mesh" % i)
		assert_equal(view.kind_of(i), kinds[i], "tree %d's kind" % i)
		assert_equal(view.hash_of(i), LookScript.tree_hash(stand.at[i]), "tree %d's hash" % i)
		var worn: Material = _mesh_of(nodes[i]).get_surface_override_material(0)
		assert_true(worn is ShaderMaterial and (worn as ShaderMaterial).shader == IN_LEAF_SHADER, "the in-leaf variant")
	assert_equal(view.tree_materials().size(), 2, "one model: its tree material and its in-leaf variant")


func test_the_view_writes_the_calendars_season_to_each_tree() -> void:
	"""On the calendar's hour: each tree's instance numbers are its sample (an autumn oak turned; a winter oak bare in
	the tree shader); the season and the day follow the calendar."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.AUTUMN, 9.5)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	assert_equal(view.season(), LookScript.AUTUMN, "autumn")
	assert_almost_equal(view.day(), 9.5, "day 9.5")
	_look.sample_into(view.kind_of(0), view.hash_of(0), LookScript.AUTUMN, 9.5, _sample)
	var mesh: GeometryInstance3D = view.dressed(0)
	assert_true((mesh.get_instance_shader_parameter(SeasonViewScript.PARAM_TINT) as Color).is_equal_approx(_sample.tint),
		"the tint written")
	assert_true(_sample.tint.a > 0.3, "and turned")
	calendar.tick = tick_at(LookScript.WINTER, 6.5)
	view._process(0.016)
	assert_equal(view.season(), LookScript.WINTER, "on the hour, winter")
	for i: int in view.dressed_count():
		_look.sample_into(view.kind_of(i), view.hash_of(i), LookScript.WINTER, 6.5, _sample)
		assert_almost_equal(float(view.dressed(i).get_instance_shader_parameter(SeasonViewScript.PARAM_BARE)), _sample.bare,
			"tree %d: its bare share" % i)
		var wear: int = SeasonViewScript.wear_for(_sample.bare, false)
		assert_equal(view.wearing(i), wear, "tree %d wears %d" % [i, wear])


func test_a_bare_tree_wears_its_bare_boughs_once_they_are_made() -> void:
	"""prepare_bare makes the model's boughs once; a tree with every leaf down is drawn as them in the tree shader, and
	its own mesh comes back with the thaw."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.WINTER, 6.5)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	assert_equal(view.prepare_bare(), 1, "one model, one set of boughs")
	assert_equal(view.prepare_bare(), 0, "made once")
	var bare: int = -1
	for i: int in view.dressed_count():
		if float(view.dressed(i).get_instance_shader_parameter(SeasonViewScript.PARAM_BARE)) >= 1.0:
			bare = i
	assert_true(bare >= 0, "a bare tree")
	var mesh := view.dressed(bare) as MeshInstance3D
	assert_equal(view.wearing(bare), SeasonViewScript.WEAR_BARE, "wearing its boughs")
	assert_true(mesh.mesh != _two_triangle_mesh() and mesh.mesh.get_surface_count() == 1, "the boughs drawn")
	assert_true((mesh.get_surface_override_material(0) as ShaderMaterial).shader == FADE_SHADER, "in the tree shader")
	calendar.tick = tick_at(LookScript.SPRING, 3.0)
	view._process(0.016)
	assert_equal(view.wearing(bare), SeasonViewScript.WEAR_LEAFY, "spring: in leaf")
	assert_true(mesh.mesh == _two_triangle_mesh(), "its own mesh back")


func test_a_mesh_is_redressed_only_when_its_wear_changes() -> void:
	"""_wear sets a mesh's material and mesh only on a change: a refresh in the same wear leaves them alone."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var mesh := view.dressed(0) as MeshInstance3D
	var other: ShaderMaterial = view._full[0]
	mesh.set_surface_override_material(0, other)
	view.refresh()
	assert_true(mesh.get_surface_override_material(0) == other, "the same wear: untouched")


func test_a_trees_own_material_is_its_meshs_under_any_override() -> void:
	"""own_material: the mesh's glTF material even while a surface override draws it."""
	var mesh := MeshInstance3D.new()
	mesh.mesh = _two_triangle_mesh()
	mesh.set_surface_override_material(0, StandardMaterial3D.new())
	assert_true(CanopyScript.own_material(mesh) == _two_triangle_mesh().surface_get_material(0), "its own")
	mesh.set_surface_override_material(0, null)
	mesh.free()


func test_a_tree_drawn_twice_is_dressed_once() -> void:
	"""A world tree the stand also draws (the same node) is one dressed mesh, not two."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var stand: StandScript = fixture[1]
	var nodes: Array[Node3D] = fixture[3]
	for i: int in 3:
		view._world_nodes.append(nodes[i])
		view._world_keys.append(StandScript.LOOK_KEYS[stand.look[i]])
		view._world_at.append(stand.at[i])
	view._collect()
	assert_equal(view.dressed_count(), 3, "three, not six")


func test_the_hour_alone_refreshes_the_trees() -> void:
	"""With the woods unchanged, the calendar's hour turning is enough to write the new season."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.SUMMER, 6.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	view._process(0.016)
	calendar.tick = tick_at(LookScript.AUTUMN, 9.0)
	view._process(0.016)
	assert_equal(view.season(), LookScript.AUTUMN, "autumn on the hour")


func test_a_falling_trees_upper_part_is_a_new_node() -> void:
	"""The woods' upper part of a falling tree is seen (forest_view.gd `upper_part`) and dressed."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var forest: ViewScript = fixture[2]
	var part := _keep(MeshInstance3D.new()) as MeshInstance3D
	part.mesh = _two_triangle_mesh()
	forest._upper_nodes[1] = part
	assert_true(forest.upper_part(1) == part, "the view says so")
	assert_true(view.nodes_changed(), "a new node")
	view._collect()
	var dressed: bool = false
	for i: int in view.dressed_count():
		dressed = dressed or view.dressed(i) == part
	assert_true(dressed, "dressed")


func test_a_winter_recollect_keeps_each_trees_own_mesh_for_the_thaw() -> void:
	"""A tree replaced mid-winter re-collects every tree while the bare ones wear their boughs; each keeps its own
	model as its own mesh, so the thaw brings their leaves back."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.WINTER, 6.5)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var forest: ViewScript = fixture[2]
	view.prepare_bare()
	view._process(0.016)
	var bare: Array[MeshInstance3D] = []
	for i: int in view.dressed_count():
		if view.wearing(i) == SeasonViewScript.WEAR_BARE:
			bare.append(view.dressed(i) as MeshInstance3D)
	assert_false(bare.is_empty(), "some trees bare")
	forest._tree_nodes[2] = _keep(_tree_node()) as Node3D
	calendar.tick += SimClock.TICKS_PER_HOUR
	view._process(0.016)
	calendar.tick = tick_at(LookScript.SPRING, 3.0)
	view._process(0.016)
	var checked: int = 0
	for mesh: MeshInstance3D in bare:
		for i: int in view.dressed_count():
			if view.dressed(i) == mesh:
				assert_equal(view.wearing(i), SeasonViewScript.WEAR_LEAFY, "in leaf again")
				assert_true(mesh.mesh == _two_triangle_mesh(), "its own mesh back")
				checked += 1
	assert_true(checked > 0, "a tree bare through the re-collect, still dressed")


func test_a_revision_without_a_new_node_writes_nothing() -> void:
	"""A stand revision that makes no node (a trunk hauled) re-collects nothing and leaves the trees' numbers be."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.AUTUMN, 9.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var stand: StandScript = fixture[1]
	view._process(0.016)
	view.dressed(0).set_instance_shader_parameter(SeasonViewScript.PARAM_BARE, 0.5)
	stand.revision += 1
	view._process(0.016)
	assert_almost_equal(float(view.dressed(0).get_instance_shader_parameter(SeasonViewScript.PARAM_BARE)), 0.5,
		"not rewritten")
	calendar.tick += SimClock.TICKS_PER_HOUR
	view._process(0.016)
	assert_almost_equal(float(view.dressed(0).get_instance_shader_parameter(SeasonViewScript.PARAM_BARE)), 0.0,
		"the hour rewrites it")


func test_the_prewarm_draws_each_models_bare_boughs_once() -> void:
	"""begin_prewarm: one sample per model's boughs, in its tree material; end_prewarm lets them go."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	view.prepare_bare()
	view.begin_prewarm()
	var samples: Array[MeshInstance3D] = view._samples.duplicate()
	assert_equal(samples.size(), 1, "one model, one sample")
	assert_true(samples[0].mesh == view._bare_mesh[0] and (samples[0].material_override as ShaderMaterial).shader
		== FADE_SHADER, "its boughs in the tree shader")
	view.end_prewarm()
	assert_true(view._samples.is_empty(), "let go")
	samples[0].free()


func test_a_node_the_woods_replace_is_dressed_on_the_next_hour() -> void:
	"""nodes_changed sees a tree's new node; the view collects it and writes it the season."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.AUTUMN, 9.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var forest: ViewScript = fixture[2]
	assert_false(view.nodes_changed(), "nothing new")
	var fresh := _keep(_tree_node()) as Node3D
	forest._tree_nodes[0] = fresh
	assert_true(view.nodes_changed(), "a new node")
	calendar.tick += SimClock.TICKS_PER_HOUR
	view._process(0.016)
	assert_false(view.nodes_changed(), "collected")
	var dressed: bool = false
	for i: int in view.dressed_count():
		dressed = dressed or view.dressed(i) == _mesh_of(fresh)
	assert_true(dressed, "the new node is dressed")
	assert_true((_mesh_of(fresh).get_instance_shader_parameter(SeasonViewScript.PARAM_TINT) as Color).a > 0.0, "turned")


func test_a_placeholder_tree_keeps_its_own_material() -> void:
	"""is_staged: a mesh whose own material has no texture is not dressed."""
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).material = StandardMaterial3D.new()
	_keep(box)
	assert_false(SeasonViewScript.is_staged(box), "a placeholder")
	var staged := _mesh_of(_keep(_tree_node()) as Node3D)
	assert_true(SeasonViewScript.is_staged(staged), "a staged model")


func test_the_weathers_cover_is_set_on_the_tree_materials_in_steps() -> void:
	"""follow_cover: the weather view's cover and frost onto every tree material, snapped to COVER_STEP, only when they
	move."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var weather := _keep(SeasonViewScript.WeatherViewScript.new()) as SeasonViewScript.WeatherViewScript
	weather._cover = 0.537
	weather._frost = 0.2
	view._weather_view = weather
	view.follow_cover()
	for material: ShaderMaterial in view.tree_materials():
		assert_almost_equal(float(material.get_shader_parameter(SeasonViewScript.PARAM_COVER)), 0.54, "the cover, snapped")
		assert_almost_equal(float(material.get_shader_parameter(SeasonViewScript.PARAM_FROST)), 0.2, "the frost")
	view.tree_materials()[0].set_shader_parameter(SeasonViewScript.PARAM_COVER, 0.0)
	weather._cover = 0.541
	view.follow_cover()
	assert_almost_equal(float(view.tree_materials()[0].get_shader_parameter(SeasonViewScript.PARAM_COVER)), 0.0,
		"inside the same step: not set again")


func test_the_preview_draws_each_preset_and_hands_back_to_the_calendar() -> void:
	"""next_preview: each preset in turn (the trees written its season), then the calendar's own; the Lab's button
	names the one drawn and the next."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.SUMMER, 6.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	var button := _keep(Button.new()) as Button
	view.bind_lab(button)
	assert_equal(button.text, SeasonViewScript.PREVIEW_OFF % "Mid-spring", "the calendar's; next mid-spring")
	for k: int in SeasonViewScript.PRESET_NAMES.size():
		view.next_preview()
		assert_equal(view.preview(), k, "preset %d" % k)
		assert_equal(view.season(), SeasonViewScript.PRESET_SEASONS[k], "its season")
		assert_almost_equal(view.day(), SeasonViewScript.PRESET_DAYS[k], "its day")
		assert_true(button.text.contains(SeasonViewScript.PRESET_NAMES[k]), "named: %s" % button.text)
	_look.sample_into(view.kind_of(0), view.hash_of(0), LookScript.WINTER, 6.0, _sample)
	assert_almost_equal(float(view.dressed(0).get_instance_shader_parameter(SeasonViewScript.PARAM_BARE)), _sample.bare,
		"mid-winter written")
	view.next_preview()
	assert_equal(view.preview(), -1, "back to the calendar")
	assert_equal(view.season(), LookScript.SUMMER, "summer again")
	view.set_preview(99)
	assert_equal(view.preview(), SeasonViewScript.PRESET_NAMES.size() - 1, "clamped")


func test_the_lab_says_a_triggers_own_done_text() -> void:
	"""A trigger with its own `done` text says it once sent (the season preview makes no news); others say DONE."""
	var lab := _keep(LabScript.new()) as LabScript
	lab.add_trigger("Season preview", "tip", "", func() -> void: pass, Callable(), "", "drawn as the button says")
	lab.add_trigger("Storm gust", "tip", "Woods", func() -> void: pass)
	lab.trigger(0)
	assert_equal(lab.status_text(), "drawn as the button says", "its own")
	lab.trigger(1)
	assert_true(lab.status_text().begins_with("Sent: Storm gust"), "the usual")


func test_leaves_fall_in_late_autumn_and_never_with_reduced_motion() -> void:
	"""Late autumn: the leaves fall; reduced motion: none at all; back to full: they fall again. Spring: none."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.AUTUMN, 10.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	view._process(0.016)
	assert_true(view.leaves.is_falling(), "late autumn: falling")
	DemoMotion.reduced = true
	view._process(0.016)
	assert_false(view.leaves.is_falling(), "reduced motion: none")
	assert_false(view.leaves_fall(), "and none wanted")
	DemoMotion.reduced = false
	view._process(0.016)
	assert_true(view.leaves.is_falling(), "full motion: falling again")
	view.leaves.run(true, Vector3.ZERO, 0.0)
	assert_equal(view.leaves.particles().speed_scale, 0.0, "paused: they hang")
	view.leaves.run(true, Vector3.ZERO, 4.0)
	assert_equal(view.leaves.particles().speed_scale, 4.0, "4x: four times as fast")
	view.set_preview(0)
	view._process(0.016)
	assert_false(view.leaves.is_falling(), "mid-spring: none")


func test_the_prewarm_lets_every_leaf_out_below_the_ground_then_stops() -> void:
	"""begin_prewarm: every leaf at once (explosive), falling, whatever the season; end_prewarm: back to none in
	spring."""
	var calendar := CalendarScript.new()
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	view.begin_prewarm()
	view._process(0.016)
	assert_true(view.leaves.is_falling() and view.leaves.particles().explosiveness == 1.0, "all out, falling")
	assert_true(view.leaves.particles().position.y < 0.0, "below the ground")
	view.end_prewarm()
	view._process(0.016)
	assert_false(view.leaves.is_falling(), "spring: none")
	assert_equal(view.leaves.particles().explosiveness, 0.0, "a steady fall again")


func test_a_frame_allocates_nothing() -> void:
	"""Frames within an hour, and the hour's refresh itself, make no object: in late autumn with leaves falling, and
	through an hour turning in winter."""
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.AUTUMN, 10.0)
	var fixture: Array = _seasons(calendar)
	var view: SeasonViewScript = fixture[0]
	view.prepare_bare()
	for k: int in 5:
		view._process(0.016)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 300:
		view._process(0.016)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "300 frames: no object")
	calendar.tick = tick_at(LookScript.WINTER, 2.0)
	view._process(0.016)
	objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 48:
		calendar.tick += SimClock.TICKS_PER_HOUR
		view._process(0.016)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "48 hours of refreshes: no object")


func test_the_ground_and_the_tufts_follow_the_season() -> void:
	"""On a built (placeholder) world: the ground's grass moves from its own colours with the season, autumn lays
	fallen leaves, and the tufts draw through one shared copy of their material, multiplied."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	world.build({})
	var ground := world.find_child("Ground", true, false) as MeshInstance3D
	var material := ground.get_active_material(0) as ShaderMaterial
	var base: Color = material.get_shader_parameter(&"grass_color")
	var calendar := CalendarScript.new()
	calendar.tick = tick_at(LookScript.SUMMER, 6.0)
	var stand := StandScript.new()
	var forest := _keep(ViewScript.new()) as ViewScript
	forest.configure(stand, func(_p: int) -> Node3D: return null, world.make_piece, ServicesScript.new().props)
	var view := _keep(SeasonViewScript.new()) as SeasonViewScript
	view.configure(calendar, null, world, stand, forest, null, _material_for)
	assert_true((material.get_shader_parameter(&"grass_color") as Color).is_equal_approx(base), "summer: its own")
	assert_equal(float(material.get_shader_parameter(SeasonViewScript.PARAM_LEAF_FALL)), 0.0, "no leaves lying")
	view.set_preview(3)
	assert_false((material.get_shader_parameter(&"grass_color") as Color).is_equal_approx(base), "late autumn: moved")
	assert_true(float(material.get_shader_parameter(SeasonViewScript.PARAM_LEAF_FALL)) > 0.3, "leaves lying")
	var tufts := world.find_child(SeasonViewScript.TUFT_NODE, true, false) as MultiMeshInstance3D
	assert_true(tufts.material_override == view.tuft_material() and view.tuft_material() != null, "one shared copy")
	assert_false(view.tuft_material().albedo_color.is_equal_approx(view._tuft_base), "multiplied")
