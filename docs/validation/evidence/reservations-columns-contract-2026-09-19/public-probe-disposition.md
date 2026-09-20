# Public-API and byte baselines

Both probes exited0 without script errors. public_overflow_probe uses only
public item registration, container/lot creation and claim_batch. Two different
items each reserve6e18milli for the same job. Both claims succeed and pool.audit
passes; job_reserved_total_milli returns-6446744073709551616 from unchecked i64
addition. This is a real runtime arithmetic defect, tracked separately. The
exact owner snapshot must not reject this admitted set by inventing a job-wide
sum bound; no such scalar is serialized. Per-lot sums remain valid6e18 each.

wire_probe records existing section7owner4schema1 single-block byte hashes for
small empty/sparse and full empty/occupied arrays. It composes the unchanged
literal wrapper and public codec columns, not a full six-owner section encode.
The full fixture has reverse semantic purpose order and positive quantities.
