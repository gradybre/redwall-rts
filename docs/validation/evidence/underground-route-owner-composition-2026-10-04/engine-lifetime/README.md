# Exact engine lifetime used by the1167 constructor census

This is a logical source-lifetime argument for installed Godot4.7.2 commit
`ed1daf0bf001b61586d9930840f2f1394092c079`. It is not native allocation measurement.
Every complete downloaded engine file and the reused1143 compiler snapshots are
pinned in `source-sha256.json`; the census fixes the whole manifest before use.

`Levels.binding_matches` calls `Domain.descriptor`, retains its eight-entry
Dictionary plus six-I32 bounds, and calls `_identity_of`. That helper first
constructs a packed eleven-I32 array from a literal, appends the six bounds,
then appends four identity integers constructed from a second literal.

The initial eleven-element **untyped Array literal** does not coexist with the
later four-element literal. The exact analyzer's `reduce_array` starts with
untyped `Variant::ARRAY` (analyzer.cpp2714–2728). Built-in packed constructors
validate the input type without adding a typed Array element type
(analyzer.cpp3285–3430). In `GDScriptDataType::can_contain_object`
(function.h69–89), an untyped Array returns true. The compiler creates a temporary
for the literal (compiler.cpp501–530), pops call arguments after use, and calls
`clear_temporaries` after **each statement** (compiler.cpp2276).
`pop_temporary` records object-capable slots for clearing (byte_codegen.cpp135–147);
`clear_temporaries` emits that clear (1911–1921). Thus the first literal's contents
are released before the later statement. The provisional256-byte expression
allowance also conservatively covers an empty temporary header during clearing.

The **PackedInt32Array return temporary is different**: its type cannot contain
an Object. It may retain the initial44-byte payload after assignment, forcing
copy-on-write on the first append. The census does **not** depend on a later
pool-slot reuse releasing it: it charges the original44 bytes **and an additional
256-byte provisional packed header** alongside the final84-byte output, the
later16-byte packed argument, the four-element Array and descriptor. This is a
conservative2,344-byte heap coexistence; the earlier first-construction phase is
1,956 bytes. There is no assumption that packed clear or reassignment frees all
aliases. Native allocator/reallocation/header overhead remains expressly
unmeasured.

The exact constructor call chain plus the temporary13-reference Configuration
therefore costs4,159 bytes in the maximum Catalog→Levels case. The existing
private retirement Scope and copied Owners are absent during synchronous
construction, leaving4,002 bytes of the accepted controls; together8,161/8,192.
Removing one redundant local Owners reference from `_prepare_candidate` saves
32 counted stack bytes without changing ownership or permission. This is a
source/phase count within the existing reserve, not a capacity increase.
