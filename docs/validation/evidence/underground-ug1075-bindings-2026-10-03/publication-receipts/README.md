# Exact companion publication receipts

SpaceOwner and Locations now expose `last_published_token()`. It records only
that exact actual owner's successful bank swap. Abort, staging, sealing and
refused publication do not change it. A successful same-schema restore clears
it; a refused restore preserves the previous receipt. The scalar is not saved,
hashed or added to a packed/wire schema. All four Space publication paths use
the common swap point, including actual Room and Furniture source transitions.

Routes requires the exact prepared Space and Locations tokens both before the
provider callback and immediately before graph publication. Future Locations
also requires the exact actual Space receipt, in addition to its existing real
Sites publication window, full identities, geometry and shared cold lease. A
matching numeric geometry revision or a reused unborn endpoint handle is not
sufficient. These receipts do not make separate owner swaps atomic or repair
the existing generic SpaceOwner caller assertion contract. Real coordinators
must still preflight the entire operation and publish in their exact paid
same-stack window.

Regression tests use actual core bank/Directory/Buildings/Router/Inventory
owners. World clearance/profile certificates remain explicitly synthetic.
They cover every Space publication path, abort/refusal/load lifecycle, candidate
A aborted followed by B at the same target revision, a future endpoint handle
reused by another candidate, and actual same-image restores during the route
callback. The full Sites + future endpoint + route paid composition remains a
separate production acceptance boundary; no synthetic fixture grants that claim.

The new Locations scalar costs 8 logical bytes inside the existing 2,112-byte
whole-topology fixed-control reservation, whose actual census becomes 2,068.
The combined 1,041,728-byte topology reservation does not grow. SpaceOwner's
additional 8 bytes are charged to the separate existing bindings/control reserve.
No new snapshot, packet, canonical field or per-row column is allocated.

The clean check moved assets aside, deleted only this worktree's `.godot`, ran
`godot --headless --path godot --editor --quit`, then the unchanged strict runner
for each affected singleton shard, and restored assets. Analyzer uses port 6153
and `--max 0`. Source hashes and raw logs are retained beside this file.

```
87 test(s), 5017 assertion(s), 0 failure(s)
30 test(s), 808 assertion(s), 0 failure(s)
40 test(s), 9175 assertion(s), 0 failure(s)
```

Every suite reports:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Total: 157 tests / 15,000 assertions / 0 failures. Analyzer:
`0 GDScript warning(s) in 0 of 6 file(s)`. Independent read-only review accepted all six exact source/test pins with no high/medium finding; no duplicate engine run was performed.
The earlier rejected test-only no-op revision assumption is retained separately.
