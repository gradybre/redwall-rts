# 1047 — The people card does not have the pause card's sizing bug

Date: 2026-10-02 · Status: Accepted (checked; no code change)

## The question

The pause card's sizing bug is described in decision 0931. That card is placed
with `FarmUi.place`, and nothing placed it again when its minimum height changed.
A wrapping Label measured at 1 px before its first layout set the card tall,
and the card stayed that tall. `godot/demo/people/people_card.gd`, the
spotlight and reflection card, also places itself with `FarmUi.place` and has
no `minimum_size_changed` refit. The brief asked whether it shows the same bug
when windowed.

## Finding: it does not

Two things keep it right, both already in the code:

1. **Its wrapping labels are given their width before the card is first shown.**
   `_ready` runs `_place`, which sets `custom_minimum_size.x` on the body and
   each reflection line to the card's inner width. The words are never measured
   at 1 px, which was the cause in 0931.
2. **Every change of content places it again after the change.** `_draw` ends
   with `_place.call_deferred()`. So the card is placed again after the mode,
   the words or the visible rows change, once the labels are measured at their
   real width.

The 0931 pattern, a refit on `minimum_size_changed`, would therefore change
nothing here. It is not added.

## Evidence (windowed, not headless; 0931's bug showed only windowed)

- `test/live/demo_people_live.gd` windowed at 1920x1080 and 1280x720:
  `LIVE-SUMMARY 36 0`. A new check, "as tall as its words (decision 1047)",
  requires the card's height to be no more than its combined minimum:
  158 px for 158 px at both sizes. The `spotlight` frames were looked at: one
  three-line offer and one row of buttons, with no empty panel.
- A scratch probe, windowed at 1920x1080, ran a spotlight, then the season's
  reflection (three moments), then Later back to a spotlight, then the next
  offer. It then resized the window to 1280x720, 1920x1080, 1366x768 and
  2560x1440. The card's height equalled its minimum every time: 158, 272, 158,
  181, then 181 at each size.

The new check stays in the harness, but **it guards only a windowed run**. CI
runs the harness headless (`test_demo_people_live.gd`), and as decision 0931
found, a headless run lays the words out before the card is placed, so the
check cannot fail there (review M2). It catches a regression only when someone
runs the harness windowed, as here. A CI guard would need a windowed run under a
virtual display. That is not set up in this repository's CI and is not added
here.
