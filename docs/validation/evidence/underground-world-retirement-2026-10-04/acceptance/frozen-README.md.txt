# ADR1155 — whole-World retirement component

Frozen candidate 9 is an owner-lifetime component. It does not activate an
operational Session, source profile, route, paid phase or playable Kitchen.
The actual Session/SettlementSystem host composition is root-owned. The fixture
uses actual World, Directory, stores, RoomOrders, Sites, Router, SpaceAuthority,
EntryWorldBindings, Locations and WorldRoutes. Its finite geometry/profile
content is explicitly synthetic. Host and Session test tokens establish only
identity, never actual mount ownership or a production content proof.

Base: `dc6baa12a2c78d873a5f3673e28df177552ce8c0`.
Owned branch: `codex/underground-world-retirement` in the matching worktree.
`source-sha256.json` pins the final executable/test/UID/census/harness packet.
`output-sha256.json` pins current evidence; `history-sha256.json` preserves every
earlier candidate and source image. Archived GDScripts are non-executable
`.gd.txt` files. No shared registry, Session, route, profile or host source is
changed by this component.

## Public composition

`Retirement.Owners` is a fixed typed packet with the full World handle and 38
strong source/owner references. Fifteen correspond to the mounted host's
borrowed World/stores/content; foundation and optional operational receivers
complete the exact original graph. The real host must prove this is its mounted
Session's tuple, complete observations, and stop admission/ticks before calling:

- `prepare_into(original_host: Object, original_session: RefCounted,
  original: Owners, out: Scope, allow_prepared_world: bool = false) -> StringName`
- `cleared_refusal(scope: Scope, original_host: Object,
  original_session: RefCounted) -> StringName`
- `release_preflighted(scope: Scope, original_host: Object,
  original_session: RefCounted) -> StringName`

Preparation copies fixed fields into Scope only after complete preflight.
Scope retains its own source/authority references; later changes to the caller
packet cannot select a new release target. Repeated preparation requires the
original complete tuple and original source images. Null and expired weak links
are different. Allowed settled projects, residents and goods remain untouched.
Active journal, haul, cold, publication and observer scopes refuse. The inherited
EntryWorldBindings read/cold brackets are covered explicitly; a settled cached
contact is permitted.

After the caller's real whole-World clear, the original Directory must have no
live entities, retain the old World generation without rewinding it, and have
its reset persistent-ID counter. Each affected store must be empty. Inventory's
bound spatial adapter must lead to that exact actual Directory and World.
Every leaf runs before the first release. The final tail calls only static
owner-owned methods; the kernel never assigns foreign fields. Buildings drops
its exact Room link; Construction drops exact excavation/modular links; Work
drops those links plus its actual delivery link and derived Script; Inventory
drops the exact spatial link, old World and checked revision. Gear, GroundPiles,
item definitions, generations and existing arenas remain under their original
owners. Inventory can subsequently bind a new real spatial namespace only at
the identical existing finite endpoint capacity; it does not resize.

The four owners expose paired `world_retirement_refusal_in` and
`world_retirement_release_preflighted_in` static leaves. Their complete typed
signatures are in the source. These are the kernel's concrete release tail,
not independent gameplay unbind APIs. In particular, unbound Inventory has no
spatial link to prove or release; the composed host/store checks still establish
its original Gear/Directory relationship.

The staged WorldInit exception captures the original Request object, accepted
seed and attempt count. The host still owns Request content validation. No new
World may be published within this synchronous interval. A freed object cannot
be passed through Godot's typed Object argument boundary; callers normalize it
to null. The kernel also checks the original host retained by Scope, rejecting
a fresh replacement token after the original Node expires.

Use exactly one caller packet and one Scope for this synchronous reset. Drop
Scope on success or abandonment before resuming admission. A Session holding
its own Scope must break the temporary Scope-to-Session strong cycle before
dropping itself. This lifecycle is an explicit root integration obligation.

## Validation and retained failures

Candidate 9: **19 tests / 1,963 assertions / 0 failures**, all strict/raw errors,
warnings, expected/tolerated diagnostics and leaks zero; analyzer **0 / 6 files**.
The actual subtype and late-source cases include original optional-null
retention, stale generation, foreign/equal-number Directory, partial clear,
hidden paid/Work carry, source-bank replacement, pending-World substitution,
freed-host refusal, original reference lifetime and actual same-capacity remount.
Old Location reads refuse after the original World is cleared.

Candidate 8's seven official singleton suites passed **429 / 15,769 / 0**.
The final correction touched only the new kernel/test; Buildings, Construction,
Work, Inventory, InventorySpatial and Locations evidence remains applicable.
Those six suites plus final candidate 9 total **430 / 15,829 / 0**. This is
selected-suite evidence, not the full no-argument project milestone.

The harness records exact commands, all current GDScript inputs, source hashes,
isolated user directory, raw clean-import diagnostics and actual restoration of
project/registry/assets/import sidecars/HEAD. The temporary new-module registry
appendix is retained verbatim and restored in `finally`; it is not a permanent
shared ledger edit.

Earlier attempts remain historical:

- Candidate 1: registry scanner could not see endpoint resize calls nested in
  the new initial-allocation condition. A bounded initial-allocation helper
  exposes the unchanged finite columns to the existing scanner.
- Candidate 2: test incorrectly treated the real void `Inventory.abort()` as a
  result object. No passing assertion was claimed from that parse failure.
- Candidate 3: stale fixture assumptions used the wrong global World slot and
  generation-reuse order; the corrected test reuses the actual original slot.
- Candidate 4: the staged-World fixture omitted the caller's existing
  externally-cleared-kind declaration. The corrected real WorldInit preflight
  uses the same explicit declaration boundary as the host.
- Candidate 5: Godot rejected a freed Node at the typed API call boundary. Its
  aborted-method diagnostics/leaks are preserved; candidate 6 instead exercises
  null and expired-original-host rejection without a freed typed argument.
- Candidates 6 and 7 are earlier passing component iterations. Candidate 8 is
  the broad owner regression. Candidate 9 adds the inherited EntryWorldBindings
  guard identified during root's early source review.

## Source census and reserve proposal

`census.py` includes both Owners packets, Scope, original Session and the
complete static cross-owner call graph. Thirteen tests reject missing owner
copies/comparisons, extra storage, transitive observers, late allocation,
nonstatic release, foreign kernel writes, omitted joint preflight, resizing the
old arena and expanded reserve constants.

| Quantity | Source count / explicit allowance |
|---|---:|
| Additional caller/Scope numeric members | 49 B |
| Additional caller/Scope reference slots | 85 |
| Original Session numeric members / references | 27 B / 24 |
| Joint numeric members / reference slots | 76 B / 109 |
| Additional numeric constants | 16 B |
| Maximum numeric/StringName chain | 141 B |
| Maximum reference-value chain | 18 |
| Proposed additional control/helper slices | 6,144 / 2,048 B |
| Provisional control / helper arithmetic | 5,601 / 973 B |

The reference assumptions are **32 B per slot**, **256 B per control object**
(three objects), **2,048 B shared-script/symbol/native allowance**, and **256 B
caller/expression allowance**. These are provisional allowances, not measured
engine representation sizes or proof of a native loading peak. The existing
Session 1,536 B is charged once. The additional, root-authorized logical
retirement carve-out is 8,192 B inside unchanged Profile 262,144 B. With the
root-reported 1156 joint 238,676 B it yields 246,868 B and 15,276 B remaining;
root must reconcile the actual shared ledger after source acceptance. There
are no new packed banks or per-resident fields. `memory-proposal-1.json` and
`memory-proposal-2.json` retain earlier arithmetic before explicit constants and
the final subtype source pin; they are superseded by `census.json`.

## Reproduction

From this worktree, with the existing local Godot toolchain:

```sh
python3 -B docs/validation/evidence/underground-world-retirement-2026-10-04/test_census.py
python3 -B docs/validation/evidence/underground-world-retirement-2026-10-04/census.py
python3 docs/validation/evidence/underground-world-retirement-2026-10-04/reproduce.py --out /tmp/ug1155-new-review
```

The last command requires a new output directory, removes only this worktree's
cache and uses a unique user directory. To repeat the broad owner selection,
append `--suites test_underground_world_retirement.gd test_buildings.gd
test_construction.gd test_work.gd test_inventory.gd test_inventory_spatial.gd
test_underground_locations.gd`. No duplicate engine run is needed for source
review; every executed image and raw result is retained.
