# ALERT-R02 — implementation status, 2026-09-12

Task: 04_5_ui_visual_refinement.md
Date: 2026-09-12


Implemented and recorded in
[0134](../decisions/0134-alert-r02-packs-two-instances-of-one-catalogued-card.md).
Native captures 32–40 in
[the UI evidence README](../validation/evidence/ui-refinement/README.md).

- [x] `alert_stack_into()` takes an explicit notice `count` and refuses one it has no
  measurement for (`UI_INVALID_ALERT_NOTICE_COUNT`), so an empty slot never becomes an
  empty card. The four packing rules are implemented as written and swept in
  `test_ui_layout.gd`.
- [x] NARROW is compact by construction: `alert_zone_interior(NARROW)` is 44, which IS
  `ALERT_CARD_HEIGHT`, so the ceiling equals the floor. Swept over eight measured
  heights; capture `38` shows the same notice compact at NARROW and complete at STANDARD.
- [x] STANDARD/WIDE prefer the complete message and grow the card to hold it; captures
  `36` and `37`.
- [x] A second UI-SET-011 **instance** — not a new §4 id — with its own rectangle, its own
  notice, its own click region, its own tab stop between card one and the history rail,
  its own Enter/Space activation and its own focus return on close.
- [x] The undisplayed count is published through UI-SET-102's existing 32 px trigger
  description. No third row was added to the 96 px zone.
- [x] No truncation, no ellipsis, no font reduction: a card prints exactly its authored
  summary or exactly its message, asserted across both cards and all three profiles.
- [ ] **Open, not ALERT-R02's:** the centred workspace frame occludes the whole
  top-centre alert zone at 1280×720 at both STANDARD and NARROW. §3's layer table already
  puts the workspace above the permanent HUD, so this is a §1.2 rectangle collision with
  no stated precedence, not a z-order defect. Capture `40`; arithmetic in ADR 0134.
- [ ] **ART-UI-12 visual verdict remains open.** Nothing above claims visual approval.
- [ ] No screen-reader qualification. Both cards' names and descriptions are set and
  asserted; no assistive technology was run.
