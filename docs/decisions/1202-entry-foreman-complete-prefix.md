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
