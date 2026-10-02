extends TestCase
## The arena: a street race in the car and an air circuit, with a field of four against the clock.


func after_each() -> void:
	Races.ENABLED = true
	World.use_map(0)


func _sess(opts := {}) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "COV", "features": Session.SANDBOX_FEATURES,
		"ground_war": true, "races": true, "renown": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
	s.update(1.0 / 30)
	return s


## Run the course: the clock at `secs` after the start gate when the last gate is taken, every gate in between.
func _drive(s: Session, c, secs: float) -> void:
	var kind: String = c.kind
	var t0 := s.time
	for i in c.gates.size():
		var g: Vector3 = c.gates[i]
		s.time = t0 + secs * float(i) / float(c.gates.size() - 1)
		s.races.feed(kind, Vector2(g.x, g.y), g.z)


func test_there_when_asked_and_the_street_needs_roads() -> void:
	var s := _sess()
	check(s.races != null, "there when asked")
	var cs: Array = s.races.courses_here()
	check_eq(cs.map(func(c): return c.kind), ["car", "air"], "a street race and a circuit")
	s.dispose()
	s = _sess({"ground_war": false})
	check_eq(s.races.courses_here().map(func(c): return c.kind), ["air"], "no roads, no street race")
	s.dispose()
	s = _sess({"races": false})
	check(s.races == null, "and not unless asked")
	s.dispose()


func test_the_courses_are_sensible() -> void:
	var s := _sess()
	var af := s.airfield
	var car = s.races.courses_here()[0]
	check(car.gates.size() >= 4, "the street has gates (%d)" % car.gates.size())
	var first: Vector3 = car.gates[0]
	var last: Vector3 = car.gates[car.gates.size() - 1]
	check(Vector2(first.x, first.y).distance_to(Vector2(af.x, af.y)) < 1.0, "it starts at the strip")
	check(Vector2(last.x, last.y).distance_to(Vector2(af.x, af.y)) < 1.0, "and comes back to it")
	for i in range(1, car.gates.size()):
		var a: Vector3 = car.gates[i - 1]
		var b: Vector3 = car.gates[i]
		check(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) <= Races.GATE_EVERY_M + 1.0, "gate %d is within %d m of the last" % [i, int(Races.GATE_EVERY_M)])
	check(car.par_s > 60.0 and car.prize == Races.CAR_PRIZE and car.fee == int(Races.CAR_PRIZE * Races.FEE_SHARE), "par %.0f s, the prize and the fee" % car.par_s)
	var air = s.races.courses_here()[1]
	check_eq(air.gates.size(), Races.AIR_GATES + 1, "six gates and the finish")
	var a0: Vector3 = air.gates[0]
	var a6: Vector3 = air.gates[Races.AIR_GATES]
	check(a0 == a6, "the finish is the first gate again")
	check_near(a0.z, s.world.ground(a0.x, a0.y) + Races.AIR_GATE_AGL, 0.01, "up in the air")
	s.dispose()


func test_entering_costs_the_fee_once() -> void:
	var s := _sess()
	var car = s.races.courses_here()[0]
	s.money = 5000
	check_eq(s.races.enter(car.id), "", "in")
	check_eq(s.money, 5000 - car.fee, "the fee")
	check(s.races.enter(car.id) != "", "not twice")
	s.races.abort("test")
	check_eq(s.money, 5000 - car.fee, "an abort does not refund")
	s.money = 3
	check(s.races.enter(car.id) != "", "no money, no entry")
	check(s.races.enter("nowhere") != "", "no such race")
	s.dispose()


func test_the_gates_in_order_and_the_clock_starts_at_the_first() -> void:
	var s := _sess()
	var car = s.races.courses_here()[0]
	s.money = 5000
	s.races.enter(car.id)
	var g1: Vector3 = car.gates[1]
	s.races.feed("car", Vector2(g1.x, g1.y), 0.0)
	check_eq(s.races.run.next, 0, "the second gate first does not count")
	s.races.feed("air", Vector2(car.gates[0].x, car.gates[0].y), 0.0)
	check_eq(s.races.run.next, 0, "a car race ignores an aeroplane")
	s.time = 100.0
	s.races.feed("car", Vector2(car.gates[0].x, car.gates[0].y), 0.0)
	check_eq(s.races.run.next, 1, "the start gate")
	check_near(s.races.run.t0, 100.0, 0.001, "starts the clock")
	s.races.feed("car", Vector2(car.gates[0].x + 200.0, car.gates[0].y), 0.0)
	check_eq(s.races.run.next, 1, "200 m off the gate is a miss")
	s.dispose()


func test_a_fast_run_wins_and_pays_once_an_hour() -> void:
	var s := _sess()
	var car = s.races.courses_here()[0]
	s.money = 5000
	s.races.enter(car.id)
	var best: float = s.races.field(car)[0]
	var money0 := s.money
	var name0: float = s.renown.score
	_drive(s, car, best * 0.8)
	check(not s.races.active(), "finished")
	var res: Dictionary = s.races.results[s.races.results.size() - 1]
	check_eq(res.place, 1, "first place")
	check_eq(res.prize, Races.CAR_PRIZE, "the prize")
	check_eq(s.money, money0 + Races.CAR_PRIZE, "paid")
	check_near(s.renown.score, name0 + 6.0, 0.001, "and a name")
	s.races.enter(car.id)
	_drive(s, car, best * 0.8)
	var again: Dictionary = s.races.results[s.races.results.size() - 1]
	check_eq(again.place, 1, "first again")
	check_eq(again.prize, 0, "but it paid within the hour")
	s.time += Races.PAYS_EVERY_S + 10.0
	check_near(s.races.cooldown(car.id), 0.0, 0.001, "an hour later it pays again")
	s.dispose()


func test_places_follow_the_field() -> void:
	var s := _sess()
	var car = s.races.courses_here()[0]
	var f: Array = s.races.field(car)
	check_eq(f.size(), Races.FIELD, "four rivals")
	for i in range(1, f.size()):
		check(f[i] >= f[i - 1], "sorted")
	check(f[0] >= car.par_s * 0.85 - 0.01 and f[f.size() - 1] <= car.par_s * 1.35 + 0.01, "within the spread of par")
	check_eq(s.races.field(car), f, "the same field every time")
	s.money = 5000
	s.races.enter(car.id)
	_drive(s, car, f[1] + 1.0)  # slower than two of them
	check_eq(s.races.results[s.races.results.size() - 1].place, 3, "third: half the prize / a quarter")
	check_eq(s.races.results[s.races.results.size() - 1].prize, int(Races.CAR_PRIZE * 0.25), "a quarter of the prize")
	s.time += 4000.0
	s.races.enter(car.id)
	_drive(s, car, f[3] + 50.0)  # last
	check_eq(s.races.results[s.races.results.size() - 1].place, 5, "last of five")
	check_eq(s.races.results[s.races.results.size() - 1].prize, 0, "nothing")
	s.dispose()


func test_too_slow_and_the_circuit_height() -> void:
	var s := _sess()
	var car = s.races.courses_here()[0]
	s.money = 5000
	s.races.enter(car.id)
	s.time = 10.0
	s.races.feed("car", Vector2(car.gates[0].x, car.gates[0].y), 0.0)
	s.time = 10.0 + car.par_s * Races.TIME_LIMIT + 1.0
	s.races.update(1.0)
	check(not s.races.active(), "three times par and you are out")
	var air = s.races.courses_here()[1]
	s.races.enter(air.id)
	var g: Vector3 = air.gates[0]
	s.races.feed("air", Vector2(g.x, g.y), g.z - 400.0)
	check_eq(s.races.run.next, 0, "through the gate 400 m too low does not count")
	s.races.feed("air", Vector2(g.x, g.y), g.z + 50.0)
	check_eq(s.races.run.next, 1, "50 m high does")
	s.dispose()


func test_the_phone_command_and_the_save() -> void:
	var s := _sess()
	check(Roles.allowed(Roles.PILOT, "race_enter") and Roles.allowed(Roles.BOSS, "race_enter"), "pilot and boss may")
	s.money = 5000
	var car = s.races.courses_here()[0]
	var r: Array = s.command(Roles.PILOT, "race_enter", {"id": car.id})
	check(r[0], "by command: %s" % [r])
	s.races.abort("test")
	s.races.paid_at[car.id] = 123.0
	s.races.won = 900
	var d := StrategicSave.capture(s)
	var t := _sess()
	StrategicSave.restore(t, JSON.parse_string(JSON.stringify(d)))
	check_eq(t.races.won, 900, "winnings kept")
	check_near(float(t.races.paid_at.get(car.id, 0.0)), 123.0, 0.001, "and when it last paid")
	var v: Dictionary = s.races.view()
	check_eq(v.courses.size(), 2, "the view lists both")
	s.dispose()
	t.dispose()
