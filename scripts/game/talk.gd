class_name Talk
extends RefCounted
## Conversations with the Family and with the General's aide, written as
## Dialogue Manager scripts (dialogue/*.dialogue; Nathan Hoad's Dialogue
## Manager, MIT, runtime vendored in addons/dialogue_manager/).
##
## No editor plugin, autoload or import step: `manager()` instances the
## runtime once (it registers the "DialogueManager" engine singleton itself)
## and `resource()` compiles a script from its text. The scripts read and act
## through a `State`, built from the seat's snapshot and its command callable,
## so a conversation goes through the same permission-checked commands as the
## desks' keys - on the host's own seat or a remote one alike.

const DIR := "res://dialogue/"
const CAPO := "Sal Moretti"
const AIDE := "Captain Ibarra"

static var _cache := {}


## The Dialogue Manager runtime, made on first use.
static func manager() -> Node:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var dm: Node = load("res://addons/dialogue_manager/dialogue_manager.gd").new()
	dm.name = "DialogueManager"
	(Engine.get_main_loop() as SceneTree).root.add_child(dm)
	return dm


## `name`.dialogue, compiled (cached). Null, with the errors printed, if it doesn't compile.
static func resource(name: String) -> DialogueResource:
	if _cache.has(name):
		return _cache[name]
	var text := FileAccess.get_file_as_string(DIR + name + ".dialogue")
	var result: DMCompilerResult = DMCompiler.compile_string(text, DIR + name + ".dialogue")
	if not result.errors.is_empty():
		for e in result.errors:
			push_error("%s.dialogue line %d: %s" % [name, int(e.line_number) + 1, DMConstants.get_error_message(e.error)])
		return null
	var r := DialogueResource.new()
	r.using_states = result.using_states
	r.titles = result.titles
	r.first_title = result.first_title
	r.character_names = result.character_names
	r.lines = result.lines
	r.raw_text = text
	_cache[name] = r
	return r


## Open conversation `name` at `title` over a seat's link (LocalLink or
## NetClient) in a balloon under `parent`. Returns the balloon (null if the
## script didn't compile).
static func open(parent: Node, name: String, title: String, link) -> TalkBalloon:
	var res := resource(name)
	if res == null:
		return null
	var st := State.new(func(): return link.snapshot(), Callable())
	var state_ref: WeakRef = weakref(st)
	var b := TalkBalloon.new()
	var balloon_ref: WeakRef = weakref(b)
	st.cmd_fn = func(n: String, a: Dictionary) -> Array:
		return await reviewed_result(balloon_ref.get_ref(), link, n, a, state_ref.get_ref())
	parent.add_child(b)
	b.start(res, title, st)
	return b


## Keep the reviewed arguments fixed through approval and correlated execution.
## Closing/removing the conversation fences the pending preview without a mutation.
static func reviewed_result(balloon: TalkBalloon, link, name: String, arguments: Dictionary, state: State) -> Array:
	if state == null or state.cancelled or not is_instance_valid(balloon) or not balloon.is_inside_tree():
		return [false, "Conversation closed. No command sent."]
	if not is_instance_valid(link) or not link.alive():
		return [false, "Disconnected. No command sent."]
	var args := arguments.duplicate(true)
	if name in ActionReview.COMMANDS:
		var review := ActionReview.new().setup(link, name, args)
		var answer := {}
		review.finished.connect(func(approved, message):
			answer.approved = approved
			answer.message = message)
		balloon.review = review
		balloon.add_child(review)
		while answer.is_empty():
			if state.cancelled or not is_instance_valid(balloon) or not balloon.is_inside_tree() or not is_instance_valid(review) or not review.is_inside_tree():
				if is_instance_valid(review): review.queue_free()
				return [false, "Conversation closed. No command sent."]
			await (Engine.get_main_loop() as SceneTree).process_frame
		if is_instance_valid(balloon): balloon.review = null
		if not answer.approved:
			return [false, str(answer.message)]
	if state.cancelled or not is_instance_valid(balloon) or not balloon.is_inside_tree():
		return [false, "Conversation closed. No command sent."]
	return await command_result(link, name, args, state)


## Correlate this mutation with its acknowledgement. A later snapshot is a
## separate requirement: never narrate a completed purchase from stale stock.
static func command_result(link, name: String, args: Dictionary, state: State, timeout_ms := 15000) -> Array:
	if not is_instance_valid(link) or not link.alive():
		return [false, "Disconnected. No command sent."]
	var seq: int = link.send_command(name, args)
	var deadline := Time.get_ticks_msec() + timeout_ms
	while true:
		if state.cancelled:
			return [false, "Conversation closed; result unknown."]
		if not is_instance_valid(link) or not link.alive() or Time.get_ticks_msec() >= deadline:
			return [false, "Result unknown. Check the current state before trying again."]
		if link.acks.has(seq):
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	var reply: Array = link.acks[seq]
	link.acks.erase(seq)
	if not bool(reply[0]) or link is LocalLink:
		return reply
	var snapshot = link.snapshot()
	var current: Dictionary = snapshot if snapshot is Dictionary else {}
	var acknowledged_seq := int(current.get("seq", -1))
	while not state.cancelled:
		if not is_instance_valid(link) or not link.alive() or Time.get_ticks_msec() >= deadline:
			return [false, "Host accepted the command; updated state unavailable. Check before trying again."]
		var fresh = link.snapshot()
		if fresh is Dictionary and int(fresh.get("seq", -1)) > acknowledged_seq:
			return reply
		await (Engine.get_main_loop() as SceneTree).process_frame
	return [false, "Conversation closed; result unknown."]


## What a conversation can see and do. Plain fields, refreshed from the
## snapshot before every line; methods issue commands, then refresh.
class State:
	var snap_fn: Callable  ## () -> Dictionary: the seat's snapshot
	var cmd_fn: Callable  ## (name, args) -> [ok, message]
	var capo := CAPO
	var aide := AIDE
	var campaign_chapter := 0
	var campaign_guidance := ""
	var campaign_complete := false
	var campaign_ending := ""
	var money := 0
	var cancelled := false
	var pending := false
	var result := ""  ## the last command's refusal, if any
	# the Family
	var family := false
	var family_gone := false
	var respect := 0
	var has_offer := false
	var offer_id := ""
	var offer_kind := ""
	var offer_text := ""
	var offer_read := ""
	var offer_probe := ""
	var offer_cost := 0
	var tribute := 0
	var tribute_min := 0
	var stalled := false
	var loan_owed := 0
	var last := ""
	# the island
	var island := false
	var relations := 0
	var status := ""
	var passage_min := 0
	var passage_cost := 0
	var mule_pct := 0
	var ship_pct := 0
	var price := 0.0
	# the court (the pilot's case)
	var court := false
	var case_open := false
	var stage := ""
	var lawyer_name := ""
	var lawyer_tier := ""
	var judge := ""
	var judge_known := ""
	var bribable := false
	var charges := ""
	var strength := ""
	var odds := -1  ## the conviction odds in percent, once discovery is in (-1 unknown)
	var witnesses := -1
	var informant := false
	var trial_min := 0
	var bail := 0
	var bond := 0
	var no_bail := false
	var plea_years := 0.0
	var plea_charge := ""
	var has_plea := false
	var release_min := 0
	var verdict := ""
	var years := 0.0
	var appealed := false
	var tampered := false
	var bribed := false
	var filed := []  ## motions filed
	var continuances := 0
	# the trade (the buyers)
	var trade := false
	var coke := 0
	var weed := 0
	var rifles := 0
	var connected := true
	var connect_left := 0
	var street_coke := 0
	var street_weed := 0
	var quotes := {}
	var corners := {}
	var trade_last := ""
	# the payroll (the organisation's crew)
	var payroll := false
	var crew := 0
	var wage_bill := 0
	var crew_loyalty := 0  ## percent
	var unpaid := 0
	var cand: Array = []  ## up to four candidates: {id, name, role, skill, wage, hint}
	var jailed: Array = []  ## crew in custody without a lawyer: {id, name, role}
	var crew_list: Array = []  ## everyone on the payroll: {id, name, role, status, assigned, doing}
	# the Sunrise Collective (Nico Cozz)
	var psych := false
	var ps_name := "Nico Cozz"
	var ps_status := ""
	var ps_stock := 0.0
	var ps_held := 0.0
	var ps_trust := 0
	var ps_rate := 0.0
	var ps_price := 0
	var ps_weed_left := 0
	var ps_circuit_left := 0.0
	var ps_hide_min := 0
	var ps_scene := ""
	var ps_auto := false
	var ps_best_id := ""
	var ps_best_name := ""
	var ps_best_lb := 0
	var ps_acid_id := ""  ## the stash with the most sheets
	var ps_acid_name := ""
	var ps_acid_sheets := 0.0
	var ps_mood := 1.0
	var ps_earned := 0
	var ps_bartered := 0
	var ps_sold := 0.0
	var ps_raids := 0
	# the dealership (Palmetto Motors)
	var dealer := false
	var dl_name := "Marty Quintero"
	var dl_cat := {}
	var dl_cars := 0
	var dl_trucks := 0
	var dl_last_car := {}
	var dl_last_truck := {}
	var dl_insurance := 0
	var dl_auto := false
	var dl_fleet_line := ""
	# the casino (the Hotel Cielo)
	var manager := "Lenny Vance"
	var casino := false
	var cs_status := ""
	var cs_trading := false
	var cs_stake_pct := 0
	var cs_stake_price := 0
	var cs_can_buy := false
	var cs_owed := 0
	var cs_heat := 0
	var cs_unrest := 0
	var cs_rival := 0
	var cs_rival_name := ""
	var cs_rival_buyout := 0
	var cs_bought_out := false
	var cs_gross_hour := 0
	var cs_share_hour := 0
	var cs_skim_pct := 0
	var cs_family_pct := 0
	var cs_act := ""
	var cs_general_payoff := 0
	var cs_uprising_min := 0
	var cs_evac_total := 0
	var cs_has_cash := false
	var cs_cash_line := ""
	var cs_dark_note := ""
	var cs_stash_id := ""
	var cs_launder_n := 0
	var cs_launder_line := ""
	# the casino file (the law's side)
	var cs_case := 0
	var cs_cage_note := ""
	var cs_closed_note := ""
	var cs_wiretap := 0
	var cs_audit := 0
	var cs_raid := 0
	var cs_raid_case := 0

	func _init(snap_fn_: Callable, cmd_fn_: Callable) -> void:
		snap_fn = snap_fn_
		cmd_fn = cmd_fn_
		refresh()

	func refresh() -> void:
		var snap = snap_fn.call()
		if not (snap is Dictionary):
			return
		campaign_chapter = int(snap.get("campaign", {}).get("chapter", 0))
		campaign_guidance = str(snap.get("campaign", {}).get("guidance", ""))
		campaign_complete = bool(snap.get("campaign", {}).get("completed", false))
		campaign_ending = str(snap.get("campaign", {}).get("ending", ""))
		money = int(snap.get("money", 0))
		var f: Dictionary = snap.get("family", {})
		family = not f.is_empty()
		family_gone = bool(f.get("gone", false))
		respect = int(f.get("respect", 0))
		var offers: Array = f.get("offers", [])
		has_offer = not offers.is_empty()
		var o: Dictionary = offers.back() if has_offer else {}
		offer_id = str(o.get("id", ""))
		offer_kind = str(o.get("kind", ""))
		offer_text = str(o.get("text", ""))
		offer_read = str(o.get("read", ""))
		offer_probe = str(o.get("probe", ""))
		offer_cost = int(o.get("cost", 0))
		tribute = int(f.get("tribute", 0))
		tribute_min = int(ceil(float(f.get("tribute_s", 0)) / 60.0))
		stalled = bool(f.get("stalled", false))
		loan_owed = int(f.get("loan", {}).get("owed", 0))
		last = str(f.get("last", ""))
		var i: Dictionary = snap.get("island", {})
		island = not i.is_empty()
		relations = int(i.get("relations", 0))
		status = str(i.get("status", ""))
		passage_min = int(ceil(float(i.get("passage_s", 0)) / 60.0))
		passage_cost = int(i.get("passage_cost", 0))
		mule_pct = int(round(100.0 * float(i.get("mule_p", 0.0))))
		ship_pct = int(round(100.0 * float(i.get("ship_p", 0.0))))
		price = float(i.get("price", 0.0))
		var c: Dictionary = snap.get("court", {})
		court = not c.is_empty()
		case_open = bool(c.get("open", false))
		stage = str(c.get("stage", ""))
		lawyer_name = str(c.get("lawyer", "")).capitalize() if str(c.get("lawyer", "")).begins_with("the ") else str(c.get("lawyer", ""))
		lawyer_tier = str(c.get("lawyer_tier", ""))
		judge = str(c.get("judge", ""))
		judge_known = str(c.get("judge_known", ""))
		bribable = bool(c.get("bribable", false))
		charges = ", ".join(c.get("charges", []))
		strength = str(c.get("strength", ""))
		odds = int(round(100.0 * float(c.get("odds")))) if c.has("odds") else -1
		witnesses = int(c.get("witnesses", -1))
		informant = bool(c.get("informant", false))
		trial_min = int(ceil(float(c.get("trial_s", 0)) / 60.0))
		bail = int(c.get("bail", 0))
		bond = int(bail * 0.1)
		no_bail = bool(c.get("no_bail", false))
		var pl: Dictionary = c.get("plea", {})
		has_plea = not pl.is_empty()
		plea_years = float(pl.get("years", 0.0))
		plea_charge = str(Court.CHARGES.get(str(pl.get("charge", "")), [""])[0]) if has_plea else ""
		release_min = int(ceil(float(c.get("release_s", 0)) / 60.0))
		verdict = str(c.get("verdict", ""))
		years = float(c.get("years", 0.0))
		appealed = bool(c.get("appealed", false))
		tampered = bool(c.get("tampered", false))
		bribed = bool(c.get("bribed", false))
		filed = c.get("motions", [])
		continuances = int(c.get("continuances", 0))
		var p: Dictionary = snap.get("payroll", {})
		payroll = not p.is_empty()
		crew = p.get("crew", []).size()
		wage_bill = int(p.get("wage_bill", 0))
		crew_loyalty = int(round(100.0 * float(p.get("loyalty", 0.0))))
		unpaid = int(p.get("unpaid", 0))
		cand = p.get("candidates", []).slice(0, 4)
		crew_list = p.get("crew", [])
		var t: Dictionary = snap.get("trade", {})
		trade = not t.is_empty()
		coke = int(t.get("stock", {}).get("cocaine", 0))
		weed = int(t.get("stock", {}).get("marijuana", 0))
		connected = bool(t.get("connected", true))
		connect_left = maxi(0, int(Trade.CONNECT_LB) - int(t.get("sold", {}).get("marijuana", 0)))
		street_coke = int(t.get("street", {}).get("cocaine", 0.0))
		street_weed = int(t.get("street", {}).get("marijuana", 0.0))
		quotes = t.get("quotes", {})
		corners = t.get("corners", {})
		trade_last = str(t.get("last", ""))
		rifles = int(snap.get("arsenal", {}).get("stock", {}).get("rifle", 0))
		jailed = p.get("jail", []).filter(func(j): return not j.lawyer)
		var pz: Dictionary = snap.get("psych", {})
		psych = not pz.is_empty()
		if psych:
			ps_name = str(pz.chemist)
			ps_status = str(pz.status)
			ps_stock = float(pz.stock)
			ps_held = float(pz.held)
			ps_trust = int(pz.trust)
			ps_rate = float(pz.rate)
			ps_price = int(pz.price)
			ps_weed_left = int(pz.weed_left)
			ps_circuit_left = float(pz.circuit_left)
			ps_hide_min = int(pz.hide_min)
			ps_scene = str(pz.scene)
			ps_auto = bool(pz.auto)
			ps_earned = int(pz.earned)
			ps_bartered = int(pz.bartered)
			ps_sold = float(pz.sold)
			ps_raids = int(pz.raids)
			var stashes: Array = pz.stashes
			ps_best_id = str(stashes[0].id) if not stashes.is_empty() else ""
			ps_best_name = str(stashes[0].name) if not stashes.is_empty() else ""
			ps_best_lb = int(stashes[0].lb) if not stashes.is_empty() else 0
			var acid: Array = pz.get("acid_stashes", [])
			ps_acid_id = str(acid[0].id) if not acid.is_empty() else ""
			ps_acid_name = str(acid[0].name) if not acid.is_empty() else ""
			ps_acid_sheets = float(acid[0].sheets) if not acid.is_empty() else 0.0
			ps_mood = float(pz.get("mood", 1.0))
		var dz: Dictionary = snap.get("dealer", {})
		dealer = not dz.is_empty()
		if dealer:
			dl_cat = dz.cat
			dl_cars = int(dz.cars)
			dl_trucks = int(dz.trucks)
			dl_last_car = dz.last_car
			dl_last_truck = dz.last_truck
			dl_insurance = int(dz.insurance)
			dl_auto = bool(dz.auto)
			dl_fleet_line = ("%d car%s to drive, %d truck%s on the runs: %d km/h, %d%% cover, %d%% steel; insurance $%s an hour" % [dl_cars, "" if dl_cars == 1 else "s", dl_trucks, "" if dl_trucks == 1 else "s",
				int(dz.speed), int(dz.cover), int(dz.steel), Py.money(dl_insurance)])
		var cz: Dictionary = snap.get("casino", {})
		casino = not cz.is_empty()
		if casino:
			cs_status = str(cz.get("status", ""))
			if cz.has("stake"):  # the owners' view
				cs_trading = bool(cz.get("trading", false))
				cs_stake_pct = int(round(100.0 * float(cz.stake)))
				cs_stake_price = int(cz.stake_price)
				cs_can_buy = float(cz.stake) < float(cz.stake_max) - 0.001
				cs_owed = int(cz.owed)
				cs_heat = int(cz.heat)
				cs_unrest = int(cz.unrest)
				cs_rival = int(cz.rival)
				cs_rival_name = str(cz.rival_name)
				cs_rival_buyout = int(cz.rival_buyout)
				cs_bought_out = bool(cz.bought_out)
				cs_gross_hour = int(cz.gross_hour)
				cs_share_hour = int(cz.share_hour)
				cs_skim_pct = int(round(100.0 * float(cz.skim)))
				cs_family_pct = int(round(100.0 * float(cz.family_cut)))
				cs_act = str(cz.act)
				cs_general_payoff = int(cz.general_payoff)
				cs_uprising_min = int(ceil(float(cz.uprising_s) / 60.0))
				cs_evac_total = int(cz.evac_cash) + int(cz.evac_stake)
				cs_dark_note = ("A raid or a fire: %d more minutes." % int(ceil(float(cz.dark_s) / 60.0))) if int(cz.dark_s) > 0 else "The island is not in a state to gamble."
				var best: Dictionary = {}
				for st in cz.get("stashes", []):
					if best.is_empty() or int(st.cash) > int(best.cash):
						best = st
				cs_has_cash = not best.is_empty() and int(cz.cage_left) >= 100 and int(cz.cage_shut_s) == 0 and int(cz.dark_s) == 0
				cs_stash_id = str(best.get("id", ""))
				cs_launder_n = mini(int(best.get("cash", 0)), int(cz.cage_left))
				cs_cash_line = ("$%s of the $%s at %s; the cage has $%s left this hour" % [Py.money(cs_launder_n), Py.money(int(best.get("cash", 0))), str(best.get("name", "")),
					Py.money(int(cz.cage_left))]) if not best.is_empty() else "no street cash in the stashes"
				cs_launder_line = "The Family and the General took their cut."
			else:  # the law's view
				cs_case = int(cz.get("case", 0))
				cs_wiretap = int(cz.get("wiretap", 0))
				cs_audit = int(cz.get("audit", 0))
				cs_raid = int(cz.get("raid", 0))
				cs_raid_case = int(cz.get("raid_case", 0))
				cs_cage_note = ("shut for the audit: %d more minutes" % int(ceil(float(cz.audit_s) / 60.0))) if int(cz.get("audit_s", 0)) > 0 else "open"
				cs_closed_note = ("The house is dark for %d minutes." % int(ceil(float(cz.closed_s) / 60.0))) if int(cz.get("closed_s", 0)) > 0 else ""

	func _do(name: String, args := {}) -> bool:
		pending = true
		var r: Array = await cmd_fn.call(name, args)
		pending = false
		if cancelled:
			return false
		result = "" if r[0] else str(r[1])
		refresh()
		return r[0]

	func money_s(v: int) -> String:
		return "$" + Py.money(v)

	# the Family
	func take() -> bool:
		return await _do("family_accept", {"id": offer_id})

	func refuse() -> bool:
		return await _do("family_decline", {"id": offer_id})

	func press() -> bool:
		return await _do("family_probe", {"id": offer_id})

	func pay() -> bool:
		return await _do("pay_tribute")

	func stall() -> bool:
		return await _do("family_stall")

	# the island
	func buy_passage() -> bool:
		return await _do("buy_passage")

	func mules() -> bool:
		return await _do("island_ship", {"method": "mules", "amount": 4})

	func container() -> bool:
		return await _do("island_ship", {"method": "ship", "amount": 500})

	# the Sunrise Collective
	func barter_best() -> bool:
		return await _do("acid_barter", {"stash": ps_best_id, "lb": float(ps_best_lb)})

	func barter_hundred() -> bool:
		return await _do("acid_barter", {"stash": ps_best_id, "lb": 100.0})

	func sell_acid() -> bool:
		return await _do("acid_sell", {"sheets": ps_acid_sheets if ps_acid_id != "" else ps_held, "stash": ps_acid_id})

	func toggle_acid_auto() -> bool:
		return await _do("acid_auto", {"on": not ps_auto})

	# the dealership
	func dl_price(id: String) -> int:
		return int(dl_cat.get(id, [0])[0])

	func dl_can(id: String) -> bool:
		return bool(dl_cat.get(id, [0, false])[1])

	func buy_vehicle(id: String) -> bool:
		return await _do("buy_vehicle", {"id": id})

	func sell_car() -> bool:
		return await _do("sell_vehicle", {"serial": int(dl_last_car.get("serial", 0))})

	func sell_truck() -> bool:
		return await _do("sell_vehicle", {"serial": int(dl_last_truck.get("serial", 0))})

	func toggle_fleet_auto() -> bool:
		return await _do("fleet_auto", {"on": not dl_auto})

	# the casino
	func buy_stake() -> bool:
		return await _do("casino", {"do": "stake"})

	func collect() -> bool:
		return await _do("casino", {"do": "collect"})

	func launder() -> bool:
		return await _do("casino", {"do": "launder", "stash": cs_stash_id, "amount": cs_launder_n})

	func pay_general() -> bool:
		return await _do("casino", {"do": "general"})

	func buy_out() -> bool:
		return await _do("casino", {"do": "rival"})

	func evacuate() -> bool:
		return await _do("casino", {"do": "evacuate"})

	func wiretap() -> bool:
		return await _do("casino_case", {"do": "wiretap"})

	func audit() -> bool:
		return await _do("casino_case", {"do": "audit"})

	func raid() -> bool:
		return await _do("casino_case", {"do": "raid"})

	# the payroll
	func has_cand(i: int) -> bool:
		return i < cand.size()

	func cand_line(i: int) -> String:
		if i >= cand.size():
			return ""
		var c: Dictionary = cand[i]
		var sk := float(c.skill)
		return "%s, a %s - %s, $%d a payday. (%s)" % [c.name, Payroll.ROLES[c.role][2], "sharp" if sk >= 0.7 else ("solid" if sk >= 0.4 else "green"),
			int(c.wage), c.hint]

	func take_on(i: int) -> bool:
		if i < 0 or i >= cand.size():
			result = "Candidate is no longer available."
			return false
		return await _do("hire_worker", {"id": cand[i].id})

	func crew_bonus() -> bool:
		return await _do("pay_bonus")

	func jailed_name() -> String:
		return "" if jailed.is_empty() else "%s (%s)" % [jailed[0].name, Payroll.ROLES[jailed[0].role][2]]

	func lawyer_for_jailed() -> bool:
		if jailed.is_empty():
			result = "No crew member needs a lawyer."
			return false
		return await _do("pay_worker_lawyer", {"id": jailed[0].id})

	## The whole payroll, one line each, for "Who's working for me?" - where they are and what
	## they're doing, not just a headcount (crew.dialogue).
	func roster_text() -> String:
		if crew_list.is_empty():
			return "Nobody on the payroll yet."
		var lines := []
		for w in crew_list:
			lines.append("- %s, %s: %s." % [w.name, Payroll.ROLES[w.role][2], w.doing])
		return "
".join(lines)

	# the buyers
	const LOT := {"cocaine": 20, "marijuana": 200, "guns": 5}

	func sale_lot(buyer: String, good: String) -> int:
		return 4 if campaign_chapter == 9 and buyer == "agency" and good == "guns" else LOT[good]

	func _have(good: String) -> int:
		return {"cocaine": coke, "marijuana": weed, "guns": rifles}.get(good, 0)

	func can_sell(buyer: String, good: String) -> bool:
		var q: Dictionary = quotes.get(buyer, {}).get(good, {})
		return not q.is_empty() and str(q.get("why", "x")) == "" and int(q.get("room", 0)) > 0 and _have(good) > 0

	func quote_line(buyer: String, good: String) -> String:
		var q: Dictionary = quotes.get(buyer, {}).get(good, {})
		var n := mini(mini(sale_lot(buyer, good), int(q.get("room", 0))), _have(good))
		if good == "guns":
			return "%d rifles at $%s each" % [n, Py.money(int(q.get("price", 0.0)))]
		return "%d lb of %s at $%s a pound" % [n, "grass" if good == "marijuana" else "cocaine", Py.money(int(q.get("price", 0.0)))]

	func sell(buyer: String, good: String) -> bool:
		return await _do("sell_product", {"buyer": buyer, "good": good, "qty": sale_lot(buyer, good), "tier": "rifle"})

	func buyer_status() -> String:
		var lines := []
		for buyer in ["family", "agency", "rival"]:
			var offers: Dictionary = quotes.get(buyer, {})
			if offers.is_empty():
				lines.append("%s: no offer available yet" % buyer)
			for good in offers:
				var q: Dictionary = offers[good]
				var reason := str(q.get("why", ""))
				if reason == "" and _have(good) <= 0:
					reason = "no stock held"
				if reason == "" and int(q.get("room", 0)) <= 0:
					reason = "buyer has no capacity right now"
				lines.append("%s / %s: %s" % [buyer, good, reason if reason != "" else "available; review the sale before committing"])
		return "; ".join(lines)

	func corners_line() -> String:
		var parts := []
		for m in corners:
			var c: Dictionary = corners[m]
			if int(c.ours) + int(c.theirs) > 0:
				parts.append("%s: %d of ours, %d of theirs" % [m, int(c.ours), int(c.theirs)])
		return ", ".join(parts) if not parts.is_empty() else "nobody on the corners yet - hire dealers (Manny)"

	# the court
	func has_filed(kind: String) -> bool:
		return filed.has(kind)

	func post_bail(how: String) -> bool:
		return await _do("court_bail", {"how": how})

	func hire(tier: String) -> bool:
		return await _do("court_hire", {"tier": tier})

	func move(kind: String) -> bool:
		return await _do("court_motion", {"kind": kind})

	func lean_on_witness() -> bool:
		return await _do("court_tamper")

	func pay_judge() -> bool:
		return await _do("court_bribe")

	func plead() -> bool:
		return await _do("court_plea")

	func cooperate() -> bool:
		return await _do("court_cooperate")

	func appeal() -> bool:
		return await _do("court_appeal")

	func wait() -> bool:
		return await _do("court_wait")
