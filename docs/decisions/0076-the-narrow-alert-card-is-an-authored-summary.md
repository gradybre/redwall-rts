# 0076 — The NARROW alert card is an authored summary, not a shortened message
Date: 2026-09-11 · Status: Accepted

## Decision

R-UI-ALERT-001 is implemented as an authored **notice record** plus an authored
**compact summary table**, not as a runtime shortening rule.

- `godot/scripts/ui/ui_notices.gd` holds the whole condition — message, source,
  validation code, recovery, severity, occurrence count, first/last tick — in
  packed columns sized once to §7's 500-entry history cap.
- Eight authored categories each map to a severity word and a short cause title.
  The generation failure is `Error` / `Generation failed`, which the ruling names
  in terms. Nothing inspects a message string to guess a category; the caller
  that knows the condition names it.
- At NARROW the card always draws `"<Severity>: <Title>"` plus a `(+N)` count of
  other active notices. At STANDARD and WIDE it draws the whole message when the
  measured wrapped text fits the room the layout actually granted, and the same
  summary when it does not.
- `ui_layout.alert_stack_into()` replaced `alert_card_sized()`. The old function
  grew each card against the whole zone ceiling from a fixed row origin, which is
  how two cards came to overlap; the new one advances a cursor by the height it
  actually granted, so cards cannot overlap, and shows fewer when they do not fit.
- Activation — left click, Enter, or Space on the focused card — opens UI-SET-012
  with that notice selected and expanded, wrapping and scrolling, and closing it
  returns focus to the card. The accessible description carries severity, the
  **full original message**, and an `Open alert details` action.

There is no `substr`, no ellipsis, no font reduction and no discarded notice
anywhere on this path.

## Why

`ALERT_H` is `[48, 96, 96]`. At NARROW the alerts zone is 48 logical pixels: one
44-high card and its padding. UXV-032 forbids clipping, so the message wrapped,
and a three-line generation sentence drew over the pause line — visible in
`docs/validation/evidence/ui-refinement/screenshots/06_narrow_1280x720_150.png`.
`alert_card_sized()` was added to grow the card within its zone, which at NARROW
is a no-op by construction: the ceiling equals the floor.

The ruling settles it: keep the rectangle, and make the compact card a separately
authored summary with guaranteed full disclosure. An authored table is preferable
to a formatting rule because a title that does not fit is a title to be
**rewritten**, and a test can prove every one of them fits by measuring the real
theme font against the real card interior.

`ui_layout.alert_summary_width()` is that interior: 360 alert width, less §1.2's
40 px card margin (which contains the 36 px history rail), less two 12 px
paddings, less the 24 px severity icon and its 8 px grid gap — **264 logical
pixels**. It does not change with the user scale, because the whole composition is
in logical pixels, so one budget covers 100/125/150%.

## Consequences

- **The exception is narrow.** Authored summary plus guaranteed disclosure is
  allowed for compact HUD notices only. It does not extend to arbitrary labels,
  costs, the error panel or the history, all of which still wrap and scroll.
- **Adding a category means authoring a title and re-running the fit test.**
  `test_ui_notices.gd` measures every authored line, with the widest possible
  count suffix, against `alert_summary_width()` at all three user scales at the
  minimum supported display. A new language needs qualified localized titles, not
  automatic truncation.
- **UI-SET-012 became genuinely wired.** `ui_availability.gd`'s row for 012 was
  `REASON_NO_NOTICE_STORE`; a notice store now exists, so the row is
  `REASON_WIRED`. `test_ui_availability.gd` and `test_ui_shell.gd`'s
  `RENDERED_UNAVAILABLE` were updated to match. `REASON_NO_NOTICE_STORE` is left
  declared and unused rather than removed, because deleting it would renumber
  every reason after it.
- **The alert zone is now retained state, not a label.** `set_alert_display("")`
  HIDES the card without resolving anything, which is what `hud.gd`'s four-second
  hold expiry means. Two equal-severity conditions no longer overwrite each
  other: §7 orders by severity descending then earliest tick, so the earlier one
  keeps the card and the later one is retained beside it.
  `test_ui_manager.gd::test_depletion_and_diagnostics_reach_the_alert_zone` was
  updated for that and now asserts byte-for-byte retention of both sentences.
- **The history trigger is a child of the shell, not of the alert stack.** §4
  gives UI-SET-102 `ALWAYS, even when no alerts`, and a child of a hidden panel
  cannot be shown. This is what makes the empty state show only History.

## Open — raised, not decided

1. **`Error` is not one of §7's four severities.** §7's table lists INFO,
   ADVISORY, WARNING and CRITICAL; the ruling names `Error` in terms. It is
   implemented with rank above WARNING and below CRITICAL, reasoning that §7 puts
   integrity failure in CRITICAL and UI-SET-085 sends critical integrity faults to
   a stop modal instead of this card. That rank decides card order and nothing
   else. The §7 owner owns the reconciliation.
2. **The top-centre column does not fit at NARROW.** With Lh 480, the pause line,
   UI-SET-085 at a five-line refusal and UI-SET-012's 280 px minimum cannot all
   be stacked below the alerts zone. §3's one-expansion-per-zone is applied: the
   error panel stands down while the expanded view is open and returns when it
   closes. Nothing is lost — the refusal is a retained Error notice and the
   expanded view shows the same code, reason and recovery — and the condition is
   never resolved by it. §1.2 fixes no precedence between two open top-centre
   surfaces; this is the narrowest reading that keeps the thing the player just
   asked for readable.
3. **A 500-entry store of live conditions refuses a 501st.** §7 states two
   eviction tiers, both of which need a RESOLVED row. Neither selects anything
   when every row is unresolved, and inventing a third tier would silently drop a
   live condition. `push()` refuses with
   `UI_NOTICE_HISTORY_FULL_NO_EVICTION_RULE` instead.
4. **Severity glyphs are shared.** `godot/ui/**` is asset-owned and no new glyph
   was drawn: ADVISORY and WARNING share the warning mark, ERROR and CRITICAL
   share the cancel mark. The severity WORD and the §2.1 colour token separate
   them, which satisfies §7's "severity word+icon". Five distinct glyphs is an
   asset request.
5. **Resource counter cells still clip.** `12_alert_summary_narrow…` shows
   `Food 5.` for 5.48, and `09_alert_summary_standard…` shows `Wood 18` for 180 U
   and `Resident` for Residents. `_new_button()` sets `clip_text = true` and §1.3's
   narrow cell is 104 px. This ruling's exception explicitly does NOT cover it, so
   it is recorded here as a separate UXV-032 defect and left unfixed.

## Source

- `docs/rulings/2026-09-11_initial_ids_and_narrow_alerts.md` §R-UI-ALERT-001.
- `docs/ui_ux_controls.md` §1.2 (alert geometry), §1.3, §7 (severity table,
  ordering, grouping, history cap), §4 rows UI-SET-010/011/012/085/102, §2.2
  (focus return, disabled wording), §3 (one expansion per zone), §5 (pause is
  Space **with world focus**, which is why a focused HUD card may consume it).
- Measured against the real `woodland_theme.tres` font at the real 16 px NOTICE
  size; native captures 07–14 in
  `docs/validation/evidence/ui-refinement/screenshots/`.
