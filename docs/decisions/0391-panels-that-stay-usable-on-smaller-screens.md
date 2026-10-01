# 0391 — Panels that stay usable on smaller screens: a party panel that never hides, a Water panel that leads with what matters, a crop picker that stays current, and every demo surface at the interface scale
Date: 2026-10-01 · Status: Accepted

Review group F: findings F20, F31, F12 (with its crop-picker overflow paragraph), F36 and F35 of the live-demo
review (`/Users/brendan/Developer/redwall-review/REVIEW.md`, written against 157a3a4), P1's "Selected resident" and
"Water safety" rows, and two items decision 0261 left open. **Numbered 0391**: the highest record on any branch or
worktree when this was written was 0381, and the review groups take numbers ten apart.

Branch `fix/review-f-panels`, from `integrate/review-batch-2` fe74b95 (master, phase 6, groups B, C, D, E, G, H, I,
J, Q, R).

## Confirmed on this branch first

Groups G, E, H and I had changed these panels since the review, so each finding was measured again on fe74b95 with
the review's own layout probe (real Control rects, visibility and the clip of every clipping ancestor; copied to the
scratchpad as `rv_f_probe/f_probe.gd`):

| Case | 1280x720 | 1920x1080 |
|---|---|---|
| Party, 1 selected: text in view | 153 chars, 3 buttons | 505 chars |
| Party, 6 / 9 selected | **frame hidden: 0 chars, 0 buttons** | 682 / 690 chars, rows capped at 6 + "+ 3 more" |
| Water: swim and bridge actions in view | **0 of 7** (all below the roster) | 7 of 7 |
| Water: button height / text | 29 px / 12-13 px | 29 px / 12-13 px |
| Crop picker: Back exposed / scrolls | **76 %**, 2 nested | 100 %, 2 nested |
| Smallest text in Farm, Woods, Tunnels panels | 12-13 px | 12-13 px |

F36 was confirmed in code: `open_picker()` built the title, reasons and order once; `refresh()` skipped the picker.
F35: G had already moved five layout sites to `DemoUiScale.percent`; the level indicator (`tunnel_view.gd`) still
laid out at 100 %, the action cards' tooltips stayed at 15 px whatever the scale, and the menu offered nothing above
100 % at 1280x720 because the panels could not reflow there.

## Decision

### 1. The party panel never hides (F20, F31)

`control/demo_party_panel.gd` is three parts:

- **Header**: the title and "n selected".
- **Summary and actions**: one line -- a resident's name and state, or a group's common activity tallied most
  first ("Holding ×3 · Digging tunnel ×2") -- cut with an ellipsis and whole in its tooltip; then the actions, always
  in view: **Release (R)** (the R key's own action, `release_selection`, now also a button so a mouse user has it)
  and, with a digger selected, Dig tunnel (B), Burrow home (H), Root cellar (C).
- **Inspector**, a vertical scroll filling the rest of the column: the notice line first (a new notice scrolls back
  to it), then for one resident its species, the command, the progress or step **on its own row** (the state's words
  after " — "), "Then back to:" **with a row per job**, its skills, and its orders **in full** -- each with what to
  right-click; the old compact fold that dropped the target is gone. For a group, **a row for every member** (no "+ n
  more"), each a 32 px button that selects that resident alone and centres the camera on it
  (`demo_command.gd pick_member`, the roster's own rule, decision 0251).

The old `fit()` ladder (drop the hint, then the skills, then fold the orders, then hide the frame) is replaced by one
rule: where the column cannot hold the header, summary and actions **and** `MIN_INSPECTOR_H` of inspector (125 % at
1280x720, a 92 px column at 150 %), the summary and actions move to the inspector's top -- reached by scrolling, never
hidden. Under an open resource ledger the panel moves below it, or, where that leaves less than its fixed part, stays
where it is under the ledger (which draws over it until it closes) instead of hiding.

*Why the notice is in the inspector, not the fixed part:* at 1280x720 with nine selected and a two-line notice the
fixed part left one member row in view; F20 names the count, the order and the actions as what must always show.

### 2. The Water panel leads with what matters (F12, P1 "Water safety")

`waterplay/water_panel.gd`: **pinned** above its scroll -- the title, every resident in difficulty (the rescue
incident's own line, decisions 0231 and 0331) and the selected residents' swimming (two, then "n more selected",
which opens the list). The scroll has **Swimmers** (how many are in the water, the water today, Dive and Swim
shortcuts, and **All residents**, folded until opened, a row per resident that selects and centres) and **Bridges**
(the site, each kind's cost line, the two Build buttons right under them, then ◀ Site / Site ▶ / Span two banks…, the
bridges, stores and news). The cost lines are split out of `site_text` by its own prefixes
(`waterplay_text.gd PLANK_LINE`, `LOG_LINE`); `line(&"site")` still returns the text as given. Every button is at
least 32 px tall with 14 px text and a hover text (the nav buttons and Swim shortcuts gained one); a row of buttons
wraps rather than cutting a caption.

*Why the Builds come before the site's way-finding:* at 1280x720 that is what puts Dive, Swim shortcuts and both
Builds in view without scrolling. Tabs (the review's alternative) would have hidden one section's emergencies and
needed the panel's intents to pick a tab.

### 3. The crop picker stays current, with one scroll (F36, F12's overflow paragraph)

`farm/farm_bed_panel.gd` is a fixed head (title, ×, the picker's title), **one** scroll, and a fixed foot (Back). The
picker's own inner scroll is gone. `refresh()` -- run every PANEL_REFRESH_S and at once on each new hour -- now calls
`refresh_picker()` while picking: the title's date, and each crop's enabled state, card and line, **re-worded in
place**. No row is rebuilt or moved, so a focused crop keeps its focus and the scroll stays; a crop that becomes
sowable is enabled where it stands (the sowable-first order is set only when the picker opens -- reordering live would
move the row under the pointer).

### 4. Every demo surface at the interface scale (F35)

- **The level indicator** (`tunnel/tunnel_view.gd`) reads `DemoUiScale.percent`.
- **Action-card tooltips** (`ui/action_card.gd scale_tooltips`): a tooltip is a pop-up of the viewport, not a child
  of its panel's scaled frame, so it did not grow with the panel. The shared tooltip theme's type and margins are set
  to TIP_PX × S on every resize and scale change (`demo_village.gd _scale_tooltips`, `DemoUiScale.effective_scale`).
- **Scroll at any scale** (`ui/demo_scroll.gd`): the panels draw at S through their frame's `scale`, and Godot's
  `follow_focus` / `ensure_control_visible` mix global and local pixels, scrolling too far at S != 1 (measured: rows
  "revealed" out of view at 125 %). The four new scrolls follow focus with `reveal`, in the container's own pixels.
- **14 px floor** (UI §2.1): `farm_ui.gd SMALL_PX` 13 → 14 (the finding's number); the Woods and Tunnels panels' 12
  → 14; the news strip's title and history button, the incident card's and news window's buttons, and the stall
  banner's diagnostic line 13 → 14. **32 px floor** (UX-T03) on every Farm, Pantry, Woods, Tunnels, Water and party
  button.
- **The menu offers 125 % at 1280x720.** `demo_village.gd MIN_LOGICAL_HEIGHT` 720 → 576. At 576 logical rows (the
  narrow profile) every demo panel reflows or scrolls, the news strip takes the gap between the minimap and the right
  column where the centred band would be narrower than `MIN_W` (it had no width there), the Map layer picker keeps
  clear of the right column (a third slot, right of the minimap) and scrolls its list and card in a short slot, and
  the incident card narrows to the gap between the side columns with its buttons wrapping. **150 % at 1280x720 stays
  refused**: at 480 rows the news strip and the picker have no room apart. Decision 0261's rule is kept, with the new
  floor; a 150 % chosen full screen now steps down to 125 % at 1280x720.

**"200 %"** is not a UI §1.2 user scale (1.00 / 1.25 / 1.50; `UiLayout` refuses any other), so it was tested as an
*effective* scale S = 2: 2560x1440 at 150 % (and 3840x2160 at 100 % in the unit tests).

### 5. G's two leftovers

- **Covered stops** (`ui/demo_input_gate.gd occlude_with`, `covered`): the village names the shell's ordinary
  workspace's rectangle; a region control it covers is no F7/Tab stop, and Enter or Space on one already focused
  drops the focus and goes on (as from a click's focus) instead of pressing it. At 1280x720 the Residents roster
  covers right-column buttons; the live harness checks none is landed on.
- **The Map layer picker is an F7 region**: world → right column → left column → map layers → world.

## Why not…

- **…keep the party panel's fold ladder and add a scroll only for groups?** The ladder's last step hid the frame, and
  its fold dropped the orders' targets -- both are what F20 and F31 forbid.
- **…a separate "selection summary" widget elsewhere on the HUD?** UI §1.2 leaves only the left column free; a
  second surface would have to take room from the minimap band.
- **…scale the demo panels through a canvas transform instead of each frame's `scale`?** It would change every
  panel's placement code (seven files other groups own) for the same result; `demo_scroll.gd` fixes the one thing the
  frame scale broke.
- **…offer 150 % at 1280x720 too?** Tried: the frames were captured. The news strip and the picker overlap there, and
  the party column is 92 logical px. The spec's narrow profile closes the detail drawer by default, which the demo's
  always-open right column does not.

## Measurements after

Same probe, same scene (staged assets), 100 %:

| Case | 1280x720 | 1920x1080 |
|---|---|---|
| Party, 1 selected | 182 chars in view, 4 buttons (Release, Dig, Home, Cellar) all in view; the rest in the inspector | 336 chars in view (the rest one scroll away), 4 buttons |
| Party, 6 / 9 selected | **frame shown**: 232 chars, Release + tools in view, 6 / 9 member rows each reachable | 704 / 797 chars, all 10 / 13 buttons in view |
| Water: Dive, Swim shortcuts, both Builds in view unscrolled | **4 of 4** (site way-finding one scroll away) | 7 of 7 |
| Water: buttons / text | 32 px / 14 px | 32 px / 14 px |
| Crop picker: Back exposed / scrolls | **100 %**, 1 | 100 %, 1 |
| Smallest text in the demo panels | 14 px | 14 px |

At 125 % (1280x720), 150 % (1920x1080) and S = 2 (2560x1440 at 150 %) every party member row, every Water action,
the picker's last crop and the orders list are reachable by scrolling and Back is always in view
(`test_demo_layout_live.gd`).

## Evidence

- `godot/test/test_demo_panels_fit.gd` (new): the Water panel's pinned selection, folded roster, row picks, split
  costs and floors; the crop picker crossing Spring 4 → 5 with the real calendar (wheat refused with its reason, peas
  sowable, today's date, the same rows and buttons); one scroll, a fixed title and Back; pick rows; `pick_member`; the
  bottom band, picker and incident card at every offered size and S = 2; the gate's covered stops and Enter; the
  tooltip scale.
- `godot/test/test_demo_command.gd` (updated): every member listed, the dock rule, command/progress rows, the group
  tally, member rows that pick, the ledger rule, "Then back to" as rows.
- `godot/test/live/demo_layout_live.gd` + `test_demo_layout_live.gd` (new): the real scene at 1280x720, 1920x1080 and
  2560x1440, each at 100 / 125 / 150 % where offered (a refused size is checked refused and stepped down): 1, 6 and 9
  selected with a notice, the Water panel, the picker, the 14 px and 32 px floors, every surface's scale, and the
  picker, news strip, card and columns apart. Passes on placeholders too (six residents).
- `godot/test/live/demo_input_live.gd` (extended, decision 0261's harness): the workspace covers no stop; a real
  drag box-selects a group at 1280x720 and the party panel shows it; a real click on a member row selects and centres;
  a real click on Swim shortcuts, in view unscrolled; the picker open across a real Spring 4 → 5 boundary keeps its
  focus and scroll; 150 % chosen at 1080p steps down to 125 % at 1280x720.

## Consequences

- A new demo panel that scrolls should use `ui/demo_scroll.gd`, or Tab focus will scroll it wrongly at 125 % and
  above.
- A list of residents in a demo panel should use `ui/demo_pick_row.gd` and `demo_command.gd pick_member`.
- The party panel's entries carry an `"index"` (the cast index a member row selects). Group N's fed-state lines can
  join the one-resident rows (`party_lines`) or the skills.

## Open

- **150 % at 1280x720** stays refused (see §4).
- **The Woods, Tunnels and Pantry scrolls** keep Godot's own focus following (not this group's panels); at S != 1
  Tab may scroll them too far. `demo_scroll.gd` is the fix when they are next touched.
- **At 125 % on 1280x720 an incident card draws over the Map layer picker** while it shows: both use the gap
  between the side columns (the card is on its own layer above the panels; Snooze or Dismiss clears it). Seen in the
  frames, not asserted.
- **The news strip is as tall as its lines, not its band**: with several warnings at 1280x720 it grows up over the
  Map layer picker (seen in the frames after four game days; decision 0331's strip, pre-existing).
- **The HUD's own command strip** truncates "Residents" and "Objectives" at the narrow profile (the shell's layout).
