# 1098 — Profile-filtered static route search

2026-10-03. Independently reviewed component implementation; production entry and profile qualification remain separate.

## Decision

Room planning must distinguish a connected graph from a path that actually
fits an immutable travel profile. `candidate_path_into` remains a topology
observation. New `profile_path_into(first, last, profile_id, profile_revision,
content_revision, out, cold_token)` performs deterministic Dijkstra over the
same existing graph, filtering each prospective edge through the actual
WorldRoutes committed profile certificate from decision1097. There is no
topology-only fallback and no worker, Job, Selection or actor admission.

The actual Profiles owner fills one private Descriptor. Its exact revision,
complete certificate flags, mode and posture are mandatory, including for a
zero-span observation at one endpoint. The provider returns its exact borrowed
Catalog through `static_catalog_owner`; the query retains that actual object
and the original Bindings, Owner, Profiles, Locations and CoreSources strongly.
No caller descriptor or success flag is treated as permission.

Each callback is guarded against recursive queries and graph mutation. A
refused span may be bypassed by a longer qualified path. Changed geometry,
graph, profile/catalog content, World/endpoint identity or original memory
lease invalidates the whole search. Operation faults remain sticky through
all finite-work checks, and edge relaxation stops before any later permission
callback; only an ordinary clean span refusal may choose a detour. After callbacks finish, pure full-reference
and revision checks verify the collected edge chain before any caller output
is overwritten. Refusal preserves the entire output; successful writes use
only the caller's already-sized packed storage.

## Allocation and finite work

There is no new retained field, SoA column, save field, graph bank, heap or
distance/path array. The existing private Dijkstra scratch is borrowed only
during the guarded synchronous operation. The cold query object contains one
23-integer Descriptor (184 logical bytes), two full endpoint pairs (16), and
four integer pins (32): 232 known logical bytes. The returned Result adds 24
numeric bytes. A 512-byte logical envelope includes the remaining bounded call
controls; native object/reference headers remain separately obligated in the
existing bindings/growth allowance. This is not a measured native-memory claim.

The actual Routes Budget must cover the original `cold_token` for 512 bytes
**before** the private query and Descriptor are allocated, and again after every callback.
No unrelated same-sized or replacement lease can continue the query. Room
admission already holds the complete shared lease; the 512 bytes belong within
its existing 2,048-byte control allowance, not a second reservation. A standalone
caller may acquire 512 bytes explicitly and releases it after the call and its
returned observation have been consumed. Caller output storage remains its
separately admitted responsibility; this method never grows it.

Existing graph limits, positive integer costs, deterministic tie-breaking and
finite operation checks are unchanged. Each static profile predicate is charged
64 checks, and the final edge-chain pass charges every returned span. Engineering
capacity/work refusal does not become a room or population policy.

## Limits

This is a static path observation through completed existing endpoints and
committed certificates. It grants no actor movement, current dynamic clearance,
stance/work-face permission, construction frontier, new endpoint or surface
bootstrap. A zero-span result simply identifies the same current endpoint;
the concrete admission owner must still prove the complete body, stance,
approach, work stroke/contact and escape conditions there. Actual productive
work continues to require the assigned worker/tool/load/Job checks. The final
connector catalog does not imply installed connector identity or a temporary
construction route.

The implementation lease covers Routes/test plus the identity-only Catalog
getter in WorldRoutes. Root retains the rest of WorldRoutes and its tests.

## Verification

Clean CI-style validation passed 45 Routes tests / 9,328 assertions and 26
WorldRoutes tests / 1,711 assertions: 71 tests / 11,039 assertions / zero failures.
Every strict and raw footer reports zero unexpected/expected/tolerated
diagnostics and zero object/resource leaks. The analyzer reports zero warnings
in three files. Complete logs, commands and exact source pins are retained in
`docs/validation/evidence/underground-profile-paths-2026-10-03/`.

Independent review found a callback-fault escape in the initial candidate: a
later edge could overwrite the earlier operation error. Its small test output
also allowed an unrelated capacity refusal to hide that escape. The corrected
source preserves the first operation fault and immediately stops relaxation.
The regression supplies enough storage for the known detour and checks the
exact first error, unchanged output and absence of later permission callbacks.
Independent narrow re-review accepted the correction at Routes SHA-256
`0c597ff73989360488fef68d45120402942cec9ed32e9eee13cb54b201847d95`
and test SHA-256
`57a6542f8598f3a02f912879e3b36cb76142546e5e5e4e95859c8b1106a3e5ee`,
with no remaining high/medium findings. Review was read-only and did not
duplicate the execution above. Tests reuse actual WorldRoutes certificates and actual core owners; inherited body
and physical extents remain explicitly synthetic content fixtures. Negative
callbacks can reject or invalidate actual certificates but cannot manufacture
a passing span. Reused fixture assertions are failure-propagated to the outer
test verdict rather than silently ignored.


## Pure live reachability for actual productive contacts

The additive static entry
`WorldRoutes.profile_reachability_refusal(actual, first, last, profile_id,
profile_revision, content_revision, max_checks, remaining_out1)` borrows the
exact configured provider and existing Routes Dijkstra arrays. It observes
committed static eligibility without constructing the cold ProfilePath,
Descriptor, Result, snapshot, path output, actor or Job. The provider's existing
184-byte Descriptor supplies its search fields under the existing `_reading`
guard. The graph's `_searching` guard excludes another search or actor advance;
prepared owners and retention/occupancy observation also refuse. A call from an
ordinary graph callback poisons that outer operation before touching scratch.
The existing cold and actor searches retain their previous behavior.

The pure entry directly checks the actual provider/store tuple, complete
immutable Domain/Levels identity, loaded Catalog/Profile source hashes and
revisions, full World generation, and selected profile certificate/mode. It
then uses the existing deterministic Dijkstra algorithm with actual committed
full-generation profile bits. The selected chain retains full endpoint/edge
identity and current geometry/content. Each selected FLOOR_DATUM source is
rechecked against actual Room/World facts; consecutive identical sections reuse
that same synchronous proof. It does not scan all sparse regions or create an
R/O snapshot. The final fixed source check also runs on a zero-span query.
A zero-span success still provides no body/contact clearance or traversal.

All observation hooks are outside this method: it invokes no public Catalog,
Profile descriptor, Terrain binding, Location read or route-certificate callback.
Contacts must independently check the current actual worker/tool/pose, local
physical contact/support/exclusions, Placement prefix/Frontier source,
materials and safe-retreat conditions. This query proves only reachability in
current committed static certificates. Dynamic actors and physical obstacles
are not newly qualified by reusing those certificates. COMMIT callers must
retain their exact live endpoint payloads/receipts before preparing companions;
this live-only query is deliberately unavailable once preparation begins.

`remaining_out1` must already contain exactly one I32. A refusal preserves it;
only complete success writes the remaining finite work. Initial and final
source/Domain/digest checks cost 1,024 each. Four search-array initializations
cost 4N before any fill. The existing heap, ordered-edge scan and collection
continue to spend their original work; each committed-bit read costs 64,
final chain checks cost 16 per edge, and each selected endpoint/section step is
precharged. A section source lookup reserves 256+4O before its bounded O-slot
scan. Every amount is taken from the caller's one limit, bounded by the actual
Domain and MAX_CHECKS. No out-of-work path publishes a partial answer.

No bank, authoritative column, retained map, epoch, save field or owner control
is added. The deepest declared numeric frame path is bounded by 512 logical
bytes: public arguments 48, search arguments 40, selected-chain locals 40,
endpoint packet 52, section arguments 16, Location section/source frame 52,
source lookup 24, and at most 64 nested Directory/Room values =336. Alternative
heap/descriptor/fixed-source branches have smaller simultaneous scalar frames.
The existing provider Descriptor and graph scratch remain charged in their
existing owners; caller `remaining_out1` is 4 bytes. Native interpreter frames
remain a separate measurement obligation. Callers must include this frame
ceiling in their actual nested Contacts/control lifetime, not create a second
arena or assume another subsystem's unused allowance.

The isolated clean correctness run in
`docs/validation/evidence/underground-connector-placements-2026-10-03/hot-2/`
passed 137 tests / 13,326 assertions / zero failures; every strict/raw diagnostic
and leak count was zero, with analyzer 0/5. The rejected hot-1 run retained an
incorrect flags-bank length assumption; it supplied no accepted timing result.

Timing qualification **failed**. The actual O2048 source-capacity fixture
performed 20 batches of 256 live callers through a three-span committed path
(5,120 successful queries) with 256 actual living residents. Batch times were
45.749 ms minimum,46.649 ms median,47.555 ms p95 and47.770 ms maximum. The parent
full suite ran concurrently, so these are diagnostic Mac timings rather than
qualification-floor results; even so, they expose a material per-worker-search
cost. The Object counter was unchanged across the completed measured loop,
but that fact does not establish transient allocation, native peak or CPU fitness.
This increment is not qualified for an unbudgeted full search for every
productive worker. Bounded scheduling or valid shared reuse with current
source validation remains required before that runtime claim.


Independent read-only review accepted all five hot-2 pins with no high/medium
finding. The final hot-3 run changes only the Object-counter assertion wording;
it again passed137 tests /13,326 assertions with all strict/raw diagnostics and
leaks zero, analyzer0/5 and exact source/restoration checks. Final batch p95 was
46.419ms; the earlier47.555ms remains retained, and both fail the runtime gate.
See hot-3/source-sha256.json for the committed source/test closure.

## Bounded immutable attestation reuse

The next source candidate adds four unsaved I64 controls to WorldRoutes:
the original native instance identities of Catalog, Profiles and Levels, plus
the last fully attested Catalog revision. These 32 logical bytes fit its
existing4096-byte fixed allowance. They retain no object, bank or permission.
Native instance IDs are composition checks, never saved EntityRefs.

Every hot call still checks the complete actual owner wiring, immutable Domain,
full live World, current Catalog/Profile/Level revisions, bounded source rows,
and selected full endpoint/section/source identities. The reusable attestation
skips only the three already-proved immutable digest comparisons for the exact
original object tuple and unchanged Catalog revision. Catalog and Profile
loaders require strictly increasing content revisions and do not offer reset;
Levels loads once. A public source replacement therefore either invalidates
the committed route certificates or requires a new complete digest comparison
after actual cold recompilation. Equal bytes and revision on another owner
cannot reuse the original composition. The existing pure certificate tail
also checks these original owner identities after its observing callbacks.

Locations additionally holds the source-row hint documented in1105,16 logical
bytes. Combined new retained controls are48 bytes, with no new arrays or path
map. Every existing finite-work precharge remains unchanged, including the
conservative source-capacity charge on a hint hit. The deepest declared helper
frame remains336/512 logical bytes. Native headers/frame allocation, full-size
distinct-path workloads and qualification-floor timings remain open; neither
memo is an actor, contact, physical-retreat or dynamic-occupancy permission.

The rejected hot-4 run exposed a cold generic-provider boundary: an outer
`static_profile_edge_refusal` override replaced the actual Catalog after the
production provider returned. The retained private query still held the old
Catalog and could copy its answer. This is a source-identity defect, not a
permitted cache shortcut. The existing Catalog reference now lives in the typed
`Routes.Bindings` base instead of the derived WorldRoutes declaration. The cold
caller directly compares that current field with its originally pinned Catalog
after each callback and immediately before output. There is no new provider
reference slot, callback, preload cycle or caller success flag. Base bindings
remain null and their permission callbacks continue to refuse; actual
WorldRoutes explicitly initializes the inherited field during configuration.
The original outer-override regression remains active, separately from the
nested actual Terrain callback case. Evidence retains both rejected iterations.

Final frozen hot-6 validation passed144 tests/13,550 assertions with every
strict/raw diagnostic and leak count zero, analyzer0/5, and exact source/project
restoration. Actual256-query diagnostic p95 was26.018ms (minimum25.307,
median25.609,maximum26.232). This is an improvement, but remains failed runtime
qualification. The source-qualified evidence and rejected iterations are under
`docs/validation/evidence/underground-connector-placements-2026-10-03/hot-6/`.

Independent Construction read-only review accepted all five hot-6 source/test
pins, rehashed unchanged at the end, with no high/medium finding. It reviewed
source-row/full-generation freshness, immutable owner/revision reuse, the outer
callback cold-boundary correction and the48-byte census. It did not rerun engine
tests. The timing/native qualification limits above remain open.

## Measured packed-read overhead

The next bounded change follows an actual helper breakdown, rather than adding
another cache. The same actual 256-resident, O2048, three-span fixture measures
the two source checks, descriptor lookup, existing Dijkstra, final chain and
selected endpoint/source proof separately. Twenty batches retain distribution
tails. The isolated helpers execute under the same owner scratch guards and
are bracketed by a successful complete production query. The phase timings do
not sum exactly to the full query because their measurement boundaries differ.

| Phase, 256 calls | Baseline p95 ms | Direct packed reads p95 ms |
| --- | ---: | ---: |
| Complete production query | 25.710 | 21.465 |
| Both source/store attestations | 8.462 | 8.263 |
| Profile descriptor | 0.406 | 0.276 |
| Existing Dijkstra | 6.865 | 5.303 |
| Final full-edge chain | 1.682 | 1.316 |
| Selected endpoint/source proof | 5.438 | 3.874 |

Nested single-field accessors in full-ref pair/liveness reads now read the same
packed offsets directly. Search mode/posture/revision tests do the same.
WorldRoutes borrows existing typed Catalog, Profile bank/Descriptor and Location
bank references within each synchronous helper. Every prior comparison,
source check, callback guard and finite-work charge remains; no cache, field,
bank, revision, map or permission is added. No physical Terrain scan is hidden
in these timings: current local terrain/contact/support remains the separate
actual Contacts obligation.

The new endpoint stride local adds 8 declared numeric frame bytes. The
conservative deepest simultaneous helper census becomes 344/512, within the
same actual caller allowance. Other added locals borrow existing objects;
their native reference/frame cost remains unmeasured. Retained controls remain
Locations/Routes 2102/2112 and WorldRoutes' existing 4096 allowance. No larger
arena or authoritative storage is admitted.

Both clean runs passed 145 tests / 13,835 assertions / zero failures, with all
strict/raw diagnostics and leaks zero and analyzer 0/5. Exact manifests,
isolated user-directory settings and restoration proofs are retained in
`docs/validation/evidence/underground-connector-placements-2026-10-03/hot-profile-1/`
and `hot-profile-2/`. The latter source stayed unchanged throughout its run.
Its full-query minimum/median/p95/maximum were 21.113/21.340/21.465/21.778 ms.

This is still **failed runtime qualification**. Repeated small-path diagnostics
do not qualify aggregate ticks, distinct long paths, native transient memory
or the minimum-spec machine. In particular, an unbudgeted full search per
productive worker remains unsupported; scheduling or separately justified
shared proof remains a later contract, without dropping current source checks.

Independent Construction review accepted all five `hot-profile-2` source/test
pins, rehashed unchanged at the end. The review checked identical packed offsets,
short-circuit bounds, borrowed-object lifetime, unchanged predicates/charges and
the 344/512 census, with no high/medium finding and no duplicate engine run.
