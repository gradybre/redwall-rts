extends RefCounted
## HOW EACH §5.10 EVENT LOOKS, on top of the hour's condition. Decision 1632 (feature #34, livelier weather). Pure,
## static, presentation only: weather_view.gd eases toward these as it does the condition's own look (demo values).
##
## The GDD's seven events (§5.10) and what the village shows of each, beyond what the hour already draws:
##   | Event        | Look                                                                                       |
##   |--------------|--------------------------------------------------------------------------------------------|
##   | Heavy rain / storm | the rain driven slant by the wind (RAIN_SLANT) and the lightning (weather_fx.gd)     |
##   | Drought      | the grass parched straw-brown (the ground's `dryness`), a heat haze                        |
##   | Blight       | nothing more: the farm draws its blighted beds (demo/farm/)                                |
##   | Early frost  | a rime that lies all the event's days, not only in its frost nights (FROST_FLOOR)          |
##   | Hard freeze  | a heavy hoar frost over everything (FROST_FLOOR), a freezing mist, the sun cold and low    |
##   | Calm days    | nothing: "no modifier; explicitly announced safe interval"                                  |
##   | Ideal spell  | a little brighter                                                                          |
## Snow already lying is never thinned by a frost floor: the view keeps whichever cover is greater.

const WeatherCore := preload("res://scripts/core/weather.gd")

## Per event id (weather.gd EVENT_* order: blight, calm days, drought, early frost, hard freeze, heavy rain, ideal
## spell): the frost that lies whatever the hour (0..1, frosty), the grass's dryness (0..1), the haze added, the sun's
## share (a multiplier on the condition's), and the rain's slant (radians from the vertical).
const FROST_FLOOR: PackedFloat32Array = [0.0, 0.0, 0.0, 0.35, 0.9, 0.0, 0.0]
const DRYNESS: PackedFloat32Array = [0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
const HAZE_ADD: PackedFloat32Array = [0.0, 0.0, 0.0016, 0.0, 0.0036, 0.0, 0.0]
const SUN_SHARE: PackedFloat32Array = [1.0, 1.0, 1.06, 1.0, 0.82, 1.0, 1.08]
const RAIN_SLANT: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.38, 0.0]


static func _valid(event: int) -> bool:
	"""Whether `event` is one of §5.10's compiled ids (EVENT_NONE and anything else: no event)."""
	return event >= 0 and event < WeatherCore.EVENT_COUNT


static func frost_floor(event: int) -> float:
	"""The frost that lies through `event`'s days, 0..1."""
	return FROST_FLOOR[event] if _valid(event) else 0.0


static func dryness(event: int) -> float:
	"""How parched the grass is in `event`, 0..1."""
	return DRYNESS[event] if _valid(event) else 0.0


static func haze_add(event: int) -> float:
	"""The haze `event` adds (a drought's heat, a freeze's mist; never negative)."""
	return HAZE_ADD[event] if _valid(event) else 0.0


static func sun_share(event: int) -> float:
	"""`event`'s multiplier on the sun's share."""
	return SUN_SHARE[event] if _valid(event) else 1.0


static func rain_slant(event: int) -> float:
	"""How far from the vertical `event`'s rain is driven, radians."""
	return RAIN_SLANT[event] if _valid(event) else 0.0
