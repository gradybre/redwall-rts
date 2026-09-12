# 0083 — Starter ground profiles, the contact schema, and the admission boundary

Date: 2026-09-11 · Status: Accepted for the starter ground increment only.
**No MOVE gate is closed by this record**, task 05.1b is not started, and no clearance,
depth, air budget, transition cost or footprint envelope is approved by it.

Scope: the independent increment the
[2026-09-11 movement continuation ruling](../rulings/2026-09-11_movement_gate_followthrough.md)
documents under its "Independent next increment" heading — *"starter ground profile only; closes no
MOVE gate"*. Entry artifact:
[starter ground profile and contact manifest](../planning/movement_starter_ground_profile.md).
Predecessor: [decision 0053](0053-movement-ground-slice-identity-and-storage.md) (05.1a) and
[decision 0066](0066-the-route-cursor-names-its-owner-and-the-height-lookup-refuses.md).

## Decision

Publish four starter ground profiles, a work/service contact schema, and an atomic travel
admission that captures the terms a journey was admitted under, inside the four modules the
movement lane already owns. No new core module is created.

| Module | What this record adds |
|---|---|
| `godot/scripts/core/movement.gd` | The `StarterGroundProfile` catalog, the six-mode enum, `Admission`, the admission checks, and the `ResidentTravelAdmission` cursor columns |
| `godot/scripts/core/spatial_world.gd` | The `Contact` record, `bind_ground_contact()` and `contact_is_current()` |

`navigation.gd` and `transforms.gd` are unchanged.

## The four profiles, and why nothing in them is a literal

The species set is GDD §5.1's cohort sentence — *"12 adults (6 mice, 2 moles, 2 otters, 2
squirrels)"* — in that sentence's own order. The ruling forbids a new synthetic species, so the
twelve other release-1 species `residents.gd` compiles have no starter profile and
`profile_for_species_into()` refuses `PROFILE_SPECIES_MISMATCH` for each.

**Every numeric field is read from `residents.gd` at `_init()`, not copied.** The compiled species
id, GDD §4.3's size class, and GDD §5.2's speed cap and carry capacity all arrive through the
resident store's own readers. A transcribed literal would silently survive a §5.2 revision; a read
cannot. `_build_starter_profiles()` is therefore the audit itself rather than a record of one, and
mutating `_profile_speed_u_per_s[profile] = speed.value` to the literal `4096` fails the suite.

Profile keys are stable ASCII in an `increment.domain.lifestage.species` namespace
(`starter.ground.adult.mouse`), so a second life stage or domain extends the namespace instead of
overloading these four. Revisions begin at 1; `revise_profile()` advances one. **A revision is an
identity artifact the ruling asked for, not a balance value.**

## Six modes enumerated, two profiled

`MODE_GROUND_WALK`, `MODE_FORD_WALK`, `MODE_SWIM_SURFACE`, `MODE_DIVE`, `MODE_CLIMB` and
`MODE_TUNNEL_WALK` are all enumerated; `PROFILED_MODE_MASK` admits the first two. The other four
refuse `MODE_NOT_PROFILED`.

**They are enumerated precisely so the adopted scope cannot be narrowed by omission.** SET-MOVE-001
§1 keeps surface swimming, diving, climbing/canopy access and persistent constructed tunnels in
first-release scope. Leaving them out of the enum would make the increment look complete; leaving
them in, refusing, makes the gap legible at the call site. The alternative — letting an unprofiled
mode fall through to ground walking — is the exact "silently disable dangerous states to make a
fixture pass" the ruling forbids.

## The stamp on a journey is its admitted terms, not merely its route

Decision 0053 established that a route cursor must name its owner's **persistent id**, because a
generation belongs to a directory slot and every slot's first use carries generation 1. That guard
is unchanged and still mutation-tested.

This record adds the journey's **terms**: profile id, profile revision, mode, committed load and
the contact owner's destination revision. Two of those are compared after admission:

- `_advance_row()` compares `_cursor_profile_revision` against the live profile revision every
  tick and settles `MOTION_PROFILE_STALE` on mismatch. That is SET-MOVE-001 MOVE-REQ-006 at this
  increment's granularity — the **whole** remaining journey is revalidated rather than the next
  segment, because segment-level eligibility needs the clearance, posture, grip and load envelopes
  MOVE-G01 still owes. Settling is the conservative outcome and never continues under withdrawn
  terms.
- `revalidate_destination()` compares the admitted destination revision and settles
  `MOTION_CONTACT_STALE`. **The contact owner calls it**, because only the contact owner knows when
  its destination changed; movement does not poll anything and does not pretend to.

## Admission is atomic, and refuses fifteen ways

`begin_travel()` runs every precondition before writing any column, so a refused admission leaves
the motion row exactly as it was. The fifteen ordered checks and their refusal names are tabulated
in the planning document's §4. Two are worth recording here:

- **The route's last cell must be the contact's approach cell.** A route that stops near the
  destination has not reached it. There is no nearest-contact fallback, matching 05.1a's refusal to
  snap a body to its route start.
- **The committed load boundary is GDD §5.2's carry capacity exactly** — 12000 g admits a mouse,
  12001 g does not — and a negative load is its own refusal, because a negative would pass a bare
  `> capacity` test.

## The contact schema separates the work point from the approach cell

`spatial_world.Contact` holds two `Location` records under one owner plus the owner's
`destination_revision`. The work point need only exist; the approach cell must be walkable. A
workbench, a store shelf, a well head or a water work point occupies a cell navigation need not
make passable, and collapsing the two is MOVE-REQ-013's defect one level up.

`destination_revision` must be at least 1 at bind. Zero means the caller named no destination state
at all, which is how the ruling's *"empty buildings or nonexistent service stores are not valid
targets"* is kept out of the manifest — alongside two separate conditions, a live owner reference
and current endpoints, deliberately **not** merged, so a caller can tell which of the three failed.

## Values this increment refused to invent

- **Every body, posture and gear clearance.** `profile_clearance_class_into()` always refuses
  `PROFILE_CLEARANCE_UNSPECIFIED`, including for a perfectly valid profile id, so the gap is a
  refusal a caller must handle rather than a field nobody notices. `asset_dimensions_and_budgets.md`
  states its species heights "do NOT set navigation clearance, service reach, step height or
  movement capability"; the ruling adds that battle separation radii cannot determine them either;
  and no horizontal body envelope for a resident exists in any `docs/` file.
- **A footprint or contact envelope.** No adjacency or distance rule is imposed between a work
  point and its approach cell, because imposing one would be choosing the envelope the ruling
  assigns to the contact owner. A test asserts that absence deliberately.
- **Any swim, dive, climb or tunnel speed, entry/exit duration, air budget, recovery rate or grip
  rule**, and any underground depth, elevation bound or excavation cost.
- **Any life stage but adult.** `residents.gd` has no life-stage column and GDD §5.1's cohort is
  twelve adults, so `LIFE_STAGE_ADULT` is the only profiled stage.
- **Equipment-to-passage eligibility.** Load is checked against the specified carry capacity; which
  gear blocks which passage is stated nowhere.
- **A short-trip threshold or nearest-point join for the ARCH-PATH-003 macro-anchor detour.** See
  below.

## The macro anchor detour: the new ruling supplies neither fix

Decision 0053 raised it and measured it — (100,100) → (104,102) composes to **160** against a true
optimum of **48**, bounded by the 16-cell macro. The two candidate fixes each need a decision and a
number: join the entry segment at its nearest point, or fall back to an exact-start search below
some distance.

**The 2026-09-11 continuation ruling and its index mention ARCH-PATH-003, macro anchors, entry
segments and short-trip thresholds nowhere**, and `systems_architecture.md` ARCH-PATH-003 is
unchanged. The measurement therefore stays exactly as it was, pinned by `test_navigation.gd`'s
`test_the_macro_anchor_detour_is_measured_not_hidden`, and the question remains open for
ARCH-PATH-003's owner.

## Ledger

`docs/persistence_state_registry.md` gains three rows and
`docs/validation/state_registry_coverage.py` passes. The §2.3 byte ledger and
`docs/validation/ready07_arithmetic.py` are owned elsewhere and are **byte-unchanged**:

| Table | Columns × rows | Bytes | Status |
|---|---|---:|---|
| `ResidentRouteCursor._cursor_owner_id` | 1 × 512 | 2048 | Owed since decision 0066 |
| `ResidentTravelAdmission` | 5 × 512 | 10240 | New here |
| `StarterGroundProfile` | 6 × 4 | 96 | New here |

Running total owed to those two files' owner: **12384** bytes.

## Alternatives rejected

- **A new `movement_profiles.gd` core store.** Cohesively better, and the profile catalog would sit
  more naturally on its own. Rejected because new core stores are another lane's file ownership in
  this dispatch; the catalog lives in `movement.gd` instead. If ownership is reassigned, extracting
  it is a mechanical move.
- **Keeping the old two-argument `begin_travel()` alongside the admitted one.** Rejected: a second
  entry point that skips admission is a bypass around the gate, which is the defect class this
  repository has already been bitten by. The ten existing call sites in `test_movement.gd` were
  updated instead; no test was weakened and every 05.1a assertion still runs.
- **Deriving a clearance class from crowd §5's 184/246/461/922 radii via "radius + 128".** Rejected
  explicitly by the ruling: battle separation radii cannot determine settlement body dimensions.

## What remains blocked

- **Save/load round trip: still BLOCKED**, unchanged from decision 0053. The registry describes the
  new columns; no canonical serializer exists to write them.
- **Ordinary resident travel is still not production-correct.** Routes still take a
  caller-supplied clearance class, which the ruling is explicit is not a species policy.
- **`RESERVED → TRAVEL → WORK` is still unwired.** Starter profiles were one of its three
  preconditions; real services and work-unit context are the other two and are still absent.
- **No destination-revision producer exists.** Nothing calls `revalidate_destination()` per tick,
  because no building, room or service store publishes a revision. That is the contact owner's
  piece of the ruling's item 4.
