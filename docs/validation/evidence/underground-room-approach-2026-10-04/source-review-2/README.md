# Corrected final Room facts — independent delta review

Base `7e199b7669a5bad5613aaf2881c9a801cc1dda51`. Current source manifest:
`f4b559f7046b0e8bc6807fbd5453bb29f7690e34ecdfdbe9f6d3f65c61410f2c`.
The ten source/UID/tool pins stay frozen during review.

The sole rejected finding was final observer dispatch. `underground_terrain.gd`
now adds a static prepared-local path that reads actual published World,
resource and Building columns and their Directory mirrors under the original
Space/cold lease. It has nine new static functions and no retained state.
Earlier observed APIs remain byte-identical. Approach removes its own final
World/endpoint/Room getter dispatch and uses that new Terrain path. RoomBindings
and Admission test source are unchanged from the original nine-pin packet.

The three `.gd.diff` files compare the correction against exact candidate13
bytes. `candidate13-locators.json` resolves all original owned sources plus
the unchanged-at-that-time Terrain to exact historical snapshots. It is a
historical locator, never an exemption for current-source validation.

`../candidate-14-rejected-final-readers/` ran the five new final-only callback
regressions on the old source: 23 tests / 271 assertions / 5 failures, all raw
and strict diagnostics/leaks zero. World and Room readers returned success
after the actual well mutation; the other three paths were later refused as
stale candidates after the side effect. The correction prevents each observer
call completely. Explicitly performing the same real mutation then produces
the actual foundation refusal.

`../candidate-15-static-final/` is the corrected clean run: Approach 27/784,
Admission 24/821, RoomBindings 17/604 and unchanged Terrain 28/1042, totaling
96 tests / 3,251 assertions / zero failures. Every strict/raw diagnostic and
leak count is zero; analyzer zero warnings/five files; ten Python census tests
pass. All source, HEAD, project, registry and assets restoration fields pass.
The extra four tests check real purpose/water/ford/tangency, resource lifecycle
and full identity, rotated footprint/site bounds, original revision/tokens and
local capacity against the existing observed readers.

Logical memory: unchanged Witness1,744 and inherited Face907 (separate2,048
allowance). Own numeric frames604 + new Terrain312 + inherited leaf72, plus
path-call512/expression512 =3,756/4,096. No new array/field or native reserve.
Whole composed cold peak remains938,368/1,048,960. The census rejects new
retained Terrain state, instance helper dispatch, virtual final observers and
numeric growth that exceeds this allowance. Native allocation is unmeasured.

Review by `/root/ug_geometry` accepted all ten exact pins; see `acceptance.md`. Source/geometry fixture, standalone
admission, first-entry/paid-phase/runtime/source-asset/Metal/playable boundaries
remain as stated in ADR1150. No engine rerun is requested from the reviewer.
