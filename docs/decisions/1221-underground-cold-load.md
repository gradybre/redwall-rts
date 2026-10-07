# 1221 — Underground cold load: owner codecs for Routes and WorldRoutes

Date: 2026-10-07 · Status: Accepted for the owner codecs below (Brendan's decision: build cold load now). The
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

## Memory

All capture and restore images for Routes (320,608 bytes) and WorldRoutes (84,184 bytes) are charged to the
caller's existing cold Budget lease (`Budget.COLD_BYTES` = 1,048,960). Together they are 404,792 bytes. No packed
column is added, so the joint pack and `tools/underground_memory_budget.py --check` are unchanged.

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

## Not done

- Contacts, Delivery, HaulPlanner admissions and the Budget: later steps of this record.
- The section-6 body, its canonical declarations and the settlement wiring.
