# UI refinement acceptance — SET-UX-VIS-002

2026-09-11 · **Runtime cases below NOT EXECUTED by this design package.** The
reference PNGs are original synthetic compositions, not Godot screenshots.
Normative requirements: [amendment](../../ui_visual_refinement_amendment.md).

## Cases and required evidence

A case is PASS only with its actual evidence and scope. Use BLOCKED when an
owner/data/host is absent; do not rewrite that as N/A to improve a pass count.

| Case | Trigger / fixture | Required observation and evidence |
| --- | --- | --- |
| A01 | Boot, no selected entity, no workspace | Only true-gated HUD surfaces; no central empty panel. Inventory of visible UI IDs and native screenshot |
| A02 | Before/after M1; resident versus zone selection; ready/locked/development/data-unavailable | Feast gate works; resident has no zone policy; development missing owner is not a fictional unlock; hidden targets absent from focus/hit/accessibility trees; parameterized visibility tests and screenshots |
| A03 | Open Residents, select row, close, open New Settlement, then F6 | Correct 069 roster ownership, no child leakage; workspace/modal variants; no generic unavailable world-list block; one current primary workspace; real focus/visibility trace |
| A04 | Engine specimen of both surface families and eight states | Actual fonts/colors/radii/borders/states, disabled-selected check, focus+selection; contrast at actual backgrounds; screenshots of specimens and computed token contrasts |
| A05 | Keyboard and pointer/trackpad across focus changes, opening/closing, text entry and resize | Actual focus navigation/trap/return, no ghost focus outline, disabled reason inspectable, correct Esc ladder, world clicks outside controls; event trace plus focused native captures |
| A06 | Every scoped icon at16/18/24 and state glyph12; four species emblems | Recognizable silhouettes, crisp strokes, no glyph boxes/emoji/false mouse-for-all; ornament never covers content or claims an input rect; asset sheet and source/license hashes |
| A07 | 1920×1080@100; 1280×720@100; 1440×900@125 | Correct scale/profile, component geometry, safe insets, measured content/hit rects; no unintended overlap. Log actual pixels/logical viewport, not requested window size |
| A08 | 1280×720@125 and@150; select resident with drawer closed then opened; 32-character name and long warning | Correct Narrow, explicit drawer, scroll reachable, no clipping or footer occlusion, command width≥240; all overflow in096; body font unchanged; open/closed captures and keyboard sequence |
| A09 | Zero versus absent food/fuel/beds, real populated counters, empty roster/filter | Correct quantities/units/availability, no fake zero or placeholder totals; formatting tests at0/1/large quantities and captures with data provenance |
| A10 | PLAYER+MENU holds, closing menu, speed2/4, load/critical pause | Player wording reflects actual ordered reasons; requested speed remains distinct; paused UI stays interactive. Scheduler state trace and screenshot; no unpause from unrelated action |
| A11 | Actual invalid zone or stale target; warning then critical/save refusal; no active alerts | Reason/recovery appropriate to actual result; icon+word; no empty alert frame; History remains. Exact result logged; no code-only or developer-owner message. No fabricated save-error test if save owner absent |
| A12 | Real named/unnamed residents; different needs/health/XP; unavailable rate; max skill | Five meters, exact percent and rate, real XP and status, no raw basis points; safe long identity; source snapshot and screenshot. Changing selection changes the correct fields |
| A13 | New Settlement initial form at wide and narrow | All five authored inputs, legal default values, proper groups, clear Create/Cancel, illustration drops first; no roster rows behind the form; actual UI capture |
| A14 | Invalid name/seed, unavailable scenario configuration, initialization failure/progress/success | Errors next to their cause, real progress only, retained input/old world on failure, successful legal bootstrap paused; no mere Create button. If initializer blocked, record that integrated part BLOCKED |
| A15 | Zone draft while paused → queue → resume → commit/refusal → cancel | Visual state keyed to real command/result identity, no pre-commit goods/WU mutation, exactly one owned result; cancellation effects match its phase; actual state trace and capture sequence |
| A16 | Same committed inputs with UI open/closed, camera moves and mode changes | Equal-tick canonical comparison over implemented state; no widget writes, RNG draws or authoritative decisions from UI; bounded integration test and code review |
| A17 | VoiceOver/accessibility traversal, disabled reason, dynamic value changes | Correct role/name/value/state, no decoration, coherent list semantics and no duplicate announcements. Actual Mac execution or BLOCKED; NVDA/Windows deferred separately |
| A18 | Pause and reduced motion on; changing need/counter values | UI remains responsive, all transitions instant with reduced motion, no geometry animation, focus jump or lost state cue; runtime observation and targeted test |
| A19 | Synthetic specimen and live main scene | Distinct scene/data flags and visible specimen banner; evidence manifest identifies source. Resident specimen never passes real startup/selection test; mockup art not used as runtime overlay |
| A20 | Screenshot evidence set including high DPI | Actual dimensions, scale, fixture/state, source revision and filename recorded. Requested3840×2160 denied by OS stays DEFERRED/BLOCKED, never renamed pass |
| A21 | Repeated UI open/close, selection changes, roster scroll and idle frame | No accumulating nodes/theme/font reloads, full authoritative per-frame scans or per-resident processing; actual UI timing versus ARCH-UI-001 and explicit hardware/build limits |
| A22 | Matching HUD/detail composition and player review | Structural fidelity checklist below passes; before/after report records defects fixed and remaining, with Brendan's aesthetic verdict separate and no invented approval |
| A23 | Final diff and handoff | All42 IDs map to implemented files, tests and evidence; old failing assertions have migration rationale; assets/version/source changes listed; exact next dependency and remaining blockers |

## Minimum image set

Store runtime evidence in `docs/validation/evidence/ui-refinement/`, separate from
`docs/design/ui_refinement/visuals/`. Capture at least these named states:

1. Wide idle paused HUD with no selection/workspace.
2. Wide selected resident journal.
3. Narrow at150%, selection made but drawer closed.
4. Same narrow scene with drawer open and keyboard focus.
5. Roster with selection and scroll; then unrelated New Settlement without leaked rows.
6. New Settlement at wide and narrow.
7. Invalid input with error and visible footer.
8. Zone pending while paused.
9. Refused zone with correct recovery and focus.
10. Native FOREST/JOURNAL specimen with all eight states, including disabled-selected.
11. High-DPI actual viewport capture.

Cases may share images where the state genuinely proves both. Behavior needs
traces/tests as well as screenshots. Also exercise1280×720@100/125,1920×1080@150
and1440×900@125; images need not duplicate identical evidence. Record a separate
3840×2160 status. Windows is deferred by Brendan; Mac does not qualify minimum PC.

Use the same seed, committed snapshot and viewport for before/after comparisons.
If a real resident or producer is unavailable, use a labeled component specimen
for design iteration and mark the live binding case BLOCKED. Never hide initializer
failure by inventing people, resources, production activity or a terrain scene.

## Structural visual gate

The reviewer must inspect actual images at100% and at the intended viewing scale.
A matching component specimen permits direct geometry comparison; a live screenshot
with different data need not be pixel-identical to synthetic references.

- Six zones and explicit amended anchors fit the viewport. Measured top-level
  rectangles match the specified formula within one final pixel-rounding step.
- FOREST controls and JOURNAL content have distinct roles; green rectangles have
  not merely been recolored to paper without changing hierarchy/content structure.
- Header, identity, health, five needs, activity/skills and center action follow
  the resident anatomy. Values, bars and rate captions align into repeated columns.
- No empty alert card, automatic center scaffold, stretched unavailable block,
  orphaned lock, clipped label, missing glyph or visible developer-owner message.
- Typography uses the real fonts/weights. Required line heights and wrap rules
  hold; no fake bold or shrinking text. Font rasterization may differ from Pillow;
  compare metrics and hierarchy rather than requiring identical antialiasing.
- Controls have complete states; selection is not indistinguishable from focus;
  the paper focus ring remains dark and readable. Active values never depend on
  translucent scenery or color alone.
- Icons/emblems and ornament form a coherent family and read at their actual sizes;
  source screenshots are not traced/cropped into UI. Decoration never consumes
  space needed for a value, error or touch target.
- The new form is complete and calm: visible labels, grouped choices, retained
  footer, optional illustration gutter removed on small layouts.

These are all required, not a weighted beauty score. Brendan's aesthetic verdict
can still request changes after technical/structural acceptance. Record that as
PENDING / APPROVED / CHANGES_REQUESTED with the actual dated feedback; never infer
APPROVED from silence or an agent saying it looks good. Continue independent work
while feedback is pending; don't propagate an unresolved visual pattern everywhere.

## Defect and completion policy

P0: incorrect state/commands, false data, save or input safety defect. P1: unmet
required flow, clipping/contrast/focus/visibility defect, unavailable implemented
control or structural visual-gate failure. P2: small cosmetic inconsistency that
still meets the contract. Fix all P0/P1 before marking implementation complete;
list P2s with owner and follow-up. User-requested design revisions remain explicit.

Report separate booleans/statuses: implemented slice, functional checks, visual
structural checks, accessibility qualification, Brendan visual verdict, full
first-playable checkpoint. A partial UI specimen cannot collapse these into one
“done.” No declared requirement is optional merely because it is inconvenient.

Evidence manifest fields: case ID; requirement IDs; exact revision/dirty digest;
engine/build; hardware/renderer; scenario/seed/tick; actual W/H,S,Lw/Lh/profile;
source snapshot fixture; actions; expected/observed; result; screenshot/log/test
paths; reviewer; unresolved dependency. Include a short Player Impact Report with
before/after references and a requirement coverage table.

## Research-informed review procedures

The [RTS comparison](rts_ui_research.md) and [RUI-C01–11 checklist](rts_ui_review_checks.csv)
provide concrete journeys for the existing cases above. Report actual statuses and
evidence; their initial NOT_RUN values are not failures or passes. They introduce
no new gameplay scope. Proposed text-scaling work in RUI-P01 remains a separate
owner amendment; current package checks do not establish XAG101 conformance.

## Resident UI contract follow-up — 2026-09-12

A12 additionally requires UI-IDENTITY-R01 heading geometry and NEED-RATE-R01
all-five current rate bindings, caps, pause and stale-identity cases; arithmetic
checks and screenshot acceptance remain distinct.
Read [the exact ruling](../../rulings/2026-09-12_resident_header_and_need_rates.md).
