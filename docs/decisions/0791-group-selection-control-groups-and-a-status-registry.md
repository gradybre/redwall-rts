# 0791 — Group selection: control groups, a group section and a status registry
Date: 2026-10-01 · Status: Accepted (P1–P10 ruled by Brendan, 2026-10-01: as built)

Numbered 0791 because the brief for feature #58 assigned 0791–0799. No record numbered 079x exists on any branch
(`git log --all -- 'docs/decisions/079*'`) when this was written.

## Decision

The live demo gets **group selection**, on top of the select-and-command layer (decision 0196), which still owns picking,
the box, Shift and every order. New code in `godot/demo/control/`:
`group_select.gd` (controller), `group_panel.gd` (widgets), `group_status.gd` (status registry) and `control_groups.gd`
(pure group store).

What already existed and is kept as it was:
- box selection by left drag, with Shift adding;
- Shift+click toggling one resident;
- right-click move and work orders;
- the party panel's group rows (decision 0391).

What is added, from the documents:

1. **Control groups** (UI §5 `group_assign_0..9`, `group_recall_0..9`, `group_center_0..9`; §5.2).
   - Ctrl+digit keeps the selection as that group, by cast index. The demo's cast index never changes, so it stands in
     for "persistent IDs".
   - The digit selects the group again and says how many were selected. Members the cast no longer has are dropped
     from the group for good.
   - The same digit twice within 300 ms also eases the camera to the middle of the members' bounding box.
   - The input map's existing actions are read with exact matching, so Ctrl+3 is never also a recall.
   - The UI doc specifies 0–9, not 1–9, so all ten are built.
2. **Select visible similar** (UI §5 `select_similar`): a double left click within 250 ms on a resident selects every
   resident of its species in view. The cap is 256. Following §5's "a double-click replaces its result", it gives no
   order.
3. **"Selecting residents: n"** (UI-SET-025's accessible value) sits beside the box while it is dragged. It counts with
   `select_box`'s own test (`demo_command.gd box_into`), so the number shown is the number selected.
4. **The group section.** With two or more residents selected, the Demo party panel's inspector shows a section right
   after the notice line (`demo_party_panel.gd add_section`):
   - **Doing:** the party panel's own activity words, tallied, and never cut.
   - **Needs attention:** the warning rows the members hold, each as "word ×n — names", or "none".
   - **Notes:** the note rows, after the warnings.
   - **Idle:** who is idle, or "Idle: nobody".
   - **A tile per member.** Each tile shows the resident's colour, first name, and first warning, else its activity's
     first word.
   - **Crews:** a tally, and five crew buttons. One press puts every member on that crew (`work_crews.gd set_crew`).
     A crew all members are already on is disabled.
   - **Send to…** arms the next left click on the world as the group's move or work order. It waits only while two or
     more are selected and the surface view is shown: it ends when the selection drops below two, when the U view opens
     (where it cannot start: the U view gives its clicks to the tunnels, so the notice says to right-click), on Esc, and
     on a right click (which gives its own order as ever). The wheel and other buttons leave it waiting, and its prompt
     is cleared when it ends.
   - **The control-group line.**
5. **Select idle (n)** is a button under the party panel's actions, shown whether or not anything is selected.
   - It selects every resident the Work screen calls **available**: not resting, not in the water, and under no order,
     task or job (`work_crews.gd status_of`).
   - UI §5 has no key for it, so it has none.
6. **The status registry** (`group_status.gd`): **new statuses appear by data.** A status is a row of id, word, severity
   (WARN or NOTE) and `query(actor_index) -> bool`. The query must be the owner's existing read and change nothing.
   - The panel has no code for any one status. It lists warnings first, then notes, each in the order added.
   - It names a member's first warning on its tile, with a clay edge.
   - It re-reads at most four times a second, and redraws only when something changed. A status that comes or goes
     between redraws is caught, because each member's held rows are part of the change check.
   - The rows built in:
     - **Idle** (NOTE): crews' "available".
     - **Can't get there** (WARN): holding after a refused trip, the party panel's own condition.
     - **Hungry** (WARN) and **Peckish** (NOTE): `kitchen.fed_word`, `meal_rules.gd FED_WORDS`.
     - **No bed** (NOTE): `night_routine.gd bed_of`.

**How a concurrent owner adds its status** (winter fuel's Chilled, the infirmary's injuries). Add one line where the
owner is wired in `demo_village.gd`, after `_build_work()`:

```gdscript
group_select().statuses.add(&"chilled", "Chilled", GroupSelectScript.GroupStatus.SEVERITY_WARN, winter.is_chilled)
group_select().statuses.add(&"injured", "Injured", GroupSelectScript.GroupStatus.SEVERITY_WARN, infirmary.is_injured)
```

Nothing in the group section, the party panel or the single-resident card changes. The single-resident card was not
edited; the live harness checks a row added this way end to end.

## Why

- **Placement.** UI §1 puts selection commands bottom-centre and entity detail bottom-right. Neither is free in the
  demo:
  - the command strip is the shell's single row of seven commands (decision 0199);
  - UI-SET-036 is the resident journal;
  - the right column holds four tabbed panels (decision 0196).

  The demo's selection surface has been the left-column party panel since decision 0391, so the group section joins
  it there.
- **Tiles are not portraits.** The demo has no portrait art. The journal's medallions are generic species marks that
  "must never read as a portrait" (ART-UI-06), and they cover only four species. True portraits would need new art.
- **Idle = "available".** One definition, shared with the Work screen, so the two never disagree.
- **Rejected:**
  - a per-status code path in the panel, which would make every new status a panel edit;
  - reading the single-resident card's text, which is presentation and would break as the card changes.

## Consequences

- **Shared surface:**
  - `demo_command.gd`: `drag_rect`, `box_into`, both read-only;
  - `demo_party_panel.gd`: `add_top_row`, `add_section`;
  - `demo_village.gd`: `_build_group_select` and `group_select()`.
- **Inputs now consumed:**
  - Ctrl+0–9, 0–9 and a double left click. These are the input map's existing actions; no binding was added.
  - While Send to… waits, its left click and Esc.
- **Not built:**
  - UI-SET-088 cycle selection: Tab already moves focus in the demo (decision 0261).
  - Group numbers on the selection rings, and the primary double ring.
  - UI-SET-025's INK/GOLD box tokens: the box keeps decision 0196's woodland style.
  - The occluded-selection setting.
  - The world list's Shift+arrows and Ctrl+Enter.
- **Gate:** the live harness `test/live/demo_select_live.gd` (through `test/test_demo_select_live.gd`) checks all of
  the above at 1280x720 and 1920x1080, including each built-in status driven through its owner's own state.
- **The layout harness** (`test/live/demo_layout_live.gd` `_dock_keeps_focus`) now puts the party panel back with its
  real placement (`_place`) after forcing `fit(4000)`. The forced fit set the inspector to its whole content height, which
  ran off the screen once the group section made a nine-resident inspector taller than the view.

## Brendan's rulings on P1–P10 (2026-10-01)

The documents were silent on these ten points, so each was built as the smallest sensible demo behaviour and proposed.
**Brendan approved all ten as built on 2026-10-01.** The options considered are kept below for the record.

- **P1 — a tile's click.** It centres the view on that resident and keeps the group. Shift+click drops the resident from
  the selection. The party panel's member rows still select one alone.
  - Options: (a) as built; (b) select alone, like the rows; (c) make it the "primary" resident (UI §5.2).
  - **Ruled: (a), as built.**
- **P2 — Ctrl+digit with nobody selected** keeps the group as it was, and says so.
  - Option: clear the group.
  - **Ruled: keep, as built.** A stray Ctrl+digit should not wipe a group.
- **P3 — recalling an empty group** leaves the selection alone and says how to fill it. Read literally, "replace
  selection" would clear it.
  - **Ruled: keep, as built.**
- **P4 — what "idle" means.** It is the Work screen's "available".
  - Option: the work board's narrower `idle()`, which also excludes residents underground, indoors, crossing, on a
    queued walk or at a meal.
  - **Ruled: "available", as built.** It is the word the player already sees.
- **P5 — Select idle** is a button with no key, because UI §5 has none.
  - Options: (a) as built; (b) also make UI-SET-006's "n idle" readout select them.
  - **Ruled: (a), as built**, until the UI doc assigns a key.
- **P6 — need severities.**
  - Hungry and Can't get there are warnings. Peckish and No bed are notes.
  - **Ruled: as built.** "Peckish" is meal_rules' ordinary between-meals state.
- **P7 — Send to…** is a demo button. It arms the next left click as a move or work order, the same as right-click.
  UI §5 has only `command_context` (right-click or C).
  - Options: (a) keep, for discoverability; (b) drop it.
  - **Ruled: (a), keep for the demo, as built.**
- **P8 — placement.** The section sits in the left-column party panel, not bottom-centre or bottom-right (see Why).
  - **Ruled: keep for the demo, as built.** The game's UI-SET-026 and UI-SET-036 own it later.
- **P9 — Ctrl on macOS.** The UI doc and input map say Ctrl+0–9. macOS's "Switch to Desktop n" shortcuts use Ctrl+digit
  when they are turned on.
  - Option: Cmd via `command_or_control_autoremap`.
  - **Ruled: keep Ctrl** per the doc, as built. Revisit when rebinding lands.
- **P10 — crew moves apply at once**, with the change described in each button's tooltip (its action card). This
  matches the Work screen's ◀ Crew ▶. Presets are previewed, but they change every crew.
  - **Ruled: keep, as built.**

## Source

- `docs/ui_ux_controls.md`: §1 (zones), §4.1 (UI-SET-006, UI-SET-025, UI-SET-026, UI-SET-036, UI-SET-088), §5 (input
  table), §5.2 (selection feedback and group recall).
- `docs/game_gdd.md` §4: selection flags are presentation and are not saved.
- `godot/project.godot [input]`: the `group_*` and `select_*` actions.
- `work_crews.gd`: crews and "available".
- `meal_rules.gd`: fed states.
- `night_routine.gd`: beds.
- Brendan approved feature #58 on 2026-10-01, and ruled P1–P10 as built the same day.
