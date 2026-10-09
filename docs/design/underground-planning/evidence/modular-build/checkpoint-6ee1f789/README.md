# Rejected full checkpoint — 6ee1f789

The exact integrated commit `6ee1f789086def471a8f56c59d3cdedfc7505ecb`
ran the clean-assets/cache/import procedure and the no-argument full suite.
Import completed with no raw error, warning or leak markers. The full suite
failed one stale historical-catalog expectation after the independently
reviewed v2 publication renewed the actual consumer pins:

```text
10879 test(s), 997764 assertion(s), 1 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
error: 1 failing test(s).
```

`test_historical_geometry_input_cannot_reopen_current_production_catalog`
expected source drift from the active catalog; the reviewed current source now
correctly returns success. The follow-up tests current v2 success and actual
cached Contacts source refusal against the unchanged historical v1 digest.
It changes no source guard, profile geometry or qualification flag.

The full runner stopped on failure: there is **no raw success footer and no
analyzer run** for this checkpoint. Import took11.309s and the suite1682.646s.
Source and HEAD stayed unchanged, and the original absent-assets state was
restored. `invocation.json` and `source-sha256.json` retain exact provenance.
All34 Specification workflow commands passed separately under
`specification/invocation.json`; they do not turn the failed suite into a pass.

Reproduce on this exact source with the committed checkpoint runner and a fresh
output directory:

```sh
python3 docs/validation/evidence/underground-checkpoint-runner-2026-10-04/reproduce.py 6ee1f789086def471a8f56c59d3cdedfc7505ecb <fresh-output-directory>
```
