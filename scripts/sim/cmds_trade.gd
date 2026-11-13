extends RefCounted
## Stateless trade commands; the passed Session owns all state.

static func _cmd_casino(role: String, a: Dictionary, session: Session):
	if session.casino == null:
		return "There is no casino in this game."
	var err := ""
	match str(a.get("do", "")):
		"stake":
			err = session.casino.buy_stake()
		"collect":
			err = session.casino.collect()
		"launder":
			err = session.casino.launder(str(a.get("stash", "")), int(a.get("amount", 0)))
		"general":
			err = session.casino.pay_general()
		"rival":
			err = session.casino.buy_out_rival()
		"evacuate":
			err = session.casino.evacuate()
		_:
			err = "Stake, collect, launder, general, rival or evacuate."
	return err if err != "" else null


static func _cmd_acid_barter(role: String, a: Dictionary, session: Session):
	if session.psych == null:
		return "There is no Collective in this game."
	var err := session.psych.barter(str(a.get("stash", "")), float(session._num(a, "lb", 0)))
	return err if err != "" else null


## The weekly black market (D-95): buy offer `i`.
static func _cmd_black_market_buy(role: String, a: Dictionary, session: Session):
	if session.black_market == null:
		return "There is no black market in this game."
	var err: String = session.black_market.buy(int(session._num(a, "i", -1)))
	return err if err != "" else null


static func _cmd_acid_sell(role: String, a: Dictionary, session: Session):
	if session.psych == null:
		return "There is no Collective in this game."
	var err := session.psych.sell(float(session._num(a, "sheets", 1e9)), str(a.get("stash", "")))
	return err if err != "" else null


static func _cmd_acid_auto(role: String, a: Dictionary, session: Session):
	if session.psych == null:
		return "There is no Collective in this game."
	var err := session.psych.set_auto(bool(a.get("on", false)))
	return err if err != "" else null


static func _cmd_buy_vehicle(role: String, a: Dictionary, session: Session):
	if session.dealer == null:
		return "There is no dealership in this game."
	var err := session.dealer.buy(str(a.get("id", "")))
	return err if err != "" else null


static func _cmd_sell_vehicle(role: String, a: Dictionary, session: Session):
	if session.dealer == null:
		return "There is no dealership in this game."
	var err := session.dealer.sell(int(a.get("serial", 0)))
	return err if err != "" else null


static func _cmd_use_vehicle(role: String, a: Dictionary, session: Session):
	if session.dealer == null:
		return "There is no dealership in this game."
	var err := session.dealer.use_car(int(a.get("serial", 0)))
	return err if err != "" else null


static func _cmd_fleet_auto(role: String, a: Dictionary, session: Session):
	if session.dealer == null:
		return "There is no dealership in this game."
	var err := session.dealer.set_auto(bool(a.get("on", false)))
	return err if err != "" else null


static func _cmd_casino_play(role: String, a: Dictionary, session: Session):
	if session.casino == null:
		return "There is no casino in this game."
	var err := session.casino.play(str(a.get("game", "")), a)
	return err if err != "" else null


static func _cmd_casino_case(role: String, a: Dictionary, session: Session):
	if session.casino == null:
		return "There is no casino in this game."
	var err := session.casino.case_action(str(a.get("do", "")))
	return err if err != "" else null


static func _cmd_race_enter(role: String, a: Dictionary, session: Session):
	if session.races == null:
		return "There is no arena here."
	var err: String = session.races.enter(str(a.get("id", "")), int(a.get("bet", 0)), str(a.get("on", "win")))
	return err if err != "" else null


static func _cmd_island_ship(role: String, a: Dictionary, session: Session):
	if session.island == null:
		return "No island in this game."
	var err := session.island.ship(str(a.get("method", "")), int(session._num(a, "amount", 0)))
	return err if err != "" else null


static func _cmd_buy_passage(role: String, a: Dictionary, session: Session):
	if session.island == null:
		return "No island in this game."
	var err := session.island.buy_passage()
	return err if err != "" else null


static func _cmd_airport_crackdown(role: String, a: Dictionary, session: Session):
	if session.island == null:
		return "No island in this game."
	if session.law_funds < 2000.0:
		return "Need $2,000 in funds."
	session.move_law_funds(-2000.0, "outside:state", "fee")
	session.island.crackdown_until = session.time + 1800.0
	session.law_say("Customs profile every passenger off the island flights for 30 min")
	return null


static func _cmd_port_inspections(role: String, a: Dictionary, session: Session):
	if session.island == null:
		return "No island in this game."
	if session.law_funds < 3000.0:
		return "Need $3,000 in funds."
	session.move_law_funds(-3000.0, "outside:state", "fee")
	session.island.inspections_until = session.time + 1800.0
	session.law_say("Every container from Isla Soberana opened for 30 min")
	return null


static func _cmd_sell_product(role: String, a: Dictionary, session: Session):
	if session.trade == null:
		return "No trade in this game."
	var g := str(a.get("good", ""))
	if not g in ["cocaine", "marijuana", "guns"]:
		return "Sell what?"
	var err := session.trade.sell(str(a.get("buyer", "")), g, float(session._num(a, "qty", 0)), str(a.get("tier", "rifle")), str(a.get("from", "")))
	return err if err != "" else null


## Stock bought upfront (DESIGN 51.2): order `lb` of `good` from `contact` (family, agency), brought to `stash` in a window.
static func _cmd_stock_order(_role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No stash houses in this game."
	var err: String = ""
	if str(a.get("good", "")) == "guns":  # the gun dealer, on the same flow: `crates` of `tier`
		err = session.logistics.pickups.order_guns(str(a.get("tier", "")), int(session._num(a, "crates", 1)), str(a.get("stash", "")))
	elif str(a.get("good", "")) == "ammo":  # ... and crates of rounds for `tier` (DESIGN 94)
		err = session.logistics.pickups.order_ammo(str(a.get("tier", "")), int(session._num(a, "crates", 1)), str(a.get("stash", "")))
	else:
		err = session.logistics.pickups.order(str(a.get("contact", "")), str(a.get("good", "")), float(session._num(a, "lb", 0)), str(a.get("stash", "")))
	return err if err != "" else null


## Answer the price war under way (loop idea 6): `answer` is "match" or "hold".
static func _cmd_price_war(_role: String, a: Dictionary, session: Session):
	if session.trade == null or session.trade.wars == null:
		return "No price wars in this game."
	var w: Dictionary = session.trade.wars.war
	var err: String = session.trade.wars.answer(int(session._num(a, "id", int(w.get("id", -1)))), str(a.get("answer", "")))
	return err if err != "" else null


## Call off pickup `id` (the money paid is lost).
static func _cmd_pickup_cancel(_role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No stash houses in this game."
	var err: String = session.logistics.pickups.cancel(int(session._num(a, "id", -1)))
	return err if err != "" else null


## Logistics: a truck of product between stashes, or to a buyer's meet.
static func _cmd_move_goods(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: the product is just there."
	var g := str(a.get("good", ""))
	if not g in session.logistics.goods():
		return "Move what?"
	var err: String = session.logistics.send(str(a.get("from", "")), str(a.get("to", "")), g, float(session._num(a, "lb", 0)))
	return err if err != "" else null


## Logistics: keep the dealers' corners stocked by truck from the stashes that hold product elsewhere (on or off).
static func _cmd_auto_supply(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: the product is just there."
	var on = a.get("on")
	session.logistics.auto_supply = (not session.logistics.auto_supply) if on == null else Py.truthy(on)
	session.say("Dealers' corners %s." % ("restocked by truck when they run dry" if session.logistics.auto_supply else "left to you: move product yourself (Dispatch)"))
	return null


## Logistics: a truck of cash (to the HQ, usually).
static func _cmd_move_cash(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: money is money."
	var err: String = session.logistics.send(str(a.get("from", "")), str(a.get("to", Logistics.HQ)), "cash", float(session._num(a, "amount", 1e12)))
	return err if err != "" else null


## Logistics: ONE truck through several stashes, taking the cash at each, to the club (or another stash).
## {stops: [ids], to, plan: true to let the planner order them}.
static func _cmd_cash_round(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: money is money."
	var stops: Array = []
	for x in a.get("stops", []):
		stops.append(str(x))
	var to := str(a.get("to", Logistics.HQ))
	if bool(a.get("plan", false)) and stops.size() >= 2:
		stops = session.logistics.plan_order(stops, session.logistics.pos(to) if to != "" else session.logistics.hq_pos())
	var err: String = session.logistics.cash_round(stops, to)
	return err if err != "" else null


## Logistics: ONE truck loaded at `from` that drops `lb` of `good` at each stop in turn.
static func _cmd_goods_round(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: money is money."
	var stops: Array = []
	for x in a.get("stops", []):
		stops.append(str(x))
	var err: String = session.logistics.goods_round(str(a.get("from", "")), stops, str(a.get("good", "")), float(session._num(a, "lb", 1e9)))
	return err if err != "" else null


static func _cmd_load_cash(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game."
	var err: String = session.logistics.load_cash(float(session._num(a, "amount", 1e12)))
	return err if err != "" else null


static func _cmd_unload_cash(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game."
	var err: String = session.logistics.unload_cash()
	return err if err != "" else null


static func _cmd_pay_tribute(role: String, a: Dictionary, session: Session):
	if session.family == null or session.family.gone:
		return "No Family in this game."
	var err := session.family.pay_tribute()
	return err if err != "" else null
