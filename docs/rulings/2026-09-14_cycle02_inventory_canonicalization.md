# INV-CANON-R01 — canonical inventory payloads without changing retirement

2026-09-14 · Adopted engineering target; implementation and save parity pending.

<a id="retired-row-blanking"></a>
## Answer to #retired-row-blanking

**Keep the current transaction/retirement algorithm. Normalize inactive payloads
in the caller-owned save/hash copy at a completed, quiescent boundary. Persist
every physical row's occupancy and generation, and preserve the exact used free
stack prefixes. Do not omit inactive rows or sort the free stacks.**

Owners: ARCH-HASH-001, ARCH-SAVE-002/003/005, REG-R01, SAVE-LAYOUT-R01's canonical
unused-value rule, PROV-R01, and GDD §4.2 inventory identity/quantity contracts.
This completes the inventory-specific unused-value table those contracts require.

## Verified reason

`inventory.gd` is identical in this working folder and merged PR 116
(`127c8e4ce14ef7acab0b2b608abb8b6b92935928`). The merged §7 implementation is
`save_section_inventories.gd`, not the speculative `save_section_07.gd` path.

`_retire_lot()` unlinks, clears occupancy and advances the local generation.
It leaves attributes behind. `_apply_transfer()` then calls `_credit_new_lot()`,
which reads the retired source's item, quality, provenance and recipe; at capacity
one it can reuse that same physical slot. Clearing the source in `_retire_lot()`
would change correct behavior, not merely add write cost.

`_apply_merge()` transfers reserved quantity to the destination but leaves that
number in the inactive source. A focused public-operation probe reproduced a
dead source with quantity 0 and reserved 250 alongside a live destination with
reserved 250. The inventory's live audit passes. The current §7 codec validates
`reserved <= quantity` on every raw row and would reject that unnormalized copy.
This is not evidence of two live claims: occupancy is decisive, and external
claim bindings still require their own cross-store validation.

Raw `state_bytes()` remains a full rollback/debug image, deliberately including
stale payload. It is **not** the canonical save representation. Failed
transactions must still restore raw bytes exactly; do not weaken rollback tests
to compare only canonical digests.

## Exact inventory target

Keep all 30 existing inventory field keys, ordinals, types and array extents.
Container columns cover the declared container capacity; lot columns cover the
declared lot capacity. Production maxima remain 101376 containers / 16384 lots;
smaller isolated fixtures are not alternative shipping capacities.

For a row whose `_c_live` or `_l_live` is **1**, copy its payload exactly and
validate its existing domains and cross-owner references. A live equipped lot
with null container is still live, with real quantity, provenance, durability
binding and owner attestation. Never apply the inactive mask based on container
nullness, quantity, visibility, reachability or membership in a render list.

For a row whose occupancy is **0**, emit these exact unused payloads:

| Container field | Value |
|---|---:|
| `_c_owner_slot` | -1 |
| `_c_owner_generation` | 0 |
| `_c_policy` | 0 (`UNSET_POLICY`) |
| `_c_lot_count` | 0 |
| `_c_first_lot` | -1 |
| `_c_max_mass_g` | 0 |
| `_c_filters` | 0 |
| `_c_reserved_mass_g` | 0 |
| `_c_used_mass_g` | 0 |
| `_c_reachable` | 0 |

| Lot field | Value |
|---|---:|
| `_l_item_id` | 0 |
| `_l_quality` | 0 |
| `_l_provenance` | 0 (`ORDINARY`, not an unknown provenance) |
| `_l_recipe_id` | 0 |
| `_l_container_slot` | -1 |
| `_l_container_generation` | 0 |
| `_l_next` | -1 |
| `_l_prev` | -1 |
| `_l_quantity_milli` | 0 |
| `_l_reserved_milli` | 0 |
| `_l_age_milli_hours` | 0 |
| `_l_age_remainder` | 0 |

Occupancy remains 0; **the row's own `_c_generation` / `_l_generation` is copied
unchanged, not zeroed**. There is no new inventory retirement flag. Keep
`_c_free_count` / `_l_free_count` and the respective first `count` stack entries
in saved order. Tail bytes are excluded from the saved/canonical field count;
restore their backing-array tail to -1. Do not pad that logical prefix into a
full-capacity canonical record.

The table uses the existing clear-state sentinels. Applying them to the
boundary copy is the new engineering choice; this authorizes no new item,
quantity, gameplay policy or allocator capacity.

## Generation and partition validation

Validate occupancy as exactly 0/1, counts within capacities, unique in-range
free-prefix slots, no occupied slot on a free prefix, and complete partition:
every inactive slot outside the prefix must have generation INT32_MAX and is
retired. Every instantiated inventory generation is in 1..INT32_MAX; initialization
calls `clear()` and starts at 1. The target rejects zero-generation fixtures
that previously passed the codec's looser inactive-row check; a future virgin
zero-generation scheme would need an explicit allocator contract.

**INT32_MAX alone does not mean retired.** Freeing generation INT32_MAX-1
increments to INT32_MAX and pushes that slot, allowing its final valid allocation.
An inactive INT32_MAX slot *on* the prefix remains available; an inactive
INT32_MAX slot *off* the prefix is retired. A live INT32_MAX row remains live.
Persist these distinctions. Do not rebuild a stack by filtering out all MAX rows
or call `clear()` on restore (it advances generations and changes the pool).

Directory, container, lot and navigation generation spaces remain separate.
Validate each live reference in its actual namespace. A live claim pointing to
a dead/reused lot, a live container chain visiting a dead row, or a stale owner
is a refusal; masking the dead row never repairs the referring live state.

## Copy, decode and publication

1. At the established completed save boundary, require no open inventory
   transaction, no active attestation/reentrant mutation, and a stable composed
   snapshot. Reject rather than capture midway through a transfer. Restore/load
   barriers remain owned by the existing loader.
2. Validate source occupancy, generations, allocator partitions and all live
   structural/accounting relationships. Stale inactive payload is not treated
   as live ownership, a live reservation, or a current item-domain claim.
3. Copy exact live fields and masked inactive fields into bounded caller-owned
   buffers. Never normalize in place or return a writeable view of live arrays.
   Fill normalized output directly; do not allocate a second full normalized
   world or per-row object. Count scratch/live/save peaks in the ledger.
4. Drive §7 encoding and the inventory canonical adapter from this **same
   declared projection**, with identical field counts and values. A projection
   helper may serve both; they must not implement competing masks.
5. Decoding is stricter than trusted source copying: under the new schema, a
   noncanonical unused byte is refused, even if it could be replaced by a safe
   value. An incoming inactive provenance 6 does not become ORDINARY. A live
   invalid provenance is always refused. Apply exact sentinels only when
   capturing legitimate inactive source payload or rebuilding excluded tails.
6. Validate all decoded cross-owner references before publishing. Restore the
   normalized payload and exact occupancy/generations/free-prefix order without
   gameplay allocation, destruction, `clear()`, or generation increments.
   Rebuild derived counts/high-water scan bounds and rebind equipment/seed
   authorities using their existing contracts. Debug conservation tallies are
   not silently promoted into new saved fields by this ruling.

## Version and integration boundary

Adopt `(section 7, inventory)` owner schema **3** and section 7 descriptor schema
**3** (both were 2 in the audited merged baseline). Other §7 owner versions stay
unchanged. Payload layout/order/counts are unchanged; the version bump declares
stricter normalization and valid-state semantics. Preserve the existing section
7 extent/primary-count/child-table framing. The registry and rules identities,
compiled tables, codec checks and fixtures change atomically with implementation.
Do not change the `RWL-STATE-1` grammar or add a new hash algorithm.

No old development save is reinterpreted as schema 3. Refuse it unless an explicit
migration validates the old state and writes the new representation. Expect
intentional hash/byte changes at activation; do not market those as optimization
parity. There are **zero added/removed canonical records in this scoped delta**.
Final global counts also depend on the missing Construction fields and Cycle 1's
S1 scratch correction; no stale global total is frozen here.

Keep this document and its fixture manifest separate from the active registry
until the executor implements them. `DIGEST-DETERMINISM` owns the inventory copy,
§7 codec and canonical adapter together, serialized with other inventory/registry
writers. Whole-world section 15 remains incomplete until all other adapters and
the registry reconcile.

## Required evidence

- Same live state, same generations, same stack prefixes, different inactive
  attributes/tails: identical normalized field bytes and digest; raw source
  bytes unchanged by capture. No claim that every different history must hash
  equally: meaningful allocator/history differences stay observable.
- Different generation, different free-stack order, MAX-free versus MAX-retired,
  live reachability, live quantity/provenance or live reserved quantity: canonical
  stream differs. Preserve counts and distinguish all physical slots.
- Reserved-source merge: normalized source reserved=0, destination reserved
  retained; current raw residue neither breaks capture nor creates a second
  claim. Cross-check actual reservation rows after real orchestrated merges.
- Full transfer with one lot slot: attributes and age survive; old ref fails,
  replacement uses the proper generation. This guards against a tempting
  hot-retirement clear. Existing rollback tests still compare raw bytes.
- Corrupt occupancy, zero/negative generation, duplicate/free-live prefix slot,
  unaccounted non-MAX slot, stale live reference and noncanonical inactive wire
  payload all refuse without publication. Cover true MAX final reuse explicitly.
- Save → load → save has identical normalized inventory bytes. Across independent
  processes, continue allocations, reservations, merging, transfer, destruction
  and aging from saved state and compare future behavior. Until composed loaders
  exist, label these end-to-end tests blocked instead of substituting a Python
  model for production acceptance.

This answers the planning question. It does not implement the adapter, establish
full save parity, change conservation semantics, or close any art/movement gate.
