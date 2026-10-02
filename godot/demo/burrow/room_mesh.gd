extends RefCounted
## A room's earth shell: the walls and the floor room_view.gd draws below. Decision 0209 (the underground
## revamp's P3; design docs/design/underground_revamp.md §6 "Rooms"). Presentation only.
##
## ONE ART LANGUAGE. A room is the bores' own horseshoe, grown to a room (bore_mesh.gd `hub_rows`: walls
## bowing out BULGE at the springline and arching to the crown), built in the junction hubs' vertex format
## (bore_mesh.gd HUB_FORMAT) and drawn with their material (hub_earth.gdshader, over the one earth of
## bore_surface.gdshaderinc) -- so its walls are the cap's strata, damp where fresh, cut at the section plane,
## and left out where a bore opens into it (CUSTOM1..3: each opening's angle from the room's middle, floor
## half-width and crown). Its normals face inward and back faces are culled: from above the far wall and the
## floor show.
##   ROUND (a burrow home): the horseshoe lathed round the middle, ROUND_SECTORS round, its floor a disc. Its
##     wall bows out a further share round each BED ALCOVE (`alcove_scale`), a recess a bed stands in -- and much
##     further round a BED NOOK (decision 0211, underground_rooms.gd THE BED NOOK), a deep lobe flat across
##     NOOK_FLAT_RAD either side of its axis and easing back to the wall over NOOK_EASE_RAD, a large bed's bay.
##   VAULT (a root cellar): the horseshoe across it swept along its length, a ring every VAULT_STEP_M, and a
##     straight end wall at each end; its floor a rectangle.
## COLOR.b is the stone lining (a cellar's grey-blue walls and flags); UV the profile coordinate (the floor's
## worn middle); UV2 (dig day, 1 on a wall / 0 on the floor).

const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

const ROUND_SECTORS: int = 96
const VAULT_STEP_M: float = 0.25
## A bed alcove spans this far either side of its angle (rad), easing in and out.
const ALCOVE_HALF_RAD: float = 0.46


static func alcove_scale(angle: float, alcoves: PackedFloat32Array, depth_share: float,
		nooks: PackedFloat32Array = PackedFloat32Array(), nook_share: float = 0.0) -> float:
	"""How much further out a round room's wall stands at `angle` (atan2(z, x)): 1, up to 1 + `depth_share` at the
	middle of a bed alcove (`alcoves`: their angles), eased in over ALCOVE_HALF_RAD, and 1 + `nook_share` across a bed
	nook (`nooks`: their angles; see ROUND)."""
	var bump := 0.0
	for middle in alcoves:
		var off := absf(angle_difference(angle, middle))
		if off < ALCOVE_HALF_RAD:
			var swell := cos(PI * 0.5 * off / ALCOVE_HALF_RAD)
			bump = maxf(bump, swell * swell)
	var lobe := 0.0
	for middle in nooks:
		lobe = maxf(lobe, nook_bump(absf(angle_difference(angle, middle))))
	return 1.0 + maxf(depth_share * bump, nook_share * lobe)


static func nook_bump(off: float) -> float:
	"""A bed nook's lobe `off` radians from its axis: 1 across its flat, easing to 0 over NOOK_EASE_RAD (see ROUND)."""
	if off <= RoomsScript.NOOK_FLAT_RAD:
		return 1.0
	if off >= RoomsScript.NOOK_FLAT_RAD + RoomsScript.NOOK_EASE_RAD:
		return 0.0
	var eased := cos(PI * 0.5 * (off - RoomsScript.NOOK_FLAT_RAD) / RoomsScript.NOOK_EASE_RAD)
	return eased * eased


static func build_round(mesh: ArrayMesh, centre: Vector3, radius: float, crown: float, openings: PackedFloat32Array,
		alcoves: PackedFloat32Array, alcove_share: float, lined: float, day: float,
		nooks: PackedFloat32Array = PackedFloat32Array(), nook_share: float = 0.0) -> int:
	"""Write a round room's shell as `mesh`'s one surface (see ROUND): its floor centred at `centre`, `radius`
	across its floor, `crown` high, `openings` as bore_mesh.gd `build_hub` takes them, `alcoves` (angles) bowed
	out `alcove_share` and `nooks` (angles) `nook_share`, lined `lined` (0..1). Returns the vertex count."""
	var shell := BoreMeshScript.HubArrays.new()
	var rows := BoreMeshScript.hub_rows()
	var normals := BoreMeshScript.row_normals(rows, radius, crown)
	for r in rows.size():
		for sector in ROUND_SECTORS + 1:
			var angle := TAU * float(sector) / float(ROUND_SECTORS)
			var out := Vector3(cos(angle), 0.0, sin(angle))
			var reach := radius * alcove_scale(angle, alcoves, alcove_share, nooks, nook_share)
			shell.add(centre + out * (rows[r].x * reach) + Vector3.UP * (rows[r].y * crown),
				(out * normals[r].x + Vector3.UP * normals[r].y).normalized(), rows[r], Vector2(day, 1.0))
	for r in rows.size() - 1:
		for sector in ROUND_SECTORS:
			var a := r * (ROUND_SECTORS + 1) + sector
			shell.facing_tri(a, a + ROUND_SECTORS + 1, a + 1)
			shell.facing_tri(a + 1, a + ROUND_SECTORS + 1, a + ROUND_SECTORS + 2)
	_round_floor(shell, centre, radius, [alcoves, nooks], Vector2(alcove_share, nook_share), day)
	return _commit(mesh, shell, Vector3(centre.x, radius, centre.z), crown, openings, lined)


static func _round_floor(shell: BoreMeshScript.HubArrays, centre: Vector3, radius: float, bays: Array,
		shares: Vector2, day: float) -> void:
	"""A round room's floor: a disc fanned from its middle out to the wall's foot (the alcoves, `bays[0]`, and nooks,
	`bays[1]`, bowed `shares` x and y), facing up."""
	var first := shell.verts.size()
	shell.add(centre, Vector3.UP, Vector2.ZERO, Vector2(day, 0.0))
	for sector in ROUND_SECTORS:
		var angle := TAU * float(sector) / float(ROUND_SECTORS)
		var reach := radius * alcove_scale(angle, bays[0], shares.x, bays[1], shares.y)
		shell.add(centre + Vector3(cos(angle), 0.0, sin(angle)) * reach, Vector3.UP, Vector2(1.0, 0.0), Vector2(day, 0.0))
	for sector in ROUND_SECTORS:
		shell.facing_tri(first, first + 1 + sector, first + 1 + (sector + 1) % ROUND_SECTORS)


static func build_vault(mesh: ArrayMesh, centre: Vector3, across: Vector2, along: Vector2, half: Vector2, crown: float,
		openings: PackedFloat32Array, lined: float, day: float) -> int:
	"""Write a vault's shell as `mesh`'s one surface (see VAULT): its floor centred at `centre`, `half` (across,
	along) its floor's half extents, `across` and `along` its axes in the world (x, z units), `crown` high,
	`openings` as bore_mesh.gd `build_hub` takes them, lined `lined` (0..1). Returns the vertex count."""
	var shell := BoreMeshScript.HubArrays.new()
	var section := arch(half.x, crown)
	var rings := maxi(2, ceili(2.0 * half.y / VAULT_STEP_M) + 1)
	for ring in rings:
		var z := lerpf(-half.y, half.y, float(ring) / float(rings - 1))
		for k in section.size():
			var p: Vector3 = section[k]
			shell.add(_place(centre, across, along, Vector3(p.x, p.y, z)), _turn(across, along, _arch_normal(section, k)),
				Vector2(p.x / half.x, p.y / crown), Vector2(day, 1.0))
	for ring in rings - 1:
		for k in section.size() - 1:
			var a := ring * section.size() + k
			shell.facing_tri(a, a + section.size(), a + 1)
			shell.facing_tri(a + 1, a + section.size(), a + section.size() + 1)
	for end: float in [-1.0, 1.0]:
		_end_wall(shell, centre, across, along, section, half, crown, end, day)
	_vault_floor(shell, centre, across, along, half, day)
	return _commit(mesh, shell, Vector3(centre.x, half.y, centre.z), crown, openings, lined)


static func arch(half_x: float, crown: float) -> PackedVector3Array:
	"""A vault's cross-section, the horseshoe from its left floor edge over the crown to its right: (x across, y
	up, and z unused) in metres."""
	var rows := BoreMeshScript.hub_rows()
	var out := PackedVector3Array()
	for r in range(rows.size() - 1, -1, -1):
		out.append(Vector3(-rows[r].x * half_x, rows[r].y * crown, 0.0))
	for r in range(1, rows.size()):
		out.append(Vector3(rows[r].x * half_x, rows[r].y * crown, 0.0))
	return out


static func _arch_normal(section: PackedVector3Array, k: int) -> Vector3:
	"""The inward normal of cross-section point `k` in the section's plane (x across, y up): its neighbours'
	chord turned a quarter toward the inside."""
	var chord := section[mini(k + 1, section.size() - 1)] - section[maxi(k - 1, 0)]
	return Vector3(chord.y, -chord.x, 0.0).normalized()


static func _place(centre: Vector3, across: Vector2, along: Vector2, local: Vector3) -> Vector3:
	"""A point in the vault's frame (x across, y up, z along), in the world."""
	return centre + Vector3(across.x, 0.0, across.y) * local.x + Vector3.UP * local.y + Vector3(along.x, 0.0, along.y) * local.z


static func _turn(across: Vector2, along: Vector2, local: Vector3) -> Vector3:
	"""A direction in the vault's frame, in the world."""
	return (Vector3(across.x, 0.0, across.y) * local.x + Vector3.UP * local.y + Vector3(along.x, 0.0, along.y) * local.z).normalized()


static func _end_wall(shell: BoreMeshScript.HubArrays, centre: Vector3, across: Vector2, along: Vector2,
		section: PackedVector3Array, half: Vector2, crown: float, end: float, day: float) -> void:
	"""A straight end wall across the vault at `end` (-1 or +1 of its half length): the arch's outline fanned
	from its middle, facing back into the vault."""
	var inward := _turn(across, along, Vector3(0.0, 0.0, -end))
	var hub := shell.verts.size()
	shell.add(_place(centre, across, along, Vector3(0.0, crown * 0.45, end * half.y)), inward, Vector2(0.0, 0.45), Vector2(day, 1.0))
	for k in section.size():
		var p: Vector3 = section[k]
		shell.add(_place(centre, across, along, Vector3(p.x, p.y, end * half.y)), inward, Vector2(p.x / half.x, p.y / crown),
			Vector2(day, 1.0))
	for k in section.size():
		shell.facing_tri(hub, hub + 1 + k, hub + 1 + (k + 1) % section.size())


static func _vault_floor(shell: BoreMeshScript.HubArrays, centre: Vector3, across: Vector2, along: Vector2, half: Vector2,
		day: float) -> void:
	"""The vault's floor: its rectangle, facing up (UV.x across it, for the worn middle)."""
	var first := shell.verts.size()
	for corner: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		shell.add(_place(centre, across, along, Vector3(corner.x * half.x, 0.0, corner.y * half.y)), Vector3.UP,
			Vector2(corner.x, 0.0), Vector2(day, 0.0))
	shell.facing_tri(first, first + 1, first + 2)
	shell.facing_tri(first, first + 2, first + 3)


static func _commit(mesh: ArrayMesh, shell: BoreMeshScript.HubArrays, centre_radius: Vector3, crown: float,
		openings: PackedFloat32Array, lined: float) -> int:
	"""Write the shell as `mesh`'s one surface in the hubs' format: its lining in COLOR.b, the room's middle and
	crown and its openings in the custom channels. Returns the vertex count."""
	mesh.clear_surfaces()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = shell.verts
	arrays[Mesh.ARRAY_NORMAL] = shell.norms
	arrays[Mesh.ARRAY_TEX_UV] = shell.uv
	arrays[Mesh.ARRAY_TEX_UV2] = shell.uv2
	var colours := PackedColorArray()
	colours.resize(shell.verts.size())
	colours.fill(Color(0.0, 0.0, lined, 1.0))
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = shell.indices
	BoreMeshScript.hub_custom(arrays, centre_radius, crown, openings, shell.verts.size())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, BoreMeshScript.HUB_FORMAT)
	return shell.verts.size()


# --- the mound on the ground ----------------------------------------------------------------

## The mound: a dome over the room's middle MOUND_CORE of its reach, flaring into a low skirt of turf out to its
## edge, a little lumpy round its rim; MOUND_RINGS rings of MOUND_SECTORS. In the room's frame (its door at -Z),
## in metres. Where the door ramp comes in it is CUT: inside the notch (|x| under the notch's half-width, z past
## the face), the turf is pulled back to just behind the FACE -- a bank of bare earth (`build_face`) at the room's
## wall, where the door stands.
const MOUND_SECTORS: int = 48
const MOUND_RINGS: int = 14
const MOUND_CORE: float = 0.74
const MOUND_SKIRT: float = 0.28
## How far behind the face the cut turf stops (m), so the earth face is drawn over it.
const FACE_INSET_M: float = 0.03


static func mound_height(r: float) -> float:
	"""The unit mound's height `r` of its reach out (0..1): the dome's, eased into the skirt's, 0 at the edge."""
	var dome := sqrt(maxf(1.0 - (r / MOUND_CORE) * (r / MOUND_CORE), 0.0))
	var skirt := MOUND_SKIRT * (1.0 - smoothstep(MOUND_CORE * 0.7, 1.0, r))
	var blend := smoothstep(MOUND_CORE * 0.8, MOUND_CORE, r)
	return lerpf(maxf(dome, skirt), skirt, blend) if r > MOUND_CORE * 0.8 else dome


static func height_at(x: float, z: float, reach: Vector2, top: float) -> float:
	"""The mound's height (m) at (x, z) in the room's frame, reaching `reach` (m) across and along, `top` high."""
	return mound_height(minf(Vector2(x / reach.x, z / reach.y).length(), 1.0)) * top


static func build_mound(reach: Vector2, top: float, face: float, notch: float) -> ArrayMesh:
	"""The turfed mound (see the mound on the ground): `reach` (m) across and along, `top` high, cut for the door
	at `face` (m) in front of the middle, `notch` either side of the ramp."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.add_vertex(Vector3(0.0, top, 0.0))
	for ring in range(1, MOUND_RINGS + 1):
		var r := float(ring) / float(MOUND_RINGS)
		for k in MOUND_SECTORS:
			var angle := TAU * float(k) / float(MOUND_SECTORS)
			var lump := 1.0 + (0.035 * sin(3.0 * angle + 0.7) + 0.02 * sin(7.0 * angle + 2.1)) * r
			var at := Vector3(cos(angle) * r * lump * reach.x, mound_height(r) * top, sin(angle) * r * lump * reach.y)
			if absf(at.x) < notch and at.z < -face + FACE_INSET_M:
				at.z = -face + FACE_INSET_M
			tool.add_vertex(at)
	_mound_indices(tool)
	tool.generate_normals()
	return tool.commit()


static func _mound_indices(tool: SurfaceTool) -> void:
	"""The mound's triangles: a fan round its top, then a band between each ring and the next."""
	for k in MOUND_SECTORS:
		for i: int in [0, 1 + k, 1 + (k + 1) % MOUND_SECTORS]:
			tool.add_index(i)
	for ring in range(1, MOUND_RINGS):
		var inner := 1 + (ring - 1) * MOUND_SECTORS
		var outer := inner + MOUND_SECTORS
		for k in MOUND_SECTORS:
			var next := (k + 1) % MOUND_SECTORS
			for i: int in [inner + k, outer + k, outer + next, inner + k, outer + next, inner + next]:
				tool.add_index(i)


static func build_face(reach: Vector2, top: float, face: float, notch: float) -> ArrayMesh:
	"""The bank of bare earth where the mound is cut for the door (see the mound on the ground): a wall at `face`
	in front of the middle, `notch` either side, from the ground up to the mound's height there, facing out."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for i in steps + 1:
		var x := lerpf(-notch, notch, float(i) / float(steps))
		tool.set_normal(Vector3.FORWARD)
		tool.add_vertex(Vector3(x, -0.05, -face))
		tool.set_normal(Vector3.FORWARD)
		tool.add_vertex(Vector3(x, height_at(x, -face, reach, top) + 0.02, -face))
	for i in steps:
		for k: int in [2 * i, 2 * i + 3, 2 * i + 1, 2 * i, 2 * i + 2, 2 * i + 3]:
			tool.add_index(k)
	return tool.commit()


# --- the ring beam ------------------------------------------------------------------------------

static func build_beam(loop: PackedVector2Array, y: float, width: float, depth: float) -> ArrayMesh:
	"""A timber beam `width` across and `depth` deep, its middle at height `y`, run round the closed `loop` (m, in
	the room's frame: a home's circle, a cellar's rectangle) -- its top, bottom and both sides, flat-shaded (drawn
	two-sided: room_view.gd's beam material)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := _beam_edges(loop, width)
	var count := loop.size()
	var low := y - depth * 0.5
	var high := y + depth * 0.5
	for i in count:
		var j := (i + 1) % count
		var outer := (edges[2 * j] - edges[2 * i]).normalized().orthogonal()
		var side := Vector3(outer.x, 0.0, outer.y)
		_quad(tool, edges[2 * i], edges[2 * j], high, edges[2 * i + 1], edges[2 * j + 1], high, Vector3.UP)
		_quad(tool, edges[2 * i], edges[2 * j], low, edges[2 * i + 1], edges[2 * j + 1], low, Vector3.DOWN)
		_wall(tool, edges[2 * i], edges[2 * j], low, high, side)
		_wall(tool, edges[2 * i + 1], edges[2 * j + 1], low, high, -side)
	return tool.commit()


static func _beam_edges(loop: PackedVector2Array, width: float) -> PackedVector2Array:
	"""The beam's two edges at each loop point (one side, then the other), `width` apart, mitred at the corners."""
	var out := PackedVector2Array()
	var count := loop.size()
	for i in count:
		var before := (loop[i] - loop[(i + count - 1) % count]).normalized().orthogonal()
		var after := (loop[(i + 1) % count] - loop[i]).normalized().orthogonal()
		var mitre := (before + after).normalized()
		var reach := width * 0.5 / maxf(mitre.dot(after), 0.3)
		out.append(loop[i] + mitre * reach)
		out.append(loop[i] - mitre * reach)
	return out


static func _quad(tool: SurfaceTool, a0: Vector2, a1: Vector2, a_y: float, b0: Vector2, b1: Vector2, b_y: float,
		normal: Vector3) -> void:
	"""Two triangles from edge a0-a1 (at height `a_y`) to edge b0-b1 (at `b_y`), facing `normal`."""
	var corners: Array[Vector3] = [Vector3(a0.x, a_y, a0.y), Vector3(a1.x, a_y, a1.y), Vector3(b1.x, b_y, b1.y),
		Vector3(b0.x, b_y, b0.y)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.add_vertex(corners[k])


static func _wall(tool: SurfaceTool, a: Vector2, b: Vector2, low: float, high: float, normal: Vector3) -> void:
	"""One upright side of the beam along a-b, from `low` to `high`, facing `normal`."""
	_quad(tool, a, b, low, a, b, high, normal)


static func ring_loop(radius: float, points: int) -> PackedVector2Array:
	"""A circle of `radius` (m) round the room's middle, `points` round."""
	var out := PackedVector2Array()
	for k in points:
		var angle := TAU * float(k) / float(points)
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


static func box_loop(half: Vector2) -> PackedVector2Array:
	"""A rectangle `half` (m) across and along round the room's middle."""
	return PackedVector2Array([Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)])
