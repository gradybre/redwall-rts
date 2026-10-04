# Refused clean import at1eb7a64d

The exact prescribed clean-assets/cache/import procedure stopped before tests:
`WARNING: Detected another project.godot at res://data/underground/mole-worker/haul-handling-v1/native_capture. The folder will be ignored.`

The isolated source capture project needed its own .gdignore marker, as did its
archived copy. Source commitbb6c79bc adds exactly those two empty markers; it
changes no reviewed executable bytes. Direct isolated capture still emitted
522 vertices /768 triangles without diagnostics and the accepted output digest.
Root integrated that attempted fix atc24421ab and restarted a fresh clean full
qualification. That attempt also refused the same raw import warning: child
markers alone are too late in Godot's nested-project discovery. The subsequent
parent-subtree marker at9ca21351 passed clean import; its independent full
qualification is recorded separately. Neither earlier attempt proves success.
No test count, analyzer success or runtime milestone is claimed by this attempt.
The original project/assets/HEAD were restored and all tracked source pins stayed
unchanged. The raw log and invocation are preserved without filtering the warning.
