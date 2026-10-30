extends TestCase
## Rafa and Benny react to the pilot's firsts, once each, through the phone's banners.


class _Notify:
	var got := []
	func push(sender: String, body: String, _kind := "phone") -> void:
		got.append([sender, body])


func after_each() -> void:
	World.use_map(0)


func test_each_first_is_said_once() -> void:
	var s := Session.new({"seed": 4, "location": "HAR"})
	var n := _Notify.new()
	var b := Banter.new(s, n, func(): return 22.0)
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "VAL", "seconds": 300.0, "touchdown_fpm": 120.0})
	check_eq(n.got.size(), 2, "a butter landing at night: two lines")
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR", "seconds": 300.0, "touchdown_fpm": 110.0})
	check_eq(n.got.size(), 2, "the same firsts are not said again")
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR", "seconds": 300.0, "touchdown_fpm": 520.0})
	check(n.got.back()[0] == Banter.BENNY and "gear" in str(n.got.back()[1]).to_lower(), "the first hard landing")
	s.bus.emit("job_accepted", s.time, "", ["runner"], {"job_id": 1, "hot": false})
	check_eq(n.got.size(), 3, "a legal job is not news")
	s.bus.emit("job_accepted", s.time, "", ["runner"], {"job_id": 2, "hot": true})
	check_eq(n.got.size(), 4, "a hot one is")
	s.bus.emit("upgrade", s.time, "", ["law"], {"side": "law", "id": "jammer"})
	check_eq(n.got.size(), 4, "a law upgrade is not the pilot's news")
	s.dispose()


func test_the_tick_notices_radar_interest() -> void:
	var s := Session.new({"seed": 4, "location": "HAR"})
	var n := _Notify.new()
	var b := Banter.new(s, n)
	b.tick()
	check(n.got.is_empty(), "nothing yet")
	s.police.case("runner").suspicion = 25.0
	b.tick()
	check(n.got.size() == 1 and "tail number" in str(n.got[0][1]), "someone asked about the tail number")
	s.dispose()
