# `godot/ui/` asset provenance

Every file under `godot/ui/` with its source, author, licence, alterations and where it is
used. Added for task 04.4's first-playable UI shell under
`docs/planning/ui_visual_direction.md`. **No paid generation was used or authorised.**

## Fonts — `godot/ui/fonts/`

SET-UX-001 §2.1 fixes the runtime paths: "`res://ui/fonts/NotoSans-Regular.ttf`,
`NotoSans-Medium.ttf`, `NotoSans-SemiBold.ttf`, `NotoSans-Bold.ttf`" and rules "No OS font
substitution in qualification builds."

| File | Source | Author | Licence | Alterations |
| --- | --- | --- | --- | --- |
| `NotoSans-Regular.ttf` | `notofonts/notofonts.github.io` → `fonts/NotoSans/hinted/ttf/` | The Noto Project Authors | SIL Open Font License 1.1 (`OFL.txt`) | None. Byte-identical to the upstream file. |
| `NotoSans-Medium.ttf` | same | same | same | None |
| `NotoSans-SemiBold.ttf` | same | same | same | None |
| `NotoSans-Bold.ttf` | same | same | same | None |
| `OFL.txt` | `google/fonts` → `ofl/notosans/OFL.txt` | The Noto Project Authors | SIL OFL 1.1 | None |

**These are four genuinely different weights, not one file renamed four times.** Each file's own
OpenType `name` table was read before vendoring: `NotoSans-SemiBold.ttf` reports family
"Noto Sans", subfamily "SemiBold" and licence "SIL Open Font License, Version 1.1"
(`https://scripts.sil.org/OFL`). `test_ui_theme_resource.gd` re-checks the four style names at
runtime, so a future substitution fails the suite rather than passing unnoticed.

SHA-256 as vendored, retrieved 2026-09-11:

```
1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913  NotoSans-Bold.ttf
635d93d1131d791f2576de90b3bb0f7cdf61929906e8420a61b5f7f8e76420bb  NotoSans-Medium.ttf
478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823  NotoSans-Regular.ttf
a4e91fd530ac2b4ef5367240144ff37d7d65d66cf76f2e9a2187b93c676f92d0  NotoSans-SemiBold.ttf
```

Usage: `woodland_theme.tres` alone. Body 16/400, secondary 14/400, panel title 20/600, page
title 28/700, counters 18/600 with the `tnum` tabular-figure feature.

## Theme — `godot/ui/theme/`

| File | Origin | Notes |
| --- | --- | --- |
| `woodland_theme.tres` | Generated, this repository | A **build product** of `scripts/ui/ui_theme.gd`'s §2.1 tokens. Do not hand-edit; regenerate. |
| `build_woodland_theme.gd` | Original, this repository | The generator. `godot --headless --path godot --script ui/theme/build_woodland_theme.gd` |

The theme is applied once at the UI root (`ui_shell.gd`), and every control selects a theme type
variation named after its §2.2 profile. No control carries its own palette.

## Icons — `godot/ui/icons/`

**Original work for this repository**, authored as hand-written SVG paths. No icon pack, no
traced reference image, no generated art. Grid 24x24, nominal 2 px strokes, stroke colour
`#F5F0DF` (TEXT) tinted per state by the theme's `icon_*_color` entries. Licence: same as the
repository.

| File | Subject | Used by |
| --- | --- | --- |
| `provisions.svg` | A provision bowl | UI-SET-002 food counter, UI-SET-030 food orders |
| `fuel.svg` | A hearth flame | UI-SET-003 fuel counter |
| `wood.svg` | Stacked logs seen end-on | UI-SET-004 wood counter |
| `stone.svg` | A cut block | UI-SET-005 stone counter |
| `residents.svg` | Two figures | UI-SET-006 population counter, UI-SET-031 roster |
| `beds.svg` | A bed with a bolster | UI-SET-007 bed counter |
| `ledger.svg` | A ruled page | UI-SET-008/009 ledger, UI-SET-102 history |
| `calendar.svg` | A ruled calendar leaf | UI-SET-101 date trigger |
| `pause.svg` | Two bars | UI-SET-014 pause |
| `map.svg` | A folded map | UI-SET-022 minimap layers |
| `brush.svg` | A marking brush | UI-SET-028 zone command, UI-SET-059/062 brush |
| `build.svg` | A builder's square | UI-SET-027 build, UI-SET-029 jobs |
| `cancel.svg` | A struck circle | UI-SET-067 cancel, UI-SET-093 close |
| `menu.svg` | Three rules | UI-SET-019 game menu |
| `lock.svg` | A closed lock | §2.2's "disabled PANEL/MUTED+lock icon", on every unavailable control |
| `warning.svg` | A warning triangle | UI-SET-085's refusal display, so a failure carries an icon and words, never colour alone |

## Ornament — `godot/ui/ornaments/`

| File | Subject | Used by |
| --- | --- | --- |
| `sprig.svg` | A restrained leaf sprig rule, GOLD `#E6C77A`, 48x16 | The detail panel and workspace frame title margins |

**Original work for this repository.** Drawn sparsely and at 55% alpha so that selection and
keyboard focus stay the most prominent gold on screen. Every ornament instance ignores the
mouse, cannot take keyboard focus and carries an empty accessible name, so it is outside both
the hit-test table and the screen-reader tree.

## Reference material

`ImageReference/` and `docs/art-reference/` informed the tone only. **No reference screenshot was
cropped, traced or shipped as an asset**, and none is a production UI asset or a gameplay rule.
