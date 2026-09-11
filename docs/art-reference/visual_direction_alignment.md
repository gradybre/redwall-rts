# Whole-game visual direction alignment

2026-09-11 · SET-ART-ALIGN-001 revision 2 · DEC-037/038

## Confirmed intent

Brendan clarified the role of the reference material for every visual domain:
residents/units, buildings, terrain, vegetation, water, underground spaces,
items, equipment, animation, effects and UI.

1. Redwall literature and the content library supply theme, feel, atmosphere,
   material culture and community context. The GDD and adopted amendments still
   own gameplay; source evidence and authored completion remain distinguishable.
2. Supplied images are direct concept and construction references under DEC-036.
   IMG-25 provides comparative animal outlines/anatomy. Layer it with relevant
   individual character, costume, action, object and environment references.
   It is not the universal or exclusive species template. Use the actual source
   images, not only a model's recollection or a written caption.
3. Translate this into one coherent, modern, high-quality RTS visual language.
   Study Company of Heroes 1–3, Age of Empires, Northgard, Total War and other
   appropriate examples for transferable visual strengths. Older references
   supply useful design principles without imposing their technical limitations.
4. Apply that synthesis across the whole game. This is broader than a UI polish
   pass or an isolated set of animal portraits.

This refines DEC-018/019 and [bible §14.7](../setting_bible.md#147-adopted-art-direction--storybook-expression-and-grounded-construction).
It does not replace the adopted storybook/grounded-realism blend. DEC-038 now
anchors that blend in the approved visual example below.

## Approved visual example — DEC-038

Brendan's response to the generated example: **“Yes - this is what I'm looking for”.**
This settles the world-finish direction; do not reopen the broad style choice or
continue describing it as awaiting an initial aesthetic decision.

![Approved grounded, expressive woodland RTS direction](visuals/grounded_expressive_rts_example_v1.png)

[Generation provenance](visuals/grounded_expressive_rts_example_v1.json) ·
[Exact prompt](visuals/grounded_expressive_rts_example_v1.prompt.txt)

Carry these qualities into production briefs:

- Species-specific adult anatomy and readable expression through ears, muzzle,
  eyes, hands and posture; retain the contrast between mouse and mole silhouettes.
- Restrained moss green, oatmeal, ochre and earth tones with deliberate value
  grouping. This is a color relationship, not a new universal indexed palette.
- Clearly different material responses: matte woven cloth, worn leather, subdued
  iron highlights, believable timber and heavy stone.
- Warm inhabited spaces, purposeful props, supported construction and grounded
  contact. Keep both everyday character and material credibility.
- Close-view character/material appeal and a coherent elevated RTS composition.
  Simplify fine fur and texture noise as distance increases while preserving form,
  material distinction and the approved character of the image.

The left panel guides appearance; the right guides the intended RTS translation.
Neither is engine evidence or an exact camera/scale specification. Incidental
chickens, building dimensions and new content are not adopted through aesthetic
approval. Production still needs model sheets, rigs, actual gameplay-camera review
and applicable performance evidence. No additional generation was approved here.

## Domain boundaries for the executor

The [UI asset lock](../design/ui_refinement/asset_generation_lock.md) specifies
UI illustration assets. Its twelve pigments, ink contours, light angle,
24px silhouettes and medallion framing do not become global world-rendering
rules. Do not impose a watercolor shader, black outlines, fixed upper-left
sunlight or that twelve-color palette on all 3D models by extrapolation.
The world follows the approved dimensional example. UI illustrations retain their
separate treatment and must feel coherent with it; the example contains no UI.

Maintain species anatomy, credible construction and materials, visible everyday
life and readable actions/access at the actual RTS camera. High quality includes
shape, composition, animation, material separation and polish; increasing texture
size or polygon count alone does not establish it. Existing scale, rig, LOD and
performance contracts still apply. A required technical revision needs measured
engineering work. Art-reference selection does not authorize new gameplay.

## Required reference synthesis in each asset brief

Use the existing [model guide](model_reference_guide.md) and bible §14.4/14.7.
Each brief must identify:

- Relevant book/library record IDs and the atmosphere or material detail taken
  from them; retrieve individual records rather than loading the whole library.
- Exact supplied image IDs/regions actually opened, and the contribution of each:
  anatomy, costume, pose, material, prop, construction or atmosphere.
- Which reference leads when features disagree; retain source contradictions and
  describe authored hidden surfaces instead of claiming they were visible.
- Any RTS comparison, the specific quality to learn from it, and its translation
  to this woodland setting. Do not simply request a mixture of franchise styles.
- Gameplay-camera silhouette and action/access needs, close-view expectations,
  actual technical limits and required views for review.
- What is inherited, newly proposed, user-confirmed and still open.

For example, a mole brief combines IMG-08's working body and equipment,
IMG-25's comparative outline, relevant domestic clothing references, and actual
library context. It must then demonstrate a readable mole working in the game
world. A close-up portrait alone cannot establish that result.

## RTS comparison work to develop

The following are Astra's proposed research questions, not completed comparative
findings or user-approved allocations of style:

| Reference family | Quality to investigate for this game |
| --- | --- |
| Company of Heroes 1–3 | Material weight, inhabited environment composition, animation/contact, atmospheric light without losing units |
| Age of Empires | Building/role identity, settlement composition and readability across camera distances |
| Northgard | Shape economy, environmental color grouping and clarity within a woodland setting |
| Total War | Species/unit distinction at distance, motion and visual scale; separate future battle needs from current settlement scope |

Compare actual gameplay views as well as close-ups. Avoid selecting a promotional
render as evidence of runtime quality. Record the title/version, source and view.
The existing [RTS UI research](../design/ui_refinement/rts_ui_research.md) covers
interface lessons; it does not constitute a complete world-art comparison.

One verified primary-source camera lesson: the AoE IV team described balancing
a battlefield overview with selection and readability when adding zoom options.
Our inference is to validate reference-inspired assets at the intended game
camera before accepting beauty renders. Source: [AoE IV update 17718](https://www.ageofempires.com/news/age-of-empires-iv-update-17718/),
New Camera Zoom Options; consulted 2026-09-11.

## Remaining refinements

The world-finish choice is resolved by DEC-038. Normal-camera species/action
readability remains required; exact camera calibration, detailed species scale and
LOD execution must follow their owning contracts and real scene review. The example
does not answer those engineering questions numerically.

Specific favorite franchise entries and additional reference preferences can refine
later briefs but do not block applying this approved target. No further broad
style questionnaire is required before preparing the next brief.

## Next deliverable

Prepare a cross-domain visual brief anchored to the approved example, then a
small reference-backed look-development scene: representative residents,
a dwelling/workspace, woodland ground/vegetation, tools/items and the UI together.
Use normal gameplay and close views, with the lighting-condition checks from
bible §14.7. This is a proposed review sequence, not a claim that assets or runtime
screenshots now exist. Keep unapproved choices explicit rather than generating
large families around them. Paid generation requires the separate itemized process.
