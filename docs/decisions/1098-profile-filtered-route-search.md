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
