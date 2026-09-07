# 0012 — Use reviewed screenshots directly while preserving source and implementation boundaries
Date: 2026-09-06 · Status: Accepted

## Decision

Index all 28 supplied screenshots individually in `docs/art-reference/` and
use their specifically identified features as direct references during model
construction. Keep image observations, source-slide mechanics and proposed game
adaptations separate. Record source files by repository-relative path and digest.

## Why

Brendan explicitly requested detailed individual review and direct model use,
especially examining tunneling, swimming and climbing. The images now provide
concrete body, garment, prop and pose references. They also mix styles, different
novel eras, incomplete views and game-design proposals. One slide's five-pearls
claim conflicts with six in the supplied novel. Two screenshots repeat a slide.

## Consequences

- The model agent opens the originals and identifies accepted features; unseen
  backs, joints and attachments are original construction work, not source facts.
- Existing DEC-018/019 and geometry/rig/atlas limits govern production. No model
  or performance success is implied by a reviewed illustration.
- DEC-029/031's multi-level construction remains required. Its single-floor
  memory assumptions must be revised through the owning architecture amendment.
- Swimming/climbing, sapping, diving hazards and tactical effects require full
  owning specifications before activation. The review supplies the concrete work
  queue without silently replacing the active ruleset.
- Preserve food/admission/content decisions and scenario chronology. Slide
  launch/DLC classifications and turn counts are not our release or balance plan.
- Leave source PNGs in `ImageReference/`; do not rename, stage, commit or push
  them or the research as part of this task.

## Source

Brendan's 2026-09-06 request; all 28 inspected PNGs; SET-ART-PACKAGE-001,
SET-ART-MODEL-001, SET-TRAVERSAL-REVIEW-001 and SET-ART-MANIFEST-001;
AGENTS.md and current owning specifications.
