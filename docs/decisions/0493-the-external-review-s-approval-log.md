# 0493 — The external review's approval log: every group, Brendan's rulings, and what was deferred
Date: 2026-10-01 · Status: Accepted

Numbered 0493: the next free number after decision 0492 (key reassignment) on every local branch, worktree and origin
ref when this was written.

## Decision

The external review of 30 September 2026 is kept in the repository, verbatim, at
[`docs/reviews/2026-09-30-external-review.md`](../reviews/2026-09-30-external-review.md). It reviewed the repository at
commit 157a3a4. It records 53 findings (F01–F53), its proposals (ECO-001–052, SOC-001–045 and UX-001–032), and the
plans P1–P9. Brendan decided every item on 2026-09-30. He split them into lettered groups, each a unit of work with its
own decision record when built.

This record is the log of those approvals, so it lives in the repository rather than in the coordinator's chat. It
holds each group's scope, the decision, the date and the status as of this integration (batch 5, branch
`integrate/review-batch-5`). It is append-only, like every record. When a queued group is built, its own record says
so; this table is not rewritten to track it.

Status words: **done** -- built and on master, with the record that built it. **PR** -- built and in this batch's
pull request. **queued** -- approved, not yet built. **deferred** -- approved for later, or put back on the backlog;
not to be built without asking.

## The groups

| Group | Findings and proposals | Brendan's decision (date) | Status |
|---|---|---|---|
| A | F02 F03 F04 F05 F08 F09 F15 (tunnel and crew hand-offs) | Approved (2026-09-30) | done, 0361 |
| B | F19 F24 F25 F27 F28 (farm and forest conservation; a cancel finishes the delivery) | Approved (2026-09-30) | done, 0222 |
| C | F07 F38 F39 (water safety) | Approved; to land before water part B (2026-09-30) | done, 0231 |
| D1 | F18 (tree regrowth leak), F52 assessed only | Approved (2026-09-30) | done, 0241 |
| D2 | F01 (per-frame allocations), F06 (routes planned across frames) | Approved, with A (2026-09-30) | done, 0361 |
| E | F10 F14 F34 (the HUD's truth, the cast roster, the minimap, the farm units) | Approved (2026-09-30) | done, 0251 |
| F | F20 F31 F12 F36 F35 (panels at 720p) | Approved (2026-09-30) | done, 0391 |
| G | F26 F29 F30 F50 (the pantry modal, the pause menu, keyboard focus, the Demo Lab) | Approved (2026-09-30) | done, 0261 |
| H | F33 F44 (action cards, the assignment preview) | Approved (2026-09-30) | done, 0332 |
| I | F11 F37 UX-011 (the news history, persistent incidents, re-alerts) | Approved (2026-09-30) | done, 0331 |
| J | F46 F47 UX-009 (the pantry leads with stocks, the layer picker, per-member water range) | Approved (2026-09-30) | done, 0292 |
| K | Water part B, everything: fishing trips into the pantry and gear, the smoking and drying rack, mill flour, fishing boats, weir irrigation (discrete, no hydrology), ice fishing, ferries, the regatta feast, otter songs (original text only) | Approved (2026-09-30) | B1 (trips, the boat core, gear, ice, the rack, the mill, the fish stew; 0431–0436): PR. B2 (the weir sluice and garden leat, the otter songs; 0441, 0442): PR. B3 (ferries, the regatta feast): queued |
| L | Spoil per the adopted rule: dug earth is never fertiliser; spoil is earth for raising beds, banking paths and backfill; compost only from plant waste | Approved (2026-09-30) | done, 0401 |
| M | F22 F32 SOC-004 UX-001 UX-002 UX-007 (the Work screen, editable crews, idle residents take eligible work, each resident's Now / Next / Return) | Approved (2026-09-30) | done, 0411 |
| N | F21 UX-027, the minimum of ECO-029 and SOC-007 (the first meal loop) | Approved; the staple shown to Brendan before the build (2026-09-30) | done, 0381 |
| O | F45 UX-008, ECO-005's presentation (farm overview, compare beds, the season calendar, soil plans) | Approved (2026-09-30) | PR, 0451 (its key T: 0492) |
| P | P5, ECO-039 ECO-045 (bridge and tunnel benefit previews, missing-material links, route overlay reasons, the rescue card) | Approved (2026-09-30) | PR, 0461 |
| Q | F41 F42 F53 F40 F52 F51 (world) | Approved (2026-09-30) | done, 0301 |
| R | The sound pass, CC0 packs, asking before each download | Approved; all nine CC0 packs (P1–P8 and the shovel) approved 2026-09-30 | done, 0351 |
| S | Run until, pause types, accessibility presets (UX-022, UX-023); save deferred | Approved (2026-09-30) | PR, 0471 |
| T | Residents as people (P6, SOC-001, SOC-014, SOC-028); names proposed to Brendan first | Approved (2026-09-30); names ruled 2026-10-01 (below) | PR, 0491 |
| U | F49 UX-017 UX-019 (the guided first village, objective cards confirmed by real outcomes, the help page, practice stories) | Approved (2026-09-30); its objective texts approved (below) | PR, 0481 |
| V | SOC-035–045 (combat, army, campaign) | **Deferred** to the backlog: a separate tactical prototype later (2026-09-30) | deferred |
| W | ECO-002 ECO-013 ECO-023–035 (seed, forage roles, fishing methods, plans, stewardship and collection, substitutions, preservation, menus, cooking modes, drinks, local buffers, purpose reserves, storage policies, the flow view) | Approved; content calls within the content library, recorded in decisions; the pantry rules respected (eel a hazard, no shrimp, mussel coast-only, saltpan from coastal brine) (2026-09-30) | queued, after N and water B |
| X | ECO-001 ECO-003 ECO-004 ECO-006 ECO-007 (crop roles, harvest plans, player-placed gardens, irrigation fittings, tending policies) | Approved (2026-09-30) | queued, after O |
| Y | ECO-008–012 ECO-014 ECO-015 (the inherited old orchard with early yield, nursery plans, orchard harvest groups, hives, honey and wax, gathering outings, protected groves) | Approved; the M3 orchard timing change to be recorded as a decision (2026-09-30) | queued, after W |
| Z | ECO-016–022 (woodland compartments, timber types, landmark trees, equipment packages, auto-repair and quality, workshop fittings, craft provenance) | Approved (2026-09-30) | queued, after M |
| AA | ECO-039 ECO-040 ECO-042 ECO-043–052 (routes and shortcuts, diving surveys, canopy access -- waiting on the MOVE gates, warren destinations, discoveries, dig stages, passage upgrades -- bracing reconciled with the adopted support contract, earth destinations, tip reclamation, landscaping, room and cellar intentions, the shared junction nook) | Approved (2026-09-30) | queued, after tunnel P7 and L |
| AB | ECO-036–038 (the first year's cadence, seasonal work suggestions, bounded landscape threats) | Approved (2026-09-30) | queued, after O |
| AC | SOC-001 SOC-002 SOC-003 (non-military) SOC-005 SOC-006 | Approved; the mentoring rule change to be recorded (2026-09-30) | queued, after T and M |
| AD | SOC-007–012 SOC-017–019 | Approved; the child and elder items wait on the family package (PC-04) (2026-09-30) | queued, after N and T |
| AE | SOC-013–016 SOC-020–030 | Approved; lore original only (2026-09-30) | queued, after AD |
| AF | SOC-031–034 (progression and difficulty) | **Deferred**: "come back to later" -- to be raised again once a community day works (2026-09-30) | deferred |
| AG | UX-003 UX-004 UX-010 UX-012 | Approved (2026-09-30) | queued, after E, F and G |
| AH | UX-013–016 | Approved; paid art for the kit asked separately (2026-09-30) | queued, after M and H |
| AI | UX-018 (the field guide) and UX-020 (named projects) approved; UX-021 (the return journal and save browser) and UX-024 (experience selection) **deferred** with save and AF (2026-09-30) | split | UX-018, UX-020: PR, with U (0481). UX-021, UX-024: deferred |
| AJ | UX-025 (silhouettes), UX-026 (worn ground), UX-028 (seasonal scenes) approved, with no paid spend without asking; UX-030 (the music motif) and UX-032 (voices) put on the **backlog** (2026-09-30) | split | UX-025, UX-026, UX-028: queued. UX-030, UX-032: deferred |
| AK | F48, UX-005, UX-006, and bridge removal with a cap (coverage gaps found after the review was decided) | Approved (2026-10-01) | queued, after O, T and U |

Two other coverage gaps were ruled on 2026-10-01. The test hygiene work is running on `chore/test-hygiene` (0501).
Four settlement loose ends were set to "fix all": starting demolition, APPOINT_WARDEN, stale availability labels and the
family hunger helper. They are on `fix/settlement-loose-ends` (0511), with a PR open; demolition and the hunger helper
were blocked there and continue below. The release gates were folded into the performance and playtest step: asset
contact metadata, the silent-video work chain, graphics tiers with the GTX 1660 floor, and fresh-player sessions run by
Brendan.

## Brendan's rulings

- **Dishes** (group N, 2026-09-30; decision 0381): two dishes, alternating. Wild oat porridge is cooked as the GDD's
  `porridge` (grain 2 + water 2 -> 2 × 1800 NP, 12 WU). Togget's vegetable soup is cooked as `root_stew` (roots 3 +
  water 1, 16 WU). Water is a stocked item drawn at the well (1 WU a unit), and fuel is 0.1 U of wood a batch. The
  village eats breakfast and supper. Water part B added the fish stew as a third dish under the GDD's `fish_stew` row
  (decision 0436).
- **Day length** (2026-10-01; decision 0421): at 1x a game day lasts ten real minutes, as the GDD says. Crops, weather,
  spoilage, meal windows and the night routine were re-timed to fit.
- **Names** (group T, 2026-10-01; decision 0491): every name is option A -- Wenna Tallowby, Jory Whitethorn, Linnet
  Whinberry, Tobit Highbough, Tegwin Slipstone, Corra Netley, Tuppen Clayholm, Hulda Slatebrook and Elstan Weirholt.
  The cast is an ORIGINAL community: the mouse keeper is not Rowan, who stays the settlement game's Warden.
- **Songs** (group K's B2, 2026-10-01; decision 0442): the four song texts are approved as written.
- **Guide texts** (group U, 2026-10-01; decision 0481): the objective texts are approved, with "they" for residents.
- **Demolition** (2026-10-01): answers 1–9 of the drafted contract are approved, and removing furniture returns 50 % of
  its materials. The full path is approved, as a sequential programme D1–D9 in settlement code: the ruling, the
  anchor column and the memory ledger; ground piles; the live apply and container rebinding; the gate and the paid
  ledger; composed completion; evacuation hauling; dispatch, UI and the stranded notice; movement invalidation; QA.
  D1 is running on `feat/demolition-d1` (0531).
- **PC-04, the family package** (2026-10-01): adopted with children inactive, and the drafted values are confirmed:
  - child hunger 750/1000;
  - care decay 250 an hour and gain 3000 an hour, starting at or below 6000 and stopping at or above 9000;
  - turns of at most 750 ticks;
  - a household of at most 8, with at most 2 named caregivers, "willing" on by default;
  - no direct harm from zero care;
  - mood weights 12, play 320 and learning 400, with grief reused;
  - children may have non-violent arguments.

  Engineering gates 1–6 stay open. The work is running on `feat/family-pc04` (0521).
- **The Warden** (2026-10-01; 0511 and DEC-042 on the settlement branch): adults and elders may be Warden, never
  children. A living Warden may be replaced with confirmation, and the old one steps down. Naming waits on READY_07 I2.

## Deferred, not to be built without asking

- **Combat and the campaign** -- group V, SOC-035–045: a separate tactical prototype, later.
- **Progression and difficulty** -- group AF, SOC-031–034: to be raised again once a community day works.
- **Save, the return journal and experience selection** -- UX-021 and UX-024, with the save work that S also deferred.
- **The music motif and voices** -- UX-030 and UX-032: on the backlog. The otter songs (0442) keep to their terms --
  singing that is part of the world, apart from any score -- but build neither.

## Source

The external review ([`docs/reviews/2026-09-30-external-review.md`](../reviews/2026-09-30-external-review.md)); the
coordinator's review queue as of 2026-10-01; Brendan's rulings as relayed there; the decision records named in the
table.
