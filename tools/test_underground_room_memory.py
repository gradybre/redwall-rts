#!/usr/bin/env python3
"""Changes to current room owners or evidence must fail before historical replay."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
from contextlib import ExitStack
from unittest import mock

import audit_registry_capacities as audit
import underground_room_memory as room
import underground_current_census as census


class RoomMemoryWitnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = audit.load_source_index()
        cls.manifest = json.loads((room.ROOT / room.MANIFEST).read_bytes())
        cls.projected = set(json.loads((room.ROOT / room.PROJECTION).read_bytes())["inputs"])

    def refuses_current_change(self, name, changed, message):
        """ADR1212: an unprojected input still refuses here; a projected one is recounted by the current census."""
        path = self.manifest["sources"][name]["path"]
        if path not in self.projected:
            with mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, message):
                    room.build(dict(self.index, **{name: changed}))
                execute.assert_not_called()
            return
        archived = set()
        _, _, current = room.verified_inputs(dict(self.index, **{name: changed}), archived)
        self.assertIn(path, archived)
        self.assertEqual(hashlib.sha256(current[name].text.encode()).hexdigest(), self.manifest["sources"][name]["sha256"])
        index = dict(self.index, **{name: changed._replace(name=changed.name)})
        with self.assertRaisesRegex(ValueError, "unreviewed storage delta|module identity"):
            census.projected_deltas(index, sorted(self.projected), census.reviewed_table())

    def refuses_before_replay(self, changes):
        read = Path.read_bytes

        def changed(path):
            return changes[path] if path in changes else read(path)

        with mock.patch.object(Path, "read_bytes", changed), mock.patch.object(room, "producer") as execute:
            with self.assertRaises(ValueError):
                room.build(self.index)
            execute.assert_not_called()

    def test_transitive_constructor_census_is_checked_before_import(self):
        path = room.ROOT / room.C / "constructor_census.py"
        self.refuses_before_replay({path: b"raise RuntimeError('unreviewed producer')\n"})

    def test_transitive_turn_census_is_checked_before_import(self):
        path = room.ROOT / room.I / "predecessors/turn-census.py.txt"
        self.refuses_before_replay({path: path.read_bytes() + b"\nimport os\n"})

    def test_all_current_and_historical_producers_are_checked_before_execution(self):
        for folder in (room.P, room.I, room.C, room.G, room.R, room.S, room.T, room.A, room.Q):
            path = room.ROOT / folder / "census.py"
            with self.subTest(producer=folder):
                self.refuses_before_replay({path: path.read_bytes() + b"\n# unreviewed\n"})

    def test_coordinated_producer_and_manifest_change_has_no_new_authority(self):
        path = room.ROOT / room.C / "constructor_census.py"
        changed = path.read_bytes() + b"\n# coordinated change\n"
        rows = json.loads((room.ROOT / room.MANIFEST).read_bytes())
        rows["witnesses"][str(path.relative_to(room.ROOT))] = hashlib.sha256(changed).hexdigest()
        self.refuses_before_replay({path: changed, room.ROOT / room.MANIFEST: json.dumps(rows).encode()})

    def test_historical_sources_cannot_become_current_mutable_baselines(self):
        for name in ("underground_room_world_bindings", "underground_locations", "underground_session"):
            path = room.ROOT / self.manifest["baseline"][name]["locator"]
            with self.subTest(owner=name):
                self.refuses_before_replay({path: path.read_bytes() + b"\nvar extra: int = 1\n"})

    def test_current_owner_text_overrides_cannot_be_replaced_with_disk_or_cached_hash(self):
        names = ("underground_room_composition", "underground_room_itinerary",
                 "underground_room_frontier_publication", "underground_locations",
                 "underground_session", "underground_connector_catalog",
                 "underground_route_composition", "underground_world_retirement", "settlement_system")
        for name in names:
            row = self.manifest["sources"][name]
            old = self.index.get(name) or audit.parse_module(
                name, row["path"], (room.ROOT / row["path"]).read_text())
            changed = old._replace(text=old.text + "\nvar uncounted: PackedByteArray = PackedByteArray()\n")
            with self.subTest(owner=name):
                self.refuses_current_change(name, changed, "current reviewed source changed")

    def test_current_transitive_body_changes_are_not_hidden_by_frame_counts(self):
        name = "underground_work_face"
        old = self.index[name]
        changed = old._replace(text=old.text + "\nfunc same_size_callback() -> void:\n\tpass\n")
        with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
            room.build(dict(self.index, **{name: changed}))

    def test_actual_movement_reader_cannot_add_uncounted_scratch(self):
        old = self.index["movement"]
        start = old.text.index("func profile_speed_into(")
        body = old.text.index("\n", old.text.index("-> bool:", start)) + 1
        text = old.text[:body] + "\tvar uncounted: PackedByteArray = PackedByteArray()\n\tuncounted.resize(4096)\n" + old.text[body:]
        changed = audit.parse_module(old.name, old.relative_path, text)
        with self.assertRaisesRegex(ValueError, "current reviewed source changed: movement"):
            room.build(dict(self.index, movement=changed))

    def test_injected_module_path_must_identify_original_owner(self):
        name = "underground_locations"
        with self.assertRaisesRegex(ValueError, "module identity"):
            room.build(dict(self.index, **{name: self.index[name]._replace(relative_path="foreign.gd")}))

    def test_route_engine_lifetime_evidence_is_checked_before_any_producer(self):
        rows = json.loads((room.ROOT / room.R / "engine-lifetime/source-sha256.json").read_bytes())
        for relative in rows:
            path = room.ROOT / relative
            with self.subTest(engine_source=relative):
                self.refuses_before_replay({path: path.read_bytes() + b"\n// changed lifetime\n"})

    def test_route_constructor_dependency_cannot_hide_same_frame_size_mutation(self):
        name = "underground_level_catalog"
        old = self.index[name]
        changed = old._replace(text=old.text.replace("func binding_matches(", "func changed_binding_matches(", 1))
        self.assertNotEqual(old.text, changed.text)
        with mock.patch.object(room, "producer") as execute:
            with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
                room.build(dict(self.index, **{name: changed}))
            execute.assert_not_called()

    def test_route_predecessors_are_not_mutable_accounting_inputs(self):
        for name, row in self.manifest["route_predecessors"].items():
            path = room.ROOT / row["locator"]
            with self.subTest(owner=name):
                self.refuses_before_replay({path: path.read_bytes() + b"\nvar extra: int = 0\n"})

    def test_route_census_result_cannot_be_changed_to_create_headroom(self):
        path = room.ROOT / room.R / "source-review-1/census.json"
        changed = json.loads(path.read_bytes())
        changed["constructor_exclusive_reuse"]["simultaneous_total"] = 0
        self.refuses_before_replay({path: json.dumps(changed).encode()})

    def test_producer_assertions_survive_optimized_python(self):
        script = "import underground_room_memory as m; m.producer(m.P/'census.py', {str(m.P/'census.py'): b'assert False, \\\"mandatory census refusal\\\"'})"
        result = subprocess.run([sys.executable, "-O", "-c", script], cwd=room.ROOT / "tools",
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AssertionError: mandatory census refusal", result.stderr)

    def test_current_recount_requires_no_git_history_or_subprocess(self):
        with mock.patch.object(subprocess, "check_output", side_effect=AssertionError("no history")):
            result, historical = room.build(self.index)
        self.assertEqual(result["additional_global_reserved_bytes"], 0)
        self.assertEqual(result["publication"]["cold_controls_accounted"], 8050)
        self.assertEqual(result["composition"]["constructor_exclusive_reuse"]["simultaneous_total"], 7493)
        route = result["route_composition"]
        self.assertEqual(route["constructor_exclusive_reuse"]["simultaneous_total"], 8185)
        self.assertEqual(route["accounting"]["controls"], 6131)
        self.assertEqual(route["accounting"]["helpers"], 1919)
        # ADR1212: Session is projected; the route census replays its reviewed manifest-3 bytes.
        self.assertEqual(route["source_sha256"][self.index["underground_session"].relative_path],
                         self.manifest["sources"]["underground_session"]["sha256"])
        self.assertIn(self.index["underground_session"].relative_path, result["projected_reviewed_inputs"])
        self.assertEqual(result["composition"]["source_sha256"][self.index["underground_session"].relative_path],
                         self.manifest["route_predecessors"]["underground_session"]["sha256"])
        self.assertEqual(result["ground_catalog"]["fixed_peak_accounted"], 1468)
        self.assertNotEqual(historical["underground_session"].text, self.index["underground_session"].text)
        self.assertFalse(result["native_measured"])

    def test_both_programs_keep_exact_distinct_identity_and_text(self):
        for name, other in (("source_program", "short_program"), ("short_program", "source_program")):
            row, foreign = self.manifest["sources"][name], self.manifest["sources"][other]
            source = audit.parse_module(name, foreign["path"], (room.ROOT / foreign["path"]).read_text())
            with self.subTest(alias=name), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "module identity: " + name):
                    room.build(dict(self.index, **{name: source}))
                execute.assert_not_called()
            source = audit.parse_module(name, row["path"], (room.ROOT / foreign["path"]).read_text())
            with self.subTest(text=name):
                self.refuses_current_change(name, source, "current reviewed source changed: " + name)

    def test_new_current_text_changes_cannot_hide_behind_cached_hashes(self):
        for name in ("short_program", "mole_profile_driver", "mole_profile_catalog",
                     "underground_motion_catalog", "underground_motion_clock", "underground_profiles",
                     "underground_routes", "underground_world_routes", "underground_room_itinerary",
                     "underground_connector_contacts", "underground_surface_anchor"):
            row = self.manifest["sources"][name]
            source = audit.parse_module(name, row["path"], (room.ROOT / row["path"]).read_text())
            changed = source._replace(text=source.text + "\nstatic var retained: Array = [1, 2, 3]\n")
            with self.subTest(owner=name):
                self.refuses_current_change(name, changed, "current reviewed source changed: " + name)

    def test_metadata_projection_cannot_hide_current_constructor_or_body_edits(self):
        source = self.index["underground_route_composition"]
        # ADR1212: route composition is projected, so its constants and allocation sites are recounted by the
        # current census. A pure comparison edit (header[7] != N) is not storage and is not refused there.
        for before, after in (("GROUND_PACE_COUNT: int = 15", "GROUND_PACE_COUNT: int = 16"),
                              ("var o: Retirement.Owners", "var scratch: Array = [1, 2]\n\tvar o: Retirement.Owners")):
            self.assertIn(before, source.text)
            changed = source._replace(text=source.text.replace(before, after, 1))
            with self.subTest(change=before):
                self.refuses_current_change("underground_route_composition", changed,
                                            "current reviewed source changed: underground_route_composition")

    def test_transitive_short_step_contract_and_original_constructor_sources_are_immutable(self):
        paths = (room.S / "supporting/call-contract.json", room.S / "supporting/predecessors.json",
                 room.S / "profile-diagnostic-1/mole-worker.ugprof",
                 room.A / "constructor-source-sha256.json", room.A / "predecessor/manifest.json",
                 room.Q / "baseline.json", room.Q / "baseline/underground_route_composition.gd.txt",
                 room.E / "predecessors/underground_motion_memory.py.txt")
        for relative in paths:
            path = room.ROOT / relative
            with self.subTest(input=relative):
                self.refuses_before_replay({path: path.read_bytes() + b"\n# unreviewed\n"})

    def test_lower_historical_total_cannot_replace_current_constructor_report(self):
        path = room.ROOT / room.A / "source-review-3/census.json"
        data = json.loads(path.read_bytes())
        data["constructor_exclusive_reuse"]["simultaneous_total"] = 8161
        self.refuses_before_replay({path: json.dumps(data).encode()})

    def test_all_replays_use_captured_bytes_after_complete_verification(self):
        original = room.producer
        with ExitStack() as stack:
            started = False

            def replay(*args, **kwargs):
                nonlocal started
                if not started:
                    started = True
                    stack.enter_context(mock.patch.object(Path, "read_bytes", side_effect=AssertionError("late disk bytes")))
                    stack.enter_context(mock.patch.object(Path, "read_text", side_effect=AssertionError("late disk text")))
                return original(*args, **kwargs)

            stack.enter_context(mock.patch.object(room, "producer", side_effect=replay))
            result, _ = room.build(self.index)
        self.assertTrue(started)
        self.assertEqual(result["current_publication_metadata"]["joint"], 248632)

    def test_input_facade_does_not_fall_back_to_unverified_real_files(self):
        view = room.FrozenInputs({}, {})
        path = view.path(room.ROOT / "godot/scripts/core/underground_routes.gd")
        self.assertFalse(path.exists())
        with self.assertRaisesRegex(ValueError, "uncaptured census input"):
            path.read_text()
        with self.assertRaisesRegex(ValueError, "unreviewed census directory scan"):
            view.path(room.ROOT).glob("**/*")

    def test_current_runtime_helpers_and_original_reports_remain_separate(self):
        result, _ = room.build(self.index)
        self.assertEqual(result["current_source_runtime"]["profile_control"]["counted_logical"], 3571)
        self.assertEqual(result["current_source_runtime"]["paired_profiles"]["delta"], 1764)
        self.assertEqual(result["itinerary"]["itinerary"]["inclusive_peak"], 432)
        self.assertEqual(result["itinerary"]["provider_source_bound"], 509)
        self.assertEqual(result["itinerary"]["contacts_foreign_source_bound"], 344)
        self.assertEqual(result["historical_route_composition"]["constructor_exclusive_reuse"]["simultaneous_total"], 8161)
        self.assertEqual(result["route_composition"]["constructor_exclusive_reuse"]["simultaneous_total"], 8185)
        self.assertEqual(result["historical_motion"]["joint"]["total"], 237140)
        self.assertEqual(result["current_publication_metadata"]["joint"], 248632)

    def test_ui_successor_changes_only_reviewed_alias_and_dependency_closure(self):
        # The UI successor remains independently pinned inside the later entry
        # successor; its original exact-delta proof must not absorb that change.
        ui = json.loads((room.ROOT / self.manifest["entry_air_contact"]["previous_manifest"]["path"]).read_bytes())
        row = ui["ui_alias"]
        old = json.loads((room.ROOT / row["previous_manifest"]["path"]).read_bytes())
        sources = dict(old["sources"])
        sources["ui_manager"] = ui["sources"]["ui_manager"]
        sources["ui_notices"] = row["dependency"]
        self.assertEqual(ui["sources"], sources)
        witnesses = dict(old["witnesses"])
        witnesses.update({ui["sources"]["ui_manager"]["path"]:
                          ui["sources"]["ui_manager"]["sha256"],
                          row["previous_manifest"]["path"]: row["previous_manifest"]["sha256"],
                          row["original"]["locator"]: row["original"]["sha256"],
                          row["dependency"]["path"]: row["dependency"]["sha256"]})
        self.assertEqual(ui["witnesses"], witnesses)
        versions = dict(old["historical_versions"])
        versions[row["original"]["sha256"]] = row["original"]
        self.assertEqual(ui["historical_versions"], versions)
        for key in set(old) - {"checkpoint", "sources", "witnesses", "historical_versions"}:
            self.assertEqual(ui[key], old[key])

    def test_entry_successor_changes_only_reviewed_owner_and_evidence_closure(self):
        row = self.manifest["entry_air_contact"]
        old = json.loads((room.ROOT / row["previous_manifest"]["path"]).read_bytes())
        sources = dict(old["sources"])
        sources["underground_entry_world_bindings"] = self.manifest["sources"]["underground_entry_world_bindings"]
        self.assertEqual(self.manifest["sources"], sources)
        witnesses = dict(old["witnesses"])
        extra = [row["previous_manifest"]["path"], row["previous_locator"], row["receipt"], row["census"],
                 str(room.MANIFEST.parent / "independent-review-1/review.json"),
                 str(room.MANIFEST.parent / "independent-review-1/review.py")]
        witnesses.update({p: hashlib.sha256((room.ROOT / p).read_bytes()).hexdigest() for p in extra})
        self.assertEqual(self.manifest["witnesses"], witnesses)
        versions = dict(old["historical_versions"])
        versions[row["previous_sha256"]] = dict(path=row["source"], locator=row["previous_locator"], sha256=row["previous_sha256"])
        self.assertEqual(self.manifest["historical_versions"], versions)
        self.assertEqual(set(self.manifest) - set(old), {"entry_air_contact"})
        for key in set(old) - {"sources", "witnesses", "historical_versions"}:
            self.assertEqual(self.manifest[key], old[key])

    def test_entry_recount_preserves_old_packet_and_current_numeric_ceiling(self):
        result, historical = room.build(self.index)
        entry = result["current_entry_air_contact"]
        self.assertEqual(entry["fixed_bytes"], 202)
        self.assertEqual(entry["own_numeric_frames"]["bytes"], 224)
        self.assertEqual(entry["existing_helper_reservation"], 1024)
        self.assertEqual(entry["existing_total_reservation"], 2048)
        self.assertEqual(entry["additional_reserved_bytes"], 0)
        self.assertFalse(entry["native_measured"])
        self.assertEqual(hashlib.sha256(historical["underground_entry_world_bindings"].text.encode()).hexdigest(),
                         self.manifest["entry_air_contact"]["previous_sha256"])

    def test_entry_current_source_changes_refuse_before_producer(self):
        _, _, current = room.verified_inputs(self.index)
        source = current["underground_entry_world_bindings"]
        for text in (source.text + "\nvar hidden: int = 1\n", source.text.replace("_entry_box[4] >", "_entry_box[4] >=", 1)):
            with self.subTest(tail=text[-60:]), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "current reviewed source changed"):
                    room.build(dict(self.index, underground_entry_world_bindings=source._replace(text=text)))
                execute.assert_not_called()

    def test_entry_exact_predicate_cannot_admit_other_source_bytes(self):
        manifest, blobs, current = room.verified_inputs(self.index)
        source = current["underground_entry_world_bindings"]
        for text in (source.text + "\n# hidden\n", source.text.replace("_entry_box[4] >", "_entry_box[4] >=", 1),
                     source.text.replace("and _entry_box[4] > actual._location.point.y", "", 1)):
            changed = dict(current, underground_entry_world_bindings=source._replace(text=text))
            with self.subTest(tail=text[-60:]), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "entry air-contact"):
                    room.entry_air_contact_memory(changed, manifest, blobs, room.FrozenInputs(blobs, changed))
                execute.assert_not_called()

    def test_entry_receipt_census_and_original_cannot_drift_before_replay(self):
        row = self.manifest["entry_air_contact"]
        for relative in [row["previous_locator"], row["previous_manifest"]["path"], row["census"], row["receipt"]]:
            path = room.ROOT / relative
            with self.subTest(path=relative):
                self.refuses_before_replay({path: path.read_bytes() + b"\n# changed\n"})

    def test_current_ui_alias_keeps_original_accounting_bytes_separate(self):
        result, historical = room.build(self.index)
        alias = result["current_ui_alias"]
        row = self.manifest["ui_alias"]
        self.assertEqual(alias["historical_ui_manager_sha256"], row["original"]["sha256"])
        self.assertEqual(hashlib.sha256(historical["ui_manager"].text.encode()).hexdigest(),
                         row["original"]["sha256"])
        self.assertEqual(alias["source_sha256"][row["original"]["path"]],
                         self.manifest["sources"]["ui_manager"]["sha256"])
        self.assertEqual(alias["additional_reserved_bytes"], 0)
        self.assertEqual(result["route_composition"]["constructor_exclusive_reuse"]["simultaneous_total"], 8185)
        self.assertEqual(result["current_publication_metadata"]["joint"], 248632)

    def test_injected_ui_alias_text_cannot_use_the_current_disk_or_cached_hash(self):
        _, _, current = room.verified_inputs(self.index)
        source = current["ui_manager"]
        for suffix in ("\nvar extra: Array = [1, 2]\n", "\nfunc hidden_callback():\n\tpass\n"):
            changed = source._replace(text=source.text + suffix)
            with self.subTest(suffix=suffix), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "current reviewed source changed: ui_manager"):
                    room.build(dict(self.index, ui_manager=changed))
                execute.assert_not_called()

    def test_notice_dependency_value_or_body_changes_refuse_before_import(self):
        path = room.ROOT / self.manifest["ui_alias"]["dependency"]["path"]
        original = path.read_bytes()
        for changed in (original.replace(b'"CLOCK_OVERLOADED"', b'"DIFFERENT"', 1),
                        original + b"\nvar uncounted: Array = [1, 2]\n"):
            with self.subTest(changed=changed[-64:]):
                self.refuses_before_replay({path: changed})

    def test_alias_equivalence_refuses_any_other_ui_source_byte(self):
        manifest, blobs, current = room.verified_inputs(self.index)
        source = current["ui_manager"]
        for text in (source.text + "\n# another change\n",
                     source.text.replace("UiNotices.CLOCK_OVERLOAD_CODE", "UiNotices.other_code()", 1),
                     source.text + "\n" + 'const CLOCK_OVERLOAD_CODE: String = UiNotices.CLOCK_OVERLOAD_CODE\n'):
            with self.subTest(tail=text[-70:]), self.assertRaises(ValueError):
                room.ui_notice_alias(dict(current, ui_manager=source._replace(text=text)), manifest, blobs)

    def test_alias_literal_proof_refuses_changed_computed_or_duplicate_values(self):
        manifest, blobs, current = room.verified_inputs(self.index)
        source = current["ui_notices"]
        original = source.text.encode()
        for changed in (original.replace(b'"CLOCK_OVERLOADED"', b'"DIFFERENT"', 1),
                        original.replace(b'"CLOCK_OVERLOADED"', b'code_from_observer()', 1),
                        original + b'\nconst CLOCK_OVERLOAD_CODE: String = "CLOCK_OVERLOADED"\n'):
            with self.subTest(tail=changed[-80:]), self.assertRaisesRegex(ValueError, "alias literal changed"):
                room.ui_notice_alias(dict(current, ui_notices=source._replace(text=changed.decode())), manifest, blobs)

    def test_injected_notice_dependency_cannot_fall_back_to_current_disk(self):
        _, _, current = room.verified_inputs(self.index)
        source = current["ui_notices"]
        for text in (source.text.replace('"CLOCK_OVERLOADED"', '"WRONG"', 1),
                     source.text + "\nvar hidden: Array = [1, 2]\n"):
            changed = source._replace(text=text)
            with self.subTest(tail=text[-60:]), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "current reviewed source changed: ui_notices"):
                    room.build(dict(self.index, ui_notices=changed))
                execute.assert_not_called()

    def test_notice_dependency_retains_exact_module_name_and_path(self):
        _, _, current = room.verified_inputs(self.index)
        source = current["ui_notices"]
        for changed in (source._replace(name="foreign"), source._replace(relative_path="foreign.gd")):
            with self.subTest(module=changed.relative_path), mock.patch.object(room, "producer") as execute:
                with self.assertRaisesRegex(ValueError, "module identity: ui_notices"):
                    room.build(dict(self.index, ui_notices=changed))
                execute.assert_not_called()

    def test_old_ui_bytes_and_original_manifest_remain_immutable(self):
        row = self.manifest["ui_alias"]
        for relative in (row["original"]["locator"], row["previous_manifest"]["path"]):
            path = room.ROOT / relative
            with self.subTest(path=relative):
                self.refuses_before_replay({path: path.read_bytes() + b"\n# altered original\n"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
