# 1022 — A satchel is made per haul, and the claim travels with the goods
Date: 2026-10-02 · Status: Accepted (slice H1 of task 06.4); P1–P3 ruled by Brendan 2026-10-02, all as recommended

## Decision

Slice H1 builds the haul's physical carry on Brendan's 2026-10-02 satchel ruling (option b, R-H2
in decision 1021) and its two derived rules (R-H2a death/departure drop, R-H2b re-post).

1. **The satchel door (`inventory.gd`).** `POLICY_SATCHEL = 2` is the container policy domain's
   second explicitly numbered member, beside decision 0532's `POLICY_GROUND_PILE = 1`, and is
   reserved to `create_satchel(owner, carry_g)`: owner-shaped, `carry_g > 0`, every category,
   **not reachable** (nothing but its owner's own haul plans against it), **unplaced**.
   `create_container()` refuses the policy, `set_container_anchor()` refuses a satchel
   (`SATCHEL_ANCHOR_FIXED`, DEMO-CONTAIN-R01 #3d), `destroy_satchel()` retires only an empty
   satchel, `audit()` and the canonical restore refuse a satchel on a tile, and
   `is_satchel()` reads it. `test_inventory_ground_piles.gd`'s "policy 2 is opaque" assertion
   now uses `POLICY_SATCHEL + 1`, **changed on purpose**: 2 is no longer opaque.
2. **The claim moves with the goods (`reservations.gd`).** Four doors, each ONE inventory
   transaction followed by the pool's row writes, refusing a caller's open transaction exactly as
   `claim_batch()` does:
   - `load_claim_into_new_satchel()` -- the LOAD: mints the satchel, unreserves the claimed
     quantity, moves it (a whole lot by `move_lot()`, keeping its identity; a part by
     `transfer()`, an exact split), re-reserves it on arrival, then re-keys the row
     HAUL_SOURCE → HAUL_DESTINATION with the same lease. A refusal anywhere -- an expired seed, a
     full lot store -- aborts, so **no satchel is left behind** and both stores are byte-identical;
   - `carry_claim()` -- the same into an existing container;
   - `deliver_claim()` -- the UNLOAD: unreserves, releases the destination headroom the haul held,
     moves, ends the row, and **destroys the satchel the move emptied, in the same transaction**;
   - `repurpose_claim()` -- re-keys a claim where it stands (a re-posted haul's load).
   A row the arriving lot's slot still lists under another generation (a caller's leak) aborts
   the transaction rather than writing a conflicting row.
3. **Existing goods move onto piles (`ground_piles.gd`).** `move_container_into_piles()` is #9's
   breadth-first walk and site rule applied to goods that already exist: each tile's pile is
   topped up by `move_lot()` or by `transfer()` of the part that fits; nothing is created or sunk.
   It refuses a claimed source. Its `preflight_container_into_piles()` twin asks about a claimed
   source **as if released**, by releasing inside its doomed transaction, so a haul can prove the
   walk while its claim still stands. `drop_seeds_into(tile)` gives the drop's start tiles.
4. **The carry composer (`haul_carry.gd`, new).** `load_payload()` re-proves REQ-SET-111 against
   the hauler's species carry limit, refuses a second satchel (BAL-SAFE-002 "one container in
   transit"), refuses goods in another resident's satchel, re-keys goods already in the hauler's
   own satchel, and binds `Equipment.satchel` only after the load committed.
   `unload_into_store()` delivers and unbinds; `unload_into_piles()` proves the walk, releases the
   claim, moves, and destroys the satchel; `drop_satchel()` -- called before a dying or departing
   resident's row is despawned -- proves the walk, releases every claim on the satchel's lots,
   moves the goods to piles, destroys the satchel and unbinds.

## Why

- **Minting inside the move's transaction** is what makes a refused load byte-identical; a
  separate mint would leave a destroyed row's generation advanced behind every refusal.
- **Whole lots move whole** so gear instances keyed to a lot (ARCH-STATE-001) survive a haul and
  a carried lot is never merged into a pantry lot under someone else's claim.
- **The pool cannot join an inventory transaction** (its rows are not journaled), so the two pile
  paths are release-then-move. The exact preflight makes the move after the release refuse only
  if the world changed between two lines; the unload still re-claims on that unreachable
  refusal, while a drop cannot (the claims belonged to a cancelled haul) and reports it.
- **A numbered policy, not a flag column:** decision 0532 set the pattern for a container whose
  identity carries rules; a new column would cost 101376 bytes for one bit the policy already has.

## Brendan's rulings on P1–P3, 2026-10-02

All three approved as recommended (relayed by the coordinator); no behaviour changed:
- **P1 → (a).** A death or departure drop on a standing footprint starts from that building's
  door or front ring (`refund_seeds_into()`).
- **P2 → (a) now, (b) in H7.** Carried lots keep their identity and do not merge on arrival
  until H7's gear work, which then merges compatible lots on arrival, gear lots excepted.
- **P3 → (a).** Satchels are unreachable for planning (`reachable = false`).

## Proposals as offered (the documents were silent)

- **P1 -- a death on a footprint.** A hauler standing on a standing building's footprint (inside
  the hall) is on a tile #9 never lets a pile sit on. Built: the drop starts from that building's
  refund origin (`refund_seeds_into()`: the hall's door, else the front-first ring). Options:
  (a) as built; (b) the nearest tile off the footprint by breadth-first search from the tile;
  (c) refuse and leave the goods in an ownerless satchel. **Recommend (a).**
- **P2 -- a whole carried lot does not merge.** A claim covering the whole lot moves the lot itself
  (`move_lot()`), so it arrives as its own lot; only a PART of a lot (a re-posted haul claiming
  less than the satchel holds) moves by `transfer()`, which merges on arrival. Options: (a) as
  built, identity kept, one extra lot row per partial load until something merges them; (b)
  merge on arrival whenever compatible, except gear lots, which needs a gear test the inventory
  does not have. **Recommend (a) now, (b) with H7's gear work.**
- **P3 -- satchels are not reachable.** Built: `reachable = false`, so no planner treats a
  satchel as a store. Options: (a) as built; (b) reachable, relying on `is_satchel()` exclusions
  everywhere. **Recommend (a).**

## Consequences

- H4 must call `drop_satchel()` before `residents.despawn()`. Nothing enforces the order yet:
  `despawn()` clears the `Equipment.satchel` pair silently, so a satchel left at despawn would be
  a live container owned by a dead resident, unreachable by any door here. H8's restore
  cross-check (every live satchel's owner is a present resident whose pair names it) is what
  will catch it; until then the order is H4's obligation.
- Saving needs nothing new: satchels and their lots are section 7 rows, claims are section 7
  rows, `Equipment.satchel` is section 4. H8 adds the cross-check that every live satchel's owner
  names it and nothing else.
- No packed column is added to an existing store; `haul_carry.gd` owns one 40-byte scratch row
  (ledgered with decision 1023's scratch).

## Evidence

- **Suite, CI-style** (no staged demo assets in this worktree, fresh `--editor --quit` import),
  on the merged tree before the review fixes: `8871 test(s), 599911 assertion(s), 0 failure(s)`;
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated;
  leaked at exit: 0 object(s), 0 resource(s)`. The rerun after the review fixes is quoted in the
  lane record.
- **New suites:** `test_haul_carry.gd`, `test_haul_planner.gd`, `test_reservations_carry.gd`,
  `test_ground_piles_move.gd` (77 tests; 106 with `test_inventory_ground_piles.gd`), on the shared
  fixture `test/fixtures/haul_world.gd`. Every refusal is checked byte-identical across
  Inventory, the pool and the resident equipment columns; every success re-runs both audits.
- **Mutation testing, 81 mutants** over `haul_carry.gd`, `haul_planner.gd`, `reservations.gd`,
  `ground_piles.gd` and `inventory.gd`, each run against the five focused suites: **75 killed**.
  The first pass's survivors were real gaps, closed by tests (a pair naming another resident's
  satchel, a re-post that minted a second satchel, an empty satchel's drop, a drop with nowhere to
  go, a claimed lot split by the preflight, a full component, a same-building store off its
  footprint, a covered front ring tile, a stale generation, the ground destination kind, an open
  transaction at admission) or by the review fixes. **Four mutated clauses were dead and were
  removed** (source-headroom release in the preflight, `candidate == source`, the ground-kind
  grams conditional, `if not built` before R2). **Two survivors are equivalent:**
  `_preflight_carry()`'s reserved-total check, which can fire only if the pool's invariant is
  already broken; and removing the pile unload's preflight, because its re-claim restores the
  pool's canonical image (`state_bytes()` excludes row indices by design).
- **Independent `code-reviewer`:** its own 41 mutants (36 killed) and the full suite. Two HIGH,
  both fixed: a cancel after an unload released another job's grams, and a store-destination job
  unloaded onto piles leaked its grams (now `complete_unload()` through the record, plus
  `audit()`). MEDIUM, all addressed: the preflight now refuses source headroom exactly as the move
  does; the second-claim rollback is tested and its "unreachable" wording corrected; R2's proof is
  tested with a full ring pile; the footprint mask costs its rectangle, not the map; these
  records' numbers and evidence. LOW, addressed: the repurpose lease is pinned, the massless
  branch is marked defensive, a pile with everything claimed is no standing source, the pile
  unload reports the claimed quantity. Not changed: one-satchel-per-owner is enforced in
  `haul_carry.gd`, not in Inventory's doors (H8's restore cross-check); no production caller
  exists until H4.
- **Analyzer:** `tools/gdscript_warnings.py` on all eleven changed `.gd` files: 0 warnings.
- **Contracts:** every "Specification contracts" step of `.github/workflows/tests.yml` passes.

## Source

Brendan's rulings of 2026-10-02 (decision 1021 R-H2, R-H2a, R-H2b); GDD §4.2 `Equipment.satchel`;
REQ-SET-111; BAL-SAFE-002, BAL-SAFE-016; INV-GOODS-R01; DEC-043 #9; DEMO-CONTAIN-R01 #3d;
ARCH-MEM-002; ARCH-STATE-001; decisions 0019, 0532, 0533.
