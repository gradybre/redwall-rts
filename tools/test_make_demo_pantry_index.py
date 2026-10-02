#!/usr/bin/env python3
"""Checks for tools/make_demo_pantry_index.py (decision 0602): the committed index is what the tool builds from the
library's pantry, the sixteen crops keep their LEAF entries, and the goods resolve to the targets the decision names."""
from __future__ import annotations

import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_demo_pantry_index as tool  # noqa: E402


class PantryIndexTest(unittest.TestCase):
    """The demo's pantry index."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.built = tool.build()
        cls.by_key = {item["item_key"]: item for item in cls.built["items"]}

    def test_the_committed_index_is_current(self) -> None:
        """The file in godot/demo/farm is exactly what the tool builds now (rebuild it when the library changes)."""
        committed = json.loads(tool.OUT.read_text(encoding="utf-8"))
        self.assertEqual(committed, self.built)

    def test_every_pantry_item_in_catalog_order(self) -> None:
        """26 items, the crops first by their LEAF, then the goods by key."""
        self.assertEqual([item["item_key"] for item in self.built["items"]], tool.ITEM_KEYS)
        for leaf, item in zip(tool.LEAVES, self.built["items"]):
            self.assertEqual(item["leaf_id"], leaf)
            self.assertEqual(item["targets"], [leaf])

    def test_the_goods_targets(self) -> None:
        """Salmon and carp have no pantry leaf; dried fish is the dried trout; flour only the demo grains' flours."""
        self.assertEqual(self.by_key["salmon"]["targets"], [])
        self.assertEqual(self.by_key["carp"]["dishes"], [])
        self.assertEqual(self.by_key["dace"]["targets"], ["LEAF_dace"])
        self.assertEqual(self.by_key["dried_fish"]["targets"], ["COMPONENT_shared_dried_trout"])
        self.assertIn("COMPONENT_shared_wheat_flour", self.by_key["flour"]["targets"])
        self.assertNotIn("COMPONENT_shared_rye_flour", self.by_key["flour"]["targets"])
        self.assertEqual(self.by_key["potato"]["targets"], ["LEAF_potato"])
        self.assertEqual(self.by_key["honey"]["targets"], ["LEAF_honey"])

    def test_uses_are_direct_or_through_a_component(self) -> None:
        """A dish naming the target is direct; one whose component contains it is through a component; else none."""
        components = {"C1": {"dependencies": [{"target_kind": "LEAF", "target_id": "L"}]}}
        direct = {"game_inputs": [{"target_kind": "LEAF", "target_id": "L"}]}
        via = {"game_inputs": [{"target_kind": "COMPONENT", "target_id": "C1"}]}
        none = {"game_inputs": [{"target_kind": "LEAF", "target_id": "M"}]}
        self.assertEqual(tool.uses(direct, {"L"}, components, {}), "direct")
        self.assertEqual(tool.uses(via, {"L"}, components, {}), "component")
        self.assertEqual(tool.uses(via, {"C1"}, components, {}), "direct")
        self.assertEqual(tool.uses(none, {"L"}, components, {}), "")


if __name__ == "__main__":
    unittest.main()
