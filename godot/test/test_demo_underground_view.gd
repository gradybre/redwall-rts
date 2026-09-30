extends "res://test/framework/test_case.gd"
## The underground view as a layer cutaway (decision 0206; docs/design/underground_revamp.md P0): the
## render layers every drawn node keeps, a switch that writes nothing but the camera's mask, the prewarm
## registry that covers everything the U view draws, the cap's masks, and the pick plane's maths. Built
## the way demo_village.gd wires the village -- world, water, cast, command layer (and its tunnel works),
## farm and woods on one set of services -- over placeholders (no staged assets).

const Layers := preload("res://demo/demo_layers.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const DT: float = 1.0 / 30.0
## The demo camera's default pose: 50 degrees down, 22 m from its focus (demo_camera.gd).
const PITCH_DEG: float = 50.0
const DISTANCE_M: float = 22.0

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


# --- the village ------------------------------------------------------------------------------

func _village() -> Dictionary:
	"""The village as demo_village.gd wires it: {world, water, cast, command, tool, farm, woods, camera}."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new())
	world.build({"world": {}, "cast": {}})
	var props := PropsScript.new()
	var water: DemoWaterScript = _keep(DemoWaterScript.new())
	water.build({"world": {}, "cast": {}}, world, props)
	var services := ServicesScript.new(water.map())
	services.props = props
	var obstacles: Array[Vector3] = water.merged_obstacles(world.obstacles())
	obstacles.append_array(ForestryScript.extra_obstacles(world))
	var cast: DemoCastScript = _keep(DemoCastScript.new())
	cast.build({}, water.merged_points(world.points_of_interest()), obstacles)
	cast.set_bounds(world.bounds())
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var camera: Camera3D = _keep(Camera3D.new())
	var command: CommandScript = _keep(CommandScript.new())
	command.configure(cast, camera, null, services)
	command.set_world(world)
	var farm: DemoFarmScript = _keep(DemoFarmScript.new())
	var providers: Array[Callable] = [FarmCellars.provider(command.tunnels().ext.works.chambers, command.tunnels().network)]
	farm.configure({}, world, cast, command, camera, null, providers, services)
	farm.follow_chambers(command.tunnels().ext.works.chambers)
	var woods: ForestryScript = _keep(ForestryScript.new())
	var wood := IntMath.IntResult.new()
	ForestryScript.resolve_wood_id_into(wood)
	woods.configure(world, cast, command, camera, services, wood)
	return {"world": world, "water": water, "cast": cast, "command": command, "tool": command.tunnels(),
		"farm": farm, "woods": woods, "camera": camera}


func _dig(v: Dictionary) -> int:
	"""Brendan's playtest scene, dug: a braced, lit tunnel by the beds with a find in it, a burrow home
	and a root cellar off it (both done, the cellar a pantry store), a resident walking in the bore, and
	a route being laid by the mole. Returns the tunnel's slot."""
	var tool: ControlScript = v["tool"]
	var network: NetworkScript = tool.network
	var ref := PackedInt32Array([-1, 0])
	assert_true(network.add_into(PackedInt32Array([-6758, 19456, -6758, 12288, -4096, 7168]), 3, 0, ref), "a tunnel")
	network.advance(ref[0], ref[1], 1000000000)
	network.set_braced(ref[0])
	network.set_lit(ref[0])
	var chambers: ChambersScript = tool.ext.works.chambers
	for spec: Array in [[ChambersScript.KIND_HOME, 1], [ChambersScript.KIND_CELLAR, -1]]:
		var along: int = network.length_u[ref[0]] * (2 + spec[1]) / 4
		var room := PackedInt32Array([0, 0])
		assert_true(chambers.add_into(spec[0], network, ref[0], along, ChambersScript.centre_for(network, ref[0], along, spec[1]), room), "a room")
		chambers.set_done(room[0])
	tool.ext.works.stores.add_find(FindsScript.FIND_FLINT)
	tool.ext.works._record_find(ref[0], Vector2i(-6758, 15000), FindsScript.FIND_FLINT)
	_send_below(v["cast"], network, ref[0])
	_plan_route(v)
	(v["farm"] as DemoFarmScript).storage.refresh()
	_frame(v)
	return ref[0]


func _send_below(cast: DemoCastScript, network: NetworkScript, slot: int) -> void:
	"""Put resident 2 walking in the bore, part way along it."""
	var below := (cast.actor(2) as DemoActorScript).brain
	var mid: Vector2 = network.point_at(slot, network.length_m(slot) * 0.5)
	below.order_move(mid)
	below._start_travel(slot, 0.0, network.length_m(slot) * 0.5)
	assert_true(below.underground, "a resident in the bore")


func _plan_route(v: Dictionary) -> void:
	"""The mole (the first digger) selected, laying a route: the plan's marks are up in both views."""
	var command: CommandScript = v["command"]
	var tool: ControlScript = v["tool"]
	for i: int in (v["cast"] as DemoCastScript).actor_count():
		if tool.is_digger(i):
			command.select(PackedInt32Array([i]))
			break
	assert_true(tool.begin_plan(), "planning")
	tool.lay_ground(Vector2(4.0, 2.0))
	tool.lay_ground(Vector2(8.0, 2.0))


func _frame(v: Dictionary) -> void:
	"""One frame of every drawing's own per-frame work (out of the tree, so called by hand)."""
	var cast: DemoCastScript = v["cast"]
	var tool: ControlScript = v["tool"]
	cast.advance(DT)
	tool.overlay.refresh()
	tool.ext._process(DT)
	tool._process(DT)
	(v["command"] as CommandScript)._place_rings()
	(v["command"] as CommandScript)._age_markers(DT)
	var farm: DemoFarmScript = v["farm"]
	farm.view._process(DT)
	farm.view.stock.refresh()


func _roots(v: Dictionary) -> Array[Node]:
	"""Every drawn root of the village."""
	return [v["world"], v["water"], v["cast"], v["command"], v["farm"], v["woods"]]


func _drawn(v: Dictionary) -> Array[VisualInstance3D]:
	"""Every VisualInstance3D (meshes, labels, particles, lights) in the village."""
	var out: Array[VisualInstance3D] = []
	for root: Node in _roots(v):
		for node: Node in root.find_children("*", "VisualInstance3D", true, false):
			out.append(node as VisualInstance3D)
	return out


static func _within(node: Node, ancestor: Node) -> bool:
	"""Whether `node` is `ancestor` or lies under it."""
	return node == ancestor or ancestor.is_ancestor_of(node)


# --- layers ---------------------------------------------------------------------------------

func test_the_layer_masks() -> void:
	"""Four layers, two views; a node belongs to exactly one; the U view picks on the floor."""
	assert_equal(Layers.view_mask(false), Layers.SURFACE | Layers.SURFACE_MARKS, "surface view: layers 1-2")
	assert_equal(Layers.view_mask(true), Layers.UNDERGROUND | Layers.UNDERGROUND_MARKS, "U view: layers 3-4")
	assert_equal(Layers.SURFACE_VIEW & Layers.UNDERGROUND_VIEW, 0, "no layer in both")
	assert_true(Layers.is_one_view(Layers.SURFACE) and Layers.is_one_view(Layers.UNDERGROUND_MARKS), "one view")
	assert_false(Layers.is_one_view(Layers.SURFACE | Layers.UNDERGROUND), "both is refused")
	assert_false(Layers.is_one_view(0), "neither is refused")
	assert_almost_equal(Layers.pick_y(false), 0.0, "the ground")
	assert_almost_equal(Layers.pick_y(true), -Rules.BORE_FLOOR_DEPTH_M, "the bore floor")
	assert_almost_equal(Layers.CAP_Y_M, -0.75, "the cap: half a bore over the floor")


func test_set_layers_walks_the_tree_and_skips_one_branch() -> void:
	"""Every VisualInstance3D under a root, not the skipped branch; plain nodes are walked through."""
	var root: Node3D = _keep(Node3D.new())
	var holder := Node3D.new()
	root.add_child(holder)
	var mesh := MeshInstance3D.new()
	holder.add_child(mesh)
	var light := OmniLight3D.new()
	root.add_child(light)
	var skipped := Node3D.new()
	root.add_child(skipped)
	var kept := MeshInstance3D.new()
	skipped.add_child(kept)
	assert_equal(Layers.set_layers(root, Layers.UNDERGROUND, skipped), 2, "the mesh and the light")
	assert_equal(mesh.layers, Layers.UNDERGROUND, "the nested mesh")
	assert_equal(light.layers, Layers.UNDERGROUND, "the light")
	assert_equal(kept.layers, Layers.SURFACE, "the skipped branch untouched")


func test_every_drawn_node_is_on_exactly_one_view_and_the_surface_stays_up() -> void:
	"""Over the dug village: every drawn node is in exactly one view; the world, the water, the woods and
	the farm's beds, crops and labels are surface; every Label3D is on a marks layer; the cap, troughs,
	rooms, frames, lanterns, finds, the cellar's shelf and the resident below are underground."""
	var v := _village()
	var slot := _dig(v)
	for node: VisualInstance3D in _drawn(v):
		assert_true(Layers.is_one_view(node.layers), "%s is in one view (layers %d)" % [node.get_path_to(node.owner) if node.owner else node.name, node.layers])
		if node is Label3D:
			assert_true(node.layers == Layers.SURFACE_MARKS or node.layers == Layers.UNDERGROUND_MARKS, "%s is a mark" % node.name)
	for root: Node in [v["world"], v["water"], v["woods"]]:
		for node: Node in root.find_children("*", "VisualInstance3D", true, false):
			assert_equal((node as VisualInstance3D).layers & Layers.UNDERGROUND_VIEW, 0, "%s stays on the surface" % node.name)
	var farm: DemoFarmScript = v["farm"]
	for bed: Node in farm.view.beds:
		for node: Node in bed.find_children("*", "VisualInstance3D", true, false):
			assert_equal((node as VisualInstance3D).layers & Layers.UNDERGROUND_VIEW, 0, "bed %s on the surface" % node.name)
	_check_underground(v, slot)


func _check_underground(v: Dictionary, slot: int) -> void:
	"""The dug scene's underground drawings are on the underground layers, and shown."""
	var tool: ControlScript = v["tool"]
	var below := v["cast"].actor(2) as DemoActorScript
	for node: VisualInstance3D in [tool.view.cap.cap(), tool.view.cap.deep(), tool.view.cap.light(), tool.overlay.bore(slot),
			tool.ext.marks.frames(slot), tool.ext.marks.lanterns(slot)]:
		assert_equal(node.layers, Layers.UNDERGROUND, "%s below" % node.name)
		assert_true(node.visible, "%s shown" % node.name)
	for c: int in 2:
		assert_equal(tool.ext.burrow_view.room(c).get_child_count() > 0, true, "room %d built" % c)
		for piece: Node in tool.ext.burrow_view.room(c).get_children():
			assert_equal((piece as VisualInstance3D).layers, Layers.UNDERGROUND, "room %d's %s below" % [c, piece.name])
	assert_true(tool.ext.find_props.shown_count() >= 1, "the find lies in the bore")
	assert_equal(below.layers_now(), Layers.UNDERGROUND, "the resident below")
	assert_false(below.marker().visible, "no marker while below")
	var above := v["cast"].actor(1) as DemoActorScript
	assert_true(above.marker().visible and above.marker().get_child(0).layers == Layers.UNDERGROUND_MARKS, "a marker for one above")
	var shelf: Node3D = (v["farm"] as DemoFarmScript).view.stock.shelf(1)
	assert_true(shelf.visible, "the cellar's shelf stands")
	for node: Node in shelf.find_children("*", "VisualInstance3D", true, false):
		assert_equal((node as VisualInstance3D).layers, Layers.UNDERGROUND, "the shelf's %s below" % node.name)


# --- a switch writes nothing ---------------------------------------------------------------------

func test_no_transparency_or_material_is_written_by_twenty_switches() -> void:
	"""Twenty U presses over the dug village, a frame of every drawing's work after each: no drawn node's
	transparency, material, visibility or layers, no material's transparency, and no node count moves --
	only the camera's cull mask. No room is rebuilt and no trough (decision 0206)."""
	var v := _village()
	_dig(v)
	var tool: ControlScript = v["tool"]
	var before := _snapshot(v)
	var rooms: int = tool.ext.burrow_view.room_builds
	var troughs: int = tool.overlay.bore_builds
	for press: int in 20:
		assert_true(tool.handle_input(_key(KEY_U)), "U")
		_frame(v)
		assert_equal((v["camera"] as Camera3D).cull_mask, Layers.view_mask(press % 2 == 0), "the mask")
		assert_true(_snapshot(v) == before, "nothing else moved after press %d" % press)
	assert_equal(tool.ext.burrow_view.room_builds, rooms, "no room built by a switch")
	assert_equal(tool.overlay.bore_builds, troughs, "no trough built by a switch")


func _snapshot(v: Dictionary) -> Dictionary:
	"""The village's drawn state (see `snapshot_of`)."""
	return snapshot_of(_roots(v))


static func snapshot_of(roots: Array) -> Dictionary:
	"""Everything a fade, a hide or a swap would change under `roots`: every Node3D's visibility, every
	VisualInstance3D's layers, every GeometryInstance3D's transparency and material, and each material it
	draws with -- a BaseMaterial3D's transparency and albedo alpha, a ShaderMaterial's every parameter --
	and the number of nodes. Shared by the tunnel suite's switch test."""
	var out := {}
	var count: int = 0
	for root: Node in roots:
		for node: Node in [root] + root.find_children("*", "", true, false):
			count += 1
			if node is Node3D:
				out[node.get_instance_id()] = [(node as Node3D).visible, (node as VisualInstance3D).layers if node is VisualInstance3D else 0]
			var geometry := node as GeometryInstance3D
			if geometry != null:
				out[-geometry.get_instance_id()] = [geometry.transparency, geometry.material_override, _material_state(geometry)]
	out[&"nodes"] = count
	return out


static func _material_state(geometry: GeometryInstance3D) -> Array:
	"""What each material `geometry` draws with would show of a fade: see `snapshot_of`."""
	var materials: Array[Material] = [geometry.material_override]
	var mesh: Mesh = PrewarmScript._mesh_of(geometry)
	for surface: int in mesh.get_surface_count() if mesh != null else 0:
		materials.append(mesh.surface_get_material(surface))
	var state: Array = []
	for material: Material in materials:
		if material is BaseMaterial3D:
			state.append([(material as BaseMaterial3D).transparency, (material as BaseMaterial3D).albedo_color.a])
		elif material is ShaderMaterial:
			var shader: Shader = (material as ShaderMaterial).shader
			for uniform: Dictionary in shader.get_shader_uniform_list() if shader != null else []:
				state.append((material as ShaderMaterial).get_shader_parameter(uniform["name"]))
	return state


static func _key(code: Key) -> InputEventKey:
	"""A plain key press."""
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


# --- the prewarm registry --------------------------------------------------------------------------

func test_the_prewarm_registry_covers_every_underground_material() -> void:
	"""Over the dug village: every node the U view draws -- every GeometryInstance3D on layer 3 or 4 --
	has each of its materials (or, a Label3D, its style) in the registry, except the residents' own bodies,
	which the surface view draws first with the same materials (their U-view markers are covered)."""
	var v := _village()
	_dig(v)
	var prewarm: PrewarmScript = v["tool"].view.prewarm
	var cast: DemoCastScript = v["cast"]
	var checked: int = 0
	for node: VisualInstance3D in _drawn(v):
		var geometry := node as GeometryInstance3D
		if geometry == null or node.layers & Layers.UNDERGROUND_VIEW == 0 or _is_body(cast, node):
			continue
		checked += 1
		assert_true(prewarm.covers(geometry), "%s (%s) is registered" % [node.name, node.get_class()])
	assert_true(checked > 20, "the U view's drawings were walked (%d)" % checked)
	assert_true(prewarm.mesh_count() > 20 and prewarm.label_count() >= 1, "meshes and a label style registered")


static func _is_body(cast: DemoCastScript, node: Node) -> bool:
	"""Whether `node` is part of a resident's body (not its marker)."""
	for i: int in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		if _within(node, actor) and not _within(node, actor.marker()):
			return true
	return false


func test_the_registry_answers_by_material_and_label_style() -> void:
	"""A pair's override covers a node with it; a mesh's own materials cover a node with none; an
	unregistered material or label style does not; pairs and styles register once."""
	var prewarm := PrewarmScript.new()
	var box := BoxMesh.new()
	box.material = StandardMaterial3D.new()
	var override := StandardMaterial3D.new()
	prewarm.add_mesh(box)
	prewarm.add_mesh(box, override)
	prewarm.add_mesh(box, override)
	assert_equal(prewarm.mesh_count(), 2, "two pairs")
	var node: MeshInstance3D = _keep(MeshInstance3D.new())
	node.mesh = box
	assert_true(prewarm.covers(node), "the mesh's own material")
	node.material_override = override
	assert_true(prewarm.covers(node), "the override")
	node.material_override = StandardMaterial3D.new()
	assert_false(prewarm.covers(node), "another material")
	var other := BoxMesh.new()
	other.material = StandardMaterial3D.new()
	node.mesh = other
	node.material_override = null
	assert_false(prewarm.covers(node), "a mesh whose own material is not registered")
	var label: Label3D = _keep(Label3D.new())
	label.no_depth_test = true
	assert_false(prewarm.covers(label), "an unregistered style")
	prewarm.add_label(label)
	prewarm.add_label(label)
	assert_true(prewarm.covers(label) and prewarm.label_count() == 1, "registered once")


func test_the_prewarm_draws_a_sample_of_everything_then_gives_the_view_back() -> void:
	"""begin_prewarm: a sample of every pair and label and a light, all on the U view's layers, and the
	camera on the U view; end_prewarm: the samples gone and the camera back on the surface."""
	var v := _village()
	var view: ViewScript = v["tool"].view
	var camera: Camera3D = v["camera"]
	view.begin_prewarm()
	assert_true(view.is_prewarming(), "samples up")
	var samples: Node = view.get_node(^"PrewarmSamples")
	assert_equal(samples.get_child_count(), view.prewarm.mesh_count() + view.prewarm.label_count() + 1, "one of each")
	assert_true(samples.find_children("*", "MultiMeshInstance3D", false, false).size() >= 3, "instanced ones instanced")
	assert_not_null(view.get_node_or_null(^"PrewarmCover"), "a cover over the screen meanwhile")
	for sample: Node in samples.get_children():
		assert_true((sample as VisualInstance3D).layers & Layers.UNDERGROUND_VIEW != 0, "%s in the U view" % sample.name)
		assert_true((sample as Node3D).position.y < Layers.CAP_Y_M, "under the cap")
	assert_equal(camera.cull_mask, Layers.UNDERGROUND_VIEW, "drawing the U view")
	view.end_prewarm()
	assert_false(view.is_prewarming(), "samples gone")
	assert_null(view.get_node_or_null(^"PrewarmSamples"), "the samples taken out")
	assert_null(view.get_node_or_null(^"PrewarmCover"), "and the cover")
	assert_equal(camera.cull_mask, Layers.SURFACE_VIEW, "the surface again")


# --- the cap ---------------------------------------------------------------------------------------

func test_the_cap_opens_over_a_dug_bore_and_room_only() -> void:
	"""A dug tunnel stamps its width into the void mask wherever its floor is at full depth -- not its
	mouths' ramps, which rise through the cap -- and a done room its floor; the ground beside them, and
	ground not yet dug, stays solid."""
	var v := _village()
	var slot := _dig(v)
	var tool: ControlScript = v["tool"]
	var cap: CapScript = tool.view.cap
	var network: NetworkScript = tool.network
	assert_false(cap.is_dug(network.mouth(slot, false)), "not the entrance's ramp")
	for share: float in [0.25, 0.5, 0.75]:
		assert_true(cap.is_dug(network.point_at(slot, network.length_m(slot) * share)), "the bore at %s" % share)
	var middle: Vector2 = network.point_at(slot, network.length_m(slot) * 0.5)
	var across: Vector2 = network.direction_at(slot, network.length_m(slot) * 0.5).orthogonal() * 0.75
	assert_false(cap.is_dug(middle + across) or cap.is_dug(middle - across), "solid either side, between the rooms")
	assert_true(cap.is_dug(tool.ext.works.chambers.centre_m(0)), "the home's floor")
	assert_false(cap.is_dug(Vector2(0.0, -15.0)), "undug ground")


func test_the_cap_marks_water_footings_and_roots() -> void:
	"""The no-dig band covers the water and half a bore round it; a building's circle is a footing; a
	mature tree has roots under it; open village ground has none of them."""
	var v := _village()
	var cap: CapScript = v["tool"].view.cap
	var water: WaterScript = WaterScript.new((v["water"] as DemoWaterScript).map())
	var wet: Vector2 = _water_point(water)
	assert_true(cap.water_code_at(wet) > 0.5, "the water is no-dig")
	assert_true(cap.water_code_at(Vector2(0.0, 0.0)) < 0.5, "the square is not")
	assert_almost_equal(CapScript.water_code(-CapScript.WATER_CLEARANCE_M), 0.5, "the band's edge is half a bore out")
	var building: Vector3 = (v["world"] as DemoWorldScript).building_obstacles()[0]
	var keep: float = Rules.to_m(Rules.BORE_WIDTH_U) * 0.5
	assert_true(cap.footing_m(Vector2(building.x, building.z)) > 0.9, "inside its footing")
	assert_true(cap.footing_m(Vector2(building.x + building.y + keep - 0.15, building.z)) > 0.0, "out to its radius and a half bore")
	assert_true(cap.footing_m(Vector2(-4.0, 1.0)) < 0.0, "open ground is none")
	var tree: Dictionary = _mature_tree(v["world"])
	assert_true(cap.mark_at(tree["at"], 2) > 0.3, "roots under a tree")


static func _water_point(water: WaterScript) -> Vector2:
	"""A point inside the village's water (metres), found on a 1 m sweep of the mapped square."""
	for z: int in range(-40, 40):
		for x: int in range(-40, 40):
			if water.map().is_water(Vector2i(Rules.to_u(float(x)), Rules.to_u(float(z)))):
				return Vector2(x, z)
	return Vector2.INF


static func _mature_tree(world: DemoWorldScript) -> Dictionary:
	"""The first mature oak or beech inside the mapped square."""
	for tree: Dictionary in world.trees():
		var at: Vector2 = tree["at"]
		if String(tree["key"]).ends_with("_mature") and absf(at.x) < CapScript.MAP_HALF_M and absf(at.y) < CapScript.MAP_HALF_M:
			return tree
	return {}


func test_a_footing_is_its_circle_and_a_half_bore() -> void:
	"""One circle of 1 m: the marks hold its signed distance out to 1.5 m (the half bore a route keeps
	off it), to the byte's precision, measured at pixel centres."""
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	cap.add_footprints([Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	for at: Vector2 in [Vector2(1.4, 0.1), Vector2(0.2, -1.1), Vector2(1.6, 0.4), Vector2(-0.4, 0.3)]:
		var centre: Vector2 = CapScript.marks_centre(CapScript.marks_pixel(at))
		assert_true(absf(cap.footing_m(centre) - clampf(1.5 - centre.length(), -1.0, 1.0)) < 0.02, "at %s" % centre)


func test_the_void_disc_is_the_bore_width() -> void:
	"""A disc stamps every mask pixel whose centre lies within its radius, and none beyond."""
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	cap.stamp_disc(Vector2(1.0, 2.0), 0.5)
	assert_true(cap.commit_void(), "uploaded")
	assert_false(cap.commit_void(), "once")
	assert_true(cap.is_dug(Vector2(1.0, 2.0)) and cap.is_dug(Vector2(1.43, 2.0)), "inside")
	assert_false(cap.is_dug(Vector2(1.57, 2.0)) or cap.is_dug(Vector2(1.0, 2.57)), "outside")


func test_a_tunnel_being_dug_opens_the_cap_up_to_its_face_only() -> void:
	"""Part way through a dig the void reaches the face wall and stops there -- nothing opens past it --
	and a tunnel dug before the cap was handed over is stamped once it is."""
	var v := _village()
	var tool: ControlScript = v["tool"]
	var network: NetworkScript = tool.network
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([-6758, 19456, -6758, 9000]), 2, 0, ref)
	network.advance(ref[0], ref[1], 24000000)
	tool.overlay.refresh()
	var face: float = tool.overlay.dug_m(ref[0])
	assert_true(face > 3.0 and not network.is_open(ref[0]), "part dug, past the ramp (%.2f m)" % face)
	assert_true(tool.view.cap.is_dug(network.point_at(ref[0], face - 0.2)), "open behind the face")
	assert_false(tool.view.cap.is_dug(network.point_at(ref[0], face + 0.3)), "solid past it")
	var late: OverlayScript = _keep(OverlayScript.new())
	late.configure(network, v["cast"].space())
	late.refresh()
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	late.set_view(cap, PrewarmScript.new())
	late.refresh()
	assert_true(cap.is_dug(network.point_at(ref[0], face - 0.2)), "stamped when the cap arrives")


func test_a_dig_face_opens_only_the_half_behind_it() -> void:
	"""A disc cut at a face keeps the half behind the face line and opens nothing past it."""
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	cap.stamp_disc(Vector2(0.0, 0.0), 0.5, Vector2(1.0, 0.0))
	assert_true(cap.is_dug(Vector2(-0.3, 0.0)) and cap.is_dug(Vector2(-0.1, 0.3)), "behind the face")
	assert_false(cap.is_dug(Vector2(0.2, 0.0)) or cap.is_dug(Vector2(0.3, 0.2)), "nothing past it")


# --- picking -------------------------------------------------------------------------------------

func test_the_pick_plane_lands_on_the_floor_point_under_the_pointer() -> void:
	"""A ray from the demo camera's default pose through a bore-floor point: the U view's plane gives
	that point back (to a micrometre); the old ground plane put it ~1.05 m short, toward the camera; and
	the cap shows, at the pixel the ray crosses it, exactly that floor point."""
	var floor_point := Vector3(3.0, Layers.FLOOR_Y_M, -2.0)
	var pitch: float = deg_to_rad(PITCH_DEG)
	var eye := Vector3(floor_point.x, DISTANCE_M * sin(pitch), floor_point.z + DISTANCE_M * cos(pitch))
	var direction: Vector3 = (floor_point - eye).normalized()
	var picked: Vector2 = Layers.pick_ground(eye, direction, Layers.pick_y(true))
	assert_true(picked.distance_to(Vector2(floor_point.x, floor_point.z)) < 1e-4, "the floor point (%s)" % picked)
	var old: Vector2 = Layers.pick_ground(eye, direction, 0.0)
	var expected: float = Rules.BORE_FLOOR_DEPTH_M * (eye.z - floor_point.z) / (eye.y - floor_point.y)
	assert_true(absf(old.distance_to(picked) - expected) < 1e-3, "the old error: the floor's depth over the ray's slope")
	assert_true(old.distance_to(picked) > 0.9, "about a metre (%.3f m)" % old.distance_to(picked))
	var t: float = PickScript.ray_ground(eye, direction, Layers.CAP_Y_M)
	var on_cap: Vector3 = eye + direction * t
	assert_true(Layers.floor_through(eye, on_cap, Layers.FLOOR_Y_M).distance_to(picked) < 1e-4, "the cap shows that point")
	assert_equal(Layers.pick_ground(eye, Vector3(0.0, 1.0, 0.0), 0.0), Vector2.INF, "a ray upward misses")


func test_in_the_u_view_a_surface_resident_is_picked_at_its_marker() -> void:
	"""The pick proxy of a resident above ground in the U view is its marker on the floor; below ground,
	its body; in the surface view, its body (the proxy decision 0196 made)."""
	var v := _village()
	var brain: BrainScript = (v["cast"].actor(1) as DemoActorScript).brain
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	CommandScript.proxy_into(brain, Vector3(1.0, 0.0, 2.0), 1.0, true, Vector3.ZERO, out)
	assert_almost_equal(out[1], Layers.FLOOR_Y_M, "on the floor")
	assert_almost_equal(out[3], CommandScript.MARKER_PICK_HEIGHT_M, "the marker's height")
	assert_almost_equal(out[4], DemoActorScript.MARKER_RADIUS_M + DemoActorScript.MARKER_EDGE_M, "and width")
	CommandScript.proxy_into(brain, Vector3(1.0, 0.0, 2.0), 1.0, false, Vector3.ZERO, out)
	assert_almost_equal(out[1], 0.0, "the surface view: its feet")
	assert_almost_equal(out[4], brain.radius, "its body")


func test_the_u_views_marks_are_drawn_over_the_cap_on_its_own_layer() -> void:
	"""Each mark is a pair: the surface's on its marks layer and depth-tested, the U view's on its own
	marks layer and drawn without a depth test (over the cap), on the floor."""
	var v := _village()
	var command: CommandScript = v["command"]
	command.select(PackedInt32Array([1]))
	command._place_rings()
	command.mark(Vector3(2.0, 0.0, 3.0), true)
	for pair: Array in [[command._rings[1], command._rings_below[1]], [command._markers[0], command._markers_below[0]]]:
		var above: MeshInstance3D = pair[0]
		var below: MeshInstance3D = pair[1]
		assert_equal([above.layers, below.layers], [Layers.SURFACE_MARKS, Layers.UNDERGROUND_MARKS], "one per view")
		assert_false((above.material_override as BaseMaterial3D).no_depth_test, "the surface's is depth-tested")
		assert_true((below.material_override as BaseMaterial3D).no_depth_test, "the U view's is drawn over the cap")
		assert_true(below.visible and absf(below.position.y - Layers.FLOOR_Y_M) < 0.1, "on the floor")


func test_the_u_view_keeps_releases_and_keys_for_the_surface_tools() -> void:
	"""In the U view a tool hook (the woods' zone marking) is not offered a mouse press, but a release, a
	motion and a key still reach it -- so a drag or an armed tool started before U can end."""
	var v := _village()
	var command: CommandScript = v["command"]
	var seen: Array[String] = []
	command.add_input_hook(func(event: InputEvent) -> bool:
		seen.append(event.get_class())
		return true)
	v["tool"].view.set_on(true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	command.handle_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	assert_true(command.handle_input(release), "a release taken by the hook")
	assert_true(command.handle_input(InputEventMouseMotion.new()), "a motion too")
	assert_true(command.handle_input(_key(KEY_ESCAPE)), "and a key")
	assert_equal(seen.size(), 3, "all but the press")


func test_the_views_plane_is_where_a_ray_lands() -> void:
	"""The tunnel view's own plane: a ray through a floor point lands on it in the U view, and on the
	ground (about a metre nearer the camera) in the surface view; a move order follows the same plane."""
	var v := _village()
	var view: ViewScript = v["tool"].view
	var command: CommandScript = v["command"]
	var floor_point := Vector3(3.0, Layers.FLOOR_Y_M, -4.0)
	var eye := Vector3(3.0, 16.9, 10.1)
	var ray: Vector3 = (floor_point - eye).normalized()
	view.set_on(true)
	assert_true(view.ground_along(eye, ray).distance_to(Vector2(3.0, -4.0)) < 1e-4, "U view: the floor point")
	command.select(PackedInt32Array([1]))
	command.order_along(eye, ray)
	var below_at: Vector3 = command._markers[(command._marker_next + 3) % 4].position
	view.set_on(false)
	assert_true(view.ground_along(eye, ray).distance_to(Vector2(3.0, -4.0)) > 0.9, "surface: the ground, nearer")
	command.order_to(floor_point)
	var direct: Vector3 = command._markers[(command._marker_next + 3) % 4].position
	assert_true(Vector2(below_at.x, below_at.z).distance_to(Vector2(direct.x, direct.z)) < 1e-3, "the order went where the floor point is")


func test_the_sun_lights_only_the_surface_and_the_fill_light_only_below() -> void:
	"""The world's sun is on the surface layer and lights the surface's; the cap's light is on the
	underground layer and lights only it (each culled with its view)."""
	var v := _village()
	var sun := (v["world"] as Node).find_child("Sun", true, false) as DirectionalLight3D
	assert_equal([sun.layers, sun.light_cull_mask, sun.shadow_caster_mask], [Layers.SURFACE, Layers.SURFACE_VIEW, Layers.SURFACE_VIEW],
		"the sun: lighting and shadowing the surface only")
	var fill: DirectionalLight3D = v["tool"].view.cap.light()
	assert_equal([fill.layers, fill.light_cull_mask], [Layers.UNDERGROUND, Layers.UNDERGROUND], "the fill")


func test_the_u_view_does_not_hand_clicks_to_surface_handlers() -> void:
	"""With the U view on, a left click on no resident and a right-click order skip the farm's, woods',
	water's and spoil heaps' handlers (surface things it does not draw) -- and reach them again after."""
	var v := _village()
	var command: CommandScript = v["command"]
	var asked: Array[int] = [0]
	command.set_ground_handlers(func(_at: Vector2) -> bool:
		asked[0] += 1
		return true, func(_at: Vector2) -> bool:
		asked[0] += 1
		return true)
	command.select(PackedInt32Array([1]))
	v["tool"].view.set_on(true)
	command._finish_select(Vector2(-10000.0, -10000.0))
	command.select(PackedInt32Array([1]))
	command.order_at(Vector2(-10000.0, -10000.0))
	assert_equal(asked[0], 0, "neither asked in the U view")
	v["tool"].view.set_on(false)
	command.order_at(Vector2(-10000.0, -10000.0))
	command._finish_select(Vector2(-10000.0, -10000.0))
	assert_equal(asked[0], 2, "both asked on the surface")


# --- residents -----------------------------------------------------------------------------------

func test_a_resident_changes_layer_going_down_and_up_and_its_parts_follow() -> void:
	"""Down a bore: the body on the underground layer and no marker; a tool it takes up while below
	joins that layer; back up: the surface layer and its marker again, placed on the floor under it."""
	var v := _village()
	var tool: ControlScript = v["tool"]
	var network: NetworkScript = tool.network
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([-6758, 19456, -6758, 12288]), 2, 0, ref)
	network.advance(ref[0], ref[1], 1000000000)
	var actor := v["cast"].actor(2) as DemoActorScript
	_send_below(v["cast"], network, ref[0])
	v["cast"].advance(DT)
	assert_equal(actor.layers_now(), Layers.UNDERGROUND, "below")
	assert_false(actor.marker().visible, "no marker")
	actor.set_work_tool(BoxMesh.new(), Transform3D.IDENTITY)
	assert_equal((actor.get_node(^"WorkTool") as VisualInstance3D).layers, Layers.UNDERGROUND, "the tool joins it")
	actor.hold(BoxMesh.new(), Transform3D.IDENTITY)
	assert_equal((actor.get_node(^"Held") as VisualInstance3D).layers, Layers.UNDERGROUND, "and a good it takes up")
	actor.brain._set_underground(false)
	actor.brain.state = BrainScript.State.IDLE
	v["cast"].advance(DT)
	assert_equal(actor.layers_now(), Layers.SURFACE, "up")
	assert_equal((actor.get_node(^"WorkTool") as VisualInstance3D).layers, Layers.SURFACE, "with its tool")
	assert_true(actor.marker().visible, "its marker back")
	assert_almost_equal(actor.marker().position.y, Layers.FLOOR_Y_M + Layers.MARK_LIFT_M, "on the floor")
	assert_almost_equal(actor.marker().position.x, actor.brain.position.x, "under it")
