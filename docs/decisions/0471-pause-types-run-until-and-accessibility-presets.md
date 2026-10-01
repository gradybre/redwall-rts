# 0471 — The demo's pause types, one Resume, "Run until…", the accessibility presets and the object list
Date: 2026-10-01 · Status: Accepted

Numbered 0471: the brief reserved 0471–0479 for review group S; the highest record on this branch is 0421 and no
worktree held a 047x record. Review group **S, session, time and accessibility**: UX-022, UX-023 and the rest of F35
(`/Users/brendan/Developer/redwall-review/REVIEW.md` P9 and P1's "Settings / session" row). **Saving stays deferred by
Brendan's ruling**: nothing here saves or loads, and the menu still says the demo cannot save.

## 1. Pause types and the one Resume (UX-022)

- **The kinds** (`demo/session/pause_ledger.gd`): STALL (the clock's CRITICAL, REQ-SET-008's diagnostic pause),
  CRITICAL (a critical incident raised or come back, `demo_incidents.gd incident_cue`), MENU (the game menu), PLANNING (a
  planning surface open), PLAYER (Space, the HUD's pause button, or a run that arrived), OTHER (VICTORY, LOAD). Each is
  said in words on the **pause card** (`demo/ui/demo_pause_card.gd`), which stands in for the HUD's "Paused: PLAYER"
  label (UI-SET-086; the label is hidden each frame, as the HUD date and counters are repainted).
- **Three demo holds share the clock's MENU reason.** UI §8.1 puts the management pause (`pause_management`) on MENU. A
  critical incident cannot use the clock's CRITICAL: that bit is the overload producer's alone
  (`scheduler_events.gd PRODUCER_OVERLOAD`) and acknowledging it drops owed ticks. So the menu, planning and incident
  holds are a mask in the ledger, and the clock's MENU is held while any stands. **The game menu now holds its pause
  through the ledger** (`demo_menu.gd hold_pause`), so closing it never lifts a planning or critical pause beside it
  (UI §3: "Closing the menu removes MENU only" -- now "removes the menu's hold only"). The scene leaving releases every
  hold, and a new ledger lets go of a MENU nobody holds, so a Restart never opens stuck.
- **One Resume** (`pause_ledger.gd resume`): clears PLAYER, the planning pause and the critical pause. It never closes
  the menu (the menu's own Resume does) and never acknowledges a stall (the stall banner's Resume, which explicitly drops
  owed time, does; the card hides while the banner shows, so one surface speaks for a stall). Space while paused, the
  card's button and the HUD's pause button pressed while paused are all this Resume: the HUD button toggles PLAYER only
  (`ui_shell.gd`, untouched), so the time control finishes the Resume after it (`time_control.gd _on_shell_action`).
- **Panels never override the player's pause**: closing a planning surface releases its own hold, nothing else. After
  Resume the planning pause is **waived** until every planning surface has closed, so the player can plan with the
  village running; reopening one later pauses again.
- **Which incidents pause.** UI §3 limits the critical auto-pause to the first starvation death, the first
  incapacitated resident, collapse and a save error -- settlement conditions the demo does not raise. The demo's own
  CRITICAL incidents are a resident in difficulty in the water and a tunnel threat (flood, fire): those pause. A demo
  warning never does (UI §3: "first low food/fuel warning does not auto pause").
- **Auto-pause is tunable** in the menu's Settings under Time: "Pause while planning" (default **off**, UI §8.1) and
  "Pause on a critical incident" (default **on**). The planning surfaces are the management screens: the Pantry, the
  Work screen, the village news, the Residents list, the object list and the Dig tool. The right column's detail panels
  are not: they are open nearly all the time.
- **While a pop-up is open** the card rises above it, bottom centre, so a planning pause is said beside the Pantry that
  holds it (first frames: under the Pantry it was invisible). Its Resume works there; Space does not, because the input
  gate gives a modal every key (decision 0261) -- the keyboard's way out is closing the pop-up, which ends its pause.

## 2. "Run until…" (UX-022)

- **Targets** (`demo/session/run_until.gd`), each read from the system that owns it: dawn and dusk at the night routine's
  own hours (`night_routine.gd DAWN_HOUR` 06:00, `DUSK_HOUR` 20:00), the next meal at the kitchen's call
  (`meal_rules.gd CALL_HOUR`), a selected project's completion (`underground_rooms.gd is_done`, `underground_graph.gd
  is_open`, `bridges.gd is_open`, each by row and generation, so a reused row reads GONE), the next harvest window (a crop
  bed newly `STAGE_RIPE`), the next warning or incident (a new WARNING row in the notice feed -- a folded repeat is the
  same warning, as for the warning chime -- or a new or recurring incident: `demo_incidents.gd occurrences`, new).
- **Which project is "selected"**: a selected room still being dug, else a selected tunnel segment being dug, paused or
  planned, else the bridge planned at the Water panel's chosen site. With none, the target is disabled and says so.
- **Exact on the calendar.** The calendar targets know their tick, so the run caps the demo clock's next frame
  (`demo_clock.gd limit_usec`, new) at the fewest microseconds that bring the calendar onto it. Under the ten-minute day
  (decision 0421) "Run until dawn" stops at 06:00 to the tick at 1x, 2x or 4x and with ragged frames (tests; live: from
  05:40 at 4x it stopped on tick 18000). Every consumer of the demo clock takes the same capped frame, so nothing drifts.
  Event targets stop on the frame their system reports.
- **Pausing**: arrival is the PLAYER pause with the arrival as its note ("Reached dawn: Y1 Spring 2, 06:00"). **Any
  pause before arrival cancels the run** (the player's, the menu's, a planning pause, a stall), and so does a critical
  incident even with its auto-pause off -- unless the run was waiting for exactly that ("the next warning or incident").
  The card says how a run ended ("Run until dawn cancelled: paused (you paused)"). A run whose project is removed
  pauses the village too, saying so, rather than leaving it running unattended at the run's speed (review H2).
- **Where**: a button in the HUD's time cluster, in row 1's free end right of 4x at the standard and wide profiles,
  just left of the cluster at the narrow one, which has no free end; **G** opens the same menu (a modal: Tab, the arrows,
  Enter, Esc or G). The menu sets the speed (the game's requested speed) and shows each target's time ("Dawn: 06:00, in
  23 h 59 min (about 9 min 59 s at 1x)") or why it is unavailable. G was free; UI §5 names no key for it.

## 3. Accessibility presets (UX-023)

- **Settings** (`demo/access/demo_access.gd`), beside the interface scale and the mix: bigger tooltips (x1.25), high-
  contrast panels, focus hints, show interactive targets, reduced motion, fewer news toasts, and the two auto-pauses.
  Static vars, like the scale's and the mix's: kept through Restart, never written to disk.
- **Presets set individual settings**; a preset only turns its own on and leaves the rest as the player set them:
  Large readable (150 % where the window offers it, else 125 %, never smaller than now; bigger tooltips; high contrast),
  Keyboard planner (focus hints; targets), Reduced motion, Quiet focus (decision 0351's Quiet focus mix; fewer toasts).
- **Live preview**: pointing at a preset (hover or keyboard focus) shows the exact change before it is applied ("Large
  readable would change: Interface scale 100% → 150% · ..."); applying changes the running village at once; a preset is
  lit while all it sets is in place. **Restore defaults** shows its change and asks, Cancel focused (UI §8.1).
- **High contrast** re-renders the shared text pieces (`woodland_styles.gd set_high_contrast`: the panel, tight panel,
  map/tooltip, row, field and tile faces) flat and opaque **in place** -- each cached ImageTexture is updated, so every
  panel and the HUD already wearing it change at once. The 3 px focus ring UI §8.1 also lists is not done (open).
- **Reduced motion** (`demo/access/demo_motion.gd`): the camera's easing off (UI §6: "camera smoothing off"); the
  selection rings, a swimmer's ripple and the mound over a digger stop pulsing; every CPU/GPU particle system at 35 % of
  its count (each as it enters the tree, all on a change; its full count kept on the node); the rain and snow veils
  thinner by the same share and half as fast. **The demo has no camera shake**, so there was none to turn down. Nothing
  changes an action's timing or the clock (REQ-UX-008).
- **Fewer toasts**: the news strip toasts warnings only, one at a time; the history and the incident count are untouched.
- **Bigger tooltips**: the action cards' tooltip theme, the HUD theme's TooltipLabel size, and a small root-window theme
  for every other demo tooltip, all x1.25.
- **Bigger tooltips never touch the cached theme resource**: the HUD theme is written only once the woodland skin has
  made the HUD its own copy (`woodland_theme_patch.gd`'s rule), and again just after skinning.
- **Focus hints** (`focus_hint.gd`): under the keyboard's focus (never a click's) one line names the control and its
  keys, a pop-up's own keys inside one. **Interactive targets** (`target_marks.gd`): a brass ring on every resident, crop
  bed, tree, bridge and tunnel mouth, and rooms below in the U view, one MultiMesh per view, re-placed ten times a
  second (first drawn as an ImmediateMesh: ~190 targets made that ~27 000 vertex calls a rebuild, so it was replaced).
  The rings list the targets into columns of their own: sharing the object list's let a refresh move its rows under the
  keyboard (review H1).

## 4. The object list (F6)

`demo/access/object_list.gd` on UI §8.2's own F6 (`open_world_list`, bound in the project and unused until now): a modal
listing every resident, crop bed, tree, bridge, tunnel mouth and room (`world_targets.gd`, registered by
`village_targets.gd`), filterable by kind. Enter on a row selects that thing through the very call a click makes (its
panel comes forward; a room on its own level in the U view) and centres the camera on it, then closes. UI §8.2's search
field and Tiles category are not built (open).

## 5. F35's leftovers

The Woods, Tunnels and Pantry scrolls, and the menu's Settings scroll (which used `follow_focus`), are `demo_scroll.gd`:
the focused control is brought into view in the container's own pixels at any interface scale (decision 0391 §4).

## 6. Key rebinding: out of scope

The demo has no rebinding system (UI §8.1's `keybindings` list 080 is not built, and nothing reads a binding table), so
UX-023's rebinding and P9's "rebind a conflicting key" are not done here. The Controls page lists G and F6.

## Open

- Key rebinding (above); the world list's search field and Tiles category; the 3 px high-contrast focus ring.
- The Work screen's and the village news's scrolls still use the engine's focus following (not this group's panels).
- A screen reader is not exercised: the card, the run menu and the object list are ordinary Buttons and Labels.
- A pause card shown over a pop-up takes clicks; Space inside a pop-up still goes to the pop-up (decision 0261).
- Critical incidents pause on the clock's MENU, not CRITICAL (§1); a future settlement-side CRITICAL producer would
  let the clock say it itself.
