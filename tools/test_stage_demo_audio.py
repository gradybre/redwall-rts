#!/usr/bin/env python3
"""Self-test for tools/stage_demo_audio.py (decision 0351, the demo's sound files). Runs without the audio
library and without afconvert: the sources are small WAV files written into a temporary folder, and the
committed ledger and sound table are checked against the tool's choices.

NEGATIVE TESTS COME FIRST:

  N01  a source missing from the library is skipped and reported; the other variants are staged.
  N02  a source whose SHA-256 differs from the ledger is skipped, never staged.
  N03  a source the ledger does not list is skipped.
  N04  a cut outside the file, or an empty one, refuses.
  N05  a WAV that is not 16-bit PCM refuses.
  N06  a loop seam that does not fit the file refuses.
  N07  a file that is skipped on a later run is removed, with its .import: the old one is never left to ship;
       a staged file no choice names any more is removed too.
  N08  only an Ogg is copied: anything else must be rendered.
  N09  rewriting the ledger refuses a recorded file whose SHA-256 changed, unless --rehash.

Then: a render cuts, fades and changes the level exactly, clipping at full scale; a seamed loop runs on from
its last frame into its first, blends with equal power, and carries a forward loop marker; a WAV round-trips;
the loudness of a known sine is what BS.1770 says, as Godot plays it (mono in both speakers), the gates drop
quiet blocks and the K-weighting cuts the deep bass; `measure` sets volume_db to target minus level, clamped; sound_table.json lists exactly the files the tool stages;
the committed ledger lists every chosen source, says which cue uses each file, and every pack is CC0.
"""

from __future__ import annotations

import array
import json
import math
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import stage_demo_audio as audio  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _raises(call, kind=RuntimeError) -> bool:
	"""Whether `call()` raises `kind`."""
	try:
		call()
	except kind:
		return True
	return False


def _tone(seconds: float, rate: int = 8000, channels: int = 2, amplitude: float = 0.5, hz: float = 1000.0) -> array.array:
	"""Interleaved int16 samples of a sine."""
	out = array.array("h")
	for f in range(int(seconds * rate)):
		value = int(round(amplitude * 32767 * math.sin(2 * math.pi * hz * f / rate)))
		out.extend([value] * channels)
	return out


def _library(folder: pathlib.Path, names: list[str]) -> tuple[pathlib.Path, pathlib.Path]:
	"""A stand-in library of short WAVs under audio/pack/, and a ledger listing them."""
	rows = []
	for name in names:
		path = folder / "library" / "audio" / "pack" / name
		audio.write_wav(path, 2, 8000, _tone(0.5))
		rows.append({"path": "pack/" + name, "sha256": audio.sha256_of(path)})
	ledger = folder / "files.json"
	ledger.write_text(json.dumps({"files": rows}))
	return folder / "library", ledger


def _with_choices(choices: dict, call):
	"""Run `call()` with CHOICES replaced, then put it back."""
	kept = audio.CHOICES
	audio.CHOICES = choices
	try:
		return call()
	finally:
		audio.CHOICES = kept


def test_n01_a_missing_source_is_skipped_and_the_rest_staged() -> None:
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.ogg"])
		out = pathlib.Path(folder) / "out"
		choices = {"knock": [("pack/a.ogg", None), ("pack/gone.ogg", None)]}
		result = _with_choices(choices, lambda: audio.stage(library, out, ledger))
		check("N01 the present one staged", result["staged"] == ["knock_01.ogg"])
		check("N01 the missing one skipped", [n for n, _ in result["skipped"]] == ["knock_02.ogg"])
		check("N01 and said why", "missing" in result["skipped"][0][1])
		check("N01 nothing written for it", not (out / "sound" / "knock_02.ogg").exists())


def test_n02_a_changed_source_is_never_staged() -> None:
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.ogg"])
		(library / "audio" / "pack" / "a.ogg").write_bytes(b"RIFF-changed")
		out = pathlib.Path(folder) / "out"
		result = _with_choices({"knock": [("pack/a.ogg", None)]}, lambda: audio.stage(library, out, ledger))
		check("N02 skipped", result["staged"] == [] and "SHA-256" in result["skipped"][0][1])
		check("N02 not written", not (out / "sound" / "knock_01.ogg").exists())


def test_n03_a_source_not_in_the_ledger_is_skipped() -> None:
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.wav"])
		audio.write_wav(library / "audio" / "pack" / "b.ogg", 2, 8000, _tone(0.1))
		out = pathlib.Path(folder) / "out"
		result = _with_choices({"knock": [("pack/b.ogg", None)]}, lambda: audio.stage(library, out, ledger))
		check("N03 skipped as unlisted", result["staged"] == [] and "not in the ledger" in result["skipped"][0][1])


def test_n04_a_cut_outside_the_file_refuses() -> None:
	tone = _tone(0.5)
	check("N04 past the end", _raises(lambda: audio.render(2, 8000, tone, audio._cut(0.1, 0.9))))
	check("N04 before the start", _raises(lambda: audio.render(2, 8000, tone, audio._cut(-0.1, 0.2))))
	check("N04 empty", _raises(lambda: audio.render(2, 8000, tone, audio._cut(0.3, 0.3))))
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.wav"])
		out = pathlib.Path(folder) / "out"
		result = _with_choices({"knock": [("pack/a.wav", audio._cut(0.1, 0.9))]}, lambda: audio.stage(library, out, ledger))
		check("N04 staging reports it, writes nothing", result["staged"] == [] and "outside" in result["skipped"][0][1]
			and not (out / "sound" / "knock_01.wav").exists())


def test_n05_a_wav_that_is_not_16_bit_refuses() -> None:
	with tempfile.TemporaryDirectory() as folder:
		path = pathlib.Path(folder) / "x.wav"
		audio.write_wav(path, 1, 8000, _tone(0.01, channels=1))
		data = bytearray(path.read_bytes())
		data[34:36] = (24).to_bytes(2, "little")  # bits per sample
		path.write_bytes(bytes(data))
		check("N05 24-bit refused", _raises(lambda: audio.read_wav(path)))
		path.write_bytes(b"not a wav at all")
		check("N05 not RIFF refused", _raises(lambda: audio.read_wav(path)))


def test_n06_a_seam_that_does_not_fit_refuses() -> None:
	tone = _tone(0.5)
	check("N06 half the file", _raises(lambda: audio.render(2, 8000, tone, audio._seam(250))))
	check("N06 zero", _raises(lambda: audio.render(2, 8000, tone, audio._seam(0))))


def test_n07_a_file_skipped_later_or_no_longer_chosen_is_removed() -> None:
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.ogg", "b.ogg", "c.wav"])
		out = pathlib.Path(folder) / "out"
		sound = out / "sound"
		choices = {"knock": [("pack/a.ogg", None), ("pack/b.ogg", None)]}
		check("N07 both staged", _with_choices(choices, lambda: audio.stage(library, out, ledger))["staged"] == ["knock_01.ogg", "knock_02.ogg"])
		(sound / "knock_01.ogg.import").write_text("[remap]")
		(library / "audio" / "pack" / "a.ogg").write_bytes(b"changed")
		result = _with_choices(choices, lambda: audio.stage(library, out, ledger))
		check("N07 the changed one skipped", [n for n, _ in result["skipped"]] == ["knock_01.ogg"])
		check("N07 and its earlier copy gone", not (sound / "knock_01.ogg").exists())
		check("N07 with its import", not (sound / "knock_01.ogg.import").exists())
		(sound / "old_cue_01.ogg").write_bytes(b"x")
		(sound / "old_cue_01.ogg.import").write_text("[remap]")
		result = _with_choices({"knock": [("pack/a.ogg", None), ("pack/c.wav", audio._gain(1.0))]},
			lambda: audio.stage(library, out, ledger))
		check("N07 an unchosen file and the copy a render replaced are removed",
			result["removed"] == ["knock_02.ogg", "old_cue_01.ogg", "old_cue_01.ogg.import"])
		check("N07 the render staged in its place", (sound / "knock_02.wav").is_file() and not (sound / "knock_02.ogg").exists())


def test_n08_only_an_ogg_is_copied() -> None:
	with tempfile.TemporaryDirectory() as folder:
		library, ledger = _library(pathlib.Path(folder), ["a.wav"])
		out = pathlib.Path(folder) / "out"
		result = _with_choices({"knock": [("pack/a.wav", None)]}, lambda: audio.stage(library, out, ledger))
		check("N08 a WAV is not copied under an .ogg name", result["staged"] == [] and "Ogg" in result["skipped"][0][1]
			and not (out / "sound" / "knock_01.ogg").exists())


def test_n09_the_ledger_refuses_a_changed_hash_without_rehash() -> None:
	old = {"files": [{"path": "p/a.ogg", "sha256": "1"}, {"path": "p/b.ogg", "sha256": "2"}]}
	new = {"files": [{"path": "p/a.ogg", "sha256": "1"}, {"path": "p/b.ogg", "sha256": "3"}, {"path": "p/c.ogg", "sha256": "4"}]}
	check("N09 the changed file is named, a new one is not", audio.changed_rows(old, new) == ["p/b.ogg"])
	check("N09 nothing changed", audio.changed_rows(old, old) == [])


def test_a_seamed_loop_runs_on_into_its_start_and_is_marked() -> None:
	rate, frames, overlap = 1000, 1000, 100
	ramp = array.array("h", [v for f in range(frames) for v in (f * 10, -f * 10)])  # a jump of 9990 at the join
	out = audio.render(2, rate, ramp, audio._seam(100))
	check("shortened by the seam", len(out) == 2 * (frames - overlap))
	check("starts where the old end-of-loop region began", out[0] == ramp[2 * (frames - overlap)] and out[1] == ramp[2 * (frames - overlap) + 1])
	check("ends where it did before the seam", out[-2] == ramp[2 * (frames - overlap - 1)])
	check("so the join is one ordinary step", abs(out[0] - out[-2]) == 10)
	check("after the seam the source runs on", out[2 * overlap] == ramp[2 * overlap])
	half = overlap // 2
	blend = ramp[2 * half] * math.sin(math.pi / 4) + ramp[2 * (frames - overlap + half)] * math.cos(math.pi / 4)
	check("mid-seam is the equal-power blend", out[2 * half] == int(round(blend)))
	step = abs(out[2 * overlap] - out[2 * (overlap - 1)])
	check("and the seam ends without a jump (%d)" % step, step < 200)
	with tempfile.TemporaryDirectory() as folder:
		looped, plain = pathlib.Path(folder) / "l.wav", pathlib.Path(folder) / "p.wav"
		audio.write_wav(looped, 2, rate, out, loop=True)
		audio.write_wav(plain, 2, rate, out)
		check("a forward loop marker over every frame", audio.wav_loop(looped) == (0, 0, frames - overlap))
		check("none on a one-shot", audio.wav_loop(plain) is None)
		check("the marker does not disturb the samples", audio.read_wav(looped) == (2, rate, out))


def test_render_cuts_fades_and_changes_the_level() -> None:
	rate, flat = 1000, array.array("h", [1000, -1000] * 1000)  # one second, stereo
	out = audio.render(2, rate, flat, audio._cut(0.2, 0.7, 10, 20, 6.0206))
	check("cut length", len(out) == 2 * 500)
	check("fade in starts at zero", out[0] == 0 and out[1] == 0)
	check("fade out ends at zero", out[-1] == 0 and out[-2] == 0)
	check("+6.02 dB doubles the middle", out[2 * 250] == 2000 and out[2 * 250 + 1] == -2000)
	loud = audio.render(2, rate, array.array("h", [30000, -30000] * 10), audio._gain(12.0))
	check("clipped at full scale", loud[0] == 32767 and loud[1] == -32768)
	check("a gain alone keeps every frame", len(loud) == 20)


def test_a_wav_round_trips() -> None:
	with tempfile.TemporaryDirectory() as folder:
		path = pathlib.Path(folder) / "t.wav"
		tone = _tone(0.05, channels=2)
		audio.write_wav(path, 2, 8000, tone)
		check("round trip", audio.read_wav(path) == (2, 8000, tone))


def test_loudness_of_a_known_sine() -> None:
	"""BS.1770: a 1 kHz sine at 0 dBFS in one channel reads -3.01 LUFS, so in both channels 0.00; at half
	amplitude, 6.02 dB less. Godot plays a mono file in both speakers, so mono reads as that stereo does."""
	stereo = audio.loudness(2, 48000, _tone(1.0, rate=48000, channels=2, amplitude=0.5))
	check("stereo integrated -6.02 LUFS (%.2f)" % stereo["integrated_lufs"], abs(stereo["integrated_lufs"] + 6.02) < 0.2)
	mono = audio.loudness(1, 48000, _tone(1.0, rate=48000, channels=1, amplitude=0.5))
	check("mono reads as played, in both speakers (%.2f)" % mono["integrated_lufs"], abs(mono["integrated_lufs"] - stereo["integrated_lufs"]) < 0.05)
	one_side = array.array("h", [v for sample in _tone(1.0, rate=48000, channels=1, amplitude=0.5) for v in (sample, 0)])
	check("one channel of two is 3.01 dB down", abs(audio.loudness(2, 48000, one_side)["integrated_lufs"] + 9.03) < 0.2)
	check("momentary max the same for a steady tone", abs(stereo["momentary_max_lufs"] - stereo["integrated_lufs"]) < 0.2)
	check("peak -6.0 dBFS", abs(stereo["peak_dbfs"] + 6.0) < 0.1)
	short = audio.loudness(2, 48000, _tone(0.1, rate=48000, channels=2, amplitude=0.5))
	check("a 100 ms tone counts as a 400 ms block: 6 dB lower", abs(short["momentary_max_lufs"] + 12.04) < 0.3)


def test_the_gates_and_the_k_weighting() -> None:
	"""The integrated level all but ignores silence (absolute gate) and a stretch 40 dB down (relative gate):
	only the three blocks that straddle the tone's end count, partly filled; the K-weighting's high pass takes
	20 Hz well down against 1 kHz."""
	loud = _tone(4.0, rate=8000, channels=2, amplitude=0.5)
	quiet = _tone(3.0, rate=8000, channels=2, amplitude=0.005)
	alone = audio.loudness(2, 8000, loud)["integrated_lufs"]
	padded = audio.loudness(2, 8000, loud + array.array("h", bytes(2 * 2 * 8000 * 3)))["integrated_lufs"]
	check("silence does not lower it (%.2f vs %.2f)" % (padded, alone), abs(padded - alone) < 0.3)
	with_quiet = audio.loudness(2, 8000, loud + quiet)["integrated_lufs"]
	check("a stretch 40 dB down does not either (%.2f)" % with_quiet, abs(with_quiet - alone) < 0.3)
	deep = audio.loudness(2, 8000, _tone(1.0, rate=8000, channels=2, amplitude=0.5, hz=20.0))["integrated_lufs"]
	check("20 Hz well under 1 kHz (%.1f vs %.1f)" % (deep, alone), deep < alone - 6.0)


def test_measure_sets_volume_to_target_minus_level_clamped() -> None:
	with tempfile.TemporaryDirectory() as folder:
		out = pathlib.Path(folder)
		audio.write_wav(out / "sound" / "loud_01.wav", 2, 8000, _tone(1.0, channels=2, amplitude=0.5))
		audio.write_wav(out / "sound" / "soft_01.wav", 2, 8000, _tone(1.0, channels=2, amplitude=0.001))
		(out / "sound" / "torn_01.wav").write_bytes(b"RIFF....WAVE")
		choices = {"loud": [("x", audio._gain(0.0))], "soft": [("x", audio._gain(0.0))], "torn": [("x", audio._gain(0.0))]}
		report = _with_choices(choices, lambda: audio.measure(out, {"loud": -20.0, "soft": -20.0, "torn": -20.0}, set()))
		check("loud: target minus level (%s)" % report["loud"]["volume_db"], report["loud"]["volume_db"] == float(round(-20.0 - report["loud"]["mean_lufs"])))
		check("by its loudest block", report["loud"]["by"] == "momentary_max_lufs")
		check("so -14 dB for a -6 LUFS tone", report["loud"]["volume_db"] == -14.0)
		check("soft: clamped at +6", report["soft"]["volume_db"] == 6.0)
		check("an unreadable file is listed, not fatal", report["unreadable"] and report["unreadable"][0].startswith("torn_01.wav"))
		check("and its cue left out", "torn" not in report)


def test_the_sound_table_lists_exactly_what_is_staged() -> None:
	table = json.loads(audio.TABLE.read_text())["cues"]
	check("same cues", set(table) == set(audio.CHOICES))
	for cue, files in audio.table_files().items():
		check("%s files" % cue, table.get(cue, {}).get("files") == files)
		check("%s has a target level" % cue, cue in audio.TARGET_LUFS)
		check("%s within the table's 8 files" % cue, len(files) <= 8)
	check("no extra targets", set(audio.TARGET_LUFS) == set(audio.CHOICES))


def test_the_committed_ledger_matches_the_choices() -> None:
	ledger = json.loads(audio.LEDGER.read_text())
	by_path = {row["path"]: row for row in ledger["files"]}
	check("every pack recorded", set(ledger["packs"]) == set(audio.PACKS))
	for key, pack in ledger["packs"].items():
		check("%s CC0" % key, "CC0" in pack["licence"] and pack["licence_url"] == audio.CC0)
		check("%s download hashed" % key, len(pack["download_file"]["sha256"]) == 64 and pack["download_file"]["bytes"] > 0)
		check("%s licence file listed" % key, "%s/%s" % (key, pack["licence_file"]) in by_path)
	for cue, rows in audio.CHOICES.items():
		for path, _ in rows:
			check("%s source %s in the ledger" % (cue, path), path in by_path)
	for path, row in by_path.items():
		if row["cues"] != audio.uses_of(path):
			check("ledger cues of %s match CHOICES" % path, False)
	check("count", ledger["count"] == len(ledger["files"]))


def main() -> int:
	"""Run every test and print the summary line."""
	for name, test in sorted(globals().items()):
		if name.startswith("test_") and callable(test):
			try:
				test()
			except Exception as error:  # noqa: BLE001 -- a crash is a failure, not a lost run
				check("%s raised %s: %s" % (name, type(error).__name__, error), False)
	for failure in FAILURES:
		print("FAIL %s" % failure)
	print("test_stage_demo_audio: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
