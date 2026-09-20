# Reservation column allocation phases

Source accounting only. These are packed backing bytes, excluding object/Array
headers, allocator overhead, unrelated owners and externally retained buffers.
No RSS, latency, minimum-spec or whole-world memory claim follows.

| Allocation | Formula | Compiled maximum |
|---|---:|---:|
| Eight canonical arrays | 37R | 1,212,416 B |
| Seven derived arrays | 20R + 4J + 4L | 753,664 B |
| Two merge buffers | 8R | 262,144 B |
| Heap membership bitmap | R | 32,768 B |

The live owner already holds canonical and derived arrays. A caller Columns
record contributes another canonical set. Each validation creates a private
derived record, then sorts occupied row indices twice. Sorting allocates an
order and scratch buffer; scratch dies on return, and the returned job order
is explicitly released after linking and before the lot sort begins. At most
two merge buffers are retained simultaneously. After linking, the lot order
leaves the validator's scope. Private derived arrays remain for comparison or
publication. Capture's heap bitmap is allocated afterward, not alongside both
merge buffers.

Capture compares source indexes before duplicating eight arrays into the caller
record. Its private derived record remains alive during those duplicates.
Previous caller buffers can survive when retained elsewhere; neither replacement
nor scope exit proves all external references were released.

Restore validates input while the old owner arrays and input coexist. It then
duplicates eight canonical arrays into the owner and transfers the private
seven derived arrays. The record input remains independent. Old owner buffers
can survive through external references. It never creates a second Inventory.

Adapter capture adds one local Columns record and, after successful owner capture,
one private OwnerRecord. OwnerRecord constructors allocate eight arrays that are
then replaced with private captured buffers. Adapter apply constructs a Columns
record and replaces its fields with borrowed block arrays before owner restore.
Those constructor allocations are real even though short lived. Three metadata
integers are additional to packed formulas; no canonical scalar is newly saved.

The full-capacity reverse-key test performs actual restore and capture at R32768,
J8192,L16384. It is correctness evidence for the bounded algorithm, not a runtime
performance acceptance or peak-memory measurement.

## Conservative packed-buffer envelopes

For one adapter call, count every explicitly named allocation even when phases
are disjoint. Capture: live owner57R+4J+4L, prior target37R, Columns constructor37R,
export duplicates37R, private derived20R+4J+4L, at most two merge buffers8R,
heap bitmapR, staged OwnerRecord constructor37R =234R+8J+8L, or7,864,320bytes
at compiled maxima. Apply: live owner57R+4J+4L, input block37R, view constructor37R,
private derived20R+4J+4L, merge8R, installed duplicates37R =196R+8J+8L,
or6,619,136bytes. These conservative envelopes include allocations that do not
coexist; they are NOT observed or exact peaks. They assume one existing source,
one target/input and no additional externally retained snapshots. Object/Array
headers and other runtime overhead are excluded. Arbitrarily retained prior
snapshots prevent a universal process bound.

The review's approximate160R+8J+8L figure mixes merge, bitmap and duplicate
publication phases and omits the adapter's later staged-block constructor. Use
the explicit source accounting above rather than treating that figure as a
measured peak. Optimize constructor bodies only in a separately specified
change; this packet intentionally retains the accepted record API.
