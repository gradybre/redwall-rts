extends RefCounted
## The demo's ACCESSIBILITY AND TIME SETTINGS, and the four capability presets. Decision 0471 (review UX-023, P9;
## UI §8.1's settings table). Presentation only.
##
## SETTINGS (SET_*, a byte each), beside the two the demo already keeps -- the interface scale (demo_ui_scale.gd)
## and the sound mix (demo/sound/sound_mix.gd):
##   TOOLTIPS     bigger tooltips (x TOOLTIP_BOOST over the HUD's scale)
##   CONTRAST     high-contrast panels: a flat, opaque, untextured face under every panel's text (UI §8.1
##                `high_contrast`; woodland_styles.gd `set_high_contrast`)
##   FOCUS_HINTS  the keyboard's focus says which keys work there (focus_hint.gd)
##   TARGETS      "show interactive targets": a ring on every clickable thing in the world (target_marks.gd)
##   MOTION       reduced motion (UI §8.1 `reduced_motion`): the camera's easing off, the selection rings'
##                pulse still, particles at PARTICLE_RATIO, the rain and snow thinner and slower (demo_motion.gd)
##   QUIET_TOASTS fewer news toasts: warnings only, one line (demo_news_strip.gd)
##   PAUSE_PLANNING pause while a planning surface is open (UI §8.1 `pause_management`, default OFF)
##   PAUSE_CRITICAL pause on a critical incident (UI §8.1 `critical_autopause`, default ON)
## They live in STATIC vars, as the scale's and the mix's do: kept for the session and through Restart demo, never
## written to disk (the demo saves nothing yet).
##
## PRESETS SET INDIVIDUAL SETTINGS, which stay the player's to change one by one afterwards; a preset only turns
## its own settings on and leaves the rest as they are:
##   LARGE     the interface at 150 % where the window offers it, else 125 %; bigger tooltips; high contrast
##   KEYBOARD  focus hints; interactive targets shown
##   MOTION    reduced motion
##   QUIET     the sound's Quiet focus mix; fewer toasts
## Before one is applied its change is PREVIEWED as a diff ("Interface scale 100% → 150% · Bigger tooltips off → on");
## Restore defaults shows its diff and asks first (UI §8.1: "Restoring defaults shows a diff and requires" confirm).
## A SNAPSHOT is the whole set -- scale, mix, the flags -- so a preview is `diff_text(now, preset_of(now))`.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")

const SET_TOOLTIPS: int = 0
const SET_CONTRAST: int = 1
const SET_FOCUS_HINTS: int = 2
const SET_TARGETS: int = 3
const SET_MOTION: int = 4
const SET_QUIET_TOASTS: int = 5
const SET_PAUSE_PLANNING: int = 6
const SET_PAUSE_CRITICAL: int = 7
const SET_COUNT: int = 8
const SET_NAMES: Array[String] = ["Bigger tooltips", "High-contrast panels", "Focus hints", "Show interactive targets",
	"Reduced motion", "Fewer news toasts", "Pause while planning", "Pause on a critical incident"]
const SET_TIPS: Array[String] = [
	"Tooltips drawn a quarter larger",
	"A flat, opaque face under every panel's text, without the parchment's grain",
	"Where the keyboard's focus is, a line says which keys work there",
	"A ring on every resident, bed, tree, bridge, tunnel mouth and room that a click selects",
	"The camera stops easing, the selection rings stop pulsing, fewer particles, slower and thinner rain and snow",
	"News toasts show warnings only, one at a time (everything stays in the village news)",
	"Opening the Pantry, the Work screen, the village news, the Residents list, the object list or the Dig tool pauses",
	"A resident in difficulty or a threat pauses the village and says why",
]
const DEFAULTS: PackedByteArray = [0, 0, 0, 0, 0, 0, 0, 1]

const PRESET_LARGE: int = 0
const PRESET_KEYBOARD: int = 1
const PRESET_MOTION: int = 2
const PRESET_QUIET: int = 3
const PRESET_COUNT: int = 4
const PRESET_NAMES: Array[String] = ["Large readable", "Keyboard planner", "Reduced motion", "Quiet focus"]
const PRESET_TIPS: Array[String] = [
	"The interface at 150 % (125 % where the window is smaller), bigger tooltips, high-contrast panels",
	"Focus hints, and every clickable thing in the world ringed",
	"No camera easing, still selection rings, fewer particles, calmer rain and snow",
	"The Quiet focus sound mix, and news toasts for warnings only",
]
## Each preset's own flags, a bit per SET_* (the scale and mix are LARGE's and QUIET's own, below). A flat mask: a
## const Array[PackedInt32Array] of literals held untyped Arrays, and inside this script a loop over one ran no iteration.
const PRESET_MASKS: PackedInt32Array = [(1 << SET_TOOLTIPS) | (1 << SET_CONTRAST), (1 << SET_FOCUS_HINTS) | (1 << SET_TARGETS),
	1 << SET_MOTION, 1 << SET_QUIET_TOASTS]
## LARGE's scales, most wanted first.
const LARGE_SCALES: PackedInt32Array = [150, 125]

## Tooltips with SET_TOOLTIPS on are drawn this much larger.
const TOOLTIP_BOOST: float = 1.25

const ON_OFF: Array[String] = ["off", "on"]
const NO_CHANGE: String = "Nothing to change: already set"
const SCALE_WORDS: String = "Interface scale %d%% → %d%%"
const MIX_WORDS: String = "Mix %s → %s"
const FLAG_WORDS: String = "%s %s → %s"
const CUSTOM_MIX: String = "your own"

## The flags now (SET_* order).
static var flags: PackedByteArray = DEFAULTS.duplicate()


## The whole set at one moment: the interface scale, the sound mix (SoundMix.PRESET_*; CUSTOM: the player's own
## volumes) and the flags (`settings`, SET_* order).
class Snapshot:
	var scale_percent: int = UiLayout.USER_SCALE_100
	var mix: int = SoundMix.PRESET_BALANCED
	var settings: PackedByteArray = DEFAULTS.duplicate()

	func copy_from(other: Snapshot) -> void:
		"""Become `other`."""
		scale_percent = other.scale_percent
		mix = other.mix
		settings = other.settings.duplicate()

	func same_as(other: Snapshot) -> bool:
		"""Whether `other` holds exactly this."""
		return scale_percent == other.scale_percent and mix == other.mix and settings == other.settings


static func is_on(setting: int) -> bool:
	"""Whether setting `setting` (SET_*) is on now."""
	return setting >= 0 and setting < SET_COUNT and flags[setting] == 1


static func set_flag(setting: int, on: bool) -> bool:
	"""Turn one setting on or off; false (nothing changed) for an unknown one or no change."""
	if setting < 0 or setting >= SET_COUNT or (flags[setting] == 1) == on:
		return false
	flags[setting] = 1 if on else 0
	return true


static func reset() -> void:
	"""The flags back to their defaults (tests; a fresh process starts here)."""
	flags = DEFAULTS.duplicate()


static func current_into(out: Snapshot) -> void:
	"""The set as it stands now."""
	out.scale_percent = DemoUiScale.percent
	out.mix = SoundMix.preset
	out.settings = flags.duplicate()


static func defaults_into(out: Snapshot) -> void:
	"""The set at its defaults: 100 %, Balanced, DEFAULTS."""
	out.scale_percent = UiLayout.USER_SCALE_100
	out.mix = SoundMix.PRESET_BALANCED
	out.settings = DEFAULTS.duplicate()


static func preset_into(preset: int, from: Snapshot, scale_fits: Callable, out: Snapshot) -> void:
	"""`from` with preset `preset`'s own settings turned on (see PRESETS); `scale_fits(percent) -> bool` says which
	sizes the window offers (invalid: all of them)."""
	out.copy_from(from)
	if preset < 0 or preset >= PRESET_COUNT:
		return
	for setting: int in SET_COUNT:
		if PRESET_MASKS[preset] & (1 << setting) != 0:
			out.settings[setting] = 1
	if preset == PRESET_QUIET:
		out.mix = SoundMix.PRESET_QUIET
	if preset == PRESET_LARGE:
		out.scale_percent = large_scale(from.scale_percent, scale_fits)


static func large_scale(now_percent: int, scale_fits: Callable) -> int:
	"""LARGE's scale: the largest of LARGE_SCALES the window offers, never smaller than `now_percent`."""
	for percent: int in LARGE_SCALES:
		if percent <= now_percent:
			return now_percent
		if not scale_fits.is_valid() or bool(scale_fits.call(percent)):
			return percent
	return now_percent


static func diff_text(before: Snapshot, after: Snapshot) -> String:
	"""What going from `before` to `after` changes, one item per setting ("" when nothing does)."""
	var items := PackedStringArray()
	if before.scale_percent != after.scale_percent:
		items.append(SCALE_WORDS % [before.scale_percent, after.scale_percent])
	if before.mix != after.mix:
		items.append(MIX_WORDS % [mix_name(before.mix), mix_name(after.mix)])
	for setting: int in SET_COUNT:
		if before.settings[setting] != after.settings[setting]:
			items.append(FLAG_WORDS % [SET_NAMES[setting], ON_OFF[before.settings[setting]], ON_OFF[after.settings[setting]]])
	return " · ".join(items)


static func mix_name(mix: int) -> String:
	"""A mix's name ("your own" for the player's custom volumes)."""
	return SoundMix.PRESET_NAMES[mix] if mix >= 0 and mix < SoundMix.PRESET_NAMES.size() else CUSTOM_MIX


static func store(snapshot: Snapshot) -> void:
	"""Make `snapshot`'s flags and mix the settings (the mix's volumes when it names one). The scale is the host's to
	lay out (demo_village.gd `set_ui_scale`), and the effects its to apply (access_effects.gd)."""
	flags = snapshot.settings.duplicate()
	if snapshot.mix != SoundMix.preset and snapshot.mix != SoundMix.PRESET_CUSTOM:
		SoundMix.choose_preset(snapshot.mix)


static func tooltip_scale() -> float:
	"""The tooltips' size over the HUD's scale (TOOLTIP_BOOST with bigger tooltips on)."""
	return TOOLTIP_BOOST if is_on(SET_TOOLTIPS) else 1.0
