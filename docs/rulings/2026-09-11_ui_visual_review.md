# UI visual review — refine before expanding the shell

2026-09-11 · User asked whether to wait for later polish or plan refinement.
This records a screenshot review and recommendation, not implemented changes.

## Evidence and current plan

Inspected the saved resident-detail screenshot at
`.claude/worktrees/agent-ac7b19dffc047459e/docs/validation/evidence/ui-first-playable/screenshots/02_resident_detail_1920x1080.png`
in the Claude `feat/ui-shell` worktree, listed at commit `95ee560` during review.
This is one captured state, not a live input test or every UI surface.

[Task 10](../tasks/10_presentation_qualification.md) owns presentation completeness
and qualification, explicitly requiring presentation to grow with tasks 04–08.
[The visual brief](../planning/ui_visual_direction.md) requires visual review in
04.4, but permits a flat theme as a finished treatment. Theme compliance alone
has not established the high-quality visual result Brendan requested.

The screenshot shows the intended green/cream/gold palette and coherent icons.
It also shows a large central unavailable-content block, repetitive outlined
rows, weak differentiation between identity/status/actions, raw values such as
“Hunger 7500 of 10000,” and implementation-owner language on a player surface.
These are actionable UI issues independent of unfinished terrain/resident art.
Need values should use the UI registry's player-facing units/formatting; development
status belongs in the evidence report, with concise truthful availability in UI.

## Recommendation for the next bounded pass

Do not wait until task 10. Schedule visual refinement after the active UI
integration fixes, while independent simulation work continues. First produce a
convincing paused HUD and selected-resident detail as the visual target; use
current state and the approved UI geometry/profiles. Refine hierarchy, content
density, icon legibility, spacing and warm material/illustration details without
obscuring the world. Remove oversized empty scaffolding and apply the owning
registry's visibility/disclosure rules rather than presenting every unbuilt panel.

Compare the current screenshot with one or two proposed compositions before
propagating styling across every panel. Then implement the selected treatment,
capture the real game at standard and narrow sizes, and record Brendan's visual
feedback separately from functional test results. If the desired visual treatment
requires a change to owning typography/geometry/profile rules, propose that change
explicitly rather than silently overriding them.

This recommendation does not reopen command logic, add all 103 UI elements,
authorize paid assets, or certify the current shell visually complete. A dedicated
refinement task and chosen visual target are still to be authored; task 10 remains
the later full-game consistency and qualification pass.
