# 2026-09-15 UI-C3-EVIDENCE — the input half is captured

Task: 04_5_ui_visual_refinement.md
Date: 2026-09-15


UI-C3-EVIDENCE's screenshot half landed as
[`cycle-03/`](../../../validation/evidence/ui-refinement/cycle-03/README.md). Its **input** half
is now captured in
[`cycle-03-input/`](../../../validation/evidence/ui-refinement/cycle-03-input/README.md):
fourteen rendered hit-region overlays at 1280×720 at 100/125/150%, with a retained harness and a
per-run log carrying the §1.2 geometry, the raw region table and every probed point's owning
element and §3 layer.

Confirmed against a running windowed shell, not only against a passing test: the resource frame
claims exactly y16…143 and x16…375 at STANDARD, `(20,144)` and `management_top` `(20,152)` are
the world's, and the two coordinates `test_ui_hit_test.gd::_world_point()` used to sample —
`(240,120)` and `(368,136)` — are owned by UI-SET-006 and UI-SET-001. Both alert cards own their
own rectangles with the roster open and closed at STANDARD and NARROW 125%; at NARROW 150% the
compact workspace raises §4's SCRIM and the whole HUD leaves input, as §4 requires.

**Three things the captures found are open and belong to other owners. None is fixed here.**

1. **UI-SET-051, 092, 036, 038 and 098 are drawn, opaque and non-IGNORE, and have no input
   rectangle.** `_register_hit_regions()` registers only when `creates_control()` is true, and
   that is false for an unsatisfied §4 Gate — but the shell draws them anyway. Measured
   consequence: the centre of an open roster workspace and the centre of an open detail panel
   both reach the **world**. That is UX-T04's own failure criterion. Whether the correction
   belongs to the gate, to the draw or to their order is §4's owner's call; do not assume it is
   the hit table's.
2. **UI-SET-069 and 094 hold pre-sort rectangles at rest.** Registration runs inside
   `layout_for()`, before Godot's containers sort their children, so the roster row is registered
   at `(444,216,280,56)` and drawn at `(444,268,616,56)`. Captures `13`/`14` show one extra
   `layout_for()` reconciling them, which is how the timing artefact is separated from item 1.
3. **The NARROW command-strip/minimap overlap does not reproduce.** Their rectangles are 104 px
   apart at 125% and 18⅔ px apart at 150%. What does cross at NARROW is `085 ERROR PANEL`, which
   is 720 logical px wide, sits at permanent-HUD layer and claims the centre of the viewport, and
   the compact workspace, which covers 552×136 of the command strip and 69⅓×192 of the minimap.

`test_ui_shell.gd::test_the_ordinary_workspace_raises_no_scrim_and_the_compact_one_does` calls
`(1000,300)` "the world beside it". At 1280×720/100% with the roster open that point is **inside**
the ordinary workspace frame `(432,152,640,408)`; it reads world only because of item 1, and
after one relayout it belongs to UI-SET-069 at layer 40. The assertion is not wrong about the
scrim; its chosen point does not mean what its message says. Left untouched — changing a test to
match a finding is the owner's decision, not this lane's.

No visual approval is claimed or granted. ART-UI-12 remains Brendan's decision and Astra's Cycle
3 UI verdict is explicitly a planner assessment. No file under `godot/` was modified, and the
cycle-01 harnesses under `docs/validation/harnesses/artui12/` are byte-untouched.
