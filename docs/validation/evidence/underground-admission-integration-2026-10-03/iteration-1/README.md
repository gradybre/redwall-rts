# Integrated admission and identity components

At integration commit `bd00cd20`, the clean CI import procedure was followed by
nine strict selected suites using the existing partitioned runner. Assets were
absent, the own `.godot` cache was removed, and the exact editor import ran first.
This is a focused integration check, not another full no-argument suite.

Combined: **266 tests, 36,807 assertions, 0 failures**. Each individual summary
is retained in its named log and partition manifest. Every suite reports:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 12 file(s)`.
All pinned sources stayed unchanged, and the original asset state was restored.

The checked suites cover actual room admission, room orders and masks, World/Room
mask composition, sparse Owner and phase Authority, finite Actor, physical paid
excavation, and the new fixed Buildings identity reader. Source reviews and
component test histories accompany their original commits. The root's later
World Room/worker identity composition was not yet integrated and is excluded.
Playability, actual productive contacts and the entire build remain unqualified.
