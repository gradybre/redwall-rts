# UI-C3-R01 evidence — cycle 03

Repeats cycle-01's twelve conditions after implementing UI-C3-R01. Read beside
[the cycle-01 captures](../cycle-01/README.md), which measured the defects this set answers.

**No visual approval is claimed or granted here. ART-UI-12 remains Brendan's decision**, and
Astra's own Cycle 3 UI verdict is explicitly "a planner assessment; Brendan's ART-UI-12 decision
remains pending."

## How these were produced

Native macOS, windowed, absolute `save_png` path, after `godot --headless --path godot --editor
--quit` in a fresh worktree. The capture and diff harnesses are the ones retained by the cycle-01
lane and are **byte-untouched**: `capture_artui12_scratch.gd` `sha256 67966654b970ff72…`.

```
godot --path godot \
  --script ../docs/validation/harnesses/artui12/capture_artui12_scratch.gd \
  --resolution 1280x720 -- <ABSOLUTE>/<name>.png <mode> <scale>
```

Each `.log` beside a `.png` is that run's own output.

## What changed, measured

**The occlusion is fixed.** With the roster open, capture `10` (alerts expired) against `11`
(alerts active) now differ in **15360 of 15360** pixels over card 0 `(462,18,320,48)`, and again
over card 1 `(462,70,320,48)`. Cycle-01 measured **0 of 14080** — the cards were placed, reported
`visible = true`, and drew nothing. Whole-frame difference is bounded to `(460,16,359,103)`: the
alert zone and nothing else moved.

The cause was not the specification. SET-UX-VIS-002 §4.2 already distinguishes ordinary
workspaces from centred modals, and `ui_shell.gd` was placing `ID_WORKSPACE` with
`_geometry.modal`. See [ADR 0144](../../../decisions/0144-the-ordinary-workspace-was-an-unimplemented-amendment.md).

**The counters read.** Capture `03` is the ladder case: `Stone 123` and `Residents 1234` were
`Stone 12` and `Resident` in cycle-01, and now print in full on two lines at 56px cells in a
128px frame. A value too long for its card gets an explicit **See ledger** action with full-value
accessibility — never a K/M abbreviation and never clipped digits.

## One harness caveat

`_report_cell()` prints `button.text`, which is now `""` because each cell's two lines are child
Labels. Its `text_px=0.00 … verdict=FITS` lines are therefore uninformative in this set; the
images and the rect/budget figures on the same lines are the evidence. The retained harness was
deliberately not modified — it belongs to the cycle-01 record.

## Still open, and not fixed here

Two value formats §2 requires are owned elsewhere (`ui_manager.gd` / `economy_system.gd`): ready
food has no `" days"` unit, and living population is not rendered `N / 256`. `hud.gd` renders byte
for byte by contract, so adding either there would make it derive a value it is given.

The workspace header prints the §4 **name** of the open page, so the roster reads `Resident row`
— §4 catalogues UI-SET-069 as a row, not a page. A page title was not invented; it is a question
for §4's owner.

The flat roster and the raw `Paused: PLAYER` readout, which Astra names as falling below the
crafted journal/woodland finish, are a separate presentation lane.
