extends TestCase
## Renown: the name on the street, from what the organisation does (read off the event bus), and what it is worth.


func after_each() -> void:
	Renown.ENABLED = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 33, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true, "agency": true, "family": true, "renown": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.update(1.0 / 30)
	return s


func _emit(s: Session, kind: String, data := {}) -> void:
	s.bus.emit(kind, s.time, "", ["runner"], data)


func test_it_is_only_there_when_asked_for() -> void:
	var s := _sess({"renown": false})
	check(s.renown == null, "no renown unless the session asks")
	s.dispose()
	Renown.ENABLED = false
	s = _sess()
	check(s.renown == null, "and not when switched off")
	s.dispose()


func test_deliveries_make_a_name_and_setbacks_unmake_half_as_much() -> void:
	var s := _sess()
	var r: Renown = s.renown
	check_eq(r.tier(), 0, "nobody to begin with")
	for i in 3:
		_emit(s, "job_delivered")
	check_near(r.score, 9.0, 0.001, "three loads: 3 points each")
	_emit(s, "busted")
	check_near(r.score, 9.0 - 3.0, 0.001, "a bust costs half of its 6")
	for i in 5:
		_emit(s, "sentenced")
	check_eq(r.score, 0.0, "never below nothing")
	check(r.recent.size() <= Renown.KEEP, "the log is kept short")
	s.dispose()


func test_the_tier_climbs_and_the_papers_say_so() -> void:
	var s := _sess()
	var r: Renown = s.renown
	for i in 14:  # 42 points
		_emit(s, "job_delivered")
	check_eq(r.tier(), 1, "past 40: a name on the street (%.0f)" % r.score)
	check(s.messages.any(func(m): return str(m[1]).contains("RENOWN")), "it is said: %s" % [s.messages.map(func(m): return m[1])])
	check_eq(Renown.tier_of(119.9), 1, "just under 120 is still tier 1")
	check_eq(Renown.tier_of(120.0), 2, "120 is Known")
	check_eq(Renown.tier_of(10000.0), 4, "and the top is a legend")
	s.dispose()


func test_a_bigger_sale_is_a_bigger_name_and_a_rivals_flip_is_not_ours() -> void:
	var s := _sess()
	var r: Renown = s.renown
	_emit(s, "bulk_sale", {"qty": 10.0, "buyer": "family"})
	var small := r.score
	_emit(s, "bulk_sale", {"qty": 400.0, "buyer": "family"})
	check(r.score - small > small, "400 lb earns more than 10 lb (%.1f vs %.1f)" % [r.score - small, small])
	check(r.score - small <= 5.0 + 0.001, "but no sale is worth more than 5")
	var before := r.score
	_emit(s, "worker_flipped", {"outfit": "rival"})
	check_eq(r.score, before, "Los Cuervos' man talking costs us nothing")
	_emit(s, "worker_flipped", {"outfit": "org"})
	check(r.score < before, "ours does")
	s.dispose()


func test_a_name_gets_better_prices_better_recruits_and_a_watching_task_force() -> void:
	var s := _sess()
	var base: float = s.trade.quote("family", "cocaine").price
	s.renown.score = 650.0
	s.renown.apply()
	check_eq(s.renown.tier(), 4, "a legend")
	var q: Dictionary = s.trade.quote("family", "cocaine")
	if q.why == "":
		check_near(q.price, base * 1.06, base * 0.001, "buyers pay 6%% more (%.0f vs %.0f)" % [q.price, base])
	check_near(s.police.decay_mult, 0.76, 0.001, "suspicion cools 24% slower")
	check_near(s.renown.skill_bonus(), 0.12, 0.001, "+12 points of skill")
	s.dispose()
	# the same seed, the same draws: only the values shift
	var plain := _sess({"renown": false})
	var famous := _sess()
	famous.renown.score = 650.0
	famous.payroll._refresh("org")
	plain.payroll._refresh("org")
	var a: Array = plain.payroll.candidates["org"]
	var b: Array = famous.payroll.candidates["org"]
	check_eq(a.size(), b.size(), "as many candidates")
	var better := 0
	for i in mini(a.size(), b.size()):
		if float(b[i].skill) > float(a[i].skill) + 0.001:
			better += 1
		check(float(b[i].skill) >= float(a[i].skill) - 0.001, "no candidate is worse")
	check(better > 0, "and some are better (%d of %d)" % [better, a.size()])
	plain.dispose()
	famous.dispose()


func test_the_name_survives_a_save() -> void:
	var s := _sess()
	for i in 20:
		_emit(s, "job_delivered")
	var d := StrategicSave.capture(s)
	check(d.has("renown"), "the save has it")
	var t := _sess()
	check_eq(t.renown.score, 0.0, "a new game has none")
	StrategicSave.restore(t, JSON.parse_string(JSON.stringify(d)))
	check_near(t.renown.score, s.renown.score, 0.001, "restored: %.0f" % t.renown.score)
	check_near(t.police.decay_mult, s.police.decay_mult, 0.001, "and the task force sees it")
	s.dispose()
	t.dispose()
