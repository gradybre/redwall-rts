# UI-C3-EVIDENCE — input regions of the corrected shell, cycle 03

The **input** half of UI-C3-EVIDENCE. The screenshot half is
[`../cycle-03/`](../cycle-03/README.md), which shows what the corrected shell looks like.
These fourteen captures show **where its clicks go**.

**No visual approval is claimed or granted here. ART-UI-12 remains Brendan's decision**, and
Astra's own Cycle 3 UI verdict is explicitly "a planner assessment; Brendan's ART-UI-12 decision
remains pending." Nothing below is an acceptance of finish, typography, colour or layout taste.

## Why this set exists

`test_ui_hit_test.gd::_world_point()` used to sample the world band from a hard-coded
`y = 120.0`. UI-C3-R01 §2 gives the resource frame 128 px spanning y16…144, so 18 of its 1000
samples began landing on the resource cluster, and the fixture was re-anchored on
`_geometry.management_top`.

**That change was verified by a passing test, not by evidence.** This set confirms the click
regions against a running windowed shell.

## How these were produced

Native macOS, windowed, absolute `save_png` path, after `godot --headless --path godot --editor
--quit` in a fresh worktree of `50e78ce`. Every run:

```
godot --path godot \
  --script ../docs/validation/evidence/ui-refinement/cycle-03-input/harness/capture_hit_regions.gd \
  --resolution 1280x720 -- <ABSOLUTE>/<name>.png <mode> <scale> [relayout]
```

wrapped in `perl -e 'alarm 300; exec @ARGV'`. Each `.log` beside a `.png` is that run's own
output: the §1.2 geometry, the raw region table, one line per drawn element and one line per
probed point.

The harness is `harness/capture_hit_regions.gd`, `sha256
6a061dafc4e2917f6e9b14c8ff411a1daf9c681b45b15baa3712a4988ea66973`. It is **retained, not
scratch**. It sits here rather than in `docs/validation/harnesses/artui12/` only because this
lane's allowlist is this directory; the cycle-01 harnesses there are byte-untouched.

Nothing in `godot/` was modified for this set. The harness asserts no geometry of its own: every
rectangle it draws is read back from the shell's own `Control`s, and every verdict it prints is
`ui_hit_test.gd`'s own answer at a point.

## Reading the overlay

| Paint | Meaning |
|---|---|
| Thin cyan outline | a drawn element that consumes input |
| Thin grey outline | a drawn element with `MOUSE_FILTER_IGNORE` — decoration |
| Thick yellow outline, id label | the elements this capture's question is about |
| Thick red outline, sentence label | the hit table disagrees with what is drawn |
| Magenta horizontal lines | UI-C3-R01 §4's `resource frame bottom y=144` and `management_top y=152` |
| Green dot `#n WORLD` | probe n: the point reaches the 3D world |
| Red dot `#n UI <id>` | probe n: §4 element `<id>` takes it instead |
| Red dot `#n SCRIM` | probe n: a modal SCRIM is up and nothing below it receives input |

`#n` indexes the `[probe]` lines in the matching `.log`, which carry the point's name, its
logical coordinates and the §3 layer that answered.

## The files

All at **1280×720 physical**. The profile follows from the user scale, because §1.2 keys the
breakpoint on the logical width: 100% → `Lw` 1280 → **STANDARD**; 125% → 1024 → **NARROW**;
150% → 853⅓ → **NARROW**. WIDE is unreachable at this viewport and is not in this set.

| File | Scale | Profile | Mode |
|---|---|---|---|
| `01_boundary_standard_1280x720_100` | 100% | STANDARD | world created, nothing opened |
| `02_boundary_narrow_1280x720_125` | 125% | NARROW | world created, nothing opened |
| `03_boundary_narrow_1280x720_150` | 150% | NARROW | world created, nothing opened |
| `04_roster_open_standard_1280x720_100` | 100% | STANDARD | two real notices, roster **open** |
| `05_roster_closed_standard_1280x720_100` | 100% | STANDARD | the same notices, roster **closed** |
| `06_roster_open_narrow_1280x720_125` | 125% | NARROW | two real notices, roster **open** |
| `07_roster_closed_narrow_1280x720_125` | 125% | NARROW | the same notices, roster **closed** |
| `08_roster_open_narrow_1280x720_150` | 150% | NARROW | two real notices, roster **open** (compact) |
| `09_roster_closed_narrow_1280x720_150` | 150% | NARROW | the same notices, roster **closed** |
| `10_detail_open_standard_1280x720_100` | 100% | STANDARD | UI-SET-036 detail panel open |
| `11_detail_open_narrow_1280x720_125` | 125% | NARROW | UI-SET-036 detail panel open |
| `12_detail_open_narrow_1280x720_150` | 150% | NARROW | UI-SET-036 detail panel open |
| `13_roster_open_standard_1280x720_100_after_relayout` | 100% | STANDARD | `04` after one extra `layout_for()` |
| `14_roster_open_narrow_1280x720_150_after_relayout` | 150% | NARROW | `08` after one extra `layout_for()` |

The roster modes drive UI-SET-103's own `Create` with the HOLT architecture, which
`ui_world_session.gd` refuses as unauthored, exactly as the cycle-01 and cycle-03 occlusion
captures do. The refusal sentences and their severities are composed by the code under test; the
harness supplies no message text. `choose HOLT -> false` and `create -> false` in the logs are
those refusals and are the same values the committed cycle-03 logs carry.

`13` and `14` exist because registration happens inside `layout_for()`, before Godot's
containers have sorted their children. They are **not** what a player gets at rest; `04` and
`08` are. The pair is what distinguishes a one-frame stale rectangle from a permanently absent
one — see finding 3.

## What the evidence shows

### 1. The boundary is where UI-C3-R01 §4 says it is

Captures `01`–`03`, probes `#0`–`#7`. At all three scales, in logical pixels:

| Probe | Point | Verdict |
|---|---|---|
| `#3` | `(20, 143)` — last row inside the resource frame | **UI 1**, layer 20 |
| `#4` | `(20, 144)` — first row below it | **WORLD** |
| `#5` | `(20, 152)` — `management_top` | **WORLD** |
| `#1` | `(375, 20)` — last column inside, STANDARD | **UI 1**, layer 20 |
| `#2` | `(376, 20)` — first column past its right edge | **WORLD** |

The frame claims exactly its own 128 px and not one row more, at half-open edges in both axes.
The world band begins where the reserved band ends.

### 2. The stale fixture is confirmed against a running shell

Probes `#6` and `#7` are the two coordinates the old `_world_point()` would have sampled:

- `(240, 120)` → **UI 6**, the Population readout, layer 20
- `(368, 136)` → **UI 1**, the resource frame, layer 20

Both are inside the corrected resource frame. The re-anchoring was correct, and is now
evidenced rather than only asserted.

Probes `#8` and `#9` are the re-anchored fixture's first and last samples,
`(240, management_top)` and `(864, management_top + 384)`:

- `#8` `(240, 152)` reads **WORLD** in every capture where no scrim is up — all three scales.
- `#9` `(864, 536)` reads **WORLD** at 100%, and at 150%. At **125%** it reads **UI 26**, the
  command strip, in `02`, `06` and `07`.

That is not a defect in the fixture. `_world_point()` builds its band from a geometry computed
by `compute_into(1280, 720, 100, …)` and its docstring scopes the band to "the centre band the
world owns **at 1280x720**" at that scale, which is STANDARD. It is recorded here because the
band is genuinely not world-owned at every profile, so the fixture must not be generalised to
one later: at 125% the logical viewport is 1024×576 and the command strip occupies
`(280,424,640,136)`, which contains `(864, 536)`.

### 3. Five drawn, opaque, clickable elements have no input rectangle

This is the fourth bullet of the lane, and it is the substantive finding.

`ui_shell.gd::_register_hit_regions()` registers a region only when
`_availability.creates_control(id, _gates)` is true. `creates_control()` is false for an element
whose §4 Gate is unsatisfied. But the shell **draws** some of those elements anyway, so the
table and the screen disagree:

| Capture | Element | Drawn rect (logical) | Table |
|---|---|---|---|
| `04`, `06`, `08` | **051 WORKSPACE** (`GATE_WORKSPACE`) | `(432,152,640,408)` at STANDARD | no region |
| `04`, `06`, `08` | **092 BACK** (`GATE_MODAL`) | `(444,508,240,44)` at STANDARD | no region |
| `10`, `11`, `12` | **036 DETAIL** (`GATE_SELECTED`) | `(928,128,336,576)` at STANDARD | no region |
| `10`, `11`, `12` | **038 DETAIL TABS** (`GATE_SELECTED`) | `(948,228,280,36)` at STANDARD | no region |
| `10`, `11`, `12` | **098 PIN** (`GATE_SELECTED`) | `(948,391,296,32)` at STANDARD | no region |

The consequence is measured, not inferred:

- `04` probe `#17`, the centre of the **open roster workspace** at `(752, 356)`: **WORLD**.
- `10` probe `#17`, the centre of the **open detail panel** at `(1096, 416)`: **WORLD**.
- `12` probe `#16`, the same at NARROW 150%: **WORLD**.

A click in the middle of a visible, opaque panel issues a world command. That is UX-T04's own
failure criterion — "zero unintended world orders" — and §1.2's "the viewport minus the ACTUAL
VISIBLE INPUT RECTANGLES", read the other way round: a rectangle that is visible must be in the
table.

`051` and `092` are absent in `13` and `14` too, so they are not a one-frame timing artefact.
`069 RESIDENT ROW` and `094 SCROLL` **are** a timing artefact: absent in `04`/`08`, present in
`13`/`14`. Registration runs inside `layout_for()`, before the workspace's containers have
sorted, so at rest the table holds a pre-sort rectangle — in `04` the roster row's registered
rectangle is `(444,216,280,56)` while it is drawn at `(444,268,616,56)`.

This set does **not** attribute blame or propose a fix. The gate ordering it exercises is the
one `test_ui_hit_test.gd::test_the_gate_decides_before_the_availability_claim_does` deliberately
pins, and whether the correction belongs to the gate, to the draw or to the order is §4's
owner's call.

### 4. The alert cards are not occluded by the roster at STANDARD or NARROW 125%

Probes `#12` and `#13`, the two cards' own centres, with the roster **open** and **closed**:

| Capture | Roster | Card 0 | Card 1 |
|---|---|---|---|
| `04` | open, ordinary (z40) | UI 11, layer 20 | UI 11, layer 20 |
| `05` | closed | UI 11, layer 20 | UI 11, layer 20 |
| `06` | open, ordinary (z40) | UI 11, layer 20 | — (NARROW has one card) |
| `07` | closed | UI 11, layer 20 | — |
| `08` | open, **compact (z80 + SCRIM)** | **SCRIM** | — |
| `09` | closed | UI 11, layer 20 | — |

Both cards own their own rectangles whenever input is live, including the second instance, which
`_register_second_card_region()` registers separately under element 011. UI-C3-R01 §4's reserved
band is why: alerts end at y120 (STANDARD/WIDE) or y124 (NARROW) and the workspace begins at
`management_top = 152`, so there is nothing to occlude.

At NARROW **150%** the workspace is the compact variant, raises a SCRIM at layer 80 and takes
the whole HUD out of input — every probe in `08` and `14` reads `SCRIM`. That is §4's stated
contract ("Background HUD controls are excluded from input/focus while this compact modal owns
input ... Do not let a click through a dimmed alert issue a world command"), and it is what the
capture shows.

### 5. The NARROW overlap is real, and it is not the command strip against the minimap

The lane brief records the command strip and minimap as "already reported to overlap" at NARROW.
Measured on `50e78ce` at 1280×720, **their rectangles do not intersect at either NARROW scale**:

| Scale | Minimap | Command strip | Gap |
|---|---|---|---|
| 125% | `(16,368,160,192)` → x 16…176 | `(280,424,640,136)` → x 280…920 | 104 px |
| 150% | `(16,272,160,192)` → x 16…176 | `(194⅔,328,640,136)` → x 194⅔…834⅔ | 18⅔ px |

Opening the detail panel narrows the strip rather than moving it (`12`: commands
`(192,328,309⅓,136)`), and the `[overlap]` audit reports **0 crossing pairs** in `02`, `03`,
`07`, `10`, `11`, `12`.

What does cross at NARROW is different, and the `[overlap]` lines in each log name every pair:

- **`085 ERROR PANEL` is 720 logical px wide** — wider than NARROW's whole content width at
  150% (853⅓ − 32 = 821⅓). It crosses the minimap frame, the minimap view and the command strip
  in `09` (roster closed, 3 crossings) and the workspace as well in `08` (19 crossings). It is
  registered at `LAYER_PERMANENT_HUD` (20), below the workspace's 40/80, so with the roster open
  at STANDARD the error panel takes points that are drawn as roster rows: `04` probe `#19`, the
  centre of roster row 0, reads **UI 85**.
- **the compact workspace covers the command strip and the minimap.** `08`: element 051
  `(106⅔,152,640,312)` crosses the command strip over **552×136** and the minimap frame over
  **69⅓×192**. The SCRIM makes this input-safe; it is still a visible surface painted over two
  permanent HUD zones, and it is what a reader should look at in `08`.

### 6. Nothing decorative takes a point, but the error panel does take the centre

`023 WORLD SURFACE` covers the full logical viewport and is registered **non-consuming** in all
fourteen captures; `074 FOCUS OUTLINE` and `086 PAUSE LABEL` likewise. §1.2's "a transparent
full-screen Control must not block the center" holds at runtime, not only in the fixture: no
capture has a decorative region taking a point.

The `centre of the world band` probe is nevertheless not always the world's:

| Captures | Centre of the world band | Verdict |
|---|---|---|
| `01`–`05`, `10`–`13` | `(640,360)` / `(512,288)` / `(426⅔,240)` | **WORLD** |
| `06`, `07`, `09` | `(512,288)` and `(426⅔,240)` at NARROW | **UI 85**, the error panel, layer 20 |
| `08`, `14` | `(426⅔,240)` | **SCRIM** |

`085 ERROR PANEL` is a real consuming control, correctly registered, so this is not the
finding 3 failure. It is the same 720-px-wide panel from finding 5, sitting across the middle of
a NARROW viewport at permanent-HUD layer whenever a notice raises it — `06`, `07` and `09` show
it claiming the point a player would read as open ground.

## What this evidence does not show

- **No visual approval.** ART-UI-12 is Brendan's decision and none of it is claimed here.
- **No pointer events were sent.** Every verdict is `ui_hit_test.gd`'s answer for a point, which
  is the shell's own mirror of each `Control`'s `mouse_filter`. This is not a test that a real
  `InputEventMouseButton` produces the same routing through Godot's own `_gui_input` dispatch,
  and it cannot be: no click was synthesised.
- **No keyboard, focus-order or screen-reader claim.** Tab order and accessible names are
  outside this set.
- **Only 1280×720.** UI-C3-R01 §5 also asks for 1920×1080 and 3840×2160 and for the logical
  breakpoint boundaries at 1120 and 1600. Those are not captured here, so **WIDE is not covered
  at all**, and neither is physical edge rounding above the supported floor.
- **No drag, scroll, box-select or double-click.** UX-T04's "1000 UI interactions" is a
  point-sampling fixture in the suite; this set probes named points, not gestures.
- **The `13`/`14` relayout pair is a diagnostic, not a runtime state.** It is produced by calling
  `layout_for()` a second time from the harness. A player never causes it except by resizing.
- **No fix is proposed and no file in `godot/` was touched.** Finding 3 in particular is reported
  to §4's owner, not resolved here.
