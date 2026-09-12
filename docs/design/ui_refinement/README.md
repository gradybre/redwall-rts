# UI refinement package — Claude starts here

2026-09-11 · SET-UX-VIS-002 · **Design package complete; runtime implementation and
user visual approval are separate, pending work.** No gameplay code is changed
by this package. Source audit: main7c600bd; UI worktree `feat/ui-shell` at95ee560.
Recheck current branch/diffs before assigning files. Preserve parallel work.

## Current production lock — read before generation

[ART-LOCK-001](asset_generation_lock.md) answers all seven asset questions:16 rows,
12 illustration pigments, lighting, silhouettes, contour variants, medallions and
DEC-036 direct-reference permission. Use IMG-25 directly; do not request substitute
references. Paid generation is not approved by this design lock.

## Visual quality correction

Brendan clarified that visual appeal is a primary goal. Read the new
[art-finish specification](visual_art_direction.md) and
[illustrated concept](visuals/05_woodland_art_concept.png) first for the intended
craft and character. The earlier four images remain structural references, **not
the final visual-quality ceiling**. The generated concept is a candidate, with
explicit deviations; owning layout, data and input rules still govern.

## Read order and deliverable

1. Root AGENTS.md and current task status.
2. [UI visual refinement amendment](../../ui_visual_refinement_amendment.md),
   read alongside [UI/controls](../../ui_ux_controls.md). It explicitly changes
   heading font, surface variants, focus color on paper, detail/toolbar sizing,
   workspace variants and availability presentation. Unchanged contracts still apply.
3. The four reference images below, [asset provenance](ASSETS.md),
   [acceptance matrix](acceptance.md) and [task04.5](../../tasks/04_5_ui_visual_refinement.md).
4. Read the [RTS comparison and review checks](rts_ui_research.md). Its eleven
   checks strengthen existing acceptance; future proposals do not override the
   amendment. Source evidence and image links are in [the register](rts_ui_sources.json).
5. Retrieve only the relevant sources from the existing art/content library;
   use the current all-twelve-book package, not an older Brocktree-only summary.

Implement a finished HUD/resident-detail slice first, then propagate the reviewed
components into roster, New Settlement and zone/refusal surfaces. Repair gate,
workspace ownership, focus, data-formatting and responsive defects as part of
this work. A generic green/paper theme with debug labels is not completion.

## Earlier structural visual targets

These are **original synthetic design references**, not screenshots of Godot or
proof of a populated colony. Contour/map backdrops are diagrammatic. Values and
availability are illustrative; the current real world must never inherit them.
Fonts, material contrast and composition guide implementation; real state wins.
The New Settlement target has a known illustrative defect: the Create button
shows a selected check. Implement Create as an ordinary momentary action under
the existing theme, without toggle/check semantics; see research check RUI-C05.

- [Wide HUD + resident journal](visuals/01_hud_resident_wide.png): compact outer
  controls, open center, warm journal with legible needs and clear actions.
- [Narrow,150%, drawer explicitly opened](visuals/02_hud_resident_narrow.png):
  meaningful reflow, readable text, scroll body, visible footer, two command rows.
- [New Settlement](visuals/03_new_settlement.png): complete grouped form and a
  restrained original illustration area, omitted on small layouts.
- [Component state direction](visuals/04_component_states.png): both surfaces,
  focus/selection, refusal, needs and icon language. The engine specimen must
  additionally include disabled-selected; the static board is not exhaustive QA.

The rendered mouse mark is a generic species sketch, not an individual portrait.
Claude must finish the scoped four-emblem set and optical-size checks. Selection
and disabled cues in actual controls must satisfy the full text contract even
where a composition image is schematic. No paid assets are authorized.

## Mechanical files and reproducibility

[requirements.csv](requirements.csv):42 mandatory IDs mapped to source owners and
23 acceptance cases. [contract.json](contract.json): exact tokens, contrast pairs,
profile fixtures and expected image dimensions.

`python3 docs/validation/ui_refinement_contract.py` checks this package's links,
ID coverage, declared palette agreement, computed contrast, responsive arithmetic,
reference dimensions and font hashes. It does not test running UI.

`render_targets.py` reproduces the PNGs with Pillow and the vendored reference
fonts beside it. It uses native drawing primitives and exact font files. It
contains no network call, runtime injection or screenshot editing. Its checks
include explicit text fits; image output was then visually inspected. Use a
Python environment containing Pillow. The available Mac bundled runtime is
recorded in [validation results](validation.json).

## Claude dispatch prompt

> Implement docs/tasks/04_5_ui_visual_refinement.md using this package and the
> owning SET-UX-VIS-002 amendment. Preserve all parallel changes and use the
> existing six-agent hierarchy with bounded file ownership. Repair the identified
> UI defects, build the prescribed FOREST/JOURNAL system, and match the first
> HUD/resident-detail visual target before extending other screens. Do not stop
> at a theme file, a generic scaffold or a headless pass. Launch the actual main
> scene for the required screenshot/input checks, keep synthetic specimen evidence
> separate, and report each requirement's actual status. Record Brendan's visual
> verdict separately; continue independent work while awaiting feedback. Do not
> spend paid asset credits or silently change gameplay/authoritative contracts.
