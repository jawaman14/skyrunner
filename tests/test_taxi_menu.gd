extends TestCase
## Exercise a fare from menu selection through the existing authoritative ride.
## Use a minimal pilot/walker, not the full rendered city.

class TaxiPilot extends PilotApp:
	var stops: Array = []
	func taxi_stops() -> Array: return stops

var _session: Session
var _app: TaxiPilot
var _menu: TaxiMenu

func after_each() -> void:
	if _menu != null: _menu.free()
	if _app != null: _app.free()
	if _session != null: _session.dispose()
	_menu = null
	_app = null
	_session = null
	World.use_map(0)

func _setup() -> void:
	_session = T.sess(12)
	_session.police.frozen = true
	_session.money = 100
	_app = TaxiPilot.new()
	_app.set_process(false)
	Engine.get_main_loop().root.add_child(_app)
	_app.s = _session
	_app.ui = CanvasLayer.new()
	_app.add_child(_app.ui)
	_app.walker = Walker.new().setup(_session.world)
	_app.add_child(_app.walker)
	_app.walker.set_physics_process(false)
	_app.stops = [{"name": "The workshop", "at": Vector2(500, 500), "heading": 90.0,
		"dist": 600.0, "secs": 20.0, "fare": 40}]
	_menu = TaxiMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(_session)
	_menu.stops_fn = _app.taxi_stops
	_menu.chosen.connect(_app._taxi_go)
	_menu.open()

func test_menu_choice_charges_once_then_arrival_restores_walking() -> void:
	_setup()
	check_eq(_menu.list.cell(0, 3), "$40", "fare is visible before the ride")
	_menu.list.select(0)
	_menu.key("enter")
	check(not _menu.visible)
	check_eq(_session.money, 60)
	check_eq(_app.taxi_left, 20.0)
	check(not _app.walker.look_enabled)
	var before: float = _session.time
	while _app.taxi_left > 0:
		_app._taxi_tick(null, null)
	check_near(_session.time - before, 20.0, 0.001, "world time advances during transport")
	check_near(_app.walker.global_position.x, 500.0, 0.001)
	check_near(_app.walker.global_position.z, -500.0, 0.001)
	check(_app.walker.look_enabled)
	check(not _app.taxi_label.visible)
	check_eq(_session.money, 60, "arrival does not charge again")

func test_cancel_empty_list_and_stale_fare_do_not_charge_or_dispatch() -> void:
	_setup()
	_menu.close()
	check_eq(_session.money, 100, "Cancel changes nothing")
	check_eq(_app.taxi_left, 0.0)
	_app.stops = []
	_menu.open()
	_menu.key("enter")
	check_eq(_menu.footer.text, "Nowhere to go.")
	check_eq(_session.money, 100)
	_app.stops = [{"name": "The workshop", "at": Vector2.ZERO, "heading": 0.0,
		"dist": 600.0, "secs": 20.0, "fare": 40}]
	_menu.refresh()
	_menu.list.select(0)
	_app.stops[0].fare = 140
	_menu.key("enter")
	check_eq(_session.money, 100, "authoritative fare is rechecked after menu display")
	check_eq(_app.taxi_left, 0.0)
	check(_app.walker.look_enabled)
	_app._taxi_go(50)
	check_eq(_session.money, 100, "invalid destination does not charge")
