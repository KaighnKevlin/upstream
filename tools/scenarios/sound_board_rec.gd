extends RefCounted
## Sound board: builds every machine-part sound (all its variants), logs each
## one's length and peak so an empty, clipped or overlong one shows, saves
## them as .wav into the out dir to listen to, and plays them in turn.

const SFX = preload("res://scripts/sfx.gd")

const SOUNDS := {
	"ratchet": "tally notch, escapement tick, delay relay winding",
	"latch": "points, latch, overflow gate, rocker",
	"twang": "plunger, flap sorter flap, teeter launch",
	"hiss": "kicker punch, booster rollers",
	"grind": "grindstone",
	"thud": "stamp press, gear stamp",
	"magnet": "magnet drum, gauss cannon",
	"creak": "counterweight, ropeway, sluice winch",
	"whoosh": "trebuchet, volcano",
	"roll": "banked turn, bowling ramp, vortex",
}


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	DirAccess.make_dir_recursive_absolute(t.out_dir)
	var build := {
		"ratchet": func(): return SFX.sfx_ratchet(), "latch": func(): return SFX.sfx_latch(),
		"twang": func(): return SFX.sfx_twang(), "hiss": func(): return SFX.sfx_hiss(),
		"grind": func(): return SFX.sfx_grind(), "thud": func(): return SFX.sfx_thud(),
		"magnet": func(): return SFX.sfx_magnet(), "creak": func(): return SFX.sfx_creak(),
		"whoosh": func(): return SFX.sfx_whoosh(), "roll": func(): return SFX.sfx_roll(),
	}
	var bad := 0
	for name in SOUNDS:
		var first: AudioStreamWAV = build[name].call()
		var variants: Array = SFX._cache[name]
		var line := "%-8s" % name
		for v in variants.size():
			var s: AudioStreamWAV = variants[v]
			var n := s.data.size() / 2
			var peak := 0
			var sq := 0.0
			for i in n:
				var x := s.data.decode_s16(i * 2)
				peak = maxi(peak, absi(x))
				sq += float(x) * x
			var dur := float(n) / s.mix_rate
			var p := peak / 32767.0
			var rms := sqrt(sq / maxf(1.0, n)) / 32767.0
			line += "  v%d %.3fs peak %.2f rms %.3f" % [v, dur, p, rms]
			if n == 0 or p < 0.05 or p > 0.99 or dur > 0.5:
				bad += 1
				line += " !!"
			s.save_to_wav("%s/%s_v%d.wav" % [t.out_dir, name, v])
		t.log_line(line + "   (" + SOUNDS[name] + ")")
		for k in 3:
			SFX.play(t.main, first, -6.0, 1.0)
			await t.wait(0.35)
	t.log_line("sound board: %d sounds, %d bad variants, wavs in %s" % [SOUNDS.size(), bad, t.out_dir])
