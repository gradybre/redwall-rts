# 1205 — Incremental route requalification: recheck only the paths the change touches

Date: 2026-10-06 · Status: Accepted (implements Brendan's 2026-10-06 decision recorded in ADR 1203)

## Decision

A geometry-revision bump (entry confirmation, `SurfaceAnchor.create_in_section`, the contact-path
publisher, phase commits) no longer re-proves every published route edge against the new Space image.
An edge is **carried** to the new revision when nothing that changed since its own certificate's
geometry revision meets any of its profile sweeps. Every other edge is rechecked in full, exactly as
before. The cold check budget (`Space.MAX_CHECKS`, 1,048,576) is unchanged and haul edges are
published permanently, all eight of them.

## Mechanism

### The journal (`underground_geometry_journal.gd`, owned by SpaceOwner)

- **One choke point.** Every SpaceOwner publication path (generic, preflighted, Room, phase,
  installation, furniture, load) swaps the bank group `_commit_columns_0` first, while both banks are
  intact. `Journal.record` runs there and compares, slot by slot, exactly what the traversal snapshot
  copies: visibility (present and not a Room's own reservation marker), effective role (any claim
  reads OBSTACLE) and the half-open box. Each changed slot journals its before side and its after side
  with the target revision and that side's effective role. Nothing relies on callers declaring what
  they changed.
- **Bounded ring.** 256 sides. A full ring evicts its oldest entry and raises the *floor* to that
  entry's revision; a certificate older than the floor is rechecked in full. That is the overflow
  fallback. A revision that is not exactly base + 1 resets the ring (floor = that revision).
- **Staged changes.** For a preparation on a sealed Space stage (`space_token != 0`) the same slot
  comparison runs once, stage against live, into the leased Clearance (`changes`, 256 sides). More
  than 256 means `change_count = -1`: nothing is carried in that proof.

### The carry test (`WorldRoutes._carry_eligible`)

An edge is carried only when all of these hold:

1. The live certificate row has the edge's generation (so the identical immutable polyline and
   endpoint refs), the pinned profile content revision, and the live bank's catalog revision equals the
   pinned one. **Any content or catalog revision change therefore forces a full check.**
2. Its geometry revision `since` satisfies `floor <= since <= base`.
3. For every profile whose kind can serve the edge (certified, same mode, posture and family; no other
   profile can ever be admitted), every box swept along every segment misses every journal side after
   `since` and every staged side. Sides whose role is FLOOR_DATUM are inert: no clearance predicate
   reads a FLOOR_DATUM row (`Clearance.blocked` and `_body_blocked` skip it, coverage subtracts only
   SUPPORTED_VOID, SUPPORT and the pending OBSTACLE bearer, contacts read DRY_SOLID and SUPPORT).

### What a carried edge still does

Per profile, a carried edge reruns everything whose input could change without a geometry revision,
and skips only what its unchanged inputs already proved:

| Input | Carried edge |
|---|---|
| Space image rows (all volume predicates) | Skipped for profiles the live certificate admitted: every row any predicate reads overlaps a sweep, and no changed row does. |
| Endpoint Location (live, generation, refreshed to this revision, still at the path's end) | Rechecked once per endpoint. The payload is immutable per generation (`stage_refresh` never rewrites it), so box containment is not repeated. |
| Surface exclusions (water, resources, Buildings) — live World facts with no revision | Rechecked for every sweep, as before. They spend no proof checks. |
| Kind, pace, ShortStep, heading | Rechecked (content-determined, cheap). |
| Profiles the live certificate refused | Fully rechecked, so a refusal caused by a since-cleared exclusion is lifted exactly as before. |
| Source profiles 2 and 6 | Always fully rechecked: only they may omit a pending installation bearer, and that excuse depends on the installation context, not on geometry. |
| Per-edge Space source/claim pass (`SOURCE_PASS_CHECKS` before and after each edge) | Replaced by the cheap identity check (`prepared_identity_refusal`). A carried edge reads no Space truth beyond the image pinned at `_begin_proof`; the full source/claim pass still runs at begin, at seal and at publication. |

The result is the same certificate a full check would produce. During development a temporary oracle
recompiled every carried edge in full and compared the masks byte for byte across the entry work-area,
host, haul-grip, delivery, paid-assembly, entry-bindings, WorldRoutes and Routes suites: no difference.

## Persistence

The journal is **not saved**; restore empties it with the floor at the loaded revision. Route
certificates are never saved either (registry), so no certificate survives a load to be carried, and
a saved journal would vouch for nothing. After a load the first preparation proves every edge in full,
as it must anyway. If underground save composition ever saves certificates, the journal must be saved
with them. Registry: `underground_geometry_journal.gd` (category 2, §1 WORLD, like the certificates),
WorldRoutes `_envelope` (category 3).

## Measured (entry confirmation, first-entry work area)

`RoomOrders.confirm_entry` in `test_underground_entry_work_area.gd` (WorldRoutes `_proof_checks`, the
checks the sealed proof spent, against the 1,048,576 budget):

| Graph | Requalification | Checks | Share |
|---|---|---:|---:|
| 31 edges (3 haul) | full, before this change (ADR 1198 step 5) | 1,028,537 | 98.1% |
| 36 edges (8 haul) | full (carrying disabled) | refused, `WORLD_ROUTE_CHECK_CAPACITY` | >100% |
| 36 edges (8 haul) | incremental (this ADR) | **321,948** | 30.7% |

The confirmation's only traversal change is the Room's new FLOOR_DATUM row, so all 36 edges carry. The
later phase commits in the same suite also carry all 36 (337–351k). The largest proof left is the
initial work-area publication itself, 483,666, where every edge is new.

A carried edge still costs about 4–7k checks, mostly the full recheck of kind-matching profiles its
certificate refused (see "Carry refusals too" below), against 16k of source brackets plus 4–16k of
compilation before. A rechecked edge costs what it always did. So the work area could grow to roughly
140 edges before carried edges alone reach the budget.

## Also changed

- `underground_entry_work_area.gd` publishes all eight haul edges (ADR 1203 "three haul edges only" is
  superseded): WALK R↔stand R, WALK M↔stand M, CARRY stand R↔stand M, WALK stand R↔stand M. The return
  trip no longer walks M→H→R. The work area has 36 paths; the work-area test fixture's graph arena
  grows from 32 edges/128 vertices to 64/256.
- WorldRoutes `COLD_BYTES` grows by 7,168 (the staged-change sides) to 385,024; the claim-batch
  coexistence pin moves 773,120 → 780,288, still inside `Budget.COLD_BYTES`.

## Rejected

- **Raise the budget** and **publish haul edges on demand**: Brendan's decision.
- **Callers declare their dirty boxes**: one missed call site would be unsound. Diffing the banks at
  the shared swap cannot miss a publication path.
- **A retained copy of the last proof image in WorldRoutes**: a whole snapshot (~230 KB) resident, and
  it cannot cover an anchor commit followed by a separate route refresh.
- **Carry refusals too**: cheaper, but a profile refused for a live exclusion would stay refused until
  nearby geometry changed. Kept exact instead.
- **One whole-edge AABB grown by the union of all profile boxes**: the held-pick swing box (±1256)
  made every work-area path meet the confirmation's change. Per-box, per-segment sweeps do not.
