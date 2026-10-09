# Loaded gait bounded loader correction — independent acceptance

The MEDIUM pre-materialization allocation finding retained in review-v1 is
closed at `prove_loaded_gait.py` SHA256
`4b3702a73c7792bdbfd259cae2fba80014a753c57e837a1b08973bf90ae1f1ef`
and `test_loaded_gait.py` SHA256
`5de8c192cb13997dfdb83320199d9eb804f75dba028cecbdbc77e52fb0555b54`.
All five executable pins matched before and after this review.

The reader bounds the immutable input read and ZIP directory before creating
member objects, requires exactly the two unique expected members, and checks
both bounded NPY headers, exact float32 C-order shapes, matching key counts and
expanded payload lengths before either NumPy view is created. Every
decompression read has an explicit finite length. The accepted stored and
compressed payloads retain identical scalar bytes; no geometry/proof algorithm
was changed by this correction.

Independently executed the eight focused loader tests: all passed, including
compressed overflow, enormous declared shape with short payload, invalid second
member before first-array materialization, duplicate/missing members, bad dtype,
order and payload lengths, directory capacity and exact valid decoding.
`invocation.json` and `loader-tests.log` record this run. The prior independent
15-test geometry review stands; the author's corrected full 23-test run and
retained rejected allocation witness were inspected without duplicating it.

No remaining high/medium finding in the reviewed source-only packet. Native
error, actual World support, root displacement, heading transitions, gameplay
rate, runtime storage and movement permission remain outside this acceptance.
No engine ran and no file in the author's checkout was modified.
