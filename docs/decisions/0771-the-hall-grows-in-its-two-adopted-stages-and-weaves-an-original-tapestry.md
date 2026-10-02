# 0771 — The hall grows in its two adopted stages, takes four banners, and weaves an original village tapestry
Date: 2026-10-01 · Status: Accepted

Numbered 0771: feature #53 (the Great Hall) was given 0771–0779; none was taken on this branch.

## The conflict, and Brendan's ruling (2026-10-01)

Feature #53 asked for a centrepiece hall that "grows through 3–4 stages", each adding dining and sleeping capacity.
Before building, the adopted documents were checked and the request was found to contradict them, so work stopped and
the conflict was reported:

- **GDD §5.9 (line 730):** the residence/hall tier-2 package is "stone 40+wood 20+cloth 8, 1200 WU, heat fuel×0.75 and
  room comfort target+1000, no new floor/beds … Only one upgrade per building; tier 3 is absent." REQ-SET-136 applies it.
- **`gameplay_balance.md` BAL-SAFE-013:** "WHEN an upgrade completes, the system SHALL set tier=2 once; a second
  application SHALL be refused"; its upgrade table has the one hall row, tier 1 → 2.
- **Capacity:** the starter interior's dormitory (40 tiles, ≥3 a bed) and common room (25 tiles, ≥2 a dining seat) are
  full at 12 beds and 12 seats, and tier 2 adds no floor, so no stage can add dining or sleeping capacity.
- **Unlocks:** the adopted milestones (§5.11) need 12 residents (M1), 48 (M2) and 80 (M3); the demo has nine and no
  immigration. The GDD gives the tier-2 package no unlock at all.

Brendan chose **option A, "the adopted version"**: stage 1 is the hall as it stands; stage 2 is the one tier-2 upgrade
with exactly REQ-SET-136's package and BAL-SAFE-013's refusal; an optional banner step of up to four Decoration
furniture banners, comfort only; an original community tapestry with an add-entry API for #10 and #57; and the feasts'
gathering query, seats ≥ ceil(E / 3). The unlock condition was a PROPOSAL, since ruled (below).

## Decision

1. **Two stages, `godot/demo/hall/`.** `hall_rules.gd` holds every number: the package (wood 20, stone 40, cloth 8 as
   milli-U; 1200 WU; 4 builders, §5.9's maximum), the Decoration row, REQ-SET-126's refund (100% before work, 80%
   floored after), comfort (common 7500, +1000 at tier 2, +250 a banner capped at 1000, ≤10000), fuel (1000 / 750 per
   mille), the 12 seats and §5.7's ceil(E / 3). `hall_projects.gd` refuses the upgrade at tier 2 in BAL-SAFE-013's
   words, while locked and while planned, and sets tier 2 exactly once. There is no stage 3 anywhere in the code.
2. **The build flow is the work board's.** A project is DELIVERING, BUILDING or DONE; its places are a new board
   source, `WorkIds.SOURCE_HALL` (`work/hall_work.gd`). Builders walk to the stockpile, lift one material a load at
   their §5.2 carry capacity and §5.7's masses (reserved when they set off, taken from the stores only when lifted:
   REQ-SET-124), carry it to the site pile, set it down; once everything is delivered they build before the hall
   (REQ-SET-125), their work summed. A carrier called away puts its load back whole (the bridges' rule) and keeps the
   project to come back to (`hall_resume.gd`, held weakly); a load in hand is not taken to bed first (decision 0222).
   Pause and Reassign are the board's; Cancel is the panel's, per project, with REQ-SET-126's terms shown before it is
   pressed. Every milli-U is in the stores, a carrier's arms or the project until built in (tested every frame).
3. **What the hall gives, from the adopted rules only:** 12 seats (the starter layout's T cells) for meals, songs and
   feasts; floor sleep for the bedless (REQ-SET-133; the GDD's starter beds are not modelled -- the demo's beds are the
   burrow homes', decision 0210); the comfort target; a hearth's fuel factor. `demo_hall.gd` answers
   `gathering_seats()`, `seats_needed(E)`, `can_gather(E)` and `gathering_capacity()` (36) for the feasts (#9), and
   `fuel_permille()` for whoever lights a hearth here (winter fuel).
4. **The look, from existing models only** (`hall_view.gd`; no paid art, nothing new staged): the hall itself is never
   moved or scaled (no new floor, so no new footprint or obstacles). Delivering: a stone heap (`rock_cluster`), a timber
   stack (`log_stack`) and the cloth (`sack_pile`) by the east end, sized by what is delivered. Building: a work rail of
   fence lengths before the front and a plank stack. Tier 2: a second chimney pot on the east roof (`chimney_pot`,
   darkened) and two woven roundels (`rag_rug`, stood upright) in the outer bays. Banners: `relic_banner` stood upright,
   ×3, dyed clay, leaf, brass and sage by a multiply on a duplicate of its own material. Lighting owns the hall's lights;
   none are added.
5. **The village tapestry** (`tapestry.gd`): packed columns, date-ordered, at most 128 entries, never overwritten (the
   beginning is kept), refusals as codes with words, once-only keys so a caller may post on every check. The hall weaves
   stage 1 (tick 0), the first harvest (the farm crew's harvest log), the first winter (Y1 Winter 1, the offset
   calendar's tick 643500), stage 2 and each banner. The panel (`tapestry_panel.gd`) draws it as a woven timeline: warp
   and weft on an oat ground, clay-and-brass border stitches, one umber thread with a knot per entry in its kind's
   colour. **Original:** LORE-R07 ("do not install the canonical tapestry in an unrelated settlement by default") and
   the setting bible's "an original memorial must not be casually identified as Martin's sword or tapestry"; the names
   are generic ("Community hall", "Great hall", "the village tapestry"), and no book's tapestry is named or depicted.
6. **The API** is `demo_village.gd tapestry()` and `hall()`, documented in `tapestry.gd` THE API and the demo README.
   The chronicle (#10) uses `KIND_CHRONICLE`, the milestones (#57) `KIND_MILESTONE`; neither is depended on.
7. **Input:** a left click on the hall opens its panel (a ground handler asked after every other); a right click on it
   with residents selected sends them to a project under way. **No key is added.** The panel is a planning surface
   (Pause while planning), and the top-centre incident, guide and people cards yield to it.

## Brendan's rulings on the proposals (2026-10-01)

Brendan approved **P1–P5 as built** (relayed by the coordinator): the upgrade opens once the first harvest is gathered
into store; the hall keeps the village's opening 24 U of cloth; a banner costs its wood alone (decision 0210's
substitution for the missing wax); a cancelled project's refund goes into the stores; stage 2 is called "Great hall".
**P6 stays decision 0210's existing value**: a WU is 0.15 s of one builder's demo time. The options below are kept as
the record of what was weighed.

## The proposals as put (now ruled)

- **P1 — The upgrade's unlock** (`hall_rules.gd UNLOCK_CONDITION`, one data constant). Options: (a) the first harvest
  gathered into store; (b) the first winter setting in; (c) from the start, like the GDD's other Start buildings;
  (d) a scaled-down M1 for the nine-resident demo. **Recommended and built: (a)** -- an early, earned moment of
  thriving that every demo playthrough reaches.
- **P2 — The cloth.** The demo has no cloth chain; the package needs 8. Options: (a) the hall model keeps the village's
  GDD opening cloth, 24 U (§5.1), at the stockpile -- built; (b) add cloth to the shared stores and the top bar;
  (c) substitute planks, as decision 0210 did for a bed's cloth. **Recommended: (a)**, which keeps the package exact
  and the shared stores untouched.
- **P3 — The banner's wax.** §5.9's Decoration is wood 1 + wax 0.25 and the demo has no wax. Built: decision 0210's
  substitution for the same row (its wood alone). Options: keep it, or hold banners until an apiary exists.
  **Recommended: keep it.**
- **P4 — A cancelled project's refund goes into the stores**, not REQ-SET-126's "reachable ground lots": the demo has
  no ground lots (the settlement's ground piles, decision 0532, are not in the demo). Recommended: keep until the demo
  takes ground piles.
- **P5 — The name.** Tier 2 is called "Great hall" in the panel. "Great Hall" is also Redwall Abbey's room; here it is
  the generic English phrase for the village's own hall. Options: keep, or "Raised hall" / "Stone hall". Recommended:
  keep, lower-case in prose.
- **P6 — Work rate.** A WU is 0.15 s of one builder's demo time (decision 0210's fit-out rate): the upgrade's 1200 WU
  is 7.2 game hours for one builder, 1.8 for four. Recommended: keep (the demo's other furniture work's rate).

## Review and testing

An independent review found two HIGH issues, both fixed with regression tests:
- **H1.** Letting a builder go (Pause, Reassign, Cancel) could hand it straight back a place on the same project through
  an older resume record. Fixes: `hall_crew.gd` refuses a take-back while it lets someone go; a project is cancelled
  before its builders are released; a task of an older planning stops at once.
- **H2.** The open panel froze during building -- its WU and Cancel's REQ-SET-126 terms -- because work did not bump
  the projects' revision. It now bumps when work begins and on each whole WU.

Mutation testing of the logic: 39 of 40 mutants killed. The survivor (`_drive_work` returning true after the last WU)
is equivalent: the next frame's phase check ends the task. Reverting the cancel-before-release order alone is also
not caught, because the take-back guard covers the same case; the order is kept as defence in depth.

## Consequences

- A tier 3, more seats or more beds in the hall need a GDD amendment first; `plan_upgrade` refuses at tier 2.
- `WorkIds.SOURCE_COUNT` is now 9 (`SOURCE_HALL` 8; `SOURCE_WALK` moved to 9, still past every source).
- A future stone-built hall model (a real tier-2 look) would be new art; the composed additions are modest.

## Source

Brendan's ruling, 2026-10-01 (option A, relayed by the coordinator). `docs/game_gdd.md` §5.1 (initial inventory),
§5.2 (carry capacities), §5.7 (masses, feast seating), §5.9 (catalog, layout, REQ-SET-124–126, REQ-SET-133,
REQ-SET-136, the tier-2 package), §5.11 (milestones); `docs/gameplay_balance.md` BAL-SAFE-013 and its upgrade table;
`docs/setting_bible.md` LORE-R07 and §11; decisions 0210, 0222, 0411, 0491.
