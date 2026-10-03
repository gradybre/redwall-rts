# 1059 — Room purpose reuses existing identities and furniture economics

Date: 2026-10-02 · Status: Accepted catalog adapter; live construction/service integration pending

## Decision and scope

`godot/scripts/core/room_catalog.gd` provides cold, read-only queries for the
approved modular furnishing workflow. It does not allocate rooms, install
furniture, spend goods, create projects, change existing owner state or grant
services. `Catalog.ROOM_TYPE` remains the eight protected GDD ordinals;
`Catalog.FURNITURE_DEFINITION` remains the nine compiled furniture identities.
No catalog artifact, room price, construction recipe or save schema changes.

The player's blueprint is an **in-world plan painted directly on the dirt at
the selected underground level**, with planned outlines/materials/entrances
before confirmation. These query records do not imply a separate blueprint
canvas. UG09 owns that actual-world picking/overlay integration; component
fixtures are not evidence that the whole workflow is playable.

## Names, permanent purpose and presets

| Protected purpose | ID | Display label |
|---|---:|---|
| DORMITORY | 0 | Dormitory |
| PRIVATE_ROOM | 1 | Bedroom |
| KITCHEN | 2 | Kitchen |
| DINING | 3 | Dining room |
| COMMON | 4 | Common room |
| INFIRMARY | 5 | Infirmary |
| PANTRY | 6 | Pantry |
| CORRIDOR | 7 | Corridor |

`resolve_preset()` accepts these exact display labels or existing uppercase
keys. **Tunnel** is a display alias of CORRIDOR; **Root cellar** is a
presentation alias of PANTRY. Neither creates an ID, installs furniture,
adds a store, grants a preservation class or adopts an excavation price.
An ambiguous **Burrow** style or **Cellar** label refuses: the caller must
select the actual purpose or the separate existing Cellar building action.

The standalone `BuildingDefinition.cellar` remains its own existing
construction, unlock, container and storage-class owner. The older demo's
dug root-cellar fixture system also has a separate implementation and is not
silently migrated by this adapter. In particular, selecting the Root cellar
alias does not import either system's capacity or aging multiplier.

`retained_type_error()` refuses every change between two different purposes.
Its input is the already bound type, not an inferred type from contents. An
empty kitchen still has KITCHEN purpose and cannot accept a sleeping bed.
Actual room/project identities remain owned by Buildings, RoomProjects and
the integrating coordinator. Existing RoomLayout checks generation-qualified
identity and type; this stateless helper cannot prove that old-room removal,
physical backfill or new construction happened. Those lifecycle checks and
save restoration remain required. There is no retype mutation method here.

## Compatibility is separate from service contribution

The user's requested room-appropriate equipment specializes beds, patient
beds and cooking benches. GDD-required Dormitory beds remain supported.
The GDD's **service prerequisites are not an exhaustive placement ban**:
a shelf may be useful in a Bedroom without creating pantry capacity there,
and a chair need not make a Bedroom into a Dining room.

| Existing furniture | Modular placement compatibility | Service boundary |
|---|---|---|
| bed | DORMITORY, PRIVATE_ROOM | Actual installed eligible bed, valid room and access required |
| patient_bed | INFIRMARY | Patient use needs the real care/room owner |
| kitchen_bench | KITCHEN | Catalog contribution is one Kitchen station worker slot; no ready-work attestation |
| seat | Shared fitting in all purposes | Dining/Common prerequisites apply only to those room services |
| shelf | Shared fitting in all purposes | Only a valid PANTRY contributes 50,000 g per eligible shelf; no added industrial buffer |
| hearth | Shared heating fitting in all purposes | Heating needs connected topology and actual fuel; a hearth is not a cooking station |
| decoration | Shared fitting in all purposes | Existing comfort rules/validity still apply |
| interior_door, interior_partition | Shared boundary fittings in all purposes | Real opening/boundary geometry and ownership required; zero floor size is not unrestricted placement |

"Shared" means purpose-compatible, not spatially legal. Furniture must still
fit its actual finished room, retain circulation and protected connectors,
have support/headroom, and provide valid installation/use contacts. A corridor
full of shelves does not pass merely because the purpose mask allows shelves.

The GDD explicitly requires an infirmary shelf and preserves the starter
kitchen-owned shelf (R-BUILD-DOM-004); neither produces Pantry capacity.
`scoped_service_facts()` makes the pantry/kitchen contributions explicit while
leaving actual installed state, room validity, building condition, occupancy,
fuel, access, recipe/input/output and other service gates with their owners.
The returned numbers are per-piece catalog limits, not active capacity.

## Exact furniture facts and prerequisite queries

`furniture()` / `furniture_by_key()` reuse `BuildingDefinitions` for physical
floor dimensions, work and user/station slots. Every footprint tile is the
GDD's **2 m = 2048 fixed units**. A bench or hearth is 4096×2048 units;
quarter-turn rotation swaps its axes. A finer drawing grid must subdivide
that footprint exactly and cannot shrink a bed to one drawing cell.
Doors/partitions remain edge objects rather than zero-sized free objects.

Material keys and `quantity_milli:int64` arrays are copied directly from
`Construction.FURNITURE_MATERIALS`, preserving exact existing order and
quantities. Construction is preloaded for immutable facts, never instantiated
as a second project owner. No `ItemDefinition` integer is guessed: its real
loaded registry/artifact binding resolves the keys at admission.
The API refuses unknown IDs/keys and invalid rotations. **Oven** and **stove**
are not aliases: no such production furniture definition exists today.

`service_requirements()` describes the GDD §5.9 minimum furniture counts,
private-room maximum of one bed, minimum tiles, area-per-bed/seat ratios,
and separate owner gates. Numeric rules reuse Buildings' existing constants.
`countable_error()` checks only necessary count/area conditions against a
complete nine-entry installed eligible furniture census. It never uses a
presence-mask popcount or claims that a room is ready. Exact room area is an
integer in squared fixed units; one GDD tile is 4,194,304 units². Fractional
tile area is not rounded up. Count input is bounded by the existing Furniture
arena before multiplication, so adversarial int32 counts cannot overflow.

Private enclosure, heated Infirmary, Dormitory access to the exterior, and
Corridor's one-tile/2048-unit width and real exterior link stay explicit
spatial/heat requirements. Every room retains completed-shell, live identity,
installed furniture, support/nonoverlap, connected contacts and owning-service
gates. There is no `ready` or `valid` result derived from catalog facts.

All query records and packed arrays are independent copies. The adapter holds
only one immutable BuildingDefinitions reference; it adds no per-room/entity
column, saved field, service owner or per-resident update loop. Its registry
stanza classifies those cold query records as derived catalog data, not an
alternate future-affecting world store. RoomLayout's own persisted preferences
and drafts retain their separate registry obligations.

## Authoring items deliberately left as proposals

| Item | Status and required owner work |
|---|---|
| Suggested room palettes/layouts | UI convenience proposals only; narrower suggestions cannot silently prohibit shared fittings |
| Material defaults and compatible alternative finishes | D02 approves the experience, not specific production recipes/bonuses/default values; provide an authored catalog and real finish accounting |
| Equipment heights, install/use offsets and occupied volumes | Missing production profiles; require explicit revisioned, sourced profiles and actual geometry/access qualification. Existing floor dimensions do not supply them |
| Oven/stove variants | New furniture/catalog/economic proposals; no ID, recipe, work, dimensions or free cooking service adopted |
| Portable versus fixed fittings and handling work | Separate D15/D16 owner contract; this catalog does not infer portability from the object name |
| Burrow styling and preservation | Style does not choose purpose or authorize cellar aging/capacity benefits; existing service/storage owners must bind any effect |

No default height, synthetic contact offset, permissive profile, material
finish or measured-fit claim is supplied here. `FurnitureFacts` marks that
geometry profiles are required. The real RoomLayout snapshot must still
receive explicit `Profile` data at its declared pitch and change revision
when that data or compatibility changes. Edge pieces need their additional
opening/envelope owner. The UG07 coordinator must compose these gates before
accepting production work; this adapter does not bypass unbound profiles.

## Sources and verification

- GDD §4.3 protected RoomType and §5.9 furniture/room rules; REQ-SET-121,
  124–129; balance §4.3; SET-AMEND-001 retains the nine furniture identities.
- R-BUILD-DOM-002–004: Station identity, per-bench capacity and shelf scope.
- Approved underground D08–D10/D18–D19 and the furnishing plan: complete shell,
  compatible equipment, permanent purpose and removal/backfill/rebuild.
- User clarification: direct in-world dirt painting at the selected level.

The parent independently reviewed the complete source/tests before commit,
including all 72 room/furniture combinations, exact economics, area overflow
and shared versus scoped service behavior. No blocking issue was found.

Own-worktree Godot 4.7.2 verification: demo assets were absent; deleted the
own `godot/.godot` cache, then ran
`godot --headless --path godot --editor --quit` with zero diagnostic lines.
The existing CI shard planner selected only `test_room_catalog.gd` in
`./tools/run_tests.sh --shard 168/307 --output-dir /tmp/redwall-ug-catalog-tests`:

```text
state_registry_coverage: PASS -- 97 modules, 450 rows, 771 packed columns checked
14 test(s), 606 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 14 tests, 606 assertions, 0 failures.
```

Shard position depends on source weights; rediscover it rather than retaining
168/307 after catalog/test changes. Tests cover every protected identity and
compatibility pair, all nine golden recipes/footprints, rotations, immutable
purpose, exact area thresholds, shared service scoping, invalid input, and
copied output independence. An integer-division warning in one test was fixed
with exact multiplication rather than suppressed. The final analyzer command
was `python3 tools/gdscript_warnings.py godot/scripts/core/room_catalog.gd
godot/test/test_room_catalog.gd --max 0 --port 6150`:

```text
0 GDScript warning(s) in 0 of 2 file(s)
```

This is focused evidence. This lane makes no claim of a full composed save,
construction coordinator, native village integration, measured equipment
profiles, 256-resident qualification or full-suite run.
