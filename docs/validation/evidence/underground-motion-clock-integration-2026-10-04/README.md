# Adopted stair timing: integrated source checks

The Clock and Motion runtime sources at `focused/source-sha256.json` passed a
clean asset/cache import and two strict singleton suites against the actual
shared persistence registry. Project settings and assets were restored. This
checks the source-time sampler; it does not activate a worker or close playable
movement, native-memory, or whole-game performance requirements.

```text
14 test(s), 2090 assertion(s), 0 failure(s)
15 test(s), 13671 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The combined result is 29 tests / 15,761 assertions / 0 failures. Both suites
have the identical quoted diagnostics and raw-log summaries.

Independent review subsequently found that the first Python allocation census
could miss alternate collection syntax. The corrected checker pins the entire
normalized executable before counting it. Ten Clock-specific regression tests
passed independently, including the original three reproduced bypasses. The
complete corrected memory suite passed **225 tests in 63.818 seconds**; see
`final-memory-tests.log`. The first attempted module-style invocation failed to
resolve the tool's local import; `corrected-memory-tests.log` preserves that
invocation error. Running the script directly supplied its required module path.

Only the Python checker and its regression tests changed after the focused
engine run. Runtime sources, registry and generated memory pack remained
unchanged. `focused/source-sha256.json` deliberately preserves those earlier
Python pins rather than retroactively claiming they were the final checker.
The final checker pins and independent acceptance are in
`../underground-motion-clock-memory-review-2026-10-04/review-v2/`.

Clock counts 208 additional logical bytes: combined Motion/Clock helpers use
1,298 of the existing 4,096-byte reserve, and the 44-byte caller packet fits the
existing 176-byte caller maximum. The complete declared pack remains
99,998,782 bytes with 1,218 bytes of headroom. Native allocation has not been
qualified. No memory or diagnostics limit increased.
