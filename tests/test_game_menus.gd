extends TestCase
## Every ground menu (GameMenu) builds against a live session, opens, takes every key the pilot app can
## send it without a script error, and closes; plus the collectors' terms cycling through the session.

const MENUS := [
	"res://scripts/ui/hangar_menu.gd", "res://scripts/ui/hq_menu.gd", "res://scripts/ui/job_menu.gd", "res://scripts/ui/load_menu.gd",
	"res://scripts/ui/phone_menu.gd", "res://scripts/ui/race_menu.gd", "res://scripts/ui/rackets_menu.gd", "res://scripts/ui/taxi_menu.gd",
]
const KEYS := ["up", "down", "left", "right", "enter", "a", "f", "+", "-", "esc"]

var _sess: Session


func after_each() -> void:
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session() -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES + ["hq"], "payroll": true,
		"court": true, "ground_war": true, "trade": true, "logistics": true, "family": true, "island": true, "agency": true,
		"chronicle": true, "rackets": true, "renown": true, "races": true}
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.money = 50000
	_sess.update(1.0 / 30)
	return _sess


func test_every_menu_builds_opens_takes_every_key_and_closes() -> void:
	var s := _session()
	var root: Node = Engine.get_main_loop().root
	for path in MENUS:
		var m: GameMenu = load(path).new()
		root.add_child(m)
		m.setup(s)
		var closed := [0]
		m.closed.connect(func(): closed[0] += 1)
		check(not m.visible, "%s starts hidden" % path.get_file())
		m.open()
		check(m.visible, "%s opens" % path.get_file())
		check(m.title.text != "", "%s has a title" % path.get_file())
		for k in KEYS:
			if k == "esc":
				continue
			m.key(k)
		m.refresh()
		m.close()
		check(closed[0] >= 1, "%s says it closed (some close themselves on ENTER, once a call or a race is set up)" % path.get_file())
		check(not m.visible, "%s is hidden again" % path.get_file())
		m.queue_free()


func test_enter_in_the_collectors_cycles_a_markets_terms() -> void:
	var s := _session()
	var root: Node = Engine.get_main_loop().root
	var m := RacketsMenu.new()
	root.add_child(m)
	m.setup(s)
	m.open()
	if m.markets.is_empty():
		check(true, "no markets to collect from on this map (nothing to cycle)")
		m.queue_free()
		return
	var market: String = m.markets[0].market
	var before: String = s.rackets.policy[market]
	m.key("enter")
	var after: String = s.rackets.policy[market]
	check(before != after, "ENTER changes the terms: %s -> %s" % [before, after])
	check_eq(after, Rackets.POLICIES[(Rackets.POLICIES.find(before) + 1) % Rackets.POLICIES.size()], "to the next in the cycle")
	check_eq(m.markets[0].policy, after, "and the table shows it")
	m.queue_free()
