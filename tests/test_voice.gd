extends TestCase
## Voice chat that works like radio: the codec, the radio sound, who hears whom (and how well), and the host relaying
## frames and giving the DF stations their bearing.


func after_each() -> void:
	World.use_map(0)
	RadioNet.REALISM = true


func _tone(hz: float, n := 800, amp := 0.6) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = amp * sin(TAU * hz * float(i) / VoiceCodec.RATE)
	return a


func _sess(opts := {}) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.update(1.0 / 30)
	return s


# ------------------------------------------------------------------ the codec
func test_mu_law_keeps_speech_and_fits_a_byte() -> void:
	var worst := 0.0
	for i in 200:
		var x := -1.0 + 2.0 * float(i) / 199.0
		worst = maxf(worst, absf(VoiceCodec.dec(VoiceCodec.enc(x)) - x))
	check(worst < 0.045, "every sample within 4.5 percent of full scale (%.3f)" % worst)
	check_eq(VoiceCodec.enc(0.0), 0, "silence is zero")
	check(VoiceCodec.enc(-0.5) & 0x80 != 0 and VoiceCodec.enc(0.5) & 0x80 == 0, "the sign is the top bit")
	var quiet := absf(VoiceCodec.dec(VoiceCodec.enc(0.01)) - 0.01)
	check(quiet < 0.003, "quiet sounds are kept finely (the point of companding): %.4f" % quiet)
	var f := _tone(440.0, VoiceCodec.FRAME_N)
	var b := VoiceCodec.encode(f)
	check_eq(b.size(), VoiceCodec.FRAME_N, "a 40 ms frame is 320 bytes")
	var back := VoiceCodec.decode(b)
	check_eq(back.size(), f.size(), "and comes back as many samples")
	check(RadioVoice.rms(back) > 0.3, "and still a tone")
	var s := VoiceCodec.pack(f)
	check(s.length() <= VoiceCodec.MAX_FRAME_B64, "as text it fits the limit (%d characters)" % s.length())
	check_eq(VoiceCodec.unpack(s).size(), 320, "and unpacks")
	check_eq(VoiceCodec.unpack("A".repeat(VoiceCodec.MAX_FRAME_B64 + 4)).size(), 0, "an over-long frame is refused")


func test_resampling_keeps_the_pitch_and_the_length() -> void:
	var tone := _tone(500.0, 4800)
	var down := VoiceCodec.resample(tone, 48000.0, 8000.0)
	check_eq(down.size(), 800, "48 kHz to 8 kHz: a sixth of the samples")
	check_eq(VoiceCodec.resample(down, 8000.0, 48000.0).size(), 4800, "and back up")
	check_eq(VoiceCodec.resample(PackedFloat32Array(), 44100.0, 8000.0).size(), 0, "nothing in, nothing out")
	var up := VoiceCodec.resample(_tone(300.0, 400), 8000.0, 16000.0)
	check_near(RadioVoice.rms(up), RadioVoice.rms(_tone(300.0, 400)), 0.05, "no level change going up")
	var st := VoiceCodec.to_stereo(PackedFloat32Array([0.5, -0.5]), 0.5)
	check_eq(st[0], Vector2(0.25, 0.25), "mono to stereo, with a gain")
	check_near(VoiceCodec.to_mono(PackedVector2Array([Vector2(0.2, 0.4)]))[0], 0.3, 0.0001, "and stereo to mono")
	check_near(VoiceCodec.level(PackedFloat32Array([0.1, -0.7, 0.3])), 0.7, 0.0001, "the meter reads the peak")


# ------------------------------------------------------------------ the radio sound
func _through(hz: float, q := 1.0, strength := 1.0) -> float:
	var rv := RadioVoice.new(3)
	rv.strength = strength
	var out := PackedFloat32Array()
	for k in 6:
		out.append_array(rv.process(_tone(hz, 320), q))
	return RadioVoice.rms(out.slice(640))  # past the filters settling


func test_a_radio_is_a_telephone_band() -> void:
	var mid := _through(1000.0)
	check(_through(60.0) < mid * 0.35, "the rumble below 300 Hz is cut (%.3f vs %.3f)" % [_through(60.0), mid])
	check(_through(3900.0) < mid * 0.35, "and the top above 2.8 kHz (%.3f)" % _through(3900.0))
	check(mid > 0.2, "the middle comes through (%.3f)" % mid)
	var clean := _through(60.0, 1.0, 0.0)
	check(clean > 0.3, "with the radio effect off the band is not cut (%.3f)" % clean)


func test_a_weak_signal_is_hissy_and_a_dead_one_drops_out() -> void:
	var silence := PackedFloat32Array()
	silence.resize(320)
	var strong := RadioVoice.rms(RadioVoice.new(5).process(silence, 1.0))
	var weak := RadioVoice.rms(RadioVoice.new(5).process(silence, 0.1))
	check(weak > strong * 3.0, "far away there is much more hiss than close (%.3f vs %.3f)" % [weak, strong])
	var tone := _tone(1000.0, 3200)
	var near := RadioVoice.new(9)
	near.process(tone, 1.0)
	var gone := RadioVoice.new(9)
	gone.process(tone, 0.0)
	check_eq(near.drops, 0, "a strong signal never drops out")
	check(gone.drops >= 2, "a nearly dead one does (%d dropouts in 40 chunks of 10 ms)" % gone.drops)


func test_a_scrambled_voice_has_no_words_and_the_squelch_clicks() -> void:
	var plain := RadioVoice.new(2)
	var scr := RadioVoice.new(2)
	var f := _tone(700.0, 320)
	var a := plain.process(f, 1.0)
	var b := scr.process(f, 1.0, true)
	var diff := 0.0
	for i in 320:
		diff += absf(a[i] - b[i])
	check(diff / 320.0 > 0.05, "scrambled is not the same sound (%.3f)" % (diff / 320.0))
	# a spectral inversion moves 700 Hz to 3300 Hz: past the low-pass, so it is mostly gone
	check(RadioVoice.rms(b.slice(160)) < RadioVoice.rms(a.slice(160)) * 0.5, "a 700 Hz tone is turned into one the radio's band cuts")
	check(plain.squelch_open().size() > 100 and plain.squelch_close().size() > plain.squelch_open().size(), "a click as the key goes down, a longer tail as it comes up")
	var tail := plain.squelch_close()
	check(RadioVoice.rms(tail.slice(0, 100)) > RadioVoice.rms(tail.slice(800)), "and the tail dies away")


# ------------------------------------------------------------------ who hears whom
func test_the_table_hears_everything_and_the_net_is_for_the_seated() -> void:
	var s := _sess()
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "all", "")[0], 1.0, "the table channel reaches a player with no seat, clear")
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "all", Roles.CONTROLLER)[1], "all", "and the other side")
	check_eq(VoiceRouter.hear(s, "", "net", Roles.PILOT)[0], 0.0, "nobody hears an unseated player on the net")
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "net", "")[0], 0.0, "an unseated player hears no net")
	s.dispose()


func test_the_runner_net_reaches_the_crew_by_the_radios_range() -> void:
	var s := _sess()
	var boss := VoiceRouter.hear(s, Roles.PILOT, "net", Roles.BOSS)
	check_eq(boss[1], "net", "pilot to boss is the net")
	check(float(boss[0]) > 0.0, "parked at the strip, the club is in range (%.2f)" % float(boss[0]))
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "net", Roles.COPILOT)[0], 1.0, "pilot to co-pilot: the same aircraft")
	check_eq(VoiceRouter.hear(s, Roles.SPOTTER, "net", Roles.BOSS)[0], VoiceRouter.NO_GEOMETRY_Q, "a seat with no place on the map is a flat 0.75")
	s.state.x = 60000.0
	s.state.on_ground = true
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "net", Roles.BOSS)[0], 0.0, "60 km away on the ground: not heard")
	s.state.on_ground = false
	s.state.alt = 4500.0
	var high: float = VoiceRouter.hear(s, Roles.PILOT, "net", Roles.BOSS)[0]
	check(high > 0.0, "but from 4,500 m the horizon is long enough to be heard (%.2f)" % high)
	s.dispose()


func test_quality_falls_with_distance() -> void:
	var s := _sess()
	s.state.on_ground = false
	var hq: Array = s.role_position(Roles.BOSS)
	s.state.alt = 3000.0
	s.state.x = float(hq[0]) + 3000.0
	s.state.y = float(hq[1])
	var near := VoiceRouter.link(s, Roles.PILOT, Roles.BOSS)
	s.state.x = float(hq[0]) + 90000.0
	var far := VoiceRouter.link(s, Roles.PILOT, Roles.BOSS)
	check(near > far, "closer is clearer (%.2f vs %.2f)" % [near, far])
	check(near > 0.8, "3 km out: nearly clear (%.2f)" % near)
	RadioNet.REALISM = false
	check_eq(VoiceRouter.link(s, Roles.PILOT, Roles.BOSS), 1.0, "with the realism off the radio just works")
	s.dispose()


func test_the_other_side_listens_in_only_with_the_counters() -> void:
	var s := _sess({"agency": true})
	check_eq(VoiceRouter.hear(s, Roles.PILOT, "net", Roles.CONTROLLER)[0], 0.0, "the law does not hear the runners by default")
	s.upgrades["law"]["intercept"] = true
	var h := VoiceRouter.hear(s, Roles.PILOT, "net", Roles.CONTROLLER)
	check_eq(h[1], "intercept", "with the intercept upgrade it does")
	check(float(h[0]) <= VoiceRouter.INTERCEPT_FACTOR + 0.001, "a little worse than the crew hears itself (%.2f)" % float(h[0]))
	check(s.features.has("scanner"), "the sandbox has the scanner")
	var p := VoiceRouter.hear(s, Roles.CONTROLLER, "net", Roles.PILOT)
	check_eq(p[1], "intercept", "the scanner hears the police net")
	s.radio.encrypted = true
	check_eq(VoiceRouter.hear(s, Roles.CONTROLLER, "net", Roles.PILOT)[1], "scrambled", "unless it is encrypted: then it is noise")
	s.features.erase("scanner")
	check_eq(VoiceRouter.hear(s, Roles.CONTROLLER, "net", Roles.PILOT)[0], 0.0, "without a scanner nothing")
	s.dispose()


func test_the_router_skips_the_talker_and_lists_who_hears() -> void:
	var s := _sess()
	var who := [{"id": "a", "role": Roles.PILOT}, {"id": "b", "role": Roles.BOSS}, {"id": "c", "role": Roles.CONTROLLER}, {"id": "d", "role": ""}]
	var heard := VoiceRouter.route(s, "a", Roles.PILOT, "net", who)
	check_eq(heard.map(func(h): return h.id), ["b"], "on the net only the boss hears the pilot (not himself, not the law, not the lobby)")
	var table := VoiceRouter.route(s, "a", Roles.PILOT, "all", who)
	check_eq(table.map(func(h): return h.id), ["b", "c", "d"], "at the table everyone but the talker")
	s.dispose()


func test_every_seat_that_has_a_place_says_where() -> void:
	var s := _sess()
	check_eq((s.role_position(Roles.PILOT) as Array).size(), 3, "the pilot: x, y, z")
	var b: Array = s.role_position(Roles.BOSS)
	check(float(b[2]) > s.world.ground(b[0], b[1]), "the club's mast is above its ground")
	check(s.role_position(Roles.CONTROLLER) != null, "the task force has a mast")
	check(s.role_position(Roles.SPOTTER) == null, "the spotter has no fixed place")
	s.dispose()


# ------------------------------------------------------------------ the host
func test_the_host_relays_frames_to_whoever_hears_them() -> void:
	var s := _sess()
	var h := HostServer.new()
	h.sess = s
	h.host_role = Roles.BOSS
	h.host_name = "Barry"
	var got := []
	h.voice_heard.connect(func(m): got.append(m))
	var frame := VoiceCodec.pack(_tone(500.0, 320))
	h.relay_voice("tok-1", "Sam", Roles.PILOT, "net", 7, frame, false)
	check_eq(got.size(), 1, "the host (the boss) hears the pilot")
	check_eq(got[0].from, "Sam", "from Sam")
	check_eq(got[0].role, Roles.PILOT, "the seat")
	check_eq(got[0].ch, "net", "on the net")
	check_eq(got[0].s, 7, "frame 7")
	check_eq(got[0].k, "net", "the kind")
	check(float(got[0].q) > 0.0 and float(got[0].q) <= 1.0, "and the quality it arrived at (%.2f)" % float(got[0].q))
	check_eq(got[0].d, frame, "the audio itself")
	h.relay_voice("tok-1", "Sam", Roles.PILOT, "bogus", 8, frame, false)
	h.relay_voice("tok-1", "Sam", Roles.PILOT, "net", 9, "A".repeat(VoiceCodec.MAX_FRAME_B64 + 1), false)
	check_eq(got.size(), 1, "a bad channel and an over-long frame are dropped")
	h.relay_voice("tok-2", "Law", Roles.CONTROLLER, "net", 1, frame, false)
	check_eq(got.size(), 2, "the boss's scanner picks up the police net too")
	check_eq(got[1].k, "intercept", "as an intercept")
	s.features.erase("scanner")
	h.relay_voice("tok-2", "Law", Roles.CONTROLLER, "net", 2, frame, false)
	check_eq(got.size(), 2, "and without the scanner it does not")
	h.free()
	s.dispose()


func test_a_runner_transmission_from_the_air_gives_the_df_stations_a_bearing() -> void:
	var s := _sess({"agency": true})
	s.state.on_ground = false
	s.state.alt = 900.0
	var h := HostServer.new()
	h.sess = s
	var n0: int = s.radio.log.size()
	h.relay_voice("host", "me", Roles.PILOT, "net", 1, VoiceCodec.pack(_tone(500.0, 320)), false)
	h.relay_voice("host", "me", Roles.PILOT, "net", 2, "", true)
	check_eq(s.radio.log.size(), n0 + 1, "the key coming up is a runner transmission on the air")
	check_eq(s.radio.log.back().channel, "runner", "on the runner channel")
	check(s.radio.log.back().dur >= 1.0, "of a length")
	var n1: int = s.radio.log.size()
	h.relay_voice("host", "me", Roles.PILOT, "all", 3, "", true)
	check_eq(s.radio.log.size(), n1, "a word across the table is not on the air")
	s.state.on_ground = true
	h.relay_voice("host", "me", Roles.PILOT, "net", 4, "", true)
	check_eq(s.radio.log.size(), n1, "and parked on the ground there is no bearing to take")
	h.free()
	s.dispose()


func test_a_flood_of_frames_is_cut_off() -> void:
	var s := _sess()
	var h := HostServer.new()
	h.sess = s
	h.host_role = Roles.BOSS
	var got := []
	h.voice_heard.connect(func(m): got.append(m))
	var frame := VoiceCodec.pack(_tone(500.0, 320))
	for i in 200:
		h.relay_voice("tok", "Sam", Roles.PILOT, "net", i, frame, false)
	check(got.size() <= HostServer.VOICE_FRAMES_PER_S, "no more than %d frames a second get through (%d did)" % [HostServer.VOICE_FRAMES_PER_S, got.size()])
	check(got.size() >= 20, "but a real talker's 25 a second is fine")
	h.free()
	s.dispose()
