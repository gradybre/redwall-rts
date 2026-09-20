# Parent fixture correction

First combinedfocus executed9tests/47336assertions with1failure. Parentfixture guessed raw absencecode NOT_PRESENT from shorthand contract language. The existing public constant REFUSE_NOT_PRESENT is actually RESIDENT_NOT_PRESENT, and the implementation correctly preserved it. Corrected only the test literal to that established exactcode; no productcode or behavior change and no softenedassertion. Original failing log retained.

In contract/ADR/author comments, NOT_PRESENT names the existing refusal path, not a new rawcode spelling. Repaired setter still checks presence before negativearrival; INVALID_ARRIVAL_TICK is the newly introduced distinct producer code.
