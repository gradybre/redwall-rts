# 0057 — The UI shell renders §4's registry, and refuses to imply more than it drives
Date: 2026-09-11 · Status: **Accepted** ·
Closes: bullets 1 and 2 of `docs/tasks/04_world_commands.md` §04.4, and the first-playable
visual direction in `docs/planning/ui_visual_direction.md` ·
Depends on decisions [0043](0043-command-dispatch-commits-per-kind-schemas.md),
[0048](0048-world-generation-anchors-and-what-it-refuses-to-invent.md),
[0049](0049-source-intent-is-recorded-on-what-it-produced.md),
[0052](0052-resource-ids-are-compiled-item-definition-keys.md)

## Decision

`scripts/ui/` now holds a §4-driven HUD: a transcribed element registry, §1.2's layout
arithmetic, §2's palette and a generated Theme, the click-through table, §8.2's focus order,
the command bridge and the New Settlement session. `hud.tscn` hosts it, `ui_manager.gd` feeds
it committed state and routes its actions, and the world opens **paused for inspection**.

**42 of §4's 103 elements are driven by real state. The other 61 are drawn DISABLED with the
name of the owner they are waiting for.** That split is a table in `ui_availability.gd`, not a
runtime probe, and `test_ui_availability.gd` and `test_ui_shell.gd` check both halves.

Seven things were decided on the way there, and each could be undone by accident.

## 1. An unbuilt panel is drawn, disabled, and says whose fault it is

Task 04.4: "The generic rendered shell cannot claim unbuilt panels work." The tempting reading
is "hide what is not built". That is worse: a player cannot tell a missing feature from a
broken one, and the next coder cannot tell which of 103 elements are outstanding.

So every element is in exactly one of two states. A WIRED element reads or writes real state
and has a test. An UNAVAILABLE element is built, visible, **disabled**, carries §2.2's lock
icon, and prints `Unavailable: <the missing owner>` both on screen and in its accessible
description. `unavailable_label()` **refuses** for a wired element rather than returning a
plausible excuse, because that is the direction a regression would travel in.

The reasons name owners — `UI_NO_BUILDING_STORE` says "task 06 owns those contracts" —
and `UI_PANEL_NOT_BUILT` is used **only** where the store exists and the panel is honestly the
missing part. That is a weaker excuse and it is labelled as one.

## 2. Every player action becomes a command; the shell holds no store it could write

04.2: "No UI callback edits resident, ecology, jobs or inventory stores directly."
`ui_command_bridge.gd` is constructed with a `commands.gd` queue **and nothing else**. There is
no `forage.gd`, `jobs.gd` or `residents.gd` reference in it to misuse. The shell itself holds
the bridge, the New Settlement session and the ARCH-SYS-023 snapshot — again, no store.

Where an action genuinely needs a store, the shell **emits a signal and UIManager does it**:
`shell_action(103)` runs generation, `tile_picked(tile)` resolves a basin, and
`resident_row_picked(row)` resolves a resident slot. The panel never gets the store.

`test_ui_command_bridge.gd` presses the real buttons and then looks at the stores: zone count
unchanged, job count zero, queue pending one. The stores move only when ARCH-SYS-002 commits.

## 3. New Settlement discards the settlement BEFORE it generates, and says so

`world_init.gd` refuses to publish over live rows it does not own, and a settlement's residents
are exactly that. So `UIManager.create_world()` calls `SettlementSystem.reset()` first.

**One consequence is stated rather than hidden**: if generation then refuses, the previous world
is already gone and the settlement is left empty, not restored. The refusal text says so. The
alternative — attempting generation first and reporting `WORLD_FOREIGN_LIVE_ROWS` — would be a
code no player can act on.

HOLT, FORTRESS and SANDBOX are offered by §4.3's dropdowns and **refuse**, naming the missing
authoring. Generating the abbey under another name is precisely the fallback 04.3 forbids.
`tutorial` is held false against §4.3's stated default of true, because there is no tutorial
disclosure state; both values are published in `ui_world_session.gd` so the deviation is visible.

## 4. Three absences are rendered differently, because they are different

* `--` — **unpopulated**: no owning store supplies the figure (Fuel-days, Beds).
* `0` — a **measured zero**: a generated world really does have zero residents.
* `Unavailable: …` — an **unsupported feature**, with its missing owner named.

`set_counter_display()` REFUSES to print a value into an unavailable counter, so a future
caller cannot turn a named missing owner into a plausible zero. `test_ui_shell.gd` asserts the
refusal and that the cell's text does not change.

## 5. The Theme is a build product of the tokens, not a second palette

§2.1 publishes nine contrast ratios computed from ten exact hex values. A Theme hand-edited in
the inspector drifts from them silently. So `ui/theme/woodland_theme.tres` is **generated** by
`ui/theme/build_woodland_theme.gd` from `scripts/ui/ui_theme.gd`, applied once at the UI root,
and `test_ui_theme_resource.gd` compares every colour and size in the committed resource back
to the tokens.

Noto Sans 400/500/600/700 are vendored at §2.1's four exact paths from the official Noto
repository under the SIL OFL, with SHA-256s and provenance in `godot/ui/ASSETS.md`. They are
four genuinely different files: each one's own OpenType name table was read before vendoring,
and the suite re-checks all four style names and weights so a renamed regular cannot pass.

One mapping is not obvious and is recorded here: **a TOGGLE's Godot `pressed` slot carries
§2.2's SELECTED colours**, because Godot draws a latched toggle with `pressed`. Mapping it to
the PRESSED token instead left the selected speed button looking unselected and, in the
specimen, cream text on gold at about 1.4:1. It was caught by looking at a screenshot.

## 6. What consumes a click is read from the tree's own mouse filters

§1.2: the world click-through rectangle is the viewport minus the **actual visible input
rectangles**, and "A transparent full-screen Control must not block the center."
`_register_hit_regions()` walks the built controls and takes `consumes` from each control's own
`mouse_filter`, so the table a test interrogates cannot disagree with what the engine will do.
Decorative regions — the world overlay, every label, the focus outline, the tooltip, the sprig
ornament — are IGNORE, carry no focus mode and have an empty accessible name.

## 7. `project.godot`'s stretch mode defeats §1.2's breakpoints, and that is reported, not patched

Measured: `window/stretch/mode="canvas_items"` against a 1920x1080 base gives the HUD a
1920x1080 canvas in a 1280x720 window, so the shell lays out WIDE where §1.2 gives STANDARD, and
the NARROW profile is unreachable at runtime at any supported user scale. §1.2 says "Do not
scale the entire game through a low-resolution pixel viewport."

Laying out against the window size instead would be worse: the rectangles would then be scaled
a second time by the same transform. `project.godot` belongs to the integration lead, so this
is recorded in `ui_shell.gd`, in `docs/validation/evidence/ui-first-playable/README.md` and
here, and the narrow composition is covered by tests rather than by a screenshot.

## Consequences

* 42 elements wired, 61 rendered unavailable with a named owner; the count is reportable.
* Four of ARCH-CMD-003's 24 command kinds are reachable from the interface: DESIGNATE_ZONE,
  SET_POLICY, CANCEL_JOB and NAME_RESIDENT. The other twenty have no UI because they have no
  owning store or no built panel, which is the same reason `command_dispatch.gd` refuses them.
* **Nothing in `scripts/ui/` writes `JOB_STATE_WORK`, and nothing can**: no UI module holds a
  Job store. A QUEUED job remains the correct visible outcome until task 05.
* Resident selection is real: the roster lists the live cohort and resolves a row to a resident
  slot. It is **not** virtualized; the pool is twelve and the panel says so when more exist.
* The 3D world is still the prototype plane. No terrain renderer exists, so the open centre the
  design asks for is an empty field, and world picking is done on the minimap.
