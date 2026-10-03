class_name VoiceSettings
extends RefCounted
## The player's voice chat settings, kept in user://voice.cfg (never part of a save or a game: they are the person's, not
## the table's).

const PATH := "user://voice.cfg"
const DEFAULT_PTT := KEY_QUOTELEFT  ## the key under escape: ` held to talk on the net, SHIFT + ` to the whole table

var enabled := true
var ptt_key := DEFAULT_PTT
var device := ""  ## the microphone ("" = the system's default)
var in_gain := 1.0
var out_volume := 1.0
var effect := 1.0  ## 0 = clean voice, 1 = the full radio treatment
var muted: Array = []  ## talker ids (their seat tokens) you do not want to hear


static func load_from(path := PATH) -> VoiceSettings:
	var v := VoiceSettings.new()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return v
	v.enabled = bool(cf.get_value("voice", "enabled", true))
	v.ptt_key = int(cf.get_value("voice", "ptt_key", DEFAULT_PTT))
	v.device = str(cf.get_value("voice", "device", ""))
	v.in_gain = clampf(float(cf.get_value("voice", "in_gain", 1.0)), 0.0, 4.0)
	v.out_volume = clampf(float(cf.get_value("voice", "out_volume", 1.0)), 0.0, 2.0)
	v.effect = clampf(float(cf.get_value("voice", "effect", 1.0)), 0.0, 1.0)
	var m = cf.get_value("voice", "muted", [])
	if m is Array:
		for x in m:
			v.muted.append(str(x))
	return v


func save(path := PATH) -> void:
	var cf := ConfigFile.new()
	cf.set_value("voice", "enabled", enabled)
	cf.set_value("voice", "ptt_key", ptt_key)
	cf.set_value("voice", "device", device)
	cf.set_value("voice", "in_gain", in_gain)
	cf.set_value("voice", "out_volume", out_volume)
	cf.set_value("voice", "effect", effect)
	cf.set_value("voice", "muted", muted)
	cf.save(path)


func is_muted(id: String) -> bool:
	return id in muted


func set_muted(id: String, on: bool) -> void:
	if on and not (id in muted):
		muted.append(id)
	elif not on:
		muted.erase(id)


## What the key is called on the screen.
func key_name() -> String:
	if ptt_key == KEY_QUOTELEFT:
		return "` (the key under ESC)"
	return OS.get_keycode_string(ptt_key)
