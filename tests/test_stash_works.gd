extends TestCase
## Stash works: a hidden vault (a raid finds less) and a guard post (the house runs cooler), paid from the safe.


func after_each() -> void:
	StashWorks.ENABLED = true
	World.use_map(0)


func _sess() -> Session:
	var s := Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_building_costs_money_and_has_two_levels() -> void:
	var s := _sess()
	var st: Dictionary = s.stash_net.live()[0]
	s.money = 20000
	check_eq(StashWorks.build(s, st.id, "vault"), "", "first level")
	check_eq(s.money, 20000 - 2500, "$2,500")
	check_eq(StashWorks.level(st, "vault"), 1, "level 1")
	check_eq(StashWorks.build(s, st.id, "vault"), "", "second level")
	check_eq(s.money, 20000 - 2500 - 6000, "$6,000")
	check(StashWorks.build(s, st.id, "vault") != "", "there is no third")
	check_eq(StashWorks.next_cost(st, "vault"), -1, "nothing left to buy")
	s.money = 100
	check(StashWorks.build(s, st.id, "guard") != "", "no money, no guard post")
	check_eq(s.money, 100, "and nothing was charged")
	check(StashWorks.build(s, st.id, "moat") != "", "no such work")
	check(StashWorks.build(s, "nowhere", "guard") != "", "no such house")
	st.burned = true
	s.money = 99999
	check(StashWorks.build(s, st.id, "guard") != "", "a burned house is not worth it")
	s.dispose()


func test_a_guard_post_cools_the_house_and_warms_it_less() -> void:
	var s := _sess()
	var live: Array = s.stash_net.live()
	var plain: Dictionary = live[0]
	var guarded: Dictionary = live[1]
	guarded["works"] = {"guard": 2}
	plain.heat = 100.0
	guarded.heat = 100.0
	s.stash_net.update(600.0, s.time, [])
	check(float(guarded.heat) < float(plain.heat), "it cooled faster (%.1f vs %.1f)" % [guarded.heat, plain.heat])
	check_near(StashWorks.heat_in(guarded), 0.6, 0.0001, "and a delivery warms it 40% less")
	check_near(StashWorks.heat_out(guarded), 1.5, 0.0001, "and it cools 50% faster")
	check_near(StashWorks.heat_in(plain), 1.0, 0.0001, "an unimproved house is unchanged")
	s.dispose()


func test_a_vault_saves_part_of_what_a_raid_takes() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	var live: Array = s.stash_net.live()
	var st: Dictionary = live[0]
	var other: Dictionary = live[1]
	st["works"] = {"vault": 2}
	lg.stock[st.id]["cocaine"] = 100.0
	lg.cash[st.id] = 10000.0
	var coke_other: float = lg.stock[other.id]["cocaine"]
	var money0 := s.money
	var lost0: float = lg.lost.product
	lg._raided(st.id)
	check_near(lg.lost.product - lost0, 30.0, 0.01, "30% of the product was found")
	check_near(lg.stock[other.id]["cocaine"], coke_other + 70.0, 0.01, "70 lb were spirited away to another house")
	check_eq(s.money, money0 + 7000, "and $7,000 went straight to the safe")
	check_eq(lg.lost.cash, 3000, "$3,000 was lost")
	check_eq(lg.stock[st.id]["cocaine"], 0.0, "the raided house is empty")
	check(s.messages.any(func(m): return str(m[1]).contains("vault held")), "and it is said")
	# no vault: all of it goes
	var bare: Dictionary = live[2]
	lg.stock[bare.id]["cocaine"] = 50.0
	lg.cash[bare.id] = 1000.0
	var m1 := s.money
	lg._raided(bare.id)
	check_eq(s.money, m1, "nothing saved without a vault")
	s.dispose()


func test_it_is_in_the_view_the_command_and_the_save() -> void:
	var s := _sess()
	var st: Dictionary = s.stash_net.live()[0]
	s.money = 50000
	check(Roles.allowed(Roles.BOSS, "stash_works") and Roles.allowed(Roles.PILOT, "stash_works"), "boss and pilot may")
	var r: Array = s.command(Roles.PILOT, "stash_works", {"stash": st.id, "what": "guard"})
	check(r[0], "by command: %s" % [r])
	var site = s.logistics.view().sites.filter(func(x): return x.id == st.id)[0]
	check_eq(site.guard, 1, "the view shows it")
	check(not s.command(Roles.PILOT, "stash_works", {"stash": st.id, "what": "moat"})[0], "an unknown work is refused")
	var d := StrategicSave.capture(s)
	var t := _sess()
	StrategicSave.restore(t, JSON.parse_string(JSON.stringify(d)))
	check_eq(StashWorks.level(t.stash_net.get_stash(st.id), "guard"), 1, "the save keeps it")
	StashWorks.ENABLED = false
	check_eq(StashWorks.level(st, "guard"), 0, "switched off, it counts for nothing")
	s.dispose()
	t.dispose()
