class_name Story
extends RefCounted
## The story: Costa Brava, 1979-1989. From a bush pilot flying square grouper
## for a boat dealer to the organisation the whole coast answers to.
##
## Each chapter opens part of the game - a system (Session.SYSTEMS) or a lock
## (guns, the payroll's soldiers and mules) - and sets a few goals that the
## systems themselves measure. The ramp is the point: you learn the trade before
## the war, the war before the Family, the Family before the court, and only
## then the island and the Company, each one alone first. The open mode (no
## Story) has every faction and mechanic from the first minute.
##
## Chapters reuse Campaign.Chapter/Objective, so the HUD, the briefing card and
## the desks show a chapter whichever mode set it.

## Keys a chapter can open besides the systems: what Session.unlocked() asks.
const LOCKS := ["guns", "role_soldier", "role_mule"]

## [year, title, briefing, opens, goals [[key, text, target]]]
const CHAPTERS := [
	[1979, "Square Grouper",
		"San Telmo, 1979. The Cessna is half the bank's, the charters don't cover the fuel,\n"
		+ "and Benny Ruiz at the boatyard knows men up in the hills with bales of grass.\n"
		+ "Buy it at the bush strips, fly it into our stash houses, and hire a kid or two\n"
		+ "to sell it on the corners [Phone > Manny Ortega]. Low money, low risk - for now.",
		["trade", "payroll", "chronicle"],
		[["weed_lb", "Fly 300 lb of marijuana into our stash houses", 300], ["dealers", "Put a street dealer on a corner", 1],
			["trade_earned", "Make $4,000 from the trade", 4000]]],
	[1980, "The Connection",
		"The boatlift brings a hundred thousand people across the straits, and a few of them
"
		+ "know the Colombians. Grass pays by the ton; the white stuff pays by the ounce.
"
		+ "And it's a business now: product sits in a stash, the money piles up on the corners,
"
		+ "and the growers want cash on the strip. Truck it, fly it, count it [Phone > Dispatch].
"
		+ "A dealership will sell you vans for the trucks and a car of your own [phone].",
		["logistics", "dealership"],
		[["cash_home", "Truck or fly $3,000 of street money home", 3000],
			["connected", "Get the call from the Colombian connection", 1],
			["dealership_buy", "Buy a vehicle at the dealership", 1, true, 2000]]],
	[1980, "Blotter",
		"Up in the hills, past the last paved road, a commune of chemists called the Sunrise Collective
"
		+ "turns out blotter acid by the sheet, and the kids on the festival circuit will buy every one.
"
		+ "They have no way to get grass; you have more than you can sell. A bread van will call at
"
		+ "your stash, and Nico Cozz, their chemist, will talk about changing the world [Phone > Sunrise Collective; Shift+C].
"
		+ "But you are not the only one who has noticed all that grass going up into the hills.
"
		+ "Somebody at the county office has a map with a pin in it.",
		["psychedelics"],
		[["acid_lb", "Trade 150 lb of grass for acid", 150], ["acid_sheets", "Sell 20 sheets through the circuit", 20]]],
	[1981, "Cocaine Cowboys",
		"Kilo bricks now, at the shady strips. And the money brings Los Cuervos: a crew\n"
		+ "from the west side who'd rather take our corners than build their own.\n"
		+ "Machine guns in the malls, bodies in the canals. Arm up: gun runs are on the\n"
		+ "boards, soldiers in the hiring hall, and the war is on the streets [park and use the on-foot control].",
		["ground_war", "guns", "role_soldier"],
		[["coke_lb", "Fly 60 lb of cocaine home", 60], ["arsenal", "Stock 8 weapons in the armoury", 8],
			["fleet_cover", "Run a truck with real cover or steel (the dealership)", 1, true, 3000]]],
	[1982, "Family Business",
		"Word reaches Tampa. Sal Moretti's people run the unions, the casinos and the\n"
		+ "judges who owe them favours - and they want a piece of Costa Brava. Their help\n"
		+ "is real. Sometimes. Read the offer before you take it [Phone > Family].",
		["family"],
		[["family_deal", "Do business with the Morettis (an offer, a loan or a bulk sale)", 1], ["bank", "Have $30,000 in spendable cash", 30000]]],
	[1983, "The Task Force",
		"Washington sends a task force: federal prosecutors, a grand jury, and agents who\n"
		+ "follow the money. A bust is no longer a fine - it's a case, with bail, lawyers,\n"
		+ "and men of ours who might decide to talk [Phone > Your lawyer].",
		["court"],
		[["hot_loads", "Deliver 3 hot loads with the task force watching", 3], ["clean", "Keep their case under 60% at the end", 1]]],
	[1984, "Isla Soberana",
		"Twenty-three kilometres south, the General's island sells product at a third of\n"
		+ "the street price and doesn't extradite. Captain Ibarra will see you on the ramp.\n"
		+ "Fly it, walk it through the airport on mules, or ship it in a container [Phone > General's aide].",
		["island", "role_mule"],
		[["island_runs", "Bring a load home from Isla Soberana", 1]]],
	[1984, "The House",
		"The Family owns more than the docks. On Isla Soberana, in the capital, it runs the Hotel Cielo: a white\n"
		+ "tower over the bay, roulette and chemin de fer, a cabaret under the stars, and a cage in the cellar where\n"
		+ "money goes in as chips and comes out as cheques. Buy a piece of the house, wash your street cash through\n"
		+ "the cage [Phone > Hotel Cielo]. But Havana had casinos too, once, and the General's island is not as calm as it looks.",
		["casino"],
		[["casino_stake", "Buy a stake in the Hotel Cielo", 1], ["casino_laundered", "Put $15,000 of street cash through its cage", 15000],
			["casino_out", "Get out of Isla Soberana when the government falls", 1],
			["casino_tables", "Win $2,000 at the Cielo's tables", 2000, true, 3000]]],
	[1985, "The Company",
		"A man with a government haircut and no government ID. His friends fight a war in\n"
		+ "Central America that Congress won't pay for. Fly his crates south, bring his\n"
		+ "product north, sell him guns - and pray nobody ever holds the hearings.",
		["agency"],
		[["agency_jobs", "Fly a job for the Company", 1], ["guns_to_company", "Sell the Company 4 guns", 4]]],
	[1986, "Kingpin",
		"The mandatory minimums pass, the Commission trial starts in New York, and every\n"
		+ "faction on the coast wants what's ours. Build it big enough that it doesn't\n"
		+ "matter who talks: sixty-five grand in cash and product, and keep the coast through what comes next.",
		[],
		[["net_worth", "Be worth $65,000 (cash and product)", 65000]]],
	[1987, "The Hearings",
		"The Company's war ends not with a victory but with a subpoena. Congress holds hearings on a policy nobody
"
		+ "voted for, and every pilot who ever flew a crate south is a witness or a liability. Some Company contacts stop
"
		+ "returning calls and starts returning bodies: rumours say pilots have been turning up in the canals with
"
		+ "their pockets turned out. Keep your head down, your case cold, and your money out of anywhere a clerk
"
		+ "can subpoena it.",
		[],
		[["case_cold", "Keep the task force's case under 50% for half an hour", 30], ["bank", "Have $40,000 in spendable cash", 40000]]],
	[1988, "Last Flight",
		"The money is the problem now. There is talk of grand juries and changing governments; the island may have
"
		+ "a new government that wants its hotel back, and the only people who still answer your calls are the ones
"
		+ "who want something. One more big year and then the long way out: enough to buy the silence of everyone
"
		+ "who knows your name. Make it, or find out who your friends were.",
		[],
		[["net_worth", "Be worth $90,000 (cash and product)", 90000], ["case_cold", "Be clear of the law: the case under 50% for twenty minutes", 20]]],
]

var index := 0
var progress := {}  ## goal key -> value this chapter
const GUIDANCE := [
	"Start with the bush-strip job board: buy grass, fly it to a stash, then hire and assign a dealer through Manny. Hiring and recurring wages are separate costs. Benny handles bulk buyers; Manny handles people.",
	"Dispatch shows cash at each stash and street location. Bring it to headquarters to make it spendable. The connection calls after 1,200 lb of grass sold, 2,400 lb delivered, or $25,000 earned from trade. Cocaine work opens with Cocaine Cowboys. Vehicle purchases are optional; finish the bonus before mandatory goals end this chapter.",
	"Phone > Sunrise Collective reaches Nico. Trade pounds of grass for sheets, then sell sheets through the circuit. Ask about rates and half-hour limits; proceeds remain at the named location. Delegation allows your people to repeat trading automatically until you stop it.",
	"Cocaine work, guns and soldiers are now available. Acquire weapons first, hire soldiers, then assign orders at the desk. Keep eight weapons in the armoury for the objective. Truck cover and steel reduce risk; neither guarantees safety.",
	"Phone > Family reads offers; Benny also handles Family bulk sales. Any accepted offer, loan or bulk sale qualifies. Read the review for costs and continuing obligations. Spendable cash is separate from money waiting at stashes.",
	"Federal court cases now replace the old fine-only consequences of a bust. Phone > Your lawyer explains bail, discovery and pleas when a case opens. Deliver three jobs marked hot, then have suspicion below 60%; this goal is an end-state check, not a consecutive timer.",
	"Phone > General's aide compares flight, mule and container routes. Read fees and customs risk before ordering. At least some product must arrive; an intercepted shipment does not count. Logistics normally receives island product near the harbour/airport.",
	"Phone > Hotel Cielo: buy a real stake, then launder street cash through the cage. Fees and available cash appear in the action review. Meeting these goals schedules unrest in ten minutes. When the uprising begins, use the launch before its displayed deadline. Losing the house continues the story but is recorded as missed evacuation.",
	"Company-marked jobs appear on flight boards. Deliver one, then Phone > Benny Ruiz to sell four rifles to the Company. Protection has limits and can end. An unavailable Company waives unfinished work; it does not mean you completed it.",
	"Campaign wealth is spendable cash plus product value plus outlying cash. Aircraft and vehicles are excluded. No new system opens here: consolidate the business before the hearings. Existing wealth may complete this chapter immediately.",
	"Keep suspicion below 50% for thirty consecutive minutes. Reaching 50% resets the timer. Hold $40,000 of spendable cash; money at stashes is separate. Keep collecting and consolidating while the case cools.",
	"Reach $90,000 in campaign wealth and keep suspicion below 50% for twenty consecutive minutes. This is financial survival, not a required final flight. The epilogue leaves the coast open for continued play.",
]

func guidance() -> String:
	var names: Array = CHAPTERS[index][3].map(func(k): return NAMES.get(k, k))
	return "NEW: %s\n\n%s" % [", ".join(names) if not names.is_empty() else "No new systems", GUIDANCE[index]]

func journal_text() -> String:
	var sections: Array = ["CHAPTER %d - %s\n\n%s\n\n%s\n\n%s" % [chapter.num, chapter.title, chapter.briefing, guidance(), "\n".join(objective_lines())]]
	for entry in history:
		sections.append("CHAPTER %d - %s\n%s\n%s" % [entry.chapter, entry.title, entry.briefing + "\n" + str(entry.get("aftermath", "")), "\n".join(entry.objectives)])
	if completed_all:
		sections.append("1989. Benny: You made enough to choose your next move. The coast is still here. So are the people who remember you.\n" + ending_summary())
	return "\n\n".join(sections)

func ending_summary() -> String:
	if sess == null:
		return "The coast remains open for continued play."
	return "Family: %s. Company: %s. Hotel Cielo: %s. Crew still on payroll: %d. Continued play remains available." % [
		"gone" if sess.family != null and sess.family.gone else "still present",
		"unavailable" if sess.agency != null and (not sess.agency.active() or sess.agency.hung_out) else "still present",
		sess.casino.status if sess.casino != null else "unavailable",
		sess.payroll.of("org").filter(func(w): return w.status in ["free", "assigned"]).size() if sess.payroll != null else 0]

var outcome_status := {}  ## waived or missed, distinct from completed counters
var outcomes := {}  ## objective key -> failure/waiver reason
var history: Array = []  ## completed chapter briefings and actual outcomes
var opened := {}  ## every system and lock opened so far
var completed_all := false
var show_briefing := true
var _last_t := -1.0  ## the clock at the last tick (for the goals that count minutes)
var sess = null
var _chapter: Campaign.Chapter = null


func _init(index_ := 0, progress_ = null) -> void:
	index = clampi(index_, 0, CHAPTERS.size() - 1)
	progress = progress_.duplicate() if progress_ is Dictionary else {}


var chapter: Campaign.Chapter:
	get:
		if _chapter == null or _chapter.num != index + 1:
			var c: Array = CHAPTERS[index]
			var goals := []
			for g in c[4]:
				var o := Campaign.Objective.new(g[0], g[1], g[2])
				if g.size() > 3:  # [key, text, target, optional, bonus]
					o.optional = bool(g[3])
					o.bonus = int(g[4])
				goals.append(o)
			_chapter = Campaign.Chapter.new(index + 1, c[0], c[1], c[2], [], [], goals)
		return _chapter


func to_dict() -> Dictionary:
	return {"index": index, "progress": progress, "done": completed_all, "outcomes": outcomes, "outcome_status": outcome_status, "history": history, "v": 4}


static func from_dict(d) -> Story:
	if not (d is Dictionary):
		d = {}
	var idx := int(d.get("index", 0))
	var v := int(d.get("v", 1))
	if v < 2 and idx >= 6:
		idx += 1  # a save from before 'The House' was added between Isla Soberana and the Company
	if v < 3 and idx >= 2:
		idx += 1  # ... and from before 'Blotter' was added after The Connection
	var st := Story.new(idx, d.get("progress"))
	st.completed_all = bool(d.get("done", false))
	st.outcomes = d.get("outcomes", {}).duplicate()
	st.outcome_status = d.get("outcome_status", {}).duplicate()
	st.history = d.get("history", []).duplicate(true)
	return st


## The index of the chapter titled `title` (the chapters are found by name so that adding one does not break the code that waits on another).
static func index_of(title: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i][1] == title:
			return i
	return CHAPTERS.size()


func is_unlocked(key: String) -> bool:
	return completed_all or opened.has(key)


## Every system and lock chapters 1..n open.
static func opens_through(n: int) -> Array:
	var out := []
	for i in mini(n, CHAPTERS.size()):
		out += CHAPTERS[i][3]
	return out


# ------------------------------------------------------------ wiring
## Takes over the session: everything the chapters so far opened is built, the
## rest waits. The trade starts in career mode (grass until the connection).
func attach(s) -> void:
	sess = s
	s.story = self
	s.bus.subscribe("*", _on_event)
	if s.trade == null:
		s.enable_system("trade", true)
	for i in index + 1:
		_open(i, i == index)
	if index >= index_of("Cocaine Cowboys") and s.trade != null:
		s.trade.connected = true  # a saved game past 1980 already has the call
	if completed_all:
		for k in Session.SYSTEMS:
			s.enable_system(k)
	show_briefing = true
	s.say("CHAPTER %d (%d): %s" % [index + 1, chapter.year, chapter.title])


func _open(i: int, announce: bool) -> void:
	var names := []
	for key in CHAPTERS[i][3]:
		opened[key] = true
		if key in Session.SYSTEMS and sess.enable_system(key, true):
			names.append(NAMES.get(key, key))
		elif key in LOCKS:
			names.append(NAMES.get(key, key))
	if announce and i > 0 and not names.is_empty():
		sess.say("Unlocked: " + ", ".join(names))
	for code in sess.boards.keys():
		sess.refresh_board(code)
	if sess.payroll != null:
		for o in sess.payroll.candidates.keys():
			sess.payroll._refresh(o)  # the hall hires for what's open now


const NAMES := {"logistics": "logistics (stock and cash have to be moved)", "dealership": "the car dealership", "psychedelics": "the Sunrise Collective (acid for grass)", "trade": "the trade", "payroll": "the hiring hall", "chronicle": "the papers",
	"ground_war": "the street war with Los Cuervos", "guns": "gun runs and gun sales", "role_soldier": "soldiers",
	"family": "the Moretti family", "court": "the federal court", "island": "Isla Soberana", "role_mule": "mules",
	"agency": "the Company", "casino": "the Hotel Cielo"}


func objective_lines() -> Array:
	var out := []
	for o in chapter.objectives:
		if outcomes.has(o.key):
			out.append("[%s] %s: %s" % [outcome_status.get(o.key, "waived"), o.text, outcomes[o.key]])
			continue
		var v: float = progress.get(o.key, 0.0)
		var mark := "x" if v >= o.target else " "
		var count := ""
		if o.key in ["trade_earned", "bank", "net_worth", "cash_home", "casino_laundered", "casino_tables"]:
			count = " ($%s/$%s)" % [Py.money(int(v)), Py.money(int(o.target))]
		elif o.key == "case_cold":
			count = " (%d/%d min)" % [int(v), int(o.target)]
		elif o.target > 1:
			count = " (%d/%d)" % [int(v), int(o.target)]
		if o.optional:
			count += " (optional before chapter ends: +$%s)" % Py.money(o.bonus)
		out.append("[%s] %s%s" % [mark, o.text, count])
	return out


# ------------------------------------------------------------ progress
func _bump(key: String, amount := 1.0) -> void:
	if Py.any(chapter.objectives, func(o): return o.key == key):
		progress[key] = progress.get(key, 0.0) + amount


func _put(key: String, v: float) -> void:
	if Py.any(chapter.objectives, func(o): return o.key == key):
		progress[key] = v


func _waive(key: String, reason: String, status := "waived") -> bool:
	for o in chapter.objectives:
		if o.key == key and progress.get(key, 0.0) < o.target and not outcomes.has(key):
			outcomes[key] = reason
			outcome_status[key] = status
			return true
	return false


func _on_event(ev: EventBus.Event) -> void:
	var d := ev.data
	match ev.kind:
		"job_delivered":
			var good := str(d.get("good", ""))
			if good == "marijuana":
				_bump("weed_lb", float(d.get("lb", 0.0)))
			elif good == "cocaine":
				_bump("coke_lb", float(d.get("lb", 0.0)))
			if d.get("hot", false):
				_bump("hot_loads")
			if d.get("agency", false):
				_bump("agency_jobs")
			if str(d.get("origin", "")) == Island.CODE:
				_bump("island_runs")
		"island_shipment":
			if float(d.get("delivered_lb", 0.0)) > 0.0:
				_bump("island_runs")
		"cash_home":
			_bump("cash_home", float(d.get("amount", 0.0)))
		"vehicle_bought":
			_bump("dealership_buy")
		"acid_barter":
			_bump("acid_lb", float(d.get("lb", 0.0)))
		"acid_sold":
			_bump("acid_sheets", float(d.get("sheets", 0.0)))
		"casino_stake":
			_put("casino_stake", 1.0)
		"casino_laundered":
			_bump("casino_laundered", float(d.get("amount", 0.0)))
		"casino_out":
			if d.get("evacuated", false):
				_put("casino_out", 1.0)
			else:
				_waive("casino_out", "The house fell; evacuation was missed.", "missed")
		"bulk_sale":
			if d.get("buyer") == "family":
				_bump("family_deal")
			if d.get("buyer") == "agency" and d.get("good") == "guns":
				_bump("guns_to_company", float(d.get("qty", 0)))


## What finishes 'Blotter': the task force takes the lab. A van is found at the bottom of a ravine with a driver nobody will claim, the
## chemist has vanished, and the trail of grass leads to our stashes (the case against us grows).
func _blotter_ends() -> void:
	var s = sess
	if s.psych != null:
		s.psych._raid()
		s.psych.hide_until = s.time + 6.0 * 3600.0
	var c = s.police.case("runner")
	c.suspicion = minf(100.0, c.suspicion + 10.0)
	s.say("A county deputy found a bread van at the bottom of a ravine in the hills: a driver nobody will claim, and no sign of Nico Cozz. Investigators have a trail of grass that leads down to our stashes. Nico is unavailable for six hours; suspicion rose by 10 points.")


## Polled goals (state, not events), then the chapter check.
func tick(s) -> void:
	if completed_all:
		return
	if s.trade != null:
		_put("trade_earned", float(s.trade.earned))
		_put("dealers", float(s.trade.dealers("org").size()))
		_put("connected", 1.0 if s.trade.connected else 0.0)
	if s.arsenals.has("org"):
		_put("arsenal", float(s.arsenals["org"].count()))
	if s.family != null and s.family.accepted + s.family.loans_taken > 0:
		_put("family_deal", maxf(progress.get("family_deal", 0.0), 1.0))
	# no softlocks: a faction that's gone (convicted, burned, cut us loose) can't be dealt with
	if s.family != null and s.family.gone and progress.get("family_deal", 0.0) < 1.0:
		if _waive("family_deal", "The Morettis were convicted before a deal was completed."):
			s.say("The Commission trial took the Morettis before we could deal with them. The story moves on.")
	if chapter.title == "The House" and s.casino != null:
		var cz: Casino = s.casino
		if cz.status == "seized" or not cz.active() or s.family.gone:
			var newly_waived := false
			for k in ["casino_stake", "casino_laundered", "casino_out"]:
				newly_waived = _waive(k, "The house is no longer available.") or newly_waived
			if newly_waived and cz.status != "seized":
				s.say("The Family's house is out of reach: the story moves on.")
		else:
			_put("casino_stake", 1.0 if cz.stake > 0.0 else 0.0)
			if progress.get("casino_stake", 0.0) >= 1.0 and progress.get("casino_laundered", 0.0) >= 15000.0 and cz.force_uprising_at < 0.0 and cz.status == "open":
				cz.force_uprising_at = s.time + 600.0
				s.say("Word from the capital: the General's colonels are meeting. It may be time to be somewhere else.")
	if s.agency != null and (not s.agency.active() or s.agency.hung_out) and chapter.title == "The Company" and progress.get("agency_jobs", 0.0) < 99.0:
		var newly_waived := false
		for k in ["agency_jobs", "guns_to_company"]:
			newly_waived = _waive(k, "The Company cut us loose before this work was completed.") or newly_waived
		if newly_waived:
			s.say("The Company has cut us loose. So much for friends in Washington - the story moves on.")
	_put("bank", float(s.money))
	_put("net_worth", float(s.money) + (s.trade.stock_value() if s.trade != null else 0.0)
		+ (s.logistics.cash_out() if s.logistics != null else 0.0))
	if progress.get("hot_loads", 0.0) >= 3.0:
		_put("clean", 1.0 if s.police.case("runner").suspicion < 60.0 else 0.0)
	# the dealership's and the casino's side goals
	if s.dealer != null:
		var f: Dictionary = s.dealer.fleet()
		_put("fleet_cover", 1.0 if (float(f.stealth) >= 0.25 or float(f.armour) >= 0.25) else 0.0)
	if s.casino != null:
		_put("casino_tables", maxf(progress.get("casino_tables", 0.0), float(s.casino.gamble_net)))
	# the hearings and the last flight: a case kept cold, minute after consecutive minute
	var dt := clampf(s.time - _last_t, 0.0, 120.0) if _last_t >= 0.0 else 0.0
	_last_t = s.time
	if Py.any(chapter.objectives, func(o): return o.key == "case_cold"):
		if s.police.case("runner").suspicion < 50.0:
			progress["case_cold"] = progress.get("case_cold", 0.0) + dt / 60.0
		else:
			progress["case_cold"] = 0.0
	var ch := chapter
	for o in ch.objectives:  # a side goal pays once, when it is met
		var paid := "_paid_" + str(o.key)
		if o.optional and progress.get(o.key, 0.0) >= o.target and not progress.has(paid):
			progress[paid] = 1.0
			s.money += o.bonus
			s.say("Side goal done: %s. +$%s." % [o.text, Py.money(o.bonus)])
	if not Py.all(ch.objectives, func(o): return o.optional or outcomes.has(o.key) or progress.get(o.key, 0.0) >= o.target):
		return
	s.say("Chapter %d complete: %s!" % [ch.num, ch.title])
	advance()


## On to the next chapter (or the end): what finishing one does, and what a
## chapter jump (--chapter N) does.
func advance() -> void:
	var s = sess
	if completed_all:
		return
	history.append({"chapter": chapter.num, "title": chapter.title, "briefing": chapter.briefing,
		"objectives": objective_lines(), "outcomes": outcomes.duplicate(), "outcome_status": outcome_status.duplicate(), "time": s.time,
		"status": "completed" if Py.all(chapter.objectives, func(o): return o.optional or outcomes.has(o.key) or progress.get(o.key, 0.0) >= o.target) else "skipped", "aftermath": "Nico is hiding for six hours; the raid increased suspicion by 10 points." if chapter.title == "Blotter" else ""})
	if chapter.title == "Blotter":
		_blotter_ends()
	if index + 1 < CHAPTERS.size():
		index += 1
		progress = {}
		outcomes = {}
		outcome_status = {}
		_open(index, true)
		if chapter.title == "Cocaine Cowboys" and s.trade != null:
			s.trade.connected = true
		show_briefing = true
		s.say("CHAPTER %d (%d): %s" % [index + 1, chapter.year, chapter.title])
	else:
		completed_all = true
		for k in Session.SYSTEMS:
			s.enable_system(k)
		s.say(ending_summary())
		s.say("1989. The story is told - the coast is yours, for as long as it lasts. Everything stays open.")
	s.save()
