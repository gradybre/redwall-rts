# 1054 — Furniture layouts validate completed geometry before atomic project submission

Date: 2026-10-02 · Status: Accepted (independent foundation; integration remains open)

## Decision

`godot/scripts/core/room_layout.gd` owns packed, generation-validated room
preferences, furniture drafts and accepted project receipts. It does not own
inventory, construction work, installed furniture or room services. Both
**Plan layout** and **Place individually** use the same current geometry and
access validation. Switching modes preserves drafts and accepted orders.

The caller binds three trusted owner methods: `read_snapshot(room_ref)`,
`is_live(domain, ref)` and, optionally, `submit_batch(batch)`. Without the third,
planning works but confirmation explicitly refuses. There is no success fallback.
The caller must retain those owner instances; method Callables introduce no
back-reference from the owners to this planner.

## Geometry and catalog contract

`Snapshot` version 1 identifies a live room, its permanent `Catalog.ROOM_TYPE`,
level, revision, grid pitch, completed shell, explicit allowed furniture mask,
packed floor X/Z cells with floor/ceiling heights, external-route entries,
protected approaches/landings, blocked cells and eligible undirected walk links.
`room_cells` identifies the owned room floor inside that connected walk context:
an item's footprint must stay in its room, while a real installation/use contact
may lie across an open boundary (as the GDD starter pantry shelves use the common
room). Neighboring furniture obstructions and required approaches enter through
blocked/protected cells; the typed object list contains this room's own pieces.
Existing objects include **both** installed furniture and unfinished accepted
projects, each with its domain and full slot/generation reference. A snapshot
revision must change whenever geometry, occupancy, compatibility, profiles,
connections or shell completion changes.

Floor dimensions come from `BuildingDefinitions`, whose GDD §5.9 footprints
are **2 m tiles**. A finer placement grid subdivides those dimensions exactly;
it never shrinks furniture. Pitches that do not divide 2048 simulation units
refuse. Four rotations retain the same physical dimensions. Each occupied cell
must belong to the actual finished floor, share one floor height, avoid claimed
and protected cells, and fit below its actual overhead obstruction. Rotation
and translation use int64 before narrowing to int32.

Each furniture kind additionally needs an authored `Profile`: height and
rotation-zero installation/use contact cells at the snapshot pitch. All listed
contacts must remain free and reachable through the supplied movement links.
No adjacency is inferred from proximity, shared room identity or matching X/Z.
After stamping **all** old/new footprints, a deterministic flood checks contacts
and protected landings, so a later item cannot block an earlier one. Shared
contact cells are permitted while free; they are not exclusive reservations.

This does not invent a room compatibility matrix, equipment height, contact
side, portability, handling work, price or movement profile. Missing profiles,
unknown compatibility, and edge furniture needing an opening owner refuse.
The full catalog and door/partition envelopes remain integration work. “Bedroom”
does not introduce a ninth room ordinal; the existing PRIVATE_ROOM/DORMITORY
mapping belongs to the room catalog/UI owner.

## Atomic acceptance and identity

Layout drafts create no world occupancy or material claims. Individual mode
ignores retained drafts when ordering a new piece, because those drafts reserve
nothing; later confirmation revalidates them against the resulting world.
Grouped confirmation copies every retained entry into one `Batch` with the
current expected revision. The coordinator must:

1. Recheck the revision, live references and all relevant placement/command
   conditions at its commit boundary, including paused-command semantics.
2. Admit every per-furniture project atomically, or change no world owner.
3. Preserve existing Construction delivery, work, refund and inventory rules.
4. Return one distinct live construction reference per item, in request order,
   and include every accepted occupancy/access claim in the next snapshot.
5. Grant installed services only after actual installation and whole-room
   validity succeed; accepting a blueprint grants none.

The current `Buildings.place_furniture()` immediately contributes its presence
mask, and `Construction.open_furniture()` expects that published row. Calling
those two blindly would expose unfinished furniture services. They therefore
are **not** used as a direct acceptance shortcut. The composed construction and
service integration must resolve that existing gap.

An ordinary coordinator refusal retains all drafts. A malformed success is
reported as `CONSTRUCTION_COORDINATOR_CONTRACT_BREACH`; the planner cannot
roll back unknown external writes and does **not** claim otherwise. It disables
resubmission until the construction owner reconciles its state and rebinds. Production
must bind a reviewed, synchronous atomic owner, not an arbitrary permissive
callback. Reentrant planner mutations during submission refuse.

Room preferences/drafts use the whole room identity. Same-identity type changes
refuse, even for an empty room. Removing and rebuilding a room must create a
new identity; an empty live binding cannot be forgotten to bypass the type
check. Draft slots have their own local generation namespace. Retired local
generations are retained, and INT32_MAX slots never allocate again. Accepted
receipts are UI tracking only: their disappearance does not release a real
construction claim, cancel work or install furniture.

## Bounds, persistence and remaining work

Room and placement arenas are caller-sized up to existing Buildings capacities
(16384 rooms, 81920 placements). The packed payload is 13 bytes/room and
33 bytes/placement: at the inherited maxima, 2,916,352 bytes, excluding catalog
and temporary cold-operation data. These are engineering storage bounds, not
new room or population balance rules.

One validation operation admits at most 16384 floor cells, matching the
canonical footprint helper. Its link-pair and aggregate contact budgets are
each four times the configured cell budget. Objects/entries are bounded by the
configured placement arena, existing objects additionally by the cell budget;
each profile contact list is at most one cell budget. Excessive input refuses
before unbounded traversal/allocation. These are operation safety ceilings,
not promises that any room of that size is performant or movement-qualified.
No validation runs per resident or per fixed tick.

The current foundation is not wired into the demo and supplies no saved-world
codec. Preferences, drafts and receipts must survive the later approved
furnishing/revision save workflow, so their registry rows are **UNRESOLVED**
pending an owner/schema assignment, rather than falsely classified as
disposable presentation. Snapshot/validation/guide data are ephemeral owner
images, never alternate canonical world state. Relocation, unloading, service
suspension, edge-door geometry, renovation, and a live construction coordinator
remain separate queued work. Tests here use synthetic owner fixtures and prove
this boundary, not those unimplemented systems or 256-resident performance.

## Sources

- GDD §4.3, §5.9 and REQ-SET-121, 124–126, 129.
- SET-MOVE-001: explicit connected space, generation identity and real access.
- Approved underground D08–D10, D18; UG-FURN-001–012 and 024–027.
- `docs/design/underground-planning/furnishing-and-room-use.md` separates
  approved behavior from missing numerical/catalog contracts.

## Foundation verification

Godot 4.7.2, own furnishing worktree: demo assets absent; removed `.godot`, then
ran `godot --headless --path godot --editor --quit`. Ran the new suite through
the unchanged strict shell wrapper as the singleton shard selected from its
complete 299-suite manifest:

```text
./tools/run_tests.sh --shard 131/299 --output-dir /tmp/redwall-ug-furnishing-strict-final
state_registry_coverage: PASS -- 93 modules, 443 rows, 760 packed columns checked
39 test(s), 264 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The shard index follows this source/manifest; rediscover it after changing
weights or files. This is a **focused** run, not a claim that all 299 shards
ran. The integration branch still requires the full no-argument CI procedure.
`python3 tools/gdscript_warnings.py --max 0` reported
`0 GDScript warning(s) in 0 of 1030 file(s)`; the final changed files also
passed a targeted analyzer recheck after the receipt-scan and neighboring-access adjustments:
`0 GDScript warning(s) in 0 of 2 file(s)`.
