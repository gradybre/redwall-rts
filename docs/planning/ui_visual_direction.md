# First-playable UI visual direction

2026-09-11 · Task 04.4 implementation brief. **Design guidance, not implemented
UI or a visual acceptance result.** Brendan requested a high-quality interface
that fits the game. Deliver an authored, styled first-playable shell using the
existing UI system. Functional wiring and visual craft are both acceptance work.

## Authority and scope

Read [AGENTS](../../AGENTS.md), [UI/controls](../ui_ux_controls.md) §§1–4,
[task 04.4](../tasks/04_world_commands.md), and the
[first-playable acceptance checklist](first_playable_acceptance.md).
The UI specification already defines a complete palette, vendored font paths,
geometry, and inherited state profiles. Counting repeated font/color mentions
across the registry understates that specification. Apply those profiles to
every implemented element; do not substitute the Godot default theme.

Keep the current slice: New Settlement, initially paused start, time/calendar,
camera/selection, resource summary, resident detail, zone designation, pending
preview, cancellation and refusal feedback. This brief does not bring all 103
registry entries into scope or add gameplay systems. Unsupported actions retain
the owning specification's discoverability and explicit refusal/disabled reason.

Creative owners: DEC-018/019 in [setting decisions](../setting_decisions.md),
[setting bible](../setting_bible.md) §14.7,
[theme/material direction](../redwall-content-library/shared/theme_and_material_direction.md),
and the [art-reference package](../art-reference/README.md).
The styling treatment below is original game design under those directions;
it is not a claim of canonical Redwall interface design. It changes no gameplay
constants, UI token values, profile geometry or interaction contracts.

## Visual target: a woodland keeper's ledger

The interface should feel carefully made and lived with: orderly records of a
community, surrounded by the warmth of timber, cloth, hearths and woodland life.
At a glance the player should find provisions, time, the selected inhabitant and
the next action. At closer inspection, a few crafted details provide character.

| Layer | Implementation direction |
| --- | --- |
| Functional surfaces | Opaque forest-green panels, warm cream lettering, soft corners and the exact profile borders. Preserve an open center for the settlement. |
| Hierarchy | Clear title, short status, grouped facts, then actions. Maintain the specified spacing; avoid boxed subdivisions around every line. Required row separators and control borders still apply. |
| Ornament | Original, restrained sprig/leaf linework in title margins and section ends. Keep it outside text, hit targets and focus outlines; it must not change required panel dimensions. Omit where compact geometry has no room. |
| Material character | Suggest bound cloth or a hand-kept ledger through quiet edge details and original illustration. Functional text surfaces remain solid token colors. No textured text backgrounds, massive timber frames, parchment wallpaper or ornamental scrollbars. |
| Icons | One consistent set of clean, recognizable silhouettes: provision bowl, logs, resident group, calendar, brush, cancel and lock as applicable to the existing controls. Avoid emoji or mixing unrelated icon packs. Botanical ornament must remain distinguishable from functional icons. |
| Illustration | Reserve richer original artwork for spacious menu areas and future appropriate content surfaces. Do not make portraits or painted panel art a prerequisite for this slice. A resident's actual name/species/status is sufficient when portrait art is absent. |
| Voice | Warm and specific in ordinary guidance; direct in commands and refusals; restrained around injury and loss. Keep system labels readily understandable; light dialect belongs in appropriate authored character speech. |

Use `ImageReference/` through [the manifest](../art-reference/reference_manifest.json)
and [model-reference guide](../art-reference/model_reference_guide.md). IMG-03's
communal kitchen was directly inspected for this brief: bowls, baskets, cloth,
hearth warmth and practical domestic activity inform the tone. Its slide layout,
recipe claims and pictured artwork are not production UI assets or gameplay rules.
Consult IMG-04/05 and relevant library records when authoring further material or
scene briefs; inspect originals before claiming their details. Preserve the
source/game-content distinction and book-qualified provenance.

## Concrete theme and asset work

1. Create one reusable Godot `Theme`, proposed path
   `godot/ui/theme/woodland_theme.tres`, with centralized styles for the registry
   profiles. Use theme variations/reusable components for overrides. Apply it at
   the UI root so individual screens do not accumulate independent palettes.
2. Vendor Noto Sans 400/500/600/700 at the four exact `res://ui/fonts/` paths in
   UI §2.1. Include the font license and provenance. Resolve the official source
   and verify its license when obtaining files. Do not rename a regular font to
   pretend it is semibold or silently use system fallback in qualification.
3. Reproduce the existing typography: body 16, secondary 14, panel title 20,
   page title 28, counters 18 with tabular numerals. Preserve specified weights,
   line height and large-text behavior. No new display font is required.
4. Implement flat panel/button styles first using `StyleBoxFlat`; a carefully
   authored flat theme is a valid finished treatment. Nine-slice panel art is
   optional, justified only by a concrete visual benefit. If introduced later,
   preserve content margins and test small/large sizes for stretched corners.
5. Author original SVG functional icons under proposed `godot/ui/icons/` and
   ornament under `godot/ui/ornaments/`. Starting art grid: **24×24, nominal 2 px
   strokes**; this is a new presentation recommendation, not an adopted control
   size. Fit actual glyphs to registry controls; hit targets retain their stated
   dimensions. Review small-scale silhouettes and high-DPI imports in engine.
6. Record source, author, license, alterations and intended usage in proposed
   `godot/ui/ASSETS.md`. No paid generation is needed or authorized by this brief.
   Reference screenshots stay references rather than being cropped into assets.

Reuse all twelve UI §2.1 tokens unchanged. In particular, PANEL `#1E3028`,
TEXT `#F5F0DF`, MUTED `#BECABF`, GOLD `#E6C77A`, and INK `#14211B` establish the
look. Selection uses GOLD/INK where specified. Decorative gold should be sparse
so selection and focus stay prominent. Disabled text retains full prescribed
contrast; warnings and failures always carry an icon and words as well as color.

## Design the states, not just the resting screen

| Surface | Required presentation |
| --- | --- |
| New Settlement, UI-SET-103 | Calm form with a clear title and real field values. Inline validation, stable action footer, focus order and readable progress/error state. Follow existing fields and initialization rules; no invented scenario options or implied successful bootstrap. |
| Resources and time, 001–019 | Compact, stable numerical alignment and clear units. Keep required data and accessible names. Pause is unmistakable and states its actual reason; resume and requested speed reflect scheduler truth. |
| Selection/detail, 036–040 and applicable rows | Lead with actual identity and current condition. Group only supported facts. Need labels/numbers remain above their tracks. Preserve supported tab semantics; no invented histories, family ties or portrait-based gameplay cues. |
| Zone tool, 028/059 | A clear active tool state and explicit affected area. Pending, committed and refused states use the owning overlay/command contracts. Color alone never distinguishes invalid/conservation/pending states. |
| Cancel and refusal, 067 plus owning command profiles | Keep the available escape/cancel action visible. Describe what failed and, when known, the real recovery action. Preserve the technical result code in evidence/logs without exposing implementation internals as the main player message. |
| Empty or unavailable data | Distinguish a true zero, no current selection, uninitialized data and an unsupported feature. Do not display zero food-days when the value is undefined. Failed or partial initialization does not trigger a fabricated collapse or a successful settlement-start claim. |

Presentation reads committed snapshots; economic changes use the economic command
queue and speed/pause changes use the separate scheduler contract. Camera,
selection, focus and tool previews remain presentation/input behavior and must
not be incorrectly routed as economic orders. No direct authoritative store
writes from a widget. Keep pending intent distinct from committed outcomes.

## Work order and agent ownership

The lead owns integration, task status and contract decisions. Use the existing
configured Claude roles: plan-parser/sonnet for bounded source mapping;
game-coder/inherit for the theme, components and state wiring; test-runner/haiku
for repeatable execution/log collection; user-qa/sonnet for screenshot and
interaction assessment; code-reviewer/sonnet for independent diff review;
git-manager/haiku for reviewed owned changes under existing git authorization.
Escalate a difficult diagnosis to the lead rather than sending the whole corpus
to every worker. No overlapping writers to HUD scenes/scripts or project config.

Implement in this order:

1. Theme, fonts/icons and a component specimen using actual Godot controls:
   default/hover/pressed/disabled/selected/focused, field, meter and refusal.
   Keep any synthetic values in a clearly labeled **UI specimen** scene.
2. Apply the same components to the real task-04.4 surfaces and command bindings.
   Theme work can proceed while starter-service dependencies remain unresolved.
3. Capture the running application; review, correct and recapture the affected
   states. Continue independent work while Brendan reviews the first image set.
   Do not count an unseen image or a headless test as a visual pass.

## Launch and evidence handoff

Recommended executor workflow: launch the actual native game on the Mac and
capture screenshots. A `.claude/launch.json` file is a convenience if supported
by the executor's native launch tooling; its absence does not prevent Godot from
running. Do not invent its schema or mistake a browser preview for the native
scene. Use the installed launcher supported by the environment and document it.

The current project sets `run/main_scene="res://scenes/main.tscn"`. From the repo
root, the native game command corresponding to [ENVIRONMENT](../ENVIRONMENT.md)
is:

```sh
godot --path godot
```

Record the actual command, window dimensions and result. This planning review
has not launched the app or verified a launcher configuration. Run the repository
headless checks separately with `./tools/run_tests.sh`; retain the runner's real
summary and add meaningful input/binding/layout checks for the implemented slice.

Capture at least:

- 1920×1080 at default scale: paused HUD, selected resident when real state permits,
  active zone/pending preview, and a refusal with keyboard focus visible.
- 1280×720 at default scale, plus 1280×720 at 150% user scale: narrow drawer/tool
  behavior, scrollable content, fixed footers and no hidden focused control.
- New Settlement form, invalid input and actual initialization result.
- One high-DPI render, recording logical viewport and backing pixel size; use
  3840×2160 if the available setup supports it, otherwise mark that case deferred.
- Bright and dark real terrain where available. A labeled specimen backdrop can
  test contrast independently, but does not establish a real-world render pass.

Decorative Controls must use ignored mouse filtering, never receive keyboard
focus, and stay excluded from screen-reader semantics. Verify every interactive
focus outline remains distinct from selection and ornament.

Check world clicking/panning around panel edges, modal focus trapping, trackpad
alternatives, tooltip-on-focus, selected-plus-focus visibility, long labels,
reduced motion and paused UI responsiveness. Assess visual hierarchy, icon
recognition, reading comfort and whether the world remains the focus. Screenshot
review alone does not establish keyboard or screen-reader behavior; record those
as separate executed or deferred checks. Mac work is not Windows qualification.

Pair the visual sequence with a state trace: paused designation leaves stocks
unchanged and intent pending; resume commits once and produces one source-linked
job; cancellation and refusal follow their actual owner contracts. Do not expect
gathered output before compatible travel/work integration is present.

Store screenshots, logs, exact revision/dirty-diff identification, fixture/seed,
viewport/user-scale/DPI settings, reproduction steps and pass/fail/blocked results
under proposed `docs/validation/evidence/ui-first-playable/`. Include a short
Player Impact Report and a before/after pair for each material visual fix.

Recheck runtime integration before describing the world as empty: the earlier
main-scene cohort and generated-world initializer were distinct paths. If the
complete 12-resident starter fixture remains unavailable, capture that truthfully
and test resident components in a separately labeled specimen. Neither an empty
world nor a specimen completes FP-01 or full resident-selection acceptance.

## Completion boundary

This slice is complete only when its implemented controls use the shared theme,
show truthful state, pass applicable functional checks and have actual visual
review evidence. Report blockers by surface and contract; do not silently check
off task 04.4 when required real-state behavior remains blocked. Overall playable
colony, all 103 UI elements, completed movement, final artwork, screen-reader
qualification and minimum-hardware performance are separate milestones.

Hand Brendan a small annotated screenshot set for the first visual judgment.
Record feedback and subsequent decisions in the repository so future executors
inherit the design intent as well as the code.

Independent player-QA reviewed the owning UI/task contracts during preparation
and found no conflict with this direction, subject to the state, decorative
input/accessibility and responsive checks above. This was a document review,
not inspection of a running interface.
