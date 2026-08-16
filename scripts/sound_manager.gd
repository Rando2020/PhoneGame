extends Node
class_name RetroSound

const SAMPLE_RATE := 22050

func draw_card() -> void:
	_play_sequence([[520.0, 0.035, 0.16], [700.0, 0.025, 0.12]])

func select_card() -> void:
	_play_sequence([[880.0, 0.018, 0.09]])

func defend() -> void:
	_play_sequence([[260.0, 0.045, 0.18], [210.0, 0.05, 0.15]])

func meld() -> void:
	_play_sequence([[440.0, 0.045, 0.16], [660.0, 0.045, 0.16], [990.0, 0.07, 0.18]])

func hit() -> void:
	_play_sequence([[125.0, 0.055, 0.20], [92.0, 0.035, 0.16]])

func win() -> void:
	_play_sequence([[523.0, 0.08, 0.14], [659.0, 0.08, 0.14], [784.0, 0.08, 0.14], [1046.0, 0.16, 0.16]])

func lose() -> void:
	_play_sequence([[330.0, 0.09, 0.13], [247.0, 0.10, 0.13], [165.0, 0.18, 0.13]])

func _play_sequence(notes: Array) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	for note in notes:
		var frequency: float = note[0]
		var duration: float = note[1]
		var volume: float = note[2]
		var sample_count := int(SAMPLE_RATE * duration)
		for i in range(sample_count):
			var phase := fmod(float(i) * frequency / SAMPLE_RATE, 1.0)
			var square := 1.0 if phase < 0.5 else -1.0
			var envelope := 1.0 - (float(i) / max(1.0, sample_count)) * 0.55
			var sample := int(128.0 + square * 127.0 * volume * envelope)
			bytes.append(clamp(sample, 0, 255))
	stream.data = bytes
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.play()
