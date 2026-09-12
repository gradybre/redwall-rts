# 0086 — The resident journal shows percent needs, a species medallion and real panel frames
Date: 2026-09-12 · Status: Accepted

## Decision

Three queued items on `ui_shell.gd` are closed together, because all three land
in UI-SET-036 and would have collided as separate changes.

1. **UXV-020/021.** The resident card no longer prints `Hunger 7500 of 10000`.
   `scripts/ui/ui_resident_card.gd` is a new composer that converts the store's
   0–10000 basis points to an exact percent in integer arithmetic, labels the
   hunger column **`Fullness`** without inverting its value, and renders five
   independent need rows, each with a label, an exact percent, an 8 px track and
   a signed per-simulated-hour rate.
2. **ART-UI-06/09.** The four illustrated species medallions in
   `godot/ui/emblems/` are loaded and drawn at ART-LOCK-001's 48/64 px
   production sizes. The 24 px reduction is *not* offered; a species with no
   delivered medallion gets none rather than borrowing the mouse roundel.
3. **ART-UI-01/02.** `godot/ui/ui_frame_builder.gd` is called. The five framed
   containers wear their own silhouettes. `_apply_frame_art()` and
   `_add_frame_piece()` are **deleted** from `ui_shell.gd`.

## Why

**The percent conversion is exact and integer-only.** 0–10000 over 100 is exact
in two decimals, so `percent_text()` divides and takes a remainder rather than
formatting a float: 7500→`75%`, 7501→`75.01%`, 7510→`75.1%`, 10000→`100%`. A
property test round-trips all 10001 values. A mutation that printed the raw basis
points again fails seven tests.

**`Fullness` is the word, and the number is not inverted.** SET-UX-VIS-002 §5:
"Fullness is satisfaction, not severity; do not fill 25% for 7500." The store's
`hunger` column rises when a resident is fed, so a high value is a full resident.
The field name `hunger` reaches the player through the row's accessible
description, which is §5's "Hunger/fullness in accessible detail".

**Only one of the five rates is published, and the other four say so.**
`needs.gd` computes all five effective rates in the private `_fill_need_rates()`
and publishes exactly one reader, `hunger_rate_milli_per_hour(size_class)`, with
the size and winter multipliers already folded in. That is enough for Fullness,
whose effective rate depends on nothing else. Rest, comfort, social and purpose
depend on `_activity`, `_comfort_environment`, `_social_paired` and
`_purpose_source` — four columns with a setter and **no reader**. Printing the
baseline decay for them would be "the baseline formula as a universal answer",
which §5 forbids by name: a resident asleep in a bed would be shown losing rest.
So those rows print §5's own `Rate unavailable`. **This is an unfulfilled binding
requirement against `scripts/core/needs.gd`**, not a UI decision, and this task
does not own that file.

**The frames are placed explicitly, and the two earlier attempts are deleted
rather than kept.** Both used
`set_anchors_and_offsets_preset(..., PRESET_MODE_MINSIZE)`, which sizes from
`get_minimum_size()` and not `get_combined_minimum_size()`, so
`custom_minimum_size` was invisible, every offset was written as 0, and each
piece inflated outward from a zero rect along `grow_horizontal`/`grow_vertical`.
Keeping dead code that documents a fixed bug is a trap for the next reader; the
reasoning is preserved here and in `ui_frame_builder.gd`'s own header instead.
The holder is moved to child index 0 so relief draws under the panel's controls
— the command dock's corners are 22 px and its content inset is 12.

**`_refresh_frames()` exists because `resized` never fires off-tree.**
`Control.set_size()` only runs `_size_changed()` inside a tree, so the builder's
`resized` follow is dead under `--script` and in the headless suite.
`_place_zones()` therefore calls `UiFrameBuilder.refresh()` for each panel.

## What is deliberately NOT built

* **UXV-023's Center view.** §4.1 asks for a 44-high Center view in a 64 px
  footer. Its semantics belong to UI-SET-037 ("click center-camera") and
  `ui_availability.gd` records `REASON_NO_WORLD_CAMERA`: "the interface binds no
  camera". Building it needs an invented registry row *and* an invented camera
  binding. Neither is invented; the gap is reported.
* **UXV-019's age.** `residents.gd` has no age or birth column. `arrival_tick` is
  an arrival, not an age, and is not relabelled as one. The card states
  `Age unavailable: no age or birth field exists`.
* **`ART.FRAME.JOURNAL.RING` and `ART.FRAME.JOURNAL.STRAP`.** Neither has a
  declared anchor in `ui_art.gd`; the builder places neither and no anchor is
  invented for them.
* **A neutral identity mark for the twelve species with no medallion.** §2.3 asks
  for one; no such asset is delivered. Those residents show readable species text
  and no roundel.

## Two width conflicts, raised and not resolved here

Both are between §4's control table and SET-UX-VIS-002 §4.1's panel anatomy, and
both are recorded in the code at the site that has to live with them.

1. **UI-SET-037's 280 px minimum width cannot sit beside a medallion.** §4.1 adds
   20 px side insets, a top-right Close and a generic emblem. The narrow detail
   column leaves `320 − 40 − 48 − 12 − 32 − 8 = 180` for a control whose §4
   minimum is 280, and even the 384 wide column leaves 244. A Control clamps its
   own size *up* to `custom_minimum_size`, so placing the heading beside the
   emblem at 180 would silently widen it to 280 and draw it straight through
   Close. `_place_detail_header()` therefore asks whether the row can hold the §4
   minimum and drops the heading to its own full-width line when it cannot. In
   this milestone it always drops: **the roundel leads the card above the name
   rather than beside it.**
2. **UI-SET-039's 280 px minimum exceeds the narrow scrolling interior.**
   `320 − 2×20 − 16` (UI-SET-094's own minimum width) is 264. The row keeps its
   §4 minimum and lays its contents inside a usable width that reserves the
   scroll gutter at every profile, so nothing is ever clipped.

## Consequences

* `set_detail_display()` now means *heading, secondary line, supporting line* and
  RESETS the resident-only block. A tile selection can no longer be shown under
  the previous resident's percentages.
* UI-SET-039 is built as five instances of one registry definition, the pattern
  UI-SET-069's roster pool already uses. Only instance 0 is in `_controls`, so
  the focus order, the hit table and the availability claim still see one
  UI-SET-039.
* UI-SET-036's body is a `ScrollContainer`; the header and Close are pinned.
* UI-SET-100's zone harvesting policy is hidden unless `select_zone()` has been
  called with a real zone (UXV-023). It used to stand under every resident's
  needs, where pressing it could only refuse with `UI_SHELL_NOTHING_SELECTED`.
* The roster row formats health through the same `ui_resident_card.gd` function
  the journal uses, rather than a second copy of the rule. The duplicate had an
  unreachable refusal branch that survived mutation because `refresh_roster()`
  only calls it for a slot already found alive.

## Two regressions this work found and did not fix

Both arrived with the `origin/master` merge and both are outside these three
items. They are recorded here and in the evidence README because the captures
show them.

1. **UI-SET-103's Create refuses in the running game** with
   `WORLD_FOREIGN_LIVE_ROWS / generation refused during preflight`.
   `ui_world_session.create_with_cohort_into()` follows R-INIT-ID-001's
   `preflight -> reset -> seed -> cohort -> publish`, so preflight runs before
   the reset and sees boot's own cohort as live rows the plan does not own. Its
   refusal also says "The settlement is now empty", which is false on this path.
   The ordering belongs to R-INIT-ID-001's owner, not to this task.
2. **The top-left `Food-days` and `Residents` counters read `--` after boot**
   although `EconomySystem.food_days_text()` returns `5.48` and
   `has_residents()` returns true. `main.gd` binds the residents store after the
   last `stocks_changed` emission and nothing repaints the counters afterwards.
   Earlier evidence hid this because its harness pressed Create, whose
   `_refresh_hud()` repainted them.

## Source

`docs/ui_visual_refinement_amendment.md` §4.1, §5 and UXV-019…024;
`docs/design/ui_refinement/asset_generation_lock.md` §5 and its medallion frame
section; `docs/ui_ux_controls.md` §4 rows UI-SET-036…040, 093, 094, 100;
GDD §5.1 (spawn needs 7500, health 100), §5.2 (hunger 250 milli-points/hour,
size ×1000/1200/1600, winter ×1200) and §5.3 (level L at 5000·L²).
Native captures 15–17 in `docs/validation/evidence/ui-refinement/`.
