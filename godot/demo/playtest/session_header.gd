extends RefCounted
## The playtest log's SESSION HEADER: what a bug report needs to know about the machine and the build (decision
## 0562). DEMO DIAGNOSTICS.
##
## FIELDS (KEYS, in order): when the session started, the game's version, how it was built and Godot's version,
## the OS, CPU and memory, the graphics adapter and its driver, the rendering method, the screen, the window
## (mode, size, vsync), the demo's settings and presets, and the language. Copy report builds it afresh, so the
## settings and window there are the ones at the time of the copy.
##
## VERSION. A build made by tools/build_demo_windows.py packs `demo/build_info.json` -- the commit (marked -dirty
## for uncommitted changes), the build time and Godot's version -- and the header quotes it. A run from the
## project (no build info, not an export) asks git for the commit once; an export without the file says
## "unknown", which is itself a finding.
##
## PRIVACY. No account name, machine name, path or address: the folders that appear in error lines are scrubbed
## by the writer, and nothing here reads them.

const Access := preload("res://demo/access/demo_access.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

const BUILD_INFO_PATH: String = "res://demo/build_info.json"
const KEYS: Array[String] = ["started", "version", "build", "godot", "os", "cpu", "memory", "gpu", "gpu driver",
	"rendering", "display", "window", "settings", "language"]
const WINDOW_MODES: Array[String] = ["windowed", "minimized", "maximized", "full screen", "exclusive full screen"]
const VSYNC_MODES: Array[String] = ["off", "on", "adaptive", "mailbox"]
const ADAPTER_TYPES: Array[String] = ["other", "integrated", "discrete", "virtual", "CPU"]
const UNKNOWN: String = "unknown"
const MIB: int = 1024 * 1024

## The version, found once per process (git is asked at most once).
static var _version: String = ""


static func collect() -> PackedStringArray:
	"""The header's values, one per KEYS entry, read now."""
	return PackedStringArray([started_text(), version_text(), build_text(), Engine.get_version_info().get("string", UNKNOWN),
		os_text(), "%s, %d threads" % [_or_unknown(OS.get_processor_name()), OS.get_processor_count()], memory_text(),
		gpu_text(), driver_text(), rendering_text(), display_text(), window_text(), settings_text(),
		_or_unknown(OS.get_locale_language())])


static func lines(values: PackedStringArray) -> PackedStringArray:
	"""'key: value' for each field, in KEYS order."""
	var out := PackedStringArray()
	for k: int in KEYS.size():
		out.append("%s: %s" % [KEYS[k], values[k] if k < values.size() else UNKNOWN])
	return out


static func started_text() -> String:
	"""The local date and time now, with its offset from UTC: '2026-10-01 14:03:22 (UTC+01:00)'."""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	@warning_ignore("integer_division") var hours: int = absi(bias) / 60
	return "%s (UTC%s%02d:%02d)" % [Time.get_datetime_string_from_system(false, true), "-" if bias < 0 else "+",
		hours, absi(bias) % 60]


static func version_text() -> String:
	"""The build's commit and time from BUILD_INFO_PATH, else 'dev <commit>' from git (not in an export)."""
	if _version.is_empty():
		_version = _read_version()
	return _version


static func _read_version() -> String:
	"""See version_text."""
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO_PATH)) \
		if FileAccess.file_exists(BUILD_INFO_PATH) else null
	if info is Dictionary:
		var baked: Dictionary = info
		return "%s (built %s, %s export)" % [baked.get("commit", UNKNOWN), baked.get("built", UNKNOWN),
			baked.get("export", UNKNOWN)]
	if OS.has_feature("template"):
		return "%s (no build info packed)" % UNKNOWN
	var output: Array = []
	var code: int = OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"],
		output, true)
	var commit: String = String(output[0]).strip_edges() if code == 0 and not output.is_empty() else UNKNOWN
	return "dev %s (run from the project)" % commit


static func build_text() -> String:
	"""'export, release, demo_build' / 'project run, debug'."""
	return "%s, %s%s" % ["export" if OS.has_feature("template") else "project run",
		"debug" if OS.is_debug_build() else "release", ", demo_build" if OS.has_feature("demo_build") else ""]


static func os_text() -> String:
	"""'Windows 10.0.22631' / 'macOS 26.6.2'."""
	return "%s %s" % [OS.get_name(), _or_unknown(OS.get_version())]


static func memory_text() -> String:
	"""Physical memory, in MiB: '16384 MiB physical'."""
	var physical: int = int(OS.get_memory_info().get("physical", -1))
	@warning_ignore("integer_division") var mib: int = physical / MIB
	return "%d MiB physical" % mib


static func gpu_text() -> String:
	"""The adapter: 'NVIDIA GeForce GTX 1660 SUPER (NVIDIA, discrete, API 1.3.280)'."""
	var kind: int = RenderingServer.get_video_adapter_type()
	return "%s (%s, %s, API %s)" % [_or_unknown(RenderingServer.get_video_adapter_name()),
		_or_unknown(RenderingServer.get_video_adapter_vendor()), ADAPTER_TYPES[kind] if kind >= 0 and kind < ADAPTER_TYPES.size()
		else UNKNOWN, _or_unknown(RenderingServer.get_video_adapter_api_version())]


static func driver_text() -> String:
	"""The adapter's driver name and version (Windows and Linux report it; macOS does not)."""
	var info: PackedStringArray = OS.get_video_adapter_driver_info()
	return " ".join(info) if not info.is_empty() else "not reported on %s" % OS.get_name()


static func rendering_text() -> String:
	"""'forward_plus on vulkan' -- the method and driver actually running (after any fallback)."""
	return "%s on %s" % [_or_unknown(RenderingServer.get_current_rendering_method()),
		_or_unknown(RenderingServer.get_current_rendering_driver_name())]


static func display_text() -> String:
	"""'macOS display, screen 3024x1964 at scale 2, 120 Hz, 1 screen(s)'."""
	var screen: int = DisplayServer.window_get_current_screen()
	return "%s display, screen %s at scale %s, %d Hz, %d screen(s)" % [DisplayServer.get_name(),
		_size_text(DisplayServer.screen_get_size(screen)), DisplayServer.screen_get_scale(screen),
		roundi(DisplayServer.screen_get_refresh_rate(screen)), DisplayServer.get_screen_count()]


static func window_text() -> String:
	"""'maximized 1920x1080, vsync on'."""
	var mode: int = DisplayServer.window_get_mode()
	var vsync: int = DisplayServer.window_get_vsync_mode()
	return "%s %s, vsync %s, max fps %d" % [WINDOW_MODES[mode] if mode >= 0 and mode < WINDOW_MODES.size() else UNKNOWN,
		_size_text(DisplayServer.window_get_size()), VSYNC_MODES[vsync] if vsync >= 0 and vsync < VSYNC_MODES.size()
		else UNKNOWN, Engine.max_fps]


static func settings_text() -> String:
	"""The demo's settings now: 'scale 125%, sound Quiet focus, songs on; on: ...; presets: Quiet focus'."""
	var mix: String = SoundMix.PRESET_NAMES[SoundMix.preset] if SoundMix.preset >= 0 else "custom"
	var on := PackedStringArray()
	for setting: int in Access.SET_COUNT:
		if Access.is_on(setting):
			on.append(Access.SET_NAMES[setting])
	return "scale %d%%, sound %s, songs %s; on: %s; presets: %s" % [DemoUiScale.percent, mix,
		"on" if SoundMix.songs_on else "off", ", ".join(on) if not on.is_empty() else "none", presets_text()]


static func presets_text() -> String:
	"""The accessibility presets whose every setting is in effect ('none' for none)."""
	var now := Access.Snapshot.new()
	Access.current_into(now)
	var applied := Access.Snapshot.new()
	var names := PackedStringArray()
	for preset: int in Access.PRESET_COUNT:
		Access.preset_into(preset, now, Callable(), applied)
		if applied.same_as(now):
			names.append(Access.PRESET_NAMES[preset])
	return ", ".join(names) if not names.is_empty() else "none"


static func _size_text(size_px: Vector2i) -> String:
	"""'1920x1080'."""
	return "%dx%d" % [size_px.x, size_px.y]


static func _or_unknown(text: String) -> String:
	"""`text`, or UNKNOWN when it is empty (a headless run reports no adapter)."""
	return text if not text.strip_edges().is_empty() else UNKNOWN
