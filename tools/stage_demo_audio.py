#!/usr/bin/env python3
"""Stage the live demo's sound files from the audio library into godot/demo/assets/sound/. Decision 0351.

The approved CC0 packs live in the gitignored asset library, `assets/library/audio/<pack>/` (decision 0188's
layout); what is committed is their ledger, docs/art-reference/audio_library/ (README.md and files.json: every
file's pack, source, licence as stated, bytes, SHA-256 and the cue that uses it). This copies the chosen files
to the names godot/demo/sound/sound_table.json lists, in the gitignored staged folder the Windows build exports.
Without it the demo still runs, every cue silent.

  COPIED     an Ogg Vorbis file the pack gives ready to play, byte for byte (`<cue>_NN.ogg`).
  RENDERED   a file that needs a cut, a fade or a level change (`<cue>_NN.wav`, 16-bit PCM): the saw strokes
             cut from a loop, the tree's fall without the chop before it, quiet variants brought level with
             their siblings, and the wind loop, whose end did not meet its start (a click every 6 s), with
             its join cross-faded and a loop marker Godot's WAV import reads. Decoded with macOS `afconvert` (this Mac has no ffmpeg, and nothing here encodes
             Vorbis, so a rendered file is WAV). Without `afconvert` a rendered file is skipped and reported.

Every source is checked against the committed ledger's SHA-256 before it is used: a changed or missing
library file is skipped and reported, never staged.

    python3 tools/stage_demo_audio.py                   # stage (stage_demo_assets.py also calls this)
    python3 tools/stage_demo_audio.py --measure         # loudness of what is staged, per cue
    python3 tools/stage_demo_audio.py --ledger          # rewrite files.json from the library (after a download)

After staging, `godot --headless --path godot --import` imports the new files.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
LEDGER = ROOT / "docs/art-reference/audio_library/files.json"
TABLE = ROOT / "godot/demo/sound/sound_table.json"
RES_DIR = "res://demo/assets/sound"
DOWNLOADED = "2026-09-30"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"

## The nine packs Brendan approved on 2026-09-30 (decision 0351, phase 2): where each came from and the licence
## as its page stated it on the day. `download` is the page's own file link.
PACKS: dict[str, dict] = {
	"kenney_impact_sounds": {"title": "Impact Sounds", "author": "Kenney (kenney.nl)",
		"page": "https://kenney.nl/assets/impact-sounds",
		"download": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
		"licence": "Creative Commons CC0", "licence_file": "License.txt"},
	"kenney_rpg_audio": {"title": "RPG Audio", "author": "Kenney (kenney.nl)",
		"page": "https://kenney.nl/assets/rpg-audio",
		"download": "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
		"licence": "Creative Commons CC0", "licence_file": "License.txt"},
	"kenney_interface_sounds": {"title": "Interface Sounds", "author": "Kenney (kenney.nl)",
		"page": "https://kenney.nl/assets/interface-sounds",
		"download": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
		"licence": "Creative Commons CC0", "licence_file": "License.txt"},
	"oga_30_cc0_sfx_loops": {"title": "30 CC0 SFX loops", "author": "rubberduck (OpenGameArt)",
		"page": "https://opengameart.org/content/30-cc0-sfx-loops",
		"download": "https://opengameart.org/sites/default/files/sfx_loops.zip",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
	"oga_rain_loopable": {"title": "Rain (loopable)", "author": "OpenGameArt submitter (see page)",
		"page": "https://opengameart.org/content/rain-loopable",
		"download": "https://opengameart.org/sites/default/files/Rain%20OGG.zip",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
	"oga_tree_chop_fall_thud": {"title": "tree chop fall thud", "author": "OpenGameArt submitter (see page)",
		"page": "https://opengameart.org/content/tree-chop-fall-thud",
		"download": "https://opengameart.org/sites/default/files/chop-tree-fall.ogg",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
	"oga_water_splash_slime_sfx": {"title": "40 CC0 water / splash / slime SFX", "author": "rubberduck (OpenGameArt)",
		"page": "https://opengameart.org/content/40-cc0-water-splash-slime-sfx",
		"download": "https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
	"oga_wind_whoosh_loop": {"title": "wind whoosh loop", "author": "OpenGameArt submitter (see page)",
		"page": "https://opengameart.org/content/wind-whoosh-loop",
		"download": "https://opengameart.org/sites/default/files/wind%20woosh%20loop.ogg",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
	"oga_shovel_sound": {"title": "Shovel Sound", "author": "OpenGameArt submitter (see page)",
		"page": "https://opengameart.org/content/shovel-sound",
		"download": "https://opengameart.org/sites/default/files/shovel_0.ogg",
		"licence": "CC0", "licence_file": "LICENCE_AS_STATED.txt"},
}

_I = "kenney_impact_sounds/Audio/"
_R = "kenney_rpg_audio/Audio/"
_U = "kenney_interface_sounds/Audio/"
_W = "oga_water_splash_slime_sfx/"


def _cut(start: float, end: float, fade_in: int = 15, fade_out: int = 40, gain: float = 0.0) -> dict:
	"""A render: keep [start, end) seconds, fade in and out (ms), and change the level (dB)."""
	return {"start_s": start, "end_s": end, "fade_in_ms": fade_in, "fade_out_ms": fade_out, "gain_db": gain}


def _seam(seam_ms: int) -> dict:
	"""A render for a loop whose end does not meet its start: cross-fade the join (see `seam`); written with a
	loop marker."""
	return {"seam_ms": seam_ms}


def _gain(gain: float) -> dict:
	"""A render that only changes the level (dB): a quiet variant brought level with its siblings."""
	return {"gain_db": gain}


## Per cue, its variants in play order: (library path under assets/library/audio/, render or None). A None is
## copied as it is (.ogg); a render is written as .wav. Measured and chosen 2026-09-30 (decision 0351, phase 2;
## the per-file loudness is in docs/art-reference/audio_library/README.md).
CHOICES: dict[str, list[tuple[str, dict | None]]] = {
	"chop": [(_R + "chop.ogg", _gain(-10.0)), (_I + "impactWood_heavy_000.ogg", None),
		(_I + "impactWood_heavy_001.ogg", None), (_I + "impactWood_heavy_002.ogg", None),
		(_I + "impactWood_heavy_003.ogg", None)],
	"gnaw": [(_I + "impactWood_light_%03d.ogg" % k, _gain(4.0)) for k in range(5)],
	"saw": [("oga_30_cc0_sfx_loops/saw.ogg", _cut(0.20, 0.68)), ("oga_30_cc0_sfx_loops/saw.ogg", _cut(0.90, 1.36, gain=2.0)),
		("oga_30_cc0_sfx_loops/saw.ogg", _cut(1.58, 2.08, gain=-2.0))],
	"dig": [("oga_shovel_sound/download/shovel_0.ogg", _cut(0.00, 0.40, 0, 60, -6.0)),
		("oga_shovel_sound/download/shovel_0.ogg", _cut(0.50, 0.78, 15, 60, 13.0)),
		(_I + "impactMining_004.ogg", _gain(-2.5))],
	"tree_fall": [("oga_tree_chop_fall_thud/download/chop-tree-fall.ogg", _cut(0.96, 2.40, 20, 60))],
	"pickup": [(_R + "handleSmallLeather.ogg", None), (_R + "handleSmallLeather2.ogg", None), (_R + "cloth4.ogg", None)],
	"drop": [(_I + "impactPlank_medium_001.ogg", None), (_I + "impactPlank_medium_002.ogg", None),
		(_I + "impactPlank_medium_003.ogg", None), (_R + "dropLeather.ogg", None)],
	"step_grass": [(_I + "footstep_grass_%03d.ogg" % k, None) for k in (0, 1, 2, 4)],
	"step_dirt": [(_R + "footstep%02d.ogg" % k, None) for k in (0, 1, 3, 8)],
	"step_wood": [(_I + "footstep_wood_000.ogg", _gain(12.5)), (_I + "footstep_wood_001.ogg", _gain(7.4)),
		(_I + "footstep_wood_002.ogg", _gain(5.4)), (_I + "footstep_wood_003.ogg", _gain(14.4))],
	"step_tunnel": [(_R + "footstep%02d.ogg" % k, None) for k in (2, 6, 7, 9)],
	"step_wade": [(_W + "splash_10.ogg", None), (_W + "splash_14.ogg", None), (_W + "splash_15.ogg", None)],
	"splash": [(_W + "splash_04.ogg", None), (_W + "splash_07.ogg", None), (_W + "splash_08.ogg", None)],
	"water_in": [(_W + "splash_02.ogg", None), (_W + "splash_13.ogg", None)],
	"water_out": [(_W + "splash_12.ogg", None), (_W + "splash_05.ogg", None)],
	"amb_stream": [("oga_30_cc0_sfx_loops/water_flowing.ogg", None)],
	"amb_wind": [("oga_wind_whoosh_loop/download/wind woosh loop.ogg", _seam(500))],
	"amb_rain": [("oga_rain_loopable/4.ogg", None)],
	"warning": [(_U + "error_004.ogg", None)],
	"complete": [(_U + "confirmation_001.ogg", None)],
	"ui_click": [(_U + "tick_002.ogg", None)],
}

## The level each cue is set to sit at before its bus (LUFS: a one-shot's loudest 400 ms, a loop's integrated
## loudness): the event that matters most loudest, the ambience a bed under the work. `--measure` prints the
## volume_db that puts the staged files there; sound_table.json carries it, clamped to the table's -60..+6.
TARGET_LUFS: dict[str, float] = {
	"tree_fall": -16.0, "chop": -20.0, "dig": -22.0, "saw": -23.0, "gnaw": -24.0, "drop": -24.0, "pickup": -28.0,
	"step_grass": -30.0, "step_dirt": -30.0, "step_tunnel": -31.0, "step_wood": -28.0, "step_wade": -27.0,
	"splash": -20.0, "water_in": -24.0, "water_out": -26.0, "amb_stream": -26.0, "amb_wind": -30.0,
	"amb_rain": -27.0, "warning": -18.0, "complete": -20.0, "ui_click": -28.0,
}


def target_name(cue: str, index: int, render: dict | None) -> str:
	"""The staged file name of a cue's variant `index` (0-based): `<cue>_NN.ogg`, or `.wav` when rendered."""
	return "%s_%02d.%s" % (cue, index + 1, "ogg" if render is None else "wav")


def table_files() -> dict[str, list[str]]:
	"""The res:// paths sound_table.json must list for each cue, from CHOICES."""
	return {cue: ["%s/%s" % (RES_DIR, target_name(cue, i, r)) for i, (_, r) in enumerate(rows)]
		for cue, rows in CHOICES.items()}


def sha256_of(path: pathlib.Path) -> str:
	"""A file's SHA-256 (hex)."""
	return hashlib.sha256(path.read_bytes()).hexdigest()


def ledger_hashes(ledger: pathlib.Path) -> dict[str, str]:
	"""Every library file's committed SHA-256, by its path under assets/library/audio/."""
	data = json.loads(ledger.read_text())
	return {row["path"]: row["sha256"] for row in data["files"]}


# --- WAV I/O and rendering -------------------------------------------------------------------------------

def read_wav(path: pathlib.Path) -> tuple[int, int, array.array]:
	"""(channels, rate, interleaved int16 samples) of a 16-bit PCM WAV, plain or WAVE_FORMAT_EXTENSIBLE."""
	data, i, channels, rate, bits, pcm = path.read_bytes(), 12, 0, 0, 0, b""
	if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
		raise RuntimeError("%s is not a WAV file" % path)
	while i + 8 <= len(data):
		chunk, size = data[i:i + 4], struct.unpack("<I", data[i + 4:i + 8])[0]
		if chunk == b"fmt ":
			_, channels, rate, _, _, bits = struct.unpack("<HHIIHH", data[i + 8:i + 24])
		elif chunk == b"data":
			pcm = data[i + 8:i + 8 + size]
		i += 8 + size + (size & 1)
	if bits != 16 or channels < 1:
		raise RuntimeError("%s is not 16-bit PCM" % path)
	samples = array.array("h")
	samples.frombytes(pcm[:len(pcm) - len(pcm) % (2 * channels)])
	if sys.byteorder != "little":
		samples.byteswap()
	return channels, rate, samples


def write_wav(path: pathlib.Path, channels: int, rate: int, samples: array.array, loop: bool = False) -> None:
	"""Write interleaved int16 `samples` as a 16-bit PCM WAV. `loop` adds a `smpl` chunk with one forward loop
	over the whole file, which Godot's WAV import (edit/loop_mode "Detect From WAV", the default) plays as a loop.
	The end is written as the frame count: Godot reads it as exclusive, so every frame plays."""
	body = array.array("h", samples)
	if sys.byteorder != "little":
		body.byteswap()
	pcm = body.tobytes()
	frames = len(samples) // channels
	smpl = struct.pack("<4sI9I6I", b"smpl", 60, 0, 0, 1000000000 // rate, 60, 0, 0, 0, 1, 0,
		0, 0, 0, frames, 0, 0) if loop else b""
	header = struct.pack("<4sI4s4sIHHIIHH", b"RIFF", 36 + len(pcm) + len(smpl), b"WAVE", b"fmt ", 16, 1, channels,
		rate, rate * channels * 2, channels * 2, 16)
	_write_atomic(path, header + smpl + struct.pack("<4sI", b"data", len(pcm)) + pcm)


def _write_atomic(path: pathlib.Path, data: bytes) -> None:
	"""Write `data` to `path` through a temporary file beside it, so an interrupted run leaves no torn file."""
	path.parent.mkdir(parents=True, exist_ok=True)
	partial = path.with_name(path.name + ".partial")
	partial.write_bytes(data)
	os.replace(partial, path)


def wav_loop(path: pathlib.Path) -> tuple[int, int, int] | None:
	"""The first loop of a WAV's `smpl` chunk as (type: 0 forward, start frame, end frame), or None."""
	data, i = path.read_bytes(), 12
	while i + 8 <= len(data):
		chunk, size = data[i:i + 4], struct.unpack("<I", data[i + 4:i + 8])[0]
		if chunk == b"smpl" and size >= 60 and struct.unpack("<I", data[i + 36:i + 40])[0] > 0:
			return struct.unpack("<III", data[i + 48:i + 60])
		i += 8 + size + (size & 1)
	return None


def decode(source: pathlib.Path, scratch: pathlib.Path) -> tuple[int, int, array.array]:
	"""A source's samples: a WAV read directly, anything else decoded by macOS `afconvert` (RuntimeError
	without it)."""
	if source.suffix.lower() == ".wav":
		return read_wav(source)
	if shutil.which("afconvert") is None:
		raise RuntimeError("afconvert (macOS) is needed to decode %s" % source.name)
	out = scratch / (hashlib.sha1(str(source).encode()).hexdigest()[:16] + ".wav")
	subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(source), str(out)], check=True,
		stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	return read_wav(out)


def render(channels: int, rate: int, samples: array.array, spec: dict) -> array.array:
	"""Cut, fade and change the level of interleaved int16 `samples` as `spec` says (see `_cut`), clipping
	at full scale -- or, for a `_seam` spec, fold the loop's end into its start. Raises RuntimeError on a cut
	outside the file or an empty one."""
	if "seam_ms" in spec:
		return seam(channels, rate, samples, spec["seam_ms"])
	frames = len(samples) // channels
	first = int(round(spec.get("start_s", 0.0) * rate))
	last = frames if "end_s" not in spec else int(round(spec["end_s"] * rate))
	if first < 0 or last > frames or last <= first:
		raise RuntimeError("cut %.3f..%.3f s is outside the %.3f s file" % (first / rate, last / rate, frames / rate))
	gain = 10.0 ** (spec.get("gain_db", 0.0) / 20.0)
	fade_in = int(rate * spec.get("fade_in_ms", 0) / 1000)
	fade_out = int(rate * spec.get("fade_out_ms", 0) / 1000)
	count = last - first
	out = array.array("h", bytes(2 * count * channels))
	for f in range(count):
		level = gain * _ramp(f, count, fade_in, fade_out)
		for c in range(channels):
			value = int(round(samples[(first + f) * channels + c] * level))
			out[f * channels + c] = max(-32768, min(32767, value))
	return out


def seam(channels: int, rate: int, samples: array.array, seam_ms: int) -> array.array:
	"""A loop without a click at its join: the last `seam_ms` are cross-faded (equal power) into the first, and
	dropped from the end, so the new last frame runs on into the new first exactly as the source did. Raises
	RuntimeError when the seam is not shorter than half the file."""
	frames = len(samples) // channels
	overlap = int(rate * seam_ms / 1000)
	if overlap <= 0 or 2 * overlap >= frames:
		raise RuntimeError("a %d ms seam does not fit a %.3f s file" % (seam_ms, frames / rate))
	out = array.array("h", samples[:(frames - overlap) * channels])
	for f in range(overlap):
		rise = math.sin(0.5 * math.pi * f / overlap)
		fall = math.cos(0.5 * math.pi * f / overlap)
		for c in range(channels):
			value = samples[f * channels + c] * rise + samples[(frames - overlap + f) * channels + c] * fall
			out[f * channels + c] = max(-32768, min(32767, int(round(value))))
	return out


def _ramp(frame: int, count: int, fade_in: int, fade_out: int) -> float:
	"""The fade multiplier (0..1) of frame `frame` of `count`: linear up over `fade_in`, down over `fade_out`."""
	level = 1.0
	if fade_in > 0 and frame < fade_in:
		level = frame / fade_in
	if fade_out > 0 and frame >= count - fade_out:
		level = min(level, (count - 1 - frame) / fade_out)
	return level


# --- staging -----------------------------------------------------------------------------------------------

def stage(library: pathlib.Path, out: pathlib.Path, ledger: pathlib.Path = LEDGER) -> dict:
	"""Stage every chosen variant into `out`/sound/. Returns {"staged": [...], "skipped": [(target, why)],
	"removed": [...]}: a source missing, changed since the ledger, or not decodable is skipped, and any earlier
	copy of it removed (its cue plays without it); a staged file no choice names any more is removed too."""
	hashes = ledger_hashes(ledger) if ledger.is_file() else {}
	folder = out / "sound"
	folder.mkdir(parents=True, exist_ok=True)
	result: dict = {"staged": [], "skipped": [], "removed": _remove_unchosen(folder)}
	with tempfile.TemporaryDirectory() as scratch:
		for cue, rows in CHOICES.items():
			for index, (relative, spec) in enumerate(rows):
				target = folder / target_name(cue, index, spec)
				why = _stage_one(library / "audio" / relative, relative, spec, target, hashes, pathlib.Path(scratch))
				if why:
					_remove(target)
					result["skipped"].append((target.name, why))
				else:
					result["staged"].append(target.name)
	return result


def _remove_unchosen(folder: pathlib.Path) -> list[str]:
	"""Remove every staged sound (and its .import) that no choice names any more; their names."""
	chosen = {target_name(cue, i, spec) for cue, rows in CHOICES.items() for i, (_, spec) in enumerate(rows)}
	gone = []
	for path in sorted(folder.iterdir()):
		name = path.name[:-len(".import")] if path.name.endswith(".import") else path.name
		if path.is_file() and name not in chosen:
			path.unlink()
			gone.append(path.name)
	return gone


def _remove(target: pathlib.Path) -> None:
	"""Remove a staged file and its .import (an import left behind would still load the old sound)."""
	target.unlink(missing_ok=True)
	target.with_name(target.name + ".import").unlink(missing_ok=True)


def _stage_one(source: pathlib.Path, relative: str, spec: dict | None, target: pathlib.Path, hashes: dict,
		scratch: pathlib.Path) -> str:
	"""Copy or render one variant; "" when staged, else why it was not."""
	if not source.is_file():
		return "missing from the library: %s" % relative
	if relative not in hashes:
		return "not in the ledger (a new download is recorded with --ledger): %s" % relative
	if sha256_of(source) != hashes[relative]:
		return "changed since the ledger (SHA-256 differs): %s" % relative
	if spec is None and source.suffix.lower() != ".ogg":
		return "only an Ogg Vorbis file is copied (anything else is rendered): %s" % relative
	try:
		if spec is None:
			_write_atomic(target, source.read_bytes())
			return ""
		channels, rate, samples = decode(source, scratch)
		write_wav(target, channels, rate, render(channels, rate, samples, spec), "seam_ms" in spec)
	except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError, struct.error) as error:
		return "not staged: %s" % error
	return ""


# --- loudness (ITU-R BS.1770 K-weighting, pure Python) -------------------------------------------------------

def _k_weighting(rate: int) -> list[tuple[list[float], list[float]]]:
	"""The two K-weighting biquads (high shelf +4 dB at 1500 Hz, then high pass at 38 Hz: pyloudnorm's
	parameterisation of BS.1770) at `rate`, as normalised (b, a)."""
	g, q, fc = 4.0, 1 / math.sqrt(2), 1500.0
	big_a, w0 = 10 ** (g / 40), 2 * math.pi * fc / rate
	alpha, cos, root = math.sin(w0) / (2 * q), math.cos(w0), math.sqrt(10 ** (g / 40))
	b = [big_a * ((big_a + 1) + (big_a - 1) * cos + 2 * root * alpha), -2 * big_a * ((big_a - 1) + (big_a + 1) * cos),
		big_a * ((big_a + 1) + (big_a - 1) * cos - 2 * root * alpha)]
	a = [(big_a + 1) - (big_a - 1) * cos + 2 * root * alpha, 2 * ((big_a - 1) - (big_a + 1) * cos),
		(big_a + 1) - (big_a - 1) * cos - 2 * root * alpha]
	shelf = ([v / a[0] for v in b], [v / a[0] for v in a])
	q, fc = 0.5, 38.0
	w0 = 2 * math.pi * fc / rate
	alpha, cos = math.sin(w0) / (2 * q), math.cos(w0)
	b, a = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2], [1 + alpha, -2 * cos, 1 - alpha]
	return [shelf, ([v / a[0] for v in b], [v / a[0] for v in a])]


def _filtered_power(channel: list[float], rate: int) -> list[float]:
	"""Each sample's K-weighted power for one channel."""
	y = channel
	for (b0, b1, b2), (_, a1, a2) in _k_weighting(rate):
		out, x1, x2, y1, y2 = [0.0] * len(y), 0.0, 0.0, 0.0, 0.0
		for i, v in enumerate(y):
			o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2, x1, y2, y1, out[i] = x1, v, y1, o, o
		y = out
	return [v * v for v in y]


def _db(power: float) -> float:
	"""10·log10 of a power, floored at -120."""
	return 10.0 * math.log10(power) if power > 1e-12 else -120.0


def loudness(channels: int, rate: int, samples: array.array) -> dict:
	"""Peak (dBFS), the loudest 400 ms block (LUFS; a file shorter than a block counts as one block padded with
	silence) and the gated integrated loudness (LUFS) of interleaved int16 `samples`, AS GODOT PLAYS THEM: the
	channels' powers summed, and a mono file counted as the same signal in both speakers (Godot plays mono to
	both), 3.01 dB above the single channel BS.1770 alone would count."""
	chans = [[s / 32768.0 for s in samples[c::channels]] for c in range(channels)]
	frames = len(chans[0])
	speakers = 2.0 if channels == 1 else 1.0
	power = [speakers * sum(p) for p in zip(*(_filtered_power(c, rate) for c in chans))]
	prefix = [0.0]
	for p in power:
		prefix.append(prefix[-1] + p)
	block, hop = int(0.4 * rate), int(0.1 * rate)
	blocks = [(prefix[s + block] - prefix[s]) / block for s in range(0, frames - block + 1, hop)] \
		if frames >= block else [prefix[frames] / block]
	return {"peak_dbfs": round(_db(max(abs(s) for s in samples) ** 2 / 32768.0 ** 2), 1),
		"momentary_max_lufs": round(-0.691 + _db(max(blocks)), 1), "integrated_lufs": round(_gated(blocks), 1),
		"seconds": round(frames / rate, 3)}


def _gated(blocks: list[float]) -> float:
	"""BS.1770 integrated loudness of 400 ms block powers: absolute gate -70 LUFS, then relative gate -10 LU."""
	kept = [b for b in blocks if -0.691 + _db(b) > -70.0]
	if not kept:
		return -120.0
	relative = -0.691 + _db(sum(kept) / len(kept)) - 10.0
	kept = [b for b in kept if -0.691 + _db(b) > relative]
	return -0.691 + _db(sum(kept) / len(kept)) if kept else -120.0


def measure(out: pathlib.Path, targets: dict | None = None, loops: set | None = None) -> dict:
	"""Every staged file's loudness, and per cue the mean level and the volume_db that puts it at its target
	(a loop by integrated loudness, a one-shot by its loudest block), clamped to the table's -60..+6. A file
	that cannot be decoded is listed under "unreadable" instead."""
	targets = TARGET_LUFS if targets is None else targets
	if loops is None:
		loops = {cue for cue, spec in json.loads(TABLE.read_text())["cues"].items() if spec.get("loop")}
	report: dict = {"unreadable": []}
	with tempfile.TemporaryDirectory() as scratch:
		for cue, rows in CHOICES.items():
			files = {}
			for index, (_, spec) in enumerate(rows):
				staged = out / "sound" / target_name(cue, index, spec)
				try:
					files[staged.name] = loudness(*decode(staged, pathlib.Path(scratch))) if staged.is_file() else None
				except (RuntimeError, subprocess.CalledProcessError, OSError, struct.error) as error:
					report["unreadable"].append("%s: %s" % (staged.name, error))
			files = {name: level for name, level in files.items() if level is not None}
			if files:
				report[cue] = _cue_level(files, "integrated_lufs" if cue in loops else "momentary_max_lufs", targets[cue])
	return report


def _cue_level(files: dict, key: str, target: float) -> dict:
	"""A cue's mean level over its files (by `key`), its spread, and the volume_db that puts it at `target`."""
	levels = [f[key] for f in files.values()]
	mean = sum(levels) / len(levels)
	return {"files": files, "by": key, "mean_lufs": round(mean, 1), "target_lufs": target,
		"volume_db": max(-60.0, min(6.0, float(round(target - mean)))), "spread_lu": round(max(levels) - min(levels), 1)}


# --- ledger ------------------------------------------------------------------------------------------------

def uses_of(relative: str) -> list[dict]:
	"""Which cue variants use library file `relative`, and how (copied, or the render)."""
	return [{"cue": cue, "target": target_name(cue, i, spec), "render": spec}
		for cue, rows in CHOICES.items() for i, (path, spec) in enumerate(rows) if path == relative]


def build_ledger(library: pathlib.Path) -> dict:
	"""files.json: every pack (with its downloaded file's size and SHA-256) and every file under
	assets/library/audio/ (pack, path, bytes, SHA-256, licence as stated, and the cues that use it)."""
	audio = library / "audio"
	packs, files = {}, []
	for key, pack in PACKS.items():
		downloads = [p for p in sorted((audio / key / "download").iterdir()) if not p.name.startswith(".")]
		if len(downloads) != 1:
			raise RuntimeError("%s/download/ must hold exactly the one downloaded file" % key)
		download = downloads[0]
		packs[key] = {**pack, "downloaded": DOWNLOADED, "licence_url": CC0,
			"download_file": {"path": "%s/download/%s" % (key, download.name), "bytes": download.stat().st_size,
			"sha256": sha256_of(download)}}
		for path in sorted(p for p in (audio / key).rglob("*") if p.is_file() and not p.name.startswith(".")):
			relative = path.relative_to(audio).as_posix()
			files.append({"pack": key, "path": relative, "bytes": path.stat().st_size, "sha256": sha256_of(path),
				"licence": pack["licence"], "source": pack["page"], "downloaded": DOWNLOADED, "cues": uses_of(relative)})
	return {"root": "assets/library/audio/ (gitignored; binaries are local only)", "decision": "0351",
		"approved": "Brendan, 2026-09-30: exactly these nine packs", "packs": packs, "count": len(files),
		"total_bytes": sum(f["bytes"] for f in files), "files": files}


def main() -> int:
	"""Stage (default), measure or rewrite the ledger."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--measure", action="store_true", help="print the staged files' loudness as JSON")
	parser.add_argument("--ledger", action="store_true", help="rewrite %s from the library" % LEDGER.name)
	parser.add_argument("--rehash", action="store_true", help="with --ledger: accept files whose SHA-256 changed")
	args = parser.parse_args()
	if args.ledger:
		return write_ledger(args.library, args.rehash)
	if args.measure:
		print(json.dumps(measure(args.out), indent=1))
		return 0
	result = stage(args.library, args.out)
	report(result)
	return 1 if result["skipped"] else 0


def changed_rows(old: dict, new: dict) -> list[str]:
	"""Paths whose SHA-256 differs between two ledgers (a file only in one of them is not a change)."""
	before = {row["path"]: row["sha256"] for row in old.get("files", [])}
	return [row["path"] for row in new["files"] if row["path"] in before and before[row["path"]] != row["sha256"]]


def write_ledger(library: pathlib.Path, rehash: bool) -> int:
	"""Rewrite files.json from the library, refusing (1) when a recorded file's SHA-256 changed, unless `rehash`:
	a changed file is a new download to approve, not something to re-bless by habit."""
	ledger = build_ledger(library)
	changed = changed_rows(json.loads(LEDGER.read_text()), ledger) if LEDGER.is_file() else []
	if changed and not rehash:
		for path in changed:
			print("stage_demo_audio: SHA-256 changed since the ledger: %s" % path)
		print("stage_demo_audio: ledger NOT written (--rehash accepts the changes)")
		return 1
	LEDGER.write_text(json.dumps(ledger, indent=1) + "\n")
	print("stage_demo_audio: ledger written -> %s" % LEDGER)
	return 0


def report(result: dict) -> None:
	"""Print what staging did."""
	for name in result["removed"]:
		print("stage_demo_audio: removed %s (no choice names it)" % name)
	for name, why in result["skipped"]:
		print("stage_demo_audio: skipped %s -- %s" % (name, why))
	print("stage_demo_audio: %d sound files staged, %d skipped -> godot/demo/assets/sound/ (import them: "
		"godot --headless --path godot --import)" % (len(result["staged"]), len(result["skipped"])))


if __name__ == "__main__":
	sys.exit(main())
