extends TestCase
## Succession (DESIGN 101; D-82, D-101, D-105): after the takeover a chain of command stands under the boss: his close friend as
## number two, then the two most loyal captains. While Los Cuervos are against us, an hour on the ground draws for a hit (infamy and
## a truce scale it; none in the air); the friend sees half of them coming; otherwise the next in line takes the seat and the player
## carries on as him, with half the renown. Nobody in line, a man from the hall steps up. Its own stream; saved; off, nothing.


class FixedRng extends PyRandom:
	var vs: Array = []

	func _init(vs_: Array) -> void:
		vs = vs_

	func random() -> float:
		return float(vs.pop_front()) if not vs.is_empty() else 0.99


func after_each() -> void:
	World.use_map(0)
	Succession.ENABLED = true
	Takeover.ENABLED = true


func _story() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "fog": true, "career": true, "renown": true})
	Story.new(3).attach(s)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	if s.payroll != null:
		s.payroll.ai["org"] = false
	return s


func _hire(s: Session, loyalty: float) -> Dictionary:
	var w: Dictionary = s.payroll._person("org", "dealer")
	w.loyalty = loyalty
	s.payroll.candidates["org"].append(w)
	s.payroll.hire("org", w.id)
	return s.payroll.get_worker(w.id)


func _hour(s: Session, draws: Array) -> void:
	s.succession.rng = FixedRng.new(draws)
	s.succession.update(Succession.CHECK_S)


func test_nothing_before_the_takeover() -> void:
	var s := _story()
	check(s.succession != null and not s.succession.live(), "a chain, not live while Rafa sits")
	check_eq(s.succession.hit_odds(), 0.0, "no hits on a man who isn't boss")
	_hour(s, [0.0, 0.99])
	check_eq(s.succession.boss, Succession.PILOT, "nothing happens")
	s.dispose()


func test_the_chain_is_the_friend_then_the_most_loyal() -> void:
	var s := _story()
	s.takeover.fire()
	check(s.payroll != null, "a payroll in chapter 4")
	if s.payroll == null:
		s.dispose()
		return
	for w in s.payroll.of("org"):
		w.loyalty = 0.1
	var a := _hire(s, 0.95)
	var b := _hire(s, 0.9)
	var c: Array = s.succession.chain()
	check_eq(c.map(func(x): return str(x.name)).slice(0, 3), [Succession.FRIEND, str(a.name), str(b.name)], "number two, then the two most loyal")
	check(s.succession.line().contains("Next in line: %s (number two)" % Succession.FRIEND), "the Heat page says so: %s" % s.succession.line())
	s.dispose()


func test_odds_follow_infamy_and_the_truce() -> void:
	var s := _story()
	s.takeover.fire()
	check_near(s.succession.hit_odds(), Succession.HIT_BASE, 1e-9, "a nobody at war: the base")
	s.renown.score = Renown.TIERS[4]
	check_near(s.succession.hit_odds(), Succession.HIT_BASE * 1.6, 1e-9, "a legend: x1.6 (D-102)")
	if s.trade != null:
		s.trade.trust.own["rival"] = 90.0
		check_near(s.succession.hit_odds(), Succession.HIT_BASE * 1.6 * 0.25, 1e-9, "a full truce: a quarter")
	s.dispose()


func test_the_friend_sees_it_coming_or_takes_the_seat() -> void:
	var s := _story()
	s.takeover.fire()
	s.renown.score = 100.0
	_hour(s, [0.0, 0.1])  # a hit, and the friend's eye
	check_eq(s.succession.boss, Succession.PILOT, "foiled: still the pilot")
	check(s.succession.hits[-1].foiled, "recorded as foiled")
	_hour(s, [0.0, 0.9])  # a hit he doesn't see
	check_eq(s.succession.boss, Succession.FRIEND, "the number two takes the seat: you play on as him")
	check(not s.succession.friend_alive, "and the number two's place is empty")
	check_near(s.renown.score, 50.0, 1e-6, "a new face: half the name")
	s.dispose()


func test_no_hit_in_the_air() -> void:
	var s := _story()
	s.takeover.fire()
	s.phase = "flying"
	_hour(s, [0.0, 0.9])
	check(s.succession.hits.is_empty(), "out of their reach in the air")
	s.dispose()


func test_a_captain_then_the_hall() -> void:
	var s := _story()
	s.takeover.fire()
	s.succession.friend_alive = false
	s.succession.boss = Succession.FRIEND
	check(s.payroll != null and s.trade != null, "a payroll and the trade in chapter 4")
	if s.payroll != null:
		for w in s.payroll.of("org"):
			w.status = "gone"
		s.payroll.workers = s.payroll.workers.filter(func(w): return w.outfit != "org")
		var cap := _hire(s, 0.95)
		_hour(s, [0.0])
		check_eq(s.succession.boss, str(cap.name), "the most loyal captain takes the seat")
		check(s.payroll.get_worker(str(cap.id)) == null, "and leaves the payroll")
	_hour(s, [0.0])
	check_eq(s.succession.boss, "Chuy Barragan", "nobody left in line: a man from the hall steps up, never a game over")
	s.dispose()


func test_saved_and_off() -> void:
	var s := _story()
	s.takeover.fire()
	_hour(s, [0.0, 0.9])
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _story()
	StrategicSave.restore(r, d)
	check_eq(r.succession.boss, Succession.FRIEND, "who the boss is, kept")
	check(not r.succession.friend_alive and r.succession.hits.size() == 1, "and what happened")
	r.dispose()
	Succession.ENABLED = false
	var o := _story()
	check(o.succession == null, "off: no chain")
	o.dispose()


## After Lalo (DESIGN 101's number two, second part): the most loyal man left is named number two, watches the boss's back as Lalo
## did and is next in line; the number two's word on the Heat page.
func test_a_new_number_two_is_named_and_does_the_job() -> void:
	var s := _story()
	s.takeover.fire()
	for w in s.payroll.of("org"):
		w.loyalty = 0.1
	var a := _hire(s, 0.95)
	var b := _hire(s, 0.9)
	_hour(s, [0.0, 0.9])  # Lalo takes the seat
	check_eq(s.succession.boss, Succession.FRIEND, "Lalo is boss")
	check_eq(s.succession.number_two(), str(a.name), "the most loyal is named number two")
	check_eq(str(s.succession.chain()[1].name), str(b.name), "the next most loyal is the first captain")
	_hour(s, [0.0, 0.1])
	check(s.succession.hits[-1].foiled and s.succession.boss == Succession.FRIEND, "he sees it coming")
	_hour(s, [0.0, 0.9])
	check_eq(s.succession.boss, str(a.name), "and takes the seat when he doesn't")
	check(s.payroll.get_worker(str(a.id)) == null, "off the payroll")
	check_eq(s.succession.number_two(), str(b.name), "and the next is named")
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _story()
	StrategicSave.restore(r, d)
	check_eq(r.succession.second_id, str(b.id), "the number two is saved")
	r.dispose()


func test_the_number_twos_word() -> void:
	var s := _story()
	check_eq(s.succession.advice(), "", "nothing before the takeover")
	s.takeover.fire()
	for st in s.stash_net.live():
		st.heat = 0.0
	for site in s.logistics.cash:
		s.logistics.cash[site] = 0.0
	check(s.succession.advice().contains("Quiet out there"), "a quiet day: %s" % s.succession.advice())
	var lg: Logistics = s.logistics
	var site: String = lg.cash.keys()[0]
	lg.cash[site] = 9000.0
	check(s.succession.advice().contains("Bring it home"), "cash lying about: %s" % s.succession.advice())
	var hot: Dictionary = s.stash_net.live()[0]
	hot.heat = 55.0
	check(s.succession.advice().contains("getting hot"), "a hot house first: %s" % s.succession.advice())
	s.renown.score = Renown.TIERS[4]
	check(s.succession.advice().contains("looking for you"), "a likely hit before all: %s" % s.succession.advice())
	check(s.succession.line().begins_with(Succession.FRIEND + ":"), "on the Heat page, first")
	s.dispose()
