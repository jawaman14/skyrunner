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
