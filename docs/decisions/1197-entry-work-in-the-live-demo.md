# 1197 — Running the first-entry work in the live demo, with explicit "not built yet" alerts

Date: 2026-10-06 · Status: Accepted direction; implementation in progress

## Brendan's direction

> Build this work into the existing demo work (all of it) so that it takes
> advantage of everything already built, including surface walking, and then
> can properly alert to anything new we need to build out.

For brace and stone inputs, Brendan chose to **extend Delivery to the
excavation cuts**, giving one real haul path for cut and installation inputs.

## What this means

The demo runs the real chain end to end on fixed ticks:

1. Mount.
2. Compose the room, route, surface and entry owners.
3. Publish the work area.
4. Confirm the entry.
5. The foreman takes it from there: cuts, retirement, paid handling,
   installation, then T0 and the room.

It reuses everything that already exists, including the demo's presentation
surface walking. **Where a required piece does not exist, the game must not
fake it or stall silently.** It raises a visible alert through
`UIManager.push_refusal`, naming the missing capability and keeping the exact
refusal code. Each alert maps to a row in the table below. Building that row
clears the alert.

## Gaps, in build order

| # | Gap | Today | Plan |
|---|---|---|---|
| G1 | Work-area publication | Only test fixtures create the nine entry Locations and 28 paths | Runtime publisher from the ADR 1190 bundle and the ADR 1191 layout. It goes through SurfaceAnchor and real WorldRoutes publication, against actual terrain. |
| G2 | Entry confirmation in the demo | The demo only calls `confirm_room` | `RoomOrders.confirm_entry` with the bundle's EntryPlan at the chosen origin. |
| G3 | Delivery for cuts | `Delivery._pin_project` accepts only `PURPOSE_CONNECTOR_INSTALL` | Extend it to excavation phase Projects, with the same final guards. |
| G4 | Surface stock as a haul source | Surface stock has no spatial Location | Stage settlement stock at the anchor (`create_spatial_ground_staging`), then haul through Delivery. |
| G5 | Surface arrival | Residents do not walk in the simulation (`settlement_system.gd:120-135`) | The demo's presentation walk brings the resident to the stair-top anchor. The simulation hand-off places the Transform exactly on the anchor point, then `admit_travel_actor` (WALK) and a real route underground. The hand-off is shown as a known gap until surface Movement/Navigation is composed. |
| G6 | Crew selection | Tests pass the worker, tool and lots explicitly | Choose a real demo resident with an equipped tool, and real stock lots. Refuse with an alert when none qualifies. |
| G7 | Fixed-tick hookup | Nothing calls `Foreman.advance` | `SettlementSystem.run_tick` advances the foreman. |
| G8 | Row 29 presentation | The actor matches rows by actor source digest, so handling has no clip | Alert until a handling clip or reviewed fallback exists. **Presentation built (ADR 1201):** per-source Content and Actor, with row 29 drawn from the handling clock. The live demo still composes no worker Actor. |
| G9 | T0 and the room | The foreman stops after L0 | Extend it to T0 (ADR 1193 unblocked it) and to the Kitchen's own cuts. |
| G10 | Saving the cursor | Registry rows are UNRESOLVED | Decide re-derive vs save; alert on save while dispatch is in flight. |

## Alert rule

An alert carries the exact refusal code and the gap row (G#). It never offers a
workaround that grants work or movement. A completed step's world state is
never rolled back to hide a later gap.

## Status (2026-10-06)

| # | State |
|---|---|
| G1 | **Done.** `underground_entry_work_area.gd` (`7af6e990`) and the read-only site survey and suggestion in `underground_entry_site.gd` (`d9688b48`) publish all 9 endpoints and 28 paths on generated ground. |
| G2 | **Done.** The EntryPlan comes from the bundle, and `confirm_entry` succeeds on a real settlement (`8f7c7b37`, which also fixed a per-slot budget scaling bug). |
| G3 | **Done.** Delivery hauls cut inputs (`6936d505`). |
| G4 | **Blocked on mole haul motion** (ADR 1198, in progress). The live chain stops with `ENTRY_INPUTS_NOT_DELIVERED`. |
| G6 | **Partly done.** Crew selection is real (an adult mole with an equipped tool). |
| G7 | The Host API `begin_underground_entry` runs the chain (`93977843`). Foreman ticking starts once G4 clears. |
| G9 | **Partly done (ADR 1202).** The foreman runs the T0 cuts after L0 and publishes the ground ↔ L0-contact path. The Frontier successor `qualified-install-v3` lets the T0 order open; the T0 installation is blocked by the handling footing certificate on the deck (`ASSEMBLY_FOREIGN_SOLID`), which awaits a decision (ADR 1202 follow-up). The Kitchen excavation is not scoped yet. |
| **G11 (new)** | **No settlement resident ever gets a tool equipped.** Only tests call `gear.equip`. Equipping tools has to become gameplay, for example from a workshop or stores. The live chain stops with `ENTRY_CREW_NO_TOOLED_MOLE`. |

### G11 decision (Brendan, 2026-10-06)

Moles will take their tools **from stores**. That gameplay is built **later**,
after the overall entry functionality has been tested end to end. Until then,
tests equip a real basic tool lot to an adult mole explicitly, as a labelled
stand-in for stores. The live demo keeps raising the G11 alert.
