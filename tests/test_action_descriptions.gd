extends TestCase
var sess: Session
func before_each() -> void:
	sess = Session.new({"seed": 61, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "dealership": true, "trade": true, "logistics": true, "rackets": true, "payroll": true, "airframe": true, "ground_war": true, "money": 200000})
	sess.police.frozen = true
	sess.update(1.0 / 30)
func after_each() -> void:
	sess.dispose()
	World.use_map(0)

func test_descriptions_are_read_only_and_permissions_precede_data() -> void:
	var source: String = sess.logistics.stock.keys()[0]
	var dest: String = sess.logistics.stock.keys()[1]
	sess.logistics.stock[source].marijuana = 100.0
	sess.rackets.held = 3
	var before := JSON.stringify(StrategicSave.capture(sess))
	var random_before := sess.rng.get_state()
	var money_before := sess.money
	var requests := [["buy_vehicle", {"id": "van"}], ["buy_aircraft", {"key": sess.aircraft_key}], ["buy_gear", {"name": "ferry_tank"}], ["service", {"part": "both"}], ["move_goods", {"from": source, "to": dest, "good": "marijuana", "lb": 60}], ["rackets", {"what": "ransom"}], ["rackets", {"what": "turn"}], ["rackets", {"what": "release"}]]
	for request in requests:
		var action := sess.describe_action(Roles.PILOT, request[0], request[1])
		check(action.has("label") and action.has("confirmation_required") and action.has("args"))
		var forbidden := sess.describe_action(Roles.CONTROLLER, request[0], request[1])
		check(not forbidden.enabled and forbidden.preview == "", "no opposing-side consequences leaked")
	check_eq(JSON.stringify(StrategicSave.capture(sess)), before, "no strategic mutation")
	check_eq(sess.money, money_before)
	check_eq(sess.rng.get_state(), random_before, "preview consumes no random draws")

func test_cost_obligations_and_stale_vehicle_execution() -> void:
	var action := sess.describe_action(Roles.PILOT, "buy_vehicle", {"id": "van"})
	check(action.enabled and "$14,000" in action.preview and "Insurance" in action.preview)
	sess.money = 0
	check(not sess.command(Roles.PILOT, action.command, action.args)[0])
	check(sess.dealer.owned.is_empty())
	sess.money = 200000
	check(sess.command(Roles.PILOT, action.command, action.args)[0])
	var serial: int = sess.dealer.owned[0].serial
	var sale := sess.describe_action(Roles.PILOT, "sell_vehicle", {"serial": serial})
	check(sale.enabled and "insurance stops" in sale.preview)
	check(sess.command(Roles.PILOT, sale.command, sale.args)[0])
	var cash := sess.money
	check(not sess.command(Roles.PILOT, sale.command, sale.args)[0], "stale serial cannot sell twice")
	check_eq(sess.money, cash)

func test_transfer_quantity_and_changed_stock() -> void:
	var source: String = sess.logistics.stock.keys()[0]
	var dest: String = sess.logistics.stock.keys()[1]
	sess.logistics.stock[source].marijuana = 30.0
	var args := {"from": source, "to": dest, "good": "marijuana", "lb": 100.0}
	var action := sess.describe_action(Roles.PILOT, "move_goods", args)
	check(action.enabled and "30.0" in action.preview and "not delivered immediately" in action.preview)
	sess.logistics.stock[source].marijuana = 0.0
	check(not sess.command(Roles.PILOT, "move_goods", args)[0])
	check(sess.stash_net.trucks.is_empty())
	for value in [-1, INF, NAN, {}, "invalid"]:
		var invalid := args.duplicate()
		invalid.lb = value
		check(not sess.describe_action(Roles.PILOT, "move_goods", invalid).enabled)
		check(not sess.command(Roles.PILOT, "move_goods", invalid)[0])

func test_repair_and_prisoner_continuing_obligations() -> void:
	sess.airframe.cond[sess.aircraft_key] = {"engine": 50.0, "airframe": 70.0}
	var action := sess.describe_action(Roles.MECHANIC, "service", {"part": "both"})
	check(action.enabled and "Charges accrue" in action.preview and "minutes" in action.preview)
	sess.airframe.work = {"parts": ["engine"]}
	check(not sess.command(Roles.MECHANIC, "service", {"part": "both"})[0])
	sess.rackets.held = 2
	var turn := sess.describe_action(Roles.BOSS, "rackets", {"what": "turn"})
	check(turn.enabled and "per payday" in turn.preview and "low loyalty" in turn.preview)
	var ransom := sess.describe_action(Roles.BOSS, "rackets", {"what": "ransom"})
	check("actual payment may be lower" in ransom.preview, "no private rival balance exposed")
	sess.rackets.held = 0
	check(not sess.command(Roles.BOSS, "rackets", {"what": "release"})[0])

func test_local_link_and_unsupported_peer_preview_contract() -> void:
	var local := LocalLink.new(sess, Roles.PILOT, false)
	var seq := local.request_preview("buy_vehicle", {"id": "van"})
	check(local.previews[seq].enabled)
	check(local.acks.is_empty(), "preview is not a command acknowledgement")
	var old := NetClient.new()
	seq = old.request_preview("buy_vehicle", {"id": "van"})
	check(not old.previews[seq].enabled and "unavailable" in old.previews[seq].disabled_reason)
	check(old.acks.is_empty())
	old.free()


func test_dealer_cancellation_and_stale_confirmation_change_nothing() -> void:
	var menu := DealerMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(sess)
	menu.browse()
	var money := sess.money
	menu.perform_action("buy_vehicle", {"id": "van"})
	check(menu.confirmation.visible and not menu.confirmation.selected_yes)
	menu.confirmation.key("esc")
	check_eq(sess.money, money)
	check(sess.dealer.owned.is_empty())
	menu.perform_action("buy_vehicle", {"id": "van"})
	sess.money = 0
	menu.confirmation.key("right")
	for i in 3:
		await Engine.get_main_loop().process_frame
	menu.confirmation.key("enter")
	check(sess.dealer.owned.is_empty())
	check(menu.feedback.visible and "costs" in menu.feedback.text, "stale funds fail beside action")
	menu.queue_free()

func test_preview_argument_copies_and_invalid_job_ids() -> void:
	var args := {"id": "van", "nested": {"x": [1]}}
	var action := sess.describe_action(Roles.PILOT, "buy_vehicle", args)
	args.id = "armoured"
	args.nested.x.append(2)
	check_eq(action.args.id, "van")
	check_eq(action.args.nested.x, [1])
	for id in [{}, INF, "invalid"]:
		check(not sess.describe_action(Roles.PILOT, "accept_job", {"job_id": id}).enabled)


func test_product_sale_and_squad_preview_revalidate_without_hidden_data() -> void:
	var source: String = sess.logistics.stock.keys()[0]
	sess.logistics.stock[source].marijuana = 100.0
	sess.logistics.sync()
	var args := {"buyer": "rival", "good": "marijuana", "qty": 50.0, "from": source}
	var before := JSON.stringify(StrategicSave.capture(sess))
	var sale := sess.describe_action(Roles.BOSS, "sell_product", args)
	# This buyer may refuse the good; availability is still a read-only quote.
	check(sale.has("preview"))
	check_eq(JSON.stringify(StrategicSave.capture(sess)), before)
	var squad = sess.ground.recruit("org", "foot", null, false)
	check(not (squad is String), "squad raised for preview")
	if squad is String:
		return
	var action := sess.describe_action(Roles.BOSS, "disband_squad", {"id": squad.id})
	check(action.enabled and "payroll soldiers remain employed" in action.preview)
	squad.fight = GroundWar.Fight.new()
	check(not sess.command(Roles.BOSS, action.command, action.args)[0], "new firefight blocks stale approval")
	squad.fight = null
	var enemy = sess.ground.of("rival")[0]
	var forbidden := sess.describe_action(Roles.BOSS, "disband_squad", {"id": enemy.id})
	check(not forbidden.enabled and forbidden.preview == "", "no opposing squad consequences")

func test_bulk_round_previews_are_read_only_and_show_partial_distribution() -> void:
	var ids: Array = sess.logistics.stock.keys()
	var source: String = ids[0]
	var stops := [ids[1], ids[2]]
	sess.logistics.stock[source].marijuana = 25.0
	sess.logistics.cash[stops[0]] = 100.0
	sess.logistics.cash[stops[1]] = 200.0
	var before := JSON.stringify(StrategicSave.capture(sess))
	var random_before := sess.rng.get_state()
	var goods_args := {"from": source, "stops": stops, "good": "marijuana", "lb": 20.0}
	var goods := sess.describe_action(Roles.PILOT, "goods_round", goods_args)
	check(goods.enabled and "20.0 marijuana" in goods.preview and "5.0 marijuana" in goods.preview)
	check("25.0 marijuana leaves" in goods.preview)
	var cash := sess.describe_action(Roles.PILOT, "cash_round", {"stops": stops, "to": Logistics.HQ})
	check(cash.enabled and "$300" in cash.preview)
	check("Only the first stop" in cash.preview if Agent.ENABLED else "separate trucks" in cash.preview)
	check_eq(JSON.stringify(StrategicSave.capture(sess)), before)
	check_eq(sess.rng.get_state(), random_before)
	for bad in [[], [ids[1], ids[1]], [ids[1], "missing"], "not a list"]:
		check(not sess.describe_action(Roles.PILOT, "cash_round", {"stops": bad}).enabled)
	for value in [-1, INF, NAN, {}, "bad"]:
		var invalid := goods_args.duplicate(true)
		invalid.lb = value
		check(not sess.command(Roles.PILOT, "goods_round", invalid)[0])
	check(sess.stash_net.trucks.is_empty())
	sess.stash_net.get_stash(stops[0]).burned = true
	check(not sess.command(Roles.PILOT, "goods_round", goods_args)[0], "burned destination invalidates a previous preview")
	check_near(sess.logistics.stock[source].marijuana, 25, 0.001)

func test_armoury_preview_does_not_take_weapons_or_ammunition() -> void:
	var dest: String = sess.logistics.stock.keys()[0]
	var ars: Arsenal = sess.arsenals.org
	ars.stock.rifle = 7
	var before := JSON.stringify(StrategicSave.capture(sess))
	var action := sess.describe_action(Roles.PILOT, "move_armoury", {"to": dest})
	check(action.enabled and "Ammunition is not transferred" in action.preview)
	check("location changes on arrival" in action.preview)
	check_eq(JSON.stringify(StrategicSave.capture(sess)), before)
	check(not sess.describe_action(Roles.CONTROLLER, "move_armoury", {"to": dest}).enabled)
	sess.stash_net.get_stash(dest).burned = true
	check(not sess.command(Roles.PILOT, "move_armoury", {"to": dest})[0])
	check_eq(ars.stock.rifle, 7)
