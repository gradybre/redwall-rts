# Exact World/Room phase delegation

2026-10-03. Final source hashes are in `iteration-3/source-sha256.json`.
The new test uses actual World, Terrain, sparse Owner, Construction, Sites and
Budget owners. Its registrations remain explicit unstarted fixture data; these
observations grant no productive permission.

The clean CI-style focused check moved assets outside the own Godot project if
present, deleted only the own `.godot` cache, ran the exact editor import, then
strict singleton selections through the unchanged CI runner and analyzer
`--max 0`. Assets were absent and restored to that same state. Source pins were
unchanged throughout.

Final results:

- World/Room composition:8 tests,83 assertions,0 failures.
- Existing WorldBindings:37 tests,828 assertions,0 failures.
- Actual RoomBindings:17 tests,604 assertions,0 failures.
- Total62 tests,1515 assertions,0 failures.
- Every suite: `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
- Every raw footer: `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- Analyzer: `0 GDScript warning(s) in 0 of 2 file(s)`.

Retained rejected iterations are part of the record. Iteration1 stopped after
import because the Python wrapper supplied an incorrect `make_plan` keyword;
no tests ran. Iteration2 exposed a test-only inherited `Bindings` type-name
collision:1 test,0 assertions,2 failures and1 unexpected parse diagnostic. The
explicit `WorldComposer` alias fixed that test error. Neither rejected run is
passing evidence.

Tests cover exact outline holes and lower floor identity, unchanged physical
state, once-only quiescent identity wiring, wrong Site/full Room generation,
foreign/expired Budget tokens, provider expiration, and nested mask/metadata/
compositor calls. This increment does not establish the first playable Kitchen,
real worker contact qualification, fixed connectors, save/resume or256-resident
performance. Independent review is recorded alongside the committing decision.

Independent geometry review accepted the final unchanged source/test hashes
with no high/medium finding, checking exact actual object/scope identity, weak
ownership, before/after callback proofs, reentry, stale cleanup and73-byte
logical census. The reviewer read the strict/raw/analyzer evidence without
claiming a duplicate engine execution.
