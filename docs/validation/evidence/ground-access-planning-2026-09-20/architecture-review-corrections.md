# Ground-access review — correction and addendum (R01)

Scope: the six corrections in `review-corrections-r01.md`, checked against the newly supplied source (`docs/persistence_state_registry.md`, `docs/systems_architecture.md`, `docs/validation/ready07_arithmetic.py`, `godot/scripts/core/save_section_navigation.gd`, `godot/scripts/core/save_owner_movement.gd`, `docs/validation/evidence/ground-access-planning-2026-09-20/diagonal-clearance-coverage.json`, `mouse-rigid-yaw-diagnostic.json`) plus re-reading of `navigation.gd`, `movement.gd`, `spatial_world.gd`. The original review stands as a record; this addendum supersedes it wherever the two disagree. Nothing was executed; no dimension, offset, class, cost or policy is proposed or adopted.

---

## 1. Corrections — accepted, with the verification that settles each

**C1. B4 and GA-01-D are WITHDRAWN in full. The corner rule already proves the diagonal.**

I analysed `_step_is_legal` as an endpoint test plus a walkability corner test. It is not: `_corner_open()` evaluates `cell_passes_clearance(cell, _search_clearance)`, i.e. the *same* class `k`. So a legal diagonal step from anchor `a` to `a+(dx,dz)` has all four anchors `a`, `a+(dx,0)`, `a+(0,dz)`, `a+(dx,dz)` qualified at class `k` — the source anchor because it was qualified when relaxed, or by `_start_first_stage`'s explicit start check before the search began.

Because `_recompute_clearance` defines `_clearance[c]` as the side of the largest all-passable square with `c` as north-west corner, each qualified anchor certifies a full `k×k` passable cell block. Normalising to `a=(0,0)`, step `(1,1)`, the four blocks are the four products of `{[0,k], [1,k+1]}` on each axis; **all four combinations are present**, so their union is exactly `[0,k+1] × [0,k+1]`. The (k+1)-square I proposed adding is therefore already established, and the swept Minkowski region of a contained k-square along the diagonal lies inside it. `diagonal-clearance-coverage.json`'s 64 witnesses (k = 1..16, all four step signs) agree and I find no counterexample. The orthogonal case was already exact (union of two k-squares offset by one = the k×(k+1) rectangle, which is the swept region).

Consequences: the proposed `_clearance[min-anchor] >= k+1` test is redundant and would be strictly over-conservative; the route-semantics bump I motivated *from it* is withdrawn; the "failing staircase/diagonal witness" in my acceptance list is withdrawn. One residual is real and is now more load-bearing, not less: the proof is stated in the **search** clearance class, so it transfers to the traveller only if the admitted profile's class equals the class the route was searched at — which today nothing checks (see §2.3). A second residual: the argument depends on `_corner_open` testing clearance rather than walkability, which is exactly the kind of thing a later "simplification" removes silently; see the replacement test in §5.

**C2. B1's lattice/modulus claim is WITHDRAWN. The real coupling is narrower and is a different function.**

`512*(r-q) + (256+512q) = 512r + 256` for integer `q`, so the root-preserving proposal leaves the root position on the canonical lattice. `_is_centre_coordinate` tests `(units − 256) % 512 == 0` within the map bounds and therefore does **not** refuse it. My assertion that the saved-image modulus gate forces a refusal was wrong.

What survives, restated precisely. The coupling is between the stored target and the stored *cell*, not between the target and the lattice: `_advance_cursor_target` writes `_next_x/_next_z = cell_centre_*_units(route_cell)`, and `movement.gd::_columns_target_is_centre` re-derives the target from `grid_next`/`grid_cell` and refuses a mismatch. So the live decision is **which space route cells occupy**:

- If route cells remain **root-containing** cells and the footprint anchor is *derived* at passability-test time (`anchor = cell − (qx, qz)`, bounds-checked), then `_advance_cursor_target`, `_refuse_route_start`, `_is_centre_coordinate` and `_columns_target_is_centre` are all untouched. Only `navigation.gd`'s clearance/corner tests, `_start_first_stage`'s endpoint checks and `lowest_passable_cell_in_macro` change.
- If route cells become **anchor** cells, then `_refuse_route_start` refuses every admission (root cell `r` vs route cell `r−q`) and `_advance_cursor_target` drives the root to the anchor centre — a `512q` displacement per axis.

The first formulation is strictly cheaper and is what a bounded slice should specify. I withdraw the "three call sites, two in persisted-state validation" framing.

**Cache-key consequence, corrected.** A *per-profile* `q` makes passability profile-dependent, so the descriptor key `(start_macro, goal_cell, clearance, revision, variant_start)` would have to carry it (one I32 column on 256 descriptors = 1024 B, one on 8192 requests = 32768 B, plus §9 field ordinals). A **single world-wide** `q` leaves one graph per clearance class exactly as today and needs no key change. For a slice with one starter cohort the global form is the defensible choice; per-profile `q` is a later contract with that named cost. Either way the *meaning* of a stored route changes, so `ROUTE_SEMANTICS_VERSION` 2→3 and §9 `OWNER_SCHEMA_VERSION_NAVIGATION` 2→3 would be required — and that bump is justified here, unlike the one I withdrew in C1.

**C3. Section 9's codec EXISTS, is sized and validates. My "lost journey" acceptance is WITHDRAWN. But codec capability is not live capture, and is not whole-file restoration.**

`save_section_navigation.gd` is a complete two-owner §9 codec: `movement` (schema 1, 512 primaries, 18504-byte payload, nine cursor+admission fields in declared ordinal order starting at `_cursor_owner_id`) and `navigation` (schema 2, 8192 primaries, 5161468 + 4·(heap+arena) bytes), section 5180042 empty to 10422922 maximum. `persistence_state_registry.md` classifies `ResidentRouteCursor` (4 columns) and `ResidentTravelAdmission` (5 columns) as category 1 in §9. So the assertion that the cursor and admission columns are "not in the saved field window" was wrong — they are simply in a *different* window from owner 8's sixteen motion columns, which `save_owner_movement.gd` covers in §4.

The codec is also stronger than I credited: it enforces PATH-R02's `_r_start_cell == _r_exact_start`, refuses retired `PHASE_SEARCHING_LOCAL`, rebuilds descriptor refcounts from actual READY holders, reproduces `_enqueue`'s service order, refuses nonzero residue past `_heap_size`/`_arena_used`, and gates the schema version through `Navigation.refuse_route_semantics()`.

**Three distinct states, which must not be collapsed into one another.** (i) The §9 *wire format, Record codec and field allocation* exist and validate — that is what I was wrong about. (ii) *Live capture and apply* do not: the module's own BLOCKER N1 records that neither `navigation.gd` nor `movement.gd` publishes a bulk column reader/writer, and I confirm no such API in either supplied file. Nothing can read a live navigator or movement store into a Record, and nothing can install a Record into one. (iii) *Whole-file disk continuation* — orchestration, ordering, digest verification, rollback — is a further layer above both. My original text conflated (i) with (ii) in one direction; a reader should not now conflate (ii) with (iii) in the other. Accepted-elsewhere planner capture work belongs to `job_planner.gd` / §8 and establishes nothing for §9; SAVE-COLUMNS-NAVIGATION is *ready*, not *done*. The bounded ask is precisely the two owner APIs the codec header already names, following the `save_section_directory.gd` D1 precedent (closed by decision 0105) and the `sim_clock.gd` precedent (closed by RESTORE-R01).

My proposed acceptance "declare movement save-parity out of scope and test that the settle is deterministic" is **withdrawn without replacement**. It would contradict MOVE-REQ-016 and an already-implemented codec, and a missing-journey allowance is not an acceptable substitute for required full continuation parity under any framing of slice scope.

**C4. Memory arrears are ZERO, not 12384. Three of my four byte proposals are withdrawn.**

`ready07_arithmetic.py` carries `DECISION_0066_ADDED = 2048` (the `_cursor_owner_id` column) with an explicit assertion on the four-column `ResidentRouteCursor` row text in `systems_architecture.md`, and `DECISION_0083_ADDED = (5*4*512)+(6*4*4) = 10336` (travel admission + starter profile catalog). Those are exactly the 2048 + 10240 + 96 that `movement.gd`'s header still reports as owed. The header is stale prose, not a live gap — and that staleness is itself worth a one-line source fix, because a header asserting an open ledger debt is how a debt gets paid twice. The checker also now ties §3's printed rows to the `Auxiliary payload` allocation row (`assert sum(section3) == auxiliary`), which closes the class of drift I was reasoning from.

Withdrawn: the 12384 "carried arrears"; the 18432-byte "save obligation" (those are already-allocated *live* columns whose wire representation §9 already defines — conflating live allocation with wire bytes); the `_cursor_map_revision` +2048 (see C6/§4-F); the 1024/32768 descriptor+request key growth unless per-profile `q` is adopted.

Still genuinely outstanding, confirmed absent from `movement.gd`, from the registry's `ResidentTravelAdmission` row and from the checker's trail: MOVE-DEP-R05's **+6144** (`_cursor_destination_slot`, `_cursor_destination_generation`, `_cursor_contact_key`, I32[512] each) and MOVE-DEP-R02's **+4** (`_profile_life_stage` as a packed `B8[4]`, still blocked on a registry row). `systems_architecture.md`'s own 2026-09-12 note states the 6660-byte total of which only the 512-byte `life_stage` has landed.

**C5. The anatomy inference is WITHDRAWN, and my "hold q=0" recommendation is reversed.**

I had no basis to call −438u an A-pose artifact or to imply changing the asset is the cheaper repair. Withdrawn without qualification. `mouse-rigid-yaw-diagnostic.json` additionally supplies exact evidence that changes my recommendation rather than merely softening it: maximum horizontal radius 439u (outward integer, from exact rational vertex arithmetic), and containment trials showing `(256,256)` → `[−183, 695]` uncontainable at any class, `(768,256)` → X satisfied, Z still `−183`, and `(768,768)` → `[329, 1207]`, a class-3 *diagnostic* containment only. Since yaw is pinned to zero (see §2.6) the orientation-agnostic requirement is the conservative one, and a rigid-yaw radius of 439u exceeds the baseline 256u offset on both axes — so **`q = 0` is arithmetically impossible for this source before any margin**, and my "hold q=0 for the slice" recommendation is wrong. The corrected recommendation: make `q` a first-class contract term on **both** axes while assigning no value, and do not let the slice's design depend on `q = 0` being available. This is not an art judgment, a profile, a margin, or the seven-state sweep, which remains the gate.

**C6. Aperture-alignment change and the "smaller release" framing are WITHDRAWN; the octile claim is corrected.**

I recommended constraining authored openings to the 512u grid (GA-01-C option (a)). Withdrawn: I have no measurement of the rasterized aperture under the actual authored alignment, and changing authored geometry to fit a rasterization policy is backwards. The correct order is measure, then choose. Also withdrawn: any framing in which missing save parity, interpenetration or absent leases are "declared out of scope" and the result still counts as physical access.

The admissibility claim is corrected and is materially different from what I wrote. Adding an edge does **not** automatically invalidate the octile heuristic; the test is whether `h` remains a lower bound on the new cost graph:

- An edge between cells that are already lattice-adjacent, carrying a **positive surcharge** (a step-height or shore-transition cost added on top of 10/14), only *raises* costs. The octile `h` remains a lower bound and stays admissible. No Dijkstra fallback is forced.
- A **nonlocal** edge, or any edge cheaper than the octile lower bound between its endpoints, breaks the bound and does force the SET-MOVE-001 §4 Dijkstra reference for the affected graph.

This makes the doorway question sharper rather than looser: modelling a door as a surcharged lattice edge is admissibility-safe; modelling it as a shortcut is not. It also promotes a defect I had filed as low priority — `route_cost_into()` reconstructs cost from cell adjacency alone (`dx+dz==2 ? 14 : 10`), so a surcharged lattice edge makes it silently wrong while still looking plausible. Any surcharge work must fix or retire that reader in the same change.

---

## 2. Findings that survive, re-verified against the fuller source

**2.1 Contact identity is incomplete (adopted-but-unmet obligation).** `movement.gd` stores only `_cursor_destination_revision`; `revalidate_destination(resident, revision)` accepts any caller presenting a matching integer. MOVE-DEP-R05's three identity columns are absent from source, from the registry row and from §9's nine-field movement block. Unchanged.

**2.2 No contact producer and no approach selector (missing owner).** `spatial_world.gd::Contact` is a record shape; `begin_travel` requires `_route_ends_at(request, contact.approach.cell)` exactly, so something must choose the approach and route to it. The plan's candidates are 2 m tiles and movement consumes 512u cells (16 per tile), so tile→cell resolution must be deterministic and save-stable. `bind_ground_contact` qualifies an approach by `is_walkable_cell` — a class-1 test — so for `k ≥ 2` the class test must live in the selector, which cannot know it today. Unchanged.

**2.3 Clearance is not bound to the admitted profile (defect, now load-bearing).** `submit_request_into` takes `clearance_class` from the caller; `profile_clearance_class_into` always refuses; `_refuse_admission` never compares the two; `navigation.gd` exposes no reader for a request's clearance. C1 makes this worse than I first rated it: the diagonal-coverage guarantee is stated in the *search* class, so admitting a traveller whose profile class differs from the searched class voids the only proof that its diagonals are legal. This is now the single highest-value cheap fix in the package.

**2.4 Request lifecycle leak (defect).** Nothing in the supplied source calls `navigation.release_request()`. `movement.gd::_settle` leaves `_cursor_request` set and `stop()` clears the cursor without releasing. A READY request holds `_d_refcount > 0`, and `_lowest_use_unreferenced()` skips referenced descriptors, so leaked requests pin the 256-descriptor cache and exhaust the 8192 request rows. Sharper now: §9's validator *requires* `refcount == READY holders`, so a leak is perfectly valid persisted state — it will never be caught by a save check, only by exhaustion.

**2.5 Cross-segment budget loss (defect).** `_integrate_axis` runs once per axis per tick against the tick-start `_pose`, before `_spend_budget`; an axis whose tick-start delta is zero receives zero budget even if the segment entered mid-tick uses it. Separately, `_segment_is_diagonal` reads `_grid_cell/_grid_next`, which `_arrive_at_target` updates mid-tick, so the 10/14 numerator factor for the whole tick is fixed by the first segment. Both bounded by one tick's step (≤ 136u), both systematic and direction-dependent. Unchanged.

**2.6 Yaw, radius and separation are contractually pinned to zero.** `movement.gd::_columns_reserved_clear` refuses any saved image with nonzero `desired_yaw`, `next_yaw`, `radius_u`, `correction_x/z` or `blocked_ticks`, and `save_owner_movement.gd` forwards that code unchanged. Enabling facing is a §4 owner-8 schema event, not a local edit. With yaw unmodelled, the orientation-agnostic envelope is the conservative requirement — which is why the 439u rigid-yaw radius is the relevant figure for C5's arithmetic. No separation, no occupancy, no reservations; `crossing_claims.gd` remains absent from the manifest.

**2.7 Step height is unbounded and free; the ford is a 640u instantaneous vertical transfer.** `_height_at_into` writes authored tile height straight into `transforms.advance()`; the cost model has no vertical term; `_integrate_axis` is horizontal-only. MOVE-C3-R01 §1.3 declines to authorise the land↔ford delta as a step. Per C6, a positive surcharge is the admissibility-safe remedy, at the cost of `route_cost_into`.

**2.8 Batched legality publication is still necessary.** `override_static_legality` is per-cell and bumps `_map_revision` each call; each revision drives `_handle_revision_change` over 8192 requests and 256 descriptors plus `_compact_arena` (`_lowest_block_above` is O(descriptors) per block) and a deferred 262144-cell clearance recompute. §1's save semantics already support it correctly: `restore_section_1_columns` installs the stored `_walkable` and rebuilds `_walkable_count`/`_clearance` rather than re-deriving from authored terrain, and `section_1_cross_check_refusal` proves the rebuild ran. That deliberate choice should be called out so it is not "simplified" back.

**2.9 Walls and apertures are unrepresented.** `_fill_from_terrain` derives walkability from `world_init` 2 m terrain tiles only; buildings, partitions and doors contribute nothing. Unchanged as a fact; the *remedy* is reopened per C6.

**2.10 `_free_descriptor` orphans variant chains (defect, low severity, now with a digest cost).** It clears `_d_next_variant[descriptor]` before the fix-up loop, which then writes `NO_VARIANT` into the predecessor instead of splicing the successor. `_find_descriptor` scans linearly and never walks the chain, so lookups are unaffected — but §9 persists and hashes the column and only checks that a link points at a valid descriptor, so the orphaning validates cleanly and carries into the digest. Splice correctly or retire the column.

---

## 3. Newly identified in this pass

**3.1 No cross-section reconciliation between §4 owner 8 and §9's movement block.** `save_owner_movement.gd` validates the sixteen motion columns locally (its own header says so). `save_section_navigation.gd::_cursor_refusal` validates the nine cursor/admission columns locally. Neither checks the relation *between* them — a §4 row in `MOTION_TRAVELLING` with a §9 detached cursor, or an attached cursor on an `IDLE` row, passes both validators. Both modules name this class of obligation (MOVEMENT-SAVED-BINDINGS; "cross-section consistency" in the §4 stream module), so it is an acknowledged gap rather than an oversight, but it is the specific pair a ground-access slice would exercise first and it belongs in the package.

**3.2 `movement.gd`'s header reports a ledger debt the ledger has paid.** Per C4. A stale "running total still owed: 12384" invites a second payment.

**3.3 Adding the R05 identity columns is a §9 schema event with exact arithmetic.** The movement block would go from 9 to 12 fields: `MOVEMENT_PAYLOAD_BYTES` from `9*(8 + 4*512) = 18504` to `12*(8 + 4*512) = 24672`, i.e. **+6168 wire bytes** (6144 values + 24 count words); `OWNER_SCHEMA_VERSION_MOVEMENT` 1→2; `OFFSET_NAVIGATION_WRAPPER`/`OFFSET_NAVIGATION_PAYLOAD` and the section constants shift; the canonical registry and the §15 declaration table grow by three field records plus their key bytes (`ready07_arithmetic.py` derives that census from `canonical_state_registry.json`, so it will fail loudly if the table is not regenerated — which is the desired behaviour). Naming this now prevents the columns landing as "just three ints".

---

## 4. Revised bounded package (GA-01r)

**A — Placement/anchor contract (documentation + constants; no behaviour change).** Name and define four spaces: physical footprint anchor, root-containing cell, exact route start (PATH-R02's, unchanged), macro/cache anchor (PATH-R02's, unchanged). Specify the **root-cells-with-derived-anchor** formulation from C2. Make `q` a contract term on both axes with **no value assigned**, and state that the slice may not assume `q = 0` (C5). Specify that a single world-wide `q` leaves the descriptor key unchanged while a per-profile `q` requires the named key growth. Propagate the envelope tool's `PLACEMENT_INCOMPATIBLE_AT_OFFSET` into profile publication so an uncontainable profile cannot be enabled. No packed bytes.

**B — Batched static legality publication.** One revision bump, one deferred clearance recompute, all-or-nothing, refusal on revision exhaustion. Preserve and test `restore_section_1_columns`'s rebuild-from-stored-columns behaviour. Scratch only; §1 schema unchanged.

**C — Aperture: measure, then decide.** Report the rasterized usable aperture for the authored starter opening at its actual alignment and depth, under conservative whole-cell blocking, before any policy is chosen. Record both options with their real consequences: authored 512u alignment (no graph change); or an explicit ground connection at the doorway (graph change, admissibility preserved only if it is a surcharge on an existing lattice edge and not a shortcut — C6 — and `route_cost_into` must be fixed or retired either way). Recommend nothing further until the measurement exists.

**D — WITHDRAWN** (diagonal sufficiency; C1).

**E — Contact producer, selector and identity.** (i) A producer owned by the structures owner publishing `(owner_ref, contact_key, work location, approach location, destination_revision)` with a compiled `ContactDefinition` key domain. (ii) A deterministic approach selector resolving candidate tile → cell, applying the profile's clearance class (which `bind_ground_contact` cannot), and re-selecting on class or topology revision change. (iii) Movement's three R05 columns, **+6144 live bytes**, with the §3.3 §9 schema consequences executed in the same change and the registry row landed first (`state_registry_coverage.py` C3 gate). (iv) A revision-publication rule with atomic refusal at `INT32_MAX`.

**F — Clearance binding and request lifecycle.** Add a read-only `navigation.request_clearance(row)`; gate admission on equality with the profile-derived class (§2.3 — this is what preserves C1's diagonal guarantee for the actual traveller). Name the owner that calls `release_request()` on settle and fix the descriptor pinning. **Withdraw** the `_cursor_map_revision` column: `ARCH-TICK-003` already orders ARCH-SYS-011 Navigation before ARCH-SYS-012 Movement, and `_handle_revision_change` runs at the top of `service()`, so the invalidation guarantee exists at the specification level; what is missing is an in-source test pinning that order, not a redundant column.

**G — Save bindings (named, scoped, not this lane's to write).** BLOCKER N1's two bulk column APIs on `navigation.gd` and `movement.gd`, exactly as the §9 codec header specifies, plus the §4↔§9 cross-section reconciliation of §3.1. Keep the three states of C3 separate in any status report: wire format and Record codec exist; live capture/apply do not; whole-file disk continuation is a further layer. Capture/apply capability is the prerequisite for any parity claim, and no slice may substitute a missing-journey allowance for it.

---

## 5. Revised acceptance witnesses

Removed: the diagonal `(k+1)` cases and the "failing staircase witness" attributed to them.

Added — **regression guard on the corner rule's clearance semantics.** Assert that a diagonal step is refused when either adjacent orthogonal anchor fails at the *search class* even though that anchor's single cell is walkable. This pins the property C1's proof rests on, so a later change of `_corner_open` to a bare walkability test fails loudly instead of silently voiding the union argument.

Retained and unchanged: batched-legality single-revision and §1 round-trip (including that restore does not revert to authored terrain); placement refusal that no larger `k` repairs; aperture traversal or refusal with a reason, never partial; contact identity distinguishing two contacts on one owner sharing a revision, and refusing a replacement owner in a reused slot; selector stability at one revision and deterministic re-selection after a change; pantry-shelf cross-room approach; settle-releases-request and 8192 admit/settle cycles without exhaustion; steady-state speed parity between staircase and straight routes of equal step count (expected to **fail** before §2.5 is fixed — that is the point of the witness); no route crosses a height delta above the declared limit, with the ford as the fixture; reserved columns remain zero and `columns_refusal` returns `COLUMN_RESERVED` when perturbed.

Added — **cross-section**: a §4 owner-8 `TRAVELLING` row paired with a §9 detached cursor must be refused by the reconciliation validator of §3.1, and the mirror case likewise.

Added — **clearance binding**: a request searched at class `k` cannot admit a profile whose derived class is not `k`.

---

## 6. Revised ledger position

| Item | Prior review | Corrected |
|---|---|---|
| Carried movement arrears | 12384 owed | **0** — 2048 landed as 0066, 10336 as 0083; `movement.gd`'s header is stale |
| R05 contact identity | +6144 | **+6144, unchanged and still outstanding**, plus **+6168 §9 wire bytes** and an owner schema 1→2 |
| `_profile_life_stage` packed | +4 conditional | **+4, unchanged**, still blocked on a registry row |
| `_cursor_map_revision` | +2048 | **Withdrawn** — tick order is already specified |
| Cursor/admission save persistence | 18432 "deferred obligation" | **Withdrawn** — already-allocated live columns; §9 already defines their wire form |
| Per-profile `q` cache key | not raised | **+1024 descriptors, +32768 requests**, only if `q` is per-profile; a global `q` costs nothing here |
| Route semantics bump | proposed for the diagonal rule | **Withdrawn for that reason**; justified instead by a `q` adoption, and free today because §9 has no live capture/apply |

All figures are live packed-column allocation or declared wire bytes as labelled; neither is a measured resident set, and none includes Variant/container/native overhead.

---

## 7. What this addendum does not establish

It proposes no dimension, margin, offset, clearance class, speed, duration or capacity, and adopts no policy. It closes no movement gate and makes no release or playability claim, and it grants no waiver of save-continuation parity. It asserts no runtime, test or CI result — nothing was executed, and the diagonal reasoning is a set-theoretic argument checked against the supplied 64 finite witnesses, not a run. Statements about `residents.gd`, `world_init.gd`, `buildings.gd`, `entity_directory.gd`, `int_math.gd`, `starter_structures.gd`, the §4 stream coordinator, `job_planner.gd`/§8 and `tools/validate_movement_envelopes.py` remain inferences from call sites and supplied documentation and require verification against those files. The 439u rigid-yaw radius is supplied diagnostic evidence about one unposed test-pipeline mesh; it is not a body dimension, not a profile, and not a substitute for the seven-state body/gear/cargo sweep, and it must not be recorded or reused as any of those.