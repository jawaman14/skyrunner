extends TestCase
## The inventory model (docs/EMPIRE_SIMULATION_SPEC.md section 4): lots in exactly one location, splits, and conservation per good.


func test_a_lot_arrives_moves_and_stays_in_one_place() -> void:
	var inv := Inventory.new()
	var id := inv.add("cocaine", 100.0, "org:stash-docks")
	check(id > 0, "arrived")
	check_eq(inv.stock("org:stash-docks", "cocaine"), 100.0)
	check_eq(inv.move(id, 0.0, "truck-7", "carry", "org"), id, "the whole lot moves under its own id")
	check_eq(inv.stock("org:stash-docks", "cocaine"), 0.0)
	check_eq(inv.stock("truck-7", "cocaine"), 100.0)
	check_eq(inv.move(id, 0.0, "truck-7", "carry"), 0, "already there is refused")
	check_eq(inv.add("cocaine", 0.0, "x"), 0, "an empty lot is refused")
	check_eq(inv.add("cocaine", 5.0, "outside:state"), 0, "a lot cannot arrive outside the map")


func test_a_part_splits_the_lot_and_keeps_its_traits() -> void:
	var inv := Inventory.new()
	var id := inv.add("cocaine", 100.0, "a", "growers", "Medellin", 0.8, 0.4, 12.0)
	var part := inv.move(id, 30.0, "b", "carry")
	check(part != id and part > 0, "the part has its own id")
	check_eq(inv.stock("a", "cocaine"), 70.0)
	check_eq(inv.stock("b", "cocaine"), 30.0)
	check(inv.lots[part].origin == "Medellin" and inv.lots[part].quality == 0.8 and inv.lots[part].heat == 0.4, "origin, grade and heat follow")
	check_eq(inv.move(id, 71.0, "b", "carry"), 0, "more than it holds is refused")
	check_eq(inv.violations(), [], "no breach")


func test_reconcile_brings_a_location_to_a_number_and_books_the_difference() -> void:
	var inv := Inventory.new()
	inv.reconcile("stash:a", "cocaine", 80.0)
	check_eq(inv.stock("stash:a", "cocaine"), 80.0)
	inv.reconcile("stash:a", "cocaine", 50.0)
	check_eq(inv.stock("stash:a", "cocaine"), 50.0, "an excess leaves")
	inv.reconcile("stash:a", "cocaine", 65.0)
	check_eq(inv.stock("stash:a", "cocaine"), 65.0, "a shortfall arrives")
	check_eq(inv.held("cocaine"), inv.net_inflow("cocaine"), "conservation holds")
	check_eq(inv.net_inflow("cocaine"), 65.0)
	check_eq(inv.violations(), [], "no breach")
	inv.reconcile("stash:a", "cocaine", 0.0)
	check_eq(inv.held("cocaine"), 0.0)


func test_a_logistics_session_keeps_its_inventory_in_step_with_the_stash_stock() -> void:
	var s := Session.new({"seed": 1})
	s.enable_system("trade")
	s.enable_system("logistics")
	if s.logistics == null:
		s.dispose()
		return
	var id: String = s.stash_net.stashes[0].id
	s.logistics.stock[id]["cocaine"] = 120.0
	s.logistics.update(6.0)
	check_eq(s.inventory.stock("stash:" + id, "cocaine"), 120.0, "the inventory follows the stock")
	s.logistics.stock[id]["cocaine"] = 70.0
	s.logistics.update(6.0)
	check_eq(s.inventory.stock("stash:" + id, "cocaine"), 70.0, "and a loss")
	s.dispose()


func test_goods_aboard_the_aircraft_are_lots_at_the_aircraft() -> void:
	var s := Session.new({"seed": 1})
	s.enable_system("trade")
	s.enable_system("logistics")
	if s.logistics == null or s.loadout == null:
		s.dispose()
		return
	var at: String = "aircraft:" + str(s.aircraft_key)
	var it := Loadout.Item.new(Jobs.new_id(), "Kilo brick crate", "cargo", 40.0, 0, {"hot": true, "good": "cocaine"})
	s.loadout.add(it)
	s.logistics.update(6.0)
	check_eq(s.inventory.stock(at, "cocaine"), 40.0, "the crate is aboard")
	s.loadout.remove_item(it.id)
	s.logistics.update(6.0)
	check_eq(s.inventory.stock(at, "cocaine"), 0.0, "and gone when unloaded")
	s.dispose()


func test_a_flown_delivery_is_a_move_from_the_aircraft_to_the_stash() -> void:
	var s := Session.new({"seed": 1})
	s.enable_system("trade")
	s.enable_system("logistics")
	if s.logistics == null or s.loadout == null:
		s.dispose()
		return
	var st: Dictionary = s.stash_net.stashes[0]
	var jid := Jobs.new_id()
	var it := Loadout.Item.new(Jobs.new_id(), "Kilo brick crate", "cargo", 40.0, jid, {"hot": true, "good": "cocaine"})
	s.loadout.add(it)
	var job := Jobs.Job.new(jid, "Test load", "contraband", "FRM", st.strip, [it], 0, {})
	job.own_good = "cocaine"
	var inv: Inventory = s.inventory
	s.trade.delivered(job)
	var at: String = "aircraft:" + str(s.aircraft_key)
	var site: String = s.logistics.site_at(st.strip)
	check_eq(inv.stock(at, "cocaine"), 0.0, "off the aircraft")
	check_eq(inv.stock("stash:" + site, "cocaine"), 40.0, "into the stash")
	s.loadout.remove_job(jid)
	s.logistics.update(6.0)
	check_eq(inv.stock("outside:unattributed", "cocaine"), 0.0, "with nothing booked as unattributed")
	check_eq(inv.stock("stash:" + site, "cocaine"), s.logistics.stock[site]["cocaine"], "and the stash still matches its stock")
	s.dispose()


func test_conservation_per_good_through_the_boundary() -> void:
	var inv := Inventory.new()
	var id := inv.add("cocaine", 100.0, "a")
	inv.add("grass", 40.0, "a")
	var part := inv.move(id, 25.0, "outside:state", "seizure", "police")
	inv.move(id, 10.0, "outside:street", "sale", "org")
	check_eq(inv.held("cocaine"), 65.0, "what is left inside the map")
	check_eq(inv.net_inflow("cocaine"), 65.0, "arrivals minus losses equals what is held")
	check_eq(inv.held("grass"), inv.net_inflow("grass"), "and for every good")
	check(part > 0 and inv.stock("outside:state", "cocaine") == 25.0, "the seizure is accounted outside")
