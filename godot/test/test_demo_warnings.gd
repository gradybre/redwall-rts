extends "res://test/framework/test_case.gd"
## The warren's warnings and signs (decision 0211, the underground revamp's P5): the hazards' visual language
## (hazard_look.gd) and its drawing (hazard_view.gd: the bore's instance uniforms, the drips and the sand), the U view's
## warning rings, the surface signs (turf seams that heal, air vents, the mouths' hung lanterns) and the brace cost in
## the Dig tool's readout. (The HUD's Beds cell is the village's now: test_demo_hud_truth.gd, decision 0251.)
##
## No scene tree and no staged assets; nodes are built out of the tree and freed after each test.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const LookScript := preload("res://demo/tunnel/hazard_look.gd")
const HazardViewScript := preload("res://demo/tunnel/hazard_view.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const SignsScript := preload("res://demo/tunnel/warren_signs.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const TICKS_PER_DAY: int = SimClock.TICKS_PER_DAY

var _nodes: Array[Node] = []


func tolerates_outside_tree() -> bool:
	"""Its node fixtures are never inside the scene tree (test_case.gd ENGINE DIAGNOSTICS)."""
	return true


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


func _open_tunnel(network: GraphScript, points: Array[Vector2i]) -> PackedInt32Array:
	"""A mouth-to-mouth tunnel along these points, dug to the end; its segments in dig order."""
	var flat := PackedInt32Array()
	for p in points:
		flat.append_array([p.x, p.y])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(flat, points.size(), 0, ref), "fixture tunnel stored")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	return chain


func _site(points: Array[Vector2i]) -> Array:
	"""An open tunnel with its bores built on day 0 and its hazards: [network, bores, hazards, chain, calendar]."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var chain := _open_tunnel(network, points)
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var calendar := CalendarScript.new()
	bores.set_calendar(calendar)
	for slot in chain:
		bores.build(slot, network.length_m(slot), 0.0)
	return [network, bores, HazardsScript.new(network), chain, calendar]


static func _tunnels_of(network: GraphScript, chain: PackedInt32Array) -> PackedInt32Array:
	"""The open tunnel segments of `chain`."""
	var out := PackedInt32Array()
	for slot in chain:
		if network.is_tunnel(slot) and network.is_open(slot):
			out.append(slot)
	return out


# --- the visual language --------------------------------------------------------------------------

func test_the_signs_come_before_the_warning() -> void:
	"""The first signs show at half the warning's pressure, so a hazard is seen before the notice feed names it."""
	assert_equal(LookScript.SIGN_PERMILLE, HazardsScript.WARN_PERMILLE / 2, "half the warning's")
	assert_true(LookScript.SIGN_PERMILLE < HazardsScript.WARN_PERMILLE, "before it")


func test_the_level_rises_from_the_signs_to_the_strike() -> void:
	"""level_permille: 0 below the signs, 0 at them, rising evenly to 1000 at the strike, never past it."""
	var sign := LookScript.SIGN_PERMILLE
	assert_equal(LookScript.level_permille(0), 0, "nothing")
	assert_equal(LookScript.level_permille(sign - 1), 0, "just short of the signs")
	assert_equal(LookScript.level_permille(sign), 0, "the signs begin")
	assert_equal(LookScript.level_permille(sign + 1), 1000 / (1000 - sign), "and rise")
	assert_equal(LookScript.level_permille(HazardsScript.WARN_PERMILLE), (500 - sign) * 1000 / (1000 - sign), "at the warning")
	assert_equal(LookScript.level_permille(1000), 1000, "at the strike: full")
	assert_equal(LookScript.level_permille(1400), 1000, "never past it")


func test_each_seep_state_has_its_look() -> void:
	"""Plain below the signs; first signs; warned; flooded (its own look); plain when braced or closed another way."""
	var sign := LookScript.SIGN_PERMILLE
	var warn := HazardsScript.WARN_PERMILLE
	var none := GraphScript.CLOSED_NONE
	assert_equal(LookScript.seep_look(sign - 1, none, false), LookScript.LOOK_NONE, "below the signs")
	assert_equal(LookScript.seep_look(sign, none, false), LookScript.LOOK_SEEP_SIGNS, "the first signs")
	assert_equal(LookScript.seep_look(warn - 1, none, false), LookScript.LOOK_SEEP_SIGNS, "signs till the warning")
	assert_equal(LookScript.seep_look(warn, none, false), LookScript.LOOK_SEEP_WARNED, "warned")
	assert_equal(LookScript.seep_look(1000, GraphScript.CLOSED_FLOODED, false), LookScript.LOOK_FLOODED, "struck")
	assert_equal(LookScript.seep_look(900, GraphScript.CLOSED_COLLAPSED, false), LookScript.LOOK_NONE, "fallen in instead")
	assert_equal(LookScript.seep_look(900, none, true), LookScript.LOOK_NONE, "braced: plain")


func test_each_strain_state_has_its_look() -> void:
	"""The strain's: plain, first signs, warned, fallen in; plain when braced or flooded instead."""
	var sign := LookScript.SIGN_PERMILLE
	var warn := HazardsScript.WARN_PERMILLE
	var none := GraphScript.CLOSED_NONE
	assert_equal(LookScript.strain_look(sign - 1, none, false), LookScript.LOOK_NONE, "below the signs")
	assert_equal(LookScript.strain_look(sign, none, false), LookScript.LOOK_STRAIN_SIGNS, "the first signs")
	assert_equal(LookScript.strain_look(warn, none, false), LookScript.LOOK_STRAIN_WARNED, "warned")
	assert_equal(LookScript.strain_look(0, GraphScript.CLOSED_COLLAPSED, false), LookScript.LOOK_COLLAPSED, "struck")
	assert_equal(LookScript.strain_look(900, GraphScript.CLOSED_FLOODED, false), LookScript.LOOK_NONE, "flooded instead")
	assert_equal(LookScript.strain_look(900, none, true), LookScript.LOOK_NONE, "braced: plain")
	assert_equal(LookScript.LOOK_NAMES.size(), LookScript.LOOK_COLLAPSED + 1, "every look named")


func test_only_a_warning_look_is_drawn_in_the_earth() -> void:
	"""shown_level: the pressure's level for the signs and the warnings; 0 for plain, flooded and fallen in."""
	for look: int in [LookScript.LOOK_SEEP_SIGNS, LookScript.LOOK_SEEP_WARNED, LookScript.LOOK_STRAIN_SIGNS,
			LookScript.LOOK_STRAIN_WARNED]:
		assert_equal(LookScript.shown_level(look, 750), LookScript.level_permille(750), LookScript.LOOK_NAMES[look])
	for look: int in [LookScript.LOOK_NONE, LookScript.LOOK_FLOODED, LookScript.LOOK_COLLAPSED]:
		assert_equal(LookScript.shown_level(look, 1000), 0, LookScript.LOOK_NAMES[look])


# --- the warnings drawn ---------------------------------------------------------------------------

func test_a_bore_is_handed_its_hazard_levels() -> void:
	"""A seep at 750 and a strain at 600: every chunk of the bore gets both levels as instance uniforms; braced, both
	go back to 0; a segment never tunnelled is handed nothing."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var bores: BoreViewScript = site[1]
	var hazards: HazardsScript = site[2]
	var slot: int = _tunnels_of(network, site[3])[0]
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HazardViewScript = _keep(HazardViewScript.new())
	view.configure(network, hazards, bores, pools)
	hazards.seep_usec[slot] = HazardsScript.SEEP_FULL_USEC * 3 / 4
	hazards.strain_usec[slot] = HazardsScript.STRAIN_FULL_USEC * 3 / 5
	view.refresh()
	assert_equal(view.seep_level(slot), LookScript.level_permille(750), "the seep's level")
	assert_equal(view.strain_level(slot), LookScript.level_permille(600), "the strain's")
	for k in BoreViewScript.CHUNKS:
		var chunk := bores.chunk(slot, k)
		assert_true(absf(float(chunk.get_instance_shader_parameter(&"seep_level")) - 0.666) < 0.001, "chunk %d wet" % k)
		assert_true(absf(float(chunk.get_instance_shader_parameter(&"strain_level")) - 0.466) < 0.001, "and cracked")
	network.braced[slot] = 1
	view.refresh()
	assert_equal([view.seep_level(slot), view.strain_level(slot)], [0, 0], "braced: plain")
	assert_almost_equal(float(bores.chunk(slot, 0).get_instance_shader_parameter(&"seep_level")), 0.0, "written back")


func test_a_segment_split_finds_its_strain_again() -> void:
	"""A split keeps a segment's generation and shortens it: its weak section is found again for the new length."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[2]
	var slot: int = _tunnels_of(network, site[3])[0]
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HazardViewScript = _keep(HazardViewScript.new())
	view.configure(network, hazards, site[1], pools)
	hazards.fall_from_u[slot] = 2048
	hazards.fall_to_u[slot] = 4096
	hazards.strain_usec[slot] = HazardsScript.STRAIN_FULL_USEC * 6 / 10
	view.refresh()
	assert_almost_equal(view._strain_span[slot].x, 1.5, "its weak section")
	network.length_u[slot] -= 1024
	hazards.fall_from_u[slot] = 1024
	hazards.fall_to_u[slot] = 3072
	hazards.strain_usec[slot] = HazardsScript.STRAIN_FULL_USEC * 8 / 10
	view.refresh()
	assert_almost_equal(view._strain_span[slot].x, 0.5, "found again")


func test_a_level_is_written_only_when_it_moves_a_step() -> void:
	"""A creep under LEVEL_STEP leaves the bore as drawn; a step's worth writes it."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[2]
	var slot: int = _tunnels_of(network, site[3])[0]
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HazardViewScript = _keep(HazardViewScript.new())
	view.configure(network, hazards, site[1], pools)
	hazards.seep_usec[slot] = HazardsScript.SEEP_FULL_USEC * 6 / 10
	view.refresh()
	var drawn := view.seep_level(slot)
	hazards.seep_usec[slot] += HazardsScript.SEEP_FULL_USEC / 200
	view.refresh()
	assert_equal(view.seep_level(slot), drawn, "a creep: not written")
	hazards.seep_usec[slot] += HazardsScript.SEEP_FULL_USEC / 40
	view.refresh()
	assert_true(view.seep_level(slot) >= drawn + HazardViewScript.LEVEL_STEP, "a step: written")


func test_the_first_signs_are_drawn_however_faint() -> void:
	"""Just past the signs (260 per mille: level 13, under a LEVEL_STEP) the bore is handed it; a tunnel not yet open
	is handed nothing, whatever its pressure."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[2]
	var slot: int = _tunnels_of(network, site[3])[0]
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HazardViewScript = _keep(HazardViewScript.new())
	view.configure(network, hazards, site[1], pools)
	hazards.seep_usec[slot] = HazardsScript.SEEP_FULL_USEC * 26 / 100
	view.refresh()
	assert_equal(view.seep_level(slot), LookScript.level_permille(260), "faint, but drawn")
	assert_true(view.seep_level(slot) < HazardViewScript.LEVEL_STEP, "under a step")
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 12288, 16384, 12288]), 2, 0, ref)
	var laid := PackedInt32Array()
	network.piece_segments_into(ref[2], laid)
	hazards.seep_usec[laid[0]] = HazardsScript.SEEP_FULL_USEC
	view.refresh()
	assert_equal(view.seep_level(laid[0]), 0, "not open: nothing")


func test_the_worst_seeps_drip_and_the_worst_strains_trickle() -> void:
	"""Of three seeping tunnels the two worst drip, worst first, from near the crown; one straining tunnel trickles
	sand in the first sand slot, the second off; all eased, nothing falls."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var slots := PackedInt32Array()
	for row in 3:
		slots.append_array(_tunnels_of(network, _open_tunnel(network, [Vector2i(0, row * 8192), Vector2i(16384, row * 8192)])))
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	for slot in slots:
		bores.build(slot, network.length_m(slot), 0.0)
	var hazards := HazardsScript.new(network)
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HazardViewScript = _keep(HazardViewScript.new())
	view.configure(network, hazards, bores, pools)
	hazards.seep_usec[slots[0]] = HazardsScript.SEEP_FULL_USEC * 6 / 10
	hazards.seep_usec[slots[1]] = HazardsScript.SEEP_FULL_USEC * 9 / 10
	hazards.seep_usec[slots[2]] = HazardsScript.SEEP_FULL_USEC * 7 / 10
	hazards.strain_usec[slots[2]] = HazardsScript.STRAIN_FULL_USEC * 8 / 10
	view.refresh()
	assert_equal([view.dripping(0), view.dripping(1)], [slots[1], slots[2]], "the two worst, worst first")
	assert_equal([view.trickling(0), view.trickling(1)], [slots[2], -1], "one strain")
	assert_true(pools.hazard(0, false).emitting and pools.hazard(1, false).emitting, "dripping")
	assert_true(pools.hazard(0, true).emitting and not pools.hazard(1, true).emitting, "sand in one slot")
	var crown := Rules.crown_m(int(network.bore[slots[1]])) * HazardViewScript.CROWN_SHARE
	assert_true(pools.hazard(0, false).position.y > network.floor_y_at(slots[1], 1.0) + crown - 0.3, "from near the crown")
	for slot in slots:
		hazards.seep_usec[slot] = 0
		hazards.strain_usec[slot] = 0
	view.refresh()
	assert_false(pools.hazard(0, false).emitting or pools.hazard(0, true).emitting, "eased: nothing falls")


func test_a_warned_tunnel_is_ringed_in_clay_in_the_u_view_too() -> void:
	"""A warning rings the tunnel's ends on the surface and in the U view, below over the cap (no depth test), in
	clay; eased, the rings go."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[2]
	var slot: int = _tunnels_of(network, site[3])[0]
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, hazards, PropsScript.new(), DemoClockScript.new())
	hazards.strain_usec[slot] = HazardsScript.STRAIN_FULL_USEC * 6 / 10
	marks.refresh()
	var below: MeshInstance3D = marks._rings_below[2 * slot]
	assert_true(marks._rings[2 * slot].visible and below.visible, "ringed above and below")
	var material := below.material_override as StandardMaterial3D
	assert_true(material.no_depth_test, "drawn over the cap")
	assert_equal(material.albedo_color, Palette.CLAY, "in clay")
	hazards.strain_usec[slot] = 0
	marks.refresh()
	assert_false(below.visible, "eased: gone")


# --- the surface signs ------------------------------------------------------------------------------

func test_a_young_tunnel_s_seam_heals_over_days() -> void:
	"""Dug on day 0, its seam shows at full freshness; on day 1.5 it is half healed and rebuilt fainter; by
	SEAM_HEAL_DAYS it is gone; nothing is rebuilt between steps."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var network: GraphScript = site[0]
	var calendar: CalendarScript = site[4]
	var slot: int = _tunnels_of(network, site[3])[0]
	var signs: SignsScript = _keep(SignsScript.new())
	signs.configure(network, site[1])
	signs.refresh()
	assert_true(signs.seam(slot).visible, "a fresh seam")
	assert_true((signs.seam(slot).mesh as ArrayMesh).get_surface_count() == 1, "built")
	var box := (signs.seam(slot).mesh as ArrayMesh).get_aabb()
	var span := signs._stretch(slot)
	var width := 2.0 * BoreMeshScript.FLOOR_HALF_M[int(network.bore[slot])] * 0.95
	assert_true(absf(box.size.x - (span.y - span.x)) < 0.05, "as long as its stretch (%.2f)" % box.size.x)
	assert_true(box.size.z > width * 0.7 and box.size.z < width * 1.3, "as wide as the bore, ragged (%.2f)" % box.size.z)
	var alpha := _seam_alpha(signs, slot)
	assert_true(absf(alpha - SignsScript.SEAM_ALPHA) < 0.01, "full (8-bit colour)")
	var built := signs.seam_builds
	signs.refresh()
	assert_equal(signs.seam_builds, built, "unchanged: not rebuilt")
	calendar.tick = TICKS_PER_DAY * 3 / 2
	signs.refresh()
	assert_true(signs.seam(slot).visible and _seam_alpha(signs, slot) < alpha, "fainter")
	assert_almost_equal(SignsScript.freshness(1.5), 0.5, "half healed")
	calendar.tick = TICKS_PER_DAY * 3
	signs.refresh()
	assert_false(signs.seam(slot).visible, "healed: gone")


func _seam_alpha(signs: SignsScript, slot: int) -> float:
	"""The first vertex's alpha of segment `slot`'s seam."""
	var arrays := (signs.seam(slot).mesh as ArrayMesh).surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[0].a


func test_a_dig_under_way_shows_its_seam_growing() -> void:
	"""A tunnel being dug has a seam as far as its face, its key moving as the face goes on, rebuilt longer the same
	day."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var signs: SignsScript = _keep(SignsScript.new())
	signs.configure(network, bores)
	network.start_dig(chain[0], network.generation[chain[0]], 0)
	network.advance(chain[0], network.generation[chain[0]], 1000000000)
	var slot := chain[1]
	assert_equal(signs.seam_key(slot), -1, "nothing dug: no seam")
	network.start_dig(slot, network.generation[slot], 0)
	network.advance(slot, network.generation[slot], 2000000)
	var key := signs.seam_key(slot)
	assert_true(key >= 0, "dug a little: a seam")
	assert_almost_equal(signs.dug_m(slot), network.face_m(slot), "to its face")
	signs.refresh()
	var built := signs.seam_builds
	var short := (signs.seam(slot).mesh as ArrayMesh).get_aabb().size.length()
	network.advance(slot, network.generation[slot], 4000000)
	assert_true(signs.seam_key(slot) != key, "the face went on: a new seam")
	signs.refresh()
	assert_equal(signs.seam_builds, built + 1, "rebuilt the same day")
	assert_true((signs.seam(slot).mesh as ArrayMesh).get_aabb().size.length() > short, "longer")


func test_a_long_bore_breathes_through_vents() -> void:
	"""Over a tunnel at least VENT_MIN_M long, a vent every VENT_SPACING_M of its stretch, clear of its ends; none over
	a short one; none on a crop bed."""
	var site := _site([Vector2i(0, 0), Vector2i(30720, 0)])
	var network: GraphScript = site[0]
	var signs: SignsScript = _keep(SignsScript.new())
	signs.configure(network, site[1])
	signs.refresh()
	var expected := 0
	for slot in _tunnels_of(network, site[3]):
		if network.length_m(slot) >= SignsScript.VENT_MIN_M:
			var span := signs._stretch(slot)
			var usable := span.y - span.x - 2.0 * SignsScript.VENT_CLEAR_M
			expected += floori(usable / SignsScript.VENT_SPACING_M) + 1 if usable >= 0.0 else 0
	assert_true(expected >= 3, "a 30 m tunnel wants some (%d)" % expected)
	assert_equal(signs.vent_count(), expected, "that many stand")
	var short := _site([Vector2i(0, 0), Vector2i(8192, 0)])
	for slot in _tunnels_of(short[0], short[3]):
		assert_true((short[0] as GraphScript).length_m(slot) < SignsScript.VENT_MIN_M, "an 8 m tunnel's stretches are short")
	var few: SignsScript = _keep(SignsScript.new())
	few.configure(short[0], short[1])
	few.refresh()
	assert_equal(few.vent_count(), 0, "so it has none")
	assert_true(SignsScript.on_crop_bed(Catalog.bed_centre_m(0)), "a bed's middle is a bed")
	assert_false(SignsScript.on_crop_bed(Vector2(500.0, 500.0)), "far off, not")


func test_a_tunnel_stretch_under_six_metres_has_no_vent() -> void:
	"""A stretch long enough to clear both ends (3 m) but under VENT_MIN_M has none."""
	var found := false
	for metres in range(8, 16):
		var site := _site([Vector2i(0, 0), Vector2i(metres * 1024, 0)])
		var network: GraphScript = site[0]
		var signs: SignsScript = _keep(SignsScript.new())
		signs.configure(network, site[1])
		var mid := false
		var any_long := false
		for slot in _tunnels_of(network, site[3]):
			var span := signs._stretch(slot)
			any_long = any_long or network.length_m(slot) >= SignsScript.VENT_MIN_M
			mid = mid or (network.length_m(slot) < SignsScript.VENT_MIN_M and span.y - span.x >= 2.0 * SignsScript.VENT_CLEAR_M)
		if mid and not any_long:
			signs.refresh()
			assert_equal(signs.vent_count(), 0, "a %d m tunnel: no vent" % metres)
			found = true
			break
	assert_true(found, "a tunnel with only such stretches was found")


func test_no_vent_stands_on_a_crop_bed() -> void:
	"""A long tunnel under a crop bed: its vents skip the bed -- fewer than its length wants, none on it."""
	var bed := Catalog.bed_centre_m(0)
	var from := Vector2i(roundi((bed.x - 15.0) * 1024.0), roundi(bed.y * 1024.0))
	var site := _site([from, from + Vector2i(30720, 0)])
	var network: GraphScript = site[0]
	var signs: SignsScript = _keep(SignsScript.new())
	signs.configure(network, site[1])
	signs.refresh()
	var wanted := 0
	for slot in _tunnels_of(network, site[3]):
		if network.length_m(slot) >= SignsScript.VENT_MIN_M:
			var span := signs._stretch(slot)
			wanted += floori((span.y - span.x - 2.0 * SignsScript.VENT_CLEAR_M) / SignsScript.VENT_SPACING_M) + 1
	assert_true(signs.vent_count() < wanted, "fewer (%d of %d)" % [signs.vent_count(), wanted])
	for k in signs.vent_count():
		var at := signs.vents().multimesh.get_instance_transform(k).origin
		assert_false(SignsScript.on_crop_bed(Vector2(at.x, at.z)), "vent %d off the bed" % k)


func test_the_seams_and_vents_are_on_the_surface_only() -> void:
	"""The U view never draws them."""
	var site := _site([Vector2i(0, 0), Vector2i(16384, 0)])
	var signs: SignsScript = _keep(SignsScript.new())
	signs.configure(site[0], site[1])
	assert_equal(signs.seam(0).layers, 1, "seams: surface")
	assert_equal(signs.vents().layers, 1, "vents: surface")


func test_a_mouth_arch_hangs_a_lit_lantern() -> void:
	"""The gateway has a second surface -- the lantern's glass, glowing -- hung out from the lintel below it."""
	var gate := MouthScript.gateway_mesh()
	assert_equal(gate.get_surface_count(), 2, "the arch and the glass")
	var glass := gate.surface_get_material(1) as StandardMaterial3D
	assert_true(glass.emission_enabled and glass.emission_energy_multiplier >= 1.0, "lit")
	var at := MouthScript.lantern_at()
	assert_true(at.y < MouthScript.GATE_HEIGHT_M and at.y > MouthScript.GATE_HEIGHT_M - 0.5, "hung under the lintel")
	assert_true(at.z < 0.0, "out in front")
	assert_true(absf(at.x) < MouthScript.OPENING_M * 0.5, "over the way in")


# --- the brace cost in the readout -------------------------------------------------------------------

func test_the_readout_prices_the_bracing() -> void:
	"""brace_text: a quantum's wood and stone times the quanta, to the tenth of a unit, rounded down."""
	var wood := JobsScript.BRACE_WOOD_MILLI_U * 13
	var stone := JobsScript.BRACE_STONE_MILLI_U * 13
	assert_equal(ReadoutScript.brace_text(13), "brace %d.%d wood + %d.%d stone" % [wood / 1000, wood % 1000 / 100,
		stone / 1000, stone % 1000 / 100], "13 quanta")
	assert_equal(ReadoutScript.brace_text(0), "brace 0.0 wood + 0.0 stone", "nothing")
	assert_equal(ReadoutScript.tenths(3790), "3.7", "rounded down")
	assert_equal(ReadoutScript.tenths(4000), "4.0", "whole")
	assert_equal(ReadoutScript.tenths(99), "0.0", "under a tenth")
