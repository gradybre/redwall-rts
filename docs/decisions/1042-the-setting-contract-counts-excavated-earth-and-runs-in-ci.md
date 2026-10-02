# 1042 — The setting contract counts excavated earth, and CI runs it

Date: 2026-10-02 · Status: Accepted

## Decision

`docs/validation/setting_contract.py` now expects **61** catalogue items, up
from 60. The other five counts stay the same: 24 recipes, 12 ancillary, 30
buildings, 9 furniture and 5 crops. The 61st item is `excavated_earth`, a
MATERIAL. It joined the `gameplay_balance.md` item table under SET-MOVE-ECON-001
ECON-002, adopted as NEW_AUTHOR_ADOPTED under DEC-040, in commit `52cc3fa8`
(EH-01, PR #91, 2026-09-12). A comment beside the assertion gives that reason.
The resolved-dependency count is still 183, because no recipe or building takes
excavated earth as an input.

`validation-results/setting-contract.json` was regenerated with the documented
command. Its only changes are the count and the five sources' SHA-256 hashes.

## CI runs it

The contracts job left the script out, because it is a report *generator* that
needs `--output`. Most of its value is in its assertions, though, and its output
path is free. So it now runs as the step **"Rules-v2 setting catalog
contract"** and writes its report to `$RUNNER_TEMP`. That does not dirty the tree.

Nothing ran the script automatically, so it failed silently from 2026-09-12 until
someone ran it by hand. That is the same failure mode the job's own comment
records for the memory ledger and the cycle validators.

The other `--output` generators named in that comment are `arithmetic.py` and
`winter.py` (both exit 0 today), plus `qualify.py` and `run_headless.py` (both
need a built engine run). They are left as they were. Whether CI should also run
`arithmetic.py` and `winter.py` the same way is a question for a later change,
not this one.
