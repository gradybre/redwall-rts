# UI design reference asset provenance

2026-09-11 · Assets in this directory support the design handoff. They are not
runtime overlays or proof of a rendered colony. The active UI worker owns adding
reviewed runtime assets to `godot/ui/` and its manifest.

## Fonts

Noto Sans Regular/Semibold are copied unchanged from the existing `feat/ui-shell`
vendor directory; that branch records the official Noto distribution as source.
Noto Serif Semibold was downloaded from the
[official distribution](https://github.com/notofonts/notofonts.github.io/tree/main/fonts/NotoSerif/hinted/ttf)
on2026-09-11. Font bytes are unmodified. [The Noto license](https://github.com/notofonts/noto-fonts/blob/main/LICENSE)
was downloaded alongside it. Reference-only duplication makes image regeneration
independent of another agent's worktree. Runtime must still retain all four Sans
weights required by UI §2, not just the two this renderer uses.

[assets_manifest.json](assets_manifest.json) records exact source URLs and SHA-256
for all three font files. License copies are in `visuals/fonts/` alongside them.
This package does not assert a new font license or require an online font service.

## Original visual material

`render_targets.py` draws all panels, contours, glyphs, generic mouse mark,
botanical rules and hall/hearth line study from original geometric instructions.
The four PNGs are rendered from that source using Pillow with the named fonts.
No user screenshot, book illustration or slide is cropped, traced or edited into
them; the contour and map backdrops are schematic design scenery.

Synthetic examples use name Warden Rowan, needs75%, food5.48 days and other
illustrative values. They do not certify a legal starter inventory, world,
calendar, species identity, available scenario, rate or actual job assignment.
The species mark is a generic sketch, not an approved individual portrait. The
form illustration is original game design, not a canonical building plan.

## Creative reference trail

[IMG-04 and IMG-25](../../art-reference/reference_manifest.json) were viewed
this turn; IMG-03 was viewed in the preceding brief. The material-language basis
is [the shared synthesis](../../redwall-content-library/shared/theme_and_material_direction.md),
covering the twelve available novels and distinguishing interpretation from source.
A bounded kitchen-object query was also executed; no retrieved recipe or object
record was activated as gameplay. No paid generation service was used.

## Later art-direction concept

`visuals/05_woodland_art_concept.png` is a separate AI-generated candidate made
with the built-in image tool on2026-09-11. The original four programmatic images
remain unchanged. [Its manifest](woodland_art_manifest.json) records actual
dimensions, source hash, reference roles and [the complete prompt](woodland_art_prompt.txt).
The concept is not a runtime atlas or a source of sampled UI constants.

## Current reference-use authorization

DEC-036 authorizes direct use of Brendan-supplied images/material, including
IMG-25, for image-to-image and builds. The original `woodland_art_prompt.txt` is
kept verbatim as historical execution evidence, not the policy for future prompts.
Its restrictive reference wording is superseded by [ART-LOCK-001](asset_generation_lock.md).
Purpose-made sheets may be cut locally; preserve originals and crop manifests.
