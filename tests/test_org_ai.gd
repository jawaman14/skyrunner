extends TestCase
## Organisation AI v1 (L-3): the Morettis and Los Cuervos run their businesses on the player's rules, through command_as on their
## own safes; the policy tops up tills, the strategy picks the day's move; refusals are logged with their reasons.


func after_each() -> void:
	World.use_map(0)


func _city(war := false) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR"}
	if war:
		o.merge({"features": Session.SANDBOX_FEATURES, "ground_war": true, "payroll": true, "trade": true, "logistics": true})
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_the_morettis_are_an_economic_org() -> void:
	var c := _city()
	check(c.businesses.ai != null, "the AI is on")
	check_near(c.ledger.balance("moretti:safe"), OrgAI.START_SAFE.moretti, 0.01, "their safe opens")
	check(c.businesses.ai.runs_for("moretti"), "they run")
	check(not c.businesses.ai.runs_for("rival"), "Los Cuervos need the street war")
	check(absf(c.ledger.total()) < 0.01, "conservation")
	c.dispose()


func test_an_ai_org_may_only_work_its_own() -> void:
	var c := _city()
	var m := Actor.of("moretti", Roles.BOSS, "moretti:boss")
	check_eq(Actor.refusal(m, "business_fund"), "", "its own businesses")
	check(Actor.refusal(m, "hire_worker").contains("can't act as"), "but not the organisation's other orders")
	var r: Array = c.command_as(m, "business_fund", {"id": "biz-4", "amount": 100})
	check(not r[0] and str(r[1]).contains("isn't ours"), "nor our club's till: %s" % [r])
	var safe := float(c.money)
	r = c.command_as(m, "business_fund", {"id": "biz-3", "amount": 500})
	check(r[0], "the laundromat: %s" % [r])
	check_eq(float(c.money), safe, "from their safe, not ours")
	check_near(c.ledger.balance("moretti:safe"), OrgAI.START_SAFE.moretti - 500.0, 0.01, "theirs")
	c.dispose()


func test_policy_tops_up_and_the_shops_trade() -> void:
	var c := _city()
	c.businesses._on_books(null)
	for id in ["biz-3", "biz-5", "biz-10"]:
		check_eq(int(c.businesses.arrears.get(id, 0)), 0, "%s paid its day" % id)
	check(c.businesses.shelf("biz-10") > 0.0, "the fish market stocked up")
	check(c.businesses.ai.log.any(func(r): return r.layer == "policy" and r.ok), "through command_as")
	check(absf(c.ledger.total()) < 0.01, "conservation")
	check(c.inventory.violations().is_empty(), "no pound made or lost")
	c.dispose()


func test_an_empty_safe_is_a_logged_refusal() -> void:
	var c := _city()
	c.ledger.transfer("moretti:safe", "outside:market", c.ledger.balance("moretti:safe"), "purchase", "moretti", c.time)
	c.businesses._on_books(null)
	check(not c.businesses.ai.refused().is_empty(), "blocked, with the reason: %s" % [c.businesses.ai.refused().slice(0, 2)])
	check(int(c.businesses.arrears.get("biz-3", 0)) > 0, "and the laundromat owes")
	check(c.businesses.blocked.has("biz-3"), "with its blocked reason")
	c.dispose()


func test_los_cuervos_buy_a_corner_with_the_war_on() -> void:
	var c := _city(true)
	check(c.businesses.ai.runs_for("rival"), "the street war gives them a chest")
	c.ground.commanders.rival.move_cash(20000.0 - c.ground.commanders.rival.cash, "outside:street", "sales")
	c.businesses._on_books(null)
	check_eq(c.businesses.owner["biz-2"], "rival", "the free corner is theirs now (%s)" % [c.businesses.ai.last])
	check(c.command(Roles.PILOT, "business_buy", {"id": "biz-2"})[0] == false, "and not for sale to us")
	c.dispose()


func test_the_same_seed_makes_the_same_moves_and_a_save_keeps_them() -> void:
	var a := _city()
	var b := _city()
	for d in 5:
		a.businesses._on_books(null)
		b.businesses._on_books(null)
	check_eq(a.businesses.ai.log.map(func(r): return [r.cmd, r.args, r.ok]), b.businesses.ai.log.map(func(r): return [r.cmd, r.args, r.ok]), "deterministic")
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(a)))
	var r := _city()
	StrategicSave.restore(r, d)
	check_eq(r.businesses.ai.log.size(), a.businesses.ai.log.size(), "the log comes back")
	a.businesses._on_books(null)
	r.businesses._on_books(null)
	check_eq(r.businesses.ai.last, a.businesses.ai.last, "and the next day's move is the same")
	a.dispose()
	b.dispose()
	r.dispose()
