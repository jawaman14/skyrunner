class_name Casino
extends RefCounted
## The Hotel Cielo: the Family's casino on Isla Soberana, as Havana had them in the 1950s. A business you do through a menu
## (the phone, Shift+K, a desk's Z), not a place you walk into.
##
## **The house.** It takes about HOUSE_PER_HOUR a night and day, more with tourists (the island's weather and politics move
## them) and a headliner on the bill, less when the rival casino is leaning on it. The General skims a share of the gross
## (more the less he likes you), the Family another cut, and the rest is the owners': you hold a **stake** in tenths, up to
## STAKE_MAX, bought from the Family at STAKE_PRICE a tenth, and your share builds up in the house's account for you to **collect**.
## **The cage** is chips in, clean cheques out: street cash from any stash house goes in and comes out in the safe, minus the
## Family's cut and the General's skim, up to CAGE_CAP an hour. It is the way round trucking cash home, and the way the task
## force finds you: every dollar through the cage warms the house's heat, and heat becomes the task force's case. What goes
## through it also cleans the money trail: the runner's own case cools by CAGE_RELIEF a thousand.
## **The General** can be paid: it cools the heat and the island's unrest and warms his regard.
## **The rival** (the Lucky Palm) leans on the house until it is bought out or it burns something.
## **The task force** works the casino from its desk (a wiretap in the counting room, an audit of the cage, a raid once the case is
## strong enough); the AI chief does it by itself when the heat is high.
## **The end.** The island's unrest rises with the General's neglect and the house's greed; at the top the government falls (Havana,
## 1959): a short uprising in which you can evacuate what you can carry, then the house is seized. In the story it comes after the
## chapter's goals are met.
##
## Opt-in with the session option `casino: true` or the story chapter 'The House'; needs the Family and the island. Behind
## `Casino.ENABLED` (and `Casino.REVOLUTION`). Its dice are their own stream (seed + 939).

static var ENABLED := true
static var REVOLUTION := true

const NAME := "Hotel Cielo"
const RIVAL := "the Lucky Palm"
const RIVAL_BOSS := "Dante Varga"
const HOUSE_PER_HOUR := 16000.0  ## the gross, before the skims
const FAMILY_CUT := 0.12
const SKIM_BEST := 0.06
const SKIM_WORST := 0.14
const STAKE_STEP := 0.1
const STAKE_MAX := 0.4
const STAKE_PRICE := 9000
const CAGE_CAP := 8000  ## an hour
const CAGE_FAMILY_CUT := 0.08
const CAGE_RELIEF := 1.5  ## suspicion off the runner's case per $1,000 washed: the money trail is cleaner
const HEAT_PER_1K := 0.8
const HEAT_DECAY_PER_MIN := 0.25
const CASE_PER_MIN := 0.2  ## at full heat
const AUDIT_S := 1800.0
const RAID_S := 1800.0
const RAID_CASE := 50.0
const WIRETAP := 3000
const AUDIT := 2500
const RAID := 5000
const GENERAL_PAYOFF := 3000
const RIVAL_BUYOUT := 20000
const UNREST_PER_MIN := 0.15
const UPRISING_S := 1200.0
const EVAC_OWED := 0.7
const EVAC_STAKE := 0.4
const ACTS := ["Luz Casares and her orchestra", "Los Hermanos Vidal", "Mimi Delacroix, straight from Paris", "The Cielo Sisters"]
const TOURISM := {"calm": 1.0, "boatlift": 1.3, "glut": 1.0, "hurricane": 0.4, "shortage": 0.8, "purge": 0.5}

var sess
var status := "open"  ## open | uprising | seized
var stake := 0.0  ## our share of the house, 0..STAKE_MAX
var owed := 0  ## our share, in the house's account
var heat := 0.0  ## 0..100: how loudly the house's money is talking
var case_ := 0.0  ## 0..100: the task force's case against the house
var unrest := 0.0  ## 0..100: the island's patience
var rival := 0.0  ## 0..100: the Lucky Palm's pressure
var bought_out_until := -1.0
var closed_until := -1.0  ## a raid, a fire
var audit_until := -1.0  ## the cage is under audit
var uprising_until := -1.0
var act := ""  ## the headliner
var act_until := -1.0
var cage_log: Array = []  ## [t, amount]: what went through the cage lately
var laundered := 0  ## all told
var fees := 0
var collected := 0
var last := ""
var force_uprising_at := -1.0  ## the story sets this when its goals are met
var rng: PyRandom
var _t := 0.0
var _evt_t := 0.0
var _law_t := 0.0


func _init(sess_) -> void:
	sess = sess_
	rng = PyRandom.new()
	rng.seed(int(sess.seed) + 939)


func active() -> bool:
	return ENABLED and sess.family != null and sess.island != null


## Whether the house is trading right now.
func trading() -> bool:
	return active() and status == "open" and sess.time >= closed_until and sess.island.open()


func skim() -> float:
	var rel: float = sess.island.relations
	return lerpf(SKIM_WORST, SKIM_BEST, clampf(rel / 100.0, 0.0, 1.0))


func tourism() -> float:
	return float(TOURISM.get(sess.island.status, 1.0)) * (1.5 if sess.time < act_until else 1.0)


## The house's gross per hour now.
func gross_per_hour() -> float:
	if not trading():
		return 0.0
	var f := tourism() * (1.0 - rival / 200.0) * (1.1 if sess.time < bought_out_until else 1.0)
	return HOUSE_PER_HOUR * f


## What our stake earns per hour now.
func share_per_hour() -> float:
	return gross_per_hour() * (1.0 - skim() - FAMILY_CUT) * stake


func cage_left() -> int:
	var used := 0
	for e in cage_log:
		if sess.time - float(e[0]) < 3600.0:
			used += int(e[1])
	return maxi(0, CAGE_CAP - used)


# ------------------------------------------------------------------ the tick
func update(dt: float) -> void:
	if not active() or status == "seized":
		return
	var min_ := dt / 60.0
	if status == "open":
		var rate := share_per_hour() * dt / 3600.0
		owed += int(rate)
		_t += rate - int(rate)
		if _t >= 1.0:
			owed += int(_t)
			_t -= int(_t)
		heat = maxf(0.0, heat - HEAT_DECAY_PER_MIN * min_)
		case_ = clampf(case_ + (heat / 100.0) * CASE_PER_MIN * min_ - 0.05 * min_, 0.0, 100.0)
		rival = minf(100.0, rival + (0.08 if sess.time >= bought_out_until else 0.0) * min_)
		var turmoil := 0.5 if sess.island.status in ["purge", "hurricane", "shortage"] else 0.0
		unrest = minf(100.0, unrest + (UNREST_PER_MIN + turmoil + (heat / 100.0) * 0.25 - sess.island.relations / 100.0 * 0.1) * min_)
		_events(dt)
		_law_ai(dt)
		var due: bool = REVOLUTION and (unrest >= 100.0 or (force_uprising_at >= 0.0 and sess.time >= force_uprising_at))
		if due:
			_uprising()
	elif status == "uprising" and sess.time >= uprising_until:
		_fall()


func _events(dt: float) -> void:
	_evt_t += dt
	if _evt_t < 300.0:
		return
	_evt_t = 0.0
	if sess.time >= act_until and rng.random() < 0.08:
		act = ACTS[rng.randint(0, ACTS.size() - 1)]
		act_until = sess.time + 3600.0
		heat = minf(100.0, heat + 3.0)
		last = "%s opens at the %s: the tourists are in." % [act, NAME]
		sess.say("NEWS - " + last)
	if rng.random() < 0.04 and trading():
		var win := int(share_per_hour() * 1.5 + 1500.0 * stake / STAKE_MAX)
		owed += win
		heat = minf(100.0, heat + 4.0)
		last = "A high roller at the %s: the house is $%s up on one night." % [NAME, Py.money(int(gross_per_hour() * 0.5))]
		sess.say("NEWS - " + last)
	if rival >= 100.0 and sess.time >= closed_until:
		rival = 40.0
		closed_until = sess.time + 1800.0
		var loss := int(owed * 0.1)
		owed -= loss
		last = "A fire in the %s's kitchens: %s is blamed. The house is dark for half an hour." % [NAME, RIVAL_BOSS]
		sess.say("NEWS - " + last)


## The AI chief works a hot casino by itself when no human holds the desk.
func _law_ai(dt: float) -> void:
	_law_t += dt
	if _law_t < 1200.0:
		return
	_law_t = 0.0
	if sess.police.controller != "ai" or heat < 55.0:
		return
	if case_ >= RAID_CASE + 15.0 and sess.law_funds >= RAID and rng.random() < 0.5:
		case_action("raid")
	elif sess.law_funds >= AUDIT and sess.time >= audit_until and rng.random() < 0.5:
		case_action("audit")
	elif sess.law_funds >= WIRETAP and rng.random() < 0.4:
		case_action("wiretap")


# ------------------------------------------------------------------ what the owners do
func why_not() -> String:
	if not ENABLED or sess.family == null or sess.island == null:
		return "There is no casino in this game."
	if status == "seized":
		return "The %s is in other hands now." % NAME
	if status == "uprising":
		return "The %s is shuttered: there is shooting in the streets." % NAME
	if not sess.island.open():
		return "The island is closed."
	if sess.family.gone:
		return "The Family is gone: nobody on the island will deal with you."
	return ""


func buy_stake() -> String:
	var err := why_not()
	if err != "":
		return err
	if stake >= STAKE_MAX - 0.001:
		return "You hold as much of the house as the Family will sell."
	if sess.money < STAKE_PRICE:
		return "A tenth of the house is $%s." % Py.money(STAKE_PRICE)
	sess.money -= STAKE_PRICE
	stake = minf(STAKE_MAX, stake + STAKE_STEP)
	sess.family.respect = minf(100.0, sess.family.respect + 3.0)
	last = "You hold %d%% of the %s." % [int(round(stake * 100.0)), NAME]
	sess.say(last)
	sess.bus.emit("casino_stake", sess.time, "", ["runner"], {"stake": stake})
	return ""


func collect() -> String:
	var err := why_not()
	if err != "":
		return err
	if owed <= 0:
		return "Nothing owed yet."
	var got := owed
	owed = 0
	sess.money += got
	collected += got
	sess.say("The cage pays out your share: $%s." % Py.money(got))
	return ""


## Street cash from `stash_id` through the cage.
func launder(stash_id: String, amount: int) -> String:
	var err := why_not()
	if err != "":
		return err
	if sess.time < closed_until:
		return "The house is dark."
	if sess.time < audit_until:
		return "The gaming commission has the books: the cage is shut until they leave."
	if sess.logistics == null:
		return "There is no street cash to move."
	var have: int = int(sess.logistics.cash.get(stash_id, 0))
	var n := mini(amount, mini(have, cage_left()))
	if have <= 0:
		return "There is no cash at that stash."
	if n < 100:
		return "The cage is full for the hour." if cage_left() < 100 else "Too little to bother the cage with."
	sess.logistics.cash[stash_id] = have - n
	var cut := int(round(float(n) * (CAGE_FAMILY_CUT + skim())))
	var net := n - cut
	sess.money += net
	fees += cut
	laundered += n
	cage_log.append([sess.time, n])
	Py.keep_last(cage_log, 24)
	heat = minf(100.0, heat + HEAT_PER_1K * float(n) / 1000.0)
	var rc = sess.police.case("runner")
	rc.suspicion = maxf(0.0, rc.suspicion - CAGE_RELIEF * float(n) / 1000.0)
	sess.say("The cage takes $%s in chips and writes you a cheque for $%s (the Family and the General took $%s)." % [Py.money(n), Py.money(net), Py.money(cut)])
	sess.bus.emit("casino_laundered", sess.time, "", ["runner"], {"amount": n, "net": net})
	return ""


func pay_general() -> String:
	var err := why_not()
	if err != "":
		return err
	if sess.money < GENERAL_PAYOFF:
		return "The General's aide wants $%s." % Py.money(GENERAL_PAYOFF)
	sess.money -= GENERAL_PAYOFF
	sess.island.relations = minf(100.0, sess.island.relations + 8.0)
	unrest = maxf(0.0, unrest - 10.0)
	heat = maxf(0.0, heat - 5.0)
	sess.say("An envelope reaches the General's aide: the island is a little calmer, and the commission a little blinder.")
	return ""


func buy_out_rival() -> String:
	var err := why_not()
	if err != "":
		return err
	if sess.time < bought_out_until:
		return "%s is already yours." % RIVAL
	if sess.money < RIVAL_BUYOUT:
		return "%s will go for $%s." % [RIVAL_BOSS, Py.money(RIVAL_BUYOUT)]
	sess.money -= RIVAL_BUYOUT
	rival = 0.0
	bought_out_until = sess.time + 6 * 3600.0
	sess.say("%s sells %s to the Family's friends. The tables fill." % [RIVAL_BOSS, RIVAL])
	return ""


## Get out with what can be carried (during the uprising).
func evacuate() -> String:
	if status != "uprising":
		return "There is nothing to get out of."
	var cash := int(float(owed) * EVAC_OWED)
	var sold := int(round(stake / STAKE_STEP * float(STAKE_PRICE) * EVAC_STAKE))
	sess.money += cash + sold
	sess.say("You get out on the last launch with $%s: your share and what the stake would fetch (the rest is the revolution's)." % Py.money(cash + sold))
	owed = 0
	stake = 0.0
	sess.family.respect = maxf(0.0, sess.family.respect - 5.0)
	_seize(true)
	return ""


# ------------------------------------------------------------------ the task force
func case_action(kind: String) -> String:
	if not ENABLED or sess.island == null or status != "open":
		return "There is nothing to work."
	match kind:
		"wiretap":
			if sess.law_funds < WIRETAP:
				return "Need $%s in funds." % Py.money(WIRETAP)
			sess.law_funds -= WIRETAP
			case_ = minf(100.0, case_ + 20.0)
			sess.law_say("CASINO: a microphone in the %s's counting room: the case is %d%%." % [NAME, int(case_)])
		"audit":
			if sess.law_funds < AUDIT:
				return "Need $%s in funds." % Py.money(AUDIT)
			if sess.time < audit_until:
				return "The commission is already in the cage."
			sess.law_funds -= AUDIT
			audit_until = sess.time + AUDIT_S
			case_ = minf(100.0, case_ + (25.0 if cage_left() < CAGE_CAP else 10.0))
			sess.law_say("CASINO: the gaming commission opens the cage's books for %d minutes (case %d%%)." % [int(AUDIT_S / 60.0), int(case_)])
			sess.say("The gaming commission is in the %s's cage: no cheques until they leave." % NAME)
		"raid":
			if case_ < RAID_CASE:
				return "The case is only %d%%: it needs %d%% before a judge will sign." % [int(case_), int(RAID_CASE)]
			if sess.law_funds < RAID:
				return "Need $%s in funds." % Py.money(RAID)
			sess.law_funds -= RAID
			var seized := int(float(owed) * 0.4)
			owed -= seized
			sess.law_funds += seized
			closed_until = sess.time + RAID_S
			heat = 20.0
			case_ = 0.0
			sess.family.respect = maxf(0.0, sess.family.respect - 8.0)
			sess.law_say("CASINO: a raid on the %s: the house is shut, $%s of its owners' money forfeited." % [NAME, Py.money(seized)])
			sess.say("NEWS - Federal agents and the island's police raid the %s. The Family's lawyers are on the first plane." % NAME)
		_:
			return "Wiretap, audit or raid."
	return ""


# ------------------------------------------------------------------ the revolution
func _uprising() -> void:
	status = "uprising"
	uprising_until = sess.time + UPRISING_S
	last = "The government of Isla Soberana has fallen: there are barricades in the streets and a mob at the %s's doors." % NAME
	sess.say("NEWS - " + last)
	sess.say("The %s is shuttered. You have %d minutes to get out: the Cielo menu has the launch." % [NAME, int(UPRISING_S / 60.0)])
	sess.law_say("NEWS - Revolution on Isla Soberana: the General is gone and the casinos are burning.")
	sess.island.purge()
	sess.island.status_until = sess.time + 3600.0
	sess.bus.emit("casino_uprising", sess.time, "", ["runner", "law"], {})


func _fall() -> void:
	sess.say("The %s falls to the revolution with your share inside it." % NAME)
	owed = 0
	stake = 0.0
	sess.family.respect = maxf(0.0, sess.family.respect - 20.0)
	_seize(false)


func _seize(out: bool) -> void:
	status = "seized"
	sess.island.relations = 25.0
	sess.island.price_mult = 1.2
	last = "The new men on Isla Soberana nationalise the %s." % NAME
	sess.bus.emit("casino_out", sess.time, "", ["runner"], {"evacuated": out})


# ------------------------------------------------------------------ views
func view(side: String) -> Dictionary:
	if not ENABLED or sess.family == null or sess.island == null:
		return {}
	if side == "law":
		return {"status": status, "case": int(case_), "audit_s": maxi(0, int(ceil(audit_until - sess.time))), "closed_s": maxi(0, int(ceil(closed_until - sess.time))),
			"raid_case": int(RAID_CASE), "wiretap": WIRETAP, "audit": AUDIT, "raid": RAID, "heat": int(heat), "act": act if sess.time < act_until else ""}
	var stashes := []
	if sess.logistics != null and sess.stash_net != null:
		for st in sess.stash_net.stashes:
			var c: int = int(sess.logistics.cash.get(st.id, 0))
			if c > 0 and not st.burned:
				stashes.append({"id": st.id, "name": st.name, "cash": c})
	return {"stashes": stashes, "name": NAME, "status": status, "stake": snappedf(stake, 0.01), "stake_price": STAKE_PRICE, "stake_max": STAKE_MAX, "owed": owed, "heat": int(heat),
		"unrest": int(unrest), "rival": int(rival), "rival_name": RIVAL, "rival_boss": RIVAL_BOSS, "rival_buyout": RIVAL_BUYOUT, "bought_out": sess.time < bought_out_until,
		"gross_hour": int(gross_per_hour()), "share_hour": int(share_per_hour()), "skim": snappedf(skim(), 0.01), "family_cut": FAMILY_CUT, "cage_family_cut": CAGE_FAMILY_CUT,
		"cage_left": cage_left(), "cage_cap": CAGE_CAP, "cage_shut_s": maxi(0, int(ceil(audit_until - sess.time))), "dark_s": maxi(0, int(ceil(closed_until - sess.time))),
		"act": act if sess.time < act_until else "", "uprising_s": maxi(0, int(ceil(uprising_until - sess.time))) if status == "uprising" else 0,
		"general_payoff": GENERAL_PAYOFF, "laundered": laundered, "fees": fees, "collected": collected, "last": last, "trading": trading(),
		"evac_cash": int(float(owed) * EVAC_OWED), "evac_stake": int(round(stake / STAKE_STEP * float(STAKE_PRICE) * EVAC_STAKE))}
