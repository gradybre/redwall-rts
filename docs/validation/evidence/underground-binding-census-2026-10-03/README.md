# Corrected connector binding census

Decision1110 and the four final pins in source-sha256.json define this packet.
The correction includes actual Placement108800 and ConnectorWork563 inside the
unchanged524288-byte bindings reserve. Source-derived controls are1670/2048;
known binding consumers487499, remaining36789. Whole logical pack remains
99959250 bytes, runtime_qualified=false.

Independent Geometry review found one medium checker omission: actual top-level
superclasses were not pinned. The corrected source now rejects changed Placement
or ConnectorWork bases as well as added nested/inherited/late fields. Reviewer
verified all four corrected pins and found no remaining high/medium issue in
this bounded accounting slice. Initial and corrected test logs are both retained.

```text
Ran 57 tests in 13.770s
OK
```

The generated memory pack was regenerated and passes --check. This is source
accounting, not a Godot run or measured native memory result. EntryFrontier,
Contacts and EntryBindings still need actual joint capacity admission; no reserve
or approved population/shape limit was increased.
