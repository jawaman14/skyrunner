extends TestCase
## The voice chat node (headless: no microphone, no speaker, but everything that is logic): framing what the mic hears,
## hearing talkers, the roster, mutes, a talker who goes quiet, the settings on disk.

const TMP := "user://zz_voice_test.cfg"


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func after_each() -> void:
	DirAccess.remove_absolute(TMP)


func _tone(n: int, hz := 600.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = 0.5 * sin(TAU * hz * float(i) / VoiceCodec.RATE)
	return a


func _chat() -> VoiceChat:
	var v := VoiceChat.new()
	_tree().root.add_child(v)
	v.settings = VoiceSettings.new()
	return v


func _frame_msg(id: String, name: String, q := 0.9, kind := "net", end := false) -> Dictionary:
	return {"t": "voice", "from": name, "id": id, "role": Roles.PILOT, "ch": "net", "s": 1, "q": q, "k": kind,
		"d": "" if end else VoiceCodec.pack(_tone(VoiceCodec.FRAME_N)), "end": end}


# ------------------------------------------------------------------ the capture side
func test_the_microphone_is_cut_into_forty_millisecond_frames() -> void:
	var c := VoiceCapture.new()
	var out := c.push(_tone(4800, 440.0), 48000.0)  # 100 ms at 48 kHz
	check_eq(out.size(), 2, "100 ms is two whole frames")
	check_eq(out[0].size(), VoiceCodec.FRAME_N, "of 320 samples at 8 kHz")
	check_eq(c.carry.size(), 800 - 640, "and 20 ms waits for the next push")
	out = c.push(_tone(4800, 440.0), 48000.0)
	check_eq(out.size(), 3, "the leftover and 100 more make three")
	check(c.level > 0.4, "the meter reads the peak (%.2f)" % c.level)
	c.reset()
	check(c.carry.is_empty() and c.level == 0.0, "letting go drops the stub")
	c.gain = 0.5
	var quiet := c.push(_tone(4800, 440.0), 48000.0)
	check(RadioVoice.rms(quiet[0]) < 0.25 and RadioVoice.rms(quiet[0]) > 0.05, "the input volume scales it (%.2f)" % RadioVoice.rms(quiet[0]))
	c.gain = 8.0
	check(VoiceCodec.level(c.push(_tone(4800, 440.0), 48000.0)[0]) <= 1.0, "and never clips past full scale")
	check_eq(VoiceCapture.new().push(PackedFloat32Array(), 44100.0).size(), 0, "silence in, no frames out")


# ------------------------------------------------------------------ the listening side
func test_a_talker_appears_in_the_roster_and_leaves_with_the_key() -> void:
	var v := _chat()
	var changes := []
	v.talker_changed.connect(func(): changes.append(1))
	v.hear(_frame_msg("tok-a", "Sam", 0.8))
	check_eq(v.talkers().size(), 1, "Sam is talking")
	var t: Dictionary = v.talkers()[0]
	check_eq(t.name, "Sam", "named")
	check_eq(t.role, Roles.PILOT, "with his seat")
	check_near(t.q, 0.8, 0.001, "and the quality he arrives at")
	check_eq(changes.size(), 1, "the roster is told once")
	v.hear(_frame_msg("tok-a", "Sam", 0.7))
	check_eq(changes.size(), 1, "and not again on every frame")
	v.hear(_frame_msg("tok-b", "Law", 0.5, "intercept"))
	check_eq(v.talkers().size(), 2, "two talkers at once")
	check_eq(v.talkers()[0].id, "tok-b", "newest first")
	v.hear(_frame_msg("tok-a", "Sam", 0.7, "net", true))
	check_eq(v.talkers().map(func(x): return x.id), ["tok-b"], "the end marker takes Sam off")
	check(v.talking.has("tok-b") and not v.talking.has("tok-a"), "and only him")
	v.queue_free()


func test_a_talker_who_goes_quiet_without_the_end_marker_is_let_go() -> void:
	var v := _chat()
	v.hear(_frame_msg("tok-a", "Sam"))
	check_eq(v.talkers().size(), 1, "talking")
	v._speakers["tok-a"].last = v._now() - VoiceChat.TIMEOUT_S - 0.1
	v._tick_speakers()
	check(v.talkers().is_empty(), "a dropped connection does not leave a ghost on the roster")
	v.queue_free()


func test_muted_talkers_are_not_heard_and_the_effect_setting_reaches_the_voice() -> void:
	var v := _chat()
	v.settings.set_muted("tok-a", true)
	v.hear(_frame_msg("tok-a", "Sam"))
	check(v.talkers().is_empty(), "a muted talker is not on the roster and makes no sound")
	v.settings.set_muted("tok-a", false)
	v.settings.effect = 0.3
	v.hear(_frame_msg("tok-a", "Sam"))
	check_near(v._speakers["tok-a"].rv.strength, 0.3, 0.0001, "the effect strength slider reaches the radio voice")
	v.settings.enabled = false
	v.hear(_frame_msg("tok-z", "Zed"))
	check(not v.talking.has("tok-z"), "with voice chat off nothing is heard")
	v.queue_free()


func test_what_the_law_cannot_read_arrives_scrambled() -> void:
	var v := _chat()
	v.hear(_frame_msg("tok-a", "Sam", 0.8, "scrambled"))
	check(v._speakers["tok-a"].scrambled, "an encrypted net is flagged scrambled")
	check_eq(v.talkers()[0].kind, "scrambled", "and the roster says so")
	v.hear(_frame_msg("tok-b", "Lee", 0.8, "intercept"))
	check(not v._speakers["tok-b"].scrambled, "an intercept in the clear is not")
	v.queue_free()


func test_without_a_microphone_it_is_a_listener_only() -> void:
	var v := _chat()
	check(not v.has_mic(), "headless: no microphone")
	v._tick_capture()
	check(not v.transmitting, "nothing to transmit")
	v.set_loopback(true)
	check(not v.loopback, "and no loopback test either")
	v.queue_free()


# ------------------------------------------------------------------ settings and the wire
func test_the_settings_survive_a_restart() -> void:
	var s := VoiceSettings.new()
	s.enabled = false
	s.ptt_key = KEY_F5
	s.device = "USB Headset"
	s.in_gain = 1.5
	s.out_volume = 0.6
	s.effect = 0.25
	s.set_muted("tok-x", true)
	s.save(TMP)
	var r := VoiceSettings.load_from(TMP)
	check(not r.enabled, "enabled")
	check_eq(r.ptt_key, KEY_F5, "the key")
	check_eq(r.device, "USB Headset", "the device")
	check_near(r.in_gain, 1.5, 0.001, "the input volume")
	check_near(r.out_volume, 0.6, 0.001, "the output volume")
	check_near(r.effect, 0.25, 0.001, "the effect strength")
	check(r.is_muted("tok-x") and not r.is_muted("tok-y"), "who is muted")
	check_eq(r.key_name(), "F5", "the key's name")
	check_eq(VoiceSettings.load_from("user://zz_nothing.cfg").ptt_key, VoiceSettings.DEFAULT_PTT, "defaults when there is no file")
	var wild := ConfigFile.new()
	wild.set_value("voice", "in_gain", 99.0)
	wild.set_value("voice", "effect", -4.0)
	wild.save(TMP)
	var c := VoiceSettings.load_from(TMP)
	check(c.in_gain <= 4.0 and c.effect >= 0.0, "a wild config is clamped")


func test_a_client_sends_voice_and_a_host_sends_its_own() -> void:
	var link := NetClient.new()
	var v := VoiceChat.new()
	_tree().root.add_child(v)
	v.settings = VoiceSettings.new()
	v.link = link
	v.channel = "net"
	v._send("abc", false)
	check_eq(v.seq, 1, "frames are numbered")
	v._send("", true)
	check_eq(v.seq, 2, "the key coming up is a frame too")
	v.link = null
	var h := HostServer.new()
	var s := Session.new({"seed": 5, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	h.sess = s
	h.host_role = Roles.BOSS
	v.server = h
	var heard := []
	h.voice_heard.connect(func(m): heard.append(m))
	v._send("abc", false)  # the boss talking on the net: nobody else is there to hear him
	check_eq(heard.size(), 0, "the host does not hear itself")
	h.free()
	s.dispose()
	v.queue_free()
	link.free()


# ------------------------------------------------------------------ over real sockets
var _sess: Session
var _srv: HostServer
var _links: Array = []


func _loopback_game() -> void:
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES, "agency": true})
	_srv = HostServer.new()
	_srv.attach(_sess)
	_srv.start(0, Roles.VERSUS, "127.0.0.1")


func _end_loopback() -> void:
	for c in _links:
		c.close()
		c.free()
	_links.clear()
	_srv.stop()
	_srv.free()
	_sess.dispose()


func _pump_until(cond: Callable, secs := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		_srv._process(0.0)
		for c in _links:
			c.poll()
		_srv.pump(_sess)
		_sess.update(1.0 / 60)
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func test_voice_crosses_real_sockets_by_the_radios_rules() -> void:
	_loopback_game()
	var pilot := NetClient.new().open("127.0.0.1", _srv.port, "Sam", Roles.COPILOT)
	var ctl := NetClient.new().open("127.0.0.1", _srv.port, "Law", Roles.CONTROLLER)
	_links.append(pilot)
	_links.append(ctl)
	check(_pump_until(func(): return pilot.welcome != null and ctl.welcome != null), "both seated")
	var at_boss := []
	var at_ctl := []
	_srv.voice_heard.connect(func(m): at_boss.append(m))
	ctl.voice_heard.connect(func(m): at_ctl.append(m))
	var frame := VoiceCodec.pack(_tone(VoiceCodec.FRAME_N))
	pilot.send_voice("net", 1, frame, false)
	check(_pump_until(func(): return at_boss.size() >= 1), "the host's pilot hears the co-pilot's frame over TCP")
	check_eq(at_boss[0].from, "Sam", "from Sam")
	check_eq(at_boss[0].role, Roles.COPILOT, "in the co-pilot's seat")
	check_eq(at_boss[0].d, frame, "the same audio")
	check_eq(at_ctl.size(), 0, "the law, with no intercept, hears nothing of the runners' net")
	pilot.send_voice("all", 2, frame, false)
	check(_pump_until(func(): return at_ctl.size() >= 1), "but the table channel reaches the controller")
	check_eq(at_ctl[0].k, "all", "as table talk")
	_sess.upgrades["law"]["intercept"] = true
	pilot.send_voice("net", 3, frame, false)
	check(_pump_until(func(): return at_ctl.size() >= 2), "after the intercept upgrade the law hears the net too")
	check_eq(at_ctl[1].k, "intercept", "as an intercept")
	check(float(at_ctl[1].q) <= VoiceRouter.INTERCEPT_FACTOR + 0.001, "at a lower quality than the crew (%.2f)" % float(at_ctl[1].q))
	var n := at_ctl.size()
	pilot.send_voice("net", 4, "", true)
	check(_pump_until(func(): return at_ctl.size() > n and at_ctl.back().end), "the end marker follows")
	_end_loopback()


func test_a_client_cannot_send_voice_for_a_seat_it_does_not_hold() -> void:
	_loopback_game()
	var lobby := NetClient.new().open("127.0.0.1", _srv.port, "Zed", "")
	_links.append(lobby)
	check(_pump_until(func(): return lobby.welcome != null), "joined with no seat")
	var heard := []
	_srv.voice_heard.connect(func(m): heard.append(m))
	var frame := VoiceCodec.pack(_tone(VoiceCodec.FRAME_N))
	lobby.send_voice("net", 1, frame, false)
	_pump_until(func(): return false, 0.3)
	check_eq(heard.size(), 0, "an unseated player has no net to talk on")
	lobby.send_voice("all", 2, frame, false)
	check(_pump_until(func(): return heard.size() >= 1), "but can speak to the table")
	check_eq(heard[0].role, "", "as a player with no seat")
	_end_loopback()
