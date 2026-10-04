# Modular build: first-wave independent review

2026-10-02. This is incremental module evidence, not completion of the demo
workflow or of any full movement qualification gate.

## Queue tooling

The construction subagent independently reviewed the integration owner's
queue validator, unit tests, lane definitions and decision1051. It reproduced
three medium defects: noncanonical path aliases escaped overlap checks;
blocked workers immediately lost file ownership; and prematurely verified
dependencies released downstream work. Re-review found a remaining free-lease
escape for blocked workers.

All four cases were corrected. Paths must be canonical repository-relative
POSIX paths. File leases are independent of task status, with stop evidence
required to release a held lease. Free leases are only valid for unassigned,
never-started queued lanes. Active/implemented/verified lanes require verified
prerequisites. A ready batch also excludes mutually overlapping candidates.

`python3 -m unittest discover -s tools -p test_underground_build_queue.py`
reports **15 tests, OK**. Queue validation reports:

```text
ok: 17 lanes, 107 requirements; complete coverage, acyclic dependencies, no active file conflicts
```

The final qualification lane does not count as an implementation owner when
checking requirement coverage. The tool prints data and never executes
instructions or shell commands from that data. Actual evidence is reviewed by
the integrator; a nonempty JSON evidence field is not a cryptographic proof.

## UG02: room project editing holds

Worker code commit `02e98b7cc636271f7e3752c23b51ed9473fc8cf4`, registry
commit `16159538781c5893efb36850769c3b58a6998a21`; integrated unchanged as
`a244755e` and `a93a5a34`. The separate integration owner read the implementation
and checked pause preservation, generation/session reuse, late jobs,
coordinator members and outstanding claim handling. No blocking issue remains
within the narrow module scope after the worker's additional adversarial tests.

```text
20 test(s), 301 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Focused clean-import/strict-shard and changed-file analyzer evidence is recorded
in decision1053. The integrated registry gate reports 93 modules, 441 rows and
758 packed columns. The full combined no-argument suite remains due after the
first wave is assembled.

Remaining obligations are explicit: production dispatch must call the new pause
owner; invisible same-value writes to Construction's legacy boolean require a
reason-aware owner API/call-site integration; persistence is not yet activated;
and this module does not perform excavation. At the measured full Job pool,
acknowledgement averages 5.55ms, so it must not be polled per frame or simulation
tick. This is local evidence, not a minimum-hardware qualification result.
