extends Node
## The accessibility settings' EFFECTS on the running village. Decision 0471 (review UX-023). Presentation only.
##
## `apply()` reads demo_access.gd's settings and brings everything into line, at once (the Settings page calls it on
## every change, so a preset is previewed live in the village itself):
##   * high-contrast panels  woodland_styles.gd `set_high_contrast` (the shared pieces re-rendered in place)
##   * bigger tooltips       the host's tooltip scale (demo_village.gd `_scale_tooltips`: the action cards'), the
##                           HUD theme's TooltipLabel size, and a root-window theme for every other demo tooltip
##   * focus hints           focus_hint.gd on or off
##   * interactive targets   target_marks.gd shown or hidden
##   * reduced motion        demo_motion.gd's flag, every particle system in the village brought to it, and each new
##                           one as it enters the tree (`node_added`, while this node lives)
##   * fewer toasts          the news strip's `quiet`
##   * the two auto-pauses   the pause ledger's `auto_planning` and `auto_critical`
##   * the mix               the host's sound `apply` (a preset may change the mix)
## Every target is optional (null / invalid: skipped), so a test can apply to a part of the village.

const Access := preload("res://demo/access/demo_access.gd")
const Motion := preload("res://demo/access/demo_motion.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const LedgerScript := preload("res://demo/session/pause_ledger.gd")
const MarksScript := preload("res://demo/access/target_marks.gd")
const HintScript := preload("res://demo/access/focus_hint.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const ThemePatch := preload("res://demo/ui/woodland_theme_patch.gd")

const TOOLTIP_TYPE: StringName = &"TooltipLabel"
const FONT_SIZE: StringName = &"font_size"

var ledger: LedgerScript = null
var marks: MarksScript = null
var hint: HintScript = null
var news: NewsScript = null
## The HUD's theme-holding control (the shell), whose TooltipLabel size grows with bigger tooltips.
var hud_theme_owner: Control = null
## The root of what reduced motion's particles are counted under (the village).
var motion_root: Node = null
## `()`: re-scale the action cards' tooltips; `()`: write the mix to the buses.
var on_tooltips: Callable = Callable()
var on_sound: Callable = Callable()
## How many times `apply` ran (checks).
var applies: int = 0

var _hud_tip_px: int = -1
var _root_theme: Theme = null
var _root_theme_before: Theme = null
var _motion_applied: bool = false


func _ready() -> void:
	"""Follow particle systems entering the tree while reduced motion is on."""
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	"""Stop following the tree, and put the root window's theme back."""
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if _root_theme != null and get_window() != null and get_window().theme == _root_theme:
		get_window().theme = _root_theme_before


func _on_node_added(node: Node) -> void:
	"""A particle system entering the tree with reduced motion on emits its reduced share."""
	if Motion.reduced and (node is CPUParticles3D or node is GPUParticles3D):
		Motion.apply_particles(node)


func apply() -> void:
	"""Bring every effect into line with the settings (see the header)."""
	applies += 1
	Styles.set_high_contrast(Access.is_on(Access.SET_CONTRAST))
	apply_tooltips()
	_apply_motion()
	if hint != null:
		hint.enabled = Access.is_on(Access.SET_FOCUS_HINTS)
	if marks != null:
		marks.set_shown(Access.is_on(Access.SET_TARGETS))
	if news != null:
		news.quiet = Access.is_on(Access.SET_QUIET_TOASTS)
	if ledger != null:
		ledger.auto_planning = Access.is_on(Access.SET_PAUSE_PLANNING)
		ledger.auto_critical = Access.is_on(Access.SET_PAUSE_CRITICAL)
	if on_sound.is_valid():
		on_sound.call()


func _apply_motion() -> void:
	"""Reduced motion's flag, and every particle system under the village brought to it when it changed."""
	var reduced: bool = Access.is_on(Access.SET_MOTION)
	if reduced == Motion.reduced and _motion_applied:
		return
	Motion.reduced = reduced
	_motion_applied = true
	if motion_root != null:
		Motion.apply_tree(motion_root)


func apply_tooltips() -> void:
	"""The tooltips at TOOLTIP_BOOST with bigger tooltips on, at their own size with it off. The HUD's theme is written
	only once the woodland skin has made it the HUD's own copy (ThemePatch.META_SKINNED): before that it is the cached
	theme resource itself, which is never touched (the host calls this again after skinning)."""
	var scale: float = Access.tooltip_scale()
	if on_tooltips.is_valid():
		on_tooltips.call()
	var theme: Theme = hud_theme_owner.theme if hud_theme_owner != null else null
	if theme != null and theme.has_meta(ThemePatch.META_SKINNED):
		if _hud_tip_px < 0:
			_hud_tip_px = theme.get_font_size(FONT_SIZE, TOOLTIP_TYPE)
		theme.set_font_size(FONT_SIZE, TOOLTIP_TYPE, roundi(float(_hud_tip_px) * scale))
	_apply_root_tooltips(scale)


func _apply_root_tooltips(scale: float) -> void:
	"""Every other demo tooltip (controls under the root window with no theme of their own): a small theme on the
	window carrying the boosted size while it is on, the window's own theme back when it is off."""
	var window: Window = get_window() if is_inside_tree() else null
	if window == null:
		return
	if scale <= 1.0:
		if _root_theme != null and window.theme == _root_theme:
			window.theme = _root_theme_before
		return
	if _root_theme == null:
		_root_theme_before = window.theme
		_root_theme = window.theme.duplicate() as Theme if window.theme != null else Theme.new()
	var base: int = ThemeDB.fallback_font_size
	_root_theme.set_font_size(FONT_SIZE, TOOLTIP_TYPE, roundi(float(base) * scale))
	window.theme = _root_theme


func hud_tooltip_px() -> int:
	"""The HUD theme's tooltip size now (-1: no HUD theme)."""
	var theme: Theme = hud_theme_owner.theme if hud_theme_owner != null else null
	return theme.get_font_size(FONT_SIZE, TOOLTIP_TYPE) if theme != null else -1
