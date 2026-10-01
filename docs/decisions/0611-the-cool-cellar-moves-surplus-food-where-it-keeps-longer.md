# 0611 — The cool cellar: surplus food is moved to where it keeps longer
Date: 2026-10-01 · Status: Accepted (demo feature #30, approved by Brendan 2026-10-01). P1–P6 ruled as built; P7 ruled
"Build both cellars" (decision 0612).

Numbered 0611 because the brief assigned 0611–0619. No record with those numbers exists on any branch
(`git log --all`) or in any sibling worktree.

## Decision

The demo already had the room. Decisions 0209 and 0210 built the root cellar:
- a 3 x 4 m stone-lined vault, 24 quanta, entered by a hatch;
- its capacity comes from its racks (a shelf holds 20 U, a pantry rack 30 U, a root bin 25 U, hanging stores 10 U);
- the cool rule: §5.8's cellar factor (350 per mille) while the cellar is 1 m or more down, racked, and no hearth
  warms it. Otherwise it is the pantry's 750;
- harvests are delivered to the slowest-ageing store with room.

None of that changes. **What was missing was a reason to dig one after the harvest was in.** Food already stored in
the covered store stayed there and aged at 1000. This record adds four things:

1. **Every food store declares its §5.8 storage class and why** (`farm_storage.gd` STORAGE CLASS).
   - A provider entry may carry `storage_class` (StockAge `STORAGE_*`), `spoilage_permille`, or both.
   - The class alone takes its factor. The permille alone names the class whose factor it is: UNDECLARED when none
     matches, and the store still ages at its own rate.
   - Both together must agree, or the entry is refused.
   - `why` is the store's own words for how it keeps food. Without them, the class's words are used.
   - A cool root cellar is CELLAR and gives the cool rule's words. A warm one is PANTRY: "warm: a hearth within 3 m of
     it warms it".
2. **A lot can change stores without being re-made** (`farm_pantry.gd` MOVING FOOD BETWEEN STORES).
   - `begin_carry_into` takes the whole lot, or an exact split into a new row with the same age and remainder.
   - A carried lot stays booked at its source until `set_down_into` puts what fits into the store its hold
     (`reserve_at_into`) reserved.
   - Nobody else may take from it on the way. `withdraw_into` refuses it, deliveries never merge into it, and the
     kitchen counts none of it free.
   - `put_back` ends a carry anywhere else.
   - The ledger (decision 0451) never moves.
3. **Surplus food is hauled to a store where it keeps longer** (`demo/stores/cellar_haul.gd`, `demo_stores.gd`).
   - Every 2 s of cast time the planner picks the unreserved lot that spoils soonest where it is.
   - It sends that lot to the slowest-ageing store with room, the nearer one on a tie.
   - Each move takes at most one small carry, and at most 4 moves stand at once.
   - The moves are on the work board as HAULING: a new source, `SOURCE_STORES` = 8, "Food stores"
     (`work/stores_work.gd`). The board claims them for idle carriers (decision 0411).
   - The claim reserves the room. The carrier then goes to the store, picks the food up (1 WU), carries it, and
     shelves it (1 WU). It carries the food down to the cellar's middle when it can take a load below (farm_cellars.gd
     CARRIED IN); otherwise it leaves it at the hatch.
   - A carrier called away puts the load back, and the move waits again.
   - A move that cannot be made gives up and backs off **the store that failed it** for 60 s: three failed walks, a
     pick-up the pantry refuses, or a shelving with no room. A failure at the lot's store backs off that store as a
     source; a failure at the cellar backs it off as a destination.
   - A part of a lot is never smaller than 1 U (`MIN_PART_MILLI`). A whole lot of any size may move.
   - With all 128 lot rows taken, only whole lots move, because a split would be refused. The independent review
     found that otherwise the same move was claimed and refused for ever (147 claims, 0 moves in 300 s).
   - A claim or pick-up whose destination no longer keeps the food longer (a hearth lit near the cellar) closes the
     move.
   - A waiting move whose lot or destination has gone is closed at the next plan, so it no longer holds room.
   - One pass over the lots per plan, with each lot's surplus asked once.
4. **The Pantry says where each lot is and why it lasts longer** (`farm_pantry_rows.gd`).
   - The Stocks rows already gave each lot's store and its days to spoil.
   - Under the stores table, `why_text` adds a heading and one line a store, for example: "Root cellar 1 — cool: deep,
     racked and away from any hearth: food keeps 2.8× as long as in the covered store" (`farm_text.gd keeps_text`,
     floored to the tenth).
   - A row with food in hand says "· 5.0 U being moved to a cooler store".

The rules used:
- GDD §5.8: the four store factors; "Changing stores never resets age".
- REQ-SET-107: no freshness reset on transport.
- REQ-SET-111: carried mass limited by species capacity; quantity split exactly without cloning lots.
- REQ-SET-112: output room reserved before the work starts.
- GDD §5.2: the 12000 g small carry (`meal_rules.gd CARRY_G`).
- GDD §5.5: raw food weighs 250 g a unit.
- Decision 0222: nothing credited from afar.
- Decision 0361: arriving is explicit.

## Why

- **A move, not a delivery.** A new delivery would open a fresh lot at age 0. That would make food fresher by moving
  it, which is exactly what §5.8 and REQ-SET-107 forbid. So the lot itself changes stores, with its age.
- **Booked at its source until shelved.** This is the same conservation the spoil crew (decision 0361) and the
  kitchen's takes (0381) keep: the books move only where the work happens. The alternative was an "in transit" store
  index. It would have to be taught to every reader of `lot_location` (the Pantry, the kitchen, the fishery). A carried
  flag on the row needs one guard each in `withdraw_into` and `free_milli`.
- **A work-board source, not a farm job kind.** The farm crew's board (`farm_jobs.gd`) is about beds. A move has no
  bed and two stores. It is also the model #18 (preserving) and #33 (hauling and stockpile zones) will build on.
- **General, not cellar-only.** The rule is "a store that ages it more slowly, with room", not "a cellar".
  - The covered store's food therefore also restocks the kitchen pantry (750) when the kitchen has made room.
  - A future ground pile (OPEN_PILE, 1500, the demolition ruling's piles) is hauled from without new code.

## Brendan's rulings (2026-10-01, relayed by the coordinator)

- **P1–P6 are approved as built.** Surplus is any food nobody has reserved. The soonest-spoiling lot moves first, but
  not one with under 6 hours left. Any store that ages food more slowly is a destination. Food in hand ages at its
  source's rate. A move takes one small carry (48 U). Planning runs every 2 s, with 4 moves at once and a 60 s back-off.
- **P7: "Build both cellars."** The dug root cellar stays as it is. The GDD's Cellar building is added alongside it:
  decision 0612.

The proposals as they were put follow, kept as the record of what was weighed.

## Proposals for Brendan (the documents are silent; the smallest demo behaviour was built)

- **P1. What "surplus" is.**
  - Built (a): food nobody has reserved. The kitchen's takes stay where they are, and nothing else is kept back.
  - Option (b): keep a minimum per item in the kitchen pantry (REQ-SET-117's store minimums, not built).
  - **Recommend (a)** until store filters exist.
- **P2. Which food first.**
  - Built (a): the lot that spoils soonest where it is, except food with under 6 game hours left (`MIN_HOURS_LEFT`, not
    worth the walk).
  - Option (b): the move that saves the most hours first.
  - Option (c): no minimum.
  - **Recommend (a)**: it saves the food most at risk, the way REQ-SET-109 picks first-expiring-first-out.
- **P3. Which stores are destinations.**
  - Built (a): any store that ages the food more slowly. This includes covered store → kitchen pantry.
  - Option (b): cellars only.
  - **Recommend (a)**: it is the rule harvests already follow.
- **P4. Food in hand.**
  - Built (a): it ages at its source's rate until shelved, and a carrier called away puts it back from where it
    stands, as the spoil crew does.
  - The GDD names no factor for food being carried. `stock_age.gd` records the same gap for equipped lots.
  - Option (b): age it at the open-pile 1500 while in hand.
  - **Recommend (a)**: carries take minutes, so the two options barely differ.
- **P5. Load size.**
  - Built (a): 48 U, the smallest carry, whoever takes the move.
  - Option (b): size the load at the claim from the carrier's own class (64 U medium, 96 U large).
  - **Recommend (a)** for the demo. Option (b) needs a re-plan at claim time.
- **P6. Cadence.** 2 s planning, 4 moves at once, a 60 s back-off. These are demo values.
- **P7. The room's size and capacity.**
  - The GDD's Cellar is a 6×6 surface building: wood 20, stone 60, 900 WU, 1,000,000 g (about 4000 U of raw food),
    unlocked at M1.
  - The demo's root cellar is 0209/0210's 3 x 4 m room. Racked out it holds 105 U.
  - Neither the brief nor this record changes it. **Question:** should the racks hold more, or the room be bigger, to
    approach the GDD's figure?
  - **Recommend keeping the demo figures** until the settlement's own cellar building is built.

## Consequences

- Shared files touched, all additive:
  - `farm_storage.gd`: class, why, `class_and_permille_of`.
  - `farm_pantry.gd`: the carry operations and the carried flag.
  - `farm_cellars.gd`: class and why.
  - `farm_text.gd`: `keeps_text`.
  - `farm_pantry_rows.gd`, `farm_pantry_panel.gd`: the why note and the moving text.
  - `kitchen/ingredient_takes.gd`: a carried lot is never free. A reservation on a carried row is trimmed to nothing
    before a batch, and a refused withdrawal is never counted as food taken. Today the haul never carries reserved
    food, so this only guards against a later caller doing so.
  - `farm_pantry.gd` `MAX_HOLDS` rises from 32 to 52: the farm's 24 job rows, the fishery's 24 and the haul's 4 can
    each hold room at once.
  - `work/work_ids.gd`: `SOURCE_STORES` = 8, `SOURCE_COUNT` 9, `SOURCE_WALK` 9.
  - `work/demo_work.gd`: `add_stores`.
  - `demo_village.gd`: `_build_stores`.
- **The work-board source number may collide.** `SOURCE_STORES` takes the next number in sequence (8, after
  `SOURCE_FISHERY` = 7), and `SOURCE_COUNT` and `SOURCE_WALK` become 9. Another branch adding a source at the same
  time will also have claimed 8. Whoever merges second renumbers its own source to the next free number, keeps the
  sequence unbroken, moves `SOURCE_COUNT` and `SOURCE_WALK` up to match, and appends its name to `SOURCE_NAMES` in the
  same order. `test_demo_fishery.gd` and `test_demo_cellar.gd` both check that `SOURCE_WALK == SOURCE_COUNT`.
- No key was added.
- A later food store (#18 preserving, #33 stockpile zones) declares `storage_class` and `why` in its provider entry. It
  is then hauled from or to by this rule without new code. A ground pile should say `STORAGE_OPEN_PILE`.
- A new reader of lots must respect `lot_carried`: a carried lot is booked where it was, but it is in hand.

## Source

- GDD §5.2, §5.5, §5.8 (REQ-SET-107–112), §5.9.
- Decisions 0209, 0210, 0222, 0361, 0381, 0411, 0451.
- Brendan's approval of feature #30, 2026-10-01.

## Verification

- `test_demo_cellar.gd` has 40 tests, 819 assertions.
- Mutation testing: 48 mutants, 46 killed. The 2 survivors are equivalent:
  - `class_of_permille`'s `> UNDECLARED` versus `>=`: `find` never returns index 0 for a permille of at least 1.
  - The kitchen's refused-withdrawal guard: it cannot be reached after the trim.
- An independent review found two HIGH issues, both fixed:
  - the endless claim and refusal loop on a full lot table;
  - kitchen and arrival guards that no test covered.
  Its MEDIUM findings M1–M4 are also fixed and tested.
