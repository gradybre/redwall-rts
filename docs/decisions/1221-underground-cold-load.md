# 1221 — Underground cold load: the owner codecs

Date: 2026-10-07 · Status: Accepted for the owner codecs, steps 1 to 3 (Brendan's decision: build cold load now). Step 4, the
section-6 body and a fresh-settlement load, is stopped for Brendan's choice; see the last section.
section-6 body and the settlement wiring are not built; see "Not done".

## Brendan's decision

> Build cold load now: a saved underground game must reload into a fresh Session exactly.

ADR 1218 saved the first entry's progress record. It noted that a load into a fresh Session also needs codecs for
Routes, WorldRoutes, Contacts, Delivery and the cold Budget, and a section-6 orchestrator. This record covers those
owner codecs, one owner per commit.

## Convention

Each owner gets a local, versioned, little-endian wire with a magic word and schema. This follows Locations (wire
schema 2) and SpaceOwner (`state_bytes`). A capture is taken only at a quiescent boundary: no candidate,
search, motion or callback may be open. A restore decodes into the owner's inactive bank and proves the image
against the owners already restored. Only then does it swap the image in. A refusal returns an exact code and
leaves the live state byte-identical. Derived indexes are never written; the restore rebuilds them.

Load order is SpaceOwner (which resets both geometry journals), Locations, Routes, then WorldRoutes.

## 1. Routes (`underground_routes.gd`, wire schema 1)

`capture_state_into(cold_token, out)` / `restore_state_bytes(cold_token, bytes)`. The image size is
`96 + 82E + 12V + 79872 + 16L` bytes (320,608 at E 1536, V 4096, L 4096). It is charged to the caller's cold lease.

- **Header:** magic `UGRT`, schema, the four capacities, the World ref, the graph revision, the edge and vertex
  counts and the last advanced tick. The last tick is saved so that a repeated tick still refuses after a load.
- **Edge bank:** every column of the live bank, all rows. On restore, each row is checked:
  - Lifecycle: an absent row carries the canonical empty payload, and a row is retired only at generation
    I32_MAX.
  - The present paths tile the vertex prefix exactly, and the tail is zero.
  - Each present span passes the same format proof as `stage_add`: authored ranges, live endpoints at its ends, a
    live FLOOR_DATUM section and its exact integer length.
  - Its revisions may be older than the restored owners, never newer. A stale span loads as stale, exactly as it
    was, and its next use re-proves it.
- **Actor bank:** resident, resident_long and links, all rows, which includes the ADR 1219 arrival-registered
  crew and the dispatch tails (head/tail queues). On restore:
  - An unregistered row must equal the allocator's blank row.
  - A registered row must be the live Resident of its own typed row. It must stand where its Transform says,
    which is checked by exact interpolation along the span when it is on one. Its source clock word must be
    canonical. Its motion fraction must be reduced. Its phase must agree with its span and queue.
  - Every owned link must lie on exactly its owner's single, terminated chain and name a live edge.
  - The actor's Job, tool and load tuple is **not** re-proved at load. A live run does not re-prove it at a tick
    boundary either; its next motion or admission does that.
- **Rebuilt, not written:** the free heaps are rebuilt in ascending order, which is a valid minimum heap.
  `frontier_heap_refusal` replays pops on whatever heap is live, so only the minimum order matters. The adjacency
  order (`_build_edge_order`) and the occupancy index (`refresh_occupancy`) are rebuilt as well.
- **Not saved:** `_next_token`, `_last_published_token` and `_path_serial`. These are session-local identities,
  and the restore sets the last published token to 0, as Locations and SpaceOwner do. Two caches are also left out
  because nothing reads them to make a decision: `_occupancy_bounds` and `_occupancy_profile`.

## 2. WorldRoutes: saved, not re-derived (ADR 1205's carry rule)

**Decision: the live route certificates are saved.** A certificate is the result of the last preparation's proof.
Some of that proof's inputs are not saved state at all:

- the live World exclusions (water, resources, Buildings), which have no revision;
- the installation context, which excuses a pending bearer for source profiles 2 and 6.

So recompiling certificates at load could produce masks that differ from the ones in the run that saved.
Recompiling also costs a full proof. ADR 1205 measured 36 edges at full proof and the proof was refused with
`WORLD_ROUTE_CHECK_CAPACITY`, so a full recompile at load can fail outright.

ADR 1205's rule is that if certificates are saved, the journal must be saved with them. **Both SpaceOwner journals
are therefore saved inside WorldRoutes' image:** the traversal journal (ADR 1205) and the full-view journal
(ADR 1207). With a reset floor, the first preparation after a load would recheck everything, and the recheck can
exceed the check budget the uninterrupted run never needed.

Wire schema 1 (`CERT_WIRE_BYTES` = 84,184 bytes):

- a header: magic `UGWR`, schema, edge capacity, mask bytes and the live catalog pin;
- the live bank's masks, generations, geometry and content columns, for all 1,536 rows;
- each journal: floor, count and view flag, then 64 sides oldest first, with a zero tail.

The ring restarts at slot 0; only the order of the sides is ever read.

A restore runs after Routes and requires:

- exactly one certificate per live edge, with that edge's generation, geometry revision and content revision;
- no mask bit past the content's profile count;
- all-zero rows elsewhere;
- a catalog pin that is current, or zero when there are no edges;
- both journals valid against the restored Space: floor at most revision + 1, sides in order between the floor and
  the revision, known roles, valid boxes and a zero tail.

The remembered reachability search is cleared (`_witness_work = 0`), as in a fresh World. A remembered witness and
a fresh search spend identical debt, so clearing it does not change the result.

The quiescence check treats the once-bound installation context (ADR 1105) as quiet when it holds no route token.
The first live run refused the capture because the check had required the context to be absent.

## 3. Connector Contacts: a retained scope is saved

The registry called Contacts category 3, with "no open observation across a frame/save boundary". **That is not
quite true.** `_pin_scope` keeps `_primary_job` and `_material_container` whenever the Placement and Project are
unchanged. Router's PRODUCTIVE `transition_refusal` then reads `_primary_job` in its crew proof (`_crew_leaf`), and
in practice that Job was pinned by a `worker_refusal` in an earlier tick. A fresh Contacts would refuse
`CONNECTOR_CONTACT_WORKER` where the uninterrupted run passes. `discard_transition` and `discard_phase` also act
only on an exactly matching retained scope, and they clear the cache.

So these twelve values are saved: `_placement`, `_project`, `_ordinal`, `_action`, `_valid`, `_phase_mode`,
`_primary_job`, `_material_container`, `_phase_site`, `_phase_operation`, `_phase_episode` and
`_phase_output_container`.

The wire is schema 1, magic `UWCP`, 74 bytes. It is captured only when no proof is in progress. On restore, the
handles are checked only for shape. Nothing reads them without re-proving them: `_job_row` checks the Job's
Directory, Jobs and Router binding, and the material leaves check Construction's binding and the storage endpoint.
Every other member is re-pinned by the next call.

## 4. Delivery writes nothing; the admitted haul is the Planner's (resolves decision 1023's UNRESOLVED row)

Delivery clears its whole synchronous packet after every operation (`_clear`). Its per-haul facts are:

- HaulPlanner's admission record (`_job_generation`, the destination store, `_dest_tile`, `_reserved_g`);
- the Reservation pool's claims;
- Inventory;
- the Job.

So **Delivery saves nothing.** `save_quiescence_refusal()` admits a save or load only when no operation, work-tick
window or pinned Job is open.

**The admission record is now saved by its owner.** It is section 6 owner `haul_planner`: schema 1, ordinals 0–4,
contract C196, keyed by the pool's Job key.

- **Why section 6, not section 4.** The row's question assumed section 4. But SAVE-S4-STREAM-R01 froze section 4's
  owner set at 18 (`store_count` 18), and the record is an auxiliary admission keyed by a Job, like the entry
  progress record.
- **Wire.** Schema 1, magic `UHPL`, 196,620 bytes, all 8,192 rows.
- **Restore.** It runs after Inventory and the pool. It proves every row **from the image** before writing any:
  - an empty row is canonical;
  - an admission names either a live store, or (with 0 grams) a ground tile;
  - an admission holds at least one pool claim under its Job key;
  - the image's grams on each store fit what that store reserves (`audit()`'s rule).

The persistence registry rows become category 1, and the canonical registry advances to version 13
(`RWL-CANONICAL-REGISTRY-2026-10-07-CL1`). Section 6 goes to schema 7: 63 owners, 773 fields, 763 records and 677
packed fields. The generated declaration table, the capacity audit (5 new equalities) and the validators' pins move
with it.

## 5. The cold Budget and ConnectorWork save nothing; quiescence is required

**Budget.** The arena is saved only when quiescent: no lease and nothing used (`is_quiescent()`). Its two other
members are not state:

- `_next_token`: a token is only ever compared for equality with the live lease;
- `_peak`: a measurement.

A long-used arena and a fresh one admit, cover, extend, refuse and release every later operation identically
(`test_underground_budget.gd`). So the arena writes nothing.

**ConnectorWork.** It was listed in ADR 1218. It keeps only synchronous stage controls and a lease that it releases
before returning. `save_quiescence_refusal()` requires no operation, staged intent or retained lease. Both goal
chains assert this at every cold restore, and it held at every one.

## Memory

The Routes (320,608 bytes) and WorldRoutes (84,184 bytes) images are charged to the caller's existing cold Budget
lease (`Budget.COLD_BYTES` = 1,048,960). Together they are 404,792 bytes. The other images are not leased:

- the Contacts scope image, 74 bytes;
- the Planner's admission image, 196,620 bytes.

Each is one caller image, charged as retained, conservatively. The current-source census row `cold_load_images`
(196,694 bytes) recomputes both from the codecs' constants. The new declaration adds 165 bytes. No packed column is
added.

The joint pack moves from 100,013,033 to **100,209,892 bytes**, leaving **49,790,108 bytes** under DEC-053's 150 MB
gate. The ledger in `systems_architecture.md` and `ready07_arithmetic.py` gains two rows.

Step 1 also changed Routes', WorldRoutes' and Contacts' storage facts (wire constants, the image resize). Their
reviewed-delta rows in `docs/validation/evidence/underground-memory-census-2026-10-06/reviewed-deltas.json` now
carry them, and the census's pinned table hash moves. **Step 1's own commit left those rows stale**, so
`underground_memory_budget.py --check` refused between that commit and this one.

## Evidence

- `test_underground_routes.gd`:
  - `test_route_wire_restores_a_moving_actor_into_blank_banks_and_arrives_exactly`: the actor is saved mid-span
    with a 2/3 fraction. The restored actor finishes the 30-tick walk to the exact unit.
  - `test_route_wire_refuses_every_corrupt_image_and_keeps_the_live_banks`: 17 kinds of damage, a busy owner, a
    foreign lease and a truncated image. Each is refused with its exact code, and the live image is unchanged.
- `test_underground_world_routes.gd`:
  - `test_cold_route_images_restore_into_blank_owners_and_the_actor_walks_on`: real WorldRoutes. The owners are
    blanked as a fresh Session's are, then restored.
  - `test_restored_journal_still_carries_the_restored_certificate`: a far change from before the save is still
    carried after the load.
  - `test_cold_certificate_image_refuses_every_corrupt_field_and_keeps_live_banks`: 11 damaged fields, a busy
    owner and a truncated image.
- Both goal chains:
  - The hauled complete prefix (`test_underground_paid_assembly_handling.gd`, 4,751 ticks) cold-restores Routes and
    WorldRoutes into blanked banks every 41 ticks, about 116 loads. It runs alongside ADR 1218's every-tick foreman
    restore.
  - The live `run_tick` chain from the surface walk to the G6 stop (`test_underground_host.gd`, tick 518)
    cold-restores both owners every 23 ticks.
  - In both chains, every final ledger and both route images are byte-identical to the uninterrupted run.

Both goal chains also cold-restore Contacts' scope and the Planner's admissions, blanked as fresh owners hold them,
with Delivery and the arena required quiescent. They do it every 41 and 23 ticks respectively, and the final images
are byte-identical. Unit tests cover the rest:

- `test_haul_planner.gd`: a store admission survives clear-and-restore and then cancels exactly, and 6 kinds of damage
  plus a truncated image are each refused with nothing written.
- `test_underground_connector_contacts.gd`: a primed scope restored into a fresh scope still lets the actual paid
  START succeed, and corruptions and busy states are refused.
- `test_underground_connector_delivery.gd`: quiescence is required.
- `test_canonical_state_hash.gd`: the new owner's declaration.

## Not done: step 4 (the section-6 body and a fresh-settlement load) needs Brendan's choice

Steps 1 to 3 are done. Every owner the lead named now has an exact codec or a proven-empty saved form: Routes,
WorldRoutes (with both journals), Contacts, Delivery (via the Planner), the Budget, and ConnectorWork.

**A load into a fresh Session cannot be built on its own**, because a fresh Session needs a fresh settlement:

- `UndergroundSession.configure` binds one-way authorities into the host's Buildings, Construction and Inventory
  (`_initial_authority_refusal`). A new Session cannot mount over the old surface owners, and world retirement
  clears those owners.
- **The settlement itself has no save or load.** `SettlementSystem` has no save path at all ("CheckpointHash: no
  save stream", task 09.2: "Full-file orchestration remains incomplete").
- Several sections have codecs, but some owners the entry chain writes have no apply adapter: Construction has no
  restore, and its paid ledger and open projects are UNRESOLVED contract questions (ConstructionPaidLedger,
  CONSTRUCTION-SAVED-BINDINGS).
- The live chain also ticks the whole surface (needs, schedule, Jobs) between saves.

So a "fresh Session or settlement" goal test needs task 09's whole-file save and load first. Those are surface
decisions, not underground ones.

Options:

- **A. Build the settlement save and load (task 09) first.** That means the section bodies, the apply adapters,
  SettlementSystem save and load, and ARCH-SAVE-004's transactional load. The underground section-6 body then rides
  on it. It is the only path to the literal goal. It is large, and several of its rows are contract questions
  only Brendan or the save contract can settle.
- **B. Build the underground section-6 body and orchestrator now**, wired into `SettlementSystem` as an
  underground capture and restore over the mounted Session. It would:
  - declare the remaining underground owners canonically;
  - restore in dependency order (Space, Locations, Routes, WorldRoutes, Placements, Workpieces, Sites, Router,
    Contacts, Planner, then ADR 1218's entry record last), with full validation and rollback;
  - prove "blank every underground owner, reload, continue" byte-identically in both chains;
  - audit the remaining underground owners (Room orders and bindings, the surface anchor, the Frontier, the entry
    bindings) for cross-tick state, as was done for Contacts here.

  The literal fresh-settlement load would then wait for A.
- **C. Stop at the owner codecs.**

**Recommendation: B, then A as its own milestone.** B is bounded, and A will call it unchanged.
