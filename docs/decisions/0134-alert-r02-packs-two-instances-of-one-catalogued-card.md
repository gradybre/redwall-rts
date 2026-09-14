# 0134 — ALERT-R02 packs two instances of ONE catalogued card
Date: 2026-09-12 · Status: Accepted

## Decision

ALERT-R02's adaptive packing is implemented in `ui_layout.gd`'s `alert_stack_into()`
and `ui_shell.gd`'s alert zone. Four points were settled:

1. **`alert_stack_into()` takes an explicit `count`.** How many notices want a card is
   the caller's fact; the shell's measured buffer is preallocated at
   `ALERT_CARDS_WIDE`, so its `size()` cannot carry that number. A count outside
   `0..measured.size()` is refused with `UI_INVALID_ALERT_NOTICE_COUNT`; nothing is
   clamped and no empty card is placed for a notice that does not exist.
2. **NARROW's compact form is a construction, not a length test.** `ALERT_H` is
   `[48, 96, 96]`, so `alert_zone_interior(NARROW)` is 44 — exactly `ALERT_CARD_HEIGHT`.
   The ceiling equals the floor, which is why the earlier `alert_card_sized()` helper
   could not work and was replaced by `alert_stack_into()`. The
   `profile != PROFILE_NARROW` term states it in the code rather than leaving it to
   arithmetic that would silently admit a short message.
3. **The second card is a second INSTANCE of UI-SET-011, not a new §4 element.**
   §4 catalogues one "Alert card" row and §8.2 lists element 011 exactly once. No
   second id was invented. The instance shares element 011's registry row, its
   click-through id and its accessible role, and carries the node-name suffix
   `alert_card_2`, exactly as UI-SET-066's instance inside UI-SET-103 carries
   `create_settlement`. Its tab stop is spliced at the `Control` level in
   `_wire_second_card_focus()`, because `ui_focus_order.gd`'s table is keyed on §4 ids.
4. **"Adaptive fitting" writes exactly one of two authored strings.** A card prints
   either the notice's authored summary or its message byte for byte. There is no
   third branch: no ellipsis, no `substr`, no reduced font size. The card that cannot
   hold its measured content is SUMMARISED, never clipped.

## Why

ALERT-R02 says STANDARD/WIDE "prefer complete text with adaptive fitting/fallback in
the existing zone" while NARROW is "always compact", and requires full selected-notice
details and accessibility to be preserved. The risk it names is that "fitting" becomes
truncation. Choosing the string AFTER the rectangle that must hold it is what makes the
two impossible to disagree: `_place_alert_cards()` measures, asks the layout to pack, and
only then prints. `_measured_full_height()` measures the NOTICE's own message from the
font — not the Label's current text — so a card cannot oscillate between the two
presentations on successive passes.

A distinct §4 id for card two was rejected. §4's ids "run 1..103 with no gaps" and every
id is a row in four parallel registry tables that this lane does not own; inventing a
104th would be exactly the invented constant the working rules forbid. Element 011 is a
*definition*, and §4's preamble allows repeated rows as "instances of a definition with
stable runtime IDs" — the same mechanism already used for the Create button.

## Measured consequence, worth knowing before reading the ruling literally

ALERT-R02's worked consequence "two 44px full cards fit exactly 92px" is packing
arithmetic, not a claim about typography. Measured in the real theme at 1280×720:
UI §2.1's NOTICE type is 16 px, one wrapped line is **23 px**, and §1.2's 12 px panel
padding top and bottom makes the smallest possible FULL card **47 px**. So:

| first card | second card | result |
|---|---|---|
| 47 (one line, full) | — | 47 + 4 leaves 41 < 44, so the second notice is **not placed**; the rail states it |
| 44 (summarised) | 47 measured | second gets its 44 px **summary**; both shown, 2+44+4+44 = 94 |
| 116 (four lines) | — | first summarises to 44, which is what lets a second card fit at all |

A 44 px *full* card is therefore not reachable at this typography. The packing rules are
implemented exactly as written; this is measured, not assumed, and it is why the
"capacity" captures show two summarised cards rather than two full ones.

## Consequences

- `alert_stack_into()`'s signature changed; `test_ui_layout.gd`'s six call sites now pass
  `measured.size()` and assert the same things they did before.
- `undisplayed_notices()` is `active_count - visible_count`, published through UI-SET-102's
  existing 32 px trigger description. No third row was added to the 96 px zone.
- `_on_control_focused()` looks a Control up by §4 id and cannot serve two instances of
  one id, so the cards use `_on_alert_card_focused(instance)` and
  `_show_focus_visuals(control, id)`. `focused_element()` still answers 011 for either
  card; `focused_alert_card()` says which.
- `ui_notices.gd` was **not** modified. Its record already carries separate `summary` and
  `message`, severity, source, code, recovery and a stable id — exactly the notice model
  ALERT-R02 asks for.
- No new packed column was added, so no ledger or registry row is owed.

## Still open, and NOT decided here

**The centred workspace frame occludes the whole top-centre alert zone at 1280×720.**
Reported by the roster lane and reproduced: capture
`40_alertr02_roster_occlusion_standard_1280x720.png`. At 1280×720 @100% the alert zone is
`(460, 16, 360, 96)` and §1.2's modal/workspace frame is
`min(960, 1248) × min(720, 688)` centred, i.e. `(160, 16, 960, 688)` — the alert zone lies
wholly inside it. At 1280×720 @150% (NARROW) the zone is `(246.67, 76, 360, 48)` and the
frame is `(16, 16, 821.33, 448)`; again wholly inside. At 1920×1080 the frame starts at
y=180 and there is no overlap.

This is **not** a z-order defect to fix here: §3's layer table puts "Build/recipe/roster/
job/feast workspace" at layer 40 and "Permanent HUD zones" at layer 20, so the workspace
drawing above the alert zone is the specification working as written. What is unresolved
is that §1.2 publishes two rectangles that collide at the supported viewport floor and
fixes no precedence between them. Resolving it means moving the alert zone, moving or
shrinking the workspace frame, or stating a third rule — all §1.2 geometry this lane does
not own. It is adjacent to ALERT-R02 rather than part of it, and is recorded here as
**open** rather than worked around.

## Source

- `docs/rulings/2026-09-12_alerts_and_seed_expiry.md`, ALERT-R02, rules 1–4.
- `docs/rulings/2026-09-11_initial_ids_and_narrow_alerts.md` (R-UI-ALERT-001), which
  ALERT-R02 clarifies.
- `docs/ui_ux_controls.md` §1.2 (zone rectangles, `ALERT_H`), §3 (layer table), §4
  (element catalogue and repeated-row instances), §7 (at most two cards), §8.2 (focus order).
- Typography measured in the real theme through `Font.get_multiline_string_size()`; see the
  table above.
- Native captures 32–40 in `docs/validation/evidence/ui-refinement/`.
