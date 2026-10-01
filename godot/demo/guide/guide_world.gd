extends RefCounted
## What the first-village guide READS of the village (decision 0481): the real models the objectives complete on, bound
## once by demo_guide.gd -- the selection, the cast's brains, the farm's beds and pantry and job board, the kitchen,
## the bridges, the tunnel network, the calendar and the stores. Every field may be left unbound (null / an invalid
## Callable): a reader then answers "nothing there", so a suite builds only what it checks. The guide WRITES NOTHING
## through this: it is read-only by construction (no method here changes a model).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

## `selected() -> PackedInt32Array` (the command layer's selection; allocates, so read on a click, not each frame),
## `first() -> int` (the first selected, -1 for none; the per-frame read), `name_of(i) -> String`.
var selected: Callable = Callable()
var first: Callable = Callable()
var name_of: Callable = Callable()
## The cast's brains, by resident index (read: state, position, underground, in_water, resting, indoors).
var brains: Array[BrainScript] = []
var sim: SimScript = null
var pantry: PantryScript = null
## The farm crew's job board and `worker_name(row) -> String`.
var jobs: JobsScript = null
var worker_name: Callable = Callable()
var kitchen: KitchenScript = null
var bridges: BridgesScript = null
## `bridge_refusal(kind) -> String` (demo_waterplay.gd build_refusal: "" when it may be built now) and `site_name()`.
var bridge_refusal: Callable = Callable()
var site_name: Callable = Callable()
var network: GraphScript = null
var calendar: CalendarScript = null
## The seasonal planner's after-action record (farm_record.gd, decision 0451): the village goals read its closed seasons.
var record: RecordScript = null
var stores: StoresScript = null
## `focus() -> Vector3`: where the camera looks (the resident marker picks the nearest to it).
var focus: Callable = Callable()
## `selected_bed() -> int` (-1: none) and `selected_tunnel() -> int` (-1: none): what a new project links to.
var selected_bed: Callable = Callable()
var selected_tunnel: Callable = Callable()
## The stream's shape, read-only: the practice stories survey their own bridge over it (practice_stories.gd).
var water_map: WaterMapScript = null

var _read: IntMath.IntResult = IntMath.IntResult.new()


func selection() -> PackedInt32Array:
	"""The selected residents (none unbound)."""
	return selected.call() as PackedInt32Array if selected.is_valid() else PackedInt32Array()


func first_selected() -> int:
	"""The first selected resident (-1 for none) -- through `first` when bound (no allocation), else the selection."""
	if first.is_valid():
		return int(first.call())
	var chosen: PackedInt32Array = selection()
	return chosen[0] if not chosen.is_empty() else -1


func resident_name(i: int) -> String:
	"""Resident `i`'s name ('a resident' unbound)."""
	return String(name_of.call(i)) if name_of.is_valid() else "a resident"


func resident_point(i: int) -> Vector3:
	"""Where resident `i` stands on the ground (INF for none)."""
	if i < 0 or i >= brains.size():
		return Vector3.INF
	return Vector3(brains[i].position.x, 0.0, brains[i].position.y)


func on_surface(i: int) -> bool:
	"""Whether resident `i` can be seen and clicked on the surface (not below, indoors, in bed or in the water)."""
	var brain: BrainScript = brains[i]
	return not brain.underground and not brain.indoors and not brain.lying and not brain.in_water


func nearest_on_surface(to: Vector3) -> int:
	"""The resident on the surface nearest `to` (-1 when nobody is)."""
	var best: int = -1
	var best_d: float = INF
	for i: int in brains.size():
		if not on_surface(i):
			continue
		var d: float = Vector2(to.x, to.z).distance_squared_to(brains[i].position)
		if d < best_d:
			best_d = d
			best = i
	return best


func camera_focus() -> Vector3:
	"""Where the camera looks (the origin unbound)."""
	return focus.call() as Vector3 if focus.is_valid() else Vector3.ZERO


static func bed_point(bed: int) -> Vector3:
	"""A bed's centre on the ground."""
	var at: Vector2 = Catalog.bed_centre_m(bed)
	return Vector3(at.x, 0.0, at.y)


func bed_label(bed: int) -> String:
	"""A bed as the player reads it ('carrot bed', 'bed 3'), as the farm crew names it."""
	var item: int = sim.item_of(bed) if sim != null else Catalog.NO_ITEM
	if Catalog.is_item(item):
		return "%s bed" % Catalog.ITEM_LABELS[item].to_lower()
	return "bed %d" % (bed + 1)


func the_bed(bed: int) -> String:
	"""A bed in a sentence: 'the carrot bed', or 'bed 3' for an empty one."""
	var label: String = bed_label(bed)
	return label if label.begins_with("bed ") else "the " + label


func hours_to_ripe(bed: int) -> int:
	"""Game hours until bed `bed` ripens at this hour's rate (-1: not growing, or stalled)."""
	if sim == null or not sim.hours_to_ripe_into(bed, _read):
		return -1
	return _read.value


func hour() -> int:
	"""The demo calendar's hour of the day (6 unbound: the demo opens at 06:00)."""
	return calendar.now().hour if calendar != null else 6


func farm_job_on(bed: int, kinds: PackedInt32Array) -> int:
	"""The first live farm job row on `bed` of one of `kinds` (-1 for none)."""
	if jobs == null:
		return -1
	for row: int in jobs.kind.size():
		if jobs.is_live(row) and jobs.bed[row] == bed and kinds.has(jobs.kind[row]):
			return row
	return -1


func job_worker(row: int) -> String:
	"""Who has farm job `row` ('the field crew' while it waits on the board)."""
	var who: String = String(worker_name.call(row)) if worker_name.is_valid() else ""
	return who if not who.is_empty() else "the field crew"


func open_tunnels() -> int:
	"""How many tunnel segments are dug open (rooms' own segments not counted)."""
	if network == null:
		return 0
	var n: int = 0
	for slot: int in TunnelRules.MAX_SEGMENTS:
		if network.is_open(slot) and network.is_tunnel(slot):
			n += 1
	return n


func tunnel_dig_percent() -> int:
	"""The furthest-on tunnel being dug, percent (-1 when none is)."""
	if network == null:
		return -1
	var best: int = -1
	for slot: int in TunnelRules.MAX_SEGMENTS:
		if network.is_tunnel(slot) and network.is_unfinished(slot):
			best = maxi(best, network.percent(slot))
	return best


func open_bridges() -> int:
	"""How many bridges are open."""
	if bridges == null:
		return 0
	var n: int = 0
	for row: int in BridgesScript.MAX_BRIDGES:
		if bridges.is_open(row):
			n += 1
	return n


func cauldron_point() -> Vector3:
	"""The kitchen's cauldron, where supper is cooked (INF unbound)."""
	if kitchen == null or kitchen.places == null:
		return Vector3.INF
	return Vector3(kitchen.places.cauldron.x, 0.0, kitchen.places.cauldron.y)


func places_into(kinds: Array[Vector3i], names: PackedStringArray) -> void:
	"""What is selected now, as a project's places (at most three): the selected bed, the selected tunnel, then the
	selected residents -- each (TARGET_* kind, id, 0) and its name."""
	var bed: int = int(selected_bed.call()) if selected_bed.is_valid() else -1
	if bed >= 0:
		kinds.append(Vector3i(NoticesScript.TARGET_BED, bed, 0))
		names.append(the_bed(bed))
	var tunnel: int = int(selected_tunnel.call()) if selected_tunnel.is_valid() else -1
	if tunnel >= 0:
		kinds.append(Vector3i(NoticesScript.TARGET_TUNNEL, tunnel, 0))
		names.append("Tunnel %d" % (tunnel + 1))
	for who: int in selection():
		if kinds.size() >= 3:
			return
		kinds.append(Vector3i(NoticesScript.TARGET_RESIDENT, who, 0))
		names.append(resident_name(who))
