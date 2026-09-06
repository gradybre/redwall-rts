# Settlement Rules Amendment — Community Admission and Food

| Field | Value |
|---|---|
| Document | SET-AMEND-001, revision 1.0, 2026-09-05 |
| Authorization | Brendan: “Adopt both”; DEC-005 and DEC-006 |
| Ruleset | `settlement_rules_v2` |
| Owners updated with this amendment | GDD revision 1.1, UI revision 1.1, balance and architecture documents |
| Scope | Approved admission and dietary rules; current refuge initialization plus contracts for other scenario authors |
| Evidence status | Exact authored specification and reference validation; not a completed settlement runtime or full-release scenario package |

## 1. Authority and provenance

The approved policies are settlement-specific populations with authored individual exceptions, and plant staples plus explicitly nonsapient fish/seafood instead of mammal/bird hunting. This document supplies the mechanical reconciliation. `[USER]` means that policy; `[NEW]` means an implementation/content choice authored here; `[INHERITED]` means an unchanged prior GDD value; `[DERIVED]` means arithmetic from identified values.

The exact refuge roster order, exception date/text, replacement recipe inputs and retirement strategy are `[NEW]`, not quotations from the user or Redwall canon. They are operative implementation choices under the adopted policies and can be revised explicitly as the interview develops. Do not attribute the rat traveler to the novels or invent a canonical biography.

For these two policies this amendment resolves the superseded rules. The GDD and derived catalogs are edited to agree; this is not an invitation to keep implementing the old tables. Other scenario maps, casts, founding histories and completion conditions remain separate required first-release work under DEC-028.

## 2. Food and material boundary

| ID | EARS requirement |
|---|---|
| REQ-ADM-001 | The catalog compiler shall reject a food-source creature classified as sapient, a resident species also registered as food stock, and any mammal or bird harvest source. |
| REQ-ADM-002 | When a food job reserves an aquatic stock, the system shall require membership in the exact edible aquatic whitelist and shall preserve the existing stock, quota, closure and hazard rules. |
| REQ-ADM-003 | If a command, scenario, recipe, lot, job or building references a retired key from Section 3, then the validator shall reject it before world mutation rather than substitute an item or spawn free resources. |

The edible aquatic whitelist is exactly `[carp, dace, herring, mackerel, mussel, perch, salmon, trout, whitefish]`, all `sapient=false` in the food-stock catalog `[INHERITED keys; NEW explicit whitelist authority]`. The `fish` recipe selector resolves only these keys. Pike/eel hazards are non-harvestable encounters; they produce no edible lot. Future sapient aquatic characters may not reuse an edible species key with a contradictory classification.

No livestock, milk or egg production is introduced. Cloth remains produced from flax, rope from flax, outfits from cloth, and tools from wood/stone/iron under existing recipes. Hide currently has producers but no active material recipe consumer; remove it rather than inventing a leather replacement chain. Wax remains available for current candles; waxed-cloth equipment is a future authored recipe, not a hidden change to outfit inputs.

## 3. Exact retirement and replacement map

| Domain | Retired keys | Replacement / disposition |
|---|---|---|
| Items | `bow`, `carcass_boar`, `carcass_deer`, `carcass_grouse`, `hide`, `hunting_tool`, `meal_game_roast`, `raw_game`, `smoked_game` | No item migration; add only `meal_nut_roast` in Section 4 |
| Main recipes | `bow`, `hunting_tool`, `smoke_game`, `game_roast` | `game_roast` is replaced by `nut_roast`; the other three have no replacement because no surviving release job needs them |
| Ancillary recipes | `process_deer`, `process_boar`, `process_grouse` | Removed |
| Building and station | `hunter_hut` | Removed; no renamed empty-purpose building |
| Huntable fauna | red deer, wild boar, wood grouse | No active food stocks, herd proxies, tracking quotas or harvesting jobs; no claim about their existence elsewhere in fiction |
| Skill/job index | `HUNT=3` | Rename to `RESERVED_3=3`, initialize XP/level/priority to 0, prohibit assignment and XP; keep 12-column physical stride |
| Zone index | `HUNT=1` | Rename to `RESERVED_1=1`; reject creation; keep other explicit enum values unchanged |
| FaunaStock component | Former game-animal stock rows | Retain allocated schema as `FaunaStockReserved`, all numeric fields 0, references `(-1,0)`, no active directory rows, no system updates |
| RNG domain | `HUNTING` | Retain existing stream slot/key as a tombstone initialized by the prior seed rule; draw_count remains 0 and no system may draw from it |
| Work telemetry | `labor_hunt_mwu` | Keep CSV compatibility column; must equal 0 in rules v2 |

Retaining tiny unused packed regions and explicit enum holes avoids renumbering unrelated skills, zones and RNG domains. It does not permit hidden hunting behavior or designate an unspecified new scouting skill. Future scouting/rescue expansions require their own concrete specification. Active skills are exactly indices `[0,1,2,4,5,6,7,8,9,10,11]` `[DERIVED]`.

Derived catalog counts after this edit: **60 items, 24 main recipes, 12 tabulated ancillary recipes, 30 buildings, 9 furniture types, 5 crops**. Non-tabulated operations such as tool repair remain as explicitly defined in the balance document. These counts describe catalog definitions, not completed runtime assets.

## 4. Replacement roast and Orchard feast

### 4.1 Exact recipe

| Field | Value | Provenance |
|---|---|---|
| Recipe key / display | `nut_roast` / Bean, root and nut roast | NEW |
| Inputs milli-U | `beans:3000; roots:2000; nuts:1000; herb:250` | NEW |
| Output | `meal_nut_roast:4000` milli-U = 4 portions | INHERITED portion count from retired game roast; NEW key |
| Base work | 30000 milli-WU; no passive wait | INHERITED |
| Station / skill / unlock | kitchen / COOK=6 / M2 | INHERITED |
| Output mass | 500 g/U | INHERITED prepared meal convention |
| Nutrition | 2400 NP/U at PLAIN quality | INHERITED target from retired game roast |
| Shelf life | 36 game hours | INHERITED |
| Raw edible output | true; it is a prepared meal | INHERITED |
| Effect | `FROM_INPUT`; dominant beans provide STAMINA, −50/1000 awake rest decay for 4500 ticks | INHERITED effect rules; DERIVED dominant ingredient |

COOK input efficiency applies to beans and roots only, as already specified. For level L in 0..10: `beans_milli=3000*(1000-10*L)//1000`, `roots_milli=2000*(1000-10*L)//1000`; nuts=1000 and herb=250. Output stays 4000 milli-U. At L=0, inputs total 6250 milli-U of 250g/U ingredients, or ceil(1562.5)=1563 g conservative inventory mass. At L=10, inputs are 2700/1800/1000/250, mass ceil(1437.5)=1438 g. The game's item masses are storage accounting, not physical mass conservation, as the GDD already states.

Beans remain the largest nonwater input by mass throughout L=0..10. Do not copy the old effect without binding actual ingredients. Total PLAIN output NP=9600; POOR/GOOD/EXCELLENT totals=8640/10080/10560 under existing quality factors. These are authored game nutrition values, not real nutrition claims or playtested balance.

### 4.2 Feast change

The Orchard main course becomes `ceil(E/4)` batches of `nut_roast`; second course, beverage, unlock, staffing, seats, wood, attendance, buff and cooldown remain unchanged. E is the GDD's eligible attendee count. For E=12: 3 roast batches, beans 9 U, roots 6 U, nuts 3 U, herb 0.75 U at COOK 0; 12 main-course portions and work is 90000 milli-WU (90 WU), from 3×30000. No additional feast service work is inferred from this preparation calculation.

For E=13: 4 batches produce 16 main portions; only the 13 served portions are consumed as attendance occurs. Existing lot/reservation and serving rules govern leftovers and spoilage. Batch count cannot be reduced to floor(E/4).

The non-orchard mastery strategy replaces `game_roast` with `nut_roast`. The ten-recipe set remains `[porridge, root_stew, fish_stew, bean_hotpot, nut_loaf, dry_fish, woodland_pie, nut_roast, feast_fish, ration]`. None requires orchard fruit or honey. All eleven active skills remain available for the existing six-distinct-skill Charter threshold; reserved index 3 cannot count.

## 5. Admission profiles and authored exceptions

### 5.1 Immutable per-scenario data

| Catalog | Typed fields / bounds | Validation |
|---|---|---|
| AdmissionProfile | `id:StringName`; `normal_species:int32[]`, length 1..16, ordered unique; `exception_events:AuthoredAdmission[]` | Species must belong to the resident catalog; pools and events counted inside existing 2 MiB immutable catalog/lookup budget |
| AuthoredAdmission | `id:StringName`; `absolute_day:int32>=4`; `species_id:int32`; `description_key:StringName` | Only days `4+3*k`, k>=0; at most one event per profile/day; species must be outside normal pool; stable unique event key; text must be present |

Bind exactly one AdmissionProfile to the scenario's versioned content manifest. Changing it changes the rules/catalog hashes used by the save contract. The current refuge uses `refuge_woodland_v1` regardless of Abbey/Holt/Fortress visual kit. Changing a visual kit does not change admission policy. Other scenarios must supply their own complete profile; missing profiles fail content validation, with no universal 16-species fallback.

Current refuge normal pool, in operative order `[NEW]`:

```text
mouse, mole, otter, squirrel, shrew, hedgehog, hare, badger
```

The global 16-species resident catalog is retained. Species outside a given pool remain available to other validated scenarios and explicitly authored exceptions. This pool is an original refuge design choice, not a universal Redwall Abbey population rule.

### 5.2 Deterministic candidate algorithm

At an immigration midnight day D=4+3*k, compute the existing candidate count C, limited to 8. Set N to the profile's normal-pool length and e=(D-4)//3. For slot i=0..C-1, assign `normal_species[(world_seed % N + e + i) % N]`. This rotation is `[NEW]`; count formula, needs, health, clothing, tools, skill XP, cap, bed/reserve checks and immigration timing are `[INHERITED]`. Seeded skill selection draws only from the eleven active skill indices.

If one authored exception is scheduled for D, replace candidate slot C-1 with that event's species and description. It consumes one candidate slot rather than increasing C. Because exception species are outside the normal pool and there is at most one event/day, `(profile, event_day, species_id)` identifies origin unambiguously. Persist the existing Candidate columns; origin is derived from immutable profile data, not a new per-resident object. Profiles with ambiguous exception definitions fail validation.

At every calendar midnight, expire all pending rows from the preceding day before creating any new candidates. A pending candidate expires at the next calendar midnight, including days without an immigration event. Accepting a candidate requires a valid row matching the current event and world state, then atomically creates the resident and clears the candidate row (`species_id=-1`, other integers 0). Refusal clears the row without a gameplay penalty. Closing the review does not refuse; unresolved candidates remain until expiry. An empty row cannot be accepted again. Normal auto-immigration skips the exception row; exception acceptance always requires the player's explicit Confirm command. Bed/cap checks cannot be overridden; the existing food-reserve override remains event-specific. No trust meter, probation timer, aid inventory grant, affinity reward or betrayal probability is added.

The existing once-per-midnight crossing and saved pending rows prevent repeat offers or duplicated acceptances on reload. Reloading an earlier save legitimately restores that earlier world's decision state; this is not a persistent cross-save moral ledger.

### 5.3 Concrete refuge exception

| Field | Value |
|---|---|
| id | `refuge_rat_petition` |
| absolute_day | 10, spring day 10 |
| species_id | rat |
| description_key | `admission.refuge_rat_petition` |
| Display label before admission | Rat traveler |
| Text | “A lone rat traveler asks to settle here and share the work. This is an individual petition outside the refuge's usual arrivals.” |
| Stat initialization | Same GDD immigrant health, needs, equipment and seeded active skills as any other candidate |
| Admission effects | Ordinary population, housing and demand effects only; no special buff or plot immunity |
| Naming after admission | Existing resident naming/notability rules; no new mandatory canonical name |

All fields and prose in this record are `[NEW]`. They are deliberately a minimal original encounter, with no established warband affiliation, family, named birthplace or book-character identity. Later approved biography can extend its text, but the mechanical offer does not depend on invented lore.

## 6. UI and implementation contract

| ID | EARS requirement |
|---|---|
| REQ-ADM-004 | When the immigration review displays an exception, the UI shall label it “Individual petition”, show its authored description and species, and expose the same exact housing/food consequences as ordinary candidates. |
| REQ-ADM-005 | While automatic immigration is enabled, the system shall exclude authored exceptions from automatic acceptance and leave them available for an explicit player decision until expiry. |
| REQ-ADM-006 | When a candidate is accepted or refused, the system shall clear that pending row in the same committed transaction and reject repeated decisions on the cleared row. |
| REQ-ADM-007 | When job controls or mastery checks enumerate skills, the system shall omit RESERVED_3 and preserve the remaining numeric indices. |
| REQ-ADM-008 | When a v2 save is loaded, the validator shall require current rules/catalog hashes, canonical reserved fields and the scenario-bound admission profile before applying world data. |

Use existing UI-SET-068/069 with selected-row detail inside 068; UI-SET-066 commits selected candidates, UI-SET-067 closes the review. Explicit refusal uses a 066 instance with the action label “Decline selected”; it cannot be confused with closing the window. New interactive element IDs are unnecessary: these are existing action templates with explicit keys `accept_candidates` and `decline_candidates`. UI controls must not imply the nonsimulated aid/probation choices described as fiction in the bible.

Candidate rows remain at most 8. Exception text uses the existing readout profile, 16 logical px, wraps inside panel content width, and scrolls with detail; it cannot cover confirmation controls. The job matrix displays 11 active columns. Removed buildings/items/recipes do not appear as ordinary locked content. There is no hidden HUNT column or selectable hunt zone.

## 7. Versioning, memory and validation

GDD revision 1.1 uses ruleset identity `settlement_rules_v2`. Regenerate ASCII catalog IDs from the active keys. Reject v1 simulation saves with a ruleset mismatch before world mutation; no migration is promised and no old numeric ID may be reinterpreted as a new key. The isolated `RWLCTRL1` winter checkpoint is a separate model without hunting/admission and remains unchanged; rerun its source-bound evidence against the revised documents before using it as current evidence.

Memory strategy `[NEW]`: retain the existing FaunaStock field allocation as a reserved region and keep skill/zone/RNG holes. Admission profiles occupy the existing immutable catalog arena. Derive exception origin from immutable event data and existing Candidate fields. Therefore no packed runtime bytes are added, and the conservative architecture ledger remains 57713254 allocated payload bytes plus 8388608 reserve = 66101862 bytes. Retired stores must stay canonical empty; the ledger is an allocation plan, not a measured peak.

| Acceptance case | Exact expectation |
|---|---|
| Active catalog integrity | 60 items, 24 main recipes, 12 tabulated ancillary rows, 30 buildings; no retired key in an active row or recipe dependency |
| Recipe reference integrity | All active inputs/outputs resolve, `@fish` resolves only the nine edible aquatic keys, no active job/recipe uses index 3 |
| Roast at COOK 0 and 10 | Inputs 3000/2000/1000/250 and 2700/1800/1000/250 milli-U; 4 PLAIN portions=9600 NP; beans dominate at every level |
| Orchard E=12 / E=13 | 3 / 4 main-course batches; 12 / 16 produced portions; no rounding down; 90 / 120 WU preparation |
| Refuge seed 20260905, day 4, C=2 | mole, otter |
| Same seed, day 7, C=2 | otter, squirrel |
| Same seed, day 10, C=2 | squirrel, rat petition; rat excluded from auto acceptance |
| Same seed, day 13, C=2 | shrew, hedgehog; no repeated rat petition |
| All ordinary events over eight cycles | No species outside the eight-key normal pool; each first candidate cycles through the full pool |
| Rejected catalog data | Resident listed as prey, aquatic species marked sapient but edible, duplicate normal key, exception inside normal pool, duplicate event day, missing description, retired recipe item |
| Runtime lifecycle, not yet executed | Accept/refuse once, expire next midnight, save/reload pending and resolved rows, reserve/bed/cap refusals, deterministic skill selection and origin labels |

Reference checks cannot certify those unimplemented runtime transactions or full three-year survival. Keep the recorded distinction between specification validation, isolated Godot kernels, complete settlement integration, all-scenario coverage and Windows qualification.
