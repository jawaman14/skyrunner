class_name VoiceCapture
extends RefCounted
## Microphone audio in whatever rate the sound card runs at, cut into the 40 ms, 8 kHz frames the wire carries
## (VoiceCodec.FRAME_N samples each). Pure: push samples in, get whole frames out; what is left over waits for the next push.

var carry := PackedFloat32Array()  ## 8 kHz samples that are not yet a whole frame
var gain := 1.0  ## the input volume slider
var level := 0.0  ## the peak of the last push (the meter)


## Mono samples at `rate` in; the whole frames (arrays of VoiceCodec.FRAME_N samples) they complete out.
func push(mono: PackedFloat32Array, rate: float) -> Array:
	var narrow := VoiceCodec.resample(mono, rate, float(VoiceCodec.RATE))
	if gain != 1.0:
		for i in narrow.size():
			narrow[i] = clampf(narrow[i] * gain, -1.0, 1.0)
	level = VoiceCodec.level(narrow)
	carry.append_array(narrow)
	var frames := []
	while carry.size() >= VoiceCodec.FRAME_N:
		frames.append(carry.slice(0, VoiceCodec.FRAME_N))
		carry = carry.slice(VoiceCodec.FRAME_N)
	return frames


## The key came up: whatever is left is not a frame; drop it (the end-of-transmission marker is sent separately).
func reset() -> void:
	carry = PackedFloat32Array()
	level = 0.0
