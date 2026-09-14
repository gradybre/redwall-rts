# UI-C3-R01 — cycle-03 geometry, 2026-09-14

Task: 04_5_ui_visual_refinement.md
Ruling: `docs/rulings/2026-09-14_cycle03_ui_geometry.md` (UI-C3-R01)
Decision: [0144](../../../decisions/0144-the-ordinary-workspace-was-an-unimplemented-amendment.md)
Base: `origin/master` at `388f4f4`, branch `feat/ui-responsive-c3`

**No visual acceptance is claimed or granted by this lane.** ART-UI-12 remains Brendan's
decision and Astra's own UI verdict is "a planner assessment". Nothing here is an approval,
and `docs/planning/art_approvals.json` was not touched.

## §2 — resource cards

- [x] 56 px readout cells in a 128 px frame at all three profiles; frame widths retained at
  360 / 480 / 176 and the resource origin at (16,16). Rows at local y8 and y64, gap 8,
  width `min(144,(R-32)/3)`; NARROW keeps two 104x56 cells with its Expand button moved to
  (136,42).
- [x] Two measured lines: a 16 px optical icon and a 4 px gap beside a 14 px caption in a
  20 px line box, then the number alone in a 26 px line box at `cell_width-8` — 101⅓ at
  STANDARD, 136 at WIDE, 96 at NARROW. Godot's own 3 px Label line spacing is overridden to
  0, because 20+26+8 is what fits 56.
- [x] Captions `Ready food / Fuel / Wood / Stone / Residents / Beds`, NARROW `Food /
  Residents`, with the full Ready food meaning kept in the accessible description. Every
  caption is measured against its own gutter in the vendored face at both profiles.
- [x] The explicit overflow exception: a value measured too wide at 18 px keeps its caption
  and its numeric line becomes **See ledger** at 16 px, which activates UI-SET-009's ledger.
  The exact figure stays in `_counter_full` and in the accessible description. No K/M, no
  ellipsis, no crop, no shrunken numeral, no falsely smaller stock.
- [x] An unavailable counter reads **Unavailable** at 16 px and keeps its named missing
  owner. It is not an overflow and does not claim a figure exists.
- [x] Inset focus ring: 2 px inset 1 px, entirely inside the reserved 4 px padding, asserted
  against the touching row below. Every other control keeps §2.2's outward offset-2 ring.
- [ ] **Not this lane's files.** `ready-food days with exactly two decimals and ` days`` and
  `living population as N / 256` are composed in `scripts/systems/economy_system.gd` and
  `scripts/systems/ui_manager.gd`. `hud.gd` renders byte for byte and must not derive, so the
  blocker is named in its header comment instead of being invented. The cell draws whichever
  form arrives.
- [ ] **Art gap, not generated here.** Only `food` and `people` have an authored 16 px
  `symbolic16` variant; fuel, wood, stone and beds take ART-UI-05's optical line glyph at
  16 px. No asset was bought or made.

## §1/§4 — the workspace, and the record correction

- [x] `ID_WORKSPACE` no longer takes `_geometry.modal` for an ordinary page. SET-UX-VIS-002
  §4.2's variant is implemented: width `min(640,Lw-32)`, bottom `command_strip.top-8`, top at
  least `management_top`, command-strip centred, clamped inside the safe viewport and off an
  open detail column, height `min(content,560,available)`.
- [x] Compact management variant below the band when under 248 px remain: `(106⅔,152,640,312)`
  at logical 853⅓x480, with 188 px of scrollable body between the fixed 64 header and 60
  footer. Asserted in both `ui_layout.gd` and the built shell.
- [x] `management_top = max(128, bottom(resources), bottom(alerts), bottom(time)) + 8` — 152 at
  every supported viewport and user scale, swept.
- [x] Real modality preserved: `MODAL_PAGES` (UI-SET-103, the name editor) keep §1.2's centred
  rectangle, layer 80 and their scrim, and a test asserts that a true modal still occludes. The
  HUD was **not** raised above dialogs.
- [x] §3's layer for the frame and its pages is now 40 ordinary / 80 compact-or-modal, and the
  scrim follows: an ordinary workspace raises none and the world beside it stays clickable; the
  compact variant raises one, so a click on a dimmed alert cannot become a world command.
- [x] **Correction to this lane's own record.** `2026-09-12-alert-r02-implementation-status.md`
  left the occlusion open as "a §1.2 rectangle collision" for §1.2's owner, and the cycle-01
  evidence README ascribed it to unresolved precedence. Both were wrong: §4.2 already
  distinguished the two variants and `ui_shell.gd` had implemented only the modal one. Those
  two files are historical evidence and are left as written; this is the correction.
- [x] Fixed on the way, found in a native capture and not in the suite: the workspace content
  column was given the ScrollContainer's *realised* width, which with horizontal scrolling
  disabled is a ratchet that can only grow. The roster kept the 936 px rows of the old
  960-wide frame inside the 640-wide one and every resident's health line was clipped.

## §3 — reachable alerts

- [x] STANDARD/WIDE zone height 104, content 100, minimum full-or-summary card 48; two full
  cards plus the 4 px gap consume exactly 100. The ruling's own cases are the test: 48+4+48
  fits, 70+4+48 does not, a 101 px first card becomes a 48 summary and still admits a second.
- [x] NARROW keeps outer 48 / card 44 with summary-only vertical padding 8 and horizontal 12,
  content centred in the 44. Full messages keep the 12 px panel padding everywhere.
- [x] Every authored summary is now validated against the card HEIGHT it is drawn in as well
  as its width, at all three profiles, wrapped into its own interior.

## Registry

- [x] Six §4 rows moved and no others: UI-SET-001 `176..480 x 128`, UI-SET-002..007
  `104..144 x 56`, UI-SET-010 maximum height 104, UI-SET-011 maximum height 100 with its 44 px
  NARROW minimum retained. Widths unchanged. UI-SET-051's row is unchanged; its compact
  placement overrides it at construction only.

## Verification

- Suite: `4394 test(s), 156031 assertion(s), 1 failure(s)` — the single failure is
  `test_the_permanent_hud_leaves_the_centre_of_the_world_clickable` in
  `godot/test/test_ui_hit_test.gd`, **outside this lane's allowlist and deliberately not
  touched**. Its `_world_point()` samples the world band from a fixed `y=120`, which the
  128 px resource frame now covers at y120 and y136. The one-line fix — deriving the band
  from `_geometry.management_top` instead — was applied temporarily, produced
  `4355 test(s), 155704 assertion(s), 0 failure(s)` on this branch at that moment, and the
  file was restored and byte-compared (`41a1732ce2faaa0e…`). It is reported, not committed.
- `python3 docs/validation/ui_refinement_contract.py` — `"status": "PASS"`.
- `godot --headless --path godot --editor --quit` — clean.
- Ten mutants, one per Godot invocation, every production file `shasum -a 256` compared
  against a pristine copy after each restore. All ten killed; no survivors.
- Native windowed captures repeating the cycle-01 conditions 01–12. Paths are reported to the
  integration lead: `docs/validation/evidence/ui-refinement/cycle-03/` is not in this lane's
  allowlist and nothing was written there.
- The paired occlusion captures were measured with the retained comparator, not inspected. With
  the roster workspace OPEN, captures `10` (alerts expired) and `11` (alerts active) now differ
  in **15360 of 15360 pixels** over card 0's `(462,18,320,48)` and again over card 1's
  `(462,70,320,48)`. Cycle-01 measured **0 of 14080** over the same condition, which is what
  proved the occlusion. The whole-frame difference is bounded to `(460,16,359,103)` — the alert
  zone and nothing else — so the alerts are the only thing that changed between the two frames.
