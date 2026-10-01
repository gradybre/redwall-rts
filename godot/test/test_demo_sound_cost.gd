extends "res://test/framework/test_case.gd"
## The demo sound pass's per-frame cost (decision 0351): twenty residents at 4x -- all walking (footsteps),
## twelve of them felling (strikes), every one picking up and dropping a load in turn -- with the notice feed,
## the weather and the village's real water map read for ambience. The director's whole frame (event map, voice
## offers, loop easing) is timed over ten real seconds of 60 fps frames. No sound files are staged, so this is
## the logic's cost; mixing staged audio is the engine's, on its own thread.
##
## The bound asserted is deliberately loose (a slow CI host must not flake it): BUDGET_P99_USEC is a quarter of the
## 1x simulation tick's 2 ms (CLAUDE.md performance targets). The measured figures are printed for the record.

const DirectorScript := preload("res://demo/sound/sound_director.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const WORKERS: int = 20
const FELLERS: int = 12
const SPEED: int = 4
const FRAMES: int = 600
const FRAME_MS: int = 16
const BUDGET_P99_USEC: int = 500

var _director: DirectorScript = null
var _jobs: JobsScript = JobsScript.new()
var _brains: Array[BrainScript] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free the director; the mix back to Balanced."""
	if _director != null:
		_director.free()
	_director = null
	SoundMix.reset()


func _crowd() -> void:
	"""Twenty residents round the village's middle, twelve with a fell under way, and the shared feeds."""
	_director = DirectorScript.new()
	assert_true(_director.configure(), "the table reads")
	for k: int in WORKERS:
		var brain := BrainScript.new()
		brain.position = Vector2(float(k % 5) * 1.5 - 3.0, float(k / 5) * 1.5 - 3.0)
		_brains.append(brain)
		if k < FELLERS:
			assert_true(_jobs.open_into(JobsScript.KIND_FELL, k, 0, JobsScript.ORIGIN_PLAYER, _read), "fell %d" % k)
			_jobs.assign(_read.value, k)
			_jobs.step[_read.value] = 1
			_jobs.issued[_read.value] = 1
	_director.taps.brains = _brains
	_director.taps.jobs = _jobs
	_director.taps.notices = NoticesScript.new()
	_director.taps.weather = WeatherScript.new()
	_director.taps.water_map = WaterLayout.make_map()
	_director.taps.watch(0)
	_director.set_listener(Vector3.ZERO, 14.0)
	var started: int = Time.get_ticks_usec()
	_director.warm()
	print("SOUND-COST the boot prewarm step (streams and the path grid): %d us" % (Time.get_ticks_usec() - started))


func _frame(f: int) -> void:
	"""One frame of the crowd's life at SPEED: everyone walks on, the fells advance, a load changes hands."""
	var step_m: float = 0.8 * SPEED * FRAME_MS / 1000.0
	for k: int in WORKERS:
		var brain: BrainScript = _brains[k]
		var angle: float = float(f) * 0.02 + float(k)
		brain.position.x += cos(angle) * step_m
		brain.position.y += sin(angle) * step_m
	for row: int in FELLERS:
		_jobs.elapsed_usec[row] += FRAME_MS * 1000 * SPEED
	_brains[f % WORKERS].carrying = not _brains[f % WORKERS].carrying
	if f % 120 == 0:
		_director.taps.notices.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Warning %d" % f)


func test_twenty_workers_at_four_x_cost_little_per_frame() -> void:
	"""The director's frame, p50 / p95 / p99 / max, with every source busy; p99 under BUDGET_P99_USEC."""
	_crowd()
	var samples := PackedInt64Array()
	samples.resize(FRAMES)
	var events: int = 0
	for f: int in FRAMES:
		_frame(f)
		var started: int = Time.get_ticks_usec()
		_director.update(1000 + f * FRAME_MS, FRAME_MS / 1000.0)
		samples[f] = Time.get_ticks_usec() - started
		events += _director.taps.event_count
	samples.sort()
	var p99: int = samples[FRAMES * 99 / 100]
	print("SOUND-COST %d workers at %dx: p50 %d us, p95 %d us, p99 %d us, max %d us; %d events, %d played, %d folded" % [
		WORKERS, SPEED, samples[FRAMES / 2], samples[FRAMES * 95 / 100], p99, samples[FRAMES - 1], events,
		_director.voices.total_played(), _director.voices.refused[1]])
	assert_true(events > FRAMES, "the crowd is busy (%d events)" % events)
	assert_true(p99 < BUDGET_P99_USEC, "p99 %d us under %d us" % [p99, BUDGET_P99_USEC])
	assert_true(_director.voices.busy(SoundMix.BUS_WORK, 1000 + FRAMES * FRAME_MS) <= 8, "the work pool's 8 at most")
	assert_equal(_director.taps.overflow, 0, "no frame overflowed its event columns")
