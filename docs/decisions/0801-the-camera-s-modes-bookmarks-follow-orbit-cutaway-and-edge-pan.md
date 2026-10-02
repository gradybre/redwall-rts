# 0801 — The camera's modes: bookmarks, follow, orbit, the cutaway angle and the edge pan
Date: 2026-10-01 · Status: Accepted (adopted rules; Brendan ruled on every proposal, 2026-10-01)

Numbered 0801: feature #60 (the camera revamp, approved by Brendan on 2026-10-01) was given 0801–0809; none was taken on
this branch.

## Brendan's rulings (2026-10-01)

Brendan approved all eight recommendations below (P1–P8), each as option (a) / the recommendation:

| | Ruling | Built |
|---|---|---|
| P1 | Bookmarks on Ctrl+Shift+1..4 (save) and Shift+1..4 (recall) | as first built |
| P2 | Four slots, the camera pose only, for the session (through Restart), never on disk | as first built |
| P3 | Orbit on Shift+O round the building nearest the view's centre; turns on, steadily, under reduced motion | as first built |
| P4 | The cutaway angle on Shift+U, never automatic on U | as first built |
| P5 | Keep the strip where the news cannot cover it | **moved** (below) |
| P6 | An Edge scroll toggle in Settings, on by default | **added** (below) |
| P7 | No gamepad bindings | as first built |
| P8 | A "Follow (End)" button in the party panel | **added** (below) |

- **P5, the strip's row.** The strip left the top-centre column (where, at 1280x720 in the U view, the Map layer
  picker and a three-line village news crowd it) for its OWN ROW at the bottom centre: its bottom 6 logical px above the
  command strip, centred on the news' band (`demo_news_strip.gd band_placement`, so it follows the commands when the
  journal moves them) and moved in to stay between the minimap and the right column. The news gains one hook, `lift`:
  while the strip shows, the news stands on top of the strip's row (`camera_strip.gd reserved_height`). The live harness
  checks, at 1280x720 and 1920x1080, surface and U view, that a three-line news ends above the strip. Consequence: at
  1280x720 a three-line news then reaches up over part of the collapsed Map layer picker (it already overlapped it by
  30 px before; now by 74 px while the strip shows).
- **P6, Edge scroll.** `demo_access.gd` SET_EDGE_SCROLL ("Edge scroll", default on: UI §8.1 `edge_scroll`, "On mouse";
  the demo has no trackpad preset), under a new "Camera" heading in the menu's Settings; Restore defaults turns it back
  on; no preset touches it. `edge_pan.gd` reads it live.
- **P8, Follow (End).** The party panel's actions show "Follow (End)" beside Release (R) whenever anyone is selected; it
  asks the modes to toggle the follow (`follow_requested` → `camera_modes.toggle_follow`) and reads "Stop following
  (End)" while the camera follows (`camera_modes.follow_changed` → `demo_party_panel.set_following`).
- The pause card is untouched (a separate fix).

## Decision

The live demo's camera gains four modes over its RTS rig (`godot/demo/camera/demo_camera.gd`), all presentation and
none reaching the simulation (UI §6: "The camera remains a presentation service, never an entity-state writer";
REQ-SET-181; REQ-SET-004 and UI §6: it works while paused, on real time):

| Mode | Key | File |
|---|---|---|
| Follow the selected resident | End (UI §5 `camera_follow`, adopted) | `camera/camera_modes.gd` |
| Bookmarks 1–4 | Ctrl+Shift+1..4 save, Shift+1..4 recall — PROPOSAL P1 | `camera/camera_bookmarks.gd` |
| Orbit a building | Shift+O; Esc or Shift+O stops — PROPOSAL P3 | `camera/camera_modes.gd` |
| The U view's cutaway angle | Shift+U; again for your angle back — PROPOSAL P4 | `camera/camera_modes.gd` |
| Edge pan | the pointer at a window edge (UI §6, adopted) | `camera/edge_pan.gd` |

A strip (`camera/camera_strip.gd`), the U view's level indicator's twin, says which mode is on and what a bookmark key
did, under whatever else stands in the top-centre column.

The rig gains hooks and nothing else changes for the player: `track` (the follow) and `aim` (bookmarks, orbit framing,
cutaway) move its targets without counting as the player's pan; `pan_revision` / `turn_revision` count the player's own
pans (held keys, the edge, `centre_on`, Home) and turns (Q/E, the middle drag), which is how a follow or an orbit learns
the player took over; `set_edge_push` adds the edge pan to the held keys.

## Rules used (adopted)

- **UI §5 `camera_follow`** — "End · Toggle following primary resident; manual camera movement cancels follow". The
  primary resident is the command layer's `first_selected`. "Manual camera movement" is read as a *pan*: UI §5's pan row
  calls the pan "camera movement", and §5 keeps rotate, zoom and pitch as separate rows. So a pan ends the follow; Q/E,
  the wheel and a tilt do not (the player can frame the one they follow).
- **UI §6 reduced motion** — "Camera smoothing off; movement still continuous and user-controlled". With reduced motion
  a follow holds its resident with no lag, and a bookmark, the orbit's framing and the cutaway angle land at once.
- **UI §6 edge scroll** — "12 logical pixels; 250 ms dwell; default enabled with mouse", and "disabled while pointer is
  over any visible UI hit rectangle, during a modal, text editing, placement drag, or when the application lacks
  focus". A held mouse button stands for "placement drag" (it covers the Dig tool's drag, the box select and the middle
  drag). The pointer having left the window also turns it off (otherwise a pointer last seen at an edge pans forever).
  Logical pixels are UI §1.2's (S = base × user scale), so the band is 12 px at 720p and 1080p and 24 px at 4K.
- **UI §5 pan** — "diagonal normalized": the rig's held pan was not; it now is (W+D is no faster than W). The edge push
  and the keys together are no faster than either.
- **UI §6 drag-pan** is "distance×0.0015 m per physical pixel divided by S". The demo's middle drag (decision 0205) is a
  turn, not a pan, but it now divides by S the same way, so the same sweep turns as far at 4K as at 1080p.
- **UI §5's other bindings** decide what the bookmarks may not take: F1–F3 speeds, F4 roof mode, F5/F9 quicksave and
  quickload, F6 the world list, Ctrl+0..9 / 0..9 the control groups (bound in `project.godot` though the demo reads none
  of them yet). F7 and F8 are the demo's (focus, Lab), F11 full screen. UI §5: "No two enabled actions may share a chord
  in the same context."
- **The canopy files are untouched** (`canopy_fade.gdshader`, `canopy_clear.gd`, `canopy_math.gd`); every mode's eye
  still goes through the rig's clearance. **The U view's lights and environment are the tunnels'** (`tunnel_view.gd`);
  the cutaway changes the camera only.

## Checked and found consistent (720p and 4K)

The rig keeps one 40° vertical field of view with `KEEP_HEIGHT`, so a view frames the same at every 16:9 size (the live
harness unprojects the hall at its size and at 3840x2160: the same screen fraction). Zoom limits are metres (7–70 m), the
easing is `1 - exp(-rate·dt)` (frame-rate independent), and the edge band and the middle drag are in logical pixels.

## The proposals as put (all approved; see Brendan's rulings above)

Each was the smallest sensible demo behaviour where the documents are silent.

- **P1 — Bookmark keys: Ctrl+Shift+1..4 save, Shift+1..4 recall.** UI §5 names no camera bookmark. F1–F4 (the usual
  RTS choice) are UI §5's speeds and roof mode, and macOS keeps Ctrl+F1–F4 for its keyboard access (Ctrl+F1 turns it on,
  Ctrl+F2 the menu bar, ...). Digits sit beside the control groups (Ctrl+0..9 / 0..9) as a modified chord; the digit is
  matched by its physical key, so an AZERTY keyboard's Shift (which gives digits there) still works.
  Options: (a) this, recommended; (b) F1–F4 / Ctrl+F1–F4 with the speeds moved off F1–F3 — an amendment to UI §5;
  (c) Alt+1..4 / Ctrl+Alt+1..4 (AltGr on European layouts is Ctrl+Alt, so (c) types characters there).
- **P2 — Four slots, session only.** A bookmark is the camera's target centre, heading, pitch and distance (not the
  U view or level). They live in static columns, so they last the session and through Restart demo, never on disk (UI §5
  names no bookmark to save; the demo saves nothing). Options: (a) this, recommended; (b) nine slots on 1..9; (c) also
  remember the view (surface / U and level).
- **P3 — Orbit: Shift+O, "the building in view".** The demo cannot select a building (the settlement's building
  selection is not built), so the orbit takes the village building nearest the view's centre within 12 m (else the
  centre itself): 35° down, from a distance fitted to its size (12–40 m), turning 6° a second. Esc, Shift+O, a pan, a
  turn (Q/E or a sideways middle drag), a bookmark or End stop it; zoom and tilt (Alt+PgUp/PgDn or a vertical middle
  drag) adjust it. Esc keeps UI §3's dismissal ladder, one layer a press: an open pop-up or panel, then the Dig tool's
  piece and then the tool, take it first; the orbit's stop comes next (the command layer's input hook, after the tools
  and before the selection), then clearing the selection, then the game menu. With
  reduced motion it still turns, steadily — it is the requested motion, with no ease to remove. Options: (a) this,
  recommended; (b) orbit the selected resident or room as well; (c) under reduced motion, do not turn at all.
- **P4 — Cutaway: Shift+U, 65° down over the network.** Frames at 50°, 58°, 62°, 65°, 70° and 75° over a dug bore were
  compared: at 50° the far wall hides the floor; from 65° the floor, the residents and a find read clearly while the
  walls still give depth, and 65° is UI §6's steepest pitch. The centre is the middle of the network on the level shown
  (its nodes' box), at a distance fitting it (×1.3 margin, at least 18 m); no network keeps the centre and distance.
  Shift+U turns the U view on if it is off; Shift+U again, or leaving the U view, gives back the pitch and distance you
  had. It is a key, not automatic on U, so entering the U view (and the Dig tool, which opens it) never moves a camera
  the player set. Options: (a) this, recommended; (b) apply it automatically whenever the U view opens.
- **P5 — The strip's place.** Top-centre, under the lowest of the level indicator, the guide's or an incident's card, the
  pause card and (at 1280x720, where it sits there) the Map layer picker; on the indicator's canvas layer, under the
  HUD's panels. At 1280x720 in the U view the village news panel can still cover part of it.
- **P6 — Edge pan on, no Settings toggle yet.** UI §8.1 has `edge_scroll` (on with a mouse, off with the trackpad preset);
  the demo has no input preset, so it is on. A Settings toggle would touch the shared accessibility settings and is left
  for a ruling: (a) add the toggle to the menu's Settings, recommended; (b) leave it on.
- **P7 — No gamepad bindings.** UI §1 says "Mouse+keyboard; Mac trackpad equivalents; no controller-only release claim",
  and UI §5 has no gamepad column, so none was added.
- **P8 — A mouse way to follow.** UI §5 gives `camera_follow` a "Detail title context action" for the mouse; the demo's
  party panel is shared and was not touched. Recommended: a "Follow (End)" button in the party panel's actions.

## Consequences

- `camera_modes.gd` reads its keys in `_unhandled_input` (Esc during an orbit through `demo_command.add_input_hook`) and
  none while a modal or the HUD's scrimmed workspace holds the input. A new binding on Shift+O, Shift+U, End or
  Shift/Ctrl+Shift with a digit must move these first.
- When the control groups are built they must match their actions EXACTLY (`is_action_pressed(..., false, true)`):
  Godot's inexact match lets Shift+1 match `group_recall_1` and Ctrl+Shift+1 `group_assign_1`.
- Anything that calls `centre_on` is the player's pan and ends a follow. A future automatic camera move must use `track`
  or `aim` instead, or it will break the follow.
- The canopy clearance, the selected x-ray and the listener all read the same rig, so they follow every mode.

## Source

`docs/ui_ux_controls.md` §1, §1.2, §5 (input map), §6 (camera contract), §8.1 (settings); `docs/game_gdd.md`
REQ-SET-004, REQ-SET-181; Brendan's approval of feature #60 (2026-10-01); frames in the feature's check folder.
