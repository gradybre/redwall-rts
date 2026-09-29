# 0199 — The command strip is one row
Date: 2026-09-29 · Status: Accepted (Brendan's direction)

## Decision

Brendan, looking at the live demo's two-row command strip: "Can you have this layout in the UI
be all one line at the bottom of screen, adjusting with screen size".

UI-SET-026, the command strip, is now **one row**. This overrides §1.2's "width=min(640,
available); y=Lh−152; height 136 … Command buttons wrap into two or three rows".

- **Height:** one 44 px command cell plus 12 px padding top and bottom, so **68**. The strip's
  bottom stays where the 136-tall strip ended, `SAFE_INSET` (16) above the viewport's bottom
  edge, so `y = Lh − 84`.
- **Width:** as wide as the seven commands need at full size, which is 7 × 120 + 6 × 8 + 2 × 12 =
  **912**, or §1.2's interval (minimap to screen edge, or to the detail panel), whichever is
  less. It is centred in the interval, as before.
- **Cells:** the seven buttons share the interior evenly. Each is clamped to **44–120 px**, and
  the row is centred when the strip is wider. A label that no longer fits ends in an ellipsis.
  The maximum is 120, not §4's 112. "Objectives" with its lock icon measures 114 px in both the
  plain HUD and the demo skin, and was clipped to "Objective" even in the old two-row strip. 120
  is §4's own selection-command cell (UI-SET-034/035).
- **Overflow:** when even 44 px cells do not fit, a command that would cross the strip's right
  edge is hidden. It lives in the context quick menu, which is §1.2's own rule, unchanged. This
  happens only at the minimum tested logical width (1280 px at 150%, Lw 853.33) with the detail
  panel open: 309.33 px holds five commands, and Feast and Objectives go to the menu.

## What moved with it

- **Registry:** UI-SET-026's size row is now `240×68→912×68`, and UI-SET-027–033 are
  `44×44→120×44`, in `ui_ux_controls.md` §4, `ui_registry.gd` and `test_ui_registry.gd`.
- **Spec:** §1.2's worked example now reads "commands with detail x240..912, y636..704".
- **Workspace:** an ordinary workspace's bottom is "command-strip top − 8" (SET-UX-VIS-002
  §4.2), so it gains 68 px of height at every size. Every rule that derives from the strip's top
  follows it; no workspace constant changed.

## Evidence

- `test_ui_layout`: 0 failed, with the 1280×720 command span updated to [240, 912, 636, 704].
- `test_ui_registry`: 0 failed.
- `test_ui_shell`: 0 failed. Three new tests:
  - at 1920×1080: a 912 × 68 strip, its bottom at 1064, and seven 120 × 44 cells at x = 12 + 128i;
  - at 1280×720 with the detail open: every cell 600/7 px on one row, the last ending at the
    padding;
  - at Lw 853.33 with the detail open: five 44 px cells, with Feast and Objectives hidden.
