# 1202 — Entry foreman: the T0 cuts, the contact path, and two blockers before the T0 installation

Date: 2026-10-06 · Status: Accepted (partial). ADR 1197 G9 is **not closed**: the T0 installation is
blocked by the two findings below, so the Kitchen excavation was not scoped.

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
