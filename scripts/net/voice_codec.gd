class_name VoiceCodec
extends RefCounted
## Voice on the wire, radio-quality by design: 8 kHz mono, 40 ms frames of 320 samples, each sample squeezed to one
## byte with mu-law companding (the telephone's own codec), so a talker costs 8 kB/s plus the JSON line's base64 (about
## 11 kB/s) on the host connection the seats already use. No dependencies, no native code, and 8 kHz is also how a
## walkie-talkie sounds.
##
## Everything here is pure functions on arrays, so it is tested without a microphone.

const RATE := 8000
const FRAME_S := 0.04
const FRAME_N := 320  ## RATE * FRAME_S
const MU := 255.0
const MAX_FRAME_B64 := 1024  ## the host drops anything longer: a frame is 320 bytes (432 characters of base64)


## One float sample (-1..1) to a mu-law byte.
static func enc(x: float) -> int:
	var v := clampf(x, -1.0, 1.0)
	var m := log(1.0 + MU * absf(v)) / log(1.0 + MU)  # 0..1
	var q := int(roundf(m * 127.0))
	return (q | 0x80) if v < 0.0 else q


## A mu-law byte back to a float sample.
static func dec(b: int) -> float:
	var neg := (b & 0x80) != 0
	var m := float(b & 0x7F) / 127.0
	var v := (pow(1.0 + MU, m) - 1.0) / MU
	return -v if neg else v


static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in samples.size():
		out[i] = enc(samples[i])
	return out


static func decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	for i in bytes.size():
		out[i] = dec(bytes[i])
	return out


## A frame for the JSON line.
static func pack(samples: PackedFloat32Array) -> String:
	return Marshalls.raw_to_base64(encode(samples))


static func unpack(b64: String) -> PackedFloat32Array:
	if b64.length() > MAX_FRAME_B64:
		return PackedFloat32Array()
	return decode(Marshalls.base64_to_raw(b64))


## Mono samples from `src` (at `from_rate`) at `to_rate`: the average of the source samples each output sample covers
## when going down (a crude low-pass, which is what stops the aliasing), linear interpolation going up.
static func resample(src: PackedFloat32Array, from_rate: float, to_rate: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if src.is_empty() or from_rate <= 0.0 or to_rate <= 0.0:
		return out
	var n := int(float(src.size()) * to_rate / from_rate)
	out.resize(n)
	var step := from_rate / to_rate
	if step > 1.0:
		for i in n:
			var a := int(float(i) * step)
			var b := mini(src.size(), int(float(i + 1) * step))
			var acc := 0.0
			for k in range(a, maxi(b, a + 1)):
				acc += src[mini(k, src.size() - 1)]
			out[i] = acc / float(maxi(b - a, 1))
	else:
		for i in n:
			var pos := float(i) * step
			var a := int(pos)
			var f := pos - float(a)
			var x0: float = src[mini(a, src.size() - 1)]
			var x1: float = src[mini(a + 1, src.size() - 1)]
			out[i] = x0 + (x1 - x0) * f
	return out


## Stereo capture frames (Vector2 per sample, as AudioEffectCapture gives them) to mono.
static func to_mono(frames: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames.size())
	for i in frames.size():
		out[i] = (frames[i].x + frames[i].y) * 0.5
	return out


## Mono samples to the stereo frames an AudioStreamGenerator takes.
static func to_stereo(samples: PackedFloat32Array, gain := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(samples.size())
	for i in samples.size():
		var v := samples[i] * gain
		out[i] = Vector2(v, v)
	return out


## Peak level of some samples (0..1), for the talking meter.
static func level(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for x in samples:
		p = maxf(p, absf(x))
	return p
