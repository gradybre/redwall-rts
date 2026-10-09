# 1224 — The live Session composes the entry structure provider (ADR 1197 G12)

Date: 2026-10-07 · Status: Accepted; implemented. Closes ADR 1197 G12. The live chain now settles every paid L0
phase and stops in the L0 installation at a G5 gap.

## The gap

Since ADR 1223, the first paid BRACE START refused `WORLD_COMPOSITION_BINDING`. The refusal came from
`WorldBindings._structure_binding_refusal`, because the provider had no structure observer: only the fixtures called
`bind_phase_structure` (`test_underground_entry_world_bindings.gd`, `test_underground_entry_structure.gd`).

## Decision

`underground_entry_composition.gd` gains one constructor stage, `_bind_structure`. It runs at entry prefix 13,
after `_bind_phase` binds the phase contacts and before `_bind_work`. The stage does exactly what decision 1122's
fixture does, with the Session's own owners:

1. `StructureScope.configure(world_bindings, levels, budget)`.
2. `EntryStructure.configure(scope, space, terrain, levels, sites, budget)`. The entry structure extends the base
   phase structure, so ordinary Room protection is the same object.
3. `bind_entry_sources(placements, entry_frontier, ENTRY_CONTROL_BYTES)`.
4. Both objects are retained in the Retirement `Owners` packet (`structure_scope`, `entry_structure`). WorldBindings
   and the structure hold each other only weakly, and retaining before the one-way bind means a refused bind still
   leaves the pair for whole-World retirement, as the other entry stages do.
5. `world_bindings.bind_phase_structure(entry_structure, levels)`.

No prefix number changes. The Retirement shape proof adds `_structure_shape_refusal`:
- the pair exists together, and only from prefix 13;
- with the expected scripts;
- from prefix 14 on, the provider's weak `_structure` must be exactly the retained entry structure.

The Owners copy and identity comparisons carry the two fields.

**Re-mount.** This is composition, not state. A Session re-mounted by running the composers again
(`compose_underground_entry_owners`) reproduces it, with no saved byte. The settlement-save worker's §6 mount record
needs nothing extra beyond reaching prefix 17 through the same composers.

**Alert.** `WORLD_COMPOSITION_BINDING` now maps to G12 in the runtime's `GAPS`. With the provider composed, the
code means the provider lost its structure binding or a bound owner was rewired.

## The live chain now (`test_underground_host.gd`, `run_tick` only)

1. The surface walk (373 ticks) and the hauls.
2. All twelve paid L0 phases settled: BRACE, CUT and FINISH for four episodes, 36,000 mWU accepted, six whole units
   hauled.
3. The paid L0 installation opened under the crew's own installation Job.
4. At tick 2575, the installation's assembly-handling occupancy proof (`Routes._assembly_occupants_leaf`) refuses
   **`ROUTE_ASSEMBLY_ACTOR_UNBOUND`**.

That proof is the sixth occupancy proof. ADR 1219 moved five proofs to `Routes.unregistered_occupant_refusal`
(reach cubes around unregistered residents); this one still requires every living resident to be a route actor. The
code is specific, so it is mapped to **G5** in `GAPS`. Building it means applying ADR 1219's rule to this leaf.

ADR 1223's per-tick invariant holds over the whole run: from arrival to the stop, the crew holds an entry Job at
every tick and no other resident holds one. The restore-every-tick variant reaches the same stop with byte-identical
owner, record and route images. It restores the runtime 373 times mid-walk and 2,202 times after registration, and
cold-restores the route owners every 23 ticks.

## Memory

No new reserve. Decision 1122 already budgets the entry structure (384 B packet plus helper allowance), and decision
1152 budgets the base phase-structure slice. The two Owners references are object headers, which are native
overhead. `underground_world_retirement.gd` is a projected reviewed input, so its storage delta (the Owners class
gains two members, 0 B charged) is recorded in `reviewed-deltas.json` and `REVIEWED_SHA` is re-pinned. The joint pack
stays at 100,209,901 B.

## Update (2026-10-07): past the assembly proof, the next gap is G13

ADR 1219's reach rule now covers the assembly-handling proof (see the amendment in ADR 1219), so the L0 bill is
delivered. The live chain still stops at tick 2575, now in the installation's paid FUND, with
**`ENTRY_CONTACT_RETIREMENT_SOURCE`**.

The cause is the contact-retirement scope's `_source_shapes()` (`underground_entry_contact_retirement_scope.gd`).
It expects a Workpieces bank sized for the fixture, with 12 parts and 2 profile revisions. The live Session
composes the bank at production capacity (`Placements.MAX_PLACEMENTS`, `Workpieces.MAX_ASSEMBLIES`), which gives
1,536 parts and 256 revisions, so `_initial_source` refuses. The Frontier header and shapes, and the route edge
capacity (1,536), all pass.

This is recorded as ADR 1197 **G13** and not built here. The fix is to check the bank against its own configured
capacities instead of fixture literals. The code is shared with genuine source-drift refusals, so it is not mapped
to G13 in `GAPS`.

## Update (2026-10-07): G13 built; the next gap is G14

**G13 built.** The retirement scope now validates the Workpieces bank against its own configured capacity: 6 × the
assembly capacity for parts, the assembly capacity for revisions, and exactly two loaded assemblies. It snapshots
and re-proves the two assemblies' six field-major part columns at that capacity (`field × capacity + row`). This
equals the old flat indexing at the fixture's capacity of 2, so fixture images and the census-counted packet sizes
are unchanged.

**The live chain now:**
- installs L0 once (32,000 mWU of handling and fastening, `INSTALLED` 1);
- settles T0's six cut phases (54,000 mWU of cut Work in all, nine whole units hauled);
- opens T0's paid installation.

At tick 4349 the T0 FUND stops with **`CONNECTOR_CONTACT_OPERATION_CAPACITY`**. Contacts' `_scope_leaf` cannot
spend `SOURCE_CHECKS` from its per-operation fragment budget during the final observation that the FUND's input
consumption runs (`Reservations.consume_connector_inputs` → `Inventory` attestation → `Router.final_input_refusal` →
`ConnectorWork.final_funding_refusal` → `Contacts.final_observation_refusal`). The fixture never meets this. The likely
cause is the live occupancy scans: ADR 1219's reach test spends 16 checks per resident row, over 256 rows, in each
proof of the operation. This is recorded as ADR 1197 **G14** and not built here. The code is generic, so it is not
mapped in `GAPS`.

## Update (2026-10-07): G14 built (ADR 1227)

Measurement refuted the reach-scan hypothesis above. The occupancy leaf, reach scan included, spent 8,192 of the
operation's 1,046,706 checks. The overflow came from Contacts' full Region-bank scans, which were charged per slot
whether a slot was present or not. ADR 1227 charges them per slot read plus per present row. The live chain now
installs T0 and finishes the first-entry prefix at tick 4630.
