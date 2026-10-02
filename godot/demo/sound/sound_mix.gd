extends RefCounted
## The live demo's mix: its six player-facing buses, their volumes and mutes (the game menu's Settings), the
## mix presets, the pause duck and the underground filter. Decision 0351 (review F43, UX-029, UX-031).
## Presentation only.
##
## BUSES (AudioServer, made once by name, so a Restart finds them standing):
##   Master   all sound                                     (UI §8.1 master_volume, default 80)
##   Ambience wind and rain                                 (ambience_volume, 60)
##   Work     tools, loads and footsteps -- through two     (effects_volume, 75)
##            halves of its own: "Work Surface" and "Work Under" (below ground)
##   Water    the stream, splashes, wading                   (UI §8.1 lists water under ambience: 60)
##   Cues     warnings, completions and clicks               (notice_volume, 70)
##   Songs    the residents' hummed songs (decision 0442):    (a demo bus, 50)
##            diegetic singing, apart from any score
## SONGS ON (`songs_on`, the Settings' "Songs" toggle): whether residents sing at all -- the bubbles, the hum and the
## song news (demo/songs/). Off is not a mute: nothing is sung. The Songs bus's own Mute silences only the hum.
## Volumes are 0..100 % in steps of 5 (UI §8.1's steppers); 0 % or mute silences a bus.
##
## SETTINGS LIVE IN STATIC VARS, as the interface scale's do (demo_ui_scale.gd): they last for the session and
## through Restart demo, and the demo saves nothing to disk (it cannot save yet, demo_menu.gd).
##
## PRESETS (UX-031's mixes): Balanced (the defaults), Quiet focus (alerts forward, world low) and Atmosphere
## (the world forward, alerts back). Moving any volume makes the mix CUSTOM (preset -1).
##
## PAUSED (the clock stopped for any reason: the player, the menu, the stall banner): the Ambience and Water
## buses duck by DUCK_DB; the work voices are stopped by the director (sound_director.gd), not here.
## UNDERGROUND (the U view): a low-pass on Ambience, Water and Work Surface -- the world above heard through
## earth -- and off on Work Under; with the U view off it is the other way round for Work Under alone, so a
## dig below is heard muffled from the surface.

const BUS_MASTER: int = 0
const BUS_AMBIENCE: int = 1
const BUS_WORK: int = 2
const BUS_WATER: int = 3
const BUS_CUES: int = 4
const BUS_SONGS: int = 5
const BUS_COUNT: int = 6
const BUS_NAMES: Array[StringName] = [&"Master", &"Ambience", &"Work", &"Water", &"Cues", &"Songs"]
const BUS_LABELS: Array[String] = ["All sound", "Wind and rain", "Work and steps", "Water", "Alerts and clicks",
	"Songs (humming)"]
const WORK_SURFACE: StringName = &"Work Surface"
const WORK_UNDER: StringName = &"Work Under"
const PERCENT_STEP: int = 5
const PERCENT_MAX: int = 100

const PRESET_CUSTOM: int = -1
const PRESET_BALANCED: int = 0
const PRESET_QUIET: int = 1
const PRESET_ATMOSPHERE: int = 2
const PRESET_NAMES: Array[String] = ["Balanced", "Quiet focus", "Atmosphere"]
const PRESET_TIPS: Array[String] = [
	"The default mix",
	"Alerts and clicks forward; wind, water and work turned well down",
	"Wind, water and work forward; alerts a little back",
]
## Per preset, the six buses' percents in BUS_* order. Balanced is UI §8.1's defaults; the Songs bus is the demo's
## (decision 0442: subtle by default, down in Quiet focus, up in Atmosphere).
const BALANCED_PERCENTS: PackedInt32Array = [80, 60, 75, 60, 70, 50]
const QUIET_PERCENTS: PackedInt32Array = [70, 20, 30, 20, 85, 25]
const ATMOSPHERE_PERCENTS: PackedInt32Array = [80, 85, 70, 85, 55, 65]
const PRESET_PERCENTS: Array[PackedInt32Array] = [BALANCED_PERCENTS, QUIET_PERCENTS, ATMOSPHERE_PERCENTS]

## Paused: the Ambience and Water buses drop this far (dB).
const DUCK_DB: float = -12.0
## The underground filter's cutoff (Hz): the world above heard through earth.
const LOW_PASS_HZ: float = 800.0
## A bus at 0 % sits here (and is muted).
const SILENT_DB: float = -80.0

static var percents: PackedInt32Array = PRESET_PERCENTS[PRESET_BALANCED].duplicate()
static var muted: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0])
static var preset: int = PRESET_BALANCED
## Whether residents sing at all (see SONGS ON).
static var songs_on: bool = true

var paused: bool = false
var underground: bool = false


static func reset() -> void:
	"""Back to Balanced, nothing muted, songs on (tests; a fresh process starts here)."""
	percents = PRESET_PERCENTS[PRESET_BALANCED].duplicate()
	muted = PackedByteArray([0, 0, 0, 0, 0, 0])
	preset = PRESET_BALANCED
	songs_on = true


static func set_percent(bus: int, percent: int) -> bool:
	"""Set a bus's volume, snapped to the 5 % steps within 0..100. The mix becomes custom unless it now matches a
	preset. False for a bus that is not BUS_*."""
	if bus < 0 or bus >= BUS_COUNT:
		return false
	percents[bus] = clampi(snappedi(percent, PERCENT_STEP), 0, PERCENT_MAX)
	preset = matching_preset()
	return true


static func set_muted(bus: int, on: bool) -> bool:
	"""Mute or unmute a bus (its volume is kept). False for a bus that is not BUS_*."""
	if bus < 0 or bus >= BUS_COUNT:
		return false
	muted[bus] = 1 if on else 0
	return true


static func choose_preset(index: int) -> bool:
	"""Apply a preset's volumes (mutes are the player's and stay). False for an unknown preset."""
	if index < 0 or index >= PRESET_PERCENTS.size():
		return false
	percents = PRESET_PERCENTS[index].duplicate()
	preset = index
	return true


static func matching_preset() -> int:
	"""The preset whose volumes the mix has now (PRESET_CUSTOM: none)."""
	for index: int in PRESET_PERCENTS.size():
		if PRESET_PERCENTS[index] == percents:
			return index
	return PRESET_CUSTOM


static func percent_db(percent: int) -> float:
	"""A volume percent as decibels on its bus (0 %: SILENT_DB)."""
	if percent <= 0:
		return SILENT_DB
	return linear_to_db(float(percent) / float(PERCENT_MAX))


static func bus_index(bus_name: StringName) -> int:
	"""The AudioServer index of the bus named `bus_name` (-1: none)."""
	return AudioServer.get_bus_index(bus_name)


static func sub_bus_name(bus: int, below: bool) -> StringName:
	"""The AudioServer bus a voice on BUS_* `bus` plays through: the Work bus's surface or underground half."""
	if bus == BUS_WORK:
		return WORK_UNDER if below else WORK_SURFACE
	return BUS_NAMES[bus]


func ensure_buses() -> void:
	"""Make the buses that are missing (by name: a Restart finds them standing), each with its low-pass."""
	for bus: int in range(1, BUS_COUNT):
		_ensure_bus(BUS_NAMES[bus], BUS_NAMES[BUS_MASTER], bus != BUS_CUES and bus != BUS_WORK)
	_ensure_bus(WORK_SURFACE, BUS_NAMES[BUS_WORK], true)
	_ensure_bus(WORK_UNDER, BUS_NAMES[BUS_WORK], true)


static func _ensure_bus(bus_name: StringName, send: StringName, with_filter: bool) -> void:
	"""One bus sending to `send`; a filtered one (`with_filter`) carries a low-pass (made off) as its first effect."""
	if bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var index: int = bus_index(bus_name)
	AudioServer.set_bus_send(index, send)
	if with_filter and AudioServer.get_bus_effect_count(index) == 0:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = LOW_PASS_HZ
		AudioServer.add_bus_effect(index, low_pass, 0)
		AudioServer.set_bus_effect_enabled(index, 0, false)


func apply() -> void:
	"""Write the volumes, mutes, the pause duck and the underground filter to the buses."""
	for bus: int in BUS_COUNT:
		var index: int = bus_index(BUS_NAMES[bus])
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, bus_db(bus))
		AudioServer.set_bus_mute(index, muted[bus] == 1 or percents[bus] <= 0)
	_filter(BUS_NAMES[BUS_AMBIENCE], underground)
	_filter(BUS_NAMES[BUS_WATER], underground)
	_filter(WORK_SURFACE, underground)
	_filter(WORK_UNDER, not underground)
	_filter(BUS_NAMES[BUS_SONGS], underground)


func bus_db(bus: int) -> float:
	"""BUS_* `bus`'s volume now: its percent, less the pause duck on Ambience and Water."""
	var db: float = percent_db(percents[bus])
	if paused and (bus == BUS_AMBIENCE or bus == BUS_WATER):
		db += DUCK_DB
	return db


static func _filter(bus_name: StringName, on: bool) -> void:
	"""Switch a filtered bus's low-pass."""
	var index: int = bus_index(bus_name)
	if index >= 0 and AudioServer.get_bus_effect_count(index) > 0:
		AudioServer.set_bus_effect_enabled(index, 0, on)


static func filtered(bus_name: StringName) -> bool:
	"""Whether a bus's low-pass is on now (checks)."""
	var index: int = bus_index(bus_name)
	return index >= 0 and AudioServer.get_bus_effect_count(index) > 0 and AudioServer.is_bus_effect_enabled(index, 0)
