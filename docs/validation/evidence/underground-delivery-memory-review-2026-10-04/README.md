# Independent Delivery accounting review

Reviewer: `ug_construction`. Review target: root-owned seven-file accounting
diff against `fa017ba4aa8bd9620d397f5713dc6e577a4164d0` in the integration worktree.
`source-sha256.json` records the exact reviewed files. This review did not edit
that worktree or run Godot.

The current source arithmetic reconciles: Delivery's numeric, packed and nested
packets total 753 logical bytes, the new Work guard contributes one byte, and
the 1,024-byte helper and 2,048-byte provisional native allowances make 3,826
bytes within the new 4,096-byte contribution. The independently retained 216-byte
Transfer view belongs to ADR1141's Pool packet census and is not charged twice.
The empty protocol base, complete Planner member set and Work's two reference
bindings were checked. The current source allocates its fixed packets after the
explicit configure admission. No current uncharged bank was found.

The printed architecture trail, generated pack and arithmetic checker agree on
99,998,782 bytes live plus reserve and 1,218 bytes headroom. The new contribution
is outside the already assigned binding reserve. The capacity sidecar changes
only Work's source hash and proof line numbers; it does not silently expand
capacity. Runtime qualification remains false, and the rejected two-world peak
is still explicitly rejected.

## Finding R1 — medium: allocation census misses reachable extra allocations

`connector_delivery_reservation` checks the first textual `_allocate()` call and
only the known packet assignments and resizes. Two independent in-memory source
mutants passed the complete `build` unchanged:

- A new `_init()` below the existing configure method invokes `_allocate()`
  before configure has admitted the fixed packet. Its call appears after the
  first textual admitted call and escapes the position comparison.
- A local `PackedInt32Array(range(1000000))` inside `_allocate()` allocates an
  additional large image but escapes the member and resize census.

Both still report 3,826 declared bytes and the unchanged live total. See
`mutation-results-v1.json` for exact before/after substitutions. Freeze the sole
admitted allocation call and complete allocation/growth sites, and retain these
negative tests. This is a checker gap, not a finding against the frozen current
Delivery runtime source.

## Verification

All three read-only commands in `checks-v1.json` passed: exact memory artifact,
READY07 arithmetic and capacity sidecar. Their full output is retained in the
three logs. All seven reviewed pins remained unchanged afterward.

## Corrected verdict — accepted

The corrected seven pins are in `source-sha256-v2.json`; the checker is
`3064212be22374a4255c8da5ef773373a5d48408fff9c0a3810460ef2801d3e4`
and its tests are
`5a0203c03571bf4b76555389b5b2fbff3dc8e1e45933387da47617700e42c5de`.
The exact configure and allocator statement order, sole admitted call plus
declaration, complete constructor/copy/growth sites and collection-literal
refusals close R1. The reviewer independently reran both original mutants
through the full pack build; both now refuse. All nine new targeted tests and
the exact artifact check passed, with all seven pins unchanged. See
`correction-review.json` and both correction logs.

No high or medium finding remains for this accounting increment. The accepted
scope is source-derived logical accounting only; no native, runtime or playable
completion is implied.
