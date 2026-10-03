class_name VoiceChat
extends Node
## Voice chat that works like a radio. Hold the push-to-talk key (` by default) to talk on your side's net, SHIFT + ` for the
## whole table; everyone the radio's rules let hear you (VoiceRouter, on the host) gets 40 ms frames of 8 kHz mu-law over
## the host connection the seats already use, and hears you through a radio: a telephone band, hiss that grows with
## distance, dropouts at the edge of range, a squelch click as you key up and a burst of noise as you let go. What the other
## side picks up of you (the law's intercept; a runner's scanner on the police net) is scrambled when it is encrypted.
##
## One node per game: `attach_host(server)` on the machine that hosts (it is also a player), `attach_client(link)` for a
## remote seat. Microphone capture needs the project's audio input switched on (project.godot, audio/driver/enable_input)
## and a device; without one this is a listener only.

const BUS := "VoiceCapture"
const TIMEOUT_S := 0.6  ## a talker who has sent nothing for this long has let go
const BUFFER_S := 0.5

signal talker_changed  ## somebody started or stopped talking (the roster redraws)

var settings := VoiceSettings.new()
var server: HostServer = null
var link = null  ## NetClient
var capture := VoiceCapture.new()
var transmitting := false
var channel := "net"
var seq := 0
var loopback := false  ## the settings' test: hear yourself through the radio
var talking := {}  ## talker id -> {name, role, ch, q, kind, t (when last heard), my: false}
var _effect: AudioEffectCapture = null
var _mic: AudioStreamPlayer = null
var _speakers := {}  ## talker id -> Speaker
var _loop_speaker: Speaker = null
var _heard := 0  ## frames heard so far (orders the roster: newest first)


class Speaker:
	var id := ""
	var rv: RadioVoice
	var player: AudioStreamPlayer
	var playback: AudioStreamGeneratorPlayback = null
	var last := -99.0  ## wall-clock time of the last frame
	var open := false  ## the squelch is open (a transmission is on)
	var scrambled := false


func attach_host(srv: HostServer) -> VoiceChat:
	server = srv
	server.voice_heard.connect(hear)
	_start()
	return self


func attach_client(l) -> VoiceChat:
	link = l
	link.voice_heard.connect(hear)
	_start()
	return self


func _start() -> void:
	name = "voice_chat"
	settings = VoiceSettings.load_from()
	if not settings.enabled or DisplayServer.get_name() == "headless":
		return
	if ProjectSettings.get_setting("audio/driver/enable_input", false) and AudioServer.get_input_device_list().size() > 0:
		_open_mic()


## The microphone: a muted bus with a capture effect, fed by a microphone stream.
func _open_mic() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_mute(i, true)  # (the capture still sees it; nobody hears their own mic through the speakers)
		AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	_effect = AudioServer.get_bus_effect(i, 0) as AudioEffectCapture
	if settings.device != "":
		AudioServer.input_device = settings.device
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = BUS
	add_child(_mic)
	_mic.play()


func has_mic() -> bool:
	return _effect != null


## The microphones the system offers (the settings screen's list).
static func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func use_device(d: String) -> void:
	settings.device = d
	settings.save()
	if _effect != null:
		AudioServer.input_device = d


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_dt: float) -> void:
	_tick_capture()
	_tick_speakers()


# ------------------------------------------------------------------ talking
func ptt_down() -> bool:
	return settings.enabled and Input.is_physical_key_pressed(settings.ptt_key)


## Pull what the microphone heard, frame it, send it (or, if the key is up, throw it away).
func _tick_capture() -> void:
	if _effect == null:
		return
	var avail := _effect.get_frames_available()
	var pressed := ptt_down()
	if avail > 0:
		var frames := _effect.get_buffer(avail)
		if pressed or loopback:
			capture.gain = settings.in_gain
			for f in capture.push(VoiceCodec.to_mono(frames), AudioServer.get_mix_rate()):
				_emit_frame(f)
	if pressed and not transmitting:
		transmitting = true
		channel = "all" if Input.is_physical_key_pressed(KEY_SHIFT) else "net"
		seq = 0
		talker_changed.emit()
	elif not pressed and transmitting:
		transmitting = false
		_send("", true)  # the key is up
		capture.reset()
		talker_changed.emit()


func _emit_frame(f: PackedFloat32Array) -> void:
	if transmitting:
		_send(VoiceCodec.pack(f), false)
	if loopback:
		_play(_loopback_speaker(), VoiceCodec.unpack(VoiceCodec.pack(f)), 0.7, false)


func _send(d: String, end: bool) -> void:
	seq += 1
	if server != null:
		server.host_voice(channel, seq, d, end)
	elif link != null:
		link.send_voice(channel, seq, d, end)


# ------------------------------------------------------------------ hearing
## A frame as the host routed it: {from, id, role, ch, s, q, k, d, end}.
func hear(msg: Dictionary) -> void:
	var id := str(msg.get("id", ""))
	if not settings.enabled or settings.is_muted(id):
		return
	var sp := _speaker(id)
	var kind := str(msg.get("k", "net"))
	_heard += 1
	var first := not sp.open
	if bool(msg.get("end", false)):
		_close(sp)
		talking.erase(id)
		talker_changed.emit()
		return
	sp.rv.strength = settings.effect
	sp.scrambled = kind == "scrambled"
	if first:
		sp.open = true
		_push(sp, sp.rv.squelch_open(), 8000.0)
	talking[id] = {"name": str(msg.get("from", "")), "role": str(msg.get("role", "")), "ch": str(msg.get("ch", "net")),
		"q": float(msg.get("q", 1.0)), "kind": kind, "t": _now(), "n": _heard}
	if first:
		talker_changed.emit()
	var frame := VoiceCodec.unpack(str(msg.get("d", "")))
	_play(sp, frame, float(msg.get("q", 1.0)), sp.scrambled)


func _speaker(id: String) -> Speaker:
	if _speakers.has(id):
		return _speakers[id]
	var sp := Speaker.new()
	sp.id = id
	sp.rv = RadioVoice.new(hash(id))
	sp.player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = AudioServer.get_mix_rate()
	gen.buffer_length = BUFFER_S
	sp.player.stream = gen
	add_child(sp.player)
	if DisplayServer.get_name() != "headless":
		sp.player.play()
		sp.playback = sp.player.get_stream_playback() as AudioStreamGeneratorPlayback
	_speakers[id] = sp
	return sp


func _loopback_speaker() -> Speaker:
	if _loop_speaker == null:
		_loop_speaker = _speaker("loopback")
		_loop_speaker.rv.strength = settings.effect
	return _loop_speaker


func _play(sp: Speaker, frame: PackedFloat32Array, q: float, scrambled: bool) -> void:
	sp.last = _now()
	_push(sp, sp.rv.process(frame, q, scrambled), float(VoiceCodec.RATE))


## Radio-processed samples at `rate` to the speaker (resampled to the mixer's rate, at the output volume).
func _push(sp: Speaker, samples: PackedFloat32Array, rate: float) -> void:
	if sp.playback == null:
		return
	var wide := VoiceCodec.resample(samples, rate, AudioServer.get_mix_rate())
	var room := sp.playback.get_frames_available()
	if room < wide.size():
		wide = wide.slice(0, room)
	sp.playback.push_buffer(VoiceCodec.to_stereo(wide, settings.out_volume))


func _close(sp: Speaker) -> void:
	if sp.open:
		sp.open = false
		_push(sp, sp.rv.squelch_close(), 8000.0)


## A talker who has gone quiet without the end marker (a dropped connection) is let go.
func _tick_speakers() -> void:
	var now := _now()
	var changed := false
	for id in talking.keys():
		var sp: Speaker = _speakers.get(id)
		if sp != null and now - sp.last > TIMEOUT_S:
			_close(sp)
			talking.erase(id)
			changed = true
	if changed:
		talker_changed.emit()


## Who is talking now, for the roster: [{id, name, role, ch, q, kind}], newest first.
func talkers() -> Array:
	var out := []
	for id in talking:
		var t: Dictionary = talking[id].duplicate()
		t["id"] = id
		out.append(t)
	out.sort_custom(func(a, b): return a.n > b.n)
	return out


## The settings' test: hear yourself as the radio would play you.
func set_loopback(on: bool) -> void:
	loopback = on and has_mic()
	if not loopback and _loop_speaker != null:
		_close(_loop_speaker)


## The mic's peak level since the last frame (0..1), for the meter.
func level() -> float:
	return capture.level
