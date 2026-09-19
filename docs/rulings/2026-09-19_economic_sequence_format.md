# SAVE-SEQ-R01 — represent exhausted economic allocation explicitly

2026-09-19 · Astra · Version 1 · Implementation follows SAVE-P2-R02.
This is a follow-up format contract, not an active schema change in the P2 repair.

Every ordinary pair of u32 economic sequence words is meaningful, including the
initial `(0,0)`. The existing terminal runtime state is `(4294967296,0)`, after
issuing `(4294967295,4294967295)`. Reusing zero as a sentinel would corrupt an
ordinary state. Preserve runtime allocation semantics and widen only its saved
HIGH allocator word; individual command sequence words remain u32 bit patterns.

## Versioned representation

Section12 schema becomes3. Prefix becomes28 bytes: existing u32 fields at offsets
0 schema(3),4 economic_count,8 payload_used,12 scheduler_extension_bytes,16 next_low
are unchanged; next_high at20 becomes u64 LE, occupying bytes20..27. Economic
records begin28, still64 bytes each. Payload follows those records; the unchanged
SCHQ0001 schema1 extension follows payload, still48+32*S bytes. Section length is
`76 + 64*E + P + 32*S`; empty76, maximum1318988. Update framing helpers and codecs
together. Scheduler allocation and scheduler wire/control words do not change.

Accept next_high in0..4294967295 with any u32 next_low, plus exactly
next_high4294967296 with next_low0. Refuse all other tuples before mutation/encoding.
The saved high is small enough for the codec's signed-int64 implementation domain;
no arbitrary u64 maximum needs a GDScript signed representation. Do not clamp or
wrap the terminal value. Existing runtime _advance_sequence behavior remains.
The owner restore introduced by SAVE-P2-R02 already admits this exact runtime pair.

The canonical commands owner advances schema1→2. Its existing ordinal2 field
_next_sequence_high changes type u32/code1→u64/code3; ordinal, source, scalar count
and hash inclusion are unchanged. Other fields remain byte-for-byte declared as
before. Section-schema vector index11 changes2→3. Registry version3→4; retain its
registry_id namespace, updating its version rather than inventing another registry.
Regenerate the compiled declaration table and capacity sidecar digest through their
existing tools; record count596, packed source count550 and capacity proof census
stay unchanged unless another integrated task legitimately changes them first.

This adds four serialized/canonical value bytes, not a new runtime field or packed
allocation: the existing GDScript allocator scalar already represents the terminal
value. Update the prose registry and current save matrix, schema arithmetic tests
and any current framing/spec references. Preserve historical dated schemas as
history, with this ruling explicitly superseding schema2 only for the new format.
No unrelated scalar, record field, scheduler extension or payload order changes.

## Compatibility and acceptance

The new section12 decoder explicitly refuses schema2 and unknown schemas before
mutating output, with the existing unsupported-version mechanism naming the actual
and supported version. No implicit migration or silent default is supplied. Preserve
old input files; incompatible load is a refusal, never a delete/rewrite. The future
full-file coordinator must check its section versions and compatibility hashes
before reusing arrays. Do not claim that unimplemented coordinator is complete.

Fixtures must distinguish initial zero, ordinary maximum-high tuples, the final
available pair and terminal exhaustion. Stage the final pair through public owner
APIs, issue the last actual ordinary command, capture/encode/decode/restore under
the held barrier, and prove the next ordinary submission refuses without wrapping,
losing already-pending work, changing arena bytes or consuming another sequence.
Repeat after draining to an empty queue, because pending records cannot stand in
for an exhaustion marker. Pin terminal high bytes `00 00 00 00 01 00 00 00` at20.

Round-trip high words 0x7fffffff and0x80000000 as positive u64 allocator values while
record sequence halves retain their existing signed-i32 storage bit representation.
Refuse high4294967297, terminal high with nonzero low, negative scalar values,
truncated widened prefix, old/unknown section versions and malformed extent without
changing caller output/owners. Canonical hash changes when ordinary/terminal allocator
state differs; the generated field declaration must name u64 width8 and owner schema2.
Repeat P2 offset/capacity and two-store recovery tests under the new format.

Implementation packet includes commands' codec-facing allocator validation if needed,
scheduler framing helpers, pending codec/tests, canonical JSON/generated declaration,
registry prose, current compatibility checks and deterministic fixtures. Obtain a
fresh independent persistence review, full Godot suite and static checks before merge.
The full save umbrella retains this prerequisite until that evidence passes.
