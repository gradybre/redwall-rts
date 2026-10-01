extends Node3D
## The hazards' warnings, drawn: every open tunnel's seep and strain as hazard_look.gd names them. Decision 0211 (the
## underground revamp's P5; DEC-040 "warned"). Presentation only.
##
## IN THE BORE'S OWN EARTH (bore_surface.gdshaderinc THE HAZARDS): each segment's bore chunks are handed its seep's and
## strain's levels and the stretches they gather in -- its wet ground (the quanta tunnel_ground.gd calls wet) and its
## weak section (where tunnel_hazards.gd would drop its fall) -- as instance uniforms (bore_view.gd `set_hazard`),
## written only when a level moves a LEVEL_STEP. No material changes, nothing is built.
## FROM THE CROWN (warren_particles.gd): the HAZARD_SLOTS worst seeps drip and the worst strains trickle sand, each
## over the middle of its stretch.
## Everything is read from the hazards and the network each frame; the stretches only when a segment changes.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const LookScript := preload("res://demo/tunnel/hazard_look.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")

## A level is written to the bore when it has moved this much (per mille).
const LEVEL_STEP: int = 16
## The drips and sand fall from this share of the crown's height, spread at most this far either way (m).
const CROWN_SHARE: float = 0.9
const MAX_SPREAD_M: float = 1.4

var _network: GraphScript = null
var _hazards: HazardsScript = null
var _bores: BoreViewScript = null
var _particles: ParticlesScript = null
## Per segment: the levels last written (-1: never), the key its stretches were found for, and the stretches (m).
var _seep_shown: PackedInt32Array = PackedInt32Array()
var _strain_shown: PackedInt32Array = PackedInt32Array()
var _span_key: PackedInt64Array = PackedInt64Array()
var _seep_span: PackedVector2Array = PackedVector2Array()
var _strain_span: PackedVector2Array = PackedVector2Array()
## This frame's levels (per mille) and the particles' picks (segments, -1: none).
var _seep: PackedInt32Array = PackedInt32Array()
var _strain: PackedInt32Array = PackedInt32Array()
var _drip_at: PackedInt32Array = PackedInt32Array()
var _sand_at: PackedInt32Array = PackedInt32Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func configure(network: GraphScript, hazards: HazardsScript, bores: BoreViewScript, particles: ParticlesScript) -> void:
	"""Draw this network's hazards into its bores and from `particles`. Columns sized once."""
	name = "HazardView"
	_network = network
	_hazards = hazards
	_bores = bores
	_particles = particles
	for column: PackedInt32Array in [_seep_shown, _strain_shown, _seep, _strain]:
		column.resize(Rules.MAX_SEGMENTS)
	_seep_shown.fill(-1)
	_strain_shown.fill(-1)
	_span_key.resize(Rules.MAX_SEGMENTS)
	_span_key.fill(-1)
	_seep_span.resize(Rules.MAX_SEGMENTS)
	_strain_span.resize(Rules.MAX_SEGMENTS)
	_drip_at.resize(ParticlesScript.HAZARD_SLOTS)
	_sand_at.resize(ParticlesScript.HAZARD_SLOTS)


func refresh() -> void:
	"""Every segment's levels into its bore, and the worst seeps and strains dripping and trickling."""
	for slot in Rules.MAX_SEGMENTS:
		_levels(slot)
		_write(slot)
	_pick(_seep, _drip_at)
	_pick(_strain, _sand_at)
	for k in ParticlesScript.HAZARD_SLOTS:
		_fall(k, false, _drip_at[k], _seep_span)
		_fall(k, true, _sand_at[k], _strain_span)


func _levels(slot: int) -> void:
	"""Segment `slot`'s seep and strain levels this frame (per mille; hazard_look.gd), 0 for anything not an open
	tunnel."""
	_seep[slot] = 0
	_strain[slot] = 0
	if not _network.is_tunnel(slot) or not _network.is_open(slot):
		return
	var closed := int(_network.closed[slot])
	var braced := _network.braced[slot] == 1
	var seep := _hazards.seep_permille(slot)
	var strain := _hazards.strain_permille(slot)
	_seep[slot] = LookScript.shown_level(LookScript.seep_look(seep, closed, braced), seep)
	_strain[slot] = LookScript.shown_level(LookScript.strain_look(strain, closed, braced), strain)


func _write(slot: int) -> void:
	"""Hand segment `slot`'s levels and stretches to its bore when a level moved a LEVEL_STEP (or reached 0)."""
	var seep := _seep[slot]
	var strain := _strain[slot]
	if _moved(_seep_shown[slot], seep) or _moved(_strain_shown[slot], strain):
		if seep > 0 or strain > 0:
			_find_spans(slot)
		_seep_shown[slot] = seep
		_strain_shown[slot] = strain
		_bores.set_hazard(slot, float(seep) / float(Rules.PERMILLE), _seep_span[slot], float(strain) / float(Rules.PERMILLE),
			_strain_span[slot])


static func _moved(shown: int, now: int) -> bool:
	"""Whether a level `now` differs enough from the one `shown` to be written: a LEVEL_STEP, or to or from 0."""
	return absi(now - shown) >= LEVEL_STEP or ((now == 0) != (shown == 0))


func _find_spans(slot: int) -> void:
	"""Segment `slot`'s wet stretch -- its first to its last wet quantum -- and its weak section (where its fall would
	drop), in metres along it; found again only when the segment changed."""
	var key: int = (_network.generation[slot] << 32) | _network.length_u[slot]
	if _span_key[slot] == key:
		return
	_span_key[slot] = key
	var ground := _network.ground
	var first := INF
	var last := -INF
	for k in _network.timeline_count(slot):
		var at := _network.quantum_point_u(slot, k)
		if ground != null and ground.wet_at_level(at.x, at.y, _network.quantum_level(slot, k)):
			var along := Rules.to_m(_network.quantum_along_u(slot, k))
			first = minf(first, along)
			last = maxf(last, along)
	_seep_span[slot] = Vector2(first - 0.5, last + 0.5) if first <= last else Vector2.ZERO
	_strain_span[slot] = Vector2(Rules.to_m(_hazards.fall_from_u[slot]) - 0.5, Rules.to_m(_hazards.fall_to_u[slot]) + 0.5)


static func _pick(levels: PackedInt32Array, out: PackedInt32Array) -> void:
	"""The HAZARD_SLOTS segments of highest level over 0, highest first (the lower slot on a tie), into `out` (-1
	past them)."""
	out.fill(-1)
	for slot in levels.size():
		if levels[slot] <= 0:
			continue
		var at := out.size() - 1
		if out[at] >= 0 and levels[out[at]] >= levels[slot]:
			continue
		while at > 0 and (out[at - 1] < 0 or levels[out[at - 1]] < levels[slot]):
			out[at] = out[at - 1]
			at -= 1
		out[at] = slot


func _fall(k: int, sand: bool, slot: int, spans: PackedVector2Array) -> void:
	"""Hazard slot `k`'s drips (or sand) over the middle of segment `slot`'s stretch, from near its crown (off when
	`slot` is -1)."""
	if slot < 0:
		_particles.set_hazard(k, sand, Vector3.ZERO, Vector3.FORWARD, 0.0, false)
		return
	var span := spans[slot]
	var middle := clampf((span.x + span.y) * 0.5, 0.0, _network.length_m(slot))
	BoreCurveScript.of(_network, slot).sample(middle, _sample)
	var crown := Rules.crown_m(int(_network.bore[slot])) * CROWN_SHARE
	var at := Vector3(_sample[0].x, _network.floor_y_at(slot, middle) + crown, _sample[0].y)
	var half := minf((span.y - span.x) * 0.5, MAX_SPREAD_M)
	_particles.set_hazard(k, sand, at, Vector3(_sample[1].x, 0.0, _sample[1].y), half, true)


func seep_level(slot: int) -> int:
	"""Segment `slot`'s seep level last drawn (per mille; checks)."""
	return _seep_shown[slot]


func strain_level(slot: int) -> int:
	"""Segment `slot`'s strain level last drawn (per mille; checks)."""
	return _strain_shown[slot]


func dripping(k: int) -> int:
	"""The segment hazard slot `k`'s drips fall in (-1: none; checks)."""
	return _drip_at[k]


func trickling(k: int) -> int:
	"""The segment hazard slot `k`'s sand falls in (-1: none; checks)."""
	return _sand_at[k]
