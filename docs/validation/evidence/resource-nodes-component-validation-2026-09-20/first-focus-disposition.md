# First focused-run fixture correction

The first run completed all8tests/85132assertions with1failed test. The product predicate was not at fault: the parent copied only an outer Array before changing an intentionally bad column, so the packed element was still shared with the expected public-history image. The run exposed that fixture alias through the live-reader equality and later expected-success checks.

Parent correction duplicates every packed buffer for the bad fixture and for per-position/shape nonmutation snapshots. The initial shallow snapshot claim was wrong and has been removed. Original failure log is retained. No product source change or weakened assertion. A complete focused rerun is required.

Author summary estimated434patchlines, actual validated rawpatch545lines; both are below the650line ceiling. Raw gitapply--recount check/apply succeeded without normalization; actual ledger count governs.
