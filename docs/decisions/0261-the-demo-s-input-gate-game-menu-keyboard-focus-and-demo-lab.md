# 0261 — The demo's input gate, game menu, keyboard focus and Demo Lab
Date: 2026-09-30 · Status: Accepted

Review group G ("input, menu and keyboard"): findings F26, F29, F30 and F50 of the live-demo review
(`redwall-review/REVIEW.md`, written against 157a3a4), and P1's "Objectives / Help" and "Settings / session"
rows. **Numbered 0261, not 0212:** the highest record on this branch is 0211, and groups B–E and tunnel phase 6
are being written in parallel, so this group took the highest number plus 50 to avoid a collision.

Each finding was confirmed on this branch (feat/live-demo at 43d9654) before the fix:

- **F26.** With resident 0 selected and the Pantry open, a real `Viewport.push_input` right-click outside its
  frame moved resident 0 to `ORDER_MOVE`, and B opened the Dig tool behind it.
- **F29.** `ui_shell.gd _on_menu_pressed()` opened `ID_NEW_SETTLEMENT` (103).
- **F30.** Every demo button factory, and the right column's tabs and "×", set `FOCUS_NONE`.
- **F50.** "Next weather (demo)", "Test event (demo)", "Storm gust (demo)" and "Cramp (demo)" were buttons in
  the Tunnels, Woods and Water panels.

## Decision

### 1. One input gate (`godot/demo/ui/demo_input_gate.gd`)

UI §3 wants "a single UIPanelRouter" owning focus, the open modal and the dismissal stack. The demo's
pop-ups are its own CanvasLayers, not the shell's workspace, so the demo gets one node that does that job
for them. `demo_village.gd` adds it **last**: Godot calls `_input`, `_unhandled_key_input` and
`_unhandled_input` in reverse tree order, so it reads every event before the Dig tool's `_input`, the HUD
shell's `_input` and `_unhandled_key_input`, and every world handler.

**Modals.** A pop-up that presents as modal is *watched* (`watch_modal`): while its layer is visible it is on
the stack. The Pantry, the new game menu and the new Demo Lab are watched. While one is open:

- a **scrim** (UI §3 layer 80) is laid as its layer's first child across the whole viewport, taking every
  click, drag and wheel outside the frame — the gate adds and removes it, so the Pantry's own file is
  untouched;
- **key presses are swallowed** before anything reads them, except focus movement (Tab, Shift+Tab, arrows,
  Home/End, Page Up/Down), Enter and Space (routed below), F11 and the modal's own close keys. **Key releases
  always pass**, so a camera key held when the modal opened is let go;
- **Esc**, and the modal's own key (K / `open_food` for the Pantry, F8 for the Lab), dismiss the top modal one
  step through its own `close` Callable, and are consumed — UI §3: "Closing a modal does not also clear
  selection in the same key press";
- **focus is trapped**: it lands on the modal's first content control (a close button can be named with
  `set_modal_close` and is then last in the ring: UI §8.2's content → Cancel), Tab cycles the modal, and on
  close focus goes back to the control that had it, or to the world.

Focus opened by a click is hidden (Godot 4.7 `grab_focus(true)`), by a key drawn — decision 0198's addendum
rule, reused.

**What else presents as modal.** The notification history (UI-SET-012) is the shell's layer-30 expansion,
non-modal by UI §3; it already takes Esc itself and a click on it is consumed by its panel, which the live
check proves (a right-click on it issues no order). The Dig and room tools have **no dialogs**: their readout
is a label and their input is the tool's own. Neither is made modal.

### 2. Enter and Space go by focused context (F30's conflict)

The Dig tool reads Enter in `_input`, before the GUI, so that Enter always digs the piece laid and never
presses a HUD button that happened to hold the focus. Making the demo's buttons focusable would have broken
that. The rule now, in the gate:

- a button holding the **keyboard's** focus (`has_focus(true)`: reached by Tab or F7) takes Enter and Space —
  the gate presses it and consumes the key, so neither the Dig tool nor the world's Space pause sees it;
- a button holding a **click's** focus does not: the gate drops that focus and lets the key go on, so Enter
  still digs and Space still pauses, exactly as when nothing could take focus. The same goes for the arrows and
  Page Up/Down -- the camera's keys -- which Godot would otherwise spend moving focus between buttons, and F7
  from a click's focus starts from the world;
- Ctrl+Space stays the global pause outside a modal (UI §3); inside one every press but navigation and
  activation is swallowed, so the modal must be closed first. A focused non-button (a text field) keeps its
  keys.

This is UI §3's "Enter activates the focused control; Space activates a focused native button/toggle and
otherwise pauses the world", made exact for a HUD whose buttons also take clicks. The project's `ui_accept`
is Enter only, so Space activation is the gate's, not Godot's.

**The stall banner** (`demo_stall_banner.gd`) takes Enter and Space itself in `_input`; while it shows, the
gate leaves exactly those two keys alone (`yields`) and routes every other key as ever, so a modal under the
banner still blocks the world and the HUD. **The HUD's own scrimmed workspace** (the shell's true modal pages)
is a modal the gate does not own: while `ui_shell.gd workspace_owns_input()` (a public reading of its existing
`_workspace_owns_input`) is true, the gate routes nothing to the demo's panels. An ordinary workspace (the
Residents roster) holds nothing and the panels stay live beside it (UI §4.2). A modal that closes while
another stays open hands focus to the one still open, and Enter presses only a button inside the top modal.

### 3. Keyboard focus in the panels

The factories (`farm_ui.gd button`, the Woods, Water, Tunnels and party panels' `_button` / `_wood_button`,
the right column's tabs and "×") now call one helper, `woodland_styles.gd focusable()`: `FOCUS_ALL` and the
HUD's own focus ring (`ring_box`, the same piece the skinned HUD theme uses) as the button's `focus` StyleBox.
The change is one line per factory so the other groups' edits to those files merge cleanly.

- The ring is the control's own StyleBox, so it disappears with the control (decision 0198's rule holds with
  nothing more to do).
- The demo's panels are separate CanvasLayers, and Godot's own Tab traversal stops at a CanvasLayer, so the
  gate keeps **regions**: the right column (the tab strip, then the shown panel) and the left column (the
  party panel). Tab / Shift+Tab cycle the focused region in reading order; only shown buttons are stops.
- **F7 moves focus world → right column → left column → world**, skipping a region with nothing to focus.
  F6 was the obvious key, but UI §8.2 gives F6 to the World list; F1–F5 and F9 are bound. Esc with the
  keyboard's focus in a region gives it back to the world.

### 4. The game menu (`godot/demo/ui/demo_menu.gd`)

- The HUD's Menu button calls a host's handler when one is set. The seam is `ui_shell.gd
  set_menu_handler()`; with no handler the button keeps opening the New Settlement form, so
  `scenes/main.tscn` is unchanged. The demo sets it: its Create would discard the settlement the demo runs
  on, so New Settlement has **no legitimate use in the demo and is not reachable from it**.
- Esc that nothing else took opens the menu: `demo_village.gd _unhandled_input`, which Godot calls after every
  child's, is UI §3's last rung ("open game menu").
- Pages: Resume · Restart demo… · Controls · Settings · Demo Lab · Quit…, with **"The demo can't save yet:
  quitting or restarting loses this village."** always on the menu. Restart and Quit ask first, repeat that
  the village will be lost, and put focus on Cancel. Esc goes back a page, then closes.
- **Pause.** Opening holds the clock's MENU reason through a new `GameManager.set_menu_pause(held)` (the
  scheduler already had a MENU producer; GameManager had no public way to reach it). The requested speed is
  kept apart, so closing restores the speed the village had, and a PLAYER pause held before stays held.
- **Settings holds only what works.** Interface scale, 100 / 125 / 150 % (UI §8.1 `ui_scale`): the shell's own
  `apply_user_scale` and a demo-wide percent (`demo_ui_scale.gd`), which the five demo layout sites now read
  instead of a hard-coded 100 %, so the demo's panels grow with the HUD. A size is offered only where it leaves
  **720 logical rows** (the demo's panels are laid out for 1280x720 at 100 %); at 1280x720 only 100 % fits,
  and the refused sizes are disabled with the reason. Full screen (the F11 toggle). Sound: the demo has none,
  and the page says so. Nothing else is shown.
- **A refused release keeps the menu open.** If the clock refuses to drop MENU (a load holds its barrier),
  `close()` says so and the menu stays up, and Restart and the Lab do not run: a pause is never left
  standing with no menu to explain it. Quit still quits; it needs no pause released.
- **The scale follows the window.** On every resize (and full-screen toggle) a scale the window no longer fits
  steps down to the largest that does.
- **Restart** reloads the scene. UIManager holds UI-SET-103's opening pause once per process, so a restarted
  boot would run its clock through the prewarm frames; `demo_village.gd _hold_restart_open` holds PLAYER itself
  and `_open_running` releases it once the first frames are drawn.

### 5. The Demo Lab (`godot/demo/ui/demo_lab.gd`)

The four test triggers leave the panels and live only in the Lab — F8, or the menu's "Demo Lab" (which closes
the menu and its pause). Each is the same `on_action(ACTION_*)` its panel button called, so its behaviour is
unchanged; the panels' `ACTION_*` constants stay for that dispatch. Cramp is disabled with "Select a resident in
the water first" while no selected resident is swimming. The Lab is a modal and does not pause. The panels keep
their player-facing forecast, preparedness, rescue and recovery controls (Widen, Brace, Hang lanterns, Repair,
Dive, Swim shortcuts, the bridge builds, the woods' work).

## Why not…

- **…route the Pantry through the shell's workspace (UI-SET-051)?** The shell's workspace is the settlement's,
  with its own pages and scrim; the Pantry, the menu and the Lab are demo pop-ups on demo layers. One demo gate
  over them is smaller and leaves the shell alone but for the Menu seam.
- **…a guard in every world handler?** Eight handlers in five files owned by other groups, each one a place a
  new handler could forget. The gate is one node that runs first.
- **…keep the buttons `FOCUS_NONE` and add hotkeys?** Many actions have no key, and UI §8.2 / REQ-UX-010 want
  focusable, named controls.

## Consequences

- A new demo pop-up that presents as modal must be watched by the gate (`watch_modal`), or it will leak input
  as the Pantry did.
- A new demo panel's buttons should come from one of the factories (or call `Styles.focusable`), and a new panel
  layer must be added to a region to be reachable by F7 and Tab.
- A new demo layout site must read `DemoUiScale.percent`, not `UiLayout.USER_SCALE_100`.
- The main game's Menu still opens New Settlement (the shell's default, untouched): its game menu (UI-SET-078)
  is not built.

## Open

- **The ordinary HUD workspace overlaps two right-column stops at 1280x720.** The Residents roster (L) is a
  non-modal workspace (UI §4.2: the HUD stays live beside it), drawn on the HUD's layer over the demo's right
  column; at 1280x720 it covers two of the column's focus stops, which F7 and Tab can still reach and Enter can
  press. At 1920x1080 it covers none. Skipping stops an open workspace covers is left for later.
- **Esc with keyboard focus in a panel and the notification history open** first gives focus back to the world,
  and only the next Esc closes the history; UI §3 puts the open expansion first.
- **Docstrings in files other groups own** (`tunnel_ext.gd`, `tunnel_works.gd`, `demo_farm.gd`,
  `demo_waterplay.gd`) still name the "(demo)" buttons the Lab replaced, and `demo_waterplay.gd` still passes
  the panel a Cramp enable it no longer reads; left alone to keep this change clear of theirs.

## Evidence

- `godot/test/test_demo_input_gate.gd` (the routing table, the modal stack and scrim, the rings, F7, every
  panel button a focus stop with the ring, the panels free of triggers, the Lab), `godot/test/test_demo_menu.gd`
  (MENU pause and restore through the real GameManager script, pages, confirmations, settings, the interface
  scale, the shell's Menu seam), and `godot/test/test_demo_input_live.gd`, which runs
  `godot/test/live/demo_input_live.gd` in its own process: the real `demo_village.tscn`, real
  `Viewport.push_input` clicks, drags, keys and a forced 1.2 s stall frame, at 1280x720 and at 1920x1080 (where
  it also chooses 125 %, restarts at it, then shrinks the window and watches the scale step down). A separate process because the runner's worker runs every suite in `_initialize`,
  before the root is in the tree, where no Viewport can dispatch input.
- **The headless display server sizes the root to 64x64 on the first frame**, whatever the script set in
  `_initialize`; GUI hit tests then miss everything past 64 px. The live harness holds the size every frame.
  Recorded in `docs/ENVIRONMENT.md`.
- Frames at 1280x720 and 1920x1080 (the Pantry open, the pause menu and its pages, the focus ring on a Woods
  button, the Demo Lab): `-- --capture <dir>` on a windowed run of the harness.
- **Mutation testing**: 65 mutants of the new logic (the gate's routes, modal stack, scrim, rings and focus
  return; the menu's pause, pages and refusals; `set_menu_pause`; the village's wiring, restart hold and scale
  refit; every `DemoUiScale` reading; the Lab; the factories' focus; the shell's Menu seam), one at a time,
  each file restored and its SHA-256 checked: 65 killed. The first run left three survivors -- two filled by new
  live checks (Page Up and an arrow behind the Pantry; focus given back to a control), one dead code (a
  `_unhandled_key_input` swallow no key could reach) removed.
- **Independent review** (code-reviewer): four HIGH findings, all fixed here -- a click's focus took the arrows
  from the camera; the gate stood down entirely under the stall banner; it routed keys to the panels behind
  the HUD's own scrimmed workspace; and it allocated a Focus per input event. MEDIUMs fixed too: Enter pressed
  a button behind a stacked modal, the scale was not re-checked on resize, a refused MENU release hid the menu
  anyway, and several lines had no test.
