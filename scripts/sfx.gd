extends Node

# Procedural sound effect generator
# Creates short AudioStreamWAV samples from waveforms


static func create_sample(freq: float, duration: float, volume: float = 0.3,
		type: String = "square", freq_end: float = -1) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit samples

	if freq_end < 0:
		freq_end = freq

	for i in num_samples:
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		var f := lerpf(freq, freq_end, progress)
		var env := (1.0 - progress) * volume  # linear fade out

		var sample: float
		match type:
			"square":
				sample = env if fmod(t * f, 1.0) < 0.5 else -env
			"noise":
				sample = (randf() * 2.0 - 1.0) * env
			"sine":
				sample = sin(t * f * TAU) * env
			"saw":
				sample = (fmod(t * f, 1.0) * 2.0 - 1.0) * env

		var val := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


static func sfx_mine_hit() -> AudioStreamWAV:
	return create_sample(200, 0.08, 0.25, "noise")


static func sfx_mine_break() -> AudioStreamWAV:
	return create_sample(150, 0.12, 0.3, "noise")


static func sfx_shotgun() -> AudioStreamWAV:
	return create_sample(80, 0.15, 0.4, "noise")


static func sfx_bounce() -> AudioStreamWAV:
	return create_sample(400, 0.1, 0.2, "sine", 800)


static func sfx_laser() -> AudioStreamWAV:
	return create_sample(1200, 0.08, 0.15, "sine", 600)


static func sfx_enemy_hit() -> AudioStreamWAV:
	return create_sample(300, 0.06, 0.2, "square", 150)


static func sfx_enemy_die() -> AudioStreamWAV:
	return create_sample(400, 0.2, 0.25, "square", 80)


static func sfx_turret_fire() -> AudioStreamWAV:
	return create_sample(600, 0.05, 0.15, "square", 200)


static func sfx_ammo_received() -> AudioStreamWAV:
	return create_sample(800, 0.08, 0.15, "sine", 1200)


static func play(node: Node, stream: AudioStreamWAV) -> void:
	if node is Node2D:
		var player := AudioStreamPlayer2D.new()
		player.stream = stream
		player.volume_db = -6
		player.max_distance = 400.0
		player.attenuation = 2.0
		node.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -6
		node.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
