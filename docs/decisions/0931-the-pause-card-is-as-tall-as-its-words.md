# 0931 — The pause card is as tall as its words
Date: 2026-10-01 · Status: Accepted

Numbered 0931 as assigned by the pause-card bug brief; no other record on this branch uses it.

## The bug

In windowed runs the demo's pause card (`godot/demo/ui/demo_pause_card.gd`, decision 0471) drew about 435 px tall at
1080p: one row of words ("Paused — You paused") and Resume in a large, nearly empty green panel. It appeared when the
card was pushed below the guide's card, and it stayed after the guide's card hid. It covered the top centre and part
of the village news, and swallowed clicks there. On master, the people harness (`test/live/demo_people_live.gd`) failed
3 Spotlight checks windowed because of it: the Spotlight ★ button sat under the card. Headless runs, which the suite
uses, never showed it.

## The cause (traced frame by frame, windowed)

1. **The words are measured at the wrong width.** The card's words are a wrapping Label (`AUTOWRAP_WORD_SMART`) in an
   HBox in a PanelContainer. A wrapping Label measures its height at the width it currently has. While the card is
   hidden, the Label has never been laid out, so it is 1 px wide. When the card is first shown, the words are shaped at
   1 px, one character to a line. "Paused — You paused" is 19 characters, so the Label is 19 × 22 = 418 px tall and the
   panel 434 px.
2. **The tall size is set and then kept.** `_place` ran while the minimum was still tall. Its `FarmUi.place` and
   `reset_size()` set the panel to that height. A probe confirms that when a Control is given a size while its minimum
   is tall, it keeps that size after the minimum falls again. Both `set_size` and `reset_size` behave this way.
3. **Nothing places it again.** The container then lays the Label out at 258 px, and its minimum falls back to one line.
   But `_place` only ran when the words, the layer or the visibility changed, so the panel stayed at 434 px.

A headless run never shapes the words at 1 px there, so its minimum is already one line when `_place` runs. The same
debug script printed 434 px windowed and 45 px headless.

No harness hid the card to work around the bug. A search of `godot/test/live/` and `tools/` on master found no
pause-card hiding, so there was none to remove.

## The fix

- **The panel is placed again whenever its minimum changes.** `_frame.minimum_size_changed` is connected to
  `_queue_place`. The viewport's `size_changed` now goes there too. `_queue_place` merges all requests into one
  deferred `_place` per frame. When the words are measured again at their real width, the panel is given its size
  again, now the right one.
- **It is placed again when what it sits against moves.** Before, after the guide's card hid, the card stayed where it
  had stepped below that card. Now, while the card is shown, `_process` checks each frame whether the rect it avoids or
  the HUD's alert cards differ from what it was placed against (`_moved`), and places it again on any change.
  `_moved` calls two Callables and allocates nothing. Review finding: `demo_village.gd _hud_cards_shown` used to look
  up the shell and the alert stack by node path on every call, which would now happen every frame. It finds the stack
  once and caches it instead (`_alert_stack`).
- **It also steps below the people's offer card.** `demo_village.gd _top_card_rect` gave the incident card, else the
  guide's card. It now gives the people's offer card (`people_card.gd`) after those. This follows the order already
  written in that file ("the incident card, then this guide card, then the people's offer card"). Without it, the
  correctly sized card covered the first line of the spotlight.

The panel is still the only part of the card that takes the mouse (`MOUSE_FILTER_STOP`). Its words ignore the mouse.
Now that the panel is the size of its words, a click outside it passes through.

## Checks added

- **`test/live/demo_session_live.gd`**, paused, with the guide's card shown, then hidden, then shown again. Each time,
  the pause card must:
  - be shown;
  - be no taller than its minimum;
  - be at most two rows of words (or the Resume button's height, if that is taller) plus its margins;
  - be clear of the top card.

  Then the mouse is moved to a point below where the card's top plus that limit would end. Because the point is
  measured from the card's top, a tall card cannot move it away. The card must not hover there. Finally, the words are
  made 400 px tall and the card is placed while they are tall, as the windowed run did. The words then return to one
  row, and the card must shrink back to them. This last step reproduces the bug **headless**: with the refit removed,
  the suite's own run fails at 412 px. `MIN_CHECKS` goes from 44 to 64. The harness also runs windowed with
  `--capture`.
- **`test/live/demo_people_live.gd`**: the pause card shows (paused), and the spotlight card is clear of it.
- **`test/test_demo_pause_ledger.gd`**:
  - a change in the panel's minimum queues one placing;
  - `_moved` notices the top card shown, resized or gone, and the HUD's cards shown.

## Mutation testing

Mutants were run against the pause-ledger suite and the session and people harnesses, at 1920x1080 windowed. The last
row is also run headless (the session harness, 1280x720).

| Mutant | Outcome |
|---|---|
| No `minimum_size_changed` → `_queue_place` (the original behaviour) | killed: the unit test; windowed, 434 px against 45; headless, 412 px against 45 |
| No per-frame `_moved()` in `_process` | killed: the people harness (the card under the spotlight) |
| `_moved` ignores the HUD's cards | killed: the unit test |
| The people card left out of `_top_card_rect` | killed: the people harness |
| No coalescing guard in `_queue_place` | survived: it only places the card more than once in a frame, with the same result |
| No `_frame.reset_size()` | survived: equivalent, because `FarmUi.place` already sets the size to `(width, 0)`, clamped to the minimum |

A first version also set the Label's width before measuring it. That mutant survived, and the code review found the
line probably had no effect, because `set_size` clamps to the Label's cached minimum. It was removed.

## Rules used, and what is left

UI-SET-086 (the pause line in the alert zone, top centre) and decision 0471 (the card's place and its one Resume).
No adopted rule is changed, and nothing here is a PROPOSAL.

Seen but not changed here:

- **The Map layer picker at 1280x720.** When stepped below the guide's card, the pause card overlaps the top 15 px or so
  of the picker. The picker is still clickable below that. The guide's card avoids the picker; the pause card has no
  lower bound.
- **The people card may have the same bug.** `people_card.gd` sizes its panel the same way (`FarmUi.place` with no
  refit) and may have the same grow-and-keep problem. It was not seen in these runs.
