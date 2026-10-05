# Independent unchanged-v3 profile renewal review

The narrow create-only publication tool and its tests are accepted at the pins
below, with no high or medium finding. Root owns the new tool, Catalog renewal
and subsequent runtime integration. This reviewer wrote only this evidence
subtree and ran Python; no Godot, runtime source, shared metadata or foreign
output was changed.

| Reviewed input | SHA-256 |
| --- | --- |
| `renew_work_approach_profiles.py` | `9f6fbaa1ac04a0305c9758c4c4b6608d5cd91923829e73368cfde4b9ee699b32` |
| `test_renew_work_approach_profiles.py` | `1f5cad0ed8f6e80cb80215403548a03f41fddd9d5c0568b17c417c2b22ab03e2` |
| Reviewed consumer/native closure | `12085f7793f6520057a8fae21ae7460e43d437c58dd235aac29e04f14da708d1` |

## Scope and source boundaries

The tool validates all 509 prerequisites of immutable v3. Only the three
previously reviewed WorkFace/Routes/WorldRoutes historical files use explicit,
fixed-hash historical locators. They never replace current runtime files.
All nine current consumers are separately checked against both the approved
commit and the actual current files. The native report, original before/after
source hashes, invocation, exact-scalar verification and native binary are
bound to the immutable review record and revalidated before publication.

The original source geometry, wire, profile/content revisions, clock programme,
flags, mapping, actor and bounds remain unchanged. The constants diff contains
exactly five changed lines: generator comment, consumer commit and three
consumer hashes. The new manifest has only the nine explicitly listed
provenance/scope fields changed; every other old field compares exactly.

The current native evidence remains sampled source/clock compatibility with
its recorded physical-fixture limitations. This review does not rerun native
capture or grant World support, target, work, route or whole-room permission.

## Independent checks

All eight supplied tests passed in 1.295 seconds. They cover current and
historical source drift, each native proof input, original prerequisite drift,
wrong reviewed commit, output overwrite/escape and invalid input paths.

The additional independent replay:

- Verified all 523 renewed prerequisite hashes before and after the run.
- Exercised the real `publish` implementation with only its allowed output
  root relocated to a reviewer-owned temporary directory.
- Compared every output byte and every unchanged manifest field.
- Confirmed a second publish refuses before observing inputs and preserves
  the original output.
- Injected source drift after `inputs()` returned: the final read refused
  before an output directory was created.
- Proved a real oversized file and a real symlink refuse before reading bytes.

The archived independent outputs are:

| Output | Bytes | SHA-256 |
| --- | ---: | --- |
| Wire | 9,620 | `a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204` |
| Constants | 1,723 | `54bfe80c22bfe78ac2eb4fdf3259151beea64ce862753fdc05a399e933fe6bba` |
| Manifest | 107,340 | `ea685eafa41418ae52e097ea439764b9794111851d7389097770648bc706d70b` |

```sh
PYTHONDONTWRITEBYTECODE=1 \
  PYTHONPATH=/Users/brendan/Developer/redwall-rts-codex-ug-integration/tools \
  python3 -B -m unittest -v test_renew_work_approach_profiles
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  docs/validation/evidence/underground-room-integration-check-2026-10-05/renewal-review-1/independent_review.py
```

Exact input pins, tool snapshots, logs, constants diff, the complete prerequisite
map and rebuilt artifacts are retained here. The earlier `checkpoint-1`
composition failure remains unchanged; a coherent renewed runtime checkpoint
must pass separately.
