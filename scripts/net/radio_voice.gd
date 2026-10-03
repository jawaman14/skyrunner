class_name RadioVoice
extends RefCounted
## What a voice sounds like once it has been through a radio (8 kHz frames in, 8 kHz frames out): a telephone-band
## filter (300 Hz to 2.8 kHz), a little crunch, hiss that grows as the signal weakens, dropouts when it is nearly
## gone, a squelch click when the key goes down and a burst of noise as it goes up. A scrambled transmission (what
## an encrypted net sounds like to someone who is not meant to hear it) is spectrally inverted: the same band, turned
## upside down, so it has the rhythm of speech and none of the words.
##
## One RadioVoice per talker heard (its filters keep state between frames). Pure functions on arrays: tested without a
## speaker.

const RATE := 8000
const HP_HZ := 300.0
const LP_HZ := 2800.0
const DRIVE := 1.6  ## the crunch: tanh(DRIVE x) / tanh(DRIVE)

var strength := 1.0  ## 0 clean voice ... 1 the full radio treatment (the audio settings' slider)
var _hp := Biquad.new()
var _lp := Biquad.new()
var _rng := RandomNumberGenerator.new()
var _n := 0  ## samples so far (the sign flip of a scrambled voice must run on across frames)
var _dead := 0  ## samples of dropout still to go
var drops := 0  ## dropouts so far (for the tests)


class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var z1 := 0.0
	var z2 := 0.0

	## RBJ cookbook filters: kind "hp" or "lp".
	static func make(kind: String, fc: float, rate: float, q := 0.707) -> Biquad:
		var f := Biquad.new()
		var w := TAU * fc / rate
		var cw := cos(w)
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		if kind == "hp":
			f.b0 = (1.0 + cw) / 2.0 / a0
			f.b1 = -(1.0 + cw) / a0
			f.b2 = (1.0 + cw) / 2.0 / a0
		else:
			f.b0 = (1.0 - cw) / 2.0 / a0
			f.b1 = (1.0 - cw) / a0
			f.b2 = (1.0 - cw) / 2.0 / a0
		f.a1 = -2.0 * cw / a0
		f.a2 = (1.0 - alpha) / a0
		return f

	func copy_from(o: Biquad) -> void:
		b0 = o.b0
		b1 = o.b1
		b2 = o.b2
		a1 = o.a1
		a2 = o.a2

	func run(x: float) -> float:
		var y := b0 * x + z1
		z1 = b1 * x - a1 * y + z2
		z2 = b2 * x - a2 * y
		return y


func _init(seed_ := 1) -> void:
	_hp.copy_from(Biquad.make("hp", HP_HZ, RATE))
	_lp.copy_from(Biquad.make("lp", LP_HZ, RATE))
	_rng.seed = seed_


## One 8 kHz frame as heard at signal quality `q` (1 strong, towards 0 weak). `scrambled`: spectrally inverted and noisy.
func process(frame: PackedFloat32Array, q: float, scrambled := false) -> PackedFloat32Array:
	if strength <= 0.001 and not scrambled:
		return frame.duplicate()  # the radio effect is off: the voice as it came
	var out := PackedFloat32Array()
	out.resize(frame.size())
	var qq := clampf(q, 0.0, 1.0)
	var hiss := pow(1.0 - qq, 1.3) * 0.45 * strength + (0.02 * strength)
	var gain := lerpf(1.0, 0.3 + 0.7 * qq, strength)
	var dropout_p := clampf((0.3 - qq) * 0.5, 0.0, 0.15) * strength  # chance a 10 ms chunk drops, per chunk
	var chunk := RATE / 100
	var norm := tanh(DRIVE)
	for i in frame.size():
		if i % chunk == 0 and _dead <= 0 and _rng.randf() < dropout_p:
			_dead = chunk
			drops += 1
		var x := frame[i]
		if scrambled:
			x = x * (1.0 if (_n & 1) == 0 else -1.0)
		x = _lp.run(_hp.run(x))
		x = lerpf(x, tanh(DRIVE * x) / norm, strength)
		x *= gain
		if _dead > 0:
			x *= 0.04
			_dead -= 1
		var noise := (_rng.randf() * 2.0 - 1.0) * hiss
		out[i] = clampf(x + noise, -1.0, 1.0)
		_n += 1
	return out


## The click as the other end keys up: a short, sharp burst.
func squelch_open() -> PackedFloat32Array:
	var n := int(RATE * 0.03)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var env := exp(-float(i) / (RATE * 0.006))
		out[i] = (_rng.randf() * 2.0 - 1.0) * 0.5 * env * strength
	return out


## The squelch tail as the other end lets go: a burst of noise that dies away (and the carrier is gone).
func squelch_close() -> PackedFloat32Array:
	var n := int(RATE * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var env := exp(-float(i) / (RATE * 0.035))
		out[i] = (_rng.randf() * 2.0 - 1.0) * 0.4 * env * strength
	return out


## RMS of a frame (for tests and meters).
static func rms(frame: PackedFloat32Array) -> float:
	if frame.is_empty():
		return 0.0
	var s := 0.0
	for x in frame:
		s += x * x
	return sqrt(s / float(frame.size()))
