# Prepared connector START publication — 2026-10-04

Candidate1 ran on the owned `codex/underground-workpiece-publication` worktree,
based on accepted integration `a5a647b9`. The three changed GDScript files and
unchanged ConnectorWork dependency are pinned in
`candidate-1/source-sha256.json`. `invocation.json` records the exact commands
and confirms that source stayed unchanged and project/assets were restored.

The procedure removed this worktree's Godot cache, moved demo assets aside
when present (none were present), ran
`godot --headless --path godot --editor --quit`, and ran four selected suites
through the official runner's singleton shard support. No diagnostic or leak
allowance changed. The no-argument full suite remains an integrated milestone.

| Suite | Exact summary |
|---|---|
| Workpiece publication | `4 test(s), 48 assertion(s), 0 failure(s)` |
| Modular projects | `29 test(s), 2339 assertion(s), 0 failure(s)` |
| Connector work | `22 test(s), 258 assertion(s), 0 failure(s)` |
| Connector payment guard | `7 test(s), 142 assertion(s), 0 failure(s)` |

Total: **62 tests, 2787 assertions, zero failures**. Every suite ended with:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

```text
0 GDScript warning(s) in 0 of 3 file(s)
```

The run used the unchanged reviewed runner at
`docs/validation/evidence/underground-prepared-location-observation-2026-10-04/reproduce.py`
(SHA256 `051b1fdaaed6f760a61d3a81efa25a8a133ac53fa77b5b0596dd8bb33049a821`)
with its `FILES` set to the three changed files, port6198, these four `--suite`
arguments, and ConnectorWork as `--dependency`. The replay wrapper beside this
README expresses those exact inputs and requires a fresh output directory.

Independent review by `/root/ug_furnishing` matched all four pins and read the
full delta, the actual payment/Construction/Jobs tail, resume/default-discard
paths and all new tests. Accepted with no high/medium finding. It did not rerun
the engine. Review explicitly preserves the obligation for Decisions1134/1135
to publish only previously prepared facts through the concrete Router tuple;
the general virtual `is_publishing` observer is not a newly qualified pure tail.

No retained fields, packed columns or additional permission objects were added.
Existing Router member accounting is unchanged. Native call-frame/VM overhead
has not been measured by these tests; this does not claim zero native cost.

The new test uses actual Inventory, Reservations, Funding, Construction, Jobs,
Work and Gear, with an explicitly synthetic physical owner. It proves ordering,
original owner/candidate retention, no late purpose/bill observer, atomic final
refusal and retry, reentry/replay protection and unchanged ordinary purposes.
It does not prove physical workpiece publication, hauling, animation, default
renderer qualification or a playable first underground room.
