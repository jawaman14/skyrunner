extends RefCounted
## Stateless ground commands; the passed Session owns all state.

static func _cmd_sell_weapons(role: String, a: Dictionary, session: Session):
	if not Arsenal.REALISM:
		return "No arsenal."
	if not session.unlocked("guns"):
		return "No gun dealer will talk to us yet."
	var tier := str(a.get("tier", ""))
	var n := int(session._num(a, "n", 1))
	if not Arsenal.TIERS.has(tier) or n <= 0:
		return "Sell what?"
	var k: int = session.arsenals["org"].take(tier, n)
	if k == 0:
		return "None of those in the armoury."
	var pay := session.weapon_price(tier, false) * k
	session.money += pay
	session.econ.record_delivery("guns", "town")
	session.say("Sold %d %s to the fence: +$%s" % [k, Arsenal.TIERS[tier].name.to_lower(), Py.money(pay)])
	return null


static func _cmd_buy_weapons(role: String, a: Dictionary, session: Session):
	if not Arsenal.REALISM:
		return "No arsenal."
	if not session.unlocked("guns"):
		return "No gun dealer will talk to us yet."
	var tier := str(a.get("tier", ""))
	var n := int(session._num(a, "n", 1))
	if not Arsenal.TIERS.has(tier) or n <= 0:
		return "Buy what?"
	var cost := session.weapon_price(tier, true) * n
	if session.money < cost:
		return "Need $%s." % Py.money(cost)
	session.money -= cost
	session.arsenals["org"].add(tier, n)
	session.say("Bought %d %s from a dealer: -$%s" % [n, Arsenal.TIERS[tier].name.to_lower(), Py.money(cost)])
	return null


static func _cmd_set_cache(role: String, a: Dictionary, session: Session):
	if not Arsenal.REALISM:
		return "No arsenal."
	var id := str(a.get("stash", ""))
	if id != "" and (session.stash_net == null or session.stash_net.get_stash(id) == null or session.stash_net.get_stash(id).burned):
		return "No such stash."
	session.arsenals["org"].cache = id
	session.say("The guns are kept at %s now." % ("the club" if id == "" else session.stash_net.get_stash(id).name))
	return null


static func _cmd_squad_order(role: String, a: Dictionary, session: Session):
	if session.ground == null:
		return "No ground war here."
	var q = session.ground.get_squad(str(a.get("id", "")))
	if q == null or q.faction != session._faction_of(role):
		return "Not one of ours."
	var o: Dictionary = a.get("order", {}) if a.get("order") is Dictionary else {"type": str(a.get("order", ""))}
	for k in ["x", "y", "stash", "market", "squad", "job_id"]:
		if a.has(k) and not o.has(k):
			o[k] = a[k]
	var err: String = session.ground.order(q, o)
	if err != "":
		return err
	q.human = true
	if o.get("type", "") == "stakeout" and o.has("stash"):
		session.ground.stakeouts[str(o.stash)] = q.id
	return null


## On foot, an order to the nearest of our squads: {what: come | hold | charge | fall_back, x, y} (where the man stands).
static func _cmd_field_order(role: String, a: Dictionary, session: Session):
	if session.ground == null:
		return "No ground war here: nobody to command."
	var r: Array = session.ground.field_order(session._faction_of(role), Vector2(float(session._num(a, "x", 0.0)), float(session._num(a, "y", 0.0))), str(a.get("what", "")))
	if r[0] != "":
		return r[0]
	session.say(str(r[1]))
	return null


## The collectors and the prisoners: {what: policy (market, mode) | ransom | turn | release}.
static func _cmd_rackets(role: String, a: Dictionary, session: Session):
	if session.rackets == null:
		return "Nobody collects for us here."
	var err := ""
	match str(a.get("what", "")):
		"policy":
			err = session.rackets.set_policy(str(a.get("market", "")), str(a.get("mode", "")))
		"ransom":
			err = session.rackets.ransom()
		"turn":
			err = session.rackets.turn()
		"release":
			err = session.rackets.release()
		_:
			err = "Policy, ransom, turn or release."
	return err if err != "" else null


## Build at a stash house: {stash, what: vault | guard}.
static func _cmd_stash_works(role: String, a: Dictionary, session: Session):
	var err := StashWorks.build(session, str(a.get("stash", "")), str(a.get("what", "")))
	return err if err != "" else null


static func _cmd_recruit_squad(role: String, a: Dictionary, session: Session):
	if session.ground == null:
		return "No ground war here."
	var r = session.ground.recruit(session._faction_of(role), str(a.get("kind", "foot")))
	if r is String:
		return r
	var text := "Raised %s: %s" % [r.id, Arsenal.describe(r.loadout)]
	if r.faction == "org":
		session.say(text)
	else:
		session.law_say(text)
	return null


static func _cmd_disband_squad(role: String, a: Dictionary, session: Session):
	if session.ground == null:
		return "No ground war here."
	var q = session.ground.get_squad(str(a.get("id", "")))
	if q == null or q.faction != session._faction_of(role):
		return "Not one of ours."
	if q.fight != null:
		return "They're in a firefight."
	session.ground.disband(q)
	return null


## An escort for one of our trucks: the nearest free squad of ours rides with it
## (a checkpoint gets a fight instead of a search; an ambush meets guns).
static func _cmd_escort_truck(role: String, a: Dictionary, session: Session):
	if session.ground == null or session.stash_net == null:
		return "No street war in this game: nobody to escort it."
	var id := int(session._num(a, "job_id", -1))
	var t = Py.first(session.stash_net.trucks, func(x): return x.job_id == id)
	if t == null:
		return "No such truck on the road."
	if session.ground.squads.any(func(q): return q.faction == "org" and int(q.order.get("job_id", -1)) == id and q.state != "gone"):
		return "It already has an escort."
	var p: Array = t.pos(session.time)
	var free: Array = session.ground._free("org")
	if free.is_empty():
		return "No squad free to ride with it (the lieutenant raises them)."
	var q = Py.min_by(free, func(s): return s.pos().distance_to(Vector2(p[0], p[1])))
	var err: String = session.ground.order(q, {"type": "escort", "job_id": id})
	if err != "":
		return err
	session.say("%s rides with the truck%s." % [q.id, (" to " + session.logistics.truck_info(t).to) if session.logistics != null else ""])
	return null


## Logistics: the whole armoury by truck to a stash or the club.
static func _cmd_move_armoury(role: String, a: Dictionary, session: Session):
	if session.logistics == null:
		return "No logistics in this game: the guns are just there."
	var err: String = session.logistics.send_guns(str(a.get("to", "")), {})
	return err if err != "" else null


static func _cmd_street_sweep(role: String, a: Dictionary, session: Session):
	if session.trade == null:
		return "No street trade in this game."
	var err := session.trade.sweep(str(a.get("market", "")))
	return err if err != "" else null


static func _cmd_raid_stash(role: String, a: Dictionary, session: Session):
	if session.stash_net == null:
		return "No stash houses on this map."
	return session._raid(str(a.get("id", "")))
