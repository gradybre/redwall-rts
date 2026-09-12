# READY_07 addendum — persistence gaps, naming and responsive UI

2026-09-11 · Engineering rulings for the Claude executor. Audited source:
`28e6771fd932d6acefa0ff0b2ba10967a37419f4`. This resolves G1–G3 and I2;
it does not implement a save codec or qualify the UI. Read the current diff if
implementation has advanced. No runtime source or `project.godot` is edited by
this handoff.

Owners: [AGENTS](../../AGENTS.md), [GDD](../game_gdd.md) §5.3,
[architecture](../systems_architecture.md) ARCH-SAVE/HASH/RNG/CLOCK,
[scheduler contract](../planning/ready07_scheduler_contract.md),
[persistence registry](../persistence_state_registry.md),
and [UI specification](../ui_ux_controls.md) §1.2.
[Decision 0063](../decisions/0063-save-classification-naming-and-responsive-ui.md)
records this resolution. Earlier decision 0062 remains historical evidence.

## G1 — Command outcomes are transient; source-intent identity persists

**Do not serialize the command result ring in section 6 and do not include it
in ARCH-HASH-001. Classify it as category 3.** This covers the eight packed
columns, `_result_store_code`, `_result_write`, `_result_count` and result counters.
Results report already committed/refused work; they do not admit commands or
suppress duplicates. Whether UI readers exist today is not the classification
criterion: adding a read-only UI consumer will not make the ring authoritative.

The source-intent ledger stays category 1, section 6 AUXILIARY_STATE, included
in the canonical digest. It prevents replayed designation intent producing a
second designation/job. Pending accepted economic commands remain section 12.
Persist Chronicle/history through its actual owner when implemented, not by
promoting the rolling result ring into an undocumented history store.

On load initialize transient outcomes empty and reset UI result-reader cursors.
Never replay accepted commands merely to regenerate outcomes. Use a dedicated
transient reset; calling a dispatcher-wide clear after restoring its source-intent
ledger could erase precisely the state that must survive. On live frames,
continue delivering outcomes to the UI; loading is the explicit reset boundary.
For source-intent rows, preserve live designation matches; normalize obsolete
rows only under decision 0049's generation/liveness rule, with a destroyed/reused
designation test proving the same future admission behavior.
Source-intent targets are typed refs; result targets can be historical and should
not impose live-reference validation on a save that does not contain them.

Acceptance: identical authoritative worlds with different ring positions/results
have the same canonical digest; loading leaves no stale pending preview or success
notice; a restored source intent still refuses duplication; an accepted pending
command commits exactly once and yields one new outcome after load. These are
required codec/UI integration tests, not completed by this ruling.

## G2 — Save the current reachability byte

**`inventory._c_reachable` is category 1, section 7
INVENTORIES_AND_LEASE_INDEXES, and included in the canonical digest.** It is
an explicit InventoryContainer field in GDD §4.2 and current externally supplied
state, not a presently reconstructible index. Restore
0/1 exactly for live rows; encode canonical zero for unused payload. Validate
occupancy, the inventory generation space and byte range. No all-reachable default
and no imaginary topology rebuild is permitted.

A later topology/service implementation must explicitly define who computes
reachability, at what boundary it becomes current, and whether the meaning is
container-global or requester/profile-dependent. The existing byte cannot by
itself establish connected movement. When an actual deterministic rebuild exists,
a versioned schema change may make its result derived. Do not keep independently
writable stored and recomputed answers. Validate/migrate the old format against
the new owner or reject incompatible data; never silently relabel existing bytes.

Acceptance: save both reachable and unreachable containers; restore the bits and
verify the same eligibility, totals and operation refusals. A changed reachable
bit changes canonical state. Corrupt values reject without publishing a world.
Future derived-state acceptance must demonstrate equal-tick behavior and no
extra load-time path quota/RNG consumption before changing classification.

## G3 — Persist host continuation state; distinguish hash purposes

There is no conflict between **saving debt** and **excluding debt from the state
hash**. The misleading part was a registry where category 3 meant both “not
hashed” and “not saved,” with exceptions hidden in prose. Separate persistence
obligation from digest membership.

| State | Save owner | ARCH-HASH-001 / section 15 |
| --- | --- | --- |
| Completed tick | Section 1 plus validated header tick | Include |
| Requested speed and logical pause mask | Section 1 | Include; existing ARCH-HASH-001 does not exclude them |
| Pending scheduler records and canonical queue controls | Section 12, SCHQ0001 | Include; ring head normalizes to 0 per wire contract |
| Host debt `_debt` | Section 1 WorldRuntime, nonnegative I64 | **Exclude** |
| Six recorded clock counters | Section 1 WorldRuntime, nonnegative I64 each | **Exclude** |
| Host timestamp, callback handles, scratch, timing samples, frame-local guards | Not serialized; reset/rebind at load boundary | Exclude |

The six counters are `_fallback_count`, `_diagnostic_pause_count`,
`_acknowledged_catchup_resets`, `_acknowledged_ticks_discarded`,
`_subtick_debt_discards`, `_day_boundaries_crossed`. Historical discard counters
are evidence, not authorization to discard owed ticks now. Debt/counters are
required persisted host-continuation/evidence metadata; category 1's definition
now explicitly covers that class, with the hash exclusion stated per row.
All saved section bytes, including this metadata, remain covered by the body
SHA-256 and section CRC. No alternative state-digest bytes are added to section 15.

Do not scale, zero, clamp or subtract debt during restore. Reset the host-time
sampling origin so time spent loading is not charged. Validate representable
arithmetic bounds before publication; an invalid value rejects, never saturates.
Restore the logical saved pause mask before applying any transient LOAD guard;
adding/removing that guard must not erase PLAYER, MENU, CRITICAL or VICTORY holds
or be mistaken for an authored pending scheduler operation. Save only at a safe
completed boundary with no half-drained queue. Compare scheduler continuation
under the **same new-frame elapsed-time/event input**, not by persisting a raw OS
timestamp or resuming a partially executed host frame.

Keep three evidence claims distinct:

1. **Canonical save/replay state:** ARCH-HASH-001, with its stated exclusions.
   It still includes speed, pause and pending scheduler intent. Same boundary
   alone does not guarantee equal hashes if those inputs differ.
2. **Cross-speed gameplay comparison:** a separately labeled projection that
   excludes scheduler-control state and scheduling-only logs as well as debt,
   while holding committed economic inputs and completed tick equal. Specify its
   exact participating fields in the test; it is not section 15 and is not full
   save parity. No new digest algorithm/wire format is adopted for this probe.
3. **Host continuation:** compare restored debt/counters and subsequent scheduler
   decisions directly under identical elapsed-time/events, alongside canonical
   state agreement. Different hosts/frame inputs need not have equal debt.

Acceptance: debt `2500001` restores exactly (two owed ticks plus remainder);
changing only debt changes protected save bytes, not ARCH-HASH-001; changing
requested speed or pending scheduler input changes canonical state; a paused
load adds no wall-time debt; next-frame behavior matches with identical input.
The eight-tick ceiling and no-whole-tick-discard rule remain intact. The existing
legacy explicit discard method is not a new authorized production recovery path.

## I2 — Name the existing stable integer algorithm

Adopt **RWL-NAME-1 = ARCH-RNG-001 `hash_pair(persistent_id, world_seed)`**, already
implemented as the pure static `rng.gd::hash_pair`. Argument order is significant.
This names the missing GDD binding; it introduces neither an engine builtin hash
nor an additional RNG stream. The exact function is:

```text
h = (persistent_id XOR 0x9e3779b9) AND 0xffffffff
h = (h * 1664525 + 1013904223 + (world_seed AND 0xffffffff)) AND 0xffffffff
h = (h XOR (h >> 16)) AND 0xffffffff
given_index   = h mod 32
surname_index = (h >> 5) mod 32
```

Use nonnegative I64 intermediates and integer operations throughout. Current
persistent IDs and world seeds are positive I32 domains; reject invalid naming
inputs at the calling boundary. The general hash helper's broader accepted input
range does not broaden those domains. A zero hash is valid; the RNG seed's
zero-to-one substitution **does not apply to naming**. `RWL-NAME-1` is the
algorithm identifier, not a byte prefix passed to the function.

| Persistent ID | World seed | Unsigned hash | Given index | Surname index | Base name |
| ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 1 | 1119302415 | 15 | 24 | Ivy Pinehollow |
| 1 | 20260905 | 1139595788 | 12 | 16 | Hazel Hazelbridge |
| 2 | 20260905 | 1144555583 | 31 | 1 | Willow Ashbrook |
| 12 | 20260905 | 1134568473 | 25 | 0 | Pine Applebank |
| 2147483647 | 2147483647 | 905157919 | 31 | 8 | Willow Cedarvale |
| 16777217 | 20260905 | 1357695244 | 12 | 8 | Hazel Cedarvale |
| 65536 | 20260905 | 3724026389 | 21 | 16 | Moss Hazelbridge |

These are function vectors, not a rename of the authored **Warden Rowan** fixture.
Use the GDD's printed 32-entry catalog order; honor explicit scenario names,
player aliases and existing `-<ID>` duplicate suffix behavior. Persist the final
assigned string and naming/notable state; never regenerate a stored name on load,
promotion, transfer or a changed world seed. Restoring from saved strings also
preserves player aliases. Catalog order and algorithm identity must be covered
by naming/catalog compatibility before future generated names are permitted;
changing either needs an explicit compatibility/migration decision.

Naming-trigger integration, duplicate handling, aliases and cross-process
name/save/transfer survival still require runtime tests. The check below verifies
only the function binding, current catalog mapping and layout arithmetic.

## Three allocator families do not imply one reference type

Confirm the finding and record the domains more precisely: directory EntityRefs,
inventory **container** refs, inventory **lot** refs and navigation **route
descriptor** refs have independent generations. Container and lot domains are
separate even though the same inventory module owns both. This is three allocator
families, at least four generation namespaces; do not merge them by pair shape.

Typed-store directory mirrors must match the directory. Inventory ownership refs
may be directory refs while lot-container refs use the container domain. Movement
cursors validate navigation descriptor generations. Gear and reservation rows
are bare indices: preserve slots, holes, occupancy and intrusive child links;
validate each reference in its declared domain. A byte-perfect round trip is not
proof the original stale-handle safety gap is solved.

Preserve free/retired generations, navigation flags and allocator behavior.
Inventory's LIFO free-stack order is future-affecting and must survive; minimum
free-slot heaps may rebuild only where the same future allocation order follows.
Restore raw validated snapshot state through dedicated load APIs; do not recreate
rows with ordinary create/free/clear operations that advance generations or IDs.
Do not repair the directory/inventory integration gap inside a writer by inventing
generations or compacting row indices. Track that separately from save parity.

Codec acceptance: same numeric slot/generation in different domains stays distinct;
stale refs in each domain reject; free-slot reuse after load matches uninterrupted
allocation; a deliberately non-sorted inventory free stack preserves pop order;
gear/reservation holes, owner links and new allocations survive unchanged.

## UI canvas — proceed with the responsive correction

**Yes: change the prototype configuration/integration to implement UI §1.2.**
There is no adopted fixed-1920 canvas exception. The inspected settings combine
1920×1080 with `canvas_items`/`expand`, and no runtime content-scale override was
found. The base size alone is not the problem: the fixed stretch transform hides
the smaller logical viewport required by the specification.

Calculate S from the actual physical render viewport, exactly once, then lay out
against W/S by H/S. Keep the 3D render at its intended resolution. A suitable
implementation is disabled automatic base stretching with an explicit UI-only
scale/layout transform; an equivalent dynamic content-scale setup is acceptable
if it produces the same geometry and correct input coordinates. Do not apply both
engine base stretching and the spec's scale. Godot documents the difference
between base stretching and target-resolution drawing in its
[official multiple-resolution guide](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
Record Mac backing pixels separately from window points and handle DPI/resize
changes. Update pointer-to-world conversion and actual input rectangles together.

| Physical viewport | User scale | Logical width | Required profile |
| --- | ---: | ---: | --- |
| 1280×720 | 100% | 1280 | STANDARD |
| 1280×720 | 125% | 1024 | NARROW |
| 1280×720 | 150% | 853.333… | NARROW |
| 1920×1080 | 100% | 1920 | WIDE |
| 1920×1080 | 150% | 1280 | STANDARD |
| 3840×2160 | 100% | 1920 | WIDE |

Narrow is not expected at 1280×720 default scale. Verify these values from the
running UI, not just a settings diff; include real screenshots, focus, tool
hit-testing and drawer/command overlap cases from
[the visual brief](../planning/ui_visual_direction.md). Implementation remains
with the active Claude UI executor; this addendum does not edit its runtime files.

## Execute next and report the boundary honestly

Proceed with task 09.2's explicit per-store codec registry using these decisions;
then task 09.3 validation/load integration. The response ring is omitted,
reachability is saved, and saved host metadata has an explicit hash exclusion.
Keep full naming lifecycle and native responsive UI verification as their own
bounded implementation tasks.

Run `python3 docs/validation/ready07_addendum_checks.py --godot` for seven pinned
hash/name vectors, six layout arithmetic cases and an isolated invocation of
copies of the current production hash kernel. Run the existing registry and
READY_07 arithmetic checks too. See the companion
[validation result](2026-09-11_ready07_save_ui_validation.json) for actual results.
No save/load, full gameplay suite, cross-platform transfer, live window or visual
acceptance is established by those checks.
