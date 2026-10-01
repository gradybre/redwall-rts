extends RefCounted
## A tunnel's mouth on the surface: an OPEN CUTTING down its ramp to where the bore goes under the ground, the
## generated tunnel ARCH framing the bore there, and a lantern on it. Decisions 0207 (P1: the procedural gateway and a
## dark strip) and 0371 (P7: review F16, "the surface tunnel entrance must read as an open cutting going down"; the
## arch with its doorway's slab cut out, make_demo_derived_props.py `tunnel_arch_open`). Presentation only.
##
## In the mouth's own frame +Z runs down the ramp, into the tunnel, and X across it:
##   * THE CUTTING (`cutting_mesh`) is real geometry where the walker walks: its floor follows the ramp down
##     (tunnel_rules.gd `ramp_depth_m`, the same floor resident_brain.gd stands on) between two hand-dug earth walls up
##     to the ground, CUT_MARGIN_M beyond the bore's floor either side, its middle worn paler, a low earthen bank along
##     each top; before the arch it opens into a FORECOURT as wide as the arch's piers. The ground is cut open over it
##     (world/ground_cut.gd, by `footprint` and `court_footprint`), so it is a hole, not a strip on the turf. It ends:
##       END_FACE   while the entrance shaft is dug: the earth face where the dig has reached;
##       END_THROAT open, at the PORTAL (tunnel_rules.gd `portal_m`: where the bore's crown goes under the ground): the
##                  bore goes on as a dark THROAT, THROAT_M of floor, walls and roof fading to black under the turf;
##       END_DOOR   a burrow home's door ramp, all the way down to its door (room_view.gd stands the burrow door there):
##                  a short dark throat behind the door, through the room's wall.
##   * THE ARCH stands at the portal facing up the ramp, sunk so its doorway's top is the bore's crown there -- the
##     ground's level -- and its doorway frames the bore: the stone piers and timber posts in the cutting, the lintel and
##     its earth over the turf. Its doorway is OPENING_SHARE of its width, scaled to the bore (`arch_scale`). A
##     LANTERN -- the library's wall lantern, a small glow in its cage -- hangs on the lintel's face beside the way in.
##     Unstaged (CI), P1's procedural gateway (`gateway_mesh`, its own lantern) stands there instead, on the portal's
##     floor.
## Every mesh is built once per kind and shared by every mouth.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const GATE_HEIGHT_M: float = 1.3
const OPENING_M: float = 1.2
const JAMB_WIDTH_M: float = 0.32
const JAMB_DEPTH_M: float = 0.34
const JAMB_COURSES: int = 5
const LINTEL_M: Vector3 = Vector3(2.05, 0.19, 0.24)
## The cutting: CUT_MARGIN_M wider than the bore's floor either side, CUT_WIDTH_M the standard bore's (tunnel_heaps.gd
## keeps heaps clear of it with its banks), banks BANK_WIDTH_M wide and BANK_HEIGHT_M high on the ground beside it.
const CUT_MARGIN_M: float = 0.05
const CUT_WIDTH_M: float = 1.1
const BANK_WIDTH_M: float = 0.22
const BANK_HEIGHT_M: float = 0.07
## The hand-dug look: the earth's tone varies by EARTH_JITTER, the walls bulge by WALL_JITTER_M in WALL_BANDS bands, the
## floor's worn middle (WORN_SHARE of its width) is WORN_LIGHTEN paler.
const EARTH_JITTER: float = 0.12
const WALL_JITTER_M: float = 0.035
const WALL_BANDS: int = 3
const WORN_SHARE: float = 0.45
const WORN_LIGHTEN: float = 0.12
## The cutting's floor and walls are built every CUT_STEP_M down the ramp (the last step shorter); while its entrance
## shaft is dug it opens in OPEN_STEPS steps (each a mesh of its own, shared).
const CUT_STEP_M: float = 0.25
## Over its last FORECOURT_M before the arch the cutting widens to the arch's piers (COURT_SHARE of its half-width: the
## piers flare wider at their feet, inside the forecourt's walls), so the stone and timber stand in the open.
const FORECOURT_M: float = 0.75
const COURT_SHARE: float = 0.92
const OPEN_STEPS: int = 8
const THROAT_M: float = 1.5
const DOOR_THROAT_M: float = 1.0
## A home door's throat is this tall over the floor (its round door's top; room_view.gd).
const DOOR_THROAT_TALL_M: float = 1.3
const END_FACE: int = 0
const END_THROAT: int = 1
const END_DOOR: int = 2
const STONE_TONES: Array[Color] = [Color(0.52, 0.5, 0.46), Color(0.44, 0.42, 0.38), Color(0.6, 0.57, 0.5), Color(0.38, 0.36, 0.33)]
const TIMBER: Color = Color(0.36, 0.24, 0.14)
const CUT_TOP: Color = Color(0.33, 0.25, 0.17)
const CUT_FLOOR: Color = Color(0.3, 0.23, 0.16)
const CUT_DEEP: Color = Color(0.12, 0.09, 0.07)
const THROAT_END: Color = Color(0.01, 0.008, 0.006)
const BANK: Color = Color(0.33, 0.25, 0.17)
const SEED: int = 2073
## The procedural gateway's lantern: its bracket's reach out from the lintel's face, where it hangs across (m from the
## middle), its chain, its cage and glass, and its glow.
const LANTERN_X_M: float = 0.4
const BRACKET_REACH_M: float = 0.2
const CHAIN_M: float = 0.08
const CAGE_M: Vector3 = Vector3(0.18, 0.27, 0.18)
const IRON: Color = Color(0.16, 0.14, 0.12)
const LANTERN_GLOW: Color = Color(1.0, 0.66, 0.3)
const GLOW_ENERGY: float = 1.8
## The staged arch (make_demo_derived_props.py `tunnel_arch_open`, measured from the library high-poly): its doorway
## is OPENING_SHARE of its width (0.734 of 1.902 units) and its top OPENING_TOP_SHARE of its height (1.118 of 1.56).
## Its doorway is drawn the bore's floor and CUT_MARGIN_M either side wide.
const ARCH_KEY: StringName = &"tunnel_arch_open"
## How far past the portal the arch's back reaches (m; its piers and lintel stand over the bore's start): nobody is sent
## to stand there (cast_space.gd `on_mouth`).
const ARCH_DEPTH_M: float = 0.6
const OPENING_SHARE: float = 0.386
const OPENING_TOP_SHARE: float = 0.717
## The staged arch's lantern: the library wall lantern on the lintel's face, LANTERN_OUT_M beside the doorway, its
## middle LANTERN_UP_M over the ground; the glow in its cage GLOW_RADIUS_M round.
const LANTERN_KEY: StringName = &"wall_lantern"
const LANTERN_OUT_M: float = 0.32
const LANTERN_UP_M: float = 0.22
const GLOW_RADIUS_M: float = 0.045

static var _gate: ArrayMesh = null
static var _cuts: Dictionary = {}
static var _glow: SphereMesh = null
static var _rough: StandardMaterial3D = null
## Each bore class's portal (tunnel_rules.gd `portal_m`, a 30-step bisection), worked out once: `cutting_run_m` runs
## every frame for every resident on a ramp (demo_actor.gd).
static var _portal: PackedFloat32Array = PackedFloat32Array()


# --- the cutting -----------------------------------------------------------------------------------

static func cut_half_m(bore: int) -> float:
	"""Half the cutting's width for a bore of class `bore` (m): its floor and CUT_MARGIN_M."""
	return BoreMeshScript.FLOOR_HALF_M[bore] + CUT_MARGIN_M


static func bank_half_m(bore: int) -> float:
	"""Half the cutting's width with its banks (m): what a heap keeps clear of (tunnel_heaps.gd)."""
	return cut_half_m(bore) + BANK_WIDTH_M


static func opened_share(share: float) -> float:
	"""How much of its cutting a mouth whose entrance shaft is `share` dug shows: that share in OPEN_STEPS steps."""
	return ceilf(clampf(share, 0.0, 1.0) * float(OPEN_STEPS)) / float(OPEN_STEPS)


static func cutting_mesh(bore: int, open_m: float, end: int, court_half: float = 0.0) -> ArrayMesh:
	"""THE CUTTING of a bore of class `bore`, open `open_m` down its ramp and ending so (see the header), widened over
	its last FORECOURT_M to `court_half` either side when that is wider (`court_start`), built once per kind and
	shared."""
	var length := maxf(open_m, CUT_STEP_M)
	var key := "%d|%d|%d|%d" % [bore, roundi(length * 1000.0), end, roundi(court_half * 1000.0)]
	if not _cuts.has(key):
		_cuts[key] = _build_cutting(bore, length, end, court_half)
	return _cuts[key]


static func court_start(length: float) -> float:
	"""Where a cutting `length` long widens to its forecourt (m from its mouth): FORECOURT_M short of its end, on the
	cutting's CUT_STEP_M lattice."""
	return maxf(floorf((length - FORECOURT_M) / CUT_STEP_M) * CUT_STEP_M, 0.0)


static func _build_cutting(bore: int, length: float, end: int, court_half: float) -> ArrayMesh:
	"""Build a cutting (see `cutting_mesh`): floor and walls down the ramp, the banks, the forecourt, and its end."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := cut_half_m(bore)
	var court := court_start(length) if court_half > half else INF
	var steps := ceili(length / CUT_STEP_M - 1e-4)
	for k in steps:
		var z0 := float(k) * CUT_STEP_M
		var z1 := minf(z0 + CUT_STEP_M, length)
		var wide := court_half if z0 >= court - 1e-4 else half
		_floor(tool, wide, half * WORN_SHARE, z0, z1, k)
		for side: float in [-1.0, 1.0]:
			_wall(tool, side, wide, z0, z1, k)
			_bank(tool, side, wide, z0, z1)
	if court < INF:
		for side: float in [-1.0, 1.0]:
			_court_step(tool, side, half, court_half, court)
	if end == END_FACE:
		_face(tool, half, length)
	else:
		_throat(tool, bore, half, length, end)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, _material())
	return mesh


static func _court_step(tool: SurfaceTool, side: float, half: float, court_half: float, z: float) -> void:
	"""The earth wall where the cutting widens to its forecourt, from `half` out to `court_half` across, floor to
	ground, facing down the ramp into the forecourt."""
	var y := -Rules.ramp_depth_m(z)
	var a := Vector3(side * half, y, z)
	var b := Vector3(side * court_half, y, z)
	var corners := [b, a, a + Vector3(0.0, -y, 0.0), b + Vector3(0.0, -y, 0.0)]
	if side < 0.0:
		corners = [a, b, b + Vector3(0.0, -y, 0.0), a + Vector3(0.0, -y, 0.0)]
	_quad(tool, corners, [_floor_colour(y), _floor_colour(y), CUT_TOP, CUT_TOP])


static func _floor_colour(y: float) -> Color:
	"""The cutting's earth at height `y`: packed earth at the top, darker as it goes down."""
	return CUT_FLOOR.lerp(CUT_DEEP, clampf(-y / Rules.to_m(Rules.BORE_FLOOR_DEPTH_U), 0.0, 1.0) * 0.6)


static func jitter(k: int, salt: int) -> float:
	"""A repeatable -1..1 for step `k` and `salt`: how a hand-dug cutting's earth varies, the same every build."""
	var h := (k * 73856093) ^ (salt * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xFFFF) / 32767.5 - 1.0


static func _earth(base: Color, k: int, salt: int) -> Color:
	"""`base` a little lighter or darker, repeatably (see `jitter`)."""
	return base.lightened(EARTH_JITTER * maxf(jitter(k, salt), 0.0)).darkened(EARTH_JITTER * maxf(-jitter(k, salt), 0.0))


static func _floor(tool: SurfaceTool, half: float, worn: float, z0: float, z1: float, k: int) -> void:
	"""One step of the floor down the ramp, `half` either side, in three strips across: the worn middle (`worn` either
	side) paler than its edges."""
	var y0 := -Rules.ramp_depth_m(z0)
	var y1 := -Rules.ramp_depth_m(z1)
	var xs: Array[float] = [-half, -worn, worn, half]
	for strip in 3:
		var tone := _floor_colour(y0).lightened(WORN_LIGHTEN if strip == 1 else 0.0)
		var deep := _floor_colour(y1).lightened(WORN_LIGHTEN if strip == 1 else 0.0)
		_quad(tool, [Vector3(xs[strip], y0, z0), Vector3(xs[strip + 1], y0, z0), Vector3(xs[strip + 1], y1, z1),
			Vector3(xs[strip], y1, z1)], [_earth(tone, k, strip), _earth(tone, k, strip + 1), _earth(deep, k + 1, strip + 1),
			_earth(deep, k + 1, strip)])


static func _wall(tool: SurfaceTool, side: float, half: float, z0: float, z1: float, k: int) -> void:
	"""One step of a side wall, from the floor up to the ground in WALL_BANDS bands, facing into the cutting: its middle
	bulging in and out by up to WALL_JITTER_M (hand-dug), its foot and top straight (they meet the floor and the hole)."""
	var low := [-Rules.ramp_depth_m(z0), -Rules.ramp_depth_m(z1)]
	for band in WALL_BANDS:
		var share := [float(band) / float(WALL_BANDS), float(band + 1) / float(WALL_BANDS)]
		var corners: Array = []
		var colours: Array = []
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var z: float = [z0, z1][corner.x]
			var up: float = share[corner.y]
			var bulge := WALL_JITTER_M * jitter(k + corner.x, band + corner.y + (7 if side > 0.0 else 0)) if up > 0.0 and up < 1.0 else 0.0
			corners.append(Vector3(side * (half + bulge), lerpf(low[corner.x], 0.0, up), z))
			colours.append(_earth(_floor_colour(low[corner.x]).lerp(CUT_TOP, up), k + corner.x, band + corner.y + 3))
		if side > 0.0:
			corners = [corners[1], corners[0], corners[3], corners[2]]
			colours = [colours[1], colours[0], colours[3], colours[2]]
		_quad(tool, corners, colours)


static func _bank(tool: SurfaceTool, side: float, half: float, z0: float, z1: float) -> void:
	"""The low earthen bank along one top of the cutting, from its edge out BANK_WIDTH_M, from z0 to z1."""
	var inner := side * half
	var crest := side * (half + BANK_WIDTH_M * 0.4)
	var outer := side * (half + BANK_WIDTH_M)
	for band: Array in [[inner, 0.0, crest, BANK_HEIGHT_M], [crest, BANK_HEIGHT_M, outer, 0.0]]:
		var a := Vector3(band[0], band[1], z0)
		var b := Vector3(band[2], band[3], z0)
		var corners := [a, b, b + Vector3(0.0, 0.0, z1 - z0), a + Vector3(0.0, 0.0, z1 - z0)]
		if side < 0.0:
			corners = [b, a, a + Vector3(0.0, 0.0, z1 - z0), b + Vector3(0.0, 0.0, z1 - z0)]
		_quad(tool, corners, [BANK, BANK, BANK, BANK])


static func _face(tool: SurfaceTool, half: float, length: float) -> void:
	"""END_FACE: the earth face across the cutting's end, from its floor up to the ground, facing back up the ramp."""
	var y := -Rules.ramp_depth_m(length)
	_quad(tool, [Vector3(-half, y, length), Vector3(half, y, length), Vector3(half, 0.0, length), Vector3(-half, 0.0, length)],
		[CUT_DEEP, CUT_DEEP, CUT_TOP, CUT_TOP])


static func _throat(tool: SurfaceTool, bore: int, half: float, length: float, end: int) -> void:
	"""END_THROAT / END_DOOR: the bore going on under the ground from the cutting's end -- floor, walls and a roof at
	its crown -- fading to black, closed at its far end."""
	var run := THROAT_M if end == END_THROAT else DOOR_THROAT_M
	var tall := Rules.crown_m(bore) if end == END_THROAT else DOOR_THROAT_TALL_M
	var steps := maxi(roundi(run / CUT_STEP_M), 1)
	for k in steps:
		var z0 := length + float(k) * CUT_STEP_M
		var z1 := z0 + CUT_STEP_M
		var y0 := -Rules.ramp_depth_m(z0)
		var y1 := -Rules.ramp_depth_m(z1)
		var c0 := CUT_DEEP.lerp(THROAT_END, float(k) / float(steps))
		var c1 := CUT_DEEP.lerp(THROAT_END, float(k + 1) / float(steps))
		_quad(tool, [Vector3(-half, y0, z0), Vector3(half, y0, z0), Vector3(half, y1, z1), Vector3(-half, y1, z1)], [c0, c0, c1, c1])
		_quad(tool, [Vector3(half, y0 + tall, z0), Vector3(-half, y0 + tall, z0), Vector3(-half, y1 + tall, z1),
			Vector3(half, y1 + tall, z1)], [c0, c0, c1, c1])
		for side: float in [-1.0, 1.0]:
			var corners := [Vector3(side * half, y0, z0), Vector3(side * half, y1, z1), Vector3(side * half, y1 + tall, z1),
				Vector3(side * half, y0 + tall, z0)]
			if side > 0.0:
				corners = [corners[1], corners[0], corners[3], corners[2]]
			_quad(tool, corners, [c0, c1, c1, c0] if side < 0.0 else [c1, c0, c0, c1])
	var far := length + float(steps) * CUT_STEP_M
	var y := -Rules.ramp_depth_m(far)
	_quad(tool, [Vector3(-half, y, far), Vector3(half, y, far), Vector3(half, y + tall, far), Vector3(-half, y + tall, far)],
		[THROAT_END, THROAT_END, THROAT_END, THROAT_END])


static func door_template(network: GraphScript, m: int) -> int:
	"""The template of the dug room whose door or hatch mouth row `m` is (underground_rooms.gd TEMPLATE_*), or
	TEMPLATE_NONE: a tunnel's mouth, or a room still being dug (its ramp opens as a tunnel's does; decision 0209)."""
	var r: int = network.node_room[network.mouth_node[m]]
	if network.mouth_kind[m] == GraphScript.MOUTH_TUNNEL or r < 0 or not network.rooms.is_done(network, r):
		return RoomsScript.TEMPLATE_NONE
	return network.rooms.template[r]


static func cutting_run_m(network: GraphScript, m: int) -> float:
	"""How far mouth row `m`'s cutting runs down its ramp once open (m): to the portal, or down to a burrow home's door;
	none under a cellar's hatch, which covers its ramp."""
	var ramp: int = network.mouth_ramp(m)
	match door_template(network, m):
		RoomsScript.TEMPLATE_HOME:
			return minf(network.length_m(ramp), Rules.to_m(Rules.RAMP_RUN_U))
		RoomsScript.TEMPLATE_CELLAR:
			return 0.0
	return minf(portal_of(int(network.bore[ramp])), network.length_m(ramp))


static func portal_of(bore: int) -> float:
	"""Rules.portal_m(bore), worked out once a bore class (a pure function of the class)."""
	if _portal.size() <= bore:
		var from := _portal.size()
		_portal.resize(bore + 1)
		for b in range(from, bore + 1):
			_portal[b] = Rules.portal_m(b)
	return _portal[bore]


static func cutting_gap(network: GraphScript, m: int, at: Vector2, court_half: float, bank: float) -> float:
	"""How far `at` stands from mouth row `m`'s cutting once open (m; 0 on it): its run down the ramp and the arch's
	depth past it, `bank` wider either side than the cut, and -- at a tunnel's mouth -- its forecourt `court_half`
	either side (`court_footprint`). INF where it has none (a cellar's hatch). What a stander or a heap keeps off
	(cast_space.gd `on_mouth`, tunnel_heaps.gd)."""
	var run := cutting_run_m(network, m)
	if run <= 0.0:
		return INF
	var into := network.mouth_inward(m)
	var rel := at - network.mouth_at(m)
	var along := rel.dot(into)
	var across := absf(rel.dot(Vector2(into.y, -into.x)))
	var to := run + ARCH_DEPTH_M
	var ramp: int = network.mouth_ramp(m)
	var gap := _rect_gap(along, across, 0.0, to, cut_half_m(int(network.bore[ramp])) + bank)
	if court_half > 0.0 and door_template(network, m) == RoomsScript.TEMPLATE_NONE:
		gap = minf(gap, _rect_gap(along, across, court_start(run), to, court_half + bank))
	return gap


static func _rect_gap(along: float, across: float, from_m: float, to_m: float, half: float) -> float:
	"""How far a point `along` a cutting's line and `across` it stands from the rectangle `from_m` to `to_m` along it
	and `half` either side (m; 0 inside)."""
	var out_along := maxf(maxf(from_m - along, along - to_m), 0.0)
	var out_across := maxf(across - half, 0.0)
	return sqrt(out_along * out_along + out_across * out_across)


static func in_open_cutting(network: GraphScript, slot: int, along_m: float) -> bool:
	"""Whether a walker `along_m` into segment `slot` is in an open cutting -- on a ramp from an opened mouth, nearer it
	than its cutting runs -- where the surface view sees it (demo_actor.gd)."""
	if slot < 0 or network.seg_kind[slot] != GraphScript.SEG_RAMP:
		return false
	var at_b: bool = network.mouth_end_at_b(slot)
	var m: int = network.mouth_of_end(slot, at_b)
	if m < 0 or not network.mouth_opened(m):
		return false
	var from_mouth: float = network.length_m(slot) - along_m if at_b else along_m
	return from_mouth < cutting_run_m(network, m)


static func footprint(at: Vector2, inward: Vector2, bore: int, open_m: float) -> PackedVector2Array:
	"""Where the ground is cut open over a cutting (world x, z): from its mouth `at` down `inward` its open length,
	its width -- the hole world/ground_cut.gd makes."""
	return _rect(at, inward, cut_half_m(bore), 0.0, open_m)


static func court_footprint(at: Vector2, inward: Vector2, court_half: float, open_m: float) -> PackedVector2Array:
	"""Where the ground is cut open over a cutting's forecourt (world x, z; see `cutting_mesh`)."""
	return _rect(at, inward, court_half, court_start(open_m), open_m)


static func _rect(at: Vector2, inward: Vector2, half: float, from_m: float, to_m: float) -> PackedVector2Array:
	"""A rectangle `half` either side of the way down `inward` from `at`, `from_m` to `to_m` along it (world x, z)."""
	var across := Vector2(inward.y, -inward.x) * half
	var a := at + inward * from_m
	var b := at + inward * to_m
	return PackedVector2Array([a - across, a + across, b + across, b - across])


static func court_half_m(props: PropsScript, bore: int) -> float:
	"""How wide either side the cutting opens into its forecourt before the arch (m): out to the arch's piers (the
	staged arch's drawn half-width at its scale for the bore; the procedural gateway's jambs), so they stand in the
	open."""
	if props != null and props.is_staged(ARCH_KEY):
		return props.drawn_bound(ARCH_KEY).size.x * 0.5 * arch_scale(props, bore) * COURT_SHARE
	var wide := cut_half_m(bore) / cut_half_m(Rules.BORE_STANDARD)
	return (OPENING_M * 0.5 + JAMB_WIDTH_M + CUT_MARGIN_M) * wide


# --- the arch ---------------------------------------------------------------------------------------

static func arch_scale(props: PropsScript, bore: int) -> float:
	"""How much larger than its demo size the staged arch is drawn for a bore of class `bore`: its doorway the bore's
	floor and CUT_MARGIN_M either side wide."""
	var width: float = props.drawn_bound(ARCH_KEY).size.x
	return cut_half_m(bore) * 2.0 / maxf(width * OPENING_SHARE, 0.01)


static func arch_at(props: PropsScript, bore: int, portal: float) -> Transform3D:
	"""The staged arch in the mouth's frame (its fitted mesh's): at the portal, facing up the ramp, sunk so its doorway's
	top is the bore's crown there."""
	var scale := arch_scale(props, bore)
	var tall: float = props.drawn_bound(ARCH_KEY).size.y * scale
	var crown := -Rules.ramp_depth_m(portal) + Rules.crown_m(bore)
	var at := Vector3(0.0, crown - tall * OPENING_TOP_SHARE, portal)
	return Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale), at)


static func lantern_on_arch(props: PropsScript, bore: int, portal: float) -> Transform3D:
	"""The staged arch's lantern in the mouth's frame: the wall lantern (its plate at its +X) turned so its plate lies on
	the lintel's face, its cage out toward the mouth, beside the doorway (see the header)."""
	var scale := arch_scale(props, bore)
	var lantern: AABB = props.drawn_bound(LANTERN_KEY)
	var crown := -Rules.ramp_depth_m(portal) + Rules.crown_m(bore)
	var face := portal - lintel_front_m(props) * scale
	var x := cut_half_m(bore) + LANTERN_OUT_M
	var plate := Vector3(x, crown + LANTERN_UP_M - lantern.get_center().y, face)
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), plate) * Transform3D(Basis.IDENTITY, Vector3(-lantern.end.x, 0.0, 0.0))


static func lintel_front_m(props: PropsScript) -> float:
	"""How far in front of its middle the staged arch's lintel's face stands, at its demo size (m): the furthest forward
	any of its vertices over the doorway reaches (its piers flare further forward at their feet). Measured once."""
	var kept: Variant = props.derived(&"tunnel_arch/lintel_front")
	if kept != null:
		return kept
	var mesh := props.fitted(ARCH_KEY)
	var top := mesh.get_aabb().size.y * OPENING_TOP_SHARE
	var front := 0.0
	for surface in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if p.y > top:
				front = maxf(front, p.z)
	return props.keep(&"tunnel_arch/lintel_front", front)


static func glow_at(props: PropsScript, bore: int, portal: float) -> Vector3:
	"""Where the glow in the staged lantern's cage hangs, in the mouth's frame."""
	var lantern: AABB = props.drawn_bound(LANTERN_KEY)
	var cage := Vector3(lantern.position.x + lantern.size.x * 0.28, lantern.get_center().y, lantern.get_center().z)
	return lantern_on_arch(props, bore, portal) * cage


static func glow_mesh() -> SphereMesh:
	"""The lantern's glow: a small warm sphere, lit from within, shared."""
	if _glow == null:
		_glow = SphereMesh.new()
		_glow.radius = GLOW_RADIUS_M
		_glow.height = GLOW_RADIUS_M * 2.0
		_glow.radial_segments = 10
		_glow.rings = 5
		_glow.material = _glow_material()
	return _glow


# --- the procedural gateway (unstaged) -----------------------------------------------------------------

static func gateway_mesh() -> ArrayMesh:
	"""THE procedural gateway (see the header), shared: two jambs of rough fieldstones, a timber lintel at GATE_HEIGHT_M,
	and its lantern (the mesh's second surface, glowing)."""
	if _gate != null:
		return _gate
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for side: float in [-1.0, 1.0]:
		_jamb(tool, rng, side * (OPENING_M + JAMB_WIDTH_M) * 0.5)
	var lintel := Basis.from_euler(Vector3(0.0, 0.0, 0.025)).scaled(LINTEL_M)
	_box(tool, Transform3D(lintel, Vector3(0.0, GATE_HEIGHT_M + LINTEL_M.y * 0.5, 0.0)), TIMBER)
	_lantern_iron(tool)
	_gate = tool.commit()
	_gate.surface_set_material(0, _material())
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(glass, Transform3D(Basis.from_scale(CAGE_M * Vector3(0.78, 0.7, 0.78)), lantern_at()), LANTERN_GLOW)
	glass.commit(_gate)
	_gate.surface_set_material(1, _glow_material())
	return _gate


static func gateway_at(bore: int, portal: float) -> Transform3D:
	"""The procedural gateway in the mouth's frame: on the portal's floor, facing up the ramp, as much wider than its
	standard size as the bore's cutting is."""
	var wide := cut_half_m(bore) / cut_half_m(Rules.BORE_STANDARD)
	return Transform3D(Basis.from_scale(Vector3.ONE * wide), Vector3(0.0, -Rules.ramp_depth_m(portal), portal))


static func lantern_at() -> Vector3:
	"""The middle of the procedural gateway's hung lantern, in its frame (outward is -Z)."""
	var face := -(LINTEL_M.z * 0.5 + BRACKET_REACH_M)
	return Vector3(LANTERN_X_M, GATE_HEIGHT_M - CHAIN_M - CAGE_M.y * 0.5, face)


static func _lantern_iron(tool: SurfaceTool) -> void:
	"""The lantern's iron: a bracket out from the lintel's face, a chain down, a cap and a base round the glass."""
	var at := lantern_at()
	var face := -LINTEL_M.z * 0.5
	var arm_mid := Vector3(LANTERN_X_M, GATE_HEIGHT_M + 0.06, (face + at.z) * 0.5)
	_box(tool, Transform3D(Basis.from_scale(Vector3(0.025, 0.025, BRACKET_REACH_M)), arm_mid), IRON)
	_box(tool, Transform3D(Basis.from_scale(Vector3(0.015, CHAIN_M + 0.06, 0.015)), Vector3(at.x, GATE_HEIGHT_M - CHAIN_M * 0.5 + 0.03, at.z)), IRON)
	for y: float in [CAGE_M.y * 0.5, -CAGE_M.y * 0.5]:
		_box(tool, Transform3D(Basis.from_scale(Vector3(CAGE_M.x, 0.025, CAGE_M.z)), at + Vector3(0.0, y, 0.0)), IRON)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var post := at + Vector3(corner.x * CAGE_M.x * 0.45, 0.0, corner.y * CAGE_M.z * 0.45)
		_box(tool, Transform3D(Basis.from_scale(Vector3(0.018, CAGE_M.y, 0.018)), post), IRON)


static func _glow_material() -> StandardMaterial3D:
	"""A lantern's glass: its glow, lit from within."""
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = LANTERN_GLOW
	material.emission_enabled = true
	material.emission = LANTERN_GLOW
	material.emission_energy_multiplier = GLOW_ENERGY
	return material


static func _jamb(tool: SurfaceTool, rng: RandomNumberGenerator, x: float) -> void:
	"""One jamb: JAMB_COURSES rough stones stacked to the lintel, each a little off square."""
	var course := GATE_HEIGHT_M / float(JAMB_COURSES)
	for k in JAMB_COURSES:
		var size := Vector3(JAMB_WIDTH_M * rng.randf_range(0.9, 1.12), course * rng.randf_range(0.9, 1.0), JAMB_DEPTH_M * rng.randf_range(0.85, 1.1))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05)))
		var at := Vector3(x + rng.randf_range(-0.025, 0.025), course * (float(k) + 0.5), rng.randf_range(-0.02, 0.02))
		_box(tool, Transform3D(turn.scaled(size), at), STONE_TONES[rng.randi() % STONE_TONES.size()])


static func _box(tool: SurfaceTool, xform: Transform3D, colour: Color) -> void:
	"""A unit box put by `xform`, in one colour, into `tool`."""
	var arrays := BoxMesh.new().get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xform.basis.inverse().transposed()
	for index: int in indices:
		tool.set_color(colour)
		tool.set_normal((normal_basis * normals[index]).normalized())
		tool.add_vertex(xform * points[index])


static func _quad(tool: SurfaceTool, corners: Array, colours: Array) -> void:
	"""Two triangles over four corners, wound clockwise seen from their front (Godot's front face)."""
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(colours[k])
		tool.add_vertex(corners[k])


static func _material() -> StandardMaterial3D:
	"""Rough, coloured by its vertices: one material, shared by every cutting and the gateway."""
	if _rough == null:
		_rough = StandardMaterial3D.new()
		_rough.vertex_color_use_as_albedo = true
		_rough.vertex_color_is_srgb = true
		_rough.roughness = 0.92
	return _rough
