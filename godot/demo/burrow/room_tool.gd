extends Node3D
## The Dig tool's room tools: Burrow home and Root cellar, rooms laid as their own structures. Decision 0209
## (the underground revamp's P3; design docs/design/underground_revamp.md §4 "Tools", "Ghost preview").
## Presentation only.
##
## CONTROLS (the Dig tool, tunnel_control.gd, hands them here while a room tool is open):
##   H / C in the Dig tool, or the party panel's       the Burrow home / Root cellar tool (the same key
##   "Burrow home (H)" / "Root cellar (C)"             again: back to laying tunnels)
##   the pointer          the GHOST room follows it, on the quarter-metre lattice
##   R / Shift+R          turn it a quarter turn on / back -- the HUD's `placement_rotate` keys; the wheel
##                        stays the camera's zoom. (R releases the party only outside the Dig tool.)
##   left click           dig it there, with its proposed passage; Shift+click: standalone, no passage
##   Esc / right click    back to laying tunnels
## The tool stays open after a room is laid, for the next.
##
## THE GHOST (drawn on top, in both views): the room's void outline, its door ramp out to its mouth and a tick
## at each socket (room_view.gd `outline_into`) -- chalk-cream while it may be dug, clay when not -- its
## proposed passage (room_plan.gd THE AUTO-PASSAGE) from the network to the socket it joins, brass rings at
## both ends; and over its middle the readout (dig_readout.gd `room_text`) or, refused, the reason in words
## (underground_rooms.gd REASONS; MOVE-REQ-018: never colour alone). It is checked and redrawn only when it
## moves to another lattice point, turns, or the network or the ground's obstacles change -- the SITE (what a
## room must keep clear of: heaps, mouths, work spots) is taken afresh then, and again as a room is clicked.
##
## LAYING A ROOM. Checked again as it is clicked, the room is laid as one piece of the network
## (underground_graph.gd `add_room`) and its passage as the next piece, ending at its socket -- both in the
## digger's job list, the room first. Its digger is the Dig tool's (the first selected resident who can dig,
## else the most skilled); the rest of the selection crews it. Its door must be clear of residents and, when
## the digger starts now, within its reach -- a tunnel's entrance's rules. Should its passage fail the rules
## once the room is laid (the network's last rows, say), the room stands alone and the notice says why.
##
## ON LEVEL 2 (decision 0212). The tool places rooms on the level the U view shows (PgUp/PgDn switches it and the
## ghost with it). A room on level 2 has no door to the surface: its passage joins its door (room_plan.gd ON LEVEL
## 2), is laid with it and dug FIRST (underground_graph.gd `adopt_passage`), the room after; it cannot stand
## alone, so Shift+click is refused there, and a passage failing once the room is laid drops the room again. Its
## ghost and words lie on level 2's floor on level 2's marks layer, and its outline has no door ramp.

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomPlanScript := preload("res://demo/burrow/room_plan.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Layers := preload("res://demo/demo_layers.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")

## The ghost's centre sits on this lattice (u): a quarter metre.
const LATTICE_U: int = 256
const GHOST_CREAM: Color = Color(Palette.CREAM, 0.7)
const GHOST_CLAY: Color = Color(Palette.CLAY, 0.8)
const PASSAGE_COLOUR: Color = Color(Palette.BRASS, 0.85)
const PASSAGE_WIDTH_M: float = 0.3
const RING_M: float = 0.55
const LABEL_PX: int = 40
const LABEL_PIXEL: float = 0.0006
## The words sit centred over the ghost and wrap at LABEL_WRAP_PX, so a long refusal stays on screen beside the
## side panels (the tunnel tool's words run off to the pointer's right; a room's ring is wide enough to hold them).
const LABEL_OFFSET_PX: Vector2 = Vector2(0.0, 0.0)
const LABEL_WRAP_PX: float = 820.0
const PROMPT: String = "%s: move to place it, R to turn it, click to dig -- Shift+click: no passage · Esc: back to tunnels"
const LAID: String = "%s %d laid: %s digs it%s"
const WITH_PASSAGE: String = ", then its passage"
const WITHOUT_PASSAGE: String = " -- standalone: its passage may not be dug (%s)"
const QUEUED: String = " after its present dig"
const REFUSED: String = "Can't dig a room there: %s"
const LOWER_PASSAGE: String = ", its passage first"

var active: bool = false
var plan: RoomPlanScript = RoomPlanScript.new()

var _control: Node3D = null
var _network: GraphScript = null
var _site: RoomsScript.Site = RoomsScript.Site.new()
var _has_cursor: bool = false
## What the ghost was last checked and drawn for: its centre (u), its turns and the site's serial (-1: redraw).
var _checked: Vector4i = Vector4i(0, 0, 0, -1)
## The network revision and the ground's obstacle builds the site was taken at, and its serial.
var _site_key: Vector2i = Vector2i(-1, -1)
var _site_serial: int = 0
var _words: String = ""
## Why the last room laid stands alone although a passage was proposed ("": it did not, or none was).
var _passage_words: String = ""
## How many times the ghost has been drawn (see THE GHOST: only when it moves, turns or its site changes).
var ghost_draws: int = 0
var _ghost: MeshInstance3D = null
var _ghost_below: MeshInstance3D = null
var _passage: MeshInstance3D = null
var _passage_below: MeshInstance3D = null
var _rings: Array[MeshInstance3D] = []
var _label: Label3D = null
var _label_below: Label3D = null
var _materials: Array[StandardMaterial3D] = []


func configure(control: Node3D) -> void:
	"""The room tools of this Dig tool (tunnel_control.gd), drawing their ghost beside it."""
	name = "RoomTool"
	_control = control
	_network = control.network
	for colour: Color in [GHOST_CREAM, GHOST_CLAY, PASSAGE_COLOUR]:
		_materials.append(_on_top(colour))
	_ghost = _mesh_node(Layers.SURFACE_MARKS, 0.0)
	_ghost_below = _mesh_node(Layers.UNDERGROUND_MARKS, Layers.FLOOR_Y_M)
	_passage = _mesh_node(Layers.SURFACE_MARKS, 0.0)
	_passage_below = _mesh_node(Layers.UNDERGROUND_MARKS, Layers.FLOOR_Y_M)
	_ghost_below.mesh = _ghost.mesh
	_passage_below.mesh = _passage.mesh
	for node: MeshInstance3D in [_ghost, _ghost_below]:
		node.material_override = _materials[0]
	for node: MeshInstance3D in [_passage, _passage_below]:
		node.material_override = _materials[2]
	for _end in 2:
		_rings.append(_ring(Layers.SURFACE_MARKS, 0.0))
		_rings.append(_ring(Layers.UNDERGROUND_MARKS, Layers.FLOOR_Y_M))
	_label = _words_label(Layers.SURFACE_MARKS, 0.6)
	_label_below = _words_label(Layers.UNDERGROUND_MARKS, Layers.FLOOR_Y_M + 0.6)


static func _on_top(colour: Color) -> StandardMaterial3D:
	"""A flat see-through material drawn over everything (the ghost's)."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 2
	material.albedo_color = colour
	return material


func _mesh_node(layer: int, lift: float) -> MeshInstance3D:
	"""A ghost mesh node on `layer`, `lift` up, hidden."""
	var node := MeshInstance3D.new()
	node.mesh = ImmediateMesh.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = layer
	node.position.y = lift
	node.visible = false
	add_child(node)
	return node


func _ring(layer: int, lift: float) -> MeshInstance3D:
	"""A brass ring of the ghost's (a socket joined, a join on the network), drawn on top, hidden."""
	var ring := MarksScript.make_ring(Palette.BRASS)
	(ring.material_override as StandardMaterial3D).no_depth_test = true
	(ring.material_override as StandardMaterial3D).render_priority = 3
	ring.scale = Vector3(RING_M, 1.0, RING_M)
	ring.layers = layer
	ring.position.y = lift
	add_child(ring)
	return ring


func _words_label(layer: int, lift: float) -> Label3D:
	"""The ghost's words over its middle, wrapped, drawn on top, hidden."""
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = LABEL_PIXEL
	tag.font_size = LABEL_PX
	tag.outline_size = 10
	tag.outline_modulate = Palette.DEEP_SHADE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.width = LABEL_WRAP_PX
	tag.offset = LABEL_OFFSET_PX
	tag.layers = layer
	tag.position.y = lift
	tag.visible = false
	add_child(tag)
	return tag


func register(prewarm: PrewarmScript) -> void:
	"""What the ghost draws in the U view, for its prewarm (decision 0206)."""
	for material in _materials:
		prewarm.add_mesh(OverlayScript.immediate_sample(), material)
	for ring in _rings:
		if ring.layers == Layers.UNDERGROUND_MARKS:
			prewarm.add_mesh(ring.mesh, ring.material_override)
	prewarm.add_label(_label_below)


# --- the tool ---------------------------------------------------------------------------------

func begin(kind: int, clear_of: RoomsScript.Site) -> void:
	"""Open the tool for rooms of template `kind`, over `clear_of` (what a room must keep clear of)."""
	active = true
	plan.kind = kind
	set_level(_control.laying_level())
	_site = clear_of
	_site_key = _control.site_key()
	_site_serial += 1
	_checked = Vector4i(0, 0, 0, -1)
	_control.say(PROMPT % RoomsScript.NAMES[kind])
	_redraw()


func set_level(level: int) -> void:
	"""Place rooms on `level` (the U view's): the ghost's U-view copies on its floor and marks layer, checked afresh
	(see ON LEVEL 2)."""
	plan.level = level
	var lift := Layers.floor_y(level)
	for node: Node3D in [_ghost_below, _passage_below]:
		node.position.y = lift
		(node as VisualInstance3D).layers = Layers.marks(level)
	for k in _rings.size():
		if k % 2 == 1:
			_rings[k].position.y = lift
			_rings[k].layers = Layers.marks(level)
	_label_below.position.y = lift + 0.6
	_label_below.layers = Layers.marks(level)
	_checked = Vector4i(0, 0, 0, -1)
	_redraw()


func end() -> void:
	"""Close the tool (back to laying tunnels, or the Dig tool closed): its ghost hidden, and no pointer held."""
	active = false
	_has_cursor = false
	for node: Node3D in [_ghost, _ghost_below, _passage, _passage_below, _label, _label_below]:
		node.visible = false
	for ring in _rings:
		ring.visible = false


func handle_input(event: InputEvent) -> bool:
	"""The tool's input (see CONTROLS): the pointer, a click, R, Esc and a right click. True when taken."""
	var motion := event as InputEventMouseMotion
	if motion != null:
		hover(motion.position)
		return false
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		hover(button.position)
		place(button.shift_pressed)
		return true
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		_control.end_room()
		return true
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_R or key.keycode == KEY_R:
		turn(-1 if key.shift_pressed else 1)
		return true
	if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
		_control.end_room()
		return true
	return false


func hover(screen: Vector2) -> void:
	"""Follow the pointer with the ghost."""
	var at: Vector2 = _control.view.ground_at(screen)
	_has_cursor = at != Vector2.INF
	if _has_cursor:
		move_to(at)


func move_to(at: Vector2) -> void:
	"""Stand the ghost room at `at` (m), on the lattice, and check it."""
	_has_cursor = true
	plan.centre_u = Vector2i(snappedi(Rules.to_u(at.x), LATTICE_U), snappedi(Rules.to_u(at.y), LATTICE_U))
	_redraw()


func turn(by: int) -> void:
	"""Turn the ghost room `by` quarter turns (R, Shift+R)."""
	plan.rotate(by)
	_redraw()


func _redraw() -> void:
	"""Check the ghost where it stands (once per place, turn and network state) and draw it (see THE GHOST)."""
	if not active or not _has_cursor:
		return
	_refresh_site()
	var state := Vector4i(plan.centre_u.x, plan.centre_u.y, plan.turns, _site_serial)
	if state == _checked:
		return
	_checked = state
	plan.check(_network, _site)
	_words = _ghost_words()
	_draw_ghost()


func _refresh_site() -> void:
	"""Take the site afresh when the network or the ground's obstacles changed since it was taken."""
	var key: Vector2i = _control.site_key()
	if key != _site_key:
		_site_key = key
		_site = _control.room_site()
		_site_serial += 1


func _ghost_words() -> String:
	"""The readout for the ghost, or the reason it may not be dug."""
	if plan.refusal != RoomsScript.REFUSE_NONE:
		return RoomsScript.reason_text(plan.refusal)
	var digger: int = _control.choose_digger()
	var to := _join_name() if plan.passage.count >= 2 else ""
	return ReadoutScript.room_text(plan.kind, plan.centre_u, plan.turns, plan.passage, _control.ext.works.ground,
		_control.crew_rate(digger, 1), _control.crew_rate(digger, RoomsScript.ROOM_FACES), _control.crew_size(digger), to,
		plan.level)


func _join_name() -> String:
	"""How the readout names where the passage joins the network: "Tunnel 4", "a ramp's foot" or "a junction"."""
	if plan.passage.snap_kind[0] == SpecScript.END_ON_SEGMENT:
		return "Tunnel %d" % (plan.passage.snap_ref[0] + 1)
	var node := plan.passage.snap_ref[0]
	if _network.is_node(node) and _network.node_kind[node] == GraphScript.NODE_RAMP_END:
		return "a ramp's foot"
	if _network.is_node(node) and _network.node_kind[node] == GraphScript.NODE_END:
		return "a tunnel's end"
	return "a junction"


func _draw_ghost() -> void:
	"""The ghost in both views: the room's outline, its passage and rings, and its words."""
	ghost_draws += 1
	var refused := plan.refusal != RoomsScript.REFUSE_NONE
	var centre := Vector2(Rules.to_m(plan.centre_u.x), Rules.to_m(plan.centre_u.y))
	var material := _materials[1 if refused else 0]
	RoomViewScript.outline_into(_ghost.mesh as ImmediateMesh, material, plan.kind, centre, plan.turns, MarksScript.LIFT_M,
		plan.level == Rules.TOP_LEVEL)
	for node: MeshInstance3D in [_ghost, _ghost_below]:
		node.material_override = material
		node.visible = true
	_draw_passage()
	for tag: Label3D in [_label, _label_below]:
		tag.visible = true
		tag.text = _words
		tag.modulate = Palette.CLAY if refused else Palette.CREAM
		tag.position = Vector3(centre.x, tag.position.y, centre.y)


func _draw_passage() -> void:
	"""The proposed passage from the network to its socket, and a brass ring at each end (none: hidden)."""
	var mesh := _passage.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var shown := plan.passage.count >= 2
	_passage.visible = shown
	_passage_below.visible = shown
	for ring in _rings:
		ring.visible = shown
	if not shown:
		return
	var a := plan.passage.point_m(0)
	var b := plan.passage.point_m(1)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _materials[2])
	mesh.surface_set_normal(Vector3.UP)
	var side := (b - a).normalized().orthogonal() * PASSAGE_WIDTH_M * 0.5
	for p: Vector2 in [a - side, a + side, b + side, a - side, b + side, b - side]:
		mesh.surface_add_vertex(Vector3(p.x, MarksScript.LIFT_M, p.y))
	mesh.surface_end()
	for k in _rings.size():
		var at := a if k < 2 else b
		_rings[k].position = Vector3(at.x, _rings[k].position.y, at.y)


# --- laying a room --------------------------------------------------------------------------

func place(standalone: bool) -> bool:
	"""Lay the ghost room where it stands (see LAYING A ROOM), with its passage unless `standalone`. False, the
	reason said, when it may not be dug."""
	plan.standalone = standalone
	_refresh_site()
	_checked = Vector4i(0, 0, 0, -1)
	var refusal := plan.check(_network, _site)
	plan.standalone = false
	var digger: int = _control.choose_digger()
	if refusal != RoomsScript.REFUSE_NONE:
		return _refuse(RoomsScript.reason_text(refusal))
	var entrance := _entrance_refusal(digger)
	if entrance != Rules.REFUSE_NONE:
		return _refuse(Rules.link_text(entrance, ""))
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	if not _network.add_room(plan.kind, plan.centre_u, plan.turns, digger, ref, plan.level):
		return _refuse(RoomsScript.reason_text(RoomsScript.REFUSE_NETWORK_FULL))
	var joined := _lay_passage(ref[0], digger)
	if plan.level != Rules.TOP_LEVEL:
		return _place_lower(ref, joined, digger)
	_control.room_laid(ref[2], joined)
	var now: bool = _control.start_room(ref[3], ref[4], digger)
	_control.say(LAID % [RoomsScript.NAMES[plan.kind], ref[0] + 1, _control.digger_name(digger),
		(WITH_PASSAGE if joined >= 0 else _passage_words) + ("" if now else QUEUED)])
	_redraw()
	return true


func _entrance_refusal(digger: int) -> int:
	"""Why the room's own way in may not be dug by `digger` (a tunnel's entrance's rules for its door or hatch on
	level 1; on level 2, only that someone can dig -- its passage is checked as a piece)."""
	if plan.level != Rules.TOP_LEVEL:
		return Rules.REFUSE_NOT_A_DIGGER if digger < 0 else Rules.REFUSE_NONE
	var hole := RoomsScript.mouth_at(plan.kind, plan.centre_u, plan.turns)
	return _control.entrance_refusal(digger, Vector2(Rules.to_m(hole.x), Rules.to_m(hole.y)))


func _place_lower(ref: PackedInt32Array, joined: int, digger: int) -> bool:
	"""A room just laid on level 2 (see ON LEVEL 2): with its passage, the passage goes first and is started; without
	one the room is dropped again and refused."""
	if joined < 0:
		_network.drop_unbroken(ref[2])
		return _refuse(RoomsScript.reason_text(RoomsScript.REFUSE_NEEDS_PASSAGE) + _passage_words)
	_network.adopt_passage(ref[2], joined)
	_control.room_laid(ref[2], joined)
	var first := _network.first_of_piece(joined)
	var now: bool = _control.start_room(first, _network.generation[first], digger)
	_control.say(LAID % [RoomsScript.NAMES[plan.kind], ref[0] + 1, _control.digger_name(digger),
		LOWER_PASSAGE + ("" if now else QUEUED)])
	_redraw()
	return true


func _lay_passage(r: int, digger: int) -> int:
	"""Lay the proposed passage as a piece ending at room `r`'s socket, checked again now the room is laid;
	returns its piece (-1: none, the room stands alone -- and, when one was proposed, why in _passage_words)."""
	_passage_words = ""
	if plan.passage.count < 2 or plan.passage_socket < 0:
		return -1
	plan.passage.snap_ref[1] = _network.rooms.socket_of(r, plan.passage_socket) if plan.level == Rules.TOP_LEVEL \
			else _network.rooms.door[r]
	var reason := plan.passage.piece_reason(_network, _site.bounds_u, _site.circles_u, _site.spots_u, _site.under_u)
	if reason == Rules.REFUSE_NONE:
		var ref := PackedInt32Array([-1, 0, -1])
		if _network.add_piece(plan.passage.spec_of(digger), ref):
			return ref[2]
		reason = Rules.REFUSE_NETWORK_FULL
	_passage_words = WITHOUT_PASSAGE % Rules.link_text(reason, plan.passage.refused_name(_network))
	return -1


func _refuse(reason_words: String) -> bool:
	"""Say why a room may not be laid, and drop a clay marker where it stands."""
	_control.say(REFUSED % reason_words)
	_control.mark_at(Vector2(Rules.to_m(plan.centre_u.x), Rules.to_m(plan.centre_u.y)), false)
	return false


func label() -> Label3D:
	"""The ghost's words on the surface (for checks)."""
	return _label


func site() -> RoomsScript.Site:
	"""What the ghost is checked against now (see THE GHOST; for the checks)."""
	return _site


func words() -> String:
	"""What the ghost says beside the pointer now (checks)."""
	return _words
