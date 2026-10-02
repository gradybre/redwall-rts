# 0612 — The Cellar building stands beside the dug root cellar
Date: 2026-10-01 · Status: Accepted (Brendan's ruling on 0611 P7: "Build both cellars"). P1–P4 ruled as built,
2026-10-01.

Numbered 0612, from feature #30's range 0611–0619. No record with this number exists on any branch (`git log --all`) or
in any sibling worktree.

## Decision

The demo now has **two kinds of cellar**.

- **The dug root cellar** is decisions 0209/0210/0611's, unchanged.
- **The GDD's Cellar building** is new, in `godot/demo/stores/`:
  - `cellar_rules.gd`: every number;
  - `cellar_projects.gd`: the cellars;
  - `cellar_builders.gd`: who builds them;
  - `cellar_place.gd`: placing one;
  - `cellar_view.gd`: the look;
  - `cellar_bar.gd`: the Pantry's line and buttons.

1. **The figures are read from the settlement's own tables, never restated.**
   - Source: GDD §5.9 line 639, `gameplay_balance.md` §4.1 line 205 and §4.2 line 240. These are compiled in
     `scripts/core/building_definitions.gd` and `construction.gd BUILD_MATERIALS`.
   - Re-verified on all three sources: footprint 6 × 6 tiles; wood 20 and stone 60; 900 WU; 2 operational slots
     ("Hauler 2"); unlock M1; base store 1,000,000 g; at most 4 builders.
   - `test_demo_cellar_building.gd` asserts each one against the tables.
2. **Capacity in U** is 1,000,000 g / 500 g a unit = **2000 U**.
   - 500 g/U is GDD line 885's figure: the winter stock fixture's "At 500g/U ... 5 cellars of 1,000,000g each". That is
     the GDD's own reading of a cellar's capacity.
   - Re-verified: line 511 weighs **raw** food at 250 g a unit, and prepared meals and rations at 500 g. See P2.
3. **It registers as an ordinary cellar store.**
   - It uses farm_storage.gd's provider API (decision 0611): `storage_class` CELLAR (350 per mille), 2000 U, delivered
     to at its door.
   - It is labelled "Cellar N", and its why is "a large store above ground".
   - The haul (0611), the Pantry's rows and the why note treat it with **no special case**. The why line reads: "Cellar
     1 — a large store above ground: food keeps 2.8× as long as in the covered store".
4. **Placing it.**
   - The demo had no building tool to reuse. The HUD's Build command is locked, and its key opens the Dig tool
     (decision 0208).
   - The Pantry's Stocks tab therefore gains a "Cellar buildings" line, with **Build a cellar…**. Pressing it closes
     the Pantry and arms a placing tool built on the woods' zone-tool pattern.
   - A ghost of the cellar follows the pointer, facing the square: brass where it may stand, clay with the reason where
     it may not.
   - A left click places it; Esc or a right click puts the tool away. **No key is added.**
   - Where it may stand uses the room tool's site, taken again only when its key changes. It adds the tunnels and dug
     rooms (their segments) and the other cellar.
   - Its door and its material site must also be standable: inside the village and clear of obstacles and the water.
   - At most two cellars stand at once.
5. **Building it** follows REQ-SET-124/125/126 and matches the hall's flow (decision 0771) without depending on it.
   - Placing it deducts nothing.
   - Each cellar has 4 places (§5.9's maximum builders). They are listed on the work board's **"Food stores"** source,
     after the moves, so no new source number is taken. The board claims them for idle residents who can carry.
   - A builder walks to the open stockpile and reserves one material as it sets off. It lifts the material there; only
     then is it taken from the stores. A load is the carrier's §5.2 carry at §5.5's 5000 g a unit: 2.4, 3.2 or 4.8 U.
     The builder carries it to the site and sets it down, which delivers it.
   - What is reserved, in transit and delivered all count against what the cellar still needs, so nothing is fetched
     twice. Only a cellar still taking deliveries may be lifted for or delivered to. The independent review found the
     first build consuming 24 wood and 62.4 stone; a test with surplus stores now checks the exact cost.
   - A place keeps its work-board key, the cellar's generation plus the slot, through claims and nights. The player's
     priority and URGENT therefore stay with it, as with bridges.
   - Once everything is delivered, the builders build. Their demo time adds up, with a WU being decision 0210's 0.15 s
     of one builder's time (the hall's ruled P6).
   - A builder called away puts its load back into the stores whole, and its place waits again.
   - The Pantry's **Cancel** first lets the builders go, then returns what was delivered: all of it before work begins,
     80% floored after.
   - Every milli-U is always in the stores, in a carrier's arms, or at the site, until it is built in. A test checks
     this on every frame.
6. **The look uses existing library models only**; nothing new is staged and nothing is paid for.
   - The building is the library's `cellar` model, a stone-fronted door in a turfed mound. It was already staged and
     sized by `demo_props.gd BUILDINGS` at its 2.0 m envelope.
   - Placed, it is pressed flat as the marked footprint. Being built, it rises with the work. Built, it stands whole.
   - A plank stack and a heap of tunnel rubble at its site grow with the wood and stone delivered.
   - Its name and percent hang over it.
   - From the moment it is placed, its footprint is an obstacle: `cast_space.gd set_structure`, a new additive slot of
     4 circles.

## Brendan's rulings (2026-10-01, relayed by the coordinator)

**P1–P4 are approved as built:**
- **P1:** the Cellar building is available from the start (`UNLOCK_START`).
- **P2:** 500 g a unit, so a cellar holds 2000 U.
- **P3:** no staffing; any idle carrier hauls into and out of it.
- **P4:** the library cellar model at its lookdev size.

The proposals as they were put follow, kept as the record of what was weighed.

## Proposals for Brendan (now ruled)

- **P1. When it unlocks.** The rule is one data constant, `cellar_rules.gd UNLOCK`. The GDD's M1 needs day ≥ 4, at least
  12 residents and 200 portions, and the demo's nine residents can never reach it.
  - (a) Available from the start. This is built and **recommended**: the demo's cellars should be playable in one
    sitting, and the dug root cellar is available from the start too.
  - (b) M1 with the resident count scaled to the cast: day 4, all nine residents, 200 portions.
  - (c) 200 portions cooked plus day 4.
  - Options (b) and (c) are implemented and tested; changing the constant is all it takes. Portions are counted by the
    kitchen's `portions_eaten`, the nearest existing count, which is conservative.
  - The demo's cast never changes (no deaths, no immigration), so in the demo (b)'s resident clause always holds and
    (b) behaves exactly like (c).
- **P2. Grams per U.**
  - (a) 500 g, giving 2000 U, as built. This follows the GDD's own cellar arithmetic (line 885).
  - (b) 250 g, the raw-food mass of what the demo's stores actually hold, giving 4000 U.
  - **Recommend (a)**, the GDD's own reading.
- **P3. "Hauler 2".** The demo has no job slots: the job matrix, UI-SET-070, is not built.
  - (a) As built: no staffing. Any idle carrier the board picks runs the moves into and out of a cellar building, as for
    every other store.
  - (b) Two residents named as the cellar's haulers, whose crew gets first claim on its moves.
  - **Recommend (a)** until job slots exist.
- **P4. The look and size.**
  - (a) As built: the library cellar model at its 2.0 m lookdev envelope (about 4.1 × 4.5 m). Demo buildings are drawn at
    their envelopes (decision 0082), not at the GDD's 2 m-tile footprints (6 × 6 tiles is 12 × 12 m).
  - (b) Scale it up toward the footprint.
  - **Recommend (a)**: the covered store is drawn the same way.
  - Tunnels: a cellar can never be placed over an existing tunnel. A tunnel or room laid afterwards keeps clear of it,
    because `tunnel_control.gd _refresh_clearances` now adds the placed structures to the buildings it may not pass
    under.
  - Known limit: the tunnel extension's own copies of that list, used for re-routing, widening and nooks, are still
    the world's buildings only. They are fixed when the world is built and belong to the tunnel owner.

## Consequences

- Shared files touched (additive):
  - `cast/cast_space.gd`: `set_structure`, `structure_circles`, `STRUCTURES`;
  - `tunnel/tunnel_control.gd`: `_refresh_clearances` adds `structure_circles` to the buildings a tunnel may not pass
    under;
  - `farm/farm_pantry_panel.gd`: `add_store_control`;
  - `work/stores_work.gd` and `work/demo_work.gd`: the places after the moves;
  - `demo_village.gd`: `_build_cellar_buildings`, `_cellar_unlock_facts`, the stores' doing text.
- `stores/stand_spot.gd` now holds the one stand-spot search that the haul and the builders share.
- Preserving (#18) and stockpile zones (#33) can add stores the same way: one provider entry with a class and a why.

## Source

- GDD §5.2, §5.5 (line 511), §5.8 (line 885), §5.9 (line 639), §5.11; REQ-SET-124/125/126.
- `gameplay_balance.md` §4.1 (line 205) and §4.2 (line 240).
- Decisions 0082, 0208, 0210, 0611, 0771.
- Brendan's ruling, 2026-10-01.

## Verification

- `test_demo_cellar_building.gd` has 33 tests, 237 assertions.
- Mutation testing: 54 mutants, 52 killed. The 2 survivors are equivalent:
  - `percent`'s cap of 99: the sum cannot reach 100 before the cellar is built.
  - The put-down's refused-delivery branch: no load can be in transit once delivery is complete, because in transit
    counts toward the cost.
- An independent review found three HIGH issues, all fixed and now tested:
  - over-fetching;
  - a per-frame conservation assertion that could not fail;
  - a board key that changed on every claim.
  Its MEDIUM findings M1–M4 and M6 are fixed; M5 is the tunnel change above.
