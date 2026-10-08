extends RefCounted
## THE FEASTS' SETTLEMENT BUFFS (decision 1701; GDD §5.7's last column, REQ-SET-104/105): one row per theme, each
## lasting 48 game hours from the supper's end, granted once -- a second feast of the same theme while its buff lasts
## neither stacks nor extends it (REQ-SET-105). The regatta's Shared Warmth (regatta_menu.gd) is the same Hearth buff:
## while it lasts a called Hearth feast does not stack on it, and its readers below count it.
##
## WHAT READS THEM (the demo models no mood, purpose or social needs and no arrivals -- meal_rules.gd):
##   * Shared Warmth's cold exposure -25%: `cold_permille`, set on the winter's cold (cold_exposure.gd `gain_permille`)
##     by the feasts' node each frame -- the packet's pitfall, wired at last;
##   * Abundant Tables' work +5%: `work_permille`, a factor on the village's work pace (work_pace.gd `add_factor`);
##   * Shared Warmth's mood +400, Abundant Tables' purpose +20%, Rooted Community's social decay -20% and its two extra
##     newcomers: shown as the buff's words, consumed by nothing in the demo (as decision 0682's mood readout).
## §5.7's caps (work buffs +10%, cold-exposure reductions 40%) are never reached by one buff of each kind.

const Rules := preload("res://demo/feast/feast_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const RegattaMenuScript := preload("res://demo/regatta/regatta_menu.gd")

const NONE: int = -1

## Per theme: the tick its buff lasts until (NONE: never granted), and how many times it was granted.
var until: PackedInt64Array = PackedInt64Array([NONE, NONE, NONE])
var granted: PackedInt32Array = PackedInt32Array([0, 0, 0])
## The calendar tick the readers judge by (`work_permille` is asked per resident with no tick); the node sets it.
var now_tick: int = 0
## The regatta's menu, whose Shared Warmth is the Hearth's too (null: none).
var regatta_menu: RegattaMenuScript = null
var revision: int = 0


func active(theme: int, now: int) -> bool:
	"""Whether the theme's buff lasts at `now` (the Hearth's: the regatta's Shared Warmth too)."""
	if not Rules.valid_theme(theme):
		return false
	var own: bool = until[theme] != NONE and now < until[theme]
	return own or (theme == Rules.HEARTH and regatta_menu != null and regatta_menu.warmth_active(now))


func grant(theme: int, now: int) -> String:
	"""REQ-SET-104/105: the theme's buff for 48 h from `now`, unless it already lasts (not stacked, not extended). The
	chronicle's words."""
	if not Rules.valid_theme(theme):
		return ""
	if active(theme, now):
		return "%s already lasts (not stacked or extended)" % Rules.BUFF_NAMES[theme]
	until[theme] = Rules.buff_until(now)
	granted[theme] += 1
	revision += 1
	return "%s for %d h: %s" % [Rules.BUFF_NAMES[theme], Rules.BUFF_HOURS, Rules.BUFF_WORDS[theme]]


func hours_left(theme: int, now: int) -> int:
	"""Whole game hours of the theme's own buff left (0: none; the regatta's warmth says its own)."""
	if not Rules.valid_theme(theme) or until[theme] == NONE or now >= until[theme]:
		return 0
	@warning_ignore("integer_division") var hours: int = (until[theme] - now) / SimClock.TICKS_PER_HOUR
	return hours


func cold_permille(now: int) -> int:
	"""Cold exposure gained, per mille: Shared Warmth's 750 while it lasts (a called feast's or the regatta's)."""
	return Rules.WARMTH_COLD_PERMILLE if active(Rules.HEARTH, now) else Rules.FULL_PERMILLE


func work_permille(_who: int) -> int:
	"""The work pace's factor for any resident: Abundant Tables' 1050 while it lasts at `now_tick`, else 1000."""
	return Rules.TABLES_WORK_PERMILLE if active(Rules.HARVEST, now_tick) else Rules.FULL_PERMILLE


func status_words(now: int) -> String:
	"""'Shared Warmth 31 h · Abundant Tables 4 h' -- the called feasts' buffs lasting now ("" none)."""
	var parts := PackedStringArray()
	for theme: int in Rules.THEME_COUNT:
		if until[theme] != NONE and now < until[theme]:
			parts.append("%s %d h" % [Rules.BUFF_NAMES[theme], hours_left(theme, now)])
	return " · ".join(parts)
