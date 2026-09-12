# Claude handoff — reference permissions, UI refinement and approved world art

2026-09-11 · Consolidated execution handoff through DEC-038.

Work in `/Users/brendan/Developer/redwall-rts`. Reconcile this handoff with the
current implementation and preserve all active/uncommitted work. Old branch names,
commit hashes and worktree locations in planning documents are historical snapshots;
inspect current status before assigning or editing files.

## 1. Correct the reference restrictions

Brendan explicitly authorizes the images and material he supplied to guide direct
builds in this world. DEC-036 corrects the earlier assistant-created restriction
that IMG-25 was observe-and-describe-only or unavailable for direct production
reference use. Supplied references may be used directly for image-to-image,
image-to-3D, drawing/tracing/adaptation, modeling and texturing. Do not demand new
replacement references or infer a use prohibition from unknown creator metadata.
Preserve provenance accurately without inventing ownership, authorship or licenses.

Open the actual reference images. Written descriptions supplement them. IMG-25
provides comparative animal outlines/anatomy; combine it with the individual
mouse, mole, hare, toad, otter and other relevant character images, plus clothing,
pose, object and environment references. It is not the only species template.

This correction concerns supplied-reference use. Source slide mechanics still do
not override the GDD. Paid generation still requires itemized approval. Do not
turn either qualification into a renewed restriction on reference preparation.

## 2. Apply the whole-game visual direction

DEC-037 defines the synthesis:

- Literature/content library: theme, feel, atmosphere, community, material culture.
- Supplied images: complementary concept, anatomy, costume, pose and material inputs.
- RTS comparisons: visual composition, readable silhouettes, materials, animation,
  environmental richness and presentation at actual gameplay distances.
- Production: one coherent modern woodland RTS style across residents/units,
  buildings, terrain, vegetation, water, underground spaces, props/items, equipment,
  animation, effects and UI.

Company of Heroes 1–3, Age of Empires, Northgard and Total War are reference families
to study for particular strengths. Learn transferable principles rather than
mixing whole franchise styles. Older titles do not impose an outdated graphical
quality ceiling. Existing RTS UI research is completed comparative work for UI;
the broader world-art comparison is still proposed research, not already verified.

DEC-038 is a confirmed visual decision. Brendan viewed
`docs/art-reference/visuals/grounded_expressive_rts_example_v1.png` and answered:
**“Yes - this is what I'm looking for”.** Open that image before briefing assets.

The approved direction is grounded, expressive 3D: distinct adult animal anatomy,
character conveyed through ears/muzzle/posture, composed woodland color, convincing
cloth/leather/iron/timber/stone, and warm inhabited environments. Preserve the
contrast between the mouse and mole; do not round every species into one plush
body type. Use the close view for character/material intent and elevated view for
RTS scene composition. Simplify fine fur and texture noise for runtime while
preserving the look. Do not reopen the broad world-style choice as unanswered.

This is approval of visual direction. The generated example is not an existing
mesh or Godot screenshot, a calibrated camera test, an exact species-size ratio,
or production/performance qualification. Incidental generated content is not a
new gameplay requirement. UI is absent from the approved image, so it does not
approve unseen UI artwork.

## 3. Keep the UI and world coherent with appropriate treatments

The world follows the approved dimensional example. UI illustration follows the
storybook watercolor/controlled-ink direction in SET-UX-VIS-002 and ART-LOCK-001.
Its twelve illustration pigments, contour rules and fixed light angle apply to
that UI family; do not impose them as a global 3D palette or shader.

Visual appeal is a requirement. Flat Godot controls, generic green rectangles,
repetitive outlines and generic line icons are an intermediate stage. The four
early programmatic UI boards are structure references, not the finished quality
ceiling. The later UI concept
`docs/design/ui_refinement/visuals/05_woodland_art_concept.png` illustrates craft
and finish but remains a candidate with documented layout/data deviations.
It has not gained user approval through approval of the separate world-art image.

Build crafted FOREST chrome, a bound-paper JOURNAL, distinct component silhouettes,
coherent painted object icons, species medallions, restrained oak/acorn ornament,
and the prescribed typography, hierarchy and state feedback. Preserve opaque,
legible text areas and appropriate small functional SVGs. A beautiful backdrop
cannot compensate for unfinished UI: review it over neutral and real backgrounds.

Follow the amendment's geometry and FOREST/JOURNAL role mapping rather than
measuring the generated concept. Keep required labels, needs/rates/XP, unavailable
states, focus, input ownership and responsive behavior. Never bake generated text,
a fake minimap, or a full screenshot overlay into the interface.

## 4. The seven asset questions now have written answers

Read `docs/design/ui_refinement/asset_generation_lock.md`, with its JSON/CSV companions.
It specifies all sixteen logical asset rows (fourteen unique illustrations),
twelve illustration pigments, shared lighting/shadow limits, per-icon small-size
silhouettes, surface-dependent contours and medallion framing.

Key identity corrections:

- Ready food: the specified stew bowl.
- Fuel: flame and embers; wood: a three-log stack. These must be distinguishable.
- Stone: angular stone cluster; population: mouse/mole/otter group; beds: one bed.
- Toolbar: mallet, staked zone, crossed work tools, food/people reuse, parchment goals.
- Medallions: mouse, mole, otter, squirrel; the specified clothed three-quarter
  head-and-shoulders framing with shared roundel treatment and species anatomy.

Use the exact tables for colors, angles, sizes, contours and framing. Do not
reinterpret this summary as a replacement for those numerical instructions.
These are Astra-authored production decisions; final UI asset verdicts remain
separate. Reopen only a concrete conflict or a user-requested change.

Purpose-made asset sheets may be segmented into individual exports. Keep original
inputs, outputs and crop coordinates. ART-UI-11's prohibition on screenshot-based
production panels does not forbid cutting purpose-made sheets or using the concept
and supplied pictures directly as references.

## 5. Read authoritative context before implementing

Start with AGENTS.md, CLAUDE.md, docs/STATUS.md and the current task. Apply the
AGENTS authority hierarchy; lower-level handoff prose cannot change gameplay.
Then read the relevant sections in this order:

1. `docs/setting_decisions.md`: DEC-018/019 and DEC-036–038.
2. `docs/setting_bible.md` §14.4/14.7 and the relevant thematic context.
3. `docs/art-reference/visual_direction_alignment.md` and its approved image,
   prompt and provenance manifest.
4. `docs/art-reference/README.md`, `model_reference_guide.md`, relevant entries in
   `screenshot_review.md` / `reference_manifest.json`; `traversal_design_review.md`
   for anatomy or environments involving movement.
5. `docs/redwall-content-library/README.md`, `authoring_handoff.md` and relevant
   shared context; retrieve relevant individual records with the library tool.
   Use the current expanded book library, not an obsolete Brocktree-only summary.
   Retain actual source-coverage gaps and distinguish source facts from completions.
6. `docs/ui_ux_controls.md`, `docs/ui_visual_refinement_amendment.md`, and
   `docs/design/ui_refinement/README.md`, `visual_art_direction.md`,
   `asset_generation_lock.md`, `rts_ui_research.md`, `requirements.csv`,
   `acceptance.md` and `contract.json`.
7. `docs/tasks/04_5_ui_visual_refinement.md`, relevant asset-pipeline instructions,
   `docs/crowd_rendering_architecture.md` asset conventions, and
   `docs/design/paid_asset_process.md`.

Read owning GDD/movement/architecture contracts wherever proposed visual work touches
scale, access, physics, state or budgets. Preserve the adopted underground,
swimming/diving and climbing/canopy scope. Do not treat battle crowd limits as
measured settlement performance or silently invent new technical budgets.

## 6. Execute with the existing agent hierarchy

Use plan-parser/sonnet for bounded requirement/dependency mapping; game-coder/inherit
for implementation with Bash and permitted Blender tools; test-runner/haiku for
repeatable checks; user-qa/sonnet for visual/player review; code-reviewer/sonnet for
technical review; git-manager/haiku for authorized git/task bookkeeping. Keep hard
architecture and integration decisions with the lead. Give each worker explicit
file ownership, requirements and evidence expectations. Do not send every agent
the entire corpus or let unattended subagents spend paid credits.

First reconcile the current UI implementation with task 04.5. Complete the dependency-
ready foundation fixes, then finish one HUD/resource/time/resident-journal slice
before propagating components. Continue independent implementation and source/brief
preparation while a specific approval or data dependency is pending. Preserve
existing work and integrate deliberately; do not recreate another active worktree's
components merely because they are absent from the current checkout.

For world art, prepare a concrete look-development brief using the approved image
plus named original references: representative residents, a dwelling/workspace,
ground/vegetation and practical props. Define the actual production/validation
steps and any dependency gaps before generating families. Keep each asset's source
features, authored completion, geometry constraints and acceptance views explicit.

## 7. Paid calls, verification and durable reporting

The earlier nano-banana-pro proposal (90 floor, 30 reserve, 120 ceiling; 18 for two
probe calls in the quoted units) is not approved by these visual decisions. Verify
current tool fit, model availability, pricing/units and balance, then obtain the
required itemized approval before spending. Do not treat art approval as budget
approval. Preparation and other authorized work can proceed.

Run appropriate Mac checks and the actual scene when available. Capture native
wide/narrow/scaled UI, interaction/focus states, neutral specimens and real gameplay
views. Mark synthetic specimens distinctly. If real residents are blocked, do not
fake live state or claim a populated colony. Windows/minimum-hardware qualification
remains deferred or open under existing instructions.

The package validator checks documents, not the running UI. Headless success,
a generated concept and an agent's aesthetic opinion do not establish visual
acceptance. Report UXV-001–042, ART-UI-01–12 and applicable acceptance cases honestly.
Record Brendan's actual visual verdict separately. Keep prompts, provenance,
asset sources, decisions, task status, evidence and the exact next step in the
repository, never solely in private assistant memory. Follow existing git authority;
this handoff itself grants no new push/merge or paid-generation permission.

Begin by reporting the current implementation state, the concrete next slice,
file ownership and any specific remaining blocker, then proceed with authorized,
dependency-ready work. Do not stop after restating this handoff.

## Latest blocker handoff — 2026-09-11

Read [the asset/save/movement ruling index](../rulings/2026-09-11_asset_save_movement_blockers.md)
before dispatching the next increment. It supplies authoring and codec contracts,
corrects focus/rollback classifications, and preserves the separate open
proportion-review and full MOVE-G01 gates. It does not mark runtime work complete.
