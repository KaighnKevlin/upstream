extends Node

# Procedural sound effects: each sound is built from layers (swept tones with
# exponential decay, filtered noise bursts, inharmonic metal partials),
# rendered once per variant and cached. play() picks a variant and adds a
# little pitch jitter, so repeated sounds don't machine-gun.

const RATE := 22050
const VARIANTS := 4

static var _cache := {}


# ── synthesis helpers ──────────────────────────────────────────────────

static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


## Swept sine (f0 -> f1, exponential sweep) with a short attack and an
## exponential decay (seconds to fall to ~37%).
static func _tone(b: PackedFloat32Array, f0: float, f1: float, amp: float, decay: float,
		start := 0.0, attack := 0.002) -> void:
	var s0 := int(start * RATE)
	var phase := 0.0
	var n := b.size() - s0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / float(maxi(1, n))
		var f := f0 * pow(f1 / f0, k)
		phase += f / RATE
		var env := minf(1.0, t / attack) * exp(-t / decay)
		b[s0 + i] += sin(phase * TAU) * amp * env


## Noise burst through a one-pole low-pass (cutoff Hz); hp=true high-passes
## instead (keeps the hiss, drops the rumble).
static func _noise(b: PackedFloat32Array, amp: float, decay: float, cutoff: float,
		start := 0.0, hp := false, rng: RandomNumberGenerator = null) -> void:
	var s0 := int(start * RATE)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var lp := 0.0
	for i in b.size() - s0:
		var t := float(i) / RATE
		var w := (rng.randf() if rng else randf()) * 2.0 - 1.0
		lp += a * (w - lp)
		var v := (w - lp) if hp else lp
		b[s0 + i] += v * amp * exp(-t / decay) * minf(1.0, t / 0.001)


## Metal: a few inharmonic partials ringing down at different rates.
static func _metal(b: PackedFloat32Array, base: float, amp: float, decay: float, start := 0.0) -> void:
	for p in [[1.0, 1.0, 1.0], [1.47, 0.6, 0.7], [2.09, 0.45, 0.5], [2.76, 0.3, 0.35], [3.93, 0.2, 0.25]]:
		_tone(b, base * p[0], base * p[0] * 0.995, amp * p[1], decay * p[2], start, 0.0005)


static func _wav(b: PackedFloat32Array, vol: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		var s := int(clampf(b[i] / peak * vol, -1.0, 1.0) * 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


static func _sound(name: String, build: Callable) -> AudioStreamWAV:
	if not _cache.has(name):
		var list := []
		for v in VARIANTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(name) + v * 7919
			list.append(build.call(rng))
		_cache[name] = list
	var l: Array = _cache[name]
	return l[randi() % l.size()]


# ── the sounds ─────────────────────────────────────────────────────────

## Pick biting into rock: a short thunk and a gritty tick.
static func sfx_mine_hit() -> AudioStreamWAV:
	return _sound("mine_hit", func(r: RandomNumberGenerator):
		var b := _buf(0.12)
		_tone(b, 180 * r.randf_range(0.9, 1.1), 90, 0.7, 0.03)
		_noise(b, 0.6, 0.025, 2500, 0.0, false, r)
		_noise(b, 0.25, 0.008, 6000, 0.0, true, r)
		return _wav(b, 0.55))


## A tile giving way. kind: 0 dirt (dull, crumbly), 1+ stone (crunchier,
## brighter, a stony clack).
static func sfx_mine_break(kind := 0) -> AudioStreamWAV:
	var stony := kind != 0 and kind != 5
	return _sound("mine_break_%s" % stony, func(r: RandomNumberGenerator):
		var b := _buf(0.32)
		_tone(b, 120 * r.randf_range(0.85, 1.1), 55, 0.8, 0.05)         # thud
		var grains := r.randi_range(4, 6)
		for g in grains:                                                   # rubble
			var at := 0.01 + g * r.randf_range(0.02, 0.04)
			_noise(b, r.randf_range(0.35, 0.7), r.randf_range(0.012, 0.03),
				(3200.0 if stony else 1400.0) * r.randf_range(0.7, 1.3), at, false, r)
		if stony:
			_metal(b, r.randf_range(900, 1300), 0.12, 0.03, 0.005)          # stony clack
		return _wav(b, 0.6))


## Pick glancing off ironstone or an ore vein: a bright ringing clink.
static func sfx_clink() -> AudioStreamWAV:
	return _sound("clink", func(r: RandomNumberGenerator):
		var b := _buf(0.35)
		_metal(b, r.randf_range(1700, 2100), 0.6, 0.09)
		_noise(b, 0.4, 0.004, 8000, 0.0, true, r)
		return _wav(b, 0.45))


## Loose ore knocking into something. surface: "ground" (a dull thud with
## grit), "metal" (a machine's steel: a small tink), "ore" (stone on stone:
## a dry click, what a filling funnel sounds like).
static func sfx_ore_knock(surface: String) -> AudioStreamWAV:
	return _sound("ore_knock_" + surface, func(r: RandomNumberGenerator):
		var b := _buf(0.16)
		match surface:
			"metal":
				_metal(b, r.randf_range(1300, 1700), 0.35, 0.035)
				_tone(b, 240, 150, 0.35, 0.015)
			"ore":
				_noise(b, 0.5, 0.006, 5000, 0.0, true, r)
				_metal(b, r.randf_range(2200, 2800), 0.12, 0.012)
				_tone(b, 520, 380, 0.25, 0.008)
			_:
				_tone(b, r.randf_range(95, 130), 60, 0.7, 0.03)
				_noise(b, 0.45, 0.02, 1800, 0.0, false, r)
				_noise(b, 0.2, 0.006, 5000, 0.004, true, r)
		return _wav(b, 0.5))


static func sfx_shotgun() -> AudioStreamWAV:
	return _sound("shotgun", func(r: RandomNumberGenerator):
		var b := _buf(0.45)
		_noise(b, 1.0, 0.07, 1800, 0.0, false, r)
		_tone(b, 90, 40, 0.9, 0.09)
		_noise(b, 0.3, 0.2, 500, 0.02, false, r)                          # rumble tail
		_metal(b, 520, 0.08, 0.05, 0.03)                                    # brass ring
		return _wav(b, 0.7))


## Spring: a boing that bends up, with a soft thunk.
static func sfx_bounce() -> AudioStreamWAV:
	return _sound("bounce", func(r: RandomNumberGenerator):
		var b := _buf(0.28)
		var f := r.randf_range(170, 230)
		_tone(b, f, f * 2.3, 0.5, 0.09, 0.0, 0.004)
		_tone(b, f * 1.5, f * 3.1, 0.18, 0.06, 0.0, 0.004)
		_tone(b, 110, 70, 0.4, 0.025)
		return _wav(b, 0.42))


## Pinball bumper: a sprung thump under a bright bell.
static func sfx_bumper() -> AudioStreamWAV:
	return _sound("bumper", func(r: RandomNumberGenerator):
		var b := _buf(0.4)
		_tone(b, 150, 60, 0.6, 0.05)
		_noise(b, 0.25, 0.012, 4000, 0.0, true, r)
		_metal(b, r.randf_range(620, 700), 0.35, 0.18, 0.004)
		return _wav(b, 0.45))


static func sfx_laser() -> AudioStreamWAV:
	return _sound("laser", func(r: RandomNumberGenerator):
		var b := _buf(0.2)
		_tone(b, 1600, 280, 0.5, 0.07, 0.0, 0.001)
		_noise(b, 0.6, 0.05, 7000, 0.0, true, r)                           # crackle
		for k in 5:
			_noise(b, 0.5, 0.004, 9000, 0.02 + k * r.randf_range(0.015, 0.03), true, r)
		return _wav(b, 0.4))


## Shot hits clockwork: a short metallic clang.
static func sfx_enemy_hit() -> AudioStreamWAV:
	return _sound("enemy_hit", func(r: RandomNumberGenerator):
		var b := _buf(0.2)
		_metal(b, r.randf_range(520, 700), 0.6, 0.05)
		_noise(b, 0.35, 0.01, 4000, 0.0, false, r)
		return _wav(b, 0.45))


## Clockwork coming apart: a clang, then a rattle of gears and springs.
static func sfx_enemy_die() -> AudioStreamWAV:
	return _sound("enemy_die", func(r: RandomNumberGenerator):
		var b := _buf(0.6)
		_metal(b, r.randf_range(380, 460), 0.7, 0.12)
		_tone(b, 140, 60, 0.6, 0.08)
		for k in 8:
			_metal(b, r.randf_range(1400, 3200), 0.12, 0.02, 0.06 + k * r.randf_range(0.03, 0.06))
		return _wav(b, 0.6))


static func sfx_turret_fire() -> AudioStreamWAV:
	return _sound("turret_fire", func(r: RandomNumberGenerator):
		var b := _buf(0.3)
		_noise(b, 0.8, 0.04, 2200, 0.0, false, r)
		_tone(b, 150, 60, 0.8, 0.06)
		_metal(b, 800, 0.15, 0.04, 0.02)                                    # breech clank
		return _wav(b, 0.5))


## Ingot into the dome: a two-note brass chime.
static func sfx_ammo_received() -> AudioStreamWAV:
	return _sound("ammo", func(r: RandomNumberGenerator):
		var b := _buf(0.35)
		_tone(b, 880, 880, 0.4, 0.12, 0.0, 0.002)
		_tone(b, 1320, 1320, 0.35, 0.15, 0.06, 0.002)
		_metal(b, 1760, 0.05, 0.05)
		return _wav(b, 0.4))


## Legacy single-tone generator (kept for anything still calling it).
static func create_sample(freq: float, duration: float, volume: float = 0.3,
		type: String = "square", freq_end: float = -1) -> AudioStreamWAV:
	var b := _buf(duration)
	if type == "noise":
		_noise(b, 1.0, duration / 3.0, 3000)
	else:
		_tone(b, freq, freq_end if freq_end > 0 else freq, 1.0, duration / 3.0)
	return _wav(b, volume * 2.0)


## Many small sounds at once (a pour, a pile settling) are capped: at most
## BUSY_MAX of them start in any BUSY_WINDOW; the rest are skipped.
const BUSY_MAX := 4
const BUSY_WINDOW := 0.1
static var _busy: Array[float] = []
static var small_played := 0   # counters, for tests
static var small_skipped := 0


static func play_small(node: Node, stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _busy.is_empty() and now - _busy[0] > BUSY_WINDOW:
		_busy.pop_front()
	if _busy.size() >= BUSY_MAX:
		small_skipped += 1
		return
	small_played += 1
	_busy.append(now)
	play(node, stream, volume_db, pitch)


static func play(node: Node, stream: AudioStreamWAV, volume_db := -6.0, pitch_base := 1.0) -> void:
	var pitch := randf_range(0.93, 1.07) * pitch_base
	if node is Node2D:
		var player := AudioStreamPlayer2D.new()
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.max_distance = 400.0
		player.attenuation = 2.0
		node.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		node.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
