extends RefCounted
## THE VILLAGE'S CREWS (decision 0411, review F22 and SOC-004): named, visible and editable, in place of the hidden fixed
## routine crews (the farm's fieldworker and gatherer, the woods' forester and beaver, the bridgewright). Presentation
## only: the demo's labour, never the simulation's.
##
## Five crews -- Field, Woods, Diggers, Haulers, Builders -- each with a PREFERRED activity and two FALLBACKS (work_ids.gd
## ACT_*). Every resident is on exactly one crew, which the player may change; a resident starts on its trade's crew
## (START_CREW). A crew's PRIORITY for each activity is REQ-SET-026's 0-4 (0 forbidden, 1 highest): the preferred 1,
## the fallbacks 2 and 3, anything else 4 -- so an idle resident takes ANY work it is eligible for (GDD §5.3: skills and
## physical fit, never a species lock, LORE-P12), its own crew's first. A resident's priority for an activity is its
## crew's; the work board sorts its candidates by it (work_board.gd THE CLAIM).
##
## PRESETS (UX-007): Normal, Harvest week and Winter stores are whole priority tables, previewed as the changes they make
## before they are applied. Applying one replaces every crew's priorities; editing a crew afterwards is a deviation from
## it (`preset` says CUSTOM).
##
## A MEMBER'S STATUS: RESTING (the night routine has it in bed, decision 0210), ABSENT (in the water, or held by the
## water's rescue), OCCUPIED (under an order, a task or a job), else AVAILABLE.

const WorkIds := preload("res://demo/work/work_ids.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const CREW_FIELD: int = 0
const CREW_WOODS: int = 1
const CREW_DIGGERS: int = 2
const CREW_HAULERS: int = 3
const CREW_BUILDERS: int = 4
const CREW_COUNT: int = 5
const CREW_NAMES: Array[String] = ["Field", "Woods", "Diggers", "Haulers", "Builders"]
const PREFERRED: Array[int] = [WorkIds.ACT_FARM, WorkIds.ACT_WOODS, WorkIds.ACT_DIG, WorkIds.ACT_HAUL, WorkIds.ACT_BUILD]
## Each crew's two fallbacks, in order.
const FALLBACKS: Array[Array] = [
	[WorkIds.ACT_HAUL, WorkIds.ACT_WOODS],
	[WorkIds.ACT_HAUL, WorkIds.ACT_BUILD],
	[WorkIds.ACT_BUILD, WorkIds.ACT_HAUL],
	[WorkIds.ACT_FARM, WorkIds.ACT_WOODS],
	[WorkIds.ACT_HAUL, WorkIds.ACT_WOODS],
]
## The crew each of the demo's residents starts on (its trade); anyone else starts a Hauler.
const START_CREW: Dictionary = {
	&"mouse_fieldworker": CREW_FIELD, &"squirrel_gatherer": CREW_FIELD,
	&"squirrel_forester": CREW_WOODS,
	&"mole_digger": CREW_DIGGERS, &"badger_quarryman": CREW_DIGGERS,
	&"mouse_keeper": CREW_HAULERS, &"otter_fisher": CREW_HAULERS,
	&"beaver_bridgewright": CREW_BUILDERS, &"otter_boatwright": CREW_BUILDERS,
}

const STATUS_AVAILABLE: int = 0
const STATUS_OCCUPIED: int = 1
const STATUS_RESTING: int = 2
const STATUS_ABSENT: int = 3
const STATUS_NAMES: Array[String] = ["available", "occupied", "resting", "absent"]

const PRESET_NORMAL: int = 0
const PRESET_HARVEST: int = 1
const PRESET_WINTER: int = 2
const PRESET_COUNT: int = 3
## Edited by hand since the last preset.
const PRESET_CUSTOM: int = 3
const PRESET_NAMES: Array[String] = ["Normal", "Harvest week", "Winter stores", "Custom"]
const PRESET_NOTES: Array[String] = [
	"each crew its own work first, then its fallbacks, then anything",
	"every crew lends a hand on the farm and its hauling",
	"every crew lends a hand in the woods and its hauling; farm work waits",
]
## Harvest week and Winter stores raise these activities to at least HIGH for every crew (and lower these to LOW).
const PRESET_RAISE: Array[Array] = [[], [WorkIds.ACT_FARM, WorkIds.ACT_HAUL], [WorkIds.ACT_WOODS, WorkIds.ACT_HAUL]]
const PRESET_LOWER: Array[Array] = [[], [], [WorkIds.ACT_FARM]]

## Each resident's crew (CREW_*), by actor index.
var crew_of: PackedInt32Array = PackedInt32Array()
## Each crew's priority for each activity (crew * ACT_COUNT + activity).
var priority: PackedInt32Array = PackedInt32Array()
## The preset last applied (PRESET_*), or PRESET_CUSTOM after an edit.
var preset: int = PRESET_NORMAL
## Bumped whenever membership or a priority changes (readers rebuild their words only then).
var revision: int = 0
var _scratch: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""The Normal priorities, nobody on a crew yet."""
	priority.resize(CREW_COUNT * WorkIds.ACT_COUNT)
	table_into(PRESET_NORMAL, priority)


func setup(keys: Array[StringName]) -> void:
	"""One resident per key, each on its trade's crew (START_CREW; anyone else a Hauler)."""
	crew_of.resize(keys.size())
	for who: int in keys.size():
		crew_of[who] = int(START_CREW.get(keys[who], CREW_HAULERS))
	revision += 1


static func is_crew(crew: int) -> bool:
	"""Whether `crew` names one of the five."""
	return crew >= 0 and crew < CREW_COUNT


func set_crew(who: int, crew: int) -> bool:
	"""Put resident `who` on `crew`. False for an unknown resident or crew."""
	if who < 0 or who >= crew_of.size() or not is_crew(crew):
		return false
	if crew_of[who] != crew:
		crew_of[who] = crew
		revision += 1
	return true


func step_crew(who: int, by: int) -> bool:
	"""Move resident `who` to the next crew (`by` 1) or the one before (-1), round the five."""
	if who < 0 or who >= crew_of.size():
		return false
	return set_crew(who, posmod(crew_of[who] + by, CREW_COUNT))


func members_into(crew: int, out: PackedInt32Array) -> int:
	"""Crew `crew`'s members in actor order into `out` (cleared first); how many."""
	out.clear()
	for who: int in crew_of.size():
		if crew_of[who] == crew:
			out.append(who)
	return out.size()


func priority_of(who: int, activity: int) -> int:
	"""Resident `who`'s priority for `activity`: its crew's (PRIORITY_FORBIDDEN for an unknown resident)."""
	if who < 0 or who >= crew_of.size() or not WorkIds.is_activity(activity):
		return WorkIds.PRIORITY_FORBIDDEN
	return priority[crew_of[who] * WorkIds.ACT_COUNT + activity]


func crew_priority(crew: int, activity: int) -> int:
	"""Crew `crew`'s priority for `activity`."""
	return priority[crew * WorkIds.ACT_COUNT + activity]


func set_priority(crew: int, activity: int, value: int) -> bool:
	"""Set one crew's priority for one activity (REQ-SET-026's 0-4): a deviation from the preset."""
	if not is_crew(crew) or not WorkIds.is_activity(activity) or not WorkIds.is_priority(value):
		return false
	priority[crew * WorkIds.ACT_COUNT + activity] = value
	preset = PRESET_CUSTOM
	revision += 1
	return true


static func table_into(which: int, out: PackedInt32Array) -> void:
	"""Preset `which`'s whole priority table into `out` (sized CREW_COUNT x ACT_COUNT)."""
	out.resize(CREW_COUNT * WorkIds.ACT_COUNT)
	for crew: int in CREW_COUNT:
		for activity: int in WorkIds.ACT_COUNT:
			out[crew * WorkIds.ACT_COUNT + activity] = _normal(crew, activity)
		for activity: int in PRESET_RAISE[which]:
			var k: int = crew * WorkIds.ACT_COUNT + activity
			out[k] = mini(out[k], WorkIds.PRIORITY_HIGH)
		for activity: int in PRESET_LOWER[which]:
			if PREFERRED[crew] != activity:
				out[crew * WorkIds.ACT_COUNT + activity] = WorkIds.PRIORITY_LOW


static func _normal(crew: int, activity: int) -> int:
	"""The Normal table: the preferred activity highest, the fallbacks high and normal, anything else low."""
	if PREFERRED[crew] == activity:
		return WorkIds.PRIORITY_HIGHEST
	var fallback: int = FALLBACKS[crew].find(activity)
	if fallback >= 0:
		return WorkIds.PRIORITY_HIGH + fallback
	return WorkIds.PRIORITY_LOW


func apply_preset(which: int) -> bool:
	"""Replace every crew's priorities with preset `which`'s. False for an unknown preset."""
	if which < 0 or which >= PRESET_COUNT:
		return false
	table_into(which, priority)
	preset = which
	revision += 1
	return true


func preview_preset(which: int) -> PackedStringArray:
	"""What applying preset `which` would change, a line a crew: "Woods: Farm 4 → 2, Hauling 2 → 2" (only the activities
	that change); empty when it changes nothing."""
	var lines := PackedStringArray()
	if which < 0 or which >= PRESET_COUNT:
		return lines
	table_into(which, _scratch)
	for crew: int in CREW_COUNT:
		var parts := PackedStringArray()
		for activity: int in WorkIds.ACT_COUNT:
			var k: int = crew * WorkIds.ACT_COUNT + activity
			if _scratch[k] != priority[k]:
				parts.append("%s %s → %s" % [WorkIds.ACT_NAMES[activity], WorkIds.PRIORITY_NAMES[priority[k]].to_lower(),
					WorkIds.PRIORITY_NAMES[_scratch[k]].to_lower()])
		if not parts.is_empty():
			lines.append("%s: %s" % [CREW_NAMES[crew], ", ".join(parts)])
	return lines


static func status_of(brain: BrainScript, has_job: bool) -> int:
	"""A member's status (see A MEMBER'S STATUS); `has_job`: it holds a job on some board."""
	if brain.resting or brain.lying:
		return STATUS_RESTING
	if brain.water_hold or brain.in_water:
		return STATUS_ABSENT
	if brain.order != BrainScript.ORDER_NONE or has_job:
		return STATUS_OCCUPIED
	return STATUS_AVAILABLE


func describe(crew: int) -> String:
	"""A crew's activities in words: "prefers Farm; then Hauling, Woods"."""
	var fallbacks := PackedStringArray()
	for activity: int in FALLBACKS[crew]:
		fallbacks.append(WorkIds.ACT_NAMES[activity])
	return "prefers %s; then %s" % [WorkIds.ACT_NAMES[PREFERRED[crew]], ", ".join(fallbacks)]
