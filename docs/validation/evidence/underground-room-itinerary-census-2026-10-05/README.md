# Independent 1165 itinerary census and source review

The frozen helper and its two caller changes fit the existing logical
reservations. No retained field, bank, path, descriptor, selection, actor
column or capacity-sized array is added. This is source arithmetic and static
eligibility review; it does not qualify native RAM, runtime handoffs, movement
or paid excavation.

The review branch is `codex/underground-itinerary-census`, created from freshly
fetched `origin/master` and fast-forwarded to accepted `5b440aed`. All writes
are confined to this evidence directory. Root's source files and checkout
were read only; no engine, import or native process was started.

## Exact reviewed input

| Input | SHA-256 |
| --- | --- |
| New `underground_room_itinerary.gd` | `e2d53bb2fab86633016f5263ec364f54bad66579032bec11f046ce0f4c80c1e0` |
| Provider `underground_room_world_bindings.gd` | `95d13b1d36daec7d6a5993d2aa5d6d673618a25020acb6b949b6cccc51d4bb68` |
| Frontier `underground_room_frontier.gd` | `c012d8eae1346fb1785ad71d105e79e3da747fbc9158fb3a74f749217bf233c6` |
| Root's dedicated test | `47d3c709204743e3364baa872e128aabad2b1813eab85bd2871cbf3cee68301d` |

The first three are nonexecuting `.gd.txt` snapshots beside this file. The
test snapshot and byte-exact root logs are under `reviewed-root-evidence/`.
The locator manifests identify their original paths and hashes.

`predecessors/` retains the exact old Provider/Frontier bytes from `5b440aed`,
so integrating the new caller cannot turn it into its own historical baseline.
The turn census producer is also retained and hash-checked before importing
only its `PATHS`; its complete import closure is the standard-library modules
`hashlib`, `json`, `pathlib` and `re`. Its main function is never invoked.
`predecessor-sha256.json` pins all three witnesses. All referenced current
GDScript functions are independently re-parsed and pinned in the runtime
source manifest. No shallow-clone Git lookup is required during replay.

`source-sha256.json` pins the complete 30-module census input at accepted
runtime checkpoint `3851584553399ee41fbdcb41c08e35543a416ffe`, with the three
frozen new/wired snapshots above. The earlier `5b440aed` pin set and result
are retained as `pre-1161-*`. The five changed full files are Routes,
WorldRoutes, Locations, FinalFacts and WorkFace. The read-only replay after
1161 produced an identical complete structured result except those hashes;
`renewal-38515845.json` records that comparison. This is an explicit census
renewal, not a new engine acceptance claim for the combined checkpoint.

## Simultaneous storage

| Existing slice | Source-counted use | Limit |
| --- | ---: | ---: |
| WorldRoutes fixed numeric fields and reusable packets | 958 B | included below |
| Existing WorldRoutes constant payloads | 500 B | included below |
| New Itinerary constants | 124 B | included below |
| One sequential WorldRoutes helper allowance | 512 B | included below |
| WorldRoutes logical subtotal | **2,094 B** | **4,096 B** |
| Provider fixed 218 + helper 512 + provisional native 256 | **986 B** | **1,024 B** |
| Frontier caller/private packets 430 + helper 1,024 + provisional native 512 | **1,966 B** | **2,048 B cold** |

The WorldRoutes remainder of 2,002 bytes still covers provisional native and
reference/header accounting; it is not a measurement of Godot's interpreter,
Script, StringName, Variant or object overhead. No global reservation grows.
WorldRoutes constant strings are charged as UTF-32 payload plus a terminator.
The already admitted SourceProgram's 640-byte scalar/string payload is
recomputed from source and charged once in the existing Profiles controls,
not again here. Inherited EntryBindings controls and the existing shared
128-byte PhaseContext remain in their original allocations.

WorldRoutes retains one Domain, one Descriptor, two Profile boxes, one Location
Record, one Region, one Edge, one IntResult and their existing fixed packed
scratch. The exact field topology includes reference and bank fields, so a
new reference cannot evade the scalar sum. No new instance of these packets
is constructed by the helper or either dispatch change.

The existing Routes Dijkstra arrays use 29 bytes per configured Location
(29,696 at 1,024): distance, predecessor, heap node/position, search-state
and reverse edge-generation pairs. The two existing certificate banks total
159,744 bytes. Both are reused in place, with no third image or second path.
The single caller `PackedInt32Array[1]` output is already included in each
caller's packet and changes only on success.

## Complete call lifetimes

The recursively resolved itinerary closure contains 61 source functions.
Every declared numeric parameter/local/loop variable is charged, including
all branches in a frame; mutually exclusive child frames take their maximum.
Borrowed references and native queries are listed separately in `census.json`.
The longest chain is:

```
Itinerary.reachability_refusal 48
  _search                    40
  _find                      40
  _relax                     64
  _edge_profile              24
  _compatible                48
  SourceProgram.profile_refusal 88
  Profiles.selection_policy_leaf 32
                             ---
                             384 + 48 expression/return = 432 / 512
```

Provider's active outer chain is 169 bytes (`worker_refusal` through
`_ordinary_live_contact`, resource/storage observation and `_ordinary_path`).
Its simultaneous declared total with the itinerary is **553 bytes**, not a
claim that the whole call fits in a single 512-byte slice. The Provider frames
remain in its existing helper slice; the foreign itinerary closure occupies
the WorldRoutes slice once. Provider's unchanged maximum own chain is 272
bytes and its accepted complete non-itinerary foreign helper proof is 485
including its allowances.

Frontier's active outer chain is 72 bytes (`contact_into → _observe → _path`),
so its simultaneous declared itinerary chain is 456 bytes. Its existing cold
helper remains a deliberately conservative bound of 144 own + 512 foreign +
128 expression/return = **784 / 1,024**. The foreign 512 is a bound used for
admission, not a second physical copy of the WorldRoutes stack. Its WorkFace
proof has returned before path search. The existing Frontier cold reservation
of WorkFace 378,880 + controls 2,048 = 380,928 stays unchanged, and no Frontier
packet survives into paid phase companion preparation.

The complete existing one-profile static search is 336 + 48 = 384 bytes.
Its certificate is proven non-null from the actual call through `_find_path`
and `_relax_edges`; only `_path_profile_refusal`'s first committed-mask branch
is eligible. Counting the unrelated actor-query branch would splice mutually
exclusive operations into a false stack. The script checks that propagation
and branch order and retains the complete declared frame.

Existing physical workpiece occupancy is 104 + 48 = 152 bytes. Existing
stationary-turn alternatives are also recounted, including their current
source-clock and final physical chains. The maximum remains observed cargo
at **464 + 48 = 512 bytes**. The independent complete dynamic Profile source
admission/tick chain belongs to the accepted Profiles helper allocation; it
is not moved into this static-query slice.

`_reach_entry_refusal` and the original owner flags exclude another search,
advance, occupancy query, candidate preparation, retention callback or route
publication. The itinerary uses the existing synchronous exclusive flags and
invalidates the old single-profile witness before altering search scratch.
These lifetimes are alternatives, not additional retained banks.

## Source and test verdict

No remaining high/medium finding in the exact static component. The earlier
Directory-reader concern is closed by checking the exact actual Directory
implementation before any private final readers. The complete helper uses
current original stores, profile/source identities, full endpoint and edge
generations, source-family payload/quantity equality, actual mask bits,
bounded Dijkstra work, deterministic ties and final source revalidation.
Both callers use the old path query only for `POLICY_AUTOMATIC`, otherwise
the selected-family itinerary, and preserve monotone remaining work.

The reviewed root tests use actual published source geometry and real
supported endpoints/certificate publication. They exercise mixed backward
and all-yaw legs, reverse certificates, repeated debt/chain identity, field
and quantity mismatch, missing masks, stale generations/source/revision,
busy/exhaustion refusal with unchanged output, zero span, equal-distance
ties, Directory subclass refusal and actual Provider dispatch. Paid-cut
history remains empty. The static path creates no READY or movement grant.

Root's retained pre-1161 integration evidence has **46 tests / 516 assertions /
0 failures** across Itinerary (13/114), RoomWorldPhases (24/290) and Frontier
(9/112); every strict/raw diagnostic and leak footer is zero. Its targeted
analyzer reports zero warnings across four files. These logs were inspected,
not rerun. Their invocation reports project/assets restored and sources
unchanged. A combined post-1161 engine/source-consumer closure remains root's
integration responsibility.

## Reproduction and negative coverage

From an accepted runtime checkout containing this evidence and the pinned
sources:

```sh
python3 -B docs/validation/evidence/underground-room-itinerary-census-2026-10-05/census.py --verify-pins
python3 -B docs/validation/evidence/underground-room-itinerary-census-2026-10-05/test_census.py
```

When the evidence branch still has its original `5b440aed` runtime base, pass
`--runtime-root /absolute/path/to/accepted-38515845-checkout` to either
command. This reads that checkout without mutating it; the three reviewed
snapshots remain the exact local inputs. No Git history or engine is needed.

All **26 tests** pass against the current 1161 sources. The mutations reject
new retained/inherited/reference/bank fields, temporary arrays, larger local
and transitive frames, unknown calls, untyped/floating values, added constant
payloads, removed Directory/exclusion/witness guards, broken certificate
propagation, larger Dijkstra scratch, duplicate resizes, nested packet growth
unrelated caller changes, changed predecessor bytes and an expanded producer
import closure. A separate case proves that current caller files cannot be
used as their historical comparison. `tests-development-1.log` retains two initial
test-mutator anchor mistakes; neither was a runtime source finding. Their
corrected exact-source run is `tests-current-1161.log`.

Native memory, runtime automatic↔READY handoffs, actual actor traversal,
short-step policy, source-consumer renewal and a complete playable Kitchen
remain separate gates. No claimed rate, geometry or permission is added here.
