extends TestCase
## Crew relationships (DESIGN 89, section 51.6): when we take a man on, one draw against each of our men decides hate, friendship,
## love or nothing, on its own stream; a man won't be posted with one he hates (a stash, a squad); a man killed or taken costs his
## friends' loyalty; the roster says it; saved with the workers; off, no bonds.


class FixedRng extends PyRandom:
	var v := 0.0

	func _init(v_ := 0.0) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	Payroll.BONDS = true


func _sess() -> Session:
	var s := Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"payroll": true, "trade": true, "logistics": true})
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	s.update(1.0 / 30)
	s.money = 100000
	return s


func _hire(s: Session, role: String, draw: float) -> Dictionary:
	s.payroll.bonds_rng = FixedRng.new(draw)
	var w: Dictionary = s.payroll._person("org", role)
	w.loyalty = 0.8
	s.payroll.candidates.org.append(w)
	check_eq(s.payroll.hire("org", w.id), "", "hired %s" % w.name)
	return s.payroll.get_worker(w.id)


func test_a_new_man_has_a_bond_with_each_of_ours_or_none() -> void:
	var s := _sess()
	var a := _hire(s, "lookout", 0.99)
	var b := _hire(s, "lookout", 0.01)  # under the hate odds
	check_eq(s.payroll.bond(b.id, a.id), "hate", "they hate each other")
	check_eq(s.payroll.bond(a.id, b.id), "hate", "both ways")
	var c := _hire(s, "lookout", Payroll.BOND_HATE + 0.01)
	check_eq(s.payroll.bond(c.id, a.id), "friend", "friends")
	var d := _hire(s, "lookout", 0.99)
	check_eq(s.payroll.bond(d.id, a.id), "", "nothing between them")
	check(s.payroll.bonds_line(a).contains("hates %s" % b.name), "the roster: %s" % s.payroll.bonds_line(a))
	s.dispose()


func test_he_wont_watch_a_house_with_a_man_he_hates() -> void:
	var s := _sess()
	var a := _hire(s, "lookout", 0.99)
	var b := _hire(s, "lookout", 0.01)
	var st := str(s.stash_net.live()[0].id)
	check_eq(s.payroll.post_lookout(a.id, st), "", "the first is posted")
	var why := s.payroll.post_lookout(b.id, st)
	check(why.contains("won't watch a house with %s" % a.name), "the second won't go: %s" % why)
	check_eq(s.payroll.post_lookout(b.id, str(s.stash_net.live()[1].id)), "", "another house is fine")
	s.dispose()


func test_a_squad_is_made_of_men_who_will_stand_together() -> void:
	var s := _sess()
	var a := _hire(s, "soldier", 0.99)
	a.skill = 0.9
	var b := _hire(s, "soldier", 0.01)  # hates a
	b.skill = 0.8
	var c := _hire(s, "soldier", 0.99)
	c.skill = 0.1
	var got: Array = s.payroll.take("org", "soldier", 2, "S-test", false)
	check_eq(got.size(), 2, "two men")
	check(got.has(a.id) and got.has(c.id) and not got.has(b.id), "the best, and the man who will stand with him: %s" % str(got))
	s.dispose()


func test_a_man_lost_costs_his_friends() -> void:
	var s := _sess()
	var a := _hire(s, "lookout", 0.99)
	var friend := _hire(s, "lookout", Payroll.BOND_HATE + 0.01)
	var foe := _hire(s, "lookout", 0.99)
	s.payroll.bonds_rng = FixedRng.new(0.01)
	s.payroll._bond(foe)  # (redraw against everyone: foe now hates a and friend)
	friend.loyalty = 0.8
	foe.loyalty = 0.5
	s.payroll.lose(a.id, "dead")
	check_near(float(friend.loyalty), 0.8 + float(Payroll.GRIEF.friend), 1e-6, "his friend takes it hard")
	check_near(float(foe.loyalty), 0.5 + float(Payroll.GRIEF.hate), 1e-6, "the man who hated him less so")
	check(s.messages.any(func(m): return str(m[1]).contains("takes it hard")), "said")
	s.dispose()


func test_saved_with_the_workers_and_off_no_bonds() -> void:
	var s := _sess()
	var a := _hire(s, "lookout", 0.99)
	var b := _hire(s, "lookout", Payroll.BOND_HATE + Payroll.BOND_FRIEND + 0.005)  # love
	check_eq(s.payroll.bond(a.id, b.id), "love", "in love")
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.payroll.bond(a.id, b.id), "love", "saved")
	r.dispose()
	Payroll.BONDS = false
	var o := _sess()
	_hire(o, "lookout", 0.99)
	var y := _hire(o, "lookout", 0.0)
	check(not y.has("bonds") or y.bonds.is_empty(), "off: no bonds")
	o.dispose()
