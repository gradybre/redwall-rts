# Starter ground profile and contact manifest — **closes no MOVE gate**

Status: **starter ground profile only; closes no MOVE gate.** Prepared 2026-09-11.
Authority: [movement continuation ruling](../rulings/2026-09-11_movement_gate_followthrough.md)
("Independent next increment"), its
[index](../rulings/2026-09-11_asset_save_movement_blockers.md),
[SET-MOVE-001](../movement_direction_amendment.md),
[task 05](../tasks/05_movement_first_playable.md) §05.1a.
Engineering record: [decision 0083](../decisions/0083-starter-ground-profiles-and-the-contact-schema.md).
Predecessor: [movement ground slice entry](movement_ground_slice_entry.md) (05.1a).

**Task 05.1b is not started and is not advanced by this document.** 05.1b is full connected
movement: expanded geometry, all three construction methods, swimming/diving, climbing/canopy,
the interruption matrix, the expanded packed schemas and save migration. This increment is a
starter profile, a contact schema and an admission boundary on the existing ground slice.

---

## 1. The manifest — four starter ground profiles

Four profiles, one per species in GDD §5.1's cohort sentence *"12 adults (6 mice, 2 moles, 2
otters, 2 squirrels); IDs 1–12"*, in that sentence's order. **No synthetic species is added**, and
the twelve other species `residents.gd` compiles have no starter profile and refuse.

| Profile id | Profile key | Revision | Species | Life stage | Size class | Speed u/s | Carry g | Modes | Clearance class |
|---:|---|---:|---|---|---|---:|---:|---|---|
| 0 | `starter.ground.adult.mouse` | 1 | mouse | adult | small | 3277 | 12000 | `GROUND_WALK`, `FORD_WALK` | **UNSPECIFIED — refuses** |
| 1 | `starter.ground.adult.mole` | 1 | mole | adult | small | 3277 | 12000 | `GROUND_WALK`, `FORD_WALK` | **UNSPECIFIED — refuses** |
| 2 | `starter.ground.adult.otter` | 1 | otter | adult | medium | 4096 | 16000 | `GROUND_WALK`, `FORD_WALK` | **UNSPECIFIED — refuses** |
| 3 | `starter.ground.adult.squirrel` | 1 | squirrel | adult | small | 3277 | 12000 | `GROUND_WALK`, `FORD_WALK` | **UNSPECIFIED — refuses** |

### Source references for every bound value

| Field | Source | How it reaches the profile |
|---|---|---|
| Species set | GDD §5.1 starting cohort | `movement.gd` `PROFILE_SPECIES_KEYS`, in the sentence's own order |
| Size class | GDD §4.3 "Small species are the first six, medium the next six" | **Read** from `residents.species_size_class()` at `_init()` |
| Speed cap | GDD §5.2 "movement caps 3277/4096/3072 u/second" | **Read** from `residents.size_movement_u_per_s()` |
| Carry capacity | GDD §5.2 "Carry capacities 12000/16000/24000 g" | **Read** from `residents.size_carry_g()` |
| Life stage | GDD §5.1 "12 **adults**" | `LIFE_STAGE_ADULT`; `residents.gd` has **no life-stage column at all** |
| Modes | SET-MOVE-001 §1 | Six modes enumerated, two profiled — see §2 |

**The audit is executed, not transcribed.** `_build_starter_profiles()` reads every numeric field
back out of `residents.gd` on each construction. A literal in the profile table could drift from a
GDD §5.2 revision unnoticed; a read cannot. `test_every_profile_reads_its_speed_and_carry_cap_out_of_the_resident_store`
asserts each profile against the store's own arrays, and replacing the read with the literal `4096`
fails the suite.

### Identity and revision policy

- Profile **keys** are stable ASCII, dot-separated, namespaced `increment.domain.lifestage.species`,
  so a later life stage or domain extends the namespace instead of overloading one of these four.
- Profile **ids** are the row index and are stable for as long as the key list is.
- Profile **revisions** start at 1. `revise_profile()` advances one. Every travelling resident's
  admitted revision is compared against the live one every tick and the body settles
  `MOTION_PROFILE_STALE` on mismatch — SET-MOVE-001 MOVE-REQ-006 at this increment's granularity.
  A revision is an identity artifact the ruling asks for, **not** a balance value.

---

## 2. Capability boundary — two modes profiled, four enumerated and refused

All six adopted modes are **enumerated in code** so the scope cannot be narrowed by omission:

| Mode | Profiled here? | What is missing before it can be |
|---|---|---|
| `GROUND_WALK` | **Yes** | — |
| `FORD_WALK` | **Yes** | — |
| `SWIM_SURFACE` | No — refuses `MODE_NOT_PROFILED` | Per-profile capability, speed, entry/exit duration, load/gear compatibility |
| `DIVE` | No — refuses `MODE_NOT_PROFILED` | All of the above plus air budget, recovery and contingency; MOVE-REQ-009/010 |
| `CLIMB` | No — refuses `MODE_NOT_PROFILED` | Grip rules, supported contacts, landing/descent catalog, canopy heights |
| `TUNNEL_WALK` | No — refuses `MODE_NOT_PROFILED` | Underground geometry, depth extents, clearance, construction accounting |

**This is an incremental capability boundary, not removal.** Surface swimming, diving, climbing and
canopy work, and persistent constructed tunnels all remain first-release scope under SET-MOVE-001
§1 and DEC-029/031/035. A profiled-mode refusal is the honest state until MOVE-G01 supplies the
numbers; a silent fall-back to ground walking is the failure this enumeration exists to prevent.

`spatial_world.gd` refuses every domain but `DOMAIN_GROUND` and every layer but `LAYER_SURFACE`
for the same reason, unchanged from 05.1a.

---

## 3. The contact manifest — schema, refusals, and the values the contact owner still owes

The ruling assigns item 4 to the **contact owner**: *"generation-checked work/service destination
identities, position and access qualification, with exact supported footprint/contact envelopes."*
The movement owner returns the **schema** that consumes it. That schema is
`spatial_world.gd`'s `Contact`.

| Field | Type | Meaning | Refusal when absent or wrong |
|---|---|---|---|
| `work` | `Location` (domain, layer, map revision, cell, owner slot + generation) | Where the work happens. **Need not be walkable** — building interiors and water work points are not navigable ground | `INVALID_CELL` |
| `approach` | `Location`, same shape and same owner | Where a body must actually stand | `INVALID_CELL`, `CONTACT_APPROACH_NOT_WALKABLE` |
| owner | `EntityRef = (slot, generation)`, both halves | The generation-checked destination identity | `LOCATION_OWNER_REQUIRED`; at admission, `CONTACT_OWNER_REF_STALE` |
| `destination_revision` | positive int | The contact owner's own number, bumped when the destination changes in a way that invalidates an admitted journey | `CONTACT_DESTINATION_REVISION_REQUIRED` (0 is "named no destination state at all") |

**Work point and approach cell are two different cells on purpose.** Collapsing them is
MOVE-REQ-013's defect one level up: horizontal proximity is not access.

**"Empty buildings or nonexistent service stores are not valid targets"** is enforced as three
separate, separately-named conditions, because merging them would hide which one went stale:

1. the owner reference must be live (both halves), checked at admission;
2. both endpoints must be current at the live map revision (`contact_is_current()`);
3. the destination revision must be positive at bind, and must still match at
   `revalidate_destination()`.

### What the contact schema deliberately does NOT decide

**No adjacency or distance rule is imposed between a work point and its approach cell.** How far an
approach may lie from its work point, whether a footprint spans several cells, and which side of a
multi-sided building offers one are the *"exact supported footprint/contact envelopes"* the ruling
assigns to the contact owner. `test_no_adjacency_rule_is_imposed_between_a_work_point_and_its_approach`
asserts that absence on purpose, so nobody later reads a silently-enforced adjacency as an adopted
envelope.

**Nothing yet produces a destination revision.** No building, room or service store publishes one,
so nothing calls `revalidate_destination()` every tick. That producer is the contact owner's piece
of item 4 and is not written here.

---

## 4. Route admission — the atomic boundary (ruling item 5)

`movement.begin_travel(resident, request_row, admission, contact)`. **Every check runs before any
column is written.** A refused admission leaves the resident's motion row exactly as it was.

| Order | Check | Refusal |
|---:|---|---|
| 1 | reference is a live resident | `REF_IS_NOT_A_LIVING_RESIDENT` |
| 2 | profile id is published | `PROFILE_NOT_PUBLISHED` |
| 3 | life stage is the profiled adult | `LIFE_STAGE_NOT_PROFILED` |
| 4 | mode is inside the enum | `MODE_NOT_IN_ENUM` |
| 5 | mode is profiled for that profile | `MODE_NOT_PROFILED` |
| 6 | the resident's species is the profile's species | `PROFILE_SPECIES_MISMATCH` |
| 7 | committed load is not negative | `COMMITTED_LOAD_NEGATIVE` |
| 8 | committed load ≤ GDD §5.2 carry capacity | `LOAD_EXCEEDS_CARRY_CAPACITY` |
| 9 | contact is bound | `CONTACT_NOT_BOUND` |
| 10 | contact owner reference is live | `CONTACT_OWNER_REF_STALE` |
| 11 | both contact endpoints are current | `CONTACT_LOCATION_NOT_CURRENT` |
| 12 | route request is READY | `ROUTE_REQUEST_NOT_READY` |
| 13 | route's **last** cell is the contact's approach cell | `ROUTE_DOES_NOT_END_AT_CONTACT_APPROACH` |
| 14 | resident is placed | `RESIDENT_TRANSFORM_NOT_PLACED` |
| 15 | resident stands on the route's **first** cell | `RESIDENT_NOT_ON_ROUTE_START` |

Admission then captures, on the motion row: profile id, **profile revision**, mode, committed load
and **destination revision**. Invalidation afterwards:

| Trigger | Where | Outcome |
|---|---|---|
| Profile revision changes | every `advance_tick()` | `MOTION_PROFILE_STALE`, body stops where it stands |
| Destination revision changes | `revalidate_destination()`, called by the contact owner | `MOTION_CONTACT_STALE` |
| Route cancelled / route generation changes / typed-row successor | every `advance_tick()` | `MOTION_ROUTE_LOST` (unchanged from 05.1a) |

**Equipment eligibility is load only.** Which tool or gear blocks which passage is not stated
anywhere; the committed-load check uses GDD §5.2's carry capacity, which is.

---

## 5. Values this increment refused to invent

| Refused | Why it cannot be derived here | Owner |
|---|---|---|
| **Body, posture or gear clearance class** | `asset_dimensions_and_budgets.md` line 43: the species heights *"do NOT set navigation clearance, service reach, step height or movement capability"*. The ruling adds that the head/ear-inclusive art candidates **and battle separation radii** cannot determine these dimensions. No horizontal body envelope for a resident is stated in any `docs/` file. `profile_clearance_class_into()` therefore **always refuses**, for every valid profile id | MOVE-G01 + asset owner, jointly, per ruling item 2 |
| **Horizontal body / posture / carried-gear / stowed-gear / load envelopes** | Not authored. Crowd §5's 184/246/461/922 are battle locomotion and separation radii and are explicitly excluded | Movement + asset owners |
| **A footprint or contact envelope** (approach-to-work distance, multi-cell footprints, which side of a building) | Ruling item 4 assigns it to the contact owner | Contact owner (buildings/rooms/logistics) |
| **Any swim, dive, climb or tunnel speed, entry/exit time, air budget, recovery or grip rule** | None exists. The four modes are enumerated and refuse | MOVE-G01 |
| **Any underground depth, elevation bound, per-domain cell budget or excavation cost** | GAP-03 is explicit: *"Cellar's value is its aboveground entrance; underground depth, floors and excavated volume remain MOVE-G01/G02 work"* | MOVE-G01 |
| **Any life stage but adult** | `residents.gd` has no life-stage column; the cohort is twelve adults | MOVE-G01 + resident-store owner |
| **A profile for the other twelve release-1 species** | Ruling item 1: *"No new synthetic species."* A size class is not a traversal profile | MOVE-G01 |
| **Equipment-to-passage eligibility** | Unstated. Load is checked against the specified carry capacity; gear is not | MOVE-G01 |
| **Yaw zero direction, turn handedness, turn and segment entry/exit costs, body radius, separation strength** | Unchanged from decision 0053 | MOVE-G01 / MOVE-G04 |
| **A short-trip threshold or nearest-point join for the ARCH-PATH-003 macro-anchor detour** | See §7 — the new ruling supplies neither | ARCH-PATH-003 owner |
| **A save schema version number** | No canonical serializer exists to version against | Save owner (task 09.2) |

---

## 6. Full MOVE-G01 continuation — the exact missing artifacts, reconciled against the code

The ruling's G01 table is reproduced with a **code column** that says what exists today. Where the
ruling's row and the code disagree, the disagreement is stated.

| G01 output | Required concrete artifact | Owner | What exists in code today |
|---|---|---|---|
| **Finite geometry** | Underground/water/canopy extents, layer/voxel/contact resolution, all maximum counts | Spatial architect | Only `(DOMAIN_GROUND, LAYER_SURFACE)` on a 512×512 half-metre grid, `DOMAIN_COUNT = 1`, `LAYER_COUNT = 1`. Every other domain/layer refuses `DOMAIN_NOT_CONTRACTED` / `LAYER_NOT_CONTRACTED`. **No overflow or refusal fixture can be written for a capacity that has no number.** |
| **Three construction methods** | Placed burrow, planned tunnel/room and free multilevel excavation state machines; work/material/spoil/support/water/edit/cancel/refund tables | Gameplay/balance architect | **Nothing.** `override_static_legality()` is a whole-map, immediate, non-transactional legality flip that exists only to exercise revision invalidation. `topology_edits.gd` (task 05.6) does not exist. |
| **Full profiles** | Stable IDs/revisions for all release species and life stages, posture/body/equipment/cargo/grip and legal modes | Movement + asset owners | **Partial, and this document is that part.** Stable IDs and revisions exist for four species at one life stage with two modes. **Measured envelopes and the resulting clearances do not exist**, and unsupported states refuse explicitly rather than defaulting. |
| **Mode costs** | Speeds, entry/exit times, load rules, diving air and recovery | Gameplay/engineering owners | Ground speeds and carry capacities are inherited from GDD §5.2 and bound. **No entry/exit duration, no transition cost, no air budget, no recovery rate exists for any mode.** The octile graph has no transition edges at all. |
| **Interruptions** | Needs/cancel/exhaustion/incapacity/death by mode; explicit collapse/flood/fall/drowning policy | Gameplay architect | Four terminal motion phases (`ARRIVED`, `ROUTE_LOST`, `PROFILE_STALE`, `CONTACT_STALE`). **No needs diversion, no exhaustion, no incapacity, no death handling and no hazard policy of any kind.** A matrix whose cells have no outcomes cannot be fixtured. |

### Corrections and additions to the ruling's list

These are places where the ruling's table is incomplete or where the code contradicts an
assumption in it:

1. **The ruling's "Full profiles" row names movement and asset owners jointly, but the blocking
   artifact sits with the asset owner alone.** The profile table needs a *horizontal* envelope.
   `asset_dimensions_and_budgets.md` supplies only *vertical* comparison candidates and explicitly
   disclaims that they set clearance. The proportion comparison scene that GAP-01/02 asks for is
   the prerequisite; until it exists, no measured envelope can be authored by anyone.
2. **There is no `residents.gd` life-stage column.** The ruling asks for "all release species and
   life stages". Before profiles can carry a life stage, the resident store needs the column, which
   belongs to the resident-store owner — a dependency the ruling does not name.
3. **`SpeciesDefinition.rig_id` is required by GDD §4.3 and its value is given for no species
   anywhere.** This blocks MOVE-G04's clip catalog independently of G01, and is recorded in
   `residents.gd`'s own header rather than in the ruling.
4. **The ruling's "Mode costs" row does not mention the graph.** `navigation.gd`'s octile heuristic
   is admissible **only** on the uniform 10/14 lattice. The first nonlocal connection with a
   transition cost breaks the bound. Enabling any second mode therefore also requires the
   expanded-graph Dijkstra comparison SET-MOVE-001 §4 mandates — an engineering dependency between
   two rows of the table that the table presents as independent.
5. **"Contact owner" is named in item 4 but not in the G01 table.** Destination revisions, work and
   approach identities and footprint envelopes are a fifth owner's deliverable, and no G01 row
   currently carries it.

### Ledger rows owed to the owners of `systems_architecture.md` §2.3 and `ready07_arithmetic.py`

Both files are **byte-unchanged by this work** and are reported rather than edited:

| Table | Columns | Rows | Bytes | Status |
|---|---|---:|---:|---|
| `ResidentRouteCursor` fourth column `_cursor_owner_id` | 1 | 512 | **+2048** | Owed since decision 0066 |
| `ResidentTravelAdmission` | `_cursor_profile_id`, `_cursor_profile_revision`, `_cursor_mode`, `_cursor_load_g`, `_cursor_destination_revision` | 512 | **+10240** | New, decision 0083 |
| `StarterGroundProfile` | `_profile_species_id`, `_profile_size_class`, `_profile_speed_u_per_s`, `_profile_carry_g`, `_profile_mode_mask`, `_profile_revision` | 4 | **+96** | New, decision 0083 |

Running total owed: **12384** bytes. `docs/persistence_state_registry.md` **has** been updated with
matching rows and `state_registry_coverage.py` passes; the §2.3 ledger and the arithmetic pin have
not, because their owner is elsewhere.

---

## 7. The ARCH-PATH-003 macro-anchor detour — **the ruling resolves neither fix**

Decision 0053 measured it: implemented literally, every start routes through its macro's anchor, so
cell (100,100) → (104,102) composes to cost **160** against a true optimum of **48**, and a start
whose goal lies back past the anchor retraces its own cells. Bounded by the macro (16 cells);
negligible on a long journey, dominant on a short one.

The two available fixes each need a decision and a number: joining the entry segment to the bucket
at its **nearest point**, or falling back to an **exact-start search below some distance**.

**Neither the 2026-09-11 continuation ruling nor the blocker index mentions ARCH-PATH-003, macro
anchors, entry segments or a short-trip threshold at any point.** `systems_architecture.md`
ARCH-PATH-003 is unchanged. The measurement therefore stays exactly as it is, pinned by
`test_navigation.gd`'s `test_the_macro_anchor_detour_is_measured_not_hidden`, and remains open for
the ARCH-PATH-003 owner.

---

## 8. Test coverage delivered against ruling item 6

| Ruling item 6 clause | Tests |
|---|---|
| all 12 starters | `test_all_twelve_starters_admit_travel_under_their_own_profile` |
| exact contacts | `test_travel_refuses_a_route_that_does_not_end_on_the_contacts_approach_cell`, `test_a_contact_separates_its_work_point_from_the_cell_a_body_stands_on`, `test_a_contact_refuses_an_approach_cell_a_body_cannot_stand_on`, `test_a_contact_accepts_an_unwalkable_work_point_reached_from_a_walkable_approach` |
| retained speed remainders | `test_thirty_ticks_cover_exactly_the_cap_on_a_straight_run`, `test_the_remainder_is_carried_rather_than_reset_each_tick` (05.1a, unchanged and still green under the new admission API) |
| load boundaries | `test_the_committed_load_boundary_is_the_inherited_carry_capacity_exactly`, `test_a_negative_committed_load_refuses_rather_than_reading_as_free_capacity`, `test_an_otter_carries_more_than_a_mouse_because_its_size_class_does` |
| stale profile / contact revisions | `test_revising_a_profile_settles_a_body_already_travelling_under_the_old_one`, `test_a_changed_destination_revision_settles_the_body_contact_stale`, `test_a_contact_minted_before_an_edit_is_no_longer_current` |
| 0/1/2/4 equal-tick behaviour | `test_all_twelve_starters_agree_tick_for_tick_across_speeds_one_two_and_four`, plus 05.1a's single-body `test_equal_tick_counts_agree_across_speeds_one_two_and_four` and `test_a_paused_clock_runs_no_ticks_and_changes_no_state` |
| unsupported mode refusals | `test_only_ground_and_ford_walking_are_profiled_and_the_rest_are_enumerated`, `test_travel_refuses_an_unprofiled_mode_and_a_mode_outside_the_enum`, `test_an_unprofiled_species_refuses_rather_than_borrowing_a_size_neighbour`, `test_travel_refuses_a_life_stage_that_is_not_the_profiled_adult`, `test_no_profile_publishes_a_clearance_class` |
| production save round trip | **BLOCKED** on task 09.2's actual codec, exactly as the ruling states. Registry rows exist; nothing is written to disk. |

---

## 9. What this document does not claim

- It does **not** close MOVE-G01, G02, G03, G04 or G05, and it does not start or advance 05.1b.
- It does **not** declare ordinary resident travel production-correct. Clearance is still
  unspecified, so a route still runs on a **caller-supplied** clearance class, which the ruling is
  explicit is not a species policy.
- It does **not** narrow the adopted scope. Underground, swimming/diving and climbing/canopy remain
  first-release requirements; they are unprofiled in this increment and refuse.
- It reports **no measured performance**, on any hardware. Battle crowd limits are not settlement
  measurements.
- It establishes **no save parity**. The round trip waits for the canonical serializer.
