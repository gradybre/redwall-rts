# 1176 rejected first source review

Two MEDIUM findings were reported against the exact copied sources. First, `_live_session()` checked identity but not current source availability; fallible `level_catalog()` getters were then dereferenced inline. A changed original published seed left the same Session identity but made those getters return null. Floor/start/purpose refusal must preserve the prior draft.

Second, `_input_blocked()` returned the external modal observer result without checking its original view tuple afterward. A modal callback could select a different floor and return false after the world tool had already checked its old plane. The in-flight paint would then be accepted against a changed view.

The root retained these candidate bytes and corrected both findings. See `../room-mode-review-2/` for the separately pinned accepted delta and inspected 10/148 strict evidence. No engine rerun or foreign source writes occurred during either review.
