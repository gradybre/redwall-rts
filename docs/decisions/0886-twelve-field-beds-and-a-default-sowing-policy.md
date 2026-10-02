# 0886 — Twelve field beds and a sowing policy the live village starts with (balance ruling E5)
Date: 2026-10-01 · Status: Accepted

**Brendan's ruling E5** (2026-10-01, relayed to this lane by the coordinator and listed in the coordinator's review
queue as "E5 12-18 beds (+ default sowing policy) -> crops X"): the demo village gets **12–18 farm beds instead of 6**,
and **hands-off play must sow** -- "a default policy that sows empty beds in season, unless the GDD forbids it". The
balance baseline behind it (`docs/balance/2026-10-01-first-year-baseline.md` on the balance lane) found six beds give
about 70–100 portions a year against the 864 nine residents need, and that a village left alone never sows again (the
farm's routine raises only harvests and clearings, REQ-SET-073/085). This record should be copied into
`docs/setting_decisions.md` as a DEC by Brendan; it is recorded here as relayed. Numbering: see 0881.

## Decision

### Twelve field beds (and the kitchen garden's four on top)

**Twelve**: the six world beds and a **south field** of six more (`farm_catalog.gd` THE SOUTH FIELD, SOUTH_AT), laid
from the start, as ONE rectangular field of six GDD §5.6 tiles -- three across, two deep, 2 m × 2 m each (§5.6: "field
designation is 4–256 tiles, rectangular or painted connected area") -- on the open grass south of the covered store,
east of the workbench and north of the boulder. Every tile has an outer edge to be worked from; the tiles are not
walking obstacles (the garden's are not either; the six world beds are). With the kitchen garden's four sites
(decision 0883) the village can hold **sixteen**, inside E5's range.

Why there, and why twelve: the ground beside the first block is already spoken for -- the underground suites' and the
room tool's own test villages dig a burrow home at (-1, 10) and a cellar at (-7, 4), and a room may not be dug under
crop beds (`underground_rooms.gd` REFUSE_OVER_CROPS), so a block east of the first one (the first attempt) refused
those rooms. The ground south of the store holds exactly one 6 m × 4 m field clear of the store, the workbench, the
boulder and the shore, and close to the covered store its harvests go to. Eighteen would need a third place this
size; none is clear without moving world props. The south field's soils are loam and clay (grain, beans and the leaf
row grow on both; roots on the loam), so a hands-off spring can sow wheat in every tile. Every tile is checked clear of
every layout obstacle (`test_demo_sowing.gd`). A kitchen-garden site nobody has laid out no longer keeps a room off it
(`tunnel_control.gd bed_laid`), as it grows nothing.

**Water service** reaches every bed as it reaches the first six: hand watering from the well (the Water job), and a
tunnel outlet (decision 0884) wherever a tunnel runs under a bed. The weir's leat keeps its three beds (decision 0441:
bounded, discrete zones); extending it is a proposal below.

### The sowing policy

A fourth tending policy, **Sow empty beds in season** (`farm_tending.gd` POLICY_SOW, `farm_sowing.gd`): on an empty
laid bed not resting and not booked by the harvest plan (decision 0882: a booked bed is sown by its booking on its day,
so Steady table and Custom dates still work with the policy on), sow the player's chosen crop, else the bed's **rotation**'s next crop, when its window and soil
allow, within the group's budget (a sowing is 4 WU, §5.6).

- **The rotation** is GDD §5.6's: "chosen manually per field or through an explicit three-entry cycle; default cycle
  grain→beans→roots" -- wheat, pea, carrot in the demo's ingredients. A bed's soil may refuse a row, so a bed starts on
  the cycle its soil can follow: loam grain → beans → roots, clay grain → beans → grain, sand roots only. The player
  steps a bed through the cycles its soil can follow (the bed panel's **Rotation ▸**); a crop chosen with Plant… is
  always sown instead.
- **The cursor** follows R06-JOB-005: it advances once, when the cycle's crop has been in the bed and the bed is empty
  again; it never skips a blocked entry and never substitutes a crop. A crop whose window is closed waits for its next
  window, said once a bed and entry ("Bed 1's wheat waits: sow in Spring 1–4").
- **Default**: the module starts every policy OFF -- GDD §4.2's FieldPolicy default `auto_rotation=false`, R06-JOB-005
  ("With auto_rotation=false, completion shall not request another sowing cycle") -- and **the live village turns the
  field's sowing ON at its start** (`demo_village.gd _build_farm`), per E5. That is a deliberate exception to the GDD's
  default for the demo village, made by Brendan's ruling (which outranks the GDD in AGENTS.md's order); the kitchen
  garden's sowing stays off (the garden has its own plan, 0883).
- **The budget** default is now 16 WU a day (four sowings), up from 8, so a hands-off spring sows the nine empty field
  beds in about two days -- inside wheat's window (Spring 1–4).

## Known gaps

- The minimap still draws only the six world beds (`demo/ui/demo_minimap.gd` reads `world_layout.gd CROPS`); the south
  field and the garden are not on it yet.

## Brendan's ruling (2026-10-01)

**E5 is approved as built**: twelve field beds and the default sowing policy, with the demo village's exception to
FieldPolicy's `auto_rotation=false`. Proposal 1 is done: E5 is **DEC-046** in `docs/setting_decisions.md`. Proposals 2
and 3 stay as recommended (not built). Recorded at the batch 7 integration (decision 0902); nothing changed in behaviour.

## Proposals for Brendan

1. **Record E5 as a DEC** in `setting_decisions.md`, including the exception to FieldPolicy's `auto_rotation=false`
   default for the demo village.
2. **Extend the leat** to the south field (three more beds, a second table row set). **Recommendation:**
   only if wet/dry service proves wanted there; hand watering and tunnel outlets already reach them.
3. **More cycles** (a leaf row for summer sowing, beans → roots → roots ...) and editing a cycle entry by entry.
   **Recommendation:** after E4's pottage gives cabbage and beans a dish.
