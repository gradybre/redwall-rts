# Decision 1076: actual Inventory with sparse floor endpoints

Base: `37af9880` on `codex/underground-inventory-locations`. The final tested
source is pinned by `review-corrected/source-sha256.json`; the three changed
source/test files are the complete code delta from that base. Registry and
decision prose are not engine inputs.

## Accepted candidate

`review-corrected/` is the accepted candidate. The reproducer moved this
worktree's demo assets aside if present, deleted `godot/.godot`, ran the clean
headless editor import, then invoked the unchanged strict runner for six exact
singleton shards. It restored the assets in `finally`. The clean import had no
error or warning lines. All six suites ran once:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Inventory spatial endpoints | 18 | 274 | 0 |
| Inventory | 144 | 1013 | 0 |
| Inventory ground piles | 29 | 233 | 0 |
| Ground piles | 42 | 547 | 0 |
| Inventory anchors | 27 | 229 | 0 |
| Inventory capacity reduction | 5 | 34 | 0 |
| Total | **265** | **2330** | **0** |

Each suite independently reports these two strict footers:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The new suite summary is `18 test(s), 274 assertion(s), 0 failure(s)`.
The analyzer reports `0 GDScript warning(s) in 0 of 3 file(s)`.
These are focused regressions, not a full no-argument suite qualification.

The tests use actual Inventory transactions, journal, containers, lots and a
real Directory World. Their location geometry is explicitly synthetic.
They do not qualify actual underground support, traversal, hauling, runtime
memory, performance or save/load. Those depend on the 1075 world composition,
1072 joint capacity accounting and UG16 versioned persistence.

## Review and correction history

The root-level logs are preliminary, before all endpoint tests were written.
`final/` is a historical attempted freeze; its anchor suite failed because a
corrupt negative anchor in an unconfigured legacy store returned the new
spatial error instead of the established `AUDIT_ANCHOR` error. The fix requires
an actual reverse-matching endpoint before selecting the new error namespace.
`corrected/` then passed 261 tests / 2217 assertions, but was still awaiting
independent review and is not the accepted source.

Independent reviewer `ug_furnishing` found two additional issues in that
candidate: a provider could commit/abort/reset the caller's transaction during
attestation, and the complete flat footprint query silently omitted spatial
endpoints. The accepted candidate guards lifecycle and non-journaled setup
doors, preserves a poisoned caller's journal until that caller rolls back,
and refuses a flat completeness query without writing partial output. Four
new tests exercise these failures, including callbacks after real provisional
goods were created and callbacks outside an open transaction.

The reviewer matched all three final hashes and accepted the narrow fix
review with both findings resolved and no remaining blocker in that scope.
The reviewer did not duplicate the engine tests. A preliminary orchestration
attempt also used an incorrect Python discovery helper name; it ended after
clean import and supplied no suite evidence. The committed reproducer uses
the actual `discover`/`make_plan` API and was executed for the accepted run.

## Reproduction

From this repository worktree, choose an output directory that does not exist:

```sh
python3 docs/validation/evidence/underground-inventory-spatial-2026-10-03/reproduce.py /tmp/redwall-inventory-spatial-recheck
```

The script refuses an existing evidence directory or asset holding path,
checks the exact singleton selection, treats nonzero runner/analyzer results
as failures, and verifies the three source hashes remain unchanged during
the run. It uses analyzer port 6157; coordinate that port with concurrent
validation before invoking it.
