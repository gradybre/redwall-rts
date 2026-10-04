# 1094 — Packed room footprint validation

2026-10-03. Accepted after independent source review and strict component
verification. Production room admission remains a separate integration step.

## Decision

Preserve the public `RoomFootprint.validation_error` API, all refusal precedence,
canonical cells, connectivity, pinch and hole policy, and the existing 16,384-cell
operation ceiling. Validation alone replaces Dictionary flood/contour scratch
with a finite one-call packed packet. Shape creation, canonicalization, boundary
edges/loops, shell/surface consumers and every other public helper remain intact.
The pure geometry helper grants no actual Room, excavation, support or service.

Three I32 arrays hold vertical neighbors and a BFS queue; one byte array holds
visited and diagonal-corner flags. Exact logical packed capacity is 13N bytes plus
one 8-byte capacity scalar. Invalid requests refuse before allocation, never clamp
to a smaller plausible shape. `validation_scratch_bytes(N)` supplies that logical
payload before construction; native object/packed headers and helper call frames
remain separate caller-admitted control/growth costs. No packet survives the
synchronous validation call and there are no authoritative fields or save data.

## Algorithm and equivalence obligations

Canonical Z/X order gives left/right neighbors directly. A monotone merge over
successive occupied rows records up/down and both diagonals, examining at most
three matching cells per prior cell. Empty coordinate spans are never traversed
or allocated. BFS marks a cell on enqueue; every cell appears at most once in
its exactly sized queue. Disconnection still precedes any boundary/hole refusal.

Two occupied opposite cells at a grid vertex, with the other two absent, identify
the same ambiguous diagonal pinch as duplicate outgoing contour edges. After
cardinal connectivity and pinch exclusion, the finite planar cell complex has
Euler characteristic `N - shared_edges + filled_2x2_squares`. Connected shapes
without holes have characteristic 1; explicit hole policy remains unchanged.
This is integer topology of the exact cells, not a replacement room shape.

Independent small-grid tests compare every 4×4 subset under both hole policies
against a Dictionary membership flood and unchanged public contour tracing.
Signed extremes, enormous sparse spans, malformed/duplicate/refusal ordering,
multiple holes, narrow staircases, full existing capacity, exact packed allocation
and repeated transforms are required. Runtime evidence must quote strict/raw
diagnostics and leak totals, not process status alone.

## Admission boundary

Decision 1092's 477-cell conservative Dictionary allowance remains an unfinished
engineering admission limit and cannot become a player-facing room cap. This
packet only supplies a smaller proven validation primitive. Integrating it into
actual admission additionally requires the larger-plan/composed-survey lifetimes
to fit the same real World cold lease, without shape truncation or another hidden
limit. Root retains WorldBindings ownership; source-counted survey capacity or
one reviewed immutable plan lifetime must close separately before activation.

## Verification and review

Two clean CI-style component runs move demo assets aside, remove this worktree's
`godot/.godot`, run the exact headless editor import, then select complete suites
through the unchanged strict runner and its full shard manifests. Both imports
have no errors or warnings. Assets are restored afterward.

| Suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Packed footprint parity and capacity | 8 | 196768 | 0 |
| Existing footprint | 36 | 4038 | 0 |
| Existing room layout | 57 | 563 | 0 |
| Actual room orders | 28 | 1457 | 0 |
| Actual room admission | 15 | 504 | 0 |
| Total component evidence | 144 | 203330 | 0 |

Every suite reports the same strict and raw diagnostic footers:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`. The actual
16,384-cell buffers occupy 212,992 packed bytes plus the 8-byte capacity. Four
successive full-size validations took 97,141 microseconds on this local machine;
this is cold-path diagnostic evidence, not a frame or target-hardware budget pass.

Independent root review traced canonical preflight, linear row joins, signed
extremes, enqueue marking, both diagonal pinch cases and the connected Euler
hole count. It accepted the exact source/test pins with no high or medium
finding. No production source changed after that review. Full logs, manifests,
analyzer commands, source hashes and review scope are retained under
`docs/validation/evidence/underground-footprint-packed-2026-10-03/`.

No full-game suite, native allocation measurement or playable room admission
is claimed by this packet. The follow-up will use one actual unfiltered retained
space image plus bounded actual Terrain checks for virgin admission, retaining
every claim/history check and the explicit missing-entry refusal. That removes
the redundant composed natural/output image without weakening the proof or
introducing a replacement room-size policy.
