extends RefCounted
## The pond's ice: how thick it is, and what that allows. Decision 0433 (live demo). Integer authoritative state;
## presentation only (nothing here writes into the settlement simulation).
##
## WHAT THE GDD SAYS, AND WHAT IT DOES NOT. REQ-SET-051: "Where winter ice covers a lake, the system shall permit only
## equipped ice-kit crews or a maintained ice-access station, while river/coast access remains weather-dependent";
## §5.4's ice kit: "Frozen lake; tier 2 clothing required"; §5.10's hard freeze: "lake ice access only". It never says
## WHEN a lake freezes, how thick ice grows or how thick is safe. Those are DEMO values here, in whole micrometres:
##   * each game hour the ice grows ICE_GROWTH_UM_PER_TENTH x (degrees below 0 in tenths) -- at winter's -5.0 °C
##     baseline (§5.10) a millimetre an hour, at a hard freeze's -12.0 °C 2.4 mm -- and above 0 °C it melts
##     ICE_MELT_UM_PER_TENTH x the tenths above, from the one weather's day temperature (`day_temperature_tenths`);
##   * at FROZEN_UM (10 mm) the pond is FROZEN: no boat goes out, no net or trap is set from its bank, nobody swims it;
##   * at SAFE_UM (60 mm) the ice is SAFE to walk out on and fish through with an ice kit -- about two and a half
##     baseline winter days of cold; below it the frozen pond is THIN ice, and nobody is sent onto it.
## The stream never freezes: it flows (REQ-SET-051 leaves river access to the weather).

const FROZEN_UM: int = 10000
const SAFE_UM: int = 60000
const MAX_UM: int = 300000
const ICE_GROWTH_UM_PER_TENTH: int = 20
const ICE_MELT_UM_PER_TENTH: int = 40

const STATE_OPEN: int = 0
const STATE_THIN: int = 1
const STATE_SAFE: int = 2
const STATE_WORDS: Array[String] = ["open water", "thin ice", "safe ice"]

## Ice thickness, micrometres.
var thickness_um: int = 0
## Bumped whenever the state changes (the map layer and the panel redraw then).
var revision: int = 0


func advance_hour(day_tenths: int) -> bool:
	"""One game hour at the day's temperature (tenths of °C): the ice grows below 0, melts above. True when the
	state changed."""
	var before: int = state()
	if day_tenths < 0:
		thickness_um = mini(MAX_UM, thickness_um - day_tenths * ICE_GROWTH_UM_PER_TENTH)
	elif day_tenths > 0:
		thickness_um = maxi(0, thickness_um - day_tenths * ICE_MELT_UM_PER_TENTH)
	if state() != before:
		revision += 1
		return true
	return false


func state() -> int:
	"""STATE_OPEN below FROZEN_UM, STATE_THIN up to SAFE_UM, STATE_SAFE from it."""
	if thickness_um < FROZEN_UM:
		return STATE_OPEN
	return STATE_THIN if thickness_um < SAFE_UM else STATE_SAFE


func frozen() -> bool:
	"""Whether ice covers the pond (thin or safe)."""
	return thickness_um >= FROZEN_UM


func safe() -> bool:
	"""Whether the ice is thick enough to walk out on (SAFE_UM)."""
	return thickness_um >= SAFE_UM


func millimetres() -> int:
	"""The thickness in whole millimetres (floored)."""
	return thickness_um / 1000


static func hours_to_safe(thickness: int, day_tenths: int) -> int:
	"""Game hours the ice needs at `day_tenths` to be SAFE from `thickness` (0 when it is; -1 when it is not freezing)."""
	if thickness >= SAFE_UM:
		return 0
	if day_tenths >= 0:
		return -1
	var per_hour: int = -day_tenths * ICE_GROWTH_UM_PER_TENTH
	return (SAFE_UM - thickness + per_hour - 1) / per_hour


func line() -> String:
	"""The panel's line: "The pond: thin ice, 24 mm (safe from 60 mm)"."""
	match state():
		STATE_OPEN:
			return "The pond: open water" if thickness_um == 0 else "The pond: open water (a skin of ice, %d mm)" % millimetres()
		STATE_THIN:
			return "The pond: thin ice, %d mm — keep off (safe from %d mm)" % [millimetres(), SAFE_UM / 1000]
	return "The pond: safe ice, %d mm — ice fishing only" % millimetres()
