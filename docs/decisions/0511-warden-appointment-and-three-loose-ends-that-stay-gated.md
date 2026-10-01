# 0511 — The Warden can be appointed; demolition and the family helper stay gated; availability names the real gaps
Date: 2026-10-01 · Status: Accepted

Numbered 0511 because the brief asked for 0511–0519. No record numbered 05xx exists on any branch (`git log --all`).

The review (`redwall-review/REVIEW.md` at 157a3a4) listed four settlement loose ends. Each was re-checked on master
`df9aec3` before anything changed. Two are fixed. Two are left as they are, because changing them would contradict an
adopted ruling.

## 1. `request_demolition()` still never starts a project. Blocked on an adopted ruling.

Confirmed on master: `settlement_system.gd::request_demolition()` runs its five stages and never calls
`construction().open_demolition()`. **This is deliberate.** [INV-GOODS-R01](../rulings/2026-09-14_cycle02_construction_goods.md)
and decision 0145 make stage 5, footprint coverage, refuse `MISSING_CONTAINMENT_CONTRACT`. That stays true until some
owner publishes a container-by-tile (or container-placement) binding.
- An `InventoryContainer` row has no position, and nothing maps a tile to a container.
- So a ground pile or another entity's container inside the footprint cannot be counted.
- The ruling says a demolition request "may proceed only when they are clear", and that the zero-goods case must be
  "a successful complete scan at the final gate".

Starting the project now would require one of two things:
- **treating "I cannot see there" as "nothing is there".** The ruling exists to forbid exactly that.
- **inventing a footprint binding.** That is task 06.2's endpoint owners' contract, and nobody has written it.

Nothing on master has closed this. A search finds no container placement, tile binding or ground-pile store.

**No code changed for this item.** It unblocks when the footprint/placement binding owner lands. At that point the
gate gains its success path and calls `open_demolition()` without any refusal changing meaning, as decision 0145 already
says. `construction.gd` already implements the DEMOLISH purpose and phases, up to four builders, pause keeping progress,
and a 50% return after a quarter of build work; its tests cover them.

**The refund basis is itself not fully accepted.** The tier-2 question was answered by
[BUILD-C4-R01](../rulings/2026-09-19_cycle04_resumption.md) (2026-09-19): an upgraded building's basis is the paid base
package plus each completed paid upgrade, and "the current base-only implementation remains unaccepted for upgraded
demolition" (`open_items.json` `tier-two-demolition-basis`, `implementation_complete: false`). `construction.gd` still
refunds the base §4.1 row at every tier. That is a second open item behind the same gate, untouched here.

## 2. APPOINT_WARDEN is implemented for the part the documents agree on

**Sources.**
- REQ-SET-157: "When Warden Rowan or a later Warden dies/leaves, the system shall allow appointment of any living
  resident and preserve the settlement."
- GDD §5.11: "Warden death alone does not end play; player can appoint another adult, with no stat change."
- DEC-008 keeps the refuge's Warden succession operative and creates no universal leader.

**Store: `residents.gd::appoint_warden(slot)`.** It owns the Role column (§4.2 `Role` B8, already saved by
`save_owner_residents.gd`), so the appointment persists through the existing section-4 owner with no schema change.
- **It writes one byte, the Role.** No skill, XP, need, health, name or stage changes.
- **It refuses, in this order:**

  | Condition | Refusal |
  |---|---|
  | Free row | `RESIDENT_NOT_PRESENT` |
  | Dead resident | `WARDEN_CANDIDATE_NOT_LIVING` |
  | Stage other than ADULT | `WARDEN_CANDIDATE_STAGE_UNRULED` |
  | A living Warden already serving, the target included | `WARDEN_SEAT_OCCUPIED` |

- **`serving_warden_slot()`** returns the lowest living row whose Role is WARDEN. A dead Warden's retained row keeps
  its WARDEN byte as history and does not serve.

**Command: the APPOINT_WARDEN arm of `command_dispatch.gd`.** Its schema is new here; decision 0043 printed the other
six.
- target = the appointee resident;
- no payload;
- `arg0` = `arg1` = 0.

REQ-SET-157 names a person and nothing else, so a nonzero argument refuses as `COMMAND_ARGUMENT_RANGE` and a payload
refuses as `COMMAND_PAYLOAD_SCHEMA`, rather than either being ignored. A store refusal reaches the ledger as
`COMMAND_STORE_REFUSED` with the store's own code. No result code was added, so no result id is renumbered.
- Seven of ARCH-CMD-003's 24 kinds are now implemented.
- `settlement_system.gd` reaches the arm through the residents store it already binds.

**What stays open, recorded rather than invented:**
- **CHILD and ELDER eligibility.** REQ-SET-157 says "any living resident". §5.11 says "another adult". Only ADULT
  satisfies both, so CHILD and ELDER refuse as unruled. DEC-032's "elders retain individual roles" does not say an
  elder may be *appointed*.
- **Replacing a living Warden.** Both texts open the seat only on death or departure.
- **Departure.** No owner writes it: `needs.gd` leaves `departure_days` unwritten. "Serving" therefore means living.
  When a departure owner lands, a departed row must stop counting as serving.
- **The naming trigger.**
  - REQ-SET-040 and GDD §5.3 list "appointment as Warden" as a trigger that marks the resident notable and assigns a
    generated name.
  - The READY_07 addendum (I2) does not permit generated names until the catalog order and algorithm identity are
    covered by naming/catalog compatibility, and no generated-name owner exists.
  - So an anonymous appointee stays anonymous. `appoint_warden()` leaves naming alone so that the trigger's owner can
    add it without undoing anything.
- **Pending naming triggers can be recovered.** A living row with Role WARDEN and `_named == 0` is exactly an appointee
  whose REQ-SET-040 trigger has not been applied. Until then the state the GDD forbids (an appointed Warden who is not
  notable) exists on every anonymous appointment, and the later naming owner should sweep that predicate once.
- **Role is one enum (§4.3).** Appointing a SPECIALIST therefore replaces that byte with WARDEN. Nothing writes
  SPECIALIST today.
- **A seat that was never held is treated as vacant, on purpose.** REQ-SET-157's trigger is "dies/leaves", but a dead
  Warden's row can be despawned, which erases the WARDEN byte, so "never held" and "held by someone who left" cannot be
  told apart from the columns. DEC-008 makes the office the refuge scenario's; when another scenario lands without a
  Warden office, the command must be scoped to the scenario that has one.
- **These questions need a ruling and are not answered here:** CHILD/ELDER eligibility, replacing a living Warden and the
  naming trigger's dependency on I2. They are raised for Brendan through the coordinator, not filed into
  `open_items.json` from this branch.

## 3. Availability reasons now name the gap that remains

Several owners named in `ui_availability.gd` have landed since the table was written (95ee560, 2026-09-11), so the
reasons were corrected:
- the Building, Room and Furniture stores, and construction;
- the Transform store and exact-start navigation;
- the save codec and its sections;
- the notice history (500 rows, `ui_notices.gd`);
- weather forecasts.

No element became AVAILABLE, because none of those flows is complete. Changes, by index:

| Index | Was | Now |
|---|---|---|
| 1 | `NO_BUILDING_STORE`, "no Building, Furniture or Room store exists" | `NO_BUILDINGS_PLACED`: the stores exist, but nothing places a building (the §5.1 refuge hall included) and no build, room or bed command is wired; task 06 |
| 2 | `NO_TRANSFORM_STORE` | `NO_WORLD_PICKING`: poses are stored; the interface binds no camera to pick or project them and keeps no multi-selection |
| 3 | `NO_SAVE_CODEC`, "no save codec exists" (UI-SET-076/077) | `NO_SAVE_FILES`: sections are still unwritten and nothing writes or reads a save file on disk; tasks 09.2, 09.3 and 09.5 |
| 11 | "no forecast model exists" | no food or harvest forecast model exists; only weather is forecast |
| 14 | `NO_NOTICE_STORE`, unused and false | `NO_RELATIONSHIP_STORE`, for UI-SET-048. That row claimed "store exists, panel not built", but no Relationship store exists |
| 15 | (new) | `NO_RELIEF_SEED_POLICY`, for UI-SET-097. Its claim was false the same way, and REQUEST_RELIEF_SEEDS still refuses |
| 16 | (new) | `NO_PIN_OWNER`, for UI-SET-098. Pinning promotes to a generated name (REQ-SET-042), which the I2 gate does not yet permit, and no ledger-favorites store exists |

- `REASON_NO_MANUAL_TASK_STORE` is true and currently claimed by no element, so it is kept.
- The tests now pin the stale phrases as forbidden, so a reintroduced "no save codec" fails.

## 4. The family hunger helper stays unwired in the settlement. Blocked on PC-04.

`family_rules.gd`'s intended consumer is the Needs hunger integrator and the daily-demand sum, choosing a rate by
life stage.
- [FAMILY-RULES-R01](../planning/family_rules_api_contract.md): "The helper remains unbound until activation; catalog
  versions must change when its values begin affecting the authoritative world."
- Decision 0158: Needs and Residents runtime behaviour "remain unchanged".
- Activation is the PC-04 family amendment. `docs/planning/family_execution_package.md` is still a "version 4 draft",
  under authoring and review, and task 08.2 is unchecked.

Wiring it now would be activating PC-04 without the amendment, so it is left unwired.

The review's "unconsumed" is partly stale: the demo consumes the helper (`godot/demo/kitchen/nourishment.gd`,
`meal_rules.gd`). That presentation layer is outside the settlement's authoritative state.

## Review outcome

An independent `code-reviewer` pass on the diff found **no CRITICAL or HIGH findings**. Its full-suite copy and
`state_registry_coverage` passed apart from one timing test under load, and a save probe round-tripped both WARDEN
bytes. The MEDIUM and LOW findings were handled as follows:

- **Fixed, with tests:**
  - the refusal order is now pinned (presence, then life, then stage, then seat). Its three order mutants are killed.
  - a section-4 round trip now carries both a dead Warden's byte and an appointee's byte.
  - the stale-phrase guard now also rejects the "no Transform", "no Building", "no save codec" and "no notification
    history" prefixes.
- **Fixed in this record:** the false statement that OPEN.md still carried the tier-2 basis. It is now cited as
  BUILD-C4-R01, with that implementation still unaccepted.
- **Fixed in text:**
  - reason 16 now cites the READY_07 I2 gate and says "pin/promotion owner";
  - reason 3 says "some sections";
  - `systems_architecture.md`, `STATUS.md` and task 04 no longer say "eighteen".
- **Recorded, not changed:**
  - the never-held seat (above);
  - the questions needing a ruling (above);
  - CANCEL_JOB and NAME_RESIDENT not refusing nonzero arguments, which predates this branch;
  - the demo tooltip that quotes `REASON_TEXTS`, which belongs to the demo owner.

## Consequences

- REQ-SET-128 and REQ-SET-157's naming half stay open. The REQ-SET-157 appointment itself works.
- A future footprint binding, departure owner, naming-trigger owner or PC-04 activation each has a named place to
  land, with no refusal changing meaning.
- **Stale text spotted and NOT changed here,** each outside these four items:
  - `residents.gd`'s header (no Building store, so home/bed are null);
  - `building_definitions.gd` lines 48-58 ("Construction does not exist");
  - `settlement_system.gd`'s "no pathfinder", and its "§5.1 lists no starter building", which contradicts
    GDD §5.1 "Start with one completed refuge hall";
  - `command_dispatch.gd`'s unsupported reasons naming absent Building, Room, Construction, Furniture and FieldPolicy
    stores that now exist;
  - the doc comment in `demo/ui/demo_command_tips.gd` quoting the old reason text.

## Source

REQ-SET-040/042/128/157, GDD §5.11 and §5.3, DEC-008 and DEC-032, INV-GOODS-R01 and decision 0145, FAMILY-RULES-R01 and
decision 0158, the READY_07 addendum I2, and task 09's checklist.
