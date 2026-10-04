# 1134 — Delivered inputs and one static paid connector workpiece

Date: 2026-10-04. Status: implementation in progress; no production handling or playable-entry acceptance.

## Independently reviewed fixture prerequisite

The existing first-prefix test script loaded on its own but failed GDScript inheritance when the real Workpieces fixture extended it. Seven inline observer closures are replaced by named methods or `Callable.bind`, retaining every captured value, mutation order and assertion. The rejected inherited-load log is retained in `lifecycle-1`; the corrected original suite passes 33 tests / 10,790 assertions and its new actual Workpieces consumer passes 9 tests / 105 outer assertions in `lifecycle-2`. Every strict/raw diagnostic and leak count is zero; zero-warning analysis covers the corrected fixture and two new diagnostic modules. Root independently accepted only the fixture change at SHA256 `9bf978bcfc2a4b5b1d031849c4efd5813f576782ad8b8a14fd458268b3e13e8a`.

This prerequisite commit contains no Workpieces, ConnectorWork, Contacts or spatial production changes. The consumer ran with explicitly pinned, uncommitted diagnostic dependencies and synthetic handling profiles. Its passing START case is not acceptance of the complete1134 lifecycle, production hauling, source handling or playable entry.
