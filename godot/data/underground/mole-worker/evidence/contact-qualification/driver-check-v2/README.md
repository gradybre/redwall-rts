# Finite presentation driver component

This uses actual Residents, Transforms, Inventory, Gear, Jobs, Work and Profiles
owners, with an explicitly synthetic eight-clip mesh and synthetic geometry
certificates. It verifies the driver protocol, not the mole source, clearance,
work productivity, route admission or a construction frontier.

The five tests cover paused integer phases, refused output preservation,
interrupted entry retracing, completing productive recovery before changing a
contact, actual tool claim and pose loss, stale profile content, positive travel
fades and explicit presentation retirement. The driver never changes a core
owner or releases an equipment claim. Its host must retain the actual selected
work/tool/pose observation through recovery, or retire the visible Actor before
relinquishing that observation. A `ready` frame grants no Work credit.

The earlier `driver-check-v1` is retained: its test suite failed to parse because
a constructed packed array was used as a constant. This run corrects only that
fixture declaration to a constant typed Array.

Own assets were moved outside the Godot project, the own `.godot` cache was
removed, and the editor import completed before the unchanged strict CI shard
runner. `commands.json` records the exact singleton selection. Raw logs and
source hashes are retained. Results:

```text
5 test(s), 102 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The component owns 360 packed bytes (two 12-I64 phase rows, 12-I64 pins, eight
I32 durations, three I32 pose values and seven I32 output values), plus one
retained Profiles.Selection (168 logical bytes), two full handles (16 bytes)
and one boolean. Caller Frame has 28 packed bytes plus 77 logical numeric bytes.
The independently reviewed corrected cold peak is400 logical bytes: this
driver's184-byte Descriptor coexists with `Content.profile_matches`'s184-byte
Descriptor and32-byte digest. Two IntResult values add18 logical bytes. The
eight-byte timing scratch is later and sequential; scalar stack locals remain
separate. The original192-byte estimate omitted the nested reader scratch.
Source,
Profiles and GPU assets are shared rather than copied. RefCounted, Array/String
headers and cold/native allocator peaks are unmeasured presentation costs.
No simulation arena is borrowed or whole-client memory qualification asserted.

Independent review found a WORK role swap permitted by this candidate; it is
retained as rejected binding evidence and corrected in the following run.
No other high/medium source finding was reported. Complete real source/state union, native
presentation and runtime composition remain required; production profiles = 0.
