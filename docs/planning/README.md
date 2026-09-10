# Next settlement planning package

Prepared 2026-09-09 from `/Users/brendan/Developer/redwall-rts`, base revision
`4fb57b1ae3759511a1a25a1a0242b44f605d80aa`. **Planning only:** no runtime changes,
new gameplay constants, adopted movement closures or independent game-test result.
The executor continues task 03. These documents supply its next dependency queue.

## Read and dispatch

1. Read [AGENTS](../../AGENTS.md) and [CLAUDE](../../CLAUDE.md), then current
   [STATUS](../STATUS.md). Check the actual branch/diff before assigning files;
   another executor may have advanced since this package's snapshot.
2. Read [release roadmap](../tasks/00_release_roadmap.md) and
   [requirement allocation notes](requirements_notes.md). The
   [requirement matrix](requirements.csv) records ownership, not completion.
3. Continue [task 03](../tasks/03_ecology_crops_weather.md) using the
   [READY_06 answers](../rulings/2026-09-09_ready06_open_item_answers.md) and
   current decisions. Distinguish proposed recommendations from adopted rulings.
   Catalog-ID enumeration and its artifact already landed; do not recreate them.
4. Begin [task 04.1](../tasks/04_world_commands.md) command/scheduler closure in
   parallel with [movement-contract decisions](movement_contracts.md), using the
   plan-parser. Independently prepare 04.2 command admission and UI layout against
   settled fields. Assign shared runtime integration to one writer.
5. Build task 04, then [task 05](../tasks/05_movement_first_playable.md), through
   the [first-playable checkpoint](first_playable_acceptance.md). Report partial
   results accurately. Complete remaining movement and tasks 06–10 in the
   roadmap's dependency order. Expand those milestone cards into executable
   increments before dispatch; author PC-03 scenarios and PC-04 families now.

Use the existing six-agent roles and configured model tiers. Give each coder a
bounded contract and exact file ownership, QA the actual fixture commands and
reviewers the diffs plus evidence. Keep the lead on integration and unresolved
contracts; use cheaper tiers for repeatable execution/log extraction, not for
unreviewed design decisions. Commit only owned/reviewed work under the current
user authorization. No push, merge of unrelated PR #2, or paid asset generation
is requested by this planning package.

## Context all agents must be able to retrieve

The authority order is in AGENTS; do not substitute this index for the sources:
[setting decisions](../setting_decisions.md), [GDD](../game_gdd.md),
[setting amendment](../setting_rules_amendment.md),
[movement amendment](../movement_direction_amendment.md),
[UI/controls](../ui_ux_controls.md), [balance](../gameplay_balance.md),
[systems architecture](../systems_architecture.md),
[crowd contracts](../crowd_rendering_architecture.md),
[setting bible](../setting_bible.md), [validation resolution](../validation_resolution.md),
[environment](../ENVIRONMENT.md), [validation tools](../validation/README.md),
[decisions](../decisions/README.md) and the current task/test migration ledgers.

For creative work, read the current [library](../redwall-content-library/README.md),
[authoring handoff](../redwall-content-library/authoring_handoff.md),
[continuity](../redwall-content-library/shared/continuity.md),
[locations/movement](../redwall-content-library/shared/locations_and_movement.md),
[theme/materials](../redwall-content-library/shared/theme_and_material_direction.md),
[bounded retrieval examples](../redwall-content-library/retrieval_examples.md),
[art index](../art-reference/README.md),
[model guide](../art-reference/model_reference_guide.md) and
[traversal review](../art-reference/traversal_design_review.md).
All twelve available books were systematically read; earlier Lord Brocktree-only
coverage is historical. The missing Eulalia full text and Salamandastron pages
remain missing. Use query_library.py for relevant individual records, with the
original image files directly in relevant briefs. Keep literary evidence,
AI-authored completions and active gameplay catalogs separate.

## What this package proposes

The task decomposition, PC-01–06 contract queue, FP-01–12 fixture identifiers,
new module paths, movement table layouts/algorithms, scheduler envelope and
recovery preference are **planning/engineering proposals**. None supplies approved
new depth, species capability, air/hazard rate, excavation cost, scenario stock,
family coefficient or memory capacity. Existing numerical values retain their
own sources. G01–05 remain open until their actual closure deliverables pass.

Keep four separate facts in each handoff: adopted policy; adopted engineering
contract; implemented behavior; verified evidence. Update source documents and an
ADR when a proposal is adopted. Implementation alone cannot ratify a proposal.
The [sequencing decision](../decisions/0035-plan-through-settlement-release.md)
records this package's scope and limits.

## Session handoff to return after each implementation increment

Record: current revision and changed files; owning requirements; concrete working
behavior and how to launch it; commands/tests and actual summaries; comparison
scope and first divergence; UI evidence; new versus inherited values; memory and
performance changes; remaining blockers with owner; next exact increment and
file handoff. Put all of this in repository task/evidence documents and update
STATUS without erasing historical results. Do not report this package's static
validation as game tests or performance qualification.

## Check this package

From the repository root run `python3 -B docs/planning/validate_package.py`.
It checks 329 primary GDD/UI/movement declarations plus eight admission
requirements and ten retirement dispositions against the allocation CSV, exact
source-line pointers, unique owners and local document links. Its report is
[validation_report.json](validation_report.json). This is static planning
validation; it does not execute Godot or certify the mapped requirements.
