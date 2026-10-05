# 1175 — Actual World terrain view for underground planning

Status: Accepted as a presentation component after independent root source/native review, 2026-10-05.

D29 requires drawing on the real World at its selected integer floor. The older
village ground is an authored presentation layout near a different origin; it
cannot provide this terrain view. This additive presentation owner borrows the
running WorldInit, its full World reference, immutable Domain and LevelCatalog.
It never creates World, Space, Room, support, routes, actors or terrain colliders.

## Interface and lifetime

`configure(world, full_ref, domain, levels, surface_layer, slice_layer)` builds
once from all 16,384 actual `terrain_into` rows. The view accepts the concrete
World/Level/Directory source and their exact original published identity. The caller passes the original Session-owned Domain, not a temporary `domain_copy()`. It
retains weak owner references and copies bounded metadata, not canonical stores.
Every floor selection validates the original owners and source; a stale view
hides itself. `clear_view()` releases presentation resources and permits a new
mount. `bounds_into()` copies the six exact Domain bounds into caller scratch.
The root controller owns camera, input, HUD, actual Session lifetime and reset.

`set_floor(level_id, section_offset_u = 0)` uses the actual LevelCatalog. Surface
ID 0 has land at 512u (0.5m) and water at 0u. The root node stays at identity and
XZ coordinates never change. The reusable section mesh has local Y=0 and its
child's Y translation is precisely the selected catalog floor / 1024; this is
the true plane mapping, not a visual position offset or a physics correction.
Normals, metre UV lengths and explicit tangent handedness retain the actual face axes. Existing earth material supplies its
presentation noise in this section-local Y frame; it has no geometric authority.

## Geometry and appearance

Contiguous same-kind row runs merge into exact rectangles; no run crosses a
terrain-kind boundary. Four surface categories retain Coast/River/Lake/Land.
All land-to-water steps are 512u vertical faces on exact 2048u tile edges. The
existing grounded earth shader and world palette are reused without any old
village path/clearing mask. No AI generation or paid service is involved.

Below ground, the opaque surface is hidden. Actual surface boundary lines remain
at their true heights with no depth write and below the planning overlay's draw
priority. The selected plane shows raw unexcavated earth. The exact Terrain natural-floor rule includes solid earth below the shallow ford’s -128u bed. Other protected wet columns
use a distinct subdued **planning projection**, not a claim of water depth,
a room, a completed floor or a traversable opening. The view contains no paid
Space/Room subtraction: subsequent excavation presentation requires its own
actual owner composition. Root's floor grid and draft overlay use the same
integer plane; this view does not pick or validate a cell.

## Bounds and verification

The producer is restricted to the existing finite 128×128×2m World and exact
Domain metadata. Packed mesh buffers are counted before allocation. Mount-only
staging, retained buffers, mesh/native ownership and maximum mathematical
capacity are reported separately from the existing authoritative store budget.
No asserted allocation is a measured whole-client memory result. There are no
per-tile nodes and no mesh rebuilding in the frame loop or on floor selection.

Tests must cover actual terrain coverage, boundaries, winding/normals/UV scale,
weak lifetime and stale generation/source refusal, exact catalog floors, refusal
preservation and unchanged canonical data. A separate windowed 1280×720 native
witness will inspect surface kinds and selected-floor preview readability, and
record actual build time. Component evidence is not playable-room, whole-demo,
whole-client memory or performance qualification.

## Final component candidate

Candidate5 passes 10 focused tests / 51,358 assertions, strict/raw/leaks zero and analyzer zero warnings in three files. Native5 is actual Metal/Forward+ at 1280×720: 25 checks, no failures and four images on the original World and selected -4.5m plane. Thirteen Python evidence tests pass. Complete run history and reproduction are under `docs/validation/evidence/underground-actual-world-view-2026-10-05/`. Root independently reviewed the exact frozen source and all four native images; no high/medium finding remains. Component-only limits below remain unchanged.

The payload census includes four weak borrows, 300 actual fixed/metadata bytes, 310,512 actual raw mesh bytes (15,673,344 at the finite checkerboard capacity), one surface's staging and explicit old/new illustrative coexistence. Native allocator/renderer/noise-worker temporaries remain unmeasured; no global or authoritative memory ceiling is changed. Final native mount measured 73,962µs; finite checkerboard build measured 178,909µs in the focused headless test. These single mount-only samples do not qualify steady UI performance or target hardware.
