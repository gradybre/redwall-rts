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
| G4 | **Blocked on a Routes rule (ADR 1210), waiting on Brendan.** Wood and stone haul motion exist (ADRs 1198, 1206), and the foreman now claims inputs from M's own stock. But a source-clocked cutter cannot select the automatic tool-free haul rows (ADR 1168 handoff rule), so one mole cannot unequip, haul and re-equip. The live chain stops with `ENTRY_FOREMAN_INPUT_LOT` at the first BRACE. |
| G5 | **Presentation half done (ADR 1211).** The demo's surface walk brings a cast mole to the stair-top anchor H, and arrival raises `ENTRY_SURFACE_HANDOFF_UNBUILT`. **Open: the simulation half.** Surface Movement must walk the resident, its Transform must be placed exactly on H, it must be admitted to Routes at endpoint 0, and it needs a real route underground. ADR 1211 lists the exact calls. |
| G6 | **Partly done.** Crew selection is real (an adult mole with an equipped tool). Inputs come from the storage container's stock, not caller lots (ADR 1210). Open: reserving the crew from the JobSelector (`JOB_AGENT_BUSY`, `STEP2_ACTIVITY_FORBIDS_WORK` alert as G6). |
| G7 | **Done (ADR 1210).** The runtime plans the whole prefix after crew selection, and `SettlementSystem.run_tick` advances the foreman after ProductiveWork. Refusals raise `UIManager.push_refusal` plus the `gap_of` row once. G5 is checked explicitly (`ENTRY_SURFACE_ARRIVAL_MISSING`). |
| G8 | **Done (ADRs 1201, 1211).** The live demo composes the entry worker's four source Actors and draws rows 29–41 from the simulation's selected row, applying each clip's mask on every draw. Source-0 rows still need the pinned driver hooked up live (ADR 1211, Remaining). |
| G9 | **Prefix done; Kitchen scoped (ADRs 1202, 1205, 1207).** The foreman runs the whole first-entry prefix from the confirmed entry: six cubes, the paid L0 (split landing, `qualified-landing-v4`), the crossing survey and the paid T0, each group INSTALLED exactly once, with exact ledgers. The crossing survey's `SURFACE_ANCHOR_CHECK_CAPACITY` (ADR 1202 blocker 4) was cleared by re-proving only the Locations a change touches (ADR 1207: 551,353 of 1,048,576 checks), and the T0 commit's route budget by ADR 1205. **Open: the Kitchen's own cuts**, scoped in ADR 1202 ("Kitchen excavation: scope"). Brendan placed the Kitchen off T0's far end at the same depth; ADR 1208 records why the authored data cannot carry that as planned (nothing stands past T0, no motion on T0 reaches a Kitchen face, no far opening) and recommends cutting the Kitchen from surface stations like the Corridor's own cubes. Waiting on that choice. |
| **G11 (new)** | **No settlement resident ever gets a tool equipped.** Only tests call `gear.equip`. Equipping tools has to become gameplay, for example from a workshop or stores. The live chain stops with `ENTRY_CREW_NO_TOOLED_MOLE`. |

### G11 decision (Brendan, 2026-10-06)

Moles will take their tools **from stores**. That gameplay is built **later**,
after the overall entry functionality has been tested end to end. Until then,
tests equip a real basic tool lot to an adult mole explicitly, as a labelled
stand-in for stores. The live demo keeps raising the G11 alert.
