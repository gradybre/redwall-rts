# Task 04.5 native UI evidence

Captured 2026-09-11 from the **native macOS game**, not a headless render and not a preview.

| | |
|---|---|
| Branch | `feat/ui-shell-integration` |
| Suite at capture | `ok: 2711 tests, 98302 assertions, 0 failures.` |
| Launch | `godot --path godot --script capture_ui_scratch.gd --resolution <W>x<H> -- <out.png> <mode> [scale]` |
| Scene | the project's own `run/main_scene`, `res://scenes/main.tscn` |
| Harness | `capture_ui_scratch.gd`, a scratch file **deleted before commit**; recorded here because the exact command matters |

The harness fakes no state. It drives the interface's own public entry points —
`UIManager.create_world()` is UI-SET-103's Create — and every value on screen came from
the real stores through the real HUD.

## The responsive correction

All three profiles are reachable at runtime for the first time, matching the READY_07
save/UI addendum's table:

| Window | User scale | Logical | Profile |
|---|---:|---|---|
| 1920×1080 | 100% | 1920×1080 | WIDE |
| 1280×720 | 100% | 1280×720 | STANDARD |
| 1280×720 | 150% | 853×480 | NARROW |

Previously every window reported WIDE. It took both halves of the ruling: `project.godot`'s
base stretching disabled, **and** a UI-only scale transform on the shell. Applying only the
first drew the narrow layout correctly at 853×480 in the corner of a 1280×720 window, which
is how the missing half was found. The ruling says in terms: do not apply both.

## What each capture shows

| File | Window / scale | Shows |
|---|---|---|
| `01_paused_wide_1920x1080.png` | 1920×1080 / 100% | Boot HUD, **Paused: PLAYER** named, counters with real values or a named reason |
| `02_generated_wide_1920x1080.png` | 1920×1080 / 100% | After UI-SET-103 Create: 1695 nodes, 7 basins, 9 fish stocks, seed 20260905 — the full sentence, wrapped |
| `03_roster_wide_1920x1080.png` | 1920×1080 / 100% | Residents opens the ROSTER, not the unbuilt world-access panel |
| `04_newsettlement_wide_1920x1080.png` | 1920×1080 / 100% | The UI-SET-103 form |
| `05_standard_1280x720.png` | 1280×720 / 100% | STANDARD profile |
| `06_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW: compact two-row resources, single-row time group, two command rows |

## Open defects, visible in these images

1. **The alert card overflows at NARROW.** The message now wraps rather than clipping
   (UXV-032), and a long generation sentence wraps to three lines and draws outside a card
   whose height `ui_layout.alert_card()` fixes, over the pause line. Growing it from the
   shell does nothing — `_place_local()` re-sets the rect from the layout every pass. The
   card must become content-sized in `ui_layout.gd`, which the component owner holds.
   Overlap is worse than the clipping it replaced; both are recorded rather than traded.
2. **Frame art is authored but not applied.** `godot/ui/frames/` holds five frames of four
   corners and four edges each. Two placement attempts put corners outside their panels and
   left the edge strips invisible. The pieces load and draw, so the fault is the placement
   contract, not the paths: `ui_art_manifest.json` declares each asset's actual bounds and
   stretch margins and its author owns what they mean. `_apply_frame_art()` is kept in
   `ui_shell.gd`, uncalled, with that reason at the function.
3. **`Residents 0` after generation.** The starter cohort is on an unpushed branch and is not
   in this stack, so no resident detail exists to capture and **ART-UI-09 cannot be judged**.
4. **Painted icons are applied; panels are not.** The bowl, logs, stone, population group and
   Zone stakes render from `godot/ui/painted/`, and NARROW uses the 16 px symbolic variants
   rather than shrinking painted detail. Panels remain flat green — see defect 2.

## What these images do not establish

No visual approval. No keyboard or screen-reader qualification — names and descriptions are
set and asserted, which is not a pass. No Windows or minimum-hardware claim. High-DPI is not
captured here. Brendan's verdict is ART-UI-12 and is recorded separately.

---

# R-UI-ALERT-001 captures — 2026-09-11

Captured from the **native macOS game** on branch `fix/ui-alert-summary`.

| | |
|---|---|
| Suite at capture | `ok: 2774 tests, 99750 assertions, 0 failures.` |
| Launch | `godot --path godot --script capture_alert_scratch.gd --resolution <W>x<H> -- <absolute-out.png> <mode> <scale>` |
| Modes | `card`, `expanded`, `history`, `empty` |
| Harness | `capture_alert_scratch.gd`, a scratch file **deleted before commit**; the command is recorded here because it is the part that matters |

The harness fakes nothing. The refusal on screen is produced by choosing HOLT in
the UI-SET-103 form — a value the form offers and the session refuses as
unauthored — and then running `UIManager.create_world()`, the real Create action.
Every string was composed by the code under test. `empty` calls the same
`set_alert_display("")` that `hud.gd` calls when its four-second hold expires.

Two traps, both still true: a `--script` SceneTree run hangs forever if an error
abandons `_initialize()` before `quit()`, so the harness counts frames and quits
either way; and `save_png` needs an **absolute** path. A third was found this
time: **autoload identifiers do not resolve at compile time under `--script`.**
`UIManager` must be reached with `root.get_node_or_null("UIManager")` at runtime,
or the script fails to compile with `Identifier not found`. The test runner does
not hit this because it `load()`s its suites after `_initialize()` has begun.

| File | Window / scale | Profile | Shows |
|---|---|---|---|
| `07_alert_summary_wide_1920x1080.png` | 1920×1080 / 100% | WIDE | The compact card `Error: Generation failed (+1)` with its severity icon |
| `08_alert_expanded_wide_1920x1080.png` | 1920×1080 / 100% | WIDE | UI-SET-012 expanded on that notice: whole message, source, code, scrolling |
| `09_alert_summary_standard_1280x720.png` | 1280×720 / 100% | STANDARD | The summary card, and UI-SET-085 grown to hold the whole refusal without clipping |
| `10_alert_expanded_standard_1280x720.png` | 1280×720 / 100% | STANDARD | The expanded view, drawn above the permanent HUD |
| `11_alert_summary_narrow_1280x720_125.png` | 1280×720 / 125% | NARROW | The same summary at the second user scale |
| `12_alert_summary_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW | **Defect 1 below, fixed.** One measured line in the 44 px card; the pause line is clear |
| `13_alert_expanded_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW | Full disclosure at the tightest composition, with a visible scrollbar |
| `14_alert_empty_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW | The empty state: the History trigger alone, no card, no panel |

## What these captures closed, and what they opened

**Defect 1 of the previous list is fixed.** Compare `06` with `12`: the three-line
generation sentence no longer draws over `Paused: PLAYER`. The card is the
authored summary and the whole sentence is in `13`.

Three further defects were found BY these captures and fixed in the same change,
each with a test:

1. **UI-SET-085 drew through its own bottom edge.** The panel was placed at its
   §4 minimum 320×160 whatever the refusal said. It is now sized inside §4's
   160..480 band with a scrolling body.
2. **Open expansions were drawn outside the viewport.** A taller error panel
   pushed UI-SET-012 off the bottom at NARROW, and a 720-wide panel ran off the
   right. Both are clamped into the viewport now.
3. **The expanded view was painted over by the permanent HUD.** `ui_hit_test.gd`
   already put LAYER_EXPANSION above LAYER_PERMANENT_HUD; the child order did not
   agree, so the minimap frame and the command strip drew on top of it.

## What these images still do not establish

No visual approval. No screen-reader qualification: the accessible names and
descriptions are set and asserted, and `Open alert details` is named in the
card's description, but no assistive technology was run. **Facing a human eye is
still required.** Counter cells clip at NARROW and STANDARD — `Food 5.` for 5.48,
`Wood 18` for 180 U — which is a separate UXV-032 defect recorded in ADR 0076 and
explicitly NOT covered by R-UI-ALERT-001's exception.


---

# Resident journal captures — 2026-09-12

Captured from the **native macOS game** on branch `feat/ui-medallions-and-needs`
(ADR 0086: UXV-020/021, ART-UI-06/09, ART-UI-01/02).

| | |
|---|---|
| Suite at capture | `ok: 3200 tests, 109578 assertions, 0 failures.` (after merging `origin/master`) |
| Launch | `godot --path godot --script capture_ui_scratch.gd --resolution <W>x<H> -- <absolute-out.png> <scale>` |
| Scene | the project's own `run/main_scene`, `res://scenes/main.tscn` |
| Harness | `capture_ui_scratch.gd`, a scratch file **deleted before commit**; the command is recorded here because it is the part that matters |

The harness fakes nothing and drives no store. It calls `UIManager.refresh_roster()`
and emits `pressed` on a real roster row; every figure on screen came from
`residents.gd`, `needs.gd` and `jobs.gd` through `ui_resident_card.gd`. The world
and the §5.1 cohort are `main.gd`'s own boot, through
`SettlementSystem.create_generated_settlement()`.

**UI-SET-103's Create is deliberately NOT pressed in these runs**, because it now
refuses — see the reported regression below.

The three traps in the sections above are all still true. The harness counts
frames and quits either way, `save_png` is given an absolute path, and `UIManager`
is reached through `root.get_node_or_null("UIManager")` at runtime.

| File | Window / scale | Profile | Shows |
|---|---|---|---|
| `15_journal_medallion_wide_1920x1080.png` | 1920×1080 / 100% | WIDE | The 64 px mouse medallion, the name heading, `mouse - Resident - Active`, health, five need rows and the foraging skill row, with all five container frames applied. UI-SET-100's zone harvesting policy is absent, per UXV-023 |
| `16_journal_medallion_standard_1280x720.png` | 1280×720 / 100% | STANDARD | The same card at 48 px with the body scrolling; the scroll bar is visible beside the need rows |
| `17_journal_medallion_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW | The journal silhouette's 12 px spine and 14 px fore-edge corners at the tightest composition, with the body scrolled to the first need row |

## What these captures close

1. **ART-UI-09 can be judged for the first time.** Defect 3 of the first list —
   "the starter cohort is on an unpushed branch ... no resident detail exists to
   capture" — is gone. The card carries a real name, species, status, health,
   five needs and a real skill row.
2. **Defect 2 of the first list is fixed.** `godot/ui/frames/` is applied.
   `_apply_frame_art()` and `_add_frame_piece()` are deleted from `ui_shell.gd`;
   `ui_frame_builder.gd` places every piece explicitly and the shell refreshes
   it on relayout, because `Control.resized` never fires off-tree.
3. **The needs line is no longer `Hunger 7500 of 10000`.** Row 0 reads
   `Fullness 75% -2.50 pp/h` for a small resident and `-3.00 pp/h` for a medium
   one, which is GDD §5.2's 250 milli-points/hour under the size multiplier.

## Two regressions found BY these captures, reported and NOT fixed here

Both arrived with `origin/master` and both are outside ADR 0086's three items.

1. **UI-SET-103's Create refuses in the running game.**
   `UIManager.create_world()` returns false with
   `WORLD_FOREIGN_LIVE_ROWS / generation refused during preflight`.
   `ui_world_session.create_with_cohort_into()` follows R-INIT-ID-001's order
   `preflight -> reset -> seed -> cohort -> publish`, so the preflight runs
   *before* the reset and sees boot's own twelve residents as live rows the plan
   does not own. Pressing Create after boot therefore always refuses. The panel
   additionally states "The settlement is now empty", which is not true on this
   path: the residents survive. This belongs to R-INIT-ID-001's ordering owner.
2. **The top-left counters read `--` after boot even though the stores hold
   values.** `main.gd` registers the HUD, seeds the stores (each deposit emits
   `stocks_changed`, so Wood and Stone paint correctly), and only THEN generates
   the world and binds the residents store. Nothing refreshes the counters after
   that bind, so `Food-days` and `Residents` keep the marker they were correctly
   given while no residents store existed. `EconomySystem.food_days_text()`
   returns `5.48` and `has_residents()` returns true at the moment of capture.
   Earlier evidence hid this because the harness pressed Create, whose
   `_refresh_hud()` repainted them.

## What is visible in these images and NOT fixed here

1. **Four of the five rates read `Rate unavailable`.** `needs.gd` publishes an
   effective rate for hunger only; rest, comfort, social and purpose depend on
   four columns that have a setter and no reader. UXV-020's per-hour change is
   therefore satisfied for one row of five, and the missing readers are an
   unfulfilled binding requirement against `scripts/core/needs.gd`.
2. **The roundel leads the card above the name, not beside it.** §4's 280 px
   minimum for UI-SET-037 does not fit beside a 48/64 px medallion in any detail
   column §1.2 defines. ADR 0086 records the arithmetic.
3. **Age is stated as unavailable.** There is no age or birth column in
   `residents.gd`.
4. **Counter cells still clip** — `Wood 18` for 180 U at STANDARD, and
   `Resident` for Residents. That is ADR 0076's separate UXV-032 defect and is
   untouched here.
5. **The command dock drops to four actions at NARROW** while the journal is
   open, so Residents is not reachable from the dock there. Pre-existing.
6. **`No world generated` in the minimap.** UI-SET-021 reads the UI session's own
   published map, and boot publishes through `SettlementSystem` instead. With
   Create refusing (regression 1), the session never learns about boot's world.

## What these images still do not establish

No visual approval; ART-UI-12 is Brendan's and is recorded separately. **Facing
a human eye is still required, and specifically for the medallions:** the
species-reading test, the three-quarter turn toward screen-left and the
relationship between the roundel's weight and the data beside it are judgements
no assertion here makes. No screen-reader qualification — the roundel is
decorative and the panel's description carries "not a portrait of this resident",
both asserted, neither run through assistive technology. No Windows or
minimum-hardware claim, and no high-DPI capture.


---

# UI-IDENTITY-R01 identity-row captures — 2026-09-12

Captured from the **native macOS game** on branch `feat/ui-identity-r01`, based on
`origin/master` at `6269f2b`. Implements
[the 2026-09-12 ruling](../../../rulings/2026-09-12_resident_header_and_need_rates.md);
recorded in [ADR 0098](../../../decisions/0098-the-resident-identity-row-and-its-five-bound-rates.md).

| | |
|---|---|
| Suite at capture | `3464 test(s), 124035 assertion(s), 0 failure(s)` |
| Launch | `godot --path godot --script capture_identity_scratch.gd --resolution <W>x<H> -- <absolute-out.png> <scale> <name>` |
| `<scale>` | `100`, `125` or `150` — the §1.2 user scale, applied through the shell's own `apply_user_scale()` |
| `<name>` | `short`, `name32`, `unbroken` or `combining` |
| Scene | the project's own `run/main_scene`, `res://scenes/main.tscn` |
| Harness | `capture_identity_scratch.gd`, a scratch file **deleted before commit**; the command is recorded here because the command is the part that matters |

The harness fakes nothing. It names a real resident through `residents.set_name()`,
calls `UIManager.refresh_roster()` and emits `pressed` on a real roster row; every
figure on screen came from `residents.gd`, `needs.gd` and `jobs.gd` through
`ui_resident_snapshot.gd` and `ui_resident_card.gd`. The four names are:

| Key | Name | Why |
|---|---|---|
| `short` | `Mira` | the ordinary case |
| `name32` | `Bramblewhisker Thistledown Abbot` | the ruling's explicit 32-character case |
| `unbroken` | `Bramblewhiskerthistledownabbotofredwall` | one 39-character word, wider than any column |
| `combining` | `Maïriń Silverbrush` | combining diaeresis and combining acute |

The three traps recorded in the sections above are all still true: the harness
counts frames and quits either way, `save_png` is given an **absolute** path, and
`UIManager`/`SettlementSystem` are reached with `get_node_or_null()` at runtime
because autoload identifiers do not resolve at compile time under `--script`.

| File | Window / scale | Profile | Name | Shows |
|---|---|---|---|---|
| `18_identity_wide_1920x1080_100_short.png` | 1920×1080 / 100% | WIDE | short | **All five rates bound**: −2.50 / −3.75 / −1.00 / −1.00 / −0.75 pp/h. 64 px medallion beside the name, 220 px name column, Close top-right, Center view in the fixed footer |
| `19_identity_wide_1920x1080_100_name32.png` | 1920×1080 / 100% | WIDE | name32 | The 32-character name wrapped on whole words in the 220 px column |
| `20_identity_wide_1920x1080_100_unbroken.png` | 1920×1080 / 100% | WIDE | unbroken | The 39-character word broken on grapheme boundaries, inside its own column |
| `21_identity_wide_1920x1080_100_combining.png` | 1920×1080 / 100% | WIDE | combining | `Maïriń` with both combining marks intact |
| `22_identity_standard_1280x720_100_short.png` | 1280×720 / 100% | STANDARD | short | 64 px medallion, 172 px name column |
| `23_identity_standard_1280x720_100_name32.png` | 1280×720 / 100% | STANDARD | name32 | Header grown, body shortened, footer unmoved |
| `24_identity_standard_1280x720_100_unbroken.png` | 1280×720 / 100% | STANDARD | unbroken | Grapheme break at the narrower column |
| `25_identity_standard_1920x1080_125_name32.png` | 1920×1080 / 125% | STANDARD | name32 | The second user scale |
| `26_identity_standard_1920x1080_150_name32.png` | 1920×1080 / 150% | STANDARD | name32 | The third |
| `27_identity_narrow_1280x720_125_name32.png` | 1280×720 / 125% | NARROW | name32 | 48 px medallion, 172 px column, three-line name |
| `28_identity_narrow_1280x720_150_short.png` | 1280×720 / 150% | NARROW | short | **The ruling's explicitly required 1280×720@150%** |
| `29_identity_narrow_1280x720_150_name32.png` | 1280×720 / 150% | NARROW | name32 | The tightest composition with the longest supported name |
| `30_identity_narrow_1280x720_150_unbroken.png` | 1280×720 / 150% | NARROW | unbroken | The defect below, fixed |
| `31_identity_narrow_1280x720_150_combining.png` | 1280×720 / 150% | NARROW | combining | Combining marks at the tightest composition |

## A defect these captures found, and the assertions did not

**A long unbroken name drew three lines inside a two-line heading box**, over the
species line and over the Overview tab. The whole suite was green when it happened.

`_wrapped_height()` measured with `Font.get_multiline_string_size()`'s DEFAULT break
flags, `BREAK_MANDATORY | BREAK_WORD_BOUND`, which never splits a word. The Label is
set to `AUTOWRAP_WORD_SMART`, which does split one, on a grapheme cluster boundary.
The measurement and the drawing disagreed by exactly one line, and no headless
assertion compared them. This is the ruling's own point — "Arithmetic fit is not a
screenshot pass" — landing on the person who wrote the arithmetic.

Fixed by deriving the flags from the Label's own `autowrap_mode`, and pinned by
`test_no_name_draws_outside_its_own_heading_rectangle`, which measures the text with
the flags the Label will use and asserts the allocated rectangle holds it and
touches neither the species line nor the tabs. Reverting the one-line fix kills that
test and nothing else.

## What these captures close

1. **Four rows no longer read `Rate unavailable`.** Capture 18 shows all five need
   rows carrying a published per-simulated-hour rate. `needs.gd`'s four signed net
   readers landed with NEED-RATE-R01, and `ui_resident_snapshot.gd` copies all five
   at one validated `EntityRef`/generation boundary.
2. **The medallion is beside the name at every profile.** Defect 2 of the previous
   section — "the roundel leads the card above the name" — is gone, and there is no
   branch left that could put it back.
3. **The header grows and the footer does not move.** Compare `28` with `29`: the
   three-line name pushes the body down and shortens it; Center view stays where it
   is, and Close stays at the top right.

## What is visible here and NOT fixed

1. **Center view is disabled.** It is built, labelled and carries
   `ui_availability.gd`'s own REASON_NO_WORLD_CAMERA. No camera binding is invented.
2. **Age is still stated as unavailable** in the supporting note. `residents.gd`
   gained a life-stage column under MOVE-DEP-R02, but nothing publishes a verified
   stage into this heading and the ruling forbids inventing one.
3. **A need row can be cut at the body's scroll edge** (visible in `31`, where Rest
   is half-drawn at the bottom of the viewport). That is a ScrollContainer boundary,
   not truncation: the row is whole and scrolling reaches it.
4. **Counter cells still clip** at STANDARD and NARROW — ADR 0076's separate UXV-032
   defect, untouched here.
5. **`No world generated` in the minimap**, and the top-left counters reading `--`
   at NARROW: both pre-existing and recorded in the sections above.

## What these images still do not establish

No visual approval; ART-UI-12 is Brendan's and is recorded separately. **Facing a
human eye is still required**, specifically for the relationship between the
medallion's weight and the name beside it at 48 px, and for whether a three-line
name at NARROW leaves a usable body. No screen-reader qualification: the heading
semantics, the decorative medallion and the Capped explanation are set and asserted,
and no assistive technology was run. No Windows or minimum-hardware claim, and no
high-DPI capture.
