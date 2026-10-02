class_name CarRadio
extends Node
## The car's radio: real broadcasts from the game's years (1979-86) and the stations around the island - Miami's
## FM and AM, Jamaica, Colombia, Antigua, the Turks & Caicos, Haiti, the Dominican Republic, Nicaragua, Cuba -
## recorded off the air by listeners and kept on the Internet Archive (assets/radio/README.md says which, and the
## licence position). A station is ALWAYS ON AIR: where it is in its programme is a function of the sim clock, so
## tuning away and back, or driving for ten minutes, finds it further along - never at the start. Short
## recordings play, then a stretch of static (the signal fading) and play again.
##
## Your own: every folder in user://radio/ is a station - drop .ogg / .mp3 / .wav files in it (an optional
## station.json names it: {"name", "band": "FM"|"AM"|"SW", "label": "101.5", "blurb", "gap_s"}), and loose files
## in user://radio/ itself are "My tapes". Nothing there is ever part of the repo.
##
## In the car: R radio on / off, , and . (or [ and ]) tune. Out of the car the radio is silent.

const SHIPPED := "res://assets/radio"
const USER_DIR := "user://radio"
const STATE := "user://radio_state.cfg"
const BAND_ORDER := {"FM": 0, "AM": 1, "SW": 2}
const HISS_DB := {"FM": -48.0, "AM": -36.0, "SW": -27.0}
const GAP_HISS_DB := -14.0  ## between items the signal is gone: mostly static
const TUNING_HISS_DB := -8.0
const VOICE_DB := -4.0
const RETUNE_S := 0.45  ## the burst of static as the dial moves
const RESYNC_S := 1.5  ## the player may drift this far from "the air" before it is put back


class Clip:
	var path := ""
	var title := ""
	var dur := 0.0
	var source := ""  ## the Internet Archive item it came from (shipped clips)


class Station:
	var id := ""
	var name := ""
	var band := "FM"
	var label := ""  ## "100.7" (MHz on FM, kHz on AM and shortwave)
	var blurb := ""
	var gap_s := 0.0  ## the static after each clip
	var clips: Array = []
	var user := false

	## Where this station is at sim time t: {i: clip index or -1 in a gap, off: seconds into the clip}.
	func air(t: float) -> Dictionary:
		return CarRadio.air_position(clips.map(func(c): return (c as Clip).dur), gap_s, t + phase())

	## Each station starts its day somewhere else.
	func phase() -> float:
		return float(absi(id.hash()) % 3600)

	func dial() -> String:
		return ("%s %s" % [band, label]).strip_edges()


var app = null  ## PilotApp (for the sim clock and the message line)
var stations: Array = []
var idx := 0
var on := false  ## the knob
var active := false  ## in the car (out of it the radio is silent)
var voice: AudioStreamPlayer
var hiss: AudioStreamPlayer
var _clip: Clip = null
var _retune := 0.0
var state_path := STATE  ## where the knob and the dial are remembered
var _streams := {}  ## path -> AudioStream


func setup(app_) -> CarRadio:
	app = app_
	name = "car_radio"
	voice = AudioStreamPlayer.new()
	voice.volume_db = VOICE_DB
	add_child(voice)
	hiss = AudioStreamPlayer.new()
	hiss.stream = Soundscape.noise_loop("radio_hiss", 0.5)
	hiss.volume_db = -80.0
	add_child(hiss)
	scan()
	var cf := ConfigFile.new()
	if cf.load(state_path) == OK:
		var id := str(cf.get_value("radio", "station", ""))
		for i in stations.size():
			if (stations[i] as Station).id == id:
				idx = i
		on = bool(cf.get_value("radio", "on", false))
	return self


# ------------------------------------------------------------------ the air
## The place in a programme at time t: the clips (their lengths) each followed by gap seconds of static, round
## and round. {i: the clip, or -1 in the static, off: seconds into the clip, gap_left: seconds of static left}.
static func air_position(durs: Array, gap: float, t: float) -> Dictionary:
	var total := 0.0
	for d in durs:
		total += float(d) + gap
	if total <= 0.0:
		return {"i": -1, "off": 0.0, "gap_left": 0.0}
	var x := fposmod(t, total)
	for i in durs.size():
		var d: float = durs[i]
		if x < d:
			return {"i": i, "off": x, "gap_left": 0.0}
		x -= d
		if x < gap:
			return {"i": -1, "off": 0.0, "gap_left": gap - x}
		x -= gap
	return {"i": -1, "off": 0.0, "gap_left": 0.0}


func clock() -> float:
	if app != null and app.get("s") != null:
		return float(app.s.time)
	return Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------------ the dial
## Read the shipped dial and the player's folders.
func scan(user_dir := USER_DIR) -> void:
	stations = []
	var dial = _json("%s/dial.json" % SHIPPED)
	if dial is Dictionary:
		for id in dial.get("stations", []):
			var st := _read_shipped(str(id))
			if st != null:
				stations.append(st)
	for st in _read_user(user_dir):
		stations.append(st)
	stations.sort_custom(func(a, b): return _key(a) < _key(b))
	idx = clampi(idx, 0, maxi(0, stations.size() - 1))


static func _key(st: Station) -> String:
	var n := float(st.label) if st.label.is_valid_float() else 1e9
	return "%d-%010.2f-%s" % [BAND_ORDER.get(st.band, 3), n, st.name]


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _read_shipped(id: String) -> Station:
	var dir := "%s/%s" % [SHIPPED, id]
	var m = _json(dir + "/station.json")
	if not m is Dictionary:
		return null
	var st := _station_from(id, m, false)
	for c in m.get("clips", []):
		var clip := Clip.new()
		clip.path = "%s/%s" % [dir, str(c.get("file", ""))]
		clip.title = str(c.get("title", ""))
		clip.dur = float(c.get("len", 0.0))
		clip.source = str(c.get("ia", ""))
		if clip.dur > 0.0 and ResourceLoader.exists(clip.path):
			st.clips.append(clip)
	return st if not st.clips.is_empty() else null


static func _station_from(id: String, m: Dictionary, user: bool) -> Station:
	var st := Station.new()
	st.id = ("user:" if user else "") + id
	st.name = str(m.get("name", id.replace("_", " ").capitalize()))
	st.band = str(m.get("band", "FM")).to_upper()
	if not BAND_ORDER.has(st.band):
		st.band = "FM"
	st.label = str(m.get("label", ""))
	st.blurb = str(m.get("blurb", ""))
	st.gap_s = float(m.get("gap_s", 0.0))
	st.user = user
	return st


## user://radio/<folder>/ is a station, the loose files in user://radio/ are "My tapes".
static func _read_user(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var loose: Array = _audio_in(dir)
	if not loose.is_empty():
		var st := _station_from("my_tapes", {"name": "My tapes", "band": "FM", "blurb": "Whatever is in the radio folder."}, true)
		st.clips = loose
		out.append(st)
	var subs: Array = Array(d.get_directories())
	subs.sort()
	for sub in subs:
		var clips: Array = _audio_in("%s/%s" % [dir, sub])
		if clips.is_empty():
			continue
		var m: Variant = _json("%s/%s/station.json" % [dir, sub])
		var st := _station_from(str(sub), m if m is Dictionary else {}, true)
		st.clips = clips
		out.append(st)
	return out


static func _audio_in(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files: Array = Array(d.get_files())
	files.sort()
	for f in files:
		if str(f).get_extension().to_lower() not in ["ogg", "mp3", "wav"]:
			continue
		var clip := Clip.new()
		clip.path = "%s/%s" % [dir, f]
		clip.title = str(f).get_basename().replace("_", " ")
		var stream := load_stream(clip.path)
		if stream == null:
			continue
		clip.dur = stream.get_length()
		if clip.dur > 0.0:
			out.append(clip)
	return out


## Any of the three formats, from res:// or from disk.
static func load_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path) as AudioStream
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(path)
			return m if m.data.size() > 0 else null
		"wav":
			return wav_from_bytes(FileAccess.get_file_as_bytes(path))
	return null


## 16-bit PCM only (what an editor exports by default).
static func wav_from_bytes(b: PackedByteArray) -> AudioStreamWAV:
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos := 12
	var channels := 1
	var rate := 22050
	var bits := 16
	var pcm := false
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var tag := b.slice(pos, pos + 4).get_string_from_ascii()
		var n: int = b.decode_u32(pos + 4)
		var body := pos + 8
		if tag == "fmt " and body + 16 <= b.size():
			pcm = b.decode_u16(body) == 1
			channels = b.decode_u16(body + 2)
			rate = b.decode_u32(body + 4)
			bits = b.decode_u16(body + 14)
		elif tag == "data":
			data = b.slice(body, mini(body + n, b.size()))
		pos = body + n + (n & 1)
	if not pcm or bits != 16 or data.is_empty() or channels < 1 or channels > 2:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = channels == 2
	w.mix_rate = rate
	w.data = data
	return w


# ------------------------------------------------------------------ the knobs
func station() -> Station:
	return stations[idx] if idx < stations.size() else null


func power(v: bool) -> void:
	on = v
	_clip = null
	_retune = RETUNE_S
	if not on:
		voice.stop()
		hiss.stop()
	_save()


## Move the dial: step +1 is the next station up (wrapping), -1 the one below.
func tune(step: int) -> void:
	if stations.is_empty():
		return
	idx = posmod(idx + step, stations.size())
	_clip = null
	_retune = RETUNE_S
	voice.stop()
	_save()


func _save() -> void:
	var st := station()
	var cf := ConfigFile.new()
	cf.set_value("radio", "station", st.id if st != null else "")
	cf.set_value("radio", "on", on)
	cf.save(state_path)


## What the dial says: the band and frequency, the station, and what is on now.
func line() -> String:
	var st := station()
	if st == null:
		return "The radio has nothing to tune: no stations."
	if not on:
		return "Radio off."
	var a := st.air(clock())
	var now := "static" if int(a.i) < 0 else (st.clips[int(a.i)] as Clip).title
	return "%s  %s  -  %s" % [st.dial(), st.name, now]


# ------------------------------------------------------------------ playing
func _process(dt: float) -> void:
	var st := station()
	if st == null or not on or not active:
		if voice.playing:
			voice.stop()
		if hiss.playing:
			hiss.stop()
		return
	if not hiss.playing:
		hiss.play()
	if _retune > 0.0:
		_retune -= dt
		hiss.volume_db = TUNING_HISS_DB
		return
	var a := st.air(clock())
	var i: int = a.i
	if i < 0:
		voice.stop()
		_clip = null
		hiss.volume_db = GAP_HISS_DB
		return
	hiss.volume_db = HISS_DB.get(st.band, -30.0)
	var clip: Clip = st.clips[i]
	if clip != _clip or not voice.playing or absf(voice.get_playback_position() - float(a.off)) > RESYNC_S:
		_clip = clip
		voice.stream = _stream_of(clip)
		if voice.stream != null:
			voice.play(float(a.off))


func _stream_of(clip: Clip) -> AudioStream:
	if not _streams.has(clip.path):
		_streams[clip.path] = load_stream(clip.path)
	return _streams[clip.path]
