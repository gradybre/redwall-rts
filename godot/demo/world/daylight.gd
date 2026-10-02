extends RefCounted
## THE LIGHTING CYCLE'S SAMPLER: what the light is at a moment of the day, read off the named curves
## (daylight_curves.gd). Decision 0541. Presentation only, and pure: it reads nothing but its arguments and writes
## nothing but the Sample it is given, so a frame's sample allocates nothing.
##
## `sample_into(minute, season, bright, out)` fills `out` for `minute` after midnight (a float: the calendar's tick
## carries the part-minute) in §4.3 season `season`, with BRIGHTER NIGHTS on or off. `minute_of_tick` and
## `season_of_tick` read both off the demo calendar's tick (demo_calendar.gd, the real offset calendar: tick 0 is
## 06:00 of spring day 1).

const Curves := preload("res://demo/world/daylight_curves.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## Which part of the day a moment is in (the HUD's sun or moon, and the checks).
const PHASE_NIGHT: int = 0
const PHASE_DAWN: int = 1
const PHASE_DAY: int = 2
const PHASE_DUSK: int = 3
## Minutes in a calendar tick (1440 / 18000).
const MINUTES_PER_TICK: float = float(Curves.MINUTES_PER_DAY) / float(SimClock.TICKS_PER_DAY)


## One moment's light: every value the cycle writes, and where on the curves it was read.
class Sample:
	var minute: float = 0.0
	var season: int = 0
	var phase: int = PHASE_DAY
	## The keys it lies between and how far (eased) from the first to the second.
	var key_from: int = Curves.KEY_DAY
	var key_to: int = Curves.KEY_DAY
	var weight: float = 0.0
	## The sun's own direction (toward it), and the light's: the sun's turned toward the moon's by 1 - sun_weight.
	var sun_toward: Vector3 = Vector3.UP
	var light_toward: Vector3 = Vector3.UP
	var sun_weight: float = 1.0
	var light_colour: Color = Color.WHITE
	var light_energy: float = 1.0
	var shadow: float = 1.0
	var ambient_colour: Color = Color.WHITE
	var ambient_energy: float = 1.0
	var sky_share: float = 1.0
	var sky_top: Color = Color.WHITE
	var sky_horizon: Color = Color.WHITE
	var ground_horizon: Color = Color.WHITE
	var ground_bottom: Color = Color.WHITE
	var sky_energy: float = 1.0
	var fog_colour: Color = Color.WHITE
	var fog_density: float = 0.0
	var saturation: float = 1.0
	var exposure: float = 1.0
	var lamps: float = 0.0
	var unlit_tint: Color = Color.WHITE


static func minute_of_tick(tick: int) -> float:
	"""Minutes after midnight at a calendar tick (0 <= m < 1440; tick 0 is 06:00)."""
	var of_day: int = posmod(tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_DAY)
	return float(of_day) * MINUTES_PER_TICK


static func season_of_tick(tick: int) -> int:
	"""The §4.3 season (0 spring .. 3 winter) at a calendar tick."""
	@warning_ignore("integer_division")
	var day_zero: int = (tick + SimClock.CALENDAR_OFFSET_TICKS) / SimClock.TICKS_PER_DAY
	@warning_ignore("integer_division")
	return posmod(day_zero, SimClock.DAYS_PER_YEAR) / SimClock.DAYS_PER_SEASON


static func sunrise_of(season: int) -> int:
	"""Sunrise in a season, minutes after midnight (the GDD's daylight start; the middle of the dawn window)."""
	return Curves.SUNRISE_MIN[clampi(season, 0, Curves.SUNRISE_MIN.size() - 1)]


static func sunset_of(season: int) -> int:
	"""Sunset in a season, minutes after midnight (the GDD's daylight end; the start of the dusk window)."""
	return Curves.SUNSET_MIN[clampi(season, 0, Curves.SUNSET_MIN.size() - 1)]


static func dawn_start_of(season: int) -> int:
	"""When dawn begins in a season (minutes)."""
	return sunrise_of(season) - Curves.DAWN_HALF_MIN


static func dusk_end_of(season: int) -> int:
	"""When dusk ends -- full night -- in a season (minutes)."""
	return sunset_of(season) + Curves.DUSK_MIN


static func place_into(minute: float, season: int, out: Sample) -> void:
	"""Where `minute` lies on the keys in `season` (see daylight_curves.gd THE CLOCK): `out`'s phase, keys and eased
	weight."""
	var sunrise := float(sunrise_of(season))
	var sunset := float(sunset_of(season))
	var half := float(Curves.DAWN_HALF_MIN)
	var dusk_half := float(Curves.DUSK_MIN) * 0.5
	out.minute = minute
	out.season = season
	if minute < sunrise - half or minute >= sunset + 2.0 * dusk_half:
		_set_place(out, PHASE_NIGHT, Curves.KEY_NIGHT, Curves.KEY_NIGHT, 0.0)
	elif minute < sunrise:
		_set_place(out, PHASE_DAWN, Curves.KEY_NIGHT, Curves.KEY_DAWN, (minute - sunrise + half) / half)
	elif minute < sunrise + half:
		_set_place(out, PHASE_DAWN, Curves.KEY_DAWN, Curves.KEY_DAY, (minute - sunrise) / half)
	elif minute < sunset:
		_set_place(out, PHASE_DAY, Curves.KEY_DAY, Curves.KEY_DAY, 0.0)
	elif minute < sunset + dusk_half:
		_set_place(out, PHASE_DUSK, Curves.KEY_DAY, Curves.KEY_DUSK, (minute - sunset) / dusk_half)
	else:
		_set_place(out, PHASE_DUSK, Curves.KEY_DUSK, Curves.KEY_NIGHT, (minute - sunset - dusk_half) / dusk_half)


static func _set_place(out: Sample, phase: int, key_from: int, key_to: int, t: float) -> void:
	"""One place on the keys, its weight eased."""
	out.phase = phase
	out.key_from = key_from
	out.key_to = key_to
	out.weight = smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))


static func value(curve: PackedFloat32Array, at: Sample) -> float:
	"""A float curve at a placed sample."""
	return lerpf(curve[at.key_from], curve[at.key_to], at.weight)


static func colour(curve: PackedColorArray, at: Sample) -> Color:
	"""A colour curve at a placed sample."""
	return curve[at.key_from].lerp(curve[at.key_to], at.weight)


static func sun_toward(minute: float, season: int) -> Vector3:
	"""A unit vector toward the sun (see daylight_curves.gd THE SUN AND THE MOON): along its arc from the east at sunrise,
	through due south (+Z) at the middle of the daylight, to the west at sunset, its height SUN_PEAK_DEG at the top and
	never under LIGHT_MIN_DEG; held at either end outside the daylight."""
	var sunrise := float(sunrise_of(season))
	var span := float(sunset_of(season)) - sunrise
	var along := clampf((minute - sunrise) / span, 0.0, 1.0)
	var height := maxf(deg_to_rad(Curves.SUN_PEAK_DEG) * sin(PI * along), deg_to_rad(Curves.LIGHT_MIN_DEG))
	var round_from_east := PI * along
	return Vector3(cos(height) * cos(round_from_east), sin(height), cos(height) * sin(round_from_east))


static func sample_into(minute: float, season: int, bright: bool, out: Sample) -> void:
	"""The light at `minute` in `season` into `out` (see the header); BRIGHTER NIGHTS when `bright`."""
	place_into(minute, season, out)
	_light_into(out)
	_sky_into(out)
	if bright:
		brighten(out)


static func _light_into(out: Sample) -> void:
	"""The one light: its direction (sun toward moon), colour, energy and shadow; the lamps."""
	out.sun_weight = value(Curves.SUN_WEIGHT, out)
	out.sun_toward = sun_toward(out.minute, out.season)
	out.light_toward = Curves.MOON_TOWARD.normalized().slerp(out.sun_toward, out.sun_weight).normalized()
	out.light_colour = colour(Curves.LIGHT_COLOUR, out)
	out.light_energy = value(Curves.LIGHT_ENERGY, out)
	out.shadow = value(Curves.SHADOW, out)
	out.lamps = value(Curves.LAMPS, out)
	out.unlit_tint = colour(Curves.UNLIT_TINT, out)


static func _sky_into(out: Sample) -> void:
	"""The ambient, the sky, the haze and the adjustments."""
	out.ambient_colour = colour(Curves.AMBIENT_COLOUR, out)
	out.ambient_energy = value(Curves.AMBIENT_ENERGY, out)
	out.sky_share = value(Curves.SKY_SHARE, out)
	out.sky_top = colour(Curves.SKY_TOP, out)
	out.sky_horizon = colour(Curves.SKY_HORIZON, out)
	out.ground_horizon = colour(Curves.GROUND_HORIZON, out)
	out.ground_bottom = colour(Curves.GROUND_BOTTOM, out)
	out.sky_energy = value(Curves.SKY_ENERGY, out)
	out.fog_colour = colour(Curves.FOG_COLOUR, out)
	out.fog_density = value(Curves.FOG_DENSITY, out)
	out.saturation = value(Curves.SATURATION, out)
	out.exposure = value(Curves.EXPOSURE, out)


static func brighten(out: Sample) -> void:
	"""BRIGHTER NIGHTS on a sample, in proportion to its night (its lamps' level; daylight_curves.gd BRIGHT_*)."""
	var night := out.lamps
	out.ambient_energy *= lerpf(1.0, Curves.BRIGHT_AMBIENT_GAIN, night)
	out.light_energy *= lerpf(1.0, Curves.BRIGHT_LIGHT_GAIN, night * (1.0 - out.sun_weight))
	out.sky_share = maxf(out.sky_share - Curves.BRIGHT_SKY_SHARE_CUT * night, 0.0)
	out.exposure += Curves.BRIGHT_EXPOSURE_ADD * night


static func gloom_into(out: Sample, gloom: float) -> void:
	"""A gloomy sky on top of the hour (daylight_curves.gd THE WEATHER ON TOP): `gloom` 0 (clear) .. 1 (a storm)."""
	var g := clampf(gloom, 0.0, 1.0)
	if g <= 0.0:
		return
	var darker := 1.0 - Curves.GLOOM_DARKEN * g
	out.ambient_energy *= darker
	out.sky_energy *= darker
	out.saturation *= 1.0 - Curves.GLOOM_DESATURATE * g
	out.shadow *= 1.0 - Curves.GLOOM_SHADOW * g
	var grey := Curves.GLOOM_GREY * g
	out.sky_top = greyed(out.sky_top, grey)
	out.sky_horizon = greyed(out.sky_horizon, grey)
	out.ground_horizon = greyed(out.ground_horizon, grey)
	out.fog_colour = greyed(out.fog_colour, grey)
	out.ambient_colour = greyed(out.ambient_colour, grey)


static func greyed(of: Color, share: float) -> Color:
	"""`of` moved `share` of the way to its own grey (its Rec. 709 luminance)."""
	var luma := 0.2126 * of.r + 0.7152 * of.g + 0.0722 * of.b
	return of.lerp(Color(luma, luma, luma, of.a), share)
