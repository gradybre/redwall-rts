# 1202 — Entry foreman: the T0 cuts, the contact path, and two blockers before the T0 installation

Date: 2026-10-06 · Status: Accepted. Blockers 1–4 are resolved; the foreman completes the whole first-entry
prefix (see "Blocker 4 resolved" at the end). The Kitchen's own excavation is scoped, not built ("Kitchen
excavation: scope"). ADR 1197 G9 stays open for the Kitchen.

## What was built

### Foreman plan (`underground_entry_foreman.gd`)

- **Plan by installed prefix.** `configure` plans only the episodes whose Frontier prefix field
  (episode field 7) is 0: the L0 cuts, as before. `configure_installation(paid, k)` first appends
  every episode needing prefix `k`, then installation `k`. For `k = 1` that is Frontier episodes 4
  and 5 (BRACE/CUT/FINISH each), then the T0 installation. Nothing is touched while configuring.
- **The T0 cuts use their authored ground stations.** Episodes 4 and 5 name stations 6 and 7, whose
  endpoints 8 and 9 are the work-area surface stations at (∓1536, 0, −2560). The Frontier does not
  station the T0 cuts on the installed L0 contact, and the hand-driven fixture
  (`_complete_first_prefix_cuts`) also walks to ground stations; it only asserts that the installed
  L0 contact stays current. The foreman follows the Frontier.
- **Retreat leg.** Install field 8 is the retreat endpoint. If it differs from the installation's
  station, the next cut's travel first walks to it on that endpoint's own travel profile. For L0 the
  retreat is R on backward source 6, which is the only way off H, because H excludes all-yaw source 12
  (ADR 1191). The leg then continues on the cut station's profile.
- **Plans are resolved when the step starts.** The T0 station is the installed L0 contact, which does not
  exist until L0 commits. Endpoints are therefore resolved when the step begins, not at configuration time.
- **Field fix.** The station of an installation is install field 1, not field 0. The two fields were
  equal for both rows, so behaviour did not change.
- **Retirement.** Only installation 0 retires a pair (episodes 0 and 1, as ADR 1191 requires). Nothing
  showed a geometric need to retire anything before T0.

### Installer (`underground_entry_installer.gd`)

An all-yaw approach that arrives facing the wrong way takes the certified `WorldRoutes.turn_actor` to
the handling heading. A fixed-heading approach still refuses `ENTRY_INSTALLER_HEADING`, so H keeps its
"no turn" rule.

The new turn branch was reached only in the diagnostic experiment described under blocker 2. No
committed test reaches it yet.

### Ground ↔ installed-contact path (`underground_entry_contact_path.gd`, new)

**Why it is needed.** The hand fixture publishes `_l0_ground_connection` itself. In the ADR 1191 work
area there is no such path, and none can qualify, because the surveys leave a real gap:

- The storage footing starts at z = 238 and the installed deck ends at z = 0. Nothing is surveyed as
  SUPPORT for a stance crossing z ∈ (0, 238) at |x| < 1130.
- For |x| < 280 and z ∈ (−280, 280), no surveyed SUPPORTED_VOID exists. The neighbouring air comes from
  the contact's own air (z ≤ −280), the storage air (z ≥ 280) and the outer pair airs (|x| ≥ 280).

**What it does.** The module:

1. Surveys one natural TRANSIT contact through `SurfaceAnchor.create_in_section`, at source-local
   (0, 0, 128). Its foot is `[-406,-1,0,406,0,238]` and its air is `[-280,0,-280,280,1036,280]`.
   Terrain proves the natural support and the exterior air, and the retained-row checks still apply.
2. In one WorldRoutes preparation, requalifies every live edge with `stage_refresh`. This is required:
   the survey advanced the Space revision, and without the refresh the seal refuses
   `ROUTE_EDGE_REVISION`.
3. Stages M → (0, 0, 2048) → contact and its reverse, then seals and publishes. All endpoint, swept
   stance, air and profile proofs stay with WorldRoutes.

The foreman calls it at the start of any installation whose station endpoint is `INSTALLED_CONTACT`.
It needs `Owners.anchor`. The crossing is a TRANSIT Location with no edge of its own: it records the
survey, and it cannot be a source12 endpoint because a ±406 foot around it would overlap the
room-owned deck.

**Result.** All-yaw source 12 reaches the L0 contact from M and returns.

## Blocker 1: T0 admission requires a source2 path that cannot exist

`Contacts._resolve_all_endpoints` checks reachability from the material endpoint to the station using
the **material selector's** travel profile. Install row 1 names material selector 1, which is M with
travel profile 2. Source 2 is a fixed-heading profile that only walks −Z. M is at x = −832 and the L0
contact is at x = 0, so no source2 route can exist under any geometry. `open_order` refuses
`ROUTE_NOT_CONNECTED`.

The fix is a Frontier source successor. Install row 1 should name M's all-yaw copy, selector 10 with
travel 12, which the episodes already use for material (episode field 15). That is source authoring:
it changes the Frontier bytes, `FRONTIER_SHA` and the bundle pins. It is not something to derive at
runtime, so it was not done here.

## Blocker 2: T0 handling footing on the installed deck refuses

To find the next gap, the selector was patched in memory in a throwaway diagnostic test that was not
committed. With the patch:

- the order opens;
- the worker walks to M, turns and approaches the L0 contact on source 12;
- handling admission (row 29) refuses `ASSEMBLY_FOREIGN_SOLID`.

The handling foot box `[-274,-1,-169,299,0,174]` at the contact overlaps the excavation Room claim
region (OBSTACLE, `CLAIM_ROOM`, `[-1024,-1024,-2048,1024,0,0]`). The body and tool boxes overlap only air
and floor datum. `qualified-assembly-v1/physical_certificate.gd::_volume` treats every role other than
FLOOR_DATUM and PROTECTED_ACCESS as foreign solid, including for the foot. As a result, no handling foot
can stand on the installed L0 deck.

This needs a Geometry decision on how a foot on a room-owned installed deck is certified. It was not
changed here.

## Evidence

`test_underground_paid_assembly_handling.gd::test_entry_foreman_runs_t0_cuts_then_t0_admission_refuses_the_narrow_material_selector`.
Only `Foreman.advance(tick)` runs, from a confirmed prefix through:

- all 18 cut phases;
- the paid L0;
- the retreat to R;
- the contact-path publication.

It then refuses exactly `ROUTE_NOT_CONNECTED`. At that point:

| Ledger | Value |
|---|---|
| INSTALLED | 1 |
| Wood | 1,000 (only the T0 bill remains) |
| Stone | 0 |
| Spoil | 12,000 |
| Excavation work | 54,000 mWU |
| L0 fastening | 32,000 mWU |
| Conservation refusals | empty |
| Audits | pass |
| Live Projects | 0 |

Source12 reachability holds in both directions, and source2 reachability from M to the contact refuses.

The requested complete-prefix ledger test (`INSTALLED` = 2, wood 0, 98,000 mWU) was written and run.
It stops at blocker 1, or at blocker 2 when the selector is patched, so it is not committed as a
passing claim.

## Not done

The Kitchen room's own excavation was not scoped, because the prefix does not complete. The Frontier
successor (blocker 1) and the footing certificate (blocker 2) come first. Until then, the live demo's
G9 alert should carry `ROUTE_NOT_CONNECTED`.

## Follow-up (2026-10-06): blocker 1 fixed by a Frontier successor; blocker 2 stopped for a decision

### Why the hand fixture never met either blocker

`test_underground_entry_world_bindings.gd::test_complete_paid_l0_t0_prefix_...` does not load the published
Frontier. It encodes its own (`test_underground_first_prefix.gd::_frontier_image`, revision 31) in which every
endpoint names the same synthetic travel profile, and it publishes the M → L0 path by hand
(`_l0_ground_connection`). It also never enters paid handling (row 29): it moves the worker and selects the
INSTALL profile directly. So it says nothing about selector 1's real source2 profile or about the handling
foot, and it offers no cheaper fix.

### Blocker 1: Frontier successor `qualified-install-v3` (done)

`publish_qualified_install.py` creates `first-entry-prefix-v1/qualified-install-v3/` once from the pinned
`qualified-haul-v2` bytes, following the haul-v2 convention (create-only, every input pinned, refuses any
foreign delta). Exactly two Frontier words change:

- self revision 2 → 3, because the authored install table changed (as revision 1 → 2 did for the endpoints);
- install row 1 (T0), field 7, material selector 1 → 10.

Selector 10 is selector 1's M (same kind, datum, role and point) on all-yaw source 12; the publisher checks
that. Every episode already names it as its material endpoint. Install row 0 (L0) keeps selector 1: its leg
to H is straight −Z on source 2, which is exactly that selector's purpose. Nothing links the Frontier's
digest, so every other file is copied byte-identically; EntryPlan source digests are read from the loaded
Frontier, so they follow automatically. Consumers switched: `underground_route_composition.gd`,
`underground_entry_composition.gd`, `underground_entry_site.gd`, and the work-area and structure-source tests
(the work area's two literal revision-2 values now read `Bundle.FRONTIER_REVISION`). No runtime pin drifted.

With the successor, the foreman's T0 `open_order` admits; the worker walks to M, turns and reaches the L0
contact on source 12.

### Blocker 2: the handling foot meets the Room's own reservation marker (stopped)

Confirmed on the real data: handling admission at the L0 contact refuses `ASSEMBLY_FOREIGN_SOLID`. The foot box
`[-274,-1,-169,299,0,174]` at (0, 0, −1536) is inside the contact's proved SUPPORT (ADR 1193), but its 1-unit
contact layer y ∈ [−1, 0) also lies in the excavation Room's claim region `[-1024,-1024,-2048,1024,0,0]`
(OBSTACLE, `CLAIM_ROOM`). The geometry is not off by one: the claim is the cut cavity, the L0 deck is installed
inside it, and every stance probes 1 unit into its support. Nor is the foot box wrong.

The disagreement is a rule: Space owner (`_traversal_marker`), WorldRoutes and Locations treat a Room's own
typed reservation (CLAIM_ROOM, OBSTACLE, owner = claim) as nonphysical and omit it, and Contacts' bearing proof
skips the same Corridor's marker. `qualified-assembly-v1/physical_certificate.gd::_volume` and its twin
`underground_connector_contacts.gd::_assembly_start_volume` treat it as foreign solid, for bodies and feet.
Both sit in the certified assembly program; `physical_certificate.gd` is recorded by the native-program-v8
evidence (sha `72c3fa5e…`).

Options:

1. **Foot-only own-marker exception (recommended).** In both twins, a foot (already required to lie inside
   the station Location's proved SUPPORT) may overlap only the station Room's own reservation marker:
   CLAIM_ROOM, OBSTACLE, claim = owner = the Location's Room. Bodies and tools keep the current rule; every
   other claim, foreign OBSTACLE and DRY_SOLID still blocks. This matches how every other owner already reads
   the marker, so it has no physical trade-off, but it changes a certified rule and the v8 evidence hash.
2. Cut the claim at the installed deck (claim geometry follows installed parts). This changes Room/claim
   ownership for every installed part and is far wider.
3. Prove the foot against the installed L0 part's SUPPORT row instead of all Regions. This loses the
   "nothing foreign overlaps the foot" check, which is weaker than option 1.

An implementation of option 1 was first attempted here and refused by the session's permission classifier as a
weakening of a security/verification check, so it was not made. The decision belongs to Brendan.

### Evidence

`test_underground_paid_assembly_handling.gd::test_entry_foreman_opens_t0_then_handling_footing_refuses_on_the_l0_deck`:
only `Foreman.advance(tick)` runs from the confirmed prefix through the six cubes, the paid L0, the retreat,
the contact path and the T0 `open_order`, then refuses exactly `ASSEMBLY_FOREIGN_SOLID`. INSTALLED 1, wood
1,000, stone 0, spoil 12,000, 54,000 + 32,000 mWU, conservation refusals empty, audits pass, one live
(unfunded) T0 Project. The complete-prefix ledger test (INSTALLED 2, wood 0, 98,000 mWU) still waits on
blocker 2.

(That test was superseded by the blocker 3 test below.)

## Decision (2026-10-06): Brendan chose option 1, "Feet-only exception (Recommended)"

Implemented in both twins:

- `qualified-assembly-v1/physical_certificate.gd`: `_volume` delegates to `_regions_refusal`, which first
  requires the foot inside the station Location's proved SUPPORT (`ASSEMBLY_FOOTING` otherwise) and then lets a
  foot, and only a foot, skip a Region for which `own_room_marker(owner, row, room)` holds: present, OBSTACLE,
  `CLAIM_ROOM`, claim = owner = the station Location's Room. Admission reads the Room from the admitted
  Location; the per-tick certificate reads it from the worker's current Location.
- `underground_connector_contacts.gd::_assembly_start_volume` → `_assembly_start_regions`, the same predicate
  with `_location.room`.

Bodies and tools are unchanged. Another Room's marker, a Room claim owned by someone else, a Construction
claim, an unclaimed OBSTACLE and an unroomed (surface) station still refuse; so does a foot outside SUPPORT.
`test_underground_assembly_foot_marker.gd` covers each case on a bare Region bank.

Pins: `renew_source_pins.py --write` renewed `underground_connector_contacts.gd` in `qualified-haul-v6`.
`physical_certificate.gd` is not a runtime pin. Its entry (`72c3fa5e…`) in
`haul-handling-v1/evidence/native-program-v8/source-sha256.json` is a historical record of the files present
when that native capture ran, not a live pin: nothing verifies it against current sources, two other entries
(`source_program.gd`, `underground_connector_catalog.gd`) are already stale, and the certificate is not an
input to the captured output. Rewriting it would falsify that record and a re-run would only add a new record
of the same output, so it is left unchanged.

## Blocker 3 (2026-10-06): T0 START — the endpoint certificate only describes H (stopped)

With option 1, T0 handling admission at the L0 contact passes. `start_work` then refuses
`LOCATION_ENVELOPE_BLOCKED` (installer stage FUND). START publishes the pending T0 prism
`[-256,0,-2048,256,128,-1920]` (source-local), which lies inside the L0 contact's declared air
`[-1256,0,-2792,1256,1036,-280]`. Locations allows exactly one such overlap, through
`qualified-assembly-v1/endpoint_certificate.gd::prepared_record_refusal`, and its `_record_refusal` refuses
`ASSEMBLY_ENDPOINT_CERTIFICATE`: the record must have **no Room** and H's **narrow envelope/support words**
(union of profiles 2/6/16/29). The L0 contact is Room-owned and carries the ADR 1193 envelope, which also holds
all-yaw profile 12's body and turn sweep.

This is a real physical conflict, not just a missing case: the T0 bearer sits 384–512 units in front of the
contact, inside the air profile 12 needs to stand and turn there. Once the piece is down, profile 12 cannot
occupy the contact, yet the Frontier names the L0 contact (travel 12) as T0's retreat endpoint.

Options:

1. Extend the endpoint certificate to assembly 1: accept the Room-owned L0 contact with its exact ADR 1193
   envelope. Smallest change, but it certifies an endpoint whose declared profile-12 air the piece occupies,
   so the profile-12 retreat would likely fail next (not verified).
2. **Recommended:** split the landing (revisits ADR 1193). Keep the L0 WORK contact narrow (INSTALL 16 +
   handling 29, the certificate's shape apart from the Room) and give profile 12 a separate TRANSIT arrival
   behind it (+Z, clear of the bearer), with T0's retreat moved there. Needs a Frontier successor (one
   endpoint, install row 1 field 8) and a certificate change that accepts the station Room.
3. Re-author the T0 station or bearer so the piece is outside the profile-12 sweep (source geometry change).

The complete-prefix ledger test (INSTALLED 2, wood 0, 98,000 mWU) waits on this decision, so the Kitchen
excavation is not scoped. Evidence:
`test_underground_paid_assembly_handling.gd::test_entry_foreman_admits_t0_handling_then_start_refuses_on_the_l0_contact_envelope`
— only `Foreman.advance` runs; INSTALLED 1, wood 1,000, stone 0, spoil 12,000, 54,000 + 32,000 mWU,
conservation refusals empty, audits pass, one admitted unstarted T0 Project. The live demo's G9 alert now
carries `LOCATION_ENVELOPE_BLOCKED`.

## Decision (2026-10-06): Brendan chose option 2 for blocker 3, "split the landing"

This revisits ADR 1193. The L0 WORK contact stays narrow, and profile 12 gets a separate arrival point behind it.

### Frontier successor `qualified-landing-v4`

`publish_qualified_landing.py` creates `first-entry-prefix-v1/qualified-landing-v4/` once from the pinned
`qualified-install-v3` bytes. It follows the same convention: create-only, every input pinned, and any foreign
delta refused. `test_publish_qualified_landing.py` checks that the output rebuilds byte for byte. Only Frontier
words change:

- The self revision goes from 3 to 4, and the ENDPOINT count from 12 to 14.
- **Selector 3** (the L0 WORK contact) changes its travel profile from 12 to 2. The value is copied from the
  travel profile of install row 0's station endpoint, which is H's approach. The ADR 1193 union therefore now
  gives the contact exactly H's shape:
  - air `[-445,0,-732,910,1036,346]`;
  - footing `[-274,-1,-274,299,0,249]`.

  These are the endpoint certificate's own words: the union of profiles 2, 6 and 16, plus profile 29's foot.
- **Selector 12** is new: INSTALLED_CONTACT, assembly 0, LANDING datum 1, TRANSIT, travel 12. It sizes the
  arrival.
- **Selector 13** is new: the same point on travel 6, copied from install row 0's retreat selector (R).
- **Install row 1, field 8:** T0's retreat changes from 3 to 13.

**The arrival point is derived, not chosen.** It is `(0, 0, -664)` in source-local coordinates:

- It sits on the contact's x line.
- Its z is the T0 bearer's far face minus the lowest air z of profile 12. The bearer face is −1920, taken from
  install row 1's bearing target. The lowest air z covers every BODY, TURN and APPROACH box (−1256). The
  arrival's air therefore touches the T0 bearer but never overlaps it.
- The publisher proves that the whole profile-12 stance (±406) lies on the LANDING datum and clear of the
  contact's footing.

Consumers now load the successor:

- `underground_route_composition.gd`, `underground_entry_composition.gd` and `underground_entry_site.gd`;
- the work-area, structure-source and frontier-source tests, whose arena grows from 4,112 to 4,192 bytes.

### Runtime

- **EntryBindings** `_timber_new_locations` skips any selector that names the same assembly, datum, role and point
  as an earlier selector. Selectors 12 and 13 are one physical Location reached on two profiles, and the first
  selector sizes it. The paid L0 commit therefore creates the narrow contact and one arrival.
- **Contacts** `_approach_refusal`: when the material selector's travel profile differs from the station
  endpoint's, admission proves two legs:
  1. material to retreat (the arrival) on the material profile;
  2. arrival to station on the station's profile.

  Otherwise it proves material to station, as before. The station-to-retreat proof is unchanged. L0 and every
  cut episode have equal profiles, so they keep the direct proof.
- **Endpoint certificate** `_record_room_matches`:
  - assembly 0 (H) still requires no Room and level 0;
  - assembly 1 requires the Placement's own permanent Room and the Placement's level.

  The envelope, support, point, bearer and snapshot words are unchanged.
- **ContactPath** publishes M ↔ arrival on the existing bend polyline. It then publishes arrival ↔ contact as one
  straight leg in the contact's section, Room and level. Routes requires the edge's Room to match its section's
  owner.
- **Foreman and installer.** `_plan_arrival` adds an arrival leg whenever M's profile is not the station's
  approach profile. The installer's new stage `STAGE_LEG_ARRIVAL` (9) runs:
  1. walk from M to the arrival on source 12;
  2. take the certified turn to yaw 0;
  3. walk from the arrival to the contact on source 2.
- **Retirement scope.** The Frontier shape is now `ENDPOINTS = 14`, with derived sizes `SOURCE32 = 462` and
  `SOURCE64 = 72`. The persistence registry rows are updated to match.

### ADR 1193 for L0

The ADR 1193 mechanism stays in code: a WORK contact's footing and air are the union of its station profile and
its selector's travel profile. Its effect on L0 changes. L0's selector now names source 2, so the 812 × 812
profile-12 widening no longer applies to the L0 contact. That footing and air now belong to the arrival.

## Blocker 4 (2026-10-06): the crossing survey exceeds SurfaceAnchor's check budget (stopped)

`test_entry_foreman_splits_the_l0_landing_then_the_crossing_survey_exceeds_the_anchor_check_budget` runs only
`Foreman.advance`. Six cubes and the paid L0 complete. The L0 commit creates the narrow contact (H's exact words)
and one arrival, whose air ends at the bearer's far face. When T0 begins, `ContactPath` refuses
`SURFACE_ANCHOR_CHECK_CAPACITY` before the order opens. The ledgers at that point:

| Ledger | Value |
|---|---|
| INSTALLED | 1 |
| Wood | 1,000 |
| Stone | 0 |
| Spoil | 12,000 |
| Work | 54,000 + 32,000 mWU |
| Conservation refusals | empty |
| Audits | pass |
| Live Projects | 0 |

**Cause, measured.** One `SurfaceAnchor.create` re-proves the World final facts twice for every live Location
that Locations refreshes. Each proof costs 8,192 + 20,451 checks, so each live Location costs about 57,000 of
the 1,048,576 budget. The work area's last create already left only 46,743 checks. The crossing survey now
refreshes one more Location (the arrival), so it no longer fits. This is not a geometry refusal. It is the
Location-refresh counterpart of the route budget in ADR 1198 and ADR 1203.

### Diagnostic (not committed)

The SurfaceAnchor budget was doubled locally to see what comes next:

- The path publishes.
- T0 opens, reaches the arrival and then the contact, is admitted to handling, STARTs (the certificate accepts
  the Room-owned contact), handles, and fastens.
- T0 COMMIT then refuses `WORLD_ROUTE_CHECK_CAPACITY`, because it requalifies every route edge. This is the route
  budget that another worker is making incremental, under Brendan's ADR 1203 rule.

The WorldRoutes proof budget was then also doubled. With both doubled, the complete-prefix test passes:

| Ledger | Value |
|---|---|
| INSTALLED | 2 |
| Wood | 0 |
| Stone | 0 |
| Spoil | 12,000 |
| Work | 98,000 mWU |
| Conservation refusals | empty |
| Audits | pass |
| Live Projects | 0 |

Reachability in that run: source 12 reaches M ↔ arrival, source 2 reaches arrival → contact, source 6 reaches
contact → arrival, and source 12 is refused onto the contact. Both doublings were reverted.

### Options

1. **Recommended: apply ADR 1203's "re-check only what changed" rule to Location refresh.** A World preparation
   such as a SurfaceAnchor create would re-prove only the Locations whose envelope or support meets the newly
   staged boxes. Untouched records would carry forward unchanged under the same revision chain. This is the
   same safety argument Brendan accepted for routes, and the cost then scales with the change. It belongs with
   the WorldRoutes incremental work, which is already in flight.
2. Prove the World scope's final facts once per sealed candidate, instead of twice per refreshed Location. This
   is cheaper to build, but it changes the re-proof pattern of a verification path.
3. Retire finished endpoints: H after the L0 commit, the episode 2 and 3 stations after their cuts, and the T0
   cut stations after T0's cuts. This gains three to five Locations of headroom. The Kitchen's own endpoints
   will use that up.
4. Raise the domain check budget. This was declined for routes in ADR 1203.

The complete-prefix test waits on this choice and on the route budget, so the Kitchen excavation is still not
scoped. The live demo's G9 alert now carries `SURFACE_ANCHOR_CHECK_CAPACITY`.

## Decision (2026-10-06): Brendan chose option 1 for blocker 4, "re-check only touched Locations"

### Blocker 4 resolved (ADR 1207)

A World preparation now carries every existing Location whose air and footing no change since its own proof
touches (full-view geometry journal, a direct blocker scan, identity facts rerun); touched ones are re-proved
as before. A carried Location spends none of SurfaceAnchor's checks. Measured:

| Create | Before | After |
|---|---:|---:|
| Last work-area create (11 Locations) | 1,001,833 | 775,313 |
| T0 crossing survey (12 Locations) | refused `SURFACE_ANCHOR_CHECK_CAPACITY` | 551,353 (9 carried, 2 re-proved) |

The route budget at the T0 commit is incremental already (ADR 1205), and no other blocker appeared. The
blocker-4 test became `test_entry_foreman_runs_the_complete_prefix_from_the_confirmed_prefix`, driven only by
`Foreman.advance` from the confirmed prefix:

| Ledger | Value |
|---|---|
| INSTALLED | 2 (L0 and T0, each exactly once) |
| Wood | 0 |
| Stone | 0 |
| Spoil | 12,000 |
| Work | 54,000 cut + 44,000 fastening = 98,000 mWU |
| Conservation refusals | empty |
| Audits | pass |
| Live Projects | 0 |

Reachability: source 12 M ↔ arrival, source 2 arrival → contact, source 6 contact → arrival; source 12 is
refused onto the narrow contact.

## Kitchen excavation: scope (not implemented)

### What exists (component level, proven only in tests)

- **Room admission.** `RoomOrders.confirm_room` (`underground_room_orders.gd`) admits a painted Room and
  splits its cells into one Site per metre cube (`_prepare_room_claims` → `Sites.prepare_room_claim_batch_into`).
  It requires an `Approach.Request` (`underground_room_approach.gd`): an existing access Location, an existing
  WORK Location, travel/work profiles, the first target cube, face and yaw (ADR 1150). The mounted session binds
  the approach observer (`underground_route_composition.gd` `configure_room_approach`); nothing in production
  builds a request. The only Kitchen is the fixture in `test_underground_room_world_phases.gd` (`room_request`:
  2×2 at level 1, height 4096, 16 cubes, bootstrapped corridor endpoints).
- **Paid phases.** Sites' phase API (`open_phase`, `bind_job`, `bind_material_container`, `bind_output`,
  `begin_phase_work`, `settle_phase`) is generic and works for Room Sites.
- **Phase contacts for Room Sites.** `underground_room_world_bindings.gd` `bind_room_phase_contacts` selects the
  unique ROLE_WORK Location whose contact lies on the target face, with one fixed retreat and travel profile.
  Only tests call it; entry composition binds only the entry provider.
- **Next cube.** `underground_room_frontier.gd` `next_site_into` walks the Room's Sites in canonical order and
  derives BRACE/CUT/FINISH; `contact_into` proves an existing contact or refuses
  `ROOM_FRONTIER_EXISTING_CONTACT_REQUIRED`.
- **New stations.** `underground_room_frontier_publication.gd` `publish_into` publishes a gateway plus 1–3
  Locations and their spans on already-paid Space (ADR 1161). The caller supplies every section, point,
  profile, face and yaw.
- **Itineraries.** `underground_room_itinerary.gd` (ADRs 1165/1172).
- **The foreman's per-task loop** (open, travel, enter, start, earn, recover) is reusable; only its task source
  (Frontier EPISODE rows) is entry-specific.
- One Kitchen cube (BRACE/CUT/FINISH plus retreat) is proven end to end in `test_underground_room_world_phases.gd`.

### What is missing

1. **Geometry from T0 to the Kitchen.** `confirm_entry` admits only the Corridor; its far opening is null
   (`underground_entry_site.gd` `entry_plan`, `opening_targets`), and the prefix artifact
   (`first-entry-prefix-v1.json`) leaves the half metre beyond T0 nontraversable and excludes room completion.
   No authored descent reaches the Kitchen's depth.
2. **A Kitchen confirmation step in the runtime** (`underground_entry_runtime.gd` has no room step): a painted
   plan whose first cube is face-adjacent to the reachable end, and an `Approach.Request` built from live
   Locations (access = the installed T0 contact or the arrival).
3. **Mounted Room phase binding**: `bind_room_phase_contacts` in entry composition, with a retreat and travel
   profile that suit every cube (it binds once).
4. **A Room-station planner**: from a Site key, face and yaw, derive the `FrontierPublication.Request` (gateway,
   stations, profiles). This is the Room counterpart of the Frontier STATION/ENDPOINT rows and the core missing
   piece. Interior cubes need underground standing Locations on cut floor; upper cubes need the 232u step source,
   and a multi-heading retreat needs more than the single backward-9 retreat (ADR 1161's three open seams).
5. **A foreman Room loop**: after the last installation, repeat `next_site_into` → plan → `publish_into` →
   `contact_into` → the existing phase loop, until the scan ends and every Kitchen Site is SUPPORTED_VOID.
6. **Logistics.** Delivery pins cut Projects to the entry Placement (`underground_connector_delivery.gd`
   `_pin_project`, `_entry_placement`); Room Projects need their own pin. Spoil and inputs sit at surface M/R, so
   they need routes from Room stations or underground staging. Haul motion (G4, ADR 1198) and the stone carry
   (ADR 1203) remain open.
7. **Budgets.** Each published Room station adds route edges (ADR 1205) and Locations. Room stations are
   published by Room/phase preparations, which ADR 1207 did not make incremental. Measure as stations land.

### Ordered steps

1. **Brendan: where the Kitchen sits relative to the entry** and how T0 connects to it (a stair/descent of
   further Frontier rows, or the Kitchen's first face placed at T0's far end). Everything below depends on it.
2. Author that connection (Frontier successor or descent episodes) and prove it on the hand fixture.
3. Runtime Kitchen confirmation: build the `Approach.Request` from live Locations; `confirm_room`.
4. Compose `bind_room_phase_contacts` in entry composition.
5. Room-station planner; prove it on the ADR 1161 fixture's lower and upper cubes (closing the 232u step and
   retreat seams).
6. Foreman Room loop to all 16 Sites SUPPORTED_VOID, with exact ledgers.
7. Delivery pinning for Room Projects and underground spoil/input logistics.
8. Live demo: one G9 alert code per missing row until each lands.
