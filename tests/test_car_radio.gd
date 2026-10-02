extends TestCase
## The car's radio: what is on air at any moment, the dial of real 1979-86 recordings, the player's own folder.

const TMP := "user://zz_test_radio"


func after_each() -> void:
	_rm(TMP)
	DirAccess.remove_absolute(TMP + "_state.cfg")


func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_rm("%s/%s" % [dir, sub])
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


func _radio() -> CarRadio:
	var r := CarRadio.new()
	r.state_path = TMP + "_state.cfg"
	r.setup(null)
	return r


func _wav(path: String, seconds: float) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds) * 2)
	w.data = data
	w.save_to_wav(path)


func test_the_air_moves_with_the_clock_and_goes_to_static_between_items() -> void:
	var durs := [10.0, 20.0]
	var gap := 5.0  # a 40 s round: 0-10 clip 0, 10-15 static, 15-35 clip 1, 35-40 static
	var a := CarRadio.air_position(durs, gap, 3.0)
	check_eq(a.i, 0, "3 s in: the first clip")
	check_near(a.off, 3.0, 0.001, "3 s into it")
	a = CarRadio.air_position(durs, gap, 12.0)
	check_eq(a.i, -1, "12 s: static")
	check_near(a.gap_left, 3.0, 0.001, "3 s of it left")
	a = CarRadio.air_position(durs, gap, 20.0)
	check_eq(a.i, 1, "20 s: the second clip")
	check_near(a.off, 5.0, 0.001, "5 s into it")
	a = CarRadio.air_position(durs, gap, 40.0 * 7 + 3.0)
	check_eq(a.i, 0, "and round it goes")
	check_near(a.off, 3.0, 0.001, "the same place a round later")
	check_eq(CarRadio.air_position([], 5.0, 9.0).i, -1, "no clips, no programme")
	check_eq(CarRadio.air_position([10.0], 0.0, 25.0).i, 0, "no gap: it just loops")


func test_the_dial_has_the_stations_of_the_area_in_band_order() -> void:
	var r := _radio()
	check(r.stations.size() >= 15, "%d stations" % r.stations.size())
	var ids: Array = r.stations.map(func(s): return s.id)
	for want in ["y100", "wiod", "rjr", "4veh", "sandino", "marti"]:
		check(ids.has(want), "%s is on the dial" % want)
	var order := {"FM": 0, "AM": 1, "SW": 2}
	for i in range(1, r.stations.size()):
		var a: CarRadio.Station = r.stations[i - 1]
		var b: CarRadio.Station = r.stations[i]
		check(order[a.band] <= order[b.band], "%s before %s" % [a.dial(), b.dial()])
		if a.band == b.band:
			check(float(a.label) <= float(b.label), "%s below %s" % [a.dial(), b.dial()])
	r.free()


func test_every_shipped_clip_is_there_the_length_it_says_and_is_credited() -> void:
	var r := _radio()
	var readme := FileAccess.get_file_as_string("res://assets/radio/README.md")
	for st: CarRadio.Station in r.stations:
		check(st.name != "" and st.label != "", "%s is named and has a frequency" % st.id)
		for c: CarRadio.Clip in st.clips:
			var stream := CarRadio.load_stream(c.path)
			check(stream != null, "%s loads" % c.path)
			if stream != null:
				check_near(stream.get_length(), c.dur, 0.6, "%s is %.1f s" % [c.path, c.dur])
			check(c.source != "" and readme.contains(c.source), "%s is credited in the README (%s)" % [c.path, c.source])
	r.free()


func test_the_players_own_folders_are_stations() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/miami_nights")
	_wav(TMP + "/miami_nights/one.wav", 3.0)
	_wav(TMP + "/miami_nights/two.wav", 2.0)
	var f := FileAccess.open(TMP + "/miami_nights/station.json", FileAccess.WRITE)
	f.store_string('{"name": "Miami Nights", "band": "fm", "label": "99.9", "gap_s": 4}')
	f.close()
	_wav(TMP + "/loose.wav", 1.0)
	DirAccess.make_dir_recursive_absolute(TMP + "/empty")
	var r := CarRadio.new()
	r.state_path = TMP + "_state.cfg"
	r.scan(TMP)
	var mine: Array = r.stations.filter(func(s): return s.user)
	check_eq(mine.size(), 2, "the folder and the loose file: %s" % [mine.map(func(s): return s.name)])
	var nights: CarRadio.Station = null
	for s: CarRadio.Station in mine:
		if s.name == "Miami Nights":
			nights = s
	check(nights != null, "named by its station.json")
	if nights != null:
		check_eq(nights.band, "FM", "band")
		check_eq(nights.dial(), "FM 99.9", "dial")
		check_eq(nights.clips.size(), 2, "both clips")
		check_near((nights.clips[0] as CarRadio.Clip).dur, 3.0, 0.1, "its length is read from the file")
		check_near(nights.gap_s, 4.0, 0.001, "gap")
		var a := nights.air(0.0)
		check(a.i >= -1, "it has an air position")
	check(mine.any(func(s): return s.name == "My tapes"), "loose files are 'My tapes'")
	r.free()


func test_the_knobs_wrap_and_are_remembered() -> void:
	var r := _radio()
	check(not r.on, "off to begin with")
	check_eq(r.line(), "Radio off.", "and says so")
	r.power(true)
	var first := r.idx
	r.tune(-1)
	check_eq(r.idx, (first - 1 + r.stations.size()) % r.stations.size(), "down wraps")
	r.tune(1)
	check_eq(r.idx, first, "and back up")
	for i in r.stations.size():
		r.tune(1)
	check_eq(r.idx, first, "a full turn is where it began")
	check(r.line().contains(r.station().name), "the line names the station: %s" % r.line())
	var id: String = r.station().id
	r.free()
	var r2 := _radio()
	check(r2.on and r2.station().id == id, "a new radio finds the dial where it was left")
	r2.free()


func test_out_of_the_car_it_is_silent() -> void:
	var r := _radio()
	r.power(true)
	r.active = false
	r._process(0.1)
	check(not r.voice.playing and not r.hiss.playing, "nothing plays out of the car")
	r.free()
