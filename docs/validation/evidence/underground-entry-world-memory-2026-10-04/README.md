# Entry World memory accounting

ADR1131 accounts for the additional Entry World composer once, outside the
fully assigned binding reserve. This is source-derived logical accounting;
native memory and the complete simulation peak remain unqualified.

Construction reviewed the allocation/borrowed-packet checker and found two
mutation gaps, both corrected. Geometry independently reviewed the final
build wiring, architecture and READY07 reconciliation. Its one documentation
finding was corrected. Exact reviewed hashes are in `review-history.json`.

The first 146-test run injected two explicitly named frozen source records into
the parser index. `injected-evidence.json` and `candidate-pack.json` preserve
that developmental result without presenting it as normal integration proof.

After the accepted sources were committed in this worktree at `886a5600`, the
normal invocations in `normal-source-v1/invocation.json` passed:

```text
Ran 146 tests in 35.358s
OK
```

Artifact generation and `--check` both pass. READY07 reports PASS with 49
allocation rows, payload 91573078, and runtime tests NOT_RUN. Source hashes
were unchanged during those checks. The final pack has exactly the same
non-hash data as the independently reviewed candidate.

The distinct reservation is 2048 bytes: 130 numeric bytes, 72 packed bytes and
a 1024-byte logical helper allowance fit within it. The existing Contacts
packet and World base are borrowed or inherited and counted separately once.
Current joint mutable/reserved bytes are 4968921; one World plus the existing
reserve is 99961686, leaving 38314 below the decimal 100 MB gate. The rejected
two-World peak remains over the limit. Neither the memory limit nor a runtime
reserve was increased.

The exact accepted memory tooling was also executed without injection on the
integration branch at a1a16255. `integration-source-v1` retains all commands
and source hashes:146 tests passed; the exact pack check and READY07 passed
with49 allocation rows and135 checked links. Source and HEAD stayed unchanged.
This does not measure native runtime allocation.
