# 0200 — The pause label is centred, in the alert slot
Date: 2026-09-29 · Status: Accepted (Brendan's direction)

## Decision

Brendan, pointing at "Paused: PLAYER" hanging off-centre over a building: "can you center and
move the pause button to an appropriate spot on the screen layout".

UI-SET-086's row gives only "TC, below time/alerts". The shell had read that as the alert
column's **left edge**, one alert zone's full height down, whether or not an alert card was
showing. With no alert, the label therefore floated a card's height below an empty zone, pinned
to the left of the centre column.

`_place_pause_label()` now places it as follows:

- **Horizontally:** centred on the alert column, which is §1.2's centred top zone, so the
  label sits on the screen's centre line. Its text is centred in its box.
- **Vertically:** in the alert card's own slot at the top centre when no card is showing, and
  directly under the card (8 px gap) when one is showing.
- **When it moves:** whenever `_show_alert_card()` changes the stack, as well as on every
  layout.

The error panel and history keep their old anchors, so nothing else moves.

## Evidence

`test_ui_shell.gd`: 1687 assertions, 0 failed. The new tests check:

- with no card, the label is centred at x 640 of 1280, at the alert slot's top, with its text
  centred;
- with a card, it is 8 px under the card and still centred, and it returns to the slot when the
  card hides.

Mutants, 5 of 5 killed:

- not centred;
- always below the zone;
- never below the card;
- not re-placed when the alert changes;
- text not centred.

`test_ui_layout`, `test_ui_registry`, `test_ui_focus_order`, `test_hud` and `test_ui_manager`
pass unchanged.
