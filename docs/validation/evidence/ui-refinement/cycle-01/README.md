# ART-UI-12 cycle-01 — two isolated defect captures

**No visual approval is claimed or granted by this directory, and none may be inferred from
it. ART-UI-12 is Brendan's verdict and nobody else's.** Nothing below is an acceptance, a
sign-off, or a recommendation to accept. These twelve images exist so that a verdict can be
made on evidence instead of on description.

**This is an increment, not a replacement.** The forty existing native captures live in
[`../README.md`](../README.md) and remain the primary record. Nothing here re-shoots any of
them and nothing here supersedes any of them.

| | |
|---|---|
| Date | 2026-09-14 |
| Base | `origin/master` at `127c8e4`, branch `feat/art-ui-12-evidence` |
| Suite at capture | `ok: 4336 tests, 152719 assertions, 0 failures.` |
| Platform | native macOS, **windowed**; `--headless` returns null from `get_image()` |
| Scene | the project's own `run/main_scene`, `res://scenes/main.tscn` |
| Harness | `capture_artui12_scratch.gd` and `diff_artui12_scratch.gd`, scratch files **deleted before commit**; the exact commands are recorded below because that is the part that reproduces |

## Why these two, and only these two

The forty existing captures already document both conditions, but in each case entangled with
another feature, so the reader has to take the defect on trust:

* Captures `09` and `12` show counter clipping (`Food 5.`, `Wood 18`, `Resident`) inside
  captures whose subject is the alert card. Nothing there shows where the cut begins, or that
  content one glyph shorter survives.
* Capture `40` shows the roster workspace over the alert zone. It is a single frame, so the
  card behind it can only be inferred from the reported `visible = true`, never seen absent.

Captures `01`–`09` here isolate the first; `10`–`12` isolate the second and measure it.

## Reproducing any capture

Run from the repository root, after `godot --headless --path godot --editor --quit` — a fresh
worktree has an empty import cache, and without that step fonts and themes are unimported and
every capture is wrong.

```bash
godot --path godot --script capture_artui12_scratch.gd --resolution 1280x720 \
    -- <ABSOLUTE-out.png> <mode> <scale-percent>
```

`save_png` needs an **absolute** path. A `--script` SceneTree run hangs forever if an error
abandons `_initialize()` before `quit()`, so every run above was wrapped in
`perl -e 'alarm 240; exec @ARGV'` — macOS has no `timeout`. Autoload identifiers do not
resolve at compile time under `--script`, so `UIManager` is reached with
`root.get_node_or_null("UIManager")` at runtime.

| # | File | Window | User scale | Profile | Mode argument |
|---:|---|---|---:|---|---|
| 01 | `01_counters_standard_1280x720_100_markers.png` | 1280×720 | 100% | STANDARD | `unpopulated` |
| 02 | `02_counters_standard_1280x720_100_settlement.png` | 1280×720 | 100% | STANDARD | `settlement` |
| 03 | `03_counters_standard_1280x720_100_ladder.png` | 1280×720 | 100% | STANDARD | `ladder` |
| 04 | `04_counters_narrow_1280x720_125_markers.png` | 1280×720 | 125% | NARROW | `unpopulated` |
| 05 | `05_counters_narrow_1280x720_125_settlement.png` | 1280×720 | 125% | NARROW | `settlement` |
| 06 | `06_counters_narrow_1280x720_125_ladder.png` | 1280×720 | 125% | NARROW | `ladder` |
| 07 | `07_counters_narrow_1280x720_150_markers.png` | 1280×720 | 150% | NARROW | `unpopulated` |
| 08 | `08_counters_narrow_1280x720_150_settlement.png` | 1280×720 | 150% | NARROW | `settlement` |
| 09 | `09_counters_narrow_1280x720_150_ladder.png` | 1280×720 | 150% | NARROW | `ladder` |
| 10 | `10_occlusion_roster_open_alert_expired_standard_1280x720.png` | 1280×720 | 100% | STANDARD | `occl_expired` |
| 11 | `11_occlusion_roster_open_alert_active_standard_1280x720.png` | 1280×720 | 100% | STANDARD | `occl_active` |
| 12 | `12_occlusion_roster_closed_alert_active_standard_1280x720.png` | 1280×720 | 100% | STANDARD | `occl_open` |

So, for example, capture 08 is exactly:

```bash
godot --path godot --script capture_artui12_scratch.gd --resolution 1280x720 \
    -- /ABSOLUTE/PATH/docs/validation/evidence/ui-refinement/cycle-01/08_counters_narrow_1280x720_150_settlement.png \
       settlement 150
```

## What drove each screen, and what the harness supplied

`unpopulated` boots and touches nothing: every counter carries whatever `hud.gd` renders
before a settlement exists. `settlement` calls `UIManager.create_world()`, UI-SET-103's real
Create, and every figure on screen then came from `EconomySystem` and the residents store
through the real HUD. The occlusion modes choose HOLT — a value UI-SET-103's own dropdown
offers and `ui_world_session.gd` refuses as unauthored — and then run the real Create, so both
notices are composed by the code under test; the roster is opened by emitting `pressed` on
UI-SET-031's own button, and `occl_expired` additionally calls `hud.show_alert("")`, which is
the exact call `hud.gd` makes when its own four-second hold expires.

**`ladder` is the one mode that supplies content, and it is labelled as such.** It writes
digit strings of 1, 2, 3 and 4 glyphs into consecutive cells through
`ui_shell.set_counter_display()` — the same function `hud.gd`'s `_render_cell()` calls — so
that consecutive drawn cells differ by exactly one glyph and the first cut lands between two
neighbours. The label prefix, the composition, the font, the cell rectangle and the drawing
are all the code under test; only the magnitude is the harness's. The two cells whose owning
store does not exist refused the write with `UI_SHELL_ELEMENT_NOT_WIRED` and kept their
stated reason, which is why Fuel and Beds still read `--` in `03`.

---

# 1. Counter clipping, isolated (captures 01–09)

## The measurement, taken from the live controls

Each cell is a `Button` with `clip_text = true`, an 18 px `WoodlandCounter` face
(`ui_theme.gd` `FONT_COUNTER`) and a 24 px painted icon. The usable text width is the cell
width less the style box's 2 px left and right margins, the icon, and the 4 px `h_separation`:

| Profile | §1.2 cell | Cell width | Icon | Margins | Separation | **Text budget** |
|---|---|---:|---:|---:|---:|---:|
| STANDARD | `min(144,(360−32)/3)` | 109.33 px | 24 | 2 + 2 | 4 | **77.33 px** |
| NARROW | §1.3's fixed `104×36` | 104.00 px | 24 | 2 + 2 | 4 | **72.00 px** |

Measured in the real font by the harness, printed per capture:

| Cell text | Measured | STANDARD budget 77.33 | NARROW budget 72.00 |
|---|---:|---|---|
| `Food --` | 60.00 | fits | fits |
| `Fuel --` | 54.00 | fits | fits |
| `Beds --` | 59.00 | fits | not drawn at NARROW |
| `Food 5.48` | 84.00 | **cut by 6.67 px** | **cut by 12.00 px** |
| `Wood 180 U` | 104.00 | **cut by 26.67 px** | not drawn |
| `Stone 100 U` | 105.00 | **cut by 27.67 px** | not drawn |
| `Residents 12` | 111.00 | **cut by 33.67 px** | not drawn |
| `Residents --` | 102.00 | **cut by 24.67 px** | not drawn |

## What each capture shows

| File | Shows |
|---|---|
| `01` … `_markers.png` | The SHORT end at STANDARD. `Food --`, `Fuel --`, `Beds --` are drawn whole. `Residents --` is already cut to `Resident`, and `Wood 18` / `Stone 10` are cut from the starting stock |
| `02` … `_settlement.png` | The LONG end at STANDARD, same window, same scale. Create has run: `Food 5.4`, `Wood 18`, `Stone 10`, `Resident`. Compare cell by cell with `01` |
| `03` … `_ladder.png` | **The boundary.** `Food 1` (59.00) and `Wood 12` (76.00) are drawn whole; `Stone 123` (86.00) is cut to `Stone 12`; `Residents 1234` (132.00) is cut to `Resident`. The transition is one glyph wide and is between two adjacent cells in one frame |
| `04`, `07` | The SHORT end at NARROW, 125% and 150%. Two cells only, §1.3's count; both markers whole |
| `05`, `08` | The LONG end at NARROW. `Food 5.` — the exact string ADR 0076 recorded — with `Fuel --` beside it intact, so the cut is attributable to content width and not to the profile |
| `06`, `09` | The NARROW ladder. `Food 1` is whole at 59.00 against the 72.00 budget. Only one of the two drawn cells is writable, so this capture brackets the budget rather than stepping across it; the step is in `03` |

## Three things worth stating plainly

1. **No populated counter fits at 1280×720, at any of the three user scales.** The widest
   value any cell can carry before the cut begins is **two digits** at STANDARD, and the
   `--` marker is the only content in the set that is drawn whole.
2. **`Residents` overflows with no value at all.** The bare word `Residents` measures
   **86.00 px** against the 77.33 px budget, so the cell reads `Resident` whether the
   settlement holds 12 residents or none — compare `01` with `02`. This is not a
   long-number problem, and no value is short enough to make it go away. The other five
   labels measure `Food` 44.00, `Fuel` 37.00, `Wood` 51.00, `Stone` 51.00, `Beds` 43.00.
3. **Nothing wraps, ellipsises or shrinks — it is cut mid-glyph.** `Food 5.48` loses the
   `8`; `Wood 180 U` loses `0 U`; `Residents` loses its final `s`. A reader cannot tell a
   truncated figure from a complete one.

## Ownership

`UXV-032` — "long refusal and larger text shall wrap/scroll **without clipping**, ellipsis on
critical content, reduced font size or a covered footer"
(`docs/design/ui_refinement/requirements.csv`, UI §1.3, A08). ADR
[`0076`](../../../../decisions/0076-the-narrow-alert-card-is-an-authored-summary.md) §111 records
the counter cells as **a separate UXV-032 defect, deliberately left unfixed** because that
ruling's compact-summary exception covers HUD notices and does not extend to other labels.

**PRE-EXISTING.** Every capture in this section was taken on `127c8e4` with no production
file touched. Nothing here is a regression introduced by this lane, and nothing here is fixed
by this lane.

---

# 2. The workspace over the alert zone, isolated and measured (captures 10–12)

## The three frames

All three are 1280×720 at 100%, STANDARD, with the identical pair of notices raised by the
identical HOLT refusal.

| File | Roster workspace | Alert cards | Shows |
|---|---|---|---|
| `10` … `_alert_expired` | open | none — `hud.show_alert("")` expired the hold; `wanted=0 visible=0` | The screen with the alert stack genuinely gone |
| `11` … `_alert_active` | open | two — `card0 visible=true` `Error: Generation failed (+1)`, `card1 visible=true` `Info: Settlement notice (+1)` | The same screen with both cards placed and reporting visible |
| `12` … `_roster_closed` | **closed** | the same two cards | The control: those same cards, from the same notices, do draw |

## The measurement, and why the pair was needed

The captures are bit-deterministic: the same mode captured twice produced **0 differing
pixels of 921600**. The comparison below is therefore exact, with no tolerance.

```bash
godot --headless --path godot --script diff_artui12_scratch.gd \
    -- <ABSOLUTE-a.png> <ABSOLUTE-b.png> <x> <y> <w> <h>
```

The shell reports card 0's rectangle as `(462, 18, 320, 44)` and card 1's as
`(462, 66, 320, 44)`.

| Comparison | Region | Differing pixels |
|---|---|---:|
| `10` vs `11` | card 0, `462 18 320 44` | **0 of 14080** |
| `10` vs `11` | card 1 upper band, `462 66 320 36` | **0 of 11520** |
| `11` vs `12` | card 0, `462 18 320 44` | 2829 of 14080 |
| `11` vs `12` | card 1 upper band, `462 66 320 36` | 2641 of 11520 |

**Not one pixel of the frame changes between two active alert cards and no alert card at
all.** The occlusion is total over both card rectangles, and the same two cards against the
workspace-closed control differ across those rectangles, so the cards are not merely empty.
That is the difference between demonstrating the defect and inferring it from a `visible`
flag.

Card 1's rectangle is compared over its upper 36 px rather than its full 44, because the
roster's first row label is drawn across `y = 102…111` and shifts horizontally by 4 px
between the two frames. That shift is unrelated to the alert stack — the roster row's own
reported rectangle is `(172, 28, 280, 56)` in **both** frames — and is noted here as an
observed relayout side effect, not claimed as part of this defect and not investigated.

## Ownership

§3's layer table already puts the workspace at layer 40 and permanent HUD zones at layer 20,
so this is not a z-order bug. What is unresolved is that §1.2's alert rectangle
`(460, 16, 360, 96)` lies wholly inside the modal/workspace rectangle `(160, 16, 960, 688)`
at the supported viewport floor, and §1.2 fixes no precedence between them. **That belongs to
§1.2's owner.** ADR
[`0134`](../../../../decisions/0134-alert-r02-packs-two-instances-of-one-catalogued-card.md)
records the arithmetic at all three profiles; the existing capture `40` records the condition.

**PRE-EXISTING**, and already open as the unchecked item in
`docs/tasks/lanes/04/2026-09-12-alert-r02-implementation-status.md`.

## The same unstated precedence reaches two more zones

Visible in `10`, `11` — **and already visible in the existing capture `40`, where it was not
remarked on.** No new capture was taken for it, because the existing evidence carries it.

At 1280×720 the modal rectangle spans `x 160…1120`, `y 16…704`. §1.2's STANDARD resources
rectangle is `(16, 16, 360, 88)`, spanning `x 16…376`, so **216 of its 360 px — the right two
of its three counter columns — lie inside the modal rectangle**, which is why only Food and
Stone are readable in `10` and `11`. The minimap frame is overlapped from `x = 160` likewise,
cutting `No world generated` to `No world genera`. It is the same missing §1.2 precedence
rule, not three separate defects, and it is named here so the owner sees its full extent.

---

# What these images do not establish

* **No visual approval. None is claimed and none is granted.** ART-UI-12 is Brendan's.
* No fix. No `godot/scripts/` file was touched on this branch; both defects are recorded
  exactly as they stand on `127c8e4`.
* No screen-reader qualification. Accessible names and descriptions are set and asserted
  elsewhere; no assistive technology was run for these captures.
* No Windows, minimum-hardware or high-DPI claim.
* No statement about 1920×1080 or about WIDE — every capture here is at the supported
  viewport floor, deliberately, because that is where both defects are worst.
