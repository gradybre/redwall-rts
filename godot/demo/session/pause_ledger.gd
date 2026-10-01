extends RefCounted
## THE PAUSE TYPES and the one Resume. Decision 0471 (review UX-022, P9). Presentation over the game's own clock:
## every pause still goes through GameManager's scheduler-queued controls, and nothing here writes a tick.
##
## WHY. The clock holds a pause as a reason MASK (PLAYER, MENU, CRITICAL, VICTORY, LOAD; UI §3), so a menu pause can
## never be lifted by the player's Resume. But the demo had only two of the kinds the review asks a player to tell
## apart -- the player's own and the menu's -- and the HUD said them as "Paused: PLAYER". A panel opened to plan, or a
## critical incident (a resident in difficulty in the water, a tunnel threat), could not pause at all, and when
## several reasons stood there was no single control that said what it would clear.
##
## THE KINDS (KIND_*), in the order the pause card lists them:
##   * STALL     -- the clock's CRITICAL: REQ-SET-008's diagnostic pause after a stall. Its own banner owns it
##                  (demo_stall_banner.gd): its Resume drops the owed ticks explicitly, so ours never does.
##   * CRITICAL  -- a critical incident raised or come back (demo_incidents.gd `incident_cue`), with
##                  "Pause on a critical incident" on (UI §8.1 `critical_autopause`, default on).
##   * MENU      -- the game menu is open (demo_menu.gd), or the village guide's window (demo/guide/guide_window.gd,
##                  decision 0481: `hold_guide`, its own hold so the two never release each other's). Only closing
##                  the one that holds it lifts it.
##   * PLANNING  -- a planning surface is open (the Pantry, the Work screen, the village news, the Residents
##                  roster, the object list, the Dig tool) with "Pause while planning" on (UI §8.1
##                  `pause_management`, default OFF).
##   * PLAYER    -- the clock's PLAYER: Space, the HUD's pause button, or a "Run until..." that arrived (its NOTE
##                  says where: "Reached dawn: Y1 Spring 2, 06:00").
##   * OTHER     -- VICTORY or LOAD (never held by the demo).
##
## ONE CLOCK BIT FOR THREE DEMO HOLDS. The clock's CRITICAL is the overload producer's alone (scheduler_events.gd
## PRODUCER_OVERLOAD), and acknowledging it drops owed ticks; a demo incident cannot borrow it. UI §8.1 puts the
## management pause on MENU. So the demo's three holds -- MENU, PLANNING, INCIDENT -- share the clock's MENU reason,
## held while ANY of them stands (HOLD_*), and this ledger keeps them apart for the words. The game menu holds its
## pause HERE (`hold_menu`) rather than straight on the clock, so closing it no longer lifts a planning or critical
## pause that stands beside it.
##
## RESUME (`resume`) clears what the player may clear from the time controls: the PLAYER reason, the planning pause
## (WAIVED until every planning surface has closed: reopening one pauses again) and the critical-incident pause (the
## incident stays open in the village news). It never closes the game menu and never acknowledges a stall. Space and
## the HUD's pause button are this Resume while the village is paused (time_control.gd); "panels never override the
## player's pause": closing a panel releases the planning hold only, so a PLAYER pause stays.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const KIND_PLAYER: int = 1
const KIND_MENU: int = 2
const KIND_PLANNING: int = 4
const KIND_CRITICAL: int = 8
const KIND_STALL: int = 16
const KIND_OTHER: int = 32
## The kinds Resume clears.
const RESUMABLE: int = KIND_PLAYER | KIND_PLANNING | KIND_CRITICAL
## The demo's holds on the clock's MENU reason.
const HOLD_MENU: int = 1
const HOLD_PLANNING: int = 2
const HOLD_INCIDENT: int = 4
## The village guide's window (decision 0481), a MENU kind of its own words.
const HOLD_GUIDE: int = 8

const STALL_WORDS: String = "Critical: the computer stalled, so the village stopped rather than skip time"
const CRITICAL_WORDS: String = "Critical: %s"
const MORE_CRITICAL_WORDS: String = "Critical: %s (and %d more)"
const MENU_WORDS: String = "The game menu is open"
const GUIDE_WORDS: String = "The village guide is open"
const PLANNING_WORDS: String = "Planning: %s is open"
const PLAYER_WORDS: String = "You paused"
const OTHER_WORDS: String = "Held by the game (%s)"
const RESUME_NONE: String = "Nothing to resume"
const RESUME_MENU: String = "Close the game menu to resume"
const RESUME_GUIDE: String = "Close the village guide to resume"
const RESUME_STALL: String = "Resume on the stall banner (Enter)"

## Whether a planning surface pauses (UI §8.1 `pause_management`, default off) and a critical incident does
## (`critical_autopause`, default on). The host sets them from the settings (demo_access.gd).
var auto_planning: bool = false
var auto_critical: bool = true
## How many times Resume cleared something (checks).
var resumes: int = 0

var _manager: GameManagerScript = null
var _holds: int = 0
## Whether this ledger holds the clock's MENU reason now.
var _menu_held: bool = false
var _planning_open: bool = false
var _planning_waived: bool = false
var _planning_what: String = ""
var _incident_text: String = ""
var _incident_count: int = 0
var _player_note: String = ""


func bind(manager: GameManagerScript) -> void:
	"""Hold pauses on `manager`'s clock. A MENU reason nobody in this scene holds (a scene restarted while a planning
	or critical hold stood) is let go, so the village never opens stuck behind a reason no one can lift."""
	_manager = manager
	if _manager != null and _holds == 0 and _manager.clock().has_pause_reason(SimClock.MENU):
		_manager.set_menu_pause(false)


# --- the holds --------------------------------------------------------------------------------------------

func hold_menu(on: bool) -> bool:
	"""The game menu's pause (demo_menu.gd `hold_pause`): held while it is open. False: the clock refused."""
	return _set_hold(HOLD_MENU, on)


func hold_guide(on: bool) -> bool:
	"""The village guide window's pause (guide_window.gd `hold_pause`): held while it is open. False: the clock refused."""
	return _set_hold(HOLD_GUIDE, on)


func set_planning(open: bool, what: String) -> void:
	"""Whether a planning surface is open now, and its name ("the Pantry"); called every frame. The pause stands while
	one is open, unless the setting is off or Resume waived it (the waiver ends once every surface has closed)."""
	_planning_what = what
	if not open:
		_planning_waived = false
	_planning_open = open
	var want: bool = open and auto_planning and not _planning_waived
	if want != has_hold(HOLD_PLANNING):
		_set_hold(HOLD_PLANNING, want)


func raise_critical(text: String) -> bool:
	"""A critical incident was raised or came back: pause and say it (with "Pause on a critical incident" on).
	Returns whether it paused."""
	if not auto_critical or text.is_empty() or not _set_hold(HOLD_INCIDENT, true):
		return false
	_incident_text = text
	_incident_count += 1
	return true


func pause_player(note: String = "") -> bool:
	"""The PLAYER reason, with what to say about it ("" for the player's own pause)."""
	if _manager == null or not _manager.pause_game():
		return false
	_player_note = note
	return true


func resume() -> int:
	"""THE Resume (see RESUME): the kinds it cleared (KIND_* bits; 0 when nothing could be)."""
	if _manager == null:
		return 0
	var cleared: int = 0
	if player_held() and _manager.resume_game():
		cleared |= KIND_PLAYER
		_player_note = ""
	var lifted: int = _holds & (HOLD_PLANNING | HOLD_INCIDENT)
	if lifted != 0 and _set_hold(lifted, false):
		if lifted & HOLD_PLANNING != 0:
			_planning_waived = true
			cleared |= KIND_PLANNING
		if lifted & HOLD_INCIDENT != 0:
			_incident_count = 0
			cleared |= KIND_CRITICAL
	if cleared != 0:
		resumes += 1
	return cleared


func toggle() -> void:
	"""Space, and the HUD's pause button: Resume while the village is paused, else the player's pause."""
	if _manager == null:
		return
	if _manager.is_paused():
		resume()
	else:
		pause_player()


func release_all() -> void:
	"""Let every demo hold go (the scene is leaving: a restart must not inherit a MENU reason)."""
	_holds = 0
	_sync_clock()


func sync() -> void:
	"""Once a frame: forget a note whose PLAYER pause is gone, and take a refused MENU change up again."""
	if not player_held():
		_player_note = ""
	_sync_clock()


func _set_hold(bits: int, on: bool) -> bool:
	"""Set or clear hold `bits` and bring the clock's MENU reason into line; on a refusal nothing changes."""
	var before: int = _holds
	_holds = (_holds | bits) if on else (_holds & ~bits)
	if _sync_clock():
		return true
	_holds = before
	return false


func _sync_clock() -> bool:
	"""Hold the clock's MENU reason while any demo hold stands, and release it once none does."""
	var want: bool = _holds != 0
	if want == _menu_held:
		return true
	if _manager == null or not _manager.set_menu_pause(want):
		return false
	_menu_held = want
	return true


# --- reading ----------------------------------------------------------------------------------------------

func has_hold(bit: int) -> bool:
	"""Whether demo hold `bit` (HOLD_*) stands."""
	return _holds & bit != 0


func player_held() -> bool:
	"""Whether the clock holds the PLAYER reason."""
	return _manager != null and _manager.clock().has_pause_reason(SimClock.PLAYER)


func kinds() -> int:
	"""The pause kinds standing now (KIND_* bits; 0: the village runs)."""
	if _manager == null:
		return 0
	var clock: SimClock = _manager.clock()
	var out: int = KIND_PLAYER if clock.has_pause_reason(SimClock.PLAYER) else 0
	if clock.has_pause_reason(SimClock.CRITICAL):
		out |= KIND_STALL
	if clock.has_pause_reason(SimClock.VICTORY) or clock.has_pause_reason(SimClock.LOAD):
		out |= KIND_OTHER
	if has_hold(HOLD_MENU | HOLD_GUIDE) or (clock.has_pause_reason(SimClock.MENU) and _holds == 0):
		out |= KIND_MENU
	if has_hold(HOLD_PLANNING):
		out |= KIND_PLANNING
	if has_hold(HOLD_INCIDENT):
		out |= KIND_CRITICAL
	return out


func can_resume() -> bool:
	"""Whether Resume would clear anything now."""
	return kinds() & RESUMABLE != 0


func resume_refusal() -> String:
	"""Why Resume can do nothing now ("" when it can)."""
	var now: int = kinds()
	if now & RESUMABLE != 0:
		return ""
	if now & KIND_MENU != 0:
		return RESUME_GUIDE if has_hold(HOLD_GUIDE) and not has_hold(HOLD_MENU) else RESUME_MENU
	if now & KIND_STALL != 0:
		return RESUME_STALL
	return RESUME_NONE


func reasons_into(out: PackedStringArray) -> int:
	"""Each standing kind's words into `out` (cleared first), most urgent first; returns how many."""
	out.clear()
	var now: int = kinds()
	if now & KIND_STALL != 0:
		out.append(STALL_WORDS)
	if now & KIND_CRITICAL != 0:
		out.append(CRITICAL_WORDS % _incident_text if _incident_count <= 1
			else MORE_CRITICAL_WORDS % [_incident_text, _incident_count - 1])
	if has_hold(HOLD_MENU) or (now & KIND_MENU != 0 and not has_hold(HOLD_GUIDE)):
		out.append(MENU_WORDS)
	if has_hold(HOLD_GUIDE):
		out.append(GUIDE_WORDS)
	if now & KIND_PLANNING != 0:
		out.append(PLANNING_WORDS % _planning_what)
	if now & KIND_PLAYER != 0:
		out.append(PLAYER_WORDS if _player_note.is_empty() else _player_note)
	if now & KIND_OTHER != 0:
		out.append(OTHER_WORDS % ", ".join(_manager.get_pause_reason_names()))
	return out.size()


func player_note() -> String:
	"""What the PLAYER pause says about itself ("" for the player's own)."""
	return _player_note


func planning_waived() -> bool:
	"""Whether Resume waived the planning pause for the surfaces open now."""
	return _planning_waived
