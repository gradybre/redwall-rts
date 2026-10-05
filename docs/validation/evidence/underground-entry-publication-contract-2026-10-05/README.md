# Fixed entry source interface

ADR1190 records the startup and fixed-source contract while real paid source
qualification continues. `entry_source_constants.py` is a pure formatter: it
checks the seven fixed input names, linked header revisions/digests and finite
counts, then emits typed scalar constants without I/O. It is not a physical
validator or a publisher. No runtime accessor exists at the reserved path.

`constants-2` is the accepted candidate: ten tests pass, and independent review
reproduces the same2,114-byte sample, with all18 inputs unchanged. The sample is
deliberately stored as`.gd.txt` and uses a synthetic Workpieces serialization
fixture alongside the actual archived diagnostic headers. It cannot activate
construction. The complete physical/source/native/paid-execution acceptance
remains a separate prerequisite for the publisher.

`constants-1` retains the initial successful nine-test format check. Local
source review then aligned profile caps exactly with the reader's3072 boxes
and64 sources and added a coherent INSTALL-as-handling substitution refusal.
The independent reviewer accepted only the final`constants-2` source pins.

The review folder was copied byte-identically from the reviewer's own worktree.
To replay its frozen checks from this checkout, use its current location:

```sh
python3 -B docs/validation/evidence/underground-entry-publication-contract-2026-10-05/independent-review-v1/review.py /Users/brendan/Developer/redwall-rts-codex-ug-integration /path/to/fresh-review-output
```
