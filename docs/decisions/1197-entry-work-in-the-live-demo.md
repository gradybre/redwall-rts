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
| G8 | Row 29 presentation | The actor matches rows by actor source digest, so handling has no clip | Alert until a handling clip or reviewed fallback exists. **Presentation built (ADR 1201):** per-source Content and Actor, with row 29 drawn from the handling clock. **Live demo composition built (ADR 1211):** one worker Actor per source (stone included) for the entry crew, drawn from the selected row. |
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
| G4 | **Done for the hauling half (ADR 1210).** With Brendan's switch at rest (ADR 1168 amended), the foreman puts its tool down at M, hauls every missing whole unit of wood (lift row 34) and stone (row 39) from R's staging through Delivery, and re-equips. The hauled complete prefix installs L0 and T0 once with exact ledgers (9 trips, 500 wood and 500 stone left at M). **Open:** moving settlement stores to R's staging (`ENTRY_HAUL_NO_STAGED_STOCK`); tests stage the stock as a stand-in. |
| G5 | **Done (ADR 1219, registration on arrival).** The crew mole walks from its surface pose to H over BAL-WORK-003's straight-leg tick count (no surface path is modelled; Navigation/Movement are not composed), is placed exactly on H at its authored heading, and the foreman registers it there on H's own approach row, then leaves by the authored retreat. Only the crew is a route actor: every occupancy proof now bounds an unregistered living resident by a conservative reach cube around its Transform (`ROUTE_UNREGISTERED_RESIDENT_NEAR`, G5 alert), so `ROUTE_TURN_ACTOR_UNBOUND` is no longer a stop. Routes has no unregister; the crew stays registered after the prefix. The live chain now runs from the surface through the first brace's hauls and stops at G6 (`JOB_HAS_WORKER`). |
| G6 | **Partly done.** Crew selection is real (an adult mole with an equipped tool). Inputs come from the storage container's stock, not caller lots (ADR 1210). Open: reserving the crew from the JobSelector (`JOB_AGENT_BUSY`, `STEP2_ACTIVITY_FORBIDS_WORK` alert as G6). **Live stop since ADR 1219:** while the crew hauls, the JobSelector hands the step's unassigned BUILD Job to an idle surface resident, and the crew's walk home refuses `JOB_HAS_WORKER` (G6). |
| G7 | **Done (ADR 1210).** The runtime plans the whole prefix after crew selection, and `SettlementSystem.run_tick` advances the foreman after ProductiveWork. Refusals raise `UIManager.push_refusal` plus the `gap_of` row once. G5 is checked explicitly (`ENTRY_SURFACE_ARRIVAL_MISSING`). |
| G8 | **Done (ADRs 1201, 1211).** The live demo composes the entry worker's four source Actors and draws rows 29–41 from the simulation's selected row, applying each clip's mask on every draw. Source-0 rows still need the pinned driver hooked up live (ADR 1211, Remaining). |
| G9 | **Prefix done; Kitchen scoped (ADRs 1202, 1205, 1207).** The foreman runs the whole first-entry prefix from the confirmed entry: six cubes, the paid L0 (split landing, `qualified-landing-v4`), the crossing survey and the paid T0, each group INSTALLED exactly once, with exact ledgers. The crossing survey's `SURFACE_ANCHOR_CHECK_CAPACITY` (ADR 1202 blocker 4) was cleared by re-proving only the Locations a change touches (ADR 1207: 551,353 of 1,048,576 checks), and the T0 commit's route budget by ADR 1205. **Open: the Kitchen's own cuts**, scoped in ADR 1202 ("Kitchen excavation: scope"). Brendan placed the Kitchen off T0's far end at the same depth; ADR 1208 records why the authored data cannot carry that as planned (nothing stands past T0, no motion on T0 reaches a Kitchen face, no far opening) and recommends cutting the Kitchen from surface stations like the Corridor's own cubes. Waiting on that choice. |
| **G11 (new)** | **No settlement resident ever gets a tool equipped.** Only tests call `gear.equip`. Equipping tools has to become gameplay, for example from a workshop or stores. The live chain stops with `ENTRY_CREW_NO_TOOLED_MOLE`. **Amended by DEC-052 (ADR 1217): moles dig with claws and fit by paw, so tool equipping no longer blocks the first entry. The alert stays until the claw and paw rows land; crew selection then stops requiring a tool and this code is retired.** |

### G11 decision (Brendan, 2026-10-06)

Moles will take their tools **from stores**. That gameplay is built **later**,
after the overall entry functionality has been tested end to end. Until then,
tests equip a real basic tool lot to an adult mole explicitly, as a labelled
stand-in for stores. The live demo keeps raising the G11 alert.

### G11 amended (DEC-052, 2026-10-07)

Brendan scrapped tools for now: all digging uses the claws and timber is fitted by paw (ADR 1217). The stores
plan above is parked. G11 no longer blocks the first entry; the live demo keeps raising the alert only until claw
and paw rows are published and `_select_crew` stops requiring an equipped tool.
