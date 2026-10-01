extends RefCounted
## The village's side of the object list, the targets' rings and "Run until a project is done": which owner each kind
## of target is read from, and which selected thing is a project. Decision 0471. Presentation only; static.
##
## `register` hands world_targets.gd each kind's five owner calls -- the cast, the farm's beds, the woods' stand, the
## water's bridges, the network's mouths and rooms -- selecting through the very calls a click makes (a tunnel mouth
## selects its ramp, a room its fit-out, and in the U view each is shown on its own level).
## `project_into` gives run_until.gd the selected PROJECT and its watch: a selected room still being dug, else a
## selected tunnel being dug, paused or planned, else the bridge planned at the Water panel's chosen site. Each watch
## names its row by (row, generation), so a row reused for something else reads GONE.

const TargetsScript := preload("res://demo/access/world_targets.gd")
const RunScript := preload("res://demo/session/run_until.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CastScript := preload("res://demo/cast/demo_cast.gd")
const FarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const ToolScript := preload("res://demo/tunnel/tunnel_control.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ExtScript := preload("res://demo/tunnel/tunnel_ext.gd")

const MOUTH_NAME: String = "Mouth of tunnel %d"
const ROOM_NAME: String = "%s %d"
const TUNNEL_NAME: String = "Tunnel %d"
const PLANNED_BRIDGE: String = "%s (being built)"


static func register(targets: TargetsScript, cast: CastScript, farm: FarmScript, forestry: ForestryScript,
		waterplay: WaterplayScript, tool: ToolScript, select_resident: Callable, select_tunnel: Callable) -> void:
	"""Every kind's owner calls (see the header)."""
	targets.register(TargetsScript.KIND_RESIDENT, cast.actor_count, func(i: int) -> bool: return i < cast.actor_count(),
		func(i: int) -> String: return String(cast.actor(i).get(&"display_name")),
		func(i: int) -> Vector3: return _at(cast.actor(i)),
		select_resident)
	targets.register(TargetsScript.KIND_BED, func() -> int: return Catalog.BED_COUNT, func(_b: int) -> bool: return true,
		farm.crew.bed_label, JumpScript.bed_point, farm.select_bed)
	var stand: StandScript = forestry.stand
	targets.register(TargetsScript.KIND_TREE, stand.count, stand.is_tree, stand.label_of,
		func(t: int) -> Vector3: return JumpScript.tree_point(stand, t), forestry.select_tree)
	var bridges: BridgesScript = waterplay.bridges
	targets.register(TargetsScript.KIND_BRIDGE, func() -> int: return BridgesScript.MAX_BRIDGES,
		func(r: int) -> bool: return bridges.phase[r] != BridgesScript.PHASE_FREE, bridge_label.bind(bridges),
		func(r: int) -> Vector3: return JumpScript.bridge_point(bridges, r), waterplay.select_bridge)
	_register_below(targets, tool, select_tunnel)


static func _register_below(targets: TargetsScript, tool: ToolScript, select_tunnel: Callable) -> void:
	"""The network's mouths and rooms."""
	var network: GraphScript = tool.network
	targets.register(TargetsScript.KIND_MOUTH, func() -> int: return Rules.MAX_MOUTHS, network.is_mouth,
		func(m: int) -> String: return MOUTH_NAME % (network.mouth_ramp(m) + 1),
		func(m: int) -> Vector3: return _flat(network.mouth_at(m), 0.0),
		func(m: int) -> void: select_tunnel.call(network.mouth_ramp(m)))
	var rooms: RoomsScript = network.rooms
	targets.register(TargetsScript.KIND_ROOM, func() -> int: return RoomsScript.MAX_ROOMS, rooms.is_room,
		room_label.bind(rooms), func(r: int) -> Vector3: return _flat(rooms.centre_m(r), -Rules.to_m(rooms.floor_depth_u(r))),
		func(r: int) -> void: select_room(tool, r))


static func select_room(tool: ToolScript, r: int) -> void:
	"""Select room `r` as a click on it does, on its own level in the U view, its panel forward."""
	var rooms: RoomsScript = tool.network.rooms
	tool.ext.select_room(r)
	tool.reveal_tunnel(rooms.first_segment(r))
	tool.ext.panel_wanted.emit()


static func room_label(r: int, rooms: RoomsScript) -> String:
	"""'Burrow home 2', 'Root cellar 3'."""
	return ROOM_NAME % [RoomsScript.NAMES[rooms.template[r]], r + 1]


static func bridge_label(r: int, bridges: BridgesScript) -> String:
	"""A bridge's name, and whether it is still being built."""
	return PLANNED_BRIDGE % bridges.names[r] if bridges.is_planned(r) else bridges.names[r]


static func _at(node: Node3D) -> Vector3:
	"""Where a node stands, on the ground."""
	return Vector3(node.position.x, 0.0, node.position.z)


static func _flat(at: Vector2, y: float) -> Vector3:
	"""A ground point (x, z) at height `y`."""
	return Vector3(at.x, y, at.y)


# --- the selected project ---------------------------------------------------------------------------------------

static func project_into(run: RunScript, tool: ToolScript, waterplay: WaterplayScript) -> void:
	"""The selected project and its watch, or none (see the header)."""
	var network: GraphScript = tool.network
	var ext: ExtScript = tool.ext
	if ext.has_room_selected() and not network.rooms.is_done(network, ext.selected_room):
		var r: int = ext.selected_room
		run.set_project(room_label(r, network.rooms), room_state.bind(network, r, ext.selected_room_gen))
		return
	var slot: int = ext.actions.selected
	if slot >= 0 and network.is_ref(slot, ext.actions.selected_gen) and network.is_unfinished(slot):
		run.set_project(TUNNEL_NAME % (slot + 1), tunnel_state.bind(network, slot, ext.actions.selected_gen))
		return
	var row := IntMath.IntResult.new()
	var bridges: BridgesScript = waterplay.bridges
	if waterplay.bridge_on_site_into(row) and bridges.is_planned(row.value):
		run.set_project(bridges.names[row.value], bridge_state.bind(bridges, row.value, bridges.generation[row.value]))
		return
	run.set_project("", Callable())


static func room_state(network: GraphScript, r: int, gen: int) -> int:
	"""A room's progress as the run reads it."""
	if not network.rooms.is_ref(r, gen):
		return RunScript.PROJECT_GONE
	return RunScript.PROJECT_DONE if network.rooms.is_done(network, r) else RunScript.PROJECT_UNFINISHED


static func tunnel_state(network: GraphScript, slot: int, gen: int) -> int:
	"""A tunnel segment's progress as the run reads it."""
	if not network.is_ref(slot, gen):
		return RunScript.PROJECT_GONE
	return RunScript.PROJECT_DONE if network.is_open(slot) else RunScript.PROJECT_UNFINISHED


static func bridge_state(bridges: BridgesScript, row: int, gen: int) -> int:
	"""A bridge's progress as the run reads it."""
	if bridges.phase[row] == BridgesScript.PHASE_FREE or bridges.generation[row] != gen:
		return RunScript.PROJECT_GONE
	return RunScript.PROJECT_DONE if bridges.is_open(row) else RunScript.PROJECT_UNFINISHED
