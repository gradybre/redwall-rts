# 1022 — A satchel is made per haul, and the claim travels with the goods
Date: 2026-10-02 · Status: Accepted (slice H1 of task 06.4); proposals P1–P3 await Brendan

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

## Proposals for Brendan (the documents are silent)

- **P1 -- a death on a footprint.** A hauler standing on a standing building's footprint (inside
  the hall) is on a tile #9 never lets a pile sit on. Built: the drop starts from that building's
  refund origin (`refund_seeds_into()`: the hall's door, else the front-first ring). Options:
  (a) as built; (b) the nearest tile off the footprint by breadth-first search from the tile;
  (c) refuse and leave the goods in an ownerless satchel. **Recommend (a).**
- **P2 -- unloads do not merge.** The carried lot arrives as its own lot. Options: (a) as built,
  identity kept, one extra lot row per partial haul until something merges them; (b) merge on
  arrival with a compatible lot (`transfer()`), except gear lots, which needs a gear test the
  inventory does not have. **Recommend (a) now, (b) with H7's gear work.**
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

Filled in below the line once the gates have run.

## Source

Brendan's rulings of 2026-10-02 (decision 1021 R-H2, R-H2a, R-H2b); GDD §4.2 `Equipment.satchel`;
REQ-SET-111; BAL-SAFE-002, BAL-SAFE-016; INV-GOODS-R01; DEC-043 #9; DEMO-CONTAIN-R01 #3d;
ARCH-MEM-002; ARCH-STATE-001; decisions 0019, 0532, 0533.
