# Injury authority excerpts

These are exact source excerpts for engineering review, not new policy.

## docs/game_gdd.md
SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e

148: | ProductionOrder | recipe_id: int32, building: EntityRef, mode: enum, target_milli: int64, priority: int32, completed_batches: int32, enabled: bool | At most 32 orders/building |
149: | Job | kind: enum, requester: EntityRef, destination: EntityRef, source: EntityRef, priority: int32, required_skill: int32, remaining_mwu: int64, state: enum, created_tick: int64, worker: EntityRef | At most 8192 active/queued jobs |
150: | FishHabitat | type: enum, zone: EntityRef, capacity_milli: int64, effort_slots: int32, pollution: int32, danger: int32, protected_fraction: int32, **effort_used: int32**, **intensive_harvest: bool** | One per marked water basin; up to 32 — an **allocation ceiling**, not a generation count (READY_06 §8B). `zone` refers exclusively to the owning basin, never to a player designation, and exactly one habitat may name a given basin reference. Bold fields ratified 2026-09-09 (decision 0027): `effort_slots` is a capacity and `effort_used` its occupancy; `intensive_harvest` is §5.4's explicitly visible policy |
151: | FishStock | habitat: EntityRef, species_id: int32, population_milli: int64, capacity_milli: int64, harvested_today_milli: int64, closed: bool, **restocking: bool** | 3 stocks/habitat; no shared global fish counter. `stock_row = habitat_typed_slot * 3 + species_index`. Bold field ratified 2026-09-09 (decision 0027): REQ-SET-048's 30-down/40-up latch |
152: | FishingEffortClaim | active: bool, expedition_generation: int32, habitat: EntityRef, job: EntityRef, slot_count: int32 | One per owning Expedition, `claim_row = owning_expedition_typed_row` within the 512 Expedition rows (READY_06 §5, decision 0037). A cycle reserves its whole gear requirement atomically; only its coordinator Job owns the claim |
153: | HarvestZone | type: enum, tiles: packed int32[], danger: int32, quota_milli: int64, protected: bool, enabled: bool, **basin: EntityRef**, **harvested_today_milli: int64**, **quota_reserved_milli: int64**, **quota_mode: enum** | Up to 128; tile membership max 16384 total zone links. Bold fields ruled 2026-09-09 (decisions 0026, 0030): `quota_milli` is a **daily** limit on total forage across all five kinds, shared by the basin; a designation may be stricter but never larger in effect |
154: | FaunaStockReserved | zone: EntityRef, species_id: int32, population: int32, capacity: int32, tracks: int32, harvest_today: int32, migration_link: int32, birth_remainder: int64 | Reserved allocation only: all numeric fields 0, refs (-1,0), no active rows or updates |
155: | ForagePatch | zone: EntityRef, item_id: int32, stock_milli: int64, capacity_milli: int64, harvested_year_milli: int64 | 5 patches per **basin** (decision 0026); `zone` refers exclusively to the owning basin, never to a player designation, so overlapping designations share one stock. `patch_row = basin_typed_slot * 5 + patch_kind`, kinds Berries 0, Nuts 1, Mushrooms 2, Herb 3, Roots 4. `harvested_year_milli` is annual ecological history, **not** the quota accumulator (decision 0030) |
156: | ForageClaim | active: bool, job: EntityRef, designation: EntityRef, basin: EntityRef, patch_kind: int32, remaining_milli: int64 | One per owning Job, `claim_row = owning_job_typed_row` within the 8192 Job rows (decision 0030). Uncollected forage is ecological stock, not an InventoryLot |
157: | ResourceNode | resource_id: int32, quantity_milli: int64, capacity_milli: int64, regrow_days: int32, planted_day: int32, exhausted: bool | Tree/stone/iron source; at most 4096 |
158: | Expedition | kind: enum, zone: EntityRef, member_ids: int32[3], member_count: int32, phase: enum, remaining_mwu: int64, cargo: EntityRef, hazard_roll: int32, consent: bool | Fishing 1–2 members; third member slot reserved empty; one job/member |
159: | FarmPlot | crop_id: int32, state: enum, soil: enum, fertility: int32, moisture: int32, growth_milli_hours: int64, health: int32, last_family: int32, family_streak: int32, compost_milli: int64, sow_day: int32 | One per 2 m tile; up to 4096 active farm tiles |
160: | OrchardPlot | species_id: int32, age_days: int32, health: int32, tended_today: bool, harvested_year: bool, chill_days: int32 | One per 4×4 farm-tile orchard block |
161: | Hive | building: EntityRef, strength: int32, feed_milli: int64, serviced_day: int32, honey_milli: int64, wax_milli: int64 | One per apiary; six pollination links max per field block |
162: | Weather | event: enum, start_day: int32, duration_days: int32, temperature_tenths: int32, rain: int32, forecast: int32[3] | One active major event/world; daily baseline independently |
163: | Feast | recipe_theme: enum, state: enum, attendees: int32[], reserved_lots: int32[], start_tick: int64, capacity: int32, coverage: int32 | At most 1 scheduled/active feast |
164: | Progress | milestone: enum, unlocked_mask: int64, victory_streak_days: int32, mastered_recipe_mask: int64, feasts_completed: int32, charter_awarded: bool | Exactly 1 |
165: | Notice | severity: enum, category: enum, source: EntityRef, code: StringName, created_tick: int64, resolved: bool, acknowledged: bool | 500 history entries; deduplicated active key(code, source) |
166: | TransferManifest | manifest_id: int32, resident_ids: int32[], item_lot_ids: int32[], quantity_milli: int64[], status: enum, rules_hash: StringName | Inactive future adapter; no army entity in this release |
167: 
168: **Ruled 2026-09-11 (READY_07 §2) — resource identity.** `ResourceNode.resource_id` identifies the extracted output's compiled `ItemDefinition` ID: `wood`, `stone` and `iron`. `ForagePatch.item_id` and `FishStock.species_id` use the same domain — `berries, nuts, mushrooms, herb, roots` and `trout, dace, salmon, perch, carp, whitefish, herring, mackerel, mussel`. These seventeen bindings are resolved by key against the compiled catalog and its verified `catalog_ids.json` hash; no generic `tree`, `forage` or `fish` ItemDefinition exists, and `fish` in a recipe is a selector over the approved nine species keys rather than a runtime stock item. Patch kind, fish species row and habitat type remain **different indexes from the item ID**: a compiled item ID never subscripts the five-row patch or nine-row species tables. See decision 0052.
169: 
170: `StringName name_key` references a localized authored name or sanitized player alias; it is not part of simulation ordering. Selection flags, navigation debug visuals, skin palettes, and scene nodes are outside saved gameplay truth. Child-array capacities are hard validation limits, with explicit refusal when full.
171: 
172: Additional fixed child stores close persistence requirements used by the job and UI contracts:
173: 

208: | RoomType | DORMITORY=0, PRIVATE_ROOM=1, KITCHEN=2, DINING=3, COMMON=4, INFIRMARY=5, PANTRY=6, CORRIDOR=7 |
209: | BuildingState | BLUEPRINT=0, BUILDING=1, ACTIVE=2, PAUSED=3, DAMAGED=4, DEMOLISHING=5 |
210: | Milestone | M0=0, M1=1, M2=2, M3=3, M4=4; protected domain, Start maps to M0 |
211: | Soil | LOAM=0, CLAY=1, SAND=2 |
212: | CropState | EMPTY=0, SOWN=1, GROWING=2, RIPE=3, WITHERED=4 |
213: | OrderMode | ONCE=0, REPEAT=1, MAINTAIN_STOCK=2 |
214: | Quality | POOR=0, PLAIN=1, GOOD=2, EXCELLENT=3 |
215: | InjuryKind | NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5 |
216: | FeastState | PLANNED=0, PREPARING=1, READY=2, ACTIVE=3, COMPLETE=4, CANCELLED=5 |
217: | Severity | INFO=0, ADVISORY=1, WARNING=2, CRITICAL=3 |
218: 

865: | Season roll over during work |Eligibility checked at start; legal started harvest/fishing finishes unless safety closure requires return; next job uses new season |
866: | Pause/menu overlap |One authoritative pause reason set; closing a menu restores previous speed only if no player/critical pause remains |
867: | Hardware overload |Lower requested speed then pause; do not skip daily ecology, starvation, or consumption |
868: 
869: | ID | EARS requirement |
870: |---|---|
871: | REQ-SET-169 | If any edge case in the table occurs, then the system shall apply its declared resolution and expose the cause in the relevant panel/notice. |
872: | REQ-SET-170 | When relief seeds are requested, the system shall enforce one pouch/world-year, show its next-dawn arrival, and record a non punitive assistance event. |
873: | REQ-SET-171 | When a resident becomes incapacitated, the system shall prioritize rescue to a reachable bed and then treatment, allowing another resident to carry one casualty at 50% movement speed. |
874: | REQ-SET-172 | While a severity 1 injury is untreated, the system shall prevent hazardous work and remove 1 health/hour; severity 2 shall remove 4/hour until treatment. |
875: | REQ-SET-173 | When treatment consumes herb 1+cloth 0.5 and completes 60 WU, the system shall clear the aggregate injury and restore 10 health, capped 100; treatment can occur at a field landing point or a bed. |
876: | REQ-SET-174 | If the last resident is injured but conscious, then the system shall allow self-treatment at 120 WU when supplies are reachable; unconscious self-rescue is impossible. |
877: | REQ-SET-175 | When a critical condition resolves, the system shall clear its active alert and retain its acknowledged/resolved history record. |
878: 

## docs/underground_economy_hazard_amendment.md
SHA256 c7739c622607f771e7de773df35cc03b8bb4b39da8810c16963fc84f00875d2b

458: ## HAZ-004 — rescue, treatment and concurrent injury rules
459: 
460: Rescue requests use existing urgency bucket0 and respect eligible-rescuer priority,
461: consent and route safety. No hidden worker assignment overrides priority0. Show
462: the existing Enable safe survival jobs action when assignment is prohibited.
463: One eligible rescuer can carry one patient per REQ-SET-171. Pickup requires
464: 8000 milli-WU HAUL, set-down4000 milli-WU HAUL; these are NEW handling work,
465: separate from inherited treatment. Rescue approach is normal legal travel;
466: carrying speed is exactly half the rescuer's eligible profile speed (retain the
467: rational speed remainder; do not truncate an odd u/s cap). No work accrues in transit.
468: 
469: The patient is a generation-checked carried-resident relationship, not an item or
470: a fake mass in the ordinary satchel. Require the explicit combined rescue envelope
471: for each connection. Set down the rescuer's own ordinary cargo at a legal reachable
472: container before pickup; refuse without output capacity. The patient's actual
473: cargo stays owned by the patient and counts in the combined envelope/load contract;
474: never destroy it or count it twice. A protected airway during carrying is a
475: declared rescue-profile property; otherwise underwater air continues to run for
476: both people. One rescuer cannot pull an unconscious person through a merely
477: self-swimmable route. Missing rescue-profile compatibility is a real blocker.
478: 
479: Default destination is a reachable bed; if none is available, use a reachable dry
480: field-care landing, then continue existing treatment there. For an immediately
481: threatening underwater/hanging state, prefer the least-travel-tick compatible
482: safe landing before onward bed transport; ties use persistent owner ID then
483: contact key. Reserve pickup access and set-down capacity together before moving
484: the patient. The occupied edge must expose a separate safe rescue approach so
485: rescue cannot deadlock waiting for the patient's own occupancy to disappear.
486: No route means a persistent blocked rescue, patient location and cargo marker.
487: 
488: For underwater pickups charge pickup work's actual ticks against each person's
489: air, including all work factors; do not substitute a nominal 100 ticks if the
490: rescuer is slowed. Planned rescue must fit the rescuer's full protected round
491: trip budget. The patient's remaining time/rates are shown as conditional urgency,
492: not a false guarantee. A conscious stranded resident may self-return only through
493: an eligible supported route; an unconscious last resident cannot self-rescue.
494: 
495: Aggregate injury keeps maximum active severity. If equal-severity incoming kinds
496: conflict, retain the lower InjuryKind ID deterministically. Untreated damage is
497: 1/hour for severity1 or4/hour for severity2, not one copy per incident. A new
498: incident does not erase untreated elapsed time, remainders or already paid care
499: work. Genuine one-shot health events still apply once each; deduplicate by incident
500: identity/event ordinal. Severity escalation immediately selects the new future
501: rate. Existing treatment consumes herb1000 + cloth500 milli-U and60000 milli-WU
502: HEAL, clears the aggregate injury and restores10 health (cap100). Conscious
503: last-resident self-treatment is120000 milli-WU. No treatment work in active water,
504: on an unsupported climb, during falling or while being carried.
505: 
506: Derive exposure episode transitions from the interval's starting state, then
507: accrue rates once. Health0 commits death immediately before any later action.
508: Resolve movement/touchdown and other declared one-shot hazard events for the
509: remaining living actors; again commit any resulting death immediately. Only
510: a still-living patient may receive permitted completed care. Finish the remaining
511: lifecycle bookkeeping once. A dead body's physical recovery trajectory may
512: continue, but later care or damage calls cannot resurrect or kill it again.
513: Calls into needs must not let ordinary need recovery run in addition to a
