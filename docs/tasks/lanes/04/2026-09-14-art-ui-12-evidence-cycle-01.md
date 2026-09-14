# ART-UI-12 cycle-01 evidence — status, 2026-09-14

Task: 04_5_ui_visual_refinement.md
Date: 2026-09-14
Base: `origin/master` at `127c8e4`, branch `feat/art-ui-12-evidence`
Suite at capture: `ok: 4336 tests, 152719 assertions, 0 failures.`

Twelve native windowed captures at 1280×720 in
[`docs/validation/evidence/ui-refinement/cycle-01/`](../../../validation/evidence/ui-refinement/cycle-01/README.md),
which is an **increment** on the forty in
[`../README.md`](../../../validation/evidence/ui-refinement/README.md) and replaces none of
them.

**No visual approval is claimed or granted here or in the evidence README. ART-UI-12 is
Brendan's verdict.** No agent grants its own art approval.

## Closed

- [x] **Counter clipping isolated at 1280×720 at 100%, 125% and 150%**, captures `01`–`09`,
  with the short marker content and the long store-derived content in matched pairs at the
  same window and scale. Previously the condition was only visible inside captures whose
  subject was the alert card.
- [x] **The boundary is measured, not asserted.** Text budget is 77.33 px at STANDARD and
  72.00 px at NARROW — cell width less a 24 px icon, 2 + 2 px style margins and 4 px
  separation — and every cell's measured text width is printed in the evidence README.
  Capture `03` steps one glyph at a time across that budget between adjacent cells.
- [x] **Two findings the existing captures did not carry**: no populated counter fits at the
  supported viewport floor at any of the three user scales, and `Residents` overflows its
  cell with **no value at all**, because the label alone measures 86.00 px against a 77.33 px budget.
- [x] **The alert occlusion is demonstrated rather than inferred**, captures `10`–`12`: the
  same screen with the alert hold expired and with two active cards, plus a workspace-closed
  control. **0 differing pixels of 14080** over card 0's rectangle and **0 of 11520** over
  card 1's, against 2829 and 2641 for the control. Captures are bit-deterministic — the same
  mode twice gives 0 differing pixels of 921600 — so those zeroes are exact.
- [x] The same unstated §1.2 precedence is named as also covering the STANDARD resources
  rectangle (216 of its 360 px inside the modal rectangle) and the minimap frame. **No new
  capture was taken for it** — it is already visible in existing capture `40`, where it was
  not remarked on.

## Open, and not this lane's to close

- [ ] **Counter clipping is unfixed.** UXV-032, recorded as a separate defect in ADR
  [`0076`](../../../decisions/0076-the-narrow-alert-card-is-an-authored-summary.md); that
  ruling's compact-summary exception covers HUD notices and does not extend to other labels.
- [ ] **The workspace/alert rectangle precedence is unfixed and unstated.** §3's layer table
  is consistent; §1.2 fixes no precedence between `(460, 16, 360, 96)` and
  `(160, 16, 960, 688)` at the viewport floor. **§1.2's owner holds it.** Arithmetic in ADR
  [`0134`](../../../decisions/0134-alert-r02-packs-two-instances-of-one-catalogued-card.md).
- [ ] **A 4 px horizontal shift of the roster's row labels** between two frames whose only
  difference is the alert hold expiring, while the row's own reported rectangle
  `(172, 28, 280, 56)` is identical in both. Observed, recorded, **not investigated** and not
  claimed as part of either defect above.
- [ ] **ART-UI-12 visual verdict remains open.**
- [ ] No screen-reader qualification, no Windows, minimum-hardware or high-DPI claim, and no
  WIDE or 1920×1080 capture — every frame here is at the supported viewport floor on purpose.

## Scope kept

No `godot/` file is changed on this branch. `docs/design/ui_refinement/` is untouched.
`docs/planning/art_approvals.json` is untouched — approvals are Brendan writing `approved`
and a name, and no tool or agent writes that file. No paid generation credits were spent.
**Restored 2026-09-14, answering Astra's Cycle 2 follow-up** — "preserve those harnesses
under a validation-owned path so the evidence can be reproduced from repository contents":
both capture harnesses now live in
[`docs/validation/harnesses/artui12/`](../../../validation/harnesses/artui12/) rather than
being deleted, and every command in the evidence README names the path it invokes. They are
not `godot/` sources — nothing in the project loads them — and Godot 4.7.2 resolves a
`--script` path outside the project directory, so no loose file or copy step is needed.
Re-running capture `03` from the restored path reproduced the committed file byte for byte.
