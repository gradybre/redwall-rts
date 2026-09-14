# UI-IDENTITY-R01 and NEED-RATE-R01 — implementation status, 2026-09-12

Task: 04_5_ui_visual_refinement.md
Date: 2026-09-12


Adopted as [0097](../decisions/0097-resident-heading-and-public-need-rates.md);
implemented and recorded in [0098](../decisions/0098-the-resident-identity-row-and-its-five-bound-rates.md).

- [x] Identity row `20 | medallion | 8 | name column | 8 | 44 Close | 20` at the
  published 48/64/64 and 172/172/220 columns, medallion BESIDE the name at all
  three profiles. `ui_resident_header.gd` holds the table and derives it.
- [x] UI-SET-037's 280 px minimum overridden for the resident template only, with
  the name column allocated exactly and no `custom_minimum_size` to clamp back up.
- [x] Whole-word wrapping with a grapheme-safe break, Noto Serif 20/600 kept, the
  full persisted name kept, no ellipsis, no font reduction, no 64 px height cap.
- [x] Dedicated header/body/footer: identity height measured as the maximum of
  medallion, complete text block and Close; body height recomputed from it;
  §4.1's 64 px footer with its 44 px Center view fixed; only the body scrolls.
- [x] All five need rows bound from one validated `EntityRef`/generation snapshot,
  with `Capped` disclosure, the `pp/h` unit and the accessible full words. No rate
  formula in the UI and no private column read.
- [x] Native macOS captures at all three profiles and 100/125/150%, including
  1280x720@150%, with short, 32-character, long-unbroken and combining names.
  See [the evidence README](../validation/evidence/ui-refinement/README.md).
- [ ] **Brendan's visual verdict on the identity row.** Arithmetic fit is not a
  screenshot pass and a screenshot pass is not approval. ART-UI-12 is open.
- [ ] **Screen-reader qualification.** Heading semantics, the decorative medallion
  and the Capped explanation are set and asserted; no assistive technology was run.
- [ ] **`ui_manager.gd` passes the selected `EntityRef` to `fill_needs_for()`.**
  The ref-first entry point exists and is tested; the manager still calls the
  slot-keyed form, which resolves `ref_of(slot)` and goes through the same
  validated boundary. Integration lead owns that file.
- [ ] **Center view has no camera to bind.** The 44 px action is built, labelled
  and disabled with `ui_availability.gd`'s REASON_NO_WORLD_CAMERA. Nothing here
  supplies a camera, and §4 has no registry id for the action.
- [ ] **No verified life stage reaches the identity column.** Actual species and
  the published status are shown; age remains stated as unavailable.
