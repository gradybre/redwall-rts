extends Node3D
## THE APIARY DRAWN (decision 1601): each apiary's skep -- the food art's `bee_skep` (decision 0941, 0.75 m; its
## placeholder of the same footprint unstaged) -- and its bees, the free `bee_swarm.gd` effect of art pass 3 (decision
## 0971), wired as art_pass3_mapping.md asks: one swarm per occupied skep, out spring to autumn, hidden in winter and
## while the hive is abandoned, on the demo clock's speed (0 paused) and REDUCED with the player's reduced-motion setting.
## Presentation only: the bees are not folk (the packet's pitfall), and they carry nothing.

const Rules := preload("res://demo/hives/hive_rules.gd")
const ApiaryScript := preload("res://demo/hives/apiary_model.gd")
const SwarmScript := preload("res://demo/fx/bee_swarm.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")

const SKEP_KEY: StringName = &"bee_skep"
## The skep is staged at game height (DEC-048's 0.75 m): drawn at scale 1.
const SKEP_SIZE: float = 1.0
const SKEP_YAW: float = 0.3

var swarms: Array[SwarmScript] = []
var skeps: Array[Node3D] = []

var _model: ApiaryScript = null
var _calendar: CalendarScript = null
var _clock: DemoClockScript = null
var _reduced: bool = false
var _active: PackedByteArray = PackedByteArray()


func configure(model: ApiaryScript, make_piece: Callable, calendar: CalendarScript, clock: DemoClockScript) -> void:
	"""Draw `model`'s apiaries: a skep each (through the world's `make_piece`, absent in a check) and its swarm."""
	name = "ApiaryView"
	_model = model
	_calendar = calendar
	_clock = clock
	for apiary: int in Rules.APIARY_COUNT:
		var at: Vector2 = Rules.centre_m(apiary)
		if make_piece.is_valid():
			var skep: Node3D = make_piece.call(SKEP_KEY, at, SKEP_YAW, SKEP_SIZE)
			if skep != null:
				add_child(skep)
				skeps.append(skep)
		var swarm := SwarmScript.new()
		add_child(swarm)
		swarm.configure()
		swarm.place(Vector3(at.x, 0.0, at.y))
		swarms.append(swarm)
	_active.resize(Rules.APIARY_COUNT)
	_active.fill(2)
	follow()


func _process(_delta: float) -> void:
	"""Each frame: the bees on the clock's speed, reduced motion followed, each swarm out only when its hive is."""
	follow()


func follow() -> void:
	"""Bring the swarms up to date with the clock, the setting and each hive's season and state."""
	var speed: float = float(_clock.speed) if _clock != null else 1.0
	if _reduced != DemoMotion.reduced:
		_reduced = DemoMotion.reduced
		for swarm: SwarmScript in swarms:
			swarm.set_reduced(_reduced)
	for apiary: int in swarms.size():
		swarms[apiary].set_speed(speed)
		var on: int = 1 if is_out(apiary) else 0
		if _active[apiary] != on:
			_active[apiary] = on
			swarms[apiary].set_active(on == 1)


func is_out(apiary: int) -> bool:
	"""Whether apiary `apiary`'s bees are flying: a live hive outside winter (the hive's seasonal rhythm, ECO-011)."""
	if _model == null or _model.is_abandoned(apiary):
		return false
	var day: int = _calendar.now().absolute_day if _calendar != null else Hive.MIN_CALENDAR_DAY
	return Hive.season_of_day(day) != Hive.SEASON_WINTER
