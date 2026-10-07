# 1601 — Hives, honey and wax in the demo: a real Hive row beside the old orchard, its winter feed first
Date: 2026-10-07 · Status: Accepted (engineering); **PROPOSALS P1–P8 wait on Brendan**

**Numbering.** BACKLOG.md's HIVES packet assigns 1231–1240, but a parallel digging branch already uses 0991–1217 and
its range grows; the lead remapped this branch's three food packets to **1601–1629** (HIVES 1601–1609, PRESERVE
1611–1619, BREW 1621–1629). 1601 is free on every local and remote branch (`git for-each-ref` over `refs/heads` and
`refs/remotes`, `git ls-tree` of each one's `docs/decisions/`), and `docs/validation/decision_numbers.py` passes.

## Approval

Review group Y (decision 0493, 2026-09-30) and "HIVES: start soon (Y hives/honey/wax) after batch 7" (Brendan,
2026-10-01; recorded only in the coordinator's tracker, first written down in `docs/handoff/RULINGS.md`). The bee skep
(0941) and the bees (0971) were made under approved art passes; this record wires them. The scope below is derived
from the GDD; where it goes past the GDD it is a PROPOSAL.

## Decision

The demo's apiary is **one inherited skep west of the old orchard whose hive is a real `Hive` row of
`scripts/core/orchard_hive.gd`, created in the orchard model's own store** (`demo/hives/apiary_model.gd`). The keeper's
work is three new orchard job kinds on the existing Orchard board -- **Tend the bees**, **Feed the bees**,
**Recolonise** -- so no new work-board source is added. A collection **puts the winter's feed by in the hive first**
(ECO-012) and carries the rest of the honey to the old orchard's basket stand, where the Haulers take it on like fruit.
Honey is the pantry's existing item 25; the dish book's pending `honey` is struck, so the raspberry cordial is
cookable. Wax waits on the apiary's own shelf. A healthy hive pollinates the orchard's trees through the store's own
links and the field's beans through a new `farm_sim.gd` join.

### The rules used, as written

- **GDD §5.6's hive rows**, called through `orchard_hive.gd` and never retyped: strength 8000 at founding, healthy
  ≥ 5000; spring–autumn a serviced day makes honey 2 U + wax 0.25 U × strength/10000 for 20 WU; a missed service day
  −200 and nothing made; a tended spring day +300 after production; winter makes nothing, needs no tending, eats
  honey 0.5 U a day from the feed or loses 500; at 0 abandoned; recolonised in spring with honey 4, wood 2, 60 WU and a
  3-day wait. The store's own interpretations stand (strength clamped 0..10000; the founding day counts as serviced; a
  partial winter feed is not eaten).
- **REQ-SET-082** (§5.6 pollination ×1100 / ×1150, beans and orchard fruit, 12 m, healthy hives only) and
  **REQ-SET-083** (service and feed deficits shown before abandonment): the apiary's readout.
- **§5.8 wildlife pressure**: one midnight roll per apiary in summer and autumn, 200/10000 (100 behind a closed fence),
  taking min(2 U, the apiary's honey); an advisory, no injury.
- **§5.7** honey: 1200 NP, raw-edible, 1440 h (already the pantry's item 25, decision 0603); wax a material at 250 g.
- **Decision 0222** (room first) for the honey's carry; **decision 0671 P6** (inputs taken when the work is done) for a
  recolonisation; the orchard's job machinery (decisions 0671–0674) unchanged.
- **art_pass3_mapping.md "Hives"**: one `bee_swarm.gd` per occupied skep, `set_active(false)` in winter, the clock's
  speed, reduced motion.

### What is built

- `demo/hives/hive_rules.gd` (numbers and geometry), `apiary_model.gd` (the hive's day, collection, feed, recolonising,
  the wildlife roll, the pollination join and the books), `hive_text.gd` (refusals, readout, the guide's honey),
  `apiary_view.gd` (the skep through `make_piece`; the swarm).
- `orchard/`: `K_SERVICE`, `K_FEED`, `K_RECOLONIZE` in `orchard_rules.gd`, `orchard_jobs.gd` (programs, places, work,
  refusals, outcomes, the routine), `orchard_text.gd`, `orchard_cards.gd` (`SEL_APIARY`: its readout, verbs and cards),
  `orchard_panel.gd` (three buttons), `demo_orchard.gd` (the click, the obstacle, the view, the news, `bind_farm`);
  `orchard_model.gd` owns the apiary and closes its day after the trees'.
- **The books** (`apiary_model.gd`): honey made = honey in the hive + released + put by from the hive + lost; feed put
  by (from the hive and the pantry) = feed in the hive + eaten; wax made = wax in the hive + on the shelf. Tested over a
  whole year.

### Shared files touched (each a narrow, additive hook)

| File | Hook |
|---|---|
| `godot/demo/demo_village.gd` | one line in `_build_orchard`: `_orchard.bind_farm(_farm.sim, _kitchen.kitchen.takes)` |
| `godot/demo/farm/farm_sim.gd` | `pollinate` Callable and `pollination_of(bed)`; `harvest` and `expected_yield_into` use it (neutral without it) |
| `godot/demo/kitchen/dish_book.gd` | `honey` struck from `PENDING_SOURCES` |
| `godot/demo/world/world_sizes.gd` | `bee_skep` height (0.75 m, DEC-048) and bound (from `food_art_mapping.json`) |
| `godot/demo/guide/field_guide.gd` | honey's entry (`_hive_goods`) |

No work-board source and no pantry item is added, so nothing in `work_ids.gd` or `farm_catalog.gd` is renumbered. No
key is added. Nothing under `scripts/core/`, `demo/burrow/`, `demo/tunnel/`, `demo/cast/` or the settlement UI is
edited (the parallel digging lane's files).

## PROPOSALS (for Brendan; each built so a different ruling is a small change)

1. **The apiary stands from the start** (open question Q-D4, recommendation (a), as the Cellar building was, 0612 P1):
   one skep on tiles 57..59 × 73..75, between the field's north fence and the old orchard (clear of the stump and the herb bank), an inherited hive at 8000. So the GDD's Apiary cost (wood
   12 + rope 2, 180 WU, unlock M2) is not charged, and Q-D3's rope does not bite here. *Options:* (a) as built; (b) also
   let the player build a second apiary once Q-D3 settles rope; (c) the player builds the only one. *Recommendation:
   (a), with (b) after Q-D3.*
2. **Where it stands**: within 12 m of both old trees (10.3 m and 9.5 m) and of the four northern field beds, so beans
   sown there are pollinated; the cabbage beds (12.2 m) and the east orchard are out of reach -- the readout shows the
   difference. *Options:* (a) as built; (b) nearer the east orchard. *Recommendation: (a).*
3. **The winter feed first** (ECO-012): a collection fills the hive's feed to a whole winter's 6 U (12 days × 0.5 U)
   before any honey leaves it; in winter it covers the days left. *Options:* (a) as built; (b) a smaller reserve with
   the pantry's honey as the back-up. *Recommendation: (a).*
4. **Honey goes to the old orchard's baskets** and is hauled on with the fruit (decision 0674's gathering point).
   *Recommendation: confirm.*
5. **A winter feeding**: when the hive's feed will not last the winter, a keeper walks to the skep and the shortfall is
   drawn from the pantry's free honey when the feeding is done (no carry is drawn) -- a handling's 1 WU, since §5.6 says
   winter "needs feed but no tending labor". *Options:* (a) as built; (b) no feeding (the bees live or die on their own
   store). *Recommendation: (a).*
6. **Wax waits on the apiary's shelf** (40 U) because the village stores (`demo/tunnel/tunnel_stores.gd`) belong to the
   active digging lane; candles (`wax_candle`: wax 1 + flax 0.25 → 4) wait on FLAX. *Recommendation: the follow-ups
   below.*
7. **Recolonisation** starts only when its 3-day wait ends in spring, and takes its honey (all or none) and wood when
   the 60 WU are done (0671 P6). *Recommendation: confirm.*
8. **The wildlife roll's draw**: the demo has no ECOLOGY RNG stream (`scripts/core/ecology.gd` takes no draw), so the
   roll is a seeded hash, `rng.gd hash_pair(day, 1601 + apiary) mod 10000 < 200`, made for the day just ended when that
   day was in summer or autumn; a hit on an empty hive still says so. *Options:* (a) as built; (b) wait for the
   settlement's ECOLOGY stream. *Recommendation: (a) for the demo.*

## Follow-ups (not built here, and why)

- **Wax into the village stores**: add `wax_milli_u` to `godot/demo/tunnel/tunnel_stores.gd` (the digging lane's file)
  and move `apiary_model.gd wax_shelf_milli` there; `take_wax` is the hook.
- **Candles** (`wax_candle`, REQ-SET-148's light): after FLAX lands flax as a material.
- **A built apiary** (P1 (b)): after Q-D3.

## Gates

Filled in by the branch's gate record (the end of this lane): the focused suites, the analyzer, the CI-style suite,
the live harness at both sizes and its frames, the mutation run and the independent review.

## Source

GDD §4.2 (Hive), §5.6 (hive rows, REQ-SET-082/083), §5.7 (honey, wax), §5.8 (wildlife pressure), §5.9 (Apiary);
review group Y ECO-011/012 (decision 0493); decisions 0222, 0603, 0671–0674, 0941, 0971; `art_pass3_mapping.md`;
`docs/handoff/BACKLOG.md` HIVES; open questions Q-D3, Q-D4.
