# 1171 — Original SurfaceAnchor lifetime

The frozen component extends the actual mounted Room/route-owner Session with
one strongly retained SurfaceAnchor. It configures the existing real publisher,
then keeps that exact receiver alive through publication, failed construction,
whole-World retirement and remount. It adds no endpoint, actor, Room, excavation,
route edge, source profile, pace or work permission during composition.

Base: `e234bde0882695d9a0d28288f7bf45ca05b9a953`, branch
`codex/underground-surface-anchor-lifecycle`. The current source manifest is
`source-review-3/source-sha256.json`; it contains eight GDScript pins and the
runner/census/test pins. Only four runtime and two test GDScripts changed;
the Session and Retirement test modules are also pinned and run unchanged.
`source-review-3/source.diff` is the exact six-file runtime/test delta. The
narrow release correction is also isolated in `release-source.diff` there.

## API and original-owner lifetime

- `Settlement.compose_underground_surface_anchor() -> bool` calls the original
  mounted Session and rechecks that mount after the constructor returns.
- `Session.compose_surface_anchor() -> StringName` requires the real completed
  route tuple, quiescent existing cold owner and no published operational
  endpoint/Site/graph state. Successful repeated calls retain the same receiver.
- `Session.surface_anchor()` borrows that exact receiver only while the Session,
  cached source and complete original owner tuple still pass their existing
  checks. The existing `create` / `create_in_section` methods perform publication.
- One `Retirement.Owners.surface_anchor` field holds the original receiver;
  Scope copies that same reference. It is not another Anchor or another owner
  packet. Prefix 9 belongs only to the actual Session's constructor protocol.
- If configuration exposes Locations' one-way weak WorldScope and later fails,
  the receiver retains its original pins. Session retains that stopped prefix
  until exact whole-World reset. An unbound private candidate can be discarded;
  route-ready state resumes only after its original source/owner checks pass.
- `SurfaceAnchor.retirement_refusal_in` reads its original stored fields and
  weak backlink. It invokes no World, source, Directory or other public observer
  in the final retirement chain. All original canonical clear/release guards
  remain in force. Scope's strong Session cycle is broken before Session drops.
- `SurfaceAnchor.world_retirement_release_preflighted_in(actual, original,
  persistent_id, stopped_constructor)` repeats the original static owner and
  complete Directory-empty proof after the kernel has checked every owner and
  performed its four existing release leaves. It clears only the Anchor's 21
  references and four fixed buffers. All referenced owners still have matching
  strong references in the original Scope packet throughout this tail; dropping
  these aliases does not invoke a final-owner destructor during publication.
  The fixed numeric Record/Region packets remain, containing no owner references.
  The old nonnull full World reference stays as a permanent configure-refusal
  tombstone. Live or partially cleared Worlds never reach these writes.

Host admission and fixed ticks stop while the actual Anchor is publishing.
The actual World callback test attempts both reset and fixed tick during a
real natural-surface create, asserts both refuse, then verifies the original
operation releases its own cold lease and a later quiescent reset succeeds.

## Executed validation

`compile-1` retains the initial clean import and zero-warning eight-file
analyzer run. `candidate-1` retains 60 tests / 669 assertions / zero failures,
all strict/raw diagnostic and leak counts zero, analyzer 0/8. It precedes the
single added fixed-tick assertion and is not the final executed test source.

`candidate-2` executes the prior GDScript pins with official singleton
shards from `ci_test_shards.py`, clean cache/import and a unique project user
directory. It passes **129 tests / 3,566 assertions / zero failures**:

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| Session | 15 | 225 |
| Retirement | 19 | 1,963 |
| Host | 28 | 326 |
| SurfaceAnchor | 32 | 344 |
| RouteComposition | 19 | 337 |
| RoomComposition | 16 | 371 |

Those results did not establish collection while an old Anchor is held. The
actual new negative is retained in `retained-handle-repro-v1/old-run`, executed
against the exact candidate2 runtime snapshots: **30 tests / 451 assertions /
1 failing test**, zero diagnostics/leaks. Successful reset left 14 of 20 weakly
observed private owners/banks alive. Both the test runner and outer historical
source substitution record exact restoration. This is the rejected HIGH
resource-lifecycle defect, not a native-header accounting caveat.

The final `candidate-3` executes the corrected source in the four affected
official singleton suites: **97 tests / 2,995 assertions / zero failures**.

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| Host | 31 | 463 |
| SurfaceAnchor | 32 | 344 |
| Session | 15 | 225 |
| Retirement | 19 | 1,963 |

The lifetime regression keeps the old Anchor alive across actual publication,
Host reset, replacement World generation, and remount. All 20 weakly observed
private owners/banks are collectible; all 21 Anchor pins and four buffers are
empty. The tombstone refuses a new valid tuple before installing any weak
WorldScope, and a fresh Anchor binds normally. Additional cases refuse direct
release against a live World without changing any owner and preserve all
original owners/Scope during a partial clear, with dispatch still stopped.

Every final suite has zero unexpected errors/warnings, expected/tolerated diagnostic
counts, ObjectDB leaks and resource leaks. Raw import findings are empty;
the analyzer reports 0 warnings / 8 files. The invocation records exit 0 and
exact source, HEAD, project, registry, assets and import-sidecar restoration.
No runtime consumer or published profile is replaced for these tests. The
test-only registry appendix classifies the accepted stateless RouteComposition
at this base; the exact appendix and before/after hashes are retained, and the
original registry is restored in `finally`. Permanent registry is root-owned.

The real generated-World test creates one actual natural endpoint through the
existing physical publisher, captures its exact Anchor in Scope, clears through
the actual Host, then generates/remounts the current source and composes a new
original Anchor. The old full World and endpoint are not reused. Its explicit
small clearance/support boxes are a physical test fixture, **not a qualified
worker profile or a demonstration of playable access**. No Site/cut is created.
Other tests preserve original economic bytes while exercising late mounted
Gear replacement, actual cached-source drift, constructor reentry, stopped
prefix retirement, Scope replacement and missing weak backlinks.

Reproduce from this exact source closure using a new output path each time:

```sh
python3 -B docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05/test_census.py
python3 -B docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05/census.py --out /tmp/ug1171-census-new.json
python3 -B docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05/reproduce.py --out /tmp/ug1171-check-new --suites test_underground_session.gd test_underground_world_retirement.gd test_underground_host.gd test_underground_surface_anchor.gd test_underground_route_composition.gd test_underground_room_composition.gd
```

## Source census and review correction

The current census first verifies the fixed predecessor manifest, its producer,
all baseline snapshots and transitive manifests. It reproduces the complete
accepted 1167 report before importing/using the reviewed frame parser. Current
foreign constructor bodies are independently hash-pinned. It counts the new
Anchor static leaf and actual Surface configure/foreign-reader chain as well
as both Host post-constructor result helpers and the complete new static release
chain. The release helpers do not change the earlier maximum.

| Simultaneous lifetime | Logical / provisional bytes | Ceiling |
| --- | ---: | ---: |
| Retained controls, including both new Anchor reference slots | 6,131 | 6,144 |
| Complete reset/UI helper maximum | 1,919 | 2,048 |
| Constructor retained controls (Scope and its private copy absent) | 4,034 | — |
| Route constructor frames and temporary heap | 4,151 | — |
| Largest constructor coexistence | **8,185** | **8,192** |
| Separate Surface configure chain | 2,362 | within that same constructor maximum |

The retained-control increase is exactly two provisional 32-byte reference
slots. With no Scope yet, only the permanent new slot coexists during
construction. The Host's former later `final_code` local now belongs to a
separate helper frame; the complete post-tail is still counted. This saves
eight bytes only during construction, leaving seven bytes rather than raising
a reserve. Original Session 1,536 and PROFILE_BYTES joint 246,868 / 262,144
remain charged once and unchanged. Root owns shared-ledger reconciliation.

The Anchor itself uses its separately existing 2,048-byte logical reservation:
329 fixed numeric/packed/result bytes plus the existing 1,024 logical helper
allowance. Its 21 borrowed owner references, two retained packet objects and
four packed-buffer headers are explicitly enumerated. Native allocator,
header/reference and whole-client costs remain unmeasured; 32-byte reference
and 256-byte header terms in the lifetime model are provisional. This packet
does not claim all native Anchor allocation fits the logical 2,048 bytes.
Configuration opens no new cold lease or survey; existing create cold proofs
and arenas are unchanged.

Root's first independent census review found one MEDIUM omission: a typed
`PackedInt32Array` local initialized with a large literal counted as one
reference while its payload escaped the allocation guard. Runtime source was
unaffected. The exact rejected census/test bytes remain as non-executable
`source-review-1/*.py.txt`; the original eleven-pin manifest and report remain
unchanged. `source-review-2/prior-source-locators.json` relocates only those two
historical source pins. The correction compares every original member/constant
initializer and private packet declaration and rejects new packed/collection
locals, inline constructors and literal payloads, including outer Host/Session
frames. The only constructor array literal permitted is the already charged
six-kind World source check. That correction's **25 adversarial tests pass**;
its exact scripts/report remain preserved under source-review-2 and its
`retained-before-release-fix` locators. The current **30 adversarial tests pass**,
also requiring complete pin release, the tombstone, static full-World proof and
tail ordering. Exact source/census diffs and replay are in `source-review-3`.
Historical manifests retain their original bytes; the review3 historical
manifest mappings select only explicitly archived same-byte locators.

Root independently accepted exact source-review-3 on 2026-10-05. All 11 source,
six input, 45 output and 145 history pins and 140 historical locator rows match;
the reviewer independently reran all 30 census tests. Both the allocation-guard
and retained-Anchor findings are closed. The verbatim receipt is
`accepted-review-3/root-acceptance-review3.json`, SHA
`8d689dfa42847f7a243d78fe73f0b0373926bec220fc0b073266729658723bd0`.
No reviewed executable or original manifest changed for this acceptance note.
`accepted-review-3/reviewed-document-locators.json` resolves the original reviewed
ADR/README bytes; the acceptance manifest binds these notes separately.

Native memory measurement, current shared-ledger reconciliation, actual demo
surface/access wiring, complete worker clearance/approach, operational movement,
paid work and playable empty-Kitchen acceptance remain separate.
