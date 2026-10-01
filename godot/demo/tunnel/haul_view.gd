extends Node3D
## What a dig crew's baskets look like (spoil_haul.gd). Decision 0211 (the underground revamp's P5; design §2
## "Digging": "Behind the face a helper fills a basket and carries it out stooped. The heap at the mouth grows when the
## load is dumped"). Presentation only.
##
## Per resident, from its hauling stage:
##   FILLING   a basket on the floor before it, the spoil in it rising as it fills (the hand clip plays);
##   CARRYING  the loaded basket in its hands (demo_actor.gd `hold`: between the hands on the carry clip, which the
##             bore's stoop bends over), in place of the log;
##   TIPPING   the basket tipped out on the ground before it, toward the heap, emptying -- and, done, a puff of dust
##             where it tipped (warren_particles.gd), the heap grown by the load (tunnel_overlay.gd draws it at what is
##             tipped).
## A basket node per resident is made once; each frame only moves, scales and shows it.

const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HaulScript := preload("res://demo/tunnel/spoil_haul.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const KitScript := preload("res://demo/tunnel/warren_kit.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## A basket on the floor stands this far before its resident (m); tipped, it leans this far over (rad).
const AHEAD_M: float = 0.42
const TIP_LEAN_RAD: float = 1.1
## The spoil in a basket being filled is at least this share of full as soon as it shows.
const FIRST_SPOIL: float = 0.15

var _network: GraphScript = null
var _cast: DemoCastScript = null
var _particles: ParticlesScript = null
var _baskets: Array[Node3D] = []
var _spoil: Array[MeshInstance3D] = []
## Per resident: the stage it was last drawn at, and whether its actor holds the basket.
var _drawn: PackedByteArray = PackedByteArray()
var _held: PackedByteArray = PackedByteArray()
## The demo's props, for the library basket (decision 0371; null or unstaged: warren_kit.gd's stand-in).
var _props: PropsScript = null


func configure(network: GraphScript, cast: DemoCastScript, particles: ParticlesScript, props: PropsScript = null) -> void:
	"""Draw this network's hauling for this cast, puffing from `particles`, its baskets `props`' (warren_kit.gd): a
	hidden basket per resident."""
	name = "HaulView"
	_props = props
	_network = network
	_cast = cast
	_particles = particles
	_drawn.resize(cast.actor_count())
	_held.resize(cast.actor_count())
	for i in cast.actor_count():
		var basket_node := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = KitScript.basket(props)
		basket_node.add_child(body)
		var spoil := MeshInstance3D.new()
		spoil.mesh = KitScript.spoil_heap()
		spoil.position = Vector3(0.0, KitScript.rim_m(props) * 0.35, 0.0)
		basket_node.add_child(spoil)
		basket_node.visible = false
		add_child(basket_node)
		_baskets.append(basket_node)
		_spoil.append(spoil)


func basket(i: int) -> Node3D:
	"""Resident `i`'s floor basket (checks)."""
	return _baskets[i]


func refresh() -> void:
	"""Every resident's basket as its hauling stands (see the header)."""
	var haul: HaulScript = _network.haul
	for i in _baskets.size():
		var stage := haul.stage_of(i)
		if stage == HaulScript.STAGE_NONE and _drawn[i] == HaulScript.STAGE_NONE:
			continue
		if _drawn[i] == HaulScript.STAGE_TIPPING and stage != HaulScript.STAGE_TIPPING:
			_particles.puff(_baskets[i].position + Vector3(0.0, 0.15, 0.0), Layers.SURFACE)
		_drawn[i] = stage
		_hold(i, stage == HaulScript.STAGE_CARRYING)
		_place(i, stage, haul.fill_permille[i] if i < haul.fill_permille.size() else 0)


func _toward_heap(i: int, from: Vector2) -> Vector2:
	"""The way from `from` to the heap resident `i` tips at (its mouth's; straight ahead of it with none placed)."""
	var m: int = _network.haul.mouth_of[i] if i < _network.haul.mouth_of.size() else -1
	if m < 0 or _network.heap_radius_m[m] <= 0.0 or _network.heap_at[m].distance_to(from) < 0.01:
		var yaw: float = (_cast.actor(i) as DemoActorScript).brain.yaw
		return Vector2(sin(yaw), cos(yaw))
	return (_network.heap_at[m] - from).normalized()


func _hold(i: int, carrying: bool) -> void:
	"""Resident `i`'s actor holds the loaded basket while it carries, and lets it go after (touched on a change only)."""
	var want := 1 if carrying else 0
	if _held[i] == want:
		return
	_held[i] = want
	var actor := _cast.actor(i) as DemoActorScript
	if carrying:
		actor.hold(KitScript.loaded_basket(_props), KitScript.basket_fit(_props))
	else:
		actor.drop_held()


func _place(i: int, stage: int, permille: int) -> void:
	"""Resident `i`'s floor basket: before it while it fills (spoil rising) or tips (leaning over, emptying), else
	hidden."""
	var basket_node := _baskets[i]
	basket_node.visible = stage == HaulScript.STAGE_FILLING or stage == HaulScript.STAGE_TIPPING
	if not basket_node.visible:
		return
	var brain := (_cast.actor(i) as DemoActorScript).brain
	var tipping := stage == HaulScript.STAGE_TIPPING
	var way := _toward_heap(i, brain.position) if tipping else Vector2(sin(brain.yaw), cos(brain.yaw))
	var feet := (_cast.actor(i) as Node3D).position
	basket_node.position = Vector3(brain.position.x + way.x * AHEAD_M, feet.y, brain.position.y + way.y * AHEAD_M)
	basket_node.rotation = Vector3(TIP_LEAN_RAD if tipping else 0.0, atan2(way.x, way.y), 0.0)
	var share := float(permille) / float(Rules.PERMILLE)
	var fill := 1.0 - share if tipping else lerpf(FIRST_SPOIL, 1.0, share)
	_spoil[i].scale = Vector3(1.0, maxf(fill, 0.01), 1.0)
	var layer := Layers.body_mask(brain.view_level())
	if basket_node.get_child(0) is VisualInstance3D and (basket_node.get_child(0) as VisualInstance3D).layers != layer:
		Layers.set_layers(basket_node, layer)
