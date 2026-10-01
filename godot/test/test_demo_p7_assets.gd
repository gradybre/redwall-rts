extends "res://test/framework/test_case.gd"
## The underground revamp's P7 (decision 0371): the generated props swapped in and their defects fixed, the crouch and
## the dig swing played. The props table's new rows and its models made in PARTS; the hand lantern's glowing panes and
## the library basket; the hanging stores hung from the ring beam string by string, the root bin, the rug, the chimney
## and the large bed; the burrow door's leaf swinging open and shut; the open cutting with the ground cut away over it
## and the arch framing the bore; the stairs' timber treads; the crouch chosen in a bore and the dig swung once a
## strike; and the prewarm covering every new material.
##
## No staged assets: a "staged" prop here is a tiny scene saved under user:// (`_staged`) whose manifest row points at
## it -- the same code path the staged demo runs. Nodes are built out of the tree and freed after each test.

const PropsScript := preload("res://demo/props/demo_props.gd")
const WarrenKitScript := preload("res://demo/tunnel/warren_kit.gd")
const FixtureKitScript := preload("res://demo/burrow/fixture_kit.gd")
const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const DoorSwingScript := preload("res://demo/burrow/door_swing.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const StairScript := preload("res://demo/tunnel/stair_view.gd")
const GroundCutScript := preload("res://demo/world/ground_cut.gd")
const StrikeScript := preload("res://demo/cast/strike_clock.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const Layers := preload("res://demo/demo_layers.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")

const FAKES: String = "user://p7_fakes"
const DT: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


# --- fakes ----------------------------------------------------------------------------------------

static func _box_mesh(size: Vector3, at: Vector3, materials: Array[String]) -> ArrayMesh:
	"""An ArrayMesh of one box per named material, each `size` at `at` (the second offset upward), its materials named
	so (a "glow" surface for a lantern)."""
	var mesh := ArrayMesh.new()
	for k in materials.size():
		var box := BoxMesh.new()
		box.size = size
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.append_from(box, 0, Transform3D(Basis.IDENTITY, at + Vector3(0.0, size.y * float(k), 0.0)))
		tool.commit(mesh)
		var material := StandardMaterial3D.new()
		material.resource_name = materials[k]
		mesh.surface_set_material(k, material)
	return mesh


static func _scene(name: String, mesh: Mesh) -> String:
	"""A scene of one MeshInstance3D drawing `mesh`, saved under FAKES; its path."""
	DirAccess.make_dir_recursive_absolute(FAKES)
	var root := Node3D.new()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	root.add_child(node)
	node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.scn" % [FAKES, name]
	ResourceSaver.save(packed, path)
	root.free()
	return path


static func _row(mesh: Mesh, name: String) -> Dictionary:
	"""A manifest row for `mesh` saved as a fake, its bound the mesh's."""
	var bound := mesh.get_aabb()
	return {"path": _scene(name, mesh), "aabb_min": [bound.position.x, bound.position.y, bound.position.z],
		"aabb_max": [bound.end.x, bound.end.y, bound.end.z]}


static func _parts_row(parts: Dictionary, name: String) -> Dictionary:
	"""A manifest row for a model in parts {part: mesh}, its bound the parts' together."""
	var row := {"parts": {}}
	var whole := AABB()
	var first := true
	for part: String in parts:
		var mesh: Mesh = parts[part]
		row["parts"][part] = {"path": _scene("%s__%s" % [name, part], mesh)}
		whole = mesh.get_aabb() if first else whole.merge(mesh.get_aabb())
		first = false
		if not row.has("path"):
			row["path"] = row["parts"][part]["path"]
	row["aabb_min"] = [whole.position.x, whole.position.y, whole.position.z]
	row["aabb_max"] = [whole.end.x, whole.end.y, whole.end.z]
	return row


static func _staged(rows: Dictionary) -> PropsScript:
	"""A props table with these rows staged."""
	var props := PropsScript.new()
	props.load_from({"world": rows})
	return props


static func _door_parts() -> Dictionary:
	"""The burrow door in parts: a frame 1.9 wide, 1.5 tall, and a leaf in it from x -0.45 to 0.45."""
	return {"leaf": _box_mesh(Vector3(0.9, 0.9, 0.08), Vector3(0.0, 0.6, 0.07), ["leaf"] as Array[String]),
		"frame": _box_mesh(Vector3(1.9, 1.5, 0.6), Vector3(0.0, 0.75, 0.0), ["frame"] as Array[String])}


static func _store_parts() -> Dictionary:
	"""The hanging stores in parts: a bar 1.9 wide on top and five strings under it."""
	var parts := {"bar": _box_mesh(Vector3(1.9, 0.3, 0.3), Vector3(0.0, 1.55, 0.0), ["bar"] as Array[String])}
	for k in 5:
		parts["string%d" % k] = _box_mesh(Vector3(0.3, 1.3, 0.2), Vector3(-0.76 + 0.38 * k, 0.65, 0.0), ["string"] as Array[String])
	return parts


# --- the props table ------------------------------------------------------------------------------

func test_the_underground_props_are_sized_by_their_rule() -> void:
	"""Every P7 key has a size: the door spans a home's cutting (2.4 m), the arch's doorway a bore (2.85 m wide), the
	hand lantern 0.3 m tall, the large bed 2.7 m long; a fixed model is drawn at its plain one's size."""
	for key: StringName in [&"burrow_door", &"tunnel_arch", &"hand_lantern", &"hanging_stores", &"root_bin", &"chimney_pot",
			&"rag_rug", &"burrow_door_open", &"tunnel_arch_open", &"hand_lantern_lit", &"hanging_stores_strung", &"large_bed"]:
		assert_true(PropsScript.is_known(key) and PropsScript.drawn_size_m(key) > 0.0, "%s is sized" % key)
	assert_almost_equal(PropsScript.drawn_size_m(&"burrow_door_open"), 2.4, "the door")
	assert_almost_equal(PropsScript.drawn_size_m(&"tunnel_arch_open"), 2.85, "the arch")
	assert_equal(PropsScript.rule_of(&"hand_lantern_lit"), PropsScript.RULE_HEIGHT, "the lantern by its height")
	assert_almost_equal(PropsScript.drawn_size_m(&"hand_lantern_lit"), 0.3, "0.3 m")
	assert_almost_equal(PropsScript.drawn_size_m(&"large_bed"), 2.7, "the large bed")
	for pair: Array in [[&"burrow_door", &"burrow_door_open"], [&"tunnel_arch", &"tunnel_arch_open"],
			[&"hand_lantern", &"hand_lantern_lit"], [&"hanging_stores", &"hanging_stores_strung"]]:
		assert_equal(PropsScript.SIZES[pair[0]], PropsScript.SIZES[pair[1]], "%s drawn as %s" % [pair[1], pair[0]])


func test_a_model_in_parts_is_staged_only_with_every_part() -> void:
	"""A row whose parts all load is staged in parts, its parts in the manifest's order; one part missing and it is not
	staged at all (its stand-in is drawn)."""
	var row := _parts_row(_door_parts(), "door_a")
	var props := _staged({"burrow_door_open": row})
	assert_true(props.is_staged(&"burrow_door_open") and props.has_parts(&"burrow_door_open"), "staged in parts")
	assert_equal(props.part_names(&"burrow_door_open"), PackedStringArray(["leaf", "frame"]), "in order")
	var broken := row.duplicate(true)
	broken["parts"]["leaf"]["path"] = "%s/nowhere.scn" % FAKES
	var missing := _staged({"burrow_door_open": broken})
	assert_false(missing.is_staged(&"burrow_door_open") or missing.has_parts(&"burrow_door_open"), "a part missing: not staged")
	assert_null(missing.part_mesh(&"burrow_door_open", "leaf"), "and no part")
	assert_false(PropsScript.new().has_parts(&"burrow_door_open"), "nothing staged: no parts")


func test_every_part_shares_the_whole_model_s_fit() -> void:
	"""Each part is drawn by the whole model's scale and recentring, so the parts go back together: the frame spans the
	door's drawn 2.4 m, its base on y = 0, and the leaf sits inside it where the model has it."""
	var props := _staged({"burrow_door_open": _parts_row(_door_parts(), "door_b")})
	var frame := props.part_fit(&"burrow_door_open", "frame") * props.part_mesh(&"burrow_door_open", "frame").get_aabb()
	var leaf := props.part_fit(&"burrow_door_open", "leaf") * props.part_mesh(&"burrow_door_open", "leaf").get_aabb()
	assert_almost_equal(frame.size.x, 2.4, "the frame at the door's size")
	assert_almost_equal(frame.position.y, 0.0, "its base on the ground")
	var scale := 2.4 / 1.9
	assert_almost_equal(leaf.size.x, 0.9 * scale, "the leaf at the same scale")
	assert_almost_equal(leaf.position.y, 0.15 * scale, "where the model has it")
	assert_true(props.part_fit(&"burrow_door_open", "leaf") == props.fit_of(&"burrow_door_open"), "one shared fit")
	var node := props.part_instance(&"burrow_door_open", "leaf")
	assert_true(node.transform == props.part_fit(&"burrow_door_open", "leaf"), "an instance placed so")
	node.free()


func test_fitted_bakes_the_fit_into_one_mesh_with_its_materials() -> void:
	"""`fitted`: the staged model (or a part) as one mesh at its drawn size, base on y = 0 and centred, each surface's
	material kept, made once; nothing staged, null."""
	var lantern := _box_mesh(Vector3(1.0, 0.95, 1.0), Vector3(0.0, 0.475, 0.0), ["lantern", "glow"] as Array[String])
	var props := _staged({"hand_lantern_lit": _row(lantern, "lantern_a"), "burrow_door_open": _parts_row(_door_parts(), "door_c")})
	var fitted := props.fitted(&"hand_lantern_lit")
	assert_almost_equal(fitted.get_aabb().size.y, 0.3, "0.3 m tall")
	assert_almost_equal(fitted.get_aabb().position.y, 0.0, "on the ground")
	assert_almost_equal(fitted.get_aabb().get_center().x, 0.0, "centred")
	assert_equal(fitted.get_surface_count(), 2, "both surfaces")
	assert_equal((fitted.surface_get_material(1) as Material).resource_name, "glow", "their materials kept")
	assert_true(props.fitted(&"hand_lantern_lit") == fitted, "made once")
	assert_almost_equal(props.fitted(&"burrow_door_open", "frame").get_aabb().size.x, 2.4, "a part too")
	assert_null(PropsScript.new().fitted(&"hand_lantern_lit"), "nothing staged: null")


# --- the theatre's props --------------------------------------------------------------------------

func test_the_staged_hand_lantern_glows_from_its_panes() -> void:
	"""Staged, the hand lantern is the library's, 0.3 m tall, its `glow` surface lit from within and its frame not;
	unstaged, the procedural lantern's glass glows."""
	var lantern := _box_mesh(Vector3(1.0, 0.95, 1.0), Vector3(0.0, 0.475, 0.0), ["lantern", "glow"] as Array[String])
	var props := _staged({"hand_lantern_lit": _row(lantern, "lantern_b")})
	var mesh := WarrenKitScript.hand_lantern(props)
	assert_almost_equal(mesh.get_aabb().size.y, 0.3, "the library's, 0.3 m")
	assert_false((mesh.surface_get_material(0) as BaseMaterial3D).emission_enabled, "its frame unlit")
	var glass := mesh.surface_get_material(1) as BaseMaterial3D
	assert_true(glass.emission_enabled and glass.emission_energy_multiplier >= 1.0, "its panes glow")
	assert_true(WarrenKitScript.hand_lantern(props) == mesh, "made once")
	var stand_in := WarrenKitScript.hand_lantern(PropsScript.new())
	assert_true(stand_in != mesh and WarrenKitScript.glows(stand_in), "unstaged: the stand-in, glowing")
	assert_true(WarrenKitScript.hand_lantern() == stand_in, "no props: the same stand-in")
	var restarted := _staged({"hand_lantern_lit": _row(lantern, "lantern_b")})
	var again := WarrenKitScript.hand_lantern(restarted)
	assert_true(again != mesh and restarted.derived(&"hand_lantern/lit") == again,
		"a new props table (a restart) makes its own, kept with it: nothing kept in a static to leak")


func test_the_staged_basket_is_the_library_s_and_holds_its_spoil_at_the_rim() -> void:
	"""Staged, the hauling basket is the library's at BASKET_SIZE_M; loaded, it carries a spoil surface more; the
	hauler holds it by its rim. Unstaged, the stand-in at its own rim."""
	var basket := _box_mesh(Vector3(1.5, 1.66, 1.9), Vector3(0.0, 0.83, 0.0), ["wicker"] as Array[String])
	var props := _staged({"basket": _row(basket, "basket_a")})
	var empty := WarrenKitScript.basket(props)
	assert_almost_equal(empty.get_aabb().size.y, WarrenKitScript.BASKET_SIZE_M, "the library's basket")
	var loaded := WarrenKitScript.loaded_basket(props)
	assert_equal(loaded.get_surface_count(), empty.get_surface_count() + 1, "and the spoil heaped in it")
	assert_almost_equal(WarrenKitScript.rim_m(props), WarrenKitScript.BASKET_SIZE_M * WarrenKitScript.BASKET_RIM_SHARE, "its rim")
	assert_almost_equal(WarrenKitScript.basket_fit(props).origin.y, -WarrenKitScript.rim_m(props), "held by the rim")
	assert_almost_equal(WarrenKitScript.rim_m(), WarrenKitScript.BASKET_TALL_M, "the stand-in's rim")
	assert_true(WarrenKitScript.loaded_basket() != loaded, "unstaged: the stand-in's")


# --- the fit-out ----------------------------------------------------------------------------------

func test_the_staged_hanging_stores_hang_string_by_string_from_the_beam() -> void:
	"""Staged, the hanging stores are the bar and its five strings, the strings the slots (hidden until shown), hung by
	`hang_at`: their top at the height asked, their back that far behind the place."""
	var props := _staged({"hanging_stores_strung": _parts_row(_store_parts(), "stores_a")})
	var parent: Node3D = _keep(Node3D.new())
	var slots: Array[Node3D] = []
	var hang := FixtureKitScript.hang_at(props, 1.0, 0.3)
	FixtureKitScript.hanging(parent, slots, props, hang)
	assert_equal(slots.size(), 5, "five strings, five slots")
	var hung := parent.get_child(0) as Node3D
	assert_equal(hung.get_child_count(), 6, "the bar and the strings")
	assert_true((hung.get_child(0) as Node3D).visible and not slots[0].visible, "the bar shows, a string waits")
	var bound: AABB = props.drawn_bound(&"hanging_stores_strung")
	assert_almost_equal((hang * bound).end.y, 1.0, "its top at the beam")
	assert_almost_equal((hang * bound).position.z, -0.3, "its back against it")
	var stand_in: Array[Node3D] = []
	FixtureKitScript.hanging(_keep(Node3D.new()), stand_in)
	assert_equal(stand_in.size(), FixtureKitScript.STRINGS, "unstaged: the stand-in's strings")


func test_the_hanging_stores_back_meets_the_ring_beam() -> void:
	"""`hang_back_m`: from a home's hanging place back along its facing to the ring beam's inner face (a circle
	BEAM_INSET_M plus half the beam inside the wall), and from a cellar's to its long wall's."""
	for template: int in [RoomsScript.TEMPLATE_HOME, RoomsScript.TEMPLATE_CELLAR]:
		var f := -1
		for k in RoomsScript.fixture_count(template):
			if FixtureViewScript.FixturesScript.place_kind(template, k) == RoomsScript.FIX_HANGING:
				f = k
		var back := FixtureViewScript.hang_back_m(template, f)
		assert_true(back > 0.0, "%d: the beam is behind the place (%.2f m)" % [template, back])
		var at := Vector2(Rules.to_m(RoomsScript.fixture_field(template, f, 1)), Rules.to_m(RoomsScript.fixture_field(template, f, 2)))
		var facing := Vector2(float(RoomsScript.fixture_field(template, f, 3)), float(RoomsScript.fixture_field(template, f, 4))).normalized()
		var on := at - facing * back
		var wall := Rules.to_m(RoomsScript.void_half(template).x) - RoomViewScript.BEAM_INSET_M - RoomViewScript.BEAM_WIDTH_M * 0.5
		var reach := on.length() if template == RoomsScript.TEMPLATE_HOME else absf(on.x)
		assert_almost_equal(reach, wall, "%d: on the beam's inner face" % template)


func test_the_root_bin_rug_chimney_and_large_bed_swap_in_where_staged() -> void:
	"""Staged: the root bin is the library's, full, with no slot; the rug lies as a mesh; the chimney's top is its drawn
	height; the large bed is drawn 1.2 m by 2.7 m. Unstaged: the stand-in bin's heap is its slot, the rug a decal, the
	chimney CHIMNEY_TOP_M tall, the bed stretched to the same size."""
	var props := _staged({"root_bin": _row(_box_mesh(Vector3.ONE * 1.9, Vector3(0.0, 0.95, 0.0), ["bin"] as Array[String]), "bin_a"),
		"rag_rug": _row(_box_mesh(Vector3(1.9, 0.05, 1.9), Vector3(0.0, 0.025, 0.0), ["rug"] as Array[String]), "rug_a"),
		"chimney_pot": _row(_box_mesh(Vector3(0.8, 1.9, 0.8), Vector3(0.0, 0.95, 0.0), ["pot"] as Array[String]), "pot_a"),
		"large_bed": _row(_box_mesh(Vector3(1.24, 0.8, 3.21), Vector3(0.0, 0.4, 0.0), ["bed"] as Array[String]), "bed_a")})
	var slots: Array[Node3D] = []
	FixtureKitScript.root_bin(_keep(Node3D.new()), slots, props)
	assert_equal(slots.size(), 0, "the library's bin: no slot")
	FixtureKitScript.root_bin(_keep(Node3D.new()), slots, PropsScript.new())
	assert_equal(slots.size(), 1, "the stand-in's heap")
	FixtureKitScript.fill_heap(slots[0], 500)
	assert_almost_equal(slots[0].scale.y, FixtureKitScript.HEAP_TOP_M * 0.5 / FixtureKitScript.HEAP_HALF_M, "half full")
	assert_true(FixtureKitScript.rug(_keep(Node3D.new()), props) is MeshInstance3D, "the library rug")
	assert_true(FixtureKitScript.rug(_keep(Node3D.new())) is Decal, "the decal")
	assert_almost_equal(FixtureKitScript.chimney_top_m(props), 0.62, "the library pot's top")
	assert_almost_equal(FixtureKitScript.chimney_top_m(), FixtureKitScript.CHIMNEY_TOP_M, "the stand-in's")
	for table: PropsScript in [props, PropsScript.new()]:
		var bed := FixtureKitScript.large_bed(_keep(Node3D.new()), table)
		var drawn: AABB = bed.transform * bed.mesh.get_aabb()
		assert_almost_equal(drawn.size.x, FixtureKitScript.LARGE_BED_M.x, "1.2 m wide")
		assert_almost_equal(drawn.size.z, FixtureKitScript.LARGE_BED_M.y, "2.7 m long")


# --- the burrow door ------------------------------------------------------------------------------

func test_a_door_swings_open_for_a_resident_below_and_shuts_behind() -> void:
	"""A door opens while a resident below stands within REACH_M of it, swinging OPEN_RAD in SWING_S, and shuts once
	nobody is; a resident on the surface, or one further off, opens nothing; paused (no demo time), it holds."""
	var swing := DoorSwingScript.new()
	swing.configure(2)
	var hinge: Node3D = _keep(Node3D.new())
	swing.set_door(1, Vector2(4.0, 2.0), hinge)
	var at := PackedVector2Array([Vector2(4.5, 2.5)])
	swing.step(at, PackedByteArray([0]), 0.1)
	assert_almost_equal(swing.angle(1), 0.0, "someone on the surface: shut")
	swing.step(at, PackedByteArray([1]), DoorSwingScript.SWING_S * 0.5)
	assert_almost_equal(swing.angle(1), DoorSwingScript.OPEN_RAD * 0.5, "halfway open")
	assert_almost_equal(hinge.rotation.y, swing.angle(1), "the hinge turned")
	swing.step(at, PackedByteArray([1]), 0.0)
	assert_almost_equal(swing.angle(1), DoorSwingScript.OPEN_RAD * 0.5, "paused: held")
	swing.step(at, PackedByteArray([1]), DoorSwingScript.SWING_S)
	assert_almost_equal(swing.angle(1), DoorSwingScript.OPEN_RAD, "open, no further")
	swing.step(PackedVector2Array([Vector2(4.0, 2.0 + DoorSwingScript.REACH_M + 0.1)]), PackedByteArray([1]), DoorSwingScript.SWING_S)
	assert_almost_equal(swing.angle(1), 0.0, "through and gone: shut again")
	assert_true(DoorSwingScript.wanted_open(Vector2.ZERO, PackedVector2Array([Vector2(DoorSwingScript.REACH_M - 0.01, 0.0)]),
		PackedByteArray([1])), "just inside the reach: open")
	swing.step(PackedVector2Array([Vector2(4.0, 2.0), Vector2(30.0, 2.0)]), PackedByteArray([0, 1]), DoorSwingScript.SWING_S)
	assert_almost_equal(swing.angle(1), 0.0, "one on the surface at it, one below far off: shut")
	swing.clear(1)
	assert_false(swing.has_door(1) or swing.has_door(0), "cleared")


func test_a_dug_home_hangs_its_door_leaf_on_a_hinge_at_the_cutting_s_foot() -> void:
	"""A dug burrow home's front door stands on the cutting's floor (its level's, 1.25 m down) at its wall, its leaf on a
	hinge at its left edge the door swing turns -- inward, into the mound -- and its row has a door."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(space.tunnels, null, PropsScript.new())
	var view: RoomViewScript = _keep(RoomViewScript.new())
	view.configure(space.tunnels, PropsScript.new(), space, marks)
	var network := space.tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(2048, 4096), 0, 0, ref), "a home")
	network.start_dig(ref[3], ref[4], 0)
	network.advance(ref[3], ref[4], 1000000000)
	var body: int = network.rooms.body[ref[0]]
	network.start_dig(body, network.generation[body], 0)
	network.advance(body, network.generation[body], 1000000000)
	view.refresh()
	assert_true(view.door_swing.has_door(0), "the home has a door")
	var door: Node3D = null
	for child in view.above(0).get_children():
		if child.find_child("Hinge", false, false) != null:
			door = child
	assert_not_null(door, "its door in the mound")
	assert_almost_equal(door.position.y, Layers.floor_y(Rules.TOP_LEVEL), "on the cutting's floor")
	var hinge := door.find_child("Hinge", false, false) as Node3D
	var leaf := hinge.get_child(0) as Node3D
	assert_almost_equal((hinge.position + leaf.position).x, 0.0, "shut, the leaf in the middle of its ring")
	assert_true(hinge.position.x > 0.0, "hung at its left edge, seen from the cutting (the door's +X)")
	var shut := door.transform * hinge.transform * leaf.position
	hinge.rotation.y = DoorSwingScript.OPEN_RAD
	var open := door.transform * hinge.transform * leaf.position
	var toward := (door.transform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	assert_true((open - shut).dot(toward) > 0.2, "it swings in, away from the cutting")
	var cut := view.door_swing
	space.resident_position.append(Vector2(door.position.x, door.position.z))
	space.resident_underground.append(1)
	view.swing_doors(DoorSwingScript.SWING_S)
	assert_almost_equal(cut.angle(0), DoorSwingScript.OPEN_RAD, "a resident at it below: open")


# --- the cutting, the ground and the arch ---------------------------------------------------------

func test_the_cutting_follows_the_ramp_down_to_the_portal_and_its_throat() -> void:
	"""Open to the portal, the cutting's floor is the ramp's floor (`ramp_depth_m`) where the walker stands, its walls
	reach the ground, and the bore goes on THROAT_M as a dark throat; while dug, it ends at the earth face; a kind is
	built once."""
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	var mesh := MouthScript.cutting_mesh(Rules.BORE_STANDARD, portal, MouthScript.END_THROAT)
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var deepest := {}
	var far := 0.0
	var high := -INF
	for p: Vector3 in points:
		var z := snappedf(p.z, 0.001)
		deepest[z] = minf(deepest.get(z, INF), p.y)
		far = maxf(far, p.z)
		high = maxf(high, p.y)
	for z: float in [0.0, 1.0, 2.0, portal]:
		assert_almost_equal(deepest[snappedf(z, 0.001)], -Rules.ramp_depth_m(z), "the floor %.2f m down the ramp" % z)
	assert_almost_equal(far, portal + MouthScript.THROAT_M, "the throat beyond the portal")
	assert_almost_equal(high, MouthScript.BANK_HEIGHT_M, "walls to the ground, banks on it")
	assert_true(MouthScript.cutting_mesh(Rules.BORE_STANDARD, portal, MouthScript.END_THROAT) == mesh, "built once")
	var dug := MouthScript.cutting_mesh(Rules.BORE_STANDARD, 1.2, MouthScript.END_FACE)
	var dug_far := 0.0
	for p: Vector3 in dug.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		dug_far = maxf(dug_far, p.z)
	assert_almost_equal(dug_far, 1.2, "while dug: the face where the dig has reached")
	assert_almost_equal(MouthScript.opened_share(0.3), 0.375, "the shaft opens it in eighths")
	var court := MouthScript.cutting_mesh(Rules.BORE_STANDARD, portal, MouthScript.END_THROAT, 1.3)
	var widest_before := 0.0
	var widest_after := 0.0
	var start := MouthScript.court_start(portal)
	for p: Vector3 in court.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if p.y < -0.01 and p.z < start - 0.01:
			widest_before = maxf(widest_before, absf(p.x))
		elif p.y < -0.01 and p.z > start + 0.01 and p.z < portal - 0.01:
			widest_after = maxf(widest_after, absf(p.x))
	assert_true(widest_before < 0.65, "the cutting its bore's width (%.2f)" % widest_before)
	assert_true(widest_after > 1.25, "then its forecourt the arch's (%.2f)" % widest_after)
	assert_almost_equal(start, floorf((portal - MouthScript.FORECOURT_M) / MouthScript.CUT_STEP_M) * MouthScript.CUT_STEP_M, "on the lattice")
	var yard := MouthScript.court_footprint(Vector2.ZERO, Vector2(0.0, 1.0), 1.3, portal)
	assert_almost_equal(absf(GroundCutScript.signed_area(yard)), 2.6 * (portal - start), "its hole the forecourt's")


func test_the_ground_is_cut_by_the_cutting_s_footprint_and_conserved() -> void:
	"""GroundCut over a ground of 8 m cells: a hole drops the triangles it overlaps and draws the rest of them again as a
	collar on their plane -- the ground left and the collar together are the ground less the hole, exactly -- and does
	nothing when nothing changed; a hole wholly inside one triangle is cut too; clearing the holes gives the ground back
	whole and hides the collar."""
	var ground: MeshInstance3D = _keep(_ground_grid(4, 8.0))
	var cut := GroundCutScript.new()
	cut.set_ground(ground)
	var total := _area(ground.mesh)
	var hole := MouthScript.footprint(Vector2(1.0, 2.0), Vector2(0.6, 0.8), Rules.BORE_STANDARD, 2.9)
	cut.set_hole(0, hole)
	assert_true(cut.apply(), "cut")
	assert_true(cut.dropped >= 1 and cut.collar.visible, "triangles dropped, a collar drawn")
	assert_almost_equal(_area(ground.mesh) + _area(cut.collar.mesh), total - absf(GroundCutScript.signed_area(hole)), "conserved")
	for p: Vector3 in cut.collar.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_almost_equal(p.y, 0.25 * p.x, "the collar on the ground's plane")
	assert_false(cut.apply(), "nothing changed: nothing done")
	cut.set_hole(0, hole)
	assert_false(cut.apply(), "the same hole again: nothing done")
	var inside := PackedVector2Array([Vector2(-12.0, -12.0), Vector2(-11.0, -12.0), Vector2(-11.0, -11.5)])
	cut.set_hole(1, inside)
	cut.apply()
	assert_almost_equal(_area(ground.mesh) + _area(cut.collar.mesh),
		total - absf(GroundCutScript.signed_area(hole)) - absf(GroundCutScript.signed_area(inside)), "a hole inside one triangle")
	cut.set_hole(0, PackedVector2Array())
	cut.set_hole(1, PackedVector2Array())
	cut.apply()
	assert_almost_equal(_area(ground.mesh), total, "whole again")
	assert_false(cut.collar.visible, "no collar")
	assert_equal(cut.hole_count(), 0, "no holes")


func test_a_replaced_ground_is_read_again_as_uncut() -> void:
	"""Someone else replacing the ground's mesh (the water carving it) makes the next apply read it as the uncut
	ground and cut it again."""
	var ground: MeshInstance3D = _keep(_ground_grid(4, 8.0))
	var cut := GroundCutScript.new()
	cut.set_ground(ground)
	cut.set_hole(0, PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]))
	cut.apply()
	var replaced := _ground_grid(4, 8.0)
	ground.mesh = replaced.mesh
	replaced.free()
	var total := _area(ground.mesh)
	assert_true(cut.apply(), "a replaced ground is cut again")
	assert_almost_equal(_area(ground.mesh) + _area(cut.collar.mesh), total - 4.0, "conserved on the new ground")


static func _ground_grid(cells: int, cell_m: float) -> MeshInstance3D:
	"""A tilted ground (y = x / 4) of `cells` by `cells` cells of `cell_m`, centred, two triangles a cell."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(cells) * cell_m * 0.5
	for j in cells:
		for i in cells:
			var a := Vector2(-half + i * cell_m, -half + j * cell_m)
			var quad := [a, a + Vector2(cell_m, 0.0), a + Vector2(cell_m, cell_m), a + Vector2(0.0, cell_m)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				tool.set_normal(Vector3(-0.25, 1.0, 0.0).normalized())
				tool.add_vertex(Vector3(p.x, 0.25 * p.x, p.y))
	tool.index()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	return node


static func _area(mesh: Mesh) -> float:
	"""A mesh's area seen from above (x, z), summed over its triangles."""
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		for k in points.size():
			index.append(k)
	var total := 0.0
	for t in index.size() / 3:
		var a := Vector2(points[index[t * 3]].x, points[index[t * 3]].z)
		var b := Vector2(points[index[t * 3 + 1]].x, points[index[t * 3 + 1]].z)
		var c := Vector2(points[index[t * 3 + 2]].x, points[index[t * 3 + 2]].z)
		total += absf((b - a).cross(c - a)) * 0.5
	return total


func test_a_dug_tunnel_opens_its_mouths_and_cuts_the_ground_over_them() -> void:
	"""A tunnel dug through: each opened mouth's cutting is cut out of the ground (one hole a mouth, its footprint the
	cutting's), and the arch -- the staged one -- stands at the portal facing up the ramp, sunk so its doorway's top is
	the crown there (the ground), its lantern beside the way in; the procedural gateway without it."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 0, 10240]), 2, 0, ref)
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(space.tunnels, space)
	var arch := _box_mesh(Vector3(1.9, 1.56, 0.67), Vector3(0.0, 0.78, 0.0), ["arch"] as Array[String])
	var lantern := _box_mesh(Vector3(1.8, 1.9, 0.8), Vector3(0.0, 0.95, 0.0), ["lantern"] as Array[String])
	overlay.set_props(_staged({"tunnel_arch_open": _row(arch, "arch_a"), "wall_lantern": _row(lantern, "wall_lantern_a")}))
	var ground: MeshInstance3D = _keep(_ground_grid(6, 8.0))
	overlay.set_ground(ground)
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	for slot in chain:
		space.tunnels.start_dig(slot, space.tunnels.generation[slot], 0)
		space.tunnels.advance(slot, space.tunnels.generation[slot], 1000000000)
	overlay.refresh()
	assert_equal(overlay.ground_cut.hole_count(), 4, "both mouths cut open, each cutting and its forecourt")
	assert_true(overlay.ground_cut.dropped > 0 and overlay.ground_cut.collar.visible, "and the ground cut")
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	assert_almost_equal(overlay.mouth_open_m(0), portal, "open to the portal")
	var gateway := overlay.hole(0).get_child(OverlayScript.MOUTH_GATEWAY) as MeshInstance3D
	var drawn: AABB = gateway.transform * gateway.mesh.get_aabb()
	var doorway_top := drawn.position.y + drawn.size.y * MouthScript.OPENING_TOP_SHARE
	assert_almost_equal(doorway_top, -Rules.ramp_depth_m(portal) + Rules.crown_m(Rules.BORE_STANDARD), "its doorway's top at the crown")
	assert_almost_equal(drawn.size.x * MouthScript.OPENING_SHARE, MouthScript.cut_half_m(Rules.BORE_STANDARD) * 2.0, "the bore's width")
	assert_almost_equal(drawn.get_center().z, portal, "at the portal")
	assert_true(gateway.transform.basis.z.z < 0.0, "facing up the ramp")
	var light := overlay.hole(0).get_child(OverlayScript.MOUTH_LANTERN) as MeshInstance3D
	assert_true(light.visible and (light.transform * light.mesh.get_aabb()).get_center().z < portal, "its lantern out on its face")
	overlay.set_props(PropsScript.new())
	overlay.refresh()
	assert_true(gateway.mesh == MouthScript.gateway_mesh() and not light.visible, "unstaged: the procedural gateway")


func test_a_walker_is_in_the_open_cutting_until_the_bore_goes_under() -> void:
	"""`in_open_cutting`: down a tunnel's entrance ramp, short of the portal, yes; past it, no; on the level stretch,
	no. A burrow home's door ramp is open all the way down to its door; a cellar's, under its hatch, never."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 0, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	var ramp := chain[0]
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	var from := network.length_m(ramp) if network.mouth_end_at_b(ramp) else 0.0
	var way := -1.0 if network.mouth_end_at_b(ramp) else 1.0
	assert_true(MouthScript.in_open_cutting(network, ramp, from + way * (portal - 0.1)), "short of the portal")
	assert_false(MouthScript.in_open_cutting(network, ramp, from + way * (portal + 0.1)), "past it")
	assert_false(MouthScript.in_open_cutting(network, chain[1], 1.0), "the level bore")
	assert_false(MouthScript.in_open_cutting(network, -1, 0.0), "the surface")
	var home := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(10240, 8192), 0, 0, home)
	var cellar := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(-10240, 8192), 0, 0, cellar)
	for room: PackedInt32Array in [home, cellar]:
		network.start_dig(room[3], room[4], 0)
		network.advance(room[3], room[4], 1000000000)
		var body: int = network.rooms.body[room[0]]
		network.start_dig(body, network.generation[body], 0)
		network.advance(body, network.generation[body], 1000000000)
	var home_mouth: int = network.mouth_of_end(home[3], network.mouth_end_at_b(home[3]))
	var cellar_mouth: int = network.mouth_of_end(cellar[3], network.mouth_end_at_b(cellar[3]))
	assert_almost_equal(MouthScript.cutting_run_m(network, home_mouth), Rules.to_m(Rules.RAMP_RUN_U), "a home's: down to its door")
	assert_almost_equal(MouthScript.cutting_run_m(network, cellar_mouth), 0.0, "a cellar's: under its hatch")
	assert_almost_equal(MouthScript.cutting_run_m(network, network.mouth_of_end(ramp, network.mouth_end_at_b(ramp))), portal, "a tunnel's: to the portal")


func test_nobody_is_sent_to_stand_over_an_open_cutting() -> void:
	"""`on_mouth` keeps a stander off an opened mouth's cutting, past the portal to the arch's back -- but not off the
	ground beside it, nor a step out of the mouth; a mouth not yet opened has no cutting to keep off."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 0, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	var m: int = network.mouth_of_end(chain[0], network.mouth_end_at_b(chain[0]))
	var at: Vector2 = network.mouth_at(m)
	var into: Vector2 = network.mouth_inward(m)
	var across := Vector2(into.y, -into.x)
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	assert_true(space.on_mouth(at + into * 1.8, 0.25), "in the cutting")
	assert_true(space.on_mouth(at + into * (portal + MouthScript.ARCH_DEPTH_M + 0.2), 0.25), "against the arch's back")
	assert_false(space.on_mouth(at + into * (portal + MouthScript.ARCH_DEPTH_M + 0.3), 0.25), "past it (a body clear of the arch's back)")
	assert_false(space.on_mouth(at + into * 1.8 + across * 1.2, 0.25), "beside it")
	assert_false(space.on_mouth(at - into * 1.0, 0.25), "a step out of the mouth")
	var planned := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([12288, 0, 12288, 16384]), 2, 0, planned)
	var p_chain := PackedInt32Array()
	network.piece_segments_into(planned[2], p_chain)
	var pm: int = network.mouth_of_end(p_chain[0], network.mouth_end_at_b(p_chain[0]))
	assert_false(space.on_mouth(network.mouth_at(pm) + network.mouth_inward(pm) * 1.8, 0.25), "a planned mouth: no cutting yet")


func test_a_resident_in_the_cutting_is_drawn_on_the_surface_too() -> void:
	"""In the open cutting the resident's body is on its level's underground layer and the surface's; under the ground
	past the portal, the underground's alone."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 0, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor.setup_placeholder(0, space, 3)
	var ramp := chain[0]
	var from := network.length_m(ramp) if network.mouth_end_at_b(ramp) else 0.0
	var way := -1.0 if network.mouth_end_at_b(ramp) else 1.0
	actor.brain.task_stand_in_bore(ramp, from + way * 1.0, true)
	actor._apply_transform()
	assert_equal(actor.layers_now(), Layers.UNDERGROUND | Layers.SURFACE, "in the cutting: both")
	actor.brain.task_stand_in_bore(ramp, from + way * (Rules.portal_m(Rules.BORE_STANDARD) + 0.3), true)
	actor._apply_transform()
	assert_equal(actor.layers_now(), Layers.UNDERGROUND, "under the ground: below only")


# --- the stairs -----------------------------------------------------------------------------------

func test_the_stairs_have_timber_treads_with_a_nosing_over_their_risers() -> void:
	"""A step is a packed-earth block under a timber tread board whose nosing overhangs the timber riser at its front,
	the timber in the procedural grain; its top is the walking line (y 0)."""
	var step := StairScript.step_mesh(Rules.TOP_LEVEL)
	assert_equal(step.get_surface_count(), 2, "earth and timber")
	var timber := step.surface_get_material(1) as ShaderMaterial
	assert_true(timber.get_shader_parameter(&"albedo_texture") == StairScript.timber_texture(), "the timber's grain")
	var earth_far := -INF
	var board_far := -INF
	var top := -INF
	for p: Vector3 in step.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		earth_far = maxf(earth_far, p.z)
	var riser_low := INF
	for p: Vector3 in step.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]:
		board_far = maxf(board_far, p.z)
		top = maxf(top, p.y)
		if p.z > 0.5 - StairScript.BOARD_M - 1e-4 and p.z < 0.5 + 1e-4:
			riser_low = minf(riser_low, p.y)
	assert_almost_equal(top, 0.0, "the tread's top on the walking line")
	assert_almost_equal(board_far, 0.5 + StairScript.NOSING, "the nosing past the riser")
	assert_almost_equal(earth_far, 0.5 - StairScript.BOARD_M, "the earth behind the riser")
	assert_almost_equal(riser_low, -Rules.to_m(Rules.STAIR_RISE_U), "the riser down a whole rise")
	var board := StairScript.grain_pixel(0.3, 0.375)
	var seam := StairScript.grain_pixel(0.3, 0.25)
	assert_true(seam.r < board.r * 0.7, "a dark seam between boards")


# --- the crouch and the dig -------------------------------------------------------------------------

func test_a_walk_crouches_where_the_resident_stoops_and_a_dig_swings() -> void:
	"""choose_clip: at a face, the swing while one plays and the stance between; a walk where the resident crouches,
	the crouch walk; a carry stays a carry (the stoop bends it); a walk upright stays a walk."""
	var crouch := DemoActorScript.CLIP_CROUCH
	assert_equal(DemoActorScript.choose_clip(BrainScript.CLIP_WALK, false, false, true), crouch, "a stooping walk crouches")
	assert_equal(DemoActorScript.choose_clip(BrainScript.CLIP_WALK, false, false, false), BrainScript.CLIP_WALK, "upright: a walk")
	assert_equal(DemoActorScript.choose_clip(BrainScript.CLIP_CARRY, false, false, true), BrainScript.CLIP_CARRY, "a carry stays")
	assert_equal(DemoActorScript.choose_clip(&"pull_radish", true, true, false), DemoActorScript.CLIP_SWING, "swinging")
	assert_equal(DemoActorScript.choose_clip(&"pull_radish", true, false, true), BrainScript.CLIP_IDLE, "between swings")
	assert_almost_equal(DemoActorScript.crouch_rate(1.4, 1.4, 1.4, 0.7), 2.0, "the crouch at the walk's ground speed")
	assert_almost_equal(DemoActorScript.crouch_rate(1.4, 0.7, 1.4, 0.7), 1.0, "slowed with the walk")
	assert_almost_equal(DemoActorScript.crouch_rate(1.0, 1.4, 1.4, 0.5), 2.0, "the walk's ground speed, not its rate")


func test_a_mouse_crouches_in_a_bore_and_a_mole_walks_upright() -> void:
	"""With a crouch staged, a resident whose bore makes it stoop (a mouse, 1.0 m, in a standard bore) crouches and its
	stoop adds only what the crouch leaves; one upright there (a mole, 0.9 m) walks."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 0, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	var mouse: DemoActorScript = _keep(DemoActorScript.new())
	mouse.setup_placeholder(0, space, 3)
	mouse.height_m = 1.0
	mouse._crouch_speed = 0.88
	mouse._crouch_drop = 0.06
	mouse.brain.task_stand_in_bore(chain[1], 2.0, true)
	assert_true(mouse.crouches(), "a mouse stoops %.2f m in a standard bore: it crouches" % mouse.stoop_target_m())
	mouse.brain.clip = BrainScript.CLIP_WALK
	assert_equal(mouse.played_clip(), DemoActorScript.CLIP_CROUCH, "its walk is the crouch")
	mouse._playing = DemoActorScript.CLIP_CROUCH
	mouse.ease_stoop(1.0)
	assert_almost_equal(mouse.stoop_now_m(), mouse.stoop_target_m() - 0.06, "the stoop adds only the rest")
	mouse.height_m = 0.9
	assert_false(mouse.crouches(), "a mole stands upright in it: it walks")


func test_the_dig_swings_once_a_strike_landing_on_the_cut() -> void:
	"""The strike clock: a swing as the digger reaches the face; then one for each cut, never a second; once the time
	between cuts is known, each swing starts so its blow lands on the next cut; between swings at least REST_S; paused,
	nothing moves; reset, it starts again with a swing owed."""
	var strike := StrikeScript.new()
	assert_true(strike.step(0, DT), "a swing as it reaches the face")
	var cuts := 0
	var time := DT
	var blows: Array[float] = []
	var cut_times: Array[float] = []
	var started := 1
	while time < 40.0:
		time += DT
		if fmod(time, 3.8) < DT:
			cuts += 1
			cut_times.append(time)
		if strike.step(cuts, DT):
			started += 1
			blows.append(time + strike.impact_s)
	assert_equal(strike.swings, started, "counted")
	assert_true(started <= cuts + 1, "never more than one a cut (%d swings, %d cuts)" % [started, cuts])
	assert_true(started >= cuts, "one for each cut (%d swings, %d cuts)" % [started, cuts])
	assert_less_than(absf(strike.period() - 3.8), 2.0 * DT, "the time between cuts")
	var landed := 0
	for blow: float in blows.slice(2).filter(func(at: float) -> bool: return at < 38.0):
		for at: float in cut_times:
			if absf(blow - at) <= 2.0 * DT:
				landed += 1
	assert_equal(landed, blows.slice(2).filter(func(at: float) -> bool: return at < 38.0).size(), "each blow lands on its cut")
	var irregular := StrikeScript.new()
	irregular.step(0, DT)
	for k in roundi(3.0 / DT):
		irregular.step(0, DT)
	irregular.step(1, DT)
	for k in roundi(5.0 / DT):
		irregular.step(1, DT)
	irregular.step(2, DT)
	assert_less_than(absf(irregular.period() - 4.0), 3.0 * DT, "the time between cuts eased: 3 s then 5 s, 4 s")
	var idle := StrikeScript.new()
	for k in roundi(10.0 / DT):
		idle.step(0, DT)
	assert_equal(idle.swings, 1, "no cut, no second swing")
	var late := StrikeScript.new()
	late.step(5, DT)
	assert_true(late.period() < 0.0, "reaching a face already cut five times: no time between cuts yet")
	var held := StrikeScript.new()
	held.step(0, DT)
	held.step(0, 0.0)
	assert_true(held.swinging(), "paused mid-swing: still swinging")
	strike.reset()
	assert_true(strike.step(cuts, DT), "reset: a swing owed again")


func test_a_quick_dig_swings_back_to_back_with_a_rest_between() -> void:
	"""Cuts quicker than a swing: a swing after each one ends and REST_S more, never two at once, never more than one
	a cut."""
	var strike := StrikeScript.new()
	var cuts := 0
	var time := 0.0
	var ended := -1.0
	var gaps: Array[float] = []
	var was := false
	while time < 20.0:
		time += DT
		if fmod(time, 0.9) < DT:
			cuts += 1
		var started := strike.step(cuts, DT)
		if was and not strike.swinging():
			ended = time
		if started and ended >= 0.0:
			gaps.append(time - ended)
		was = strike.swinging()
	assert_true(strike.swings <= cuts + 1 and strike.swings > 5, "%d swings for %d cuts" % [strike.swings, cuts])
	for gap: float in gaps:
		assert_true(gap >= StrikeScript.REST_S - 1e-3, "a rest of %.2f s between" % gap)


# --- the prewarm ----------------------------------------------------------------------------------

func test_the_prewarm_covers_every_new_prop_s_material() -> void:
	"""Staged, everything the fit-out and the theatre draw with the new props -- the hanging stores' bar and strings,
	the library root bin, rug and large bed, the lit lantern, the library basket loaded and empty -- has each of its
	materials registered for the U view's prewarm."""
	var props := _staged({"hanging_stores_strung": _parts_row(_store_parts(), "stores_b"),
		"root_bin": _row(_box_mesh(Vector3.ONE * 1.9, Vector3(0.0, 0.95, 0.0), ["bin"] as Array[String]), "bin_b"),
		"rag_rug": _row(_box_mesh(Vector3(1.9, 0.05, 1.9), Vector3(0.0, 0.025, 0.0), ["rug"] as Array[String]), "rug_b"),
		"large_bed": _row(_box_mesh(Vector3(1.24, 0.8, 3.21), Vector3(0.0, 0.4, 0.0), ["bed"] as Array[String]), "bed_b"),
		"hand_lantern_lit": _row(_box_mesh(Vector3(1.0, 0.95, 1.0), Vector3(0.0, 0.475, 0.0), ["lantern", "glow"] as Array[String]), "lantern_c"),
		"basket": _row(_box_mesh(Vector3(1.5, 1.66, 1.9), Vector3(0.0, 0.83, 0.0), ["wicker"] as Array[String]), "basket_b")})
	var prewarm := PrewarmScript.new()
	FixtureKitScript.register(prewarm, props)
	WarrenKitScript.register(prewarm, props)
	var parent: Node3D = _keep(Node3D.new())
	var slots: Array[Node3D] = []
	FixtureKitScript.hanging(parent, slots, props, Transform3D.IDENTITY)
	FixtureKitScript.root_bin(parent, slots, props)
	FixtureKitScript.rug(parent, props)
	FixtureKitScript.large_bed(parent, props)
	for mesh: Mesh in [WarrenKitScript.hand_lantern(props), WarrenKitScript.basket(props), WarrenKitScript.loaded_basket(props)]:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		parent.add_child(node)
	var checked := 0
	for node: Node in parent.find_children("*", "GeometryInstance3D", true, false):
		checked += 1
		assert_true(prewarm.covers(node as GeometryInstance3D), "%s is registered" % node.name)
	assert_true(checked >= 12, "every piece walked (%d)" % checked)


# --- the mutation run's survivors (decision 0371) ---------------------------------------------------

func test_a_hole_moved_or_wound_the_other_way_is_cut_again() -> void:
	"""A hole given again in a new place is cut there; one wound clockwise is cut as one wound the other way; the collar
	is wound as the ground it stands for (facing up)."""
	var ground: MeshInstance3D = _keep(_ground_grid(4, 8.0))
	var cut := GroundCutScript.new()
	cut.set_ground(ground)
	var total := _area(ground.mesh)
	var square := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	cut.set_hole(0, square)
	cut.apply()
	var moved := PackedVector2Array([Vector2(3, 3), Vector2(6, 3), Vector2(6, 5), Vector2(3, 5)])
	cut.set_hole(0, moved)
	assert_true(cut.apply(), "moved: cut again")
	assert_almost_equal(_area(ground.mesh) + _area(cut.collar.mesh), total - 6.0, "the moved hole's area")
	var clockwise := moved.duplicate()
	clockwise.reverse()
	cut.set_hole(0, clockwise)
	cut.apply()
	assert_almost_equal(_area(ground.mesh) + _area(cut.collar.mesh), total - 6.0, "wound the other way: the same")
	var points: PackedVector3Array = cut.collar.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ground_points: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ground_index: PackedInt32Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var up := _facing(ground_points[ground_index[0]], ground_points[ground_index[1]], ground_points[ground_index[2]])
	for t in points.size() / 3:
		assert_equal(_facing(points[t * 3], points[t * 3 + 1], points[t * 3 + 2]), up, "collar triangle %d wound as the ground" % t)


static func _facing(a: Vector3, b: Vector3, c: Vector3) -> bool:
	"""Whether a triangle's winding faces up."""
	return (b - a).cross(c - a).y > 0.0


func test_the_cutting_s_width_floor_and_ends() -> void:
	"""The cutting is the bore's floor and 5 cm either side wide; its floor is the ramp's at both ends of every step; it
	opens into no forecourt narrower than itself; a home's door ramp ends in a throat DOOR_THROAT_M long."""
	assert_almost_equal(MouthScript.cut_half_m(Rules.BORE_STANDARD), 0.55, "standard: 0.5 m and 5 cm")
	assert_almost_equal(MouthScript.cut_half_m(Rules.BORE_WIDE), 1.05, "widened: 1.0 m and 5 cm")
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	var mesh := MouthScript.cutting_mesh(Rules.BORE_STANDARD, portal, MouthScript.END_THROAT, 0.3)
	var shallowest := {}
	for p: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(p.x) < 0.3 and p.z <= portal + 1e-4:
			var z := snappedf(p.z, 0.001)
			shallowest[z] = maxf(shallowest.get(z, -INF), p.y + Rules.ramp_depth_m(p.z))
		if p.y < -0.01:
			assert_true(absf(p.x) < 0.6, "no forecourt narrower than the cutting (%.2f)" % p.x)
	for z: float in shallowest:
		assert_almost_equal(shallowest[z], 0.0, "the floor at %.2f m, never a step's start" % z)
	var door := MouthScript.cutting_mesh(Rules.BORE_WIDE, 4.0, MouthScript.END_DOOR)
	var far := 0.0
	for p: Vector3 in door.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		far = maxf(far, p.z)
	assert_almost_equal(far, 4.0 + MouthScript.DOOR_THROAT_M, "a door's throat")
	assert_almost_equal(MouthScript.court_half_m(null, Rules.BORE_STANDARD),
		MouthScript.OPENING_M * 0.5 + MouthScript.JAMB_WIDTH_M + MouthScript.CUT_MARGIN_M, "the stand-in gateway's forecourt")


func test_an_exit_s_cutting_a_planned_mouth_and_a_room_being_dug() -> void:
	"""The exit ramp's cutting (its mouth at the ramp's far end) is open near that mouth; an unopened mouth's ramp has
	none; a burrow home still being dug opens its ramp as a tunnel's, to the portal."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 0, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	var exit := chain[chain.size() - 1]
	assert_false(MouthScript.in_open_cutting(network, chain[0], 1.0), "not yet dug: no cutting")
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	var at_b: bool = network.mouth_end_at_b(exit)
	var near := network.length_m(exit) - 1.0 if at_b else 1.0
	assert_true(MouthScript.in_open_cutting(network, exit, near), "the exit's cutting, 1 m in from its mouth")
	var home := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(10240, 8192), 0, 0, home)
	network.start_dig(home[3], home[4], 0)
	network.advance(home[3], home[4], 1000000000)
	var mouth: int = network.mouth_of_end(home[3], network.mouth_end_at_b(home[3]))
	assert_almost_equal(MouthScript.cutting_run_m(network, mouth), Rules.portal_m(int(network.bore[home[3]])),
		"a home being dug: to the portal, as a tunnel's")


func test_the_staged_arch_s_forecourt_is_its_piers_width() -> void:
	"""With the staged arch the forecourt opens to COURT_SHARE of the arch's half-width as drawn for the bore."""
	var arch := _box_mesh(Vector3(1.9, 1.56, 0.67), Vector3(0.0, 0.78, 0.0), ["arch"] as Array[String])
	var props := _staged({"tunnel_arch_open": _row(arch, "arch_b")})
	var drawn: float = props.drawn_bound(&"tunnel_arch_open").size.x * MouthScript.arch_scale(props, Rules.BORE_STANDARD)
	assert_almost_equal(MouthScript.court_half_m(props, Rules.BORE_STANDARD), drawn * 0.5 * MouthScript.COURT_SHARE, "to the piers")


func test_a_whole_model_has_no_parts_and_a_parted_one_its_whole_bound() -> void:
	"""A staged model without parts answers no parts; one in parts is bound by the whole, not its first part; the large
	bed drawn is the staged large bed's own mesh."""
	var bed := _box_mesh(Vector3(1.24, 0.8, 3.21), Vector3(0.0, 0.4, 0.0), ["bed"] as Array[String])
	var props := _staged({"large_bed": _row(bed, "bed_c"), "burrow_door_open": _parts_row(_door_parts(), "door_d")})
	assert_false(props.has_parts(&"large_bed"), "a whole model: no parts")
	assert_equal(props.part_names(&"large_bed"), PackedStringArray(), "none named")
	assert_almost_equal(props.drawn_bound(&"burrow_door_open").size.x, 2.4, "the door's whole width, not its leaf's")
	var node := FixtureKitScript.large_bed(_keep(Node3D.new()), props)
	assert_true(node.mesh == props.mesh_of(&"large_bed"), "the staged large bed")


func test_a_digger_strikes_only_at_an_underground_face() -> void:
	"""With the swing, a digger strikes while it digs underground with a dig to strike at -- not at an entrance shaft on
	the surface, nor with no dig."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor.setup_placeholder(0, space, 3)
	actor._strike = StrikeScript.new()
	actor.brain.state = BrainScript.State.DIG
	actor.brain.dig_tunnel = 0
	actor.brain.underground = false
	assert_false(actor._striking(), "a shaft on the surface: no strike")
	actor.brain.underground = true
	actor.brain.dig_tunnel = -1
	assert_false(actor._striking(), "no dig: no strike")
	actor.brain.dig_tunnel = 0
	assert_true(actor._striking(), "at an underground face: strikes")
	assert_equal(actor.played_clip(), BrainScript.CLIP_IDLE, "standing between swings")


func test_the_swing_plays_once_and_the_walks_loop() -> void:
	"""The actor's clip library loops every clip but the dig swing."""
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor._player = AnimationPlayer.new()
	actor.add_child(actor._player)
	var paths := {}
	for clip: StringName in [DemoActorScript.CLIP_SWING, &"walk"]:
		var holder := Node3D.new()
		var player := AnimationPlayer.new()
		holder.add_child(player)
		player.owner = holder
		var library := AnimationLibrary.new()
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(&"clip", animation)
		player.add_animation_library(&"", library)
		var packed := PackedScene.new()
		packed.pack(holder)
		holder.free()
		var path := "%s/anim_%s.scn" % [FAKES, clip]
		DirAccess.make_dir_recursive_absolute(FAKES)
		ResourceSaver.save(packed, path)
		paths[String(clip)] = path
	actor._build_library(paths, {})
	var swing := actor._player.get_animation(&"cast/%s" % DemoActorScript.CLIP_SWING)
	var walk := actor._player.get_animation(&"cast/walk")
	assert_equal(swing.loop_mode, Animation.LOOP_NONE, "the swing once")
	assert_equal(walk.loop_mode, Animation.LOOP_LINEAR, "the walk loops")


func test_a_cellar_s_hatch_has_no_cutting_and_heaps_keep_off_a_cutting_s_banks() -> void:
	"""A dug cellar's hatch covers its ramp: its mouth draws no cutting and cuts no ground. A heap's gap from a tunnel's
	cutting is measured to its banks."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(network, space)
	var ground: MeshInstance3D = _keep(_ground_grid(6, 8.0))
	overlay.set_ground(ground)
	var cellar := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(4096, 4096), 0, 0, cellar)
	network.start_dig(cellar[3], cellar[4], 0)
	network.advance(cellar[3], cellar[4], 1000000000)
	var body: int = network.rooms.body[cellar[0]]
	network.start_dig(body, network.generation[body], 0)
	network.advance(body, network.generation[body], 1000000000)
	overlay.refresh()
	var m: int = network.mouth_of_end(cellar[3], network.mouth_end_at_b(cellar[3]))
	assert_false(overlay.hole(m).visible, "the hatch's mouth draws nothing")
	assert_equal(MouthScript.cutting_gap(network, m, network.mouth_at(m) + network.mouth_inward(m) * 0.3, 1.0, 0.0), INF,
		"and has no cutting to keep off")
	assert_equal(overlay.ground_cut.hole_count(), 0, "and cuts no ground")
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([-12288, 0, -12288, 16384]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	network.start_dig(chain[0], network.generation[chain[0]], 0)
	network.advance(chain[0], network.generation[chain[0]], 1000000000)
	var tm: int = network.mouth_of_end(chain[0], network.mouth_end_at_b(chain[0]))
	var into: Vector2 = network.mouth_inward(tm)
	var across := Vector2(into.y, -into.x)
	var beside: Vector2 = network.mouth_at(tm) + into * 1.5 + across * 1.0
	assert_almost_equal(HeapsScript.cutting_gap(network, space, tm, beside), 1.0 - MouthScript.bank_half_m(Rules.BORE_STANDARD), "to its banks")
	var court: Vector2 = network.mouth_at(tm) + into * 2.5 + across * 0.9
	assert_almost_equal(HeapsScript.cutting_gap(network, space, tm, court), 0.0, "on its forecourt")
	assert_true(space.on_mouth(court, 0.25), "nobody stands on the forecourt's hole either")
	assert_false(space.on_mouth(network.mouth_at(tm) + into * 1.5 + across * 0.9, 0.25), "but beside the cutting before it")
	var past: Vector2 = network.mouth_at(tm) + into * (Rules.portal_m(Rules.BORE_STANDARD) + MouthScript.ARCH_DEPTH_M + 0.5)
	assert_almost_equal(HeapsScript.cutting_gap(network, space, tm, past), 0.5, "past the arch: 0.5 m off its far side")


func test_a_new_face_begun_within_a_frame_is_owed_its_first_swing() -> void:
	"""A digger that finishes one face and starts the next inside one frame (no step off the face to reset on) is still
	owed a swing: the cut count going down is a new dig."""
	var strike := StrikeScript.new()
	strike.swing_s = 0.2
	strike.impact_s = 0.1
	var cuts := 0
	for k in roundi(20.0 / DT):
		if k % roundi(1.0 / DT) == 0 and k > 0:
			cuts += 1
		strike.step(cuts, DT)
	var before := strike.swings
	assert_equal(before, cuts + 1, "one as it reached the face and one a cut")
	for k in roundi(2.0 / DT):
		strike.step(0, DT)
	assert_equal(strike.swings, before + 1, "the next face, its count back to none: its first swing")
	assert_true(strike.period() < 0.0, "its time between cuts not yet known")


func test_a_hole_splits_no_triangle_it_misses_and_leaves_no_slivers() -> void:
	"""A distant hole's edge lines split nothing outside its bound (the collar of two holes is the two collars); a hole
	whose edge runs through the ground's corners leaves no zero-area triangle; the ground is read when it is given, and
	a new ground takes the collar with it."""
	var ground: MeshInstance3D = _keep(_ground_grid(8, 2.0))
	var a := PackedVector2Array([Vector2(-3.5, 0.5), Vector2(-2.5, 0.5), Vector2(-2.5, 1.5), Vector2(-3.5, 1.5)])
	var b := PackedVector2Array([Vector2(2.5, 0.8), Vector2(3.5, 0.8), Vector2(3.5, 1.2), Vector2(2.5, 1.2)])
	var counts := PackedInt32Array()
	for holes: Array in [[a], [b], [a, b]]:
		var cut := GroundCutScript.new()
		cut.set_ground(_keep(_ground_grid(8, 2.0)))
		for k in holes.size():
			cut.set_hole(k, holes[k])
		cut.apply()
		counts.append(cut.collar.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	assert_equal(counts[2], counts[0] + counts[1], "two holes' collar: the two collars, no more")
	var cut := GroundCutScript.new()
	cut.set_ground(ground)
	assert_true(cut._made == ground.mesh, "the ground read when given (not on the first frame a mouth opens)")
	cut.set_hole(0, PackedVector2Array([Vector2(-2, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-2, 1)]))
	cut.apply()
	var points: PackedVector3Array = cut.collar.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for t in points.size() / 3:
		var area := absf((points[t * 3 + 1] - points[t * 3]).cross(points[t * 3 + 2] - points[t * 3]).y)
		assert_true(area > 1e-6, "collar triangle %d has an area" % t)
	var other: MeshInstance3D = _keep(_ground_grid(8, 2.0))
	cut.set_ground(other)
	cut.apply()
	assert_true(cut.collar.get_parent() == other, "a new ground: the collar under it")
