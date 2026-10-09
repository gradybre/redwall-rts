# Retained development evidence for1106 adapter

- `adapter-1`: clean import then rejected test parse (nested inherited test
  fixture could not resolve its base). No production test completion claimed.
- `adapter-2-dev`: corrected fixture,6 tests/64 assertions passed; development
  cache retained, not the final clean evidence.
- `adapter-3-dev`:11 tests/118 assertions, one rejected expectation. A genuine
  Construction pause clears its assigned-worker count; comparing the whole row
  before pause with after resume was invalid. The test now captures the exact
  post-resume row before contact refusal. Production pause behavior is unchanged.
  The large raw array failure logs are retained losslessly as `.log.gz`.
- `adapter-4`: clean14/172/all diagnostics and leaks0, analyzer0/2. Final source
  then added the pure quiescence reader and two meaningful callback/frame-boundary
  assertions; final-1 pins and reruns that exact candidate.
- `adapter-final-1`: clean94/6904 across five actual CI singleton shards, all
  strict/raw diagnostic/leak counts0; analyzer0/2 and source unchanged. This
  candidate was withheld before commit and is superseded by the correction below.
- `adapter-tail-rejected`: three new adversarial regressions reproduced late
  actual Inventory pause, a bill observer after WIP settlement, and a final
  PRODUCTIVE contact pause.17 tests/192 assertions/4 failures; raw assertion
  errors are retained, not accepted as strict success.
- `adapter-tail-1`: rejected parse mistake in the new static helper's refused
  OpResult construction (missing existing value/ref arguments). No runtime
  acceptance claimed; corrected without changing the contract.
- `adapter-tail-2`:21 tests/250 assertions, all functional cases passed but one
  census assertion incorrectly included9 numeric bytes owned only by the new
  adversarial subclass. The final test reflects the concrete production base
  instance; production retains no new fields.
- `adapter-tail-final-1`: clean102/6988 across the five actual CI shards,
  strict/raw diagnostics/leaks0, analyzer0/4, unchanged four source pins and
  restored own assets.22/258 are actual ConnectorWork tests.

Only adapter-tail-final-1 is current candidate evidence. Its exact source manifest and every
unmodified CI shard output remain in the repository. The initial failed raw
sources were not separately snapshotted; no exact-source claim is made for
those development iterations beyond each retained invocation manifest.
