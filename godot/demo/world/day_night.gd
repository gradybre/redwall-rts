extends Node
## THE DAY AND THE NIGHT: the world's light follows the demo calendar. Decision 0541. Presentation only: it reads the
## calendar and writes the sun, the sky and the haze; nothing in the simulation or the village's timing reads it (the
## night routine, the hearths, the songs and the kitchen keep their own hours, decisions 0210 / 0421 / 0442).
##
## WHAT IT WRITES, from daylight.gd's sample of the curves (daylight_curves.gd) at the calendar's moment:
##   * THE ONE LIGHT (world_look.gd's "Sun"): the sun on its arc by day, the moon by night -- its direction, colour and
##     energy; its shadow's opacity, and the shadow pass switched OFF while there is none (the night saves it);
##   * THE SURFACE'S ENVIRONMENT (world_look.gd's "Environment"): the sky's colours and energy, the ambient's colour,
##     energy and sky share, the haze's colour and density, the saturation and exposure, and a soft glow while the
##     lamps are lit;
##   * THE NIGHT LIGHTS' level (night_lights.gd), the falls' and the chimney smoke's tint (they are unshaded; the smoke
##     through `set_smoke_tinter`, per chimney), and the HUD date trigger's icon -- a sun by day, a moon by night, in
##     place of its calendar glyph while the demo runs (`set_date_button`; the trigger still opens the calendar).
## THE WEATHER multiplies the hour (weather_view.gd THE WEATHER ON TOP OF THE HOUR): the light's energy by its
## `sun_share`, the haze by its `fog_add`, and the sky darkened and greyed by its `gloom`. This node is then the one
## writer of the sun's energy and the haze (`drives_light` is turned off there).
##
## THE UNDERGROUND IS NOT TOUCHED (decision 0206/0207). The U view wears its own Environment on the camera
## (tunnel_view.gd), which this never writes; the light lights only the surface layers (tunnel_view.gd `set_world`
## gives it that cull mask), and so do the night lights. Switching U at night changes nothing here.
##
## HOW OFTEN. A write moves the sky, and the sky's radiance is then redrawn, so the light is written only when the
## calendar has moved APPLY_TICKS (about a game minute: 0.4 s at 1x, 0.1 s at 4x -- a twilight is a hundred and twenty
## steps), when the weather's eased look has moved WEATHER_STEP (at most every WEATHER_EVERY_S), when Brighter nights is turned on or off, or when the
## season changes. Paused, nothing is written. Each write fills one reused Sample: nothing is allocated.
##
## THE PREWARM (demo_prewarm.gd, decision 0205): the boot opens at 06:00, sunrise, where the shadow is off, so
## `begin_day_prewarm` first holds noon for every frame step before the night's -- the shadowed pipelines drawn, as the
## world drew them before this cycle -- then `begin_prewarm` holds the world at midnight, every night light lit, the
## glow on and the frost and snow overlay worn (weather_view.gd `begin_prewarm`: drawn, with no cover), for the boot's
## frame step, so the night's pipelines -- the shadowless sun, the glow, the lit pool --
## are compiled behind the opening pause; `end_prewarm` gives the calendar's own hour back. The first dusk then
## compiles nothing.

const Daylight := preload("res://demo/world/daylight.gd")
const Curves := preload("res://demo/world/daylight_curves.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const NightLightsScript := preload("res://demo/world/night_lights.gd")
const Access := preload("res://demo/access/demo_access.gd")

## Write again once the calendar has moved this many ticks (12.5 ticks a game minute).
const APPLY_TICKS: int = 13
## ... or the weather's eased look has moved this much (the share and the gloom; the haze WEATHER_STEP_FOG), but at
## most once in WEATHER_EVERY_S real seconds, so a weather's ease (3 demo seconds) is a dozen writes, not a write a frame.
const WEATHER_STEP: float = 0.02
const WEATHER_STEP_FOG: float = 0.0002
const WEATHER_EVERY_S: float = 0.25
## Below this opacity the sun's shadow pass is off.
const SHADOW_OFF: float = 0.02
## The prewarm's moments (minutes after midnight, in the calendar's own season): noon for the boot's first frames, the
## sun's shadow on; midnight for the night's.
const DAY_PREWARM_MINUTE: float = 720.0
const PREWARM_MINUTE: float = 0.0
## The date trigger's two glyphs, drawn like the HUD's own line icons (ui/icons/*.svg: 24 px, a 2 px cream stroke).
const SUN_SVG: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#F5F0DF\" stroke-width=\"2\" stroke-linecap=\"round\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4\"/></svg>"
const MOON_SVG: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#F5F0DF\" stroke-width=\"2\" stroke-linejoin=\"round\"><path d=\"M15.5 4.8A8 8 0 1 0 19.3 15.4A6.3 6.3 0 0 1 15.5 4.8Z\"/></svg>"

static var _sun_icon: Texture2D = null
static var _moon_icon: Texture2D = null

## The moment's light, reused by every write.
var sample: Daylight.Sample = Daylight.Sample.new()
## Writes so far (checks and measurement).
var applies: int = 0

var _calendar: CalendarScript = null
var _weather: WeatherViewScript = null
var _lights: NightLightsScript = null
var _sun: DirectionalLight3D = null
var _environment: Environment = null
var _sky: ProceduralSkyMaterial = null
var _date: Button = null
## `(tint: Color) -> void`: tints the chimneys' smoke (fixture_view.gd `set_smoke_tint`).
var _smoke_tinter: Callable = Callable()
## What the last write was made from (see HOW OFTEN).
var _applied_tick: int = -1
var _applied_season: int = -1
var _applied_bright: bool = false
var _applied_share: float = -1.0
var _applied_fog: float = -1.0
var _applied_gloom: float = -1.0
## Real seconds since the last write (see WEATHER_EVERY_S).
var _since_s: float = 0.0
## A held moment (the prewarm, and checks): minutes after midnight, or < 0 for the calendar's own.
var _held_minute: float = -1.0


func configure(calendar: CalendarScript, world: Node, weather: WeatherViewScript = null,
		lights: NightLightsScript = null) -> void:
	"""Light `world`'s sun and environment by `calendar`, with `weather` on top (it stops writing the light) and
	`lights` lit by the lamps' hour; written at once."""
	name = "DayNight"
	_calendar = calendar
	_weather = weather
	_lights = lights
	_sun = world.find_child("Sun", true, false) as DirectionalLight3D if world != null else null
	var holder := world.find_child("Environment", true, false) as WorldEnvironment if world != null else null
	_environment = holder.environment if holder != null else null
	_sky = _environment.sky.sky_material as ProceduralSkyMaterial if _environment != null and _environment.sky != null else null
	if _environment != null:
		_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		_environment.glow_hdr_threshold = 1.0
	if _weather != null:
		_weather.drives_light = false
	apply()


func set_smoke_tinter(tinter: Callable) -> void:
	"""Who tints the chimneys' smoke (`tinter(tint: Color)`), tinted at once."""
	_smoke_tinter = tinter
	_write_tints()


func set_date_button(button: Button) -> void:
	"""The HUD's date trigger, which wears a sun by day and a moon by night (shown at once)."""
	_date = button
	_show_icon()


func _process(delta: float) -> void:
	"""Write the light when the calendar, the weather or the setting has moved enough (see HOW OFTEN)."""
	update(delta)


func update(elapsed_s: float = WEATHER_EVERY_S) -> bool:
	"""Write the light if it is due (see HOW OFTEN), `elapsed_s` real seconds after the last call; true when it wrote."""
	if _calendar == null:
		return false
	_since_s += elapsed_s
	var tick := _calendar.tick
	var bright := Access.is_on(Access.SET_BRIGHT_NIGHTS)
	var due := absi(tick - _applied_tick) >= APPLY_TICKS or bright != _applied_bright \
		or Daylight.season_of_tick(tick) != _applied_season or _weather_moved()
	if due:
		apply()
	return due


func _weather_moved() -> bool:
	"""Whether the weather's eased look has moved WEATHER_STEP since the last write."""
	if _weather == null or _since_s < WEATHER_EVERY_S:
		return false
	return absf(_weather.sun_share() - _applied_share) >= WEATHER_STEP \
		or absf(_weather.fog_add() - _applied_fog) >= WEATHER_STEP_FOG \
		or absf(_weather.gloom() - _applied_gloom) >= WEATHER_STEP


func apply() -> void:
	"""Sample the moment -- the calendar's, or the held one -- and write it (see WHAT IT WRITES)."""
	var tick := _calendar.tick if _calendar != null else 0
	var minute := _held_minute if _held_minute >= 0.0 else Daylight.minute_of_tick(tick)
	_since_s = 0.0
	_applied_tick = tick
	_applied_season = Daylight.season_of_tick(tick)
	_applied_bright = Access.is_on(Access.SET_BRIGHT_NIGHTS)
	_applied_share = _weather.sun_share() if _weather != null else 1.0
	_applied_fog = _weather.fog_add() if _weather != null else 0.0
	_applied_gloom = _weather.gloom() if _weather != null else 0.0
	Daylight.sample_into(minute, _applied_season, _applied_bright, sample)
	Daylight.gloom_into(sample, _applied_gloom)
	_write_light()
	_write_environment()
	_write_tints()
	if _lights != null:
		_lights.set_level(sample.lamps)
	_show_icon()
	applies += 1


func _write_light() -> void:
	"""The one light: direction, colour, energy (times the weather's share) and shadow."""
	if _sun == null:
		return
	_sun.transform = Transform3D(Basis.looking_at(-sample.light_toward, Vector3.UP), Vector3.ZERO)
	_sun.light_color = sample.light_colour
	_sun.light_energy = sample.light_energy * _applied_share
	_sun.shadow_opacity = sample.shadow
	_sun.shadow_enabled = sample.shadow >= SHADOW_OFF


func _write_environment() -> void:
	"""The sky, the ambient, the haze (plus the weather's), the adjustments and the lamps' glow."""
	if _environment == null:
		return
	if _sky != null:
		_sky.sky_top_color = sample.sky_top
		_sky.sky_horizon_color = sample.sky_horizon
		_sky.ground_horizon_color = sample.ground_horizon
		_sky.ground_bottom_color = sample.ground_bottom
		_sky.sky_energy_multiplier = sample.sky_energy
	_environment.ambient_light_color = sample.ambient_colour
	_environment.ambient_light_energy = sample.ambient_energy
	_environment.ambient_light_sky_contribution = sample.sky_share
	_environment.fog_light_color = sample.fog_colour
	_environment.fog_density = sample.fog_density + _applied_fog
	_environment.adjustment_saturation = sample.saturation
	_environment.tonemap_exposure = sample.exposure
	_environment.glow_enabled = sample.lamps >= Curves.GLOW_FROM
	_environment.glow_intensity = Curves.GLOW_INTENSITY * sample.lamps


func _write_tints() -> void:
	"""The unshaded things that stand in the world's light: the falls and the chimney smoke."""
	if _weather != null:
		_weather.set_unlit_tint(sample.unlit_tint)
	if _smoke_tinter.is_valid():
		_smoke_tinter.call(sample.unlit_tint)


func _show_icon() -> void:
	"""The date trigger's sun or moon, set only when it changes."""
	if _date == null or not is_instance_valid(_date):
		return
	var wanted: Texture2D = day_icon() if is_daylight() else night_icon()
	if _date.icon != wanted:
		_date.icon = wanted


func is_daylight() -> bool:
	"""Whether the moment reads as day (the sun is the light, the lamps mostly out): the date trigger's sun."""
	return sample.sun_weight >= 0.5 and sample.lamps <= 0.5


static func day_icon() -> Texture2D:
	"""The sun glyph (made once)."""
	if _sun_icon == null:
		_sun_icon = _glyph(SUN_SVG)
	return _sun_icon


static func night_icon() -> Texture2D:
	"""The moon glyph (made once)."""
	if _moon_icon == null:
		_moon_icon = _glyph(MOON_SVG)
	return _moon_icon


static func _glyph(svg: String) -> Texture2D:
	"""A 24 px line glyph from SVG text (Godot's own SVG rasteriser, as the HUD's icons are imported)."""
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		return null
	return ImageTexture.create_from_image(image)


# --- holding a moment ----------------------------------------------------------------------------------------

func hold_at(minute: float) -> void:
	"""Light the world at `minute` after midnight, whatever the calendar says, until `release` (the prewarm, checks)."""
	_held_minute = maxf(minute, 0.0)
	apply()


func release() -> void:
	"""Back to the calendar's own moment, written at once."""
	_held_minute = -1.0
	apply()


func begin_day_prewarm() -> void:
	"""The boot's frames before the night's (see THE PREWARM): held at noon, the sun's shadow pass on, so every frame step
	before the night's -- the U view, the canopy, the frost overlay -- draws the shadowed pipelines the morning will use.
	The night step's end gives the calendar's hour back."""
	hold_at(DAY_PREWARM_MINUTE)


func begin_prewarm() -> void:
	"""The boot prewarm's night frames (see THE PREWARM): midnight, every night light lit, the glow on."""
	hold_at(PREWARM_MINUTE)
	if _lights != null:
		_lights.begin_prewarm()
	if _weather != null:
		_weather.begin_prewarm()


func end_prewarm() -> void:
	"""The calendar's own hour back (and the frost overlay to what the weather says)."""
	if _weather != null:
		_weather.end_prewarm()
	release()


func sun() -> DirectionalLight3D:
	"""The light this writes (checks)."""
	return _sun


func environment() -> Environment:
	"""The surface's environment this writes (checks)."""
	return _environment
