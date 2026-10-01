extends RefCounted
## The demo farm's weather: the settlement's own weather, plus two demo threats. Decision 0196.
##
## THE REAL WEATHER. The farm owns a real `crop_weather.gd` stage (farm_sim.gd), and its daily leg
## runs the real `weather.gd` store: §5.10's season baselines (spring 12 °C with +1200 rain against
## 600 evaporation, so +600 moisture a day; summer 22 °C and -600; autumn 10 °C and +100; winter
## -5 °C and -600), the forced first-spring Ideal spell on day 6 and one weighted event draw per
## later season from a seeded WEATHER stream, with its three-day forecast. Every bed's daily
## moisture and every hour's base temperature come from there, unchanged.
##
## THE DEMO OVERLAY, in this one module. §5.10's frost arrives only as autumn's Early frost (day 10)
## and winter; its blight only as a summer/autumn event, weather-wide. A demo that opens in spring
## would show neither for half an hour. So, as DEMO VALUES:
##   * FROST NIGHTS: on the season days in FROST_NIGHT_MASK the hours 02:00-05:59 fall to
##     FROST_NIGHT_TENTHS (-3 °C, the figure §5.10 gives Early frost), unless the real day is
##     already colder. Announced ALERT_HOUR the day before. A covered bed is COVER_WARMTH_TENTHS
##     warmer for the night and a raised bed RAISED_WARMTH_TENTHS warmer at all times.
##   * BLIGHT OUTBREAKS: on the season days in BLIGHT_MASK one growing bed catches blight, which
##     then spreads to its neighbours (farm_sim.gd). The damage is §5.6's own `apply_blight_day()`.
## Neither touches `weather.gd`; both are read from here by farm_sim.gd and the alerts.

## Frost nights and blight outbreaks, as a bit per season-local day (bit d = day d), by season
## (spring, summer, autumn, winter). Winter needs no frost night: its baseline is already -5 °C.
## THE FIRST SPRING IS SPACED OUT (playtest 2026-09-29: by spring 6 it had waterlogged beds, blight
## and a frost warning at once). The opening radish first waterlogs at the midnight opening spring 8
## (the Ideal spell of days 6-8 against farm_sim NATURAL_DRAIN_PER_DAY); spring's one frost night is
## the night into spring 11, warned at noon on spring 10; its outbreak opens spring 12 -- one threat
## every two days (test_demo_farm.gd walks it). Was spring 4 and 9 frost, spring 7 blight.
const FROST_NIGHT_MASK: Array[int] = [1 << 11, 0, (1 << 3) | (1 << 8), 0]
const BLIGHT_MASK: Array[int] = [1 << 12, (1 << 4) | (1 << 10), 1 << 6, 0]
## The frost-night temperature, in tenths (§5.10's Early frost figure), and its hours.
const FROST_NIGHT_TENTHS: int = -30
const FROST_FIRST_HOUR: int = 2
const FROST_LAST_HOUR: int = 5
## The hour of the day before a frost night at which it is announced.
const ALERT_HOUR: int = 12
## How much warmer a covered (for the night) and a raised (always) bed is, in tenths.
const COVER_WARMTH_TENTHS: int = 40
const RAISED_WARMTH_TENTHS: int = 30
const SEASON_COUNT: int = 4
const DAYS_PER_SEASON: int = 12


static func _day_bit(mask_by_season: Array[int], season: int, season_day: int) -> bool:
	"""Whether a season day's bit is set in a per-season mask."""
	if season < 0 or season >= SEASON_COUNT or season_day < 1 or season_day > DAYS_PER_SEASON:
		return false
	return (mask_by_season[season] & (1 << season_day)) != 0


static func is_frost_night(season: int, season_day: int) -> bool:
	"""Whether the early hours of this season day are a demo frost night."""
	return _day_bit(FROST_NIGHT_MASK, season, season_day)


static func is_blight_outbreak(season: int, season_day: int) -> bool:
	"""Whether a demo blight outbreak starts on this season day."""
	return _day_bit(BLIGHT_MASK, season, season_day)


static func is_frost_hour(season: int, season_day: int, hour: int) -> bool:
	"""Whether an hour of this season day is inside a frost night."""
	return is_frost_night(season, season_day) and hour >= FROST_FIRST_HOUR and hour <= FROST_LAST_HOUR


static func air_tenths(weather_tenths: int, frost_hour: bool) -> int:
	"""The hour's air temperature: the real weather's, pulled down to the frost-night figure."""
	if frost_hour:
		return mini(weather_tenths, FROST_NIGHT_TENTHS)
	return weather_tenths


static func bed_tenths(air: int, covered: bool, raised: bool) -> int:
	"""A bed's temperature for the hour: the air's, plus its cover and its raising."""
	var tenths: int = air
	if covered:
		tenths += COVER_WARMTH_TENTHS
	if raised:
		tenths += RAISED_WARMTH_TENTHS
	return tenths


static func next_day(season: int, season_day: int) -> Vector2i:
	"""The (season, season_day) after this one."""
	if season_day < DAYS_PER_SEASON:
		return Vector2i(season, season_day + 1)
	return Vector2i((season + 1) % SEASON_COUNT, 1)


static func frost_tonight(season: int, season_day: int) -> bool:
	"""Whether the coming night (the early hours of tomorrow) is a frost night."""
	var tomorrow: Vector2i = next_day(season, season_day)
	return is_frost_night(tomorrow.x, tomorrow.y)


static func frost_due(season: int, season_day: int, hour: int) -> bool:
	"""Whether a frost is due that straw would still help against: announced (from ALERT_HOUR the day
	before a frost night) or under way (a frost night's early hours, until FROST_LAST_HOUR)."""
	if hour >= ALERT_HOUR and frost_tonight(season, season_day):
		return true
	return is_frost_night(season, season_day) and hour <= FROST_LAST_HOUR
