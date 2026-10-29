extends RefCounted
class_name ToneGenerator
## 占位音频生成器：美术提供真实音频之前，用程序合成“钢琴旋律”和“怀表滴答声”。
## 音符用 MIDI 编号（60 = 中央 C，0 = 休止）。生成结果是单声道 16 位 AudioStreamWAV。

const SAMPLE_RATE := 22050

## 钢琴：每拍一个音，带泛音与指数衰减。
static func piano(notes: Array, beat: float, duration: float) -> AudioStreamWAV:
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * SAMPLE_RATE))
	for i in range(notes.size()):
		var midi := int(notes[i])
		if midi <= 0: continue
		var frequency := 440.0 * pow(2.0, (midi - 69) / 12.0)
		var start := int(i * beat * SAMPLE_RATE)
		var length := int(minf(beat * 2.5, duration - i * beat) * SAMPLE_RATE)
		for n in range(length):
			var t := float(n) / SAMPLE_RATE
			var attack := minf(1.0, t * 200.0)
			var tone := sin(TAU * frequency * t) + 0.5 * sin(TAU * 2.0 * frequency * t) * exp(-t * 2.0) + 0.25 * sin(TAU * 3.0 * frequency * t) * exp(-t * 4.0)
			buffer[start + n] += 0.22 * attack * exp(-t * 3.0) * tone
	return to_wav(buffer)

## 怀表：每半拍一声“滴/答”（高低交替），每拍再加一声轻柔的铃音（音高取自 bell_notes，循环使用），
## 让切开后的每个片段听起来都不一样。
static func ticks(duration: float, beat: float, bell_notes: Array) -> AudioStreamWAV:
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * SAMPLE_RATE))
	var count := int(duration / (beat * 0.5))
	for k in range(count):
		var start := int(k * beat * 0.5 * SAMPLE_RATE)
		var click := 2200.0 if k % 2 == 0 else 1500.0
		for n in range(int(0.04 * SAMPLE_RATE)):
			if start + n >= buffer.size(): break
			var t := float(n) / SAMPLE_RATE
			buffer[start + n] += 0.35 * exp(-t * 120.0) * sin(TAU * click * t)
		if k % 2 != 0 or bell_notes.is_empty(): continue
		var midi := int(bell_notes[int(k / 2.0) % bell_notes.size()])
		if midi <= 0: continue
		var frequency := 440.0 * pow(2.0, (midi - 69) / 12.0)
		for n in range(int(minf(0.45, duration - k * beat * 0.5) * SAMPLE_RATE)):
			if start + n >= buffer.size(): break
			var t := float(n) / SAMPLE_RATE
			buffer[start + n] += 0.12 * exp(-t * 6.0) * sin(TAU * frequency * t)
	return to_wav(buffer)

static func to_wav(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i in range(buffer.size()):
		# tanh 软削波，避免叠加后爆音
		data.encode_s16(i * 2, int(tanh(buffer[i]) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
