# Original entrance fixture after the inheritance correction

Exact integration HEAD `101bd0fb7fa9893344e4149ea2bdce4f4c2e65c3`.
Independent source review accepted the seven named-Callable replacements from
`932d8d0990f52bfcc533c6e9da4be788e3939266`. Arguments, mutation order and assertions
are unchanged; this avoids Godot's inherited inline-lambda parser refusal.

The original entrance suite was then run with the unchanged reviewed reproduction
runner, overriding only its source/suite list and isolated analyzer port6198.
The invocation records those overrides, runner hash and identical before/after
HEAD. Assets were initially absent. The own cache was removed, the exact clean
editor import ran, and the official test wrapper ran singleton shard90/383.

```text
33 test(s), 10790 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1 file(s)
```

Source unchanged, project restored, assets restored. This is the original33-case
prerequisite, not acceptance of the new Workpieces lifecycle or a full-suite pass.

Large raw logs are losslessly stored as `.log.gz`. `compressed-evidence.json`
records both byte counts and hashes; every compressed stream was round-trip
checked. Decompress to the original recorded name when replaying evidence tools.
