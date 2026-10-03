# Failed integration checkpoint — 97a95b92

This clean-import, full no-argument run correctly failed one assertion. It is
retained as failure evidence, not a passing qualification. All other tests ran;
the obsolete explicit ReservationPurpose count was also the sole failed shard
assertion in PR230 run37089226723. The independent registry contract gate in
that CI run separately found missing RoomProjects canonical declarations.

The focused fixes live after this source revision. New full/CI evidence is
required before claiming a clean integrated checkpoint. The wrapper stops on
the test failure before its final raw-log summary; `result.json` distinguishes
that absent line from a separately computed raw diagnostic count.
