extends TestCase
const Card = preload("res://scripts/ui/widgets/squad_card.gd")

func test_card_explains_condition_travel_and_cost() -> void:
	var row := {"id": "org-1", "kind": "car", "men": 3, "men0": 4, "rank": 2, "loadout": {"rifle": 3}, "ammo": 90,
		"morale": 0.7, "order": "escort", "tactic": "", "state": "moving", "destination": [120, 250], "upkeep_per_minute": 9.0, "player_order": true}
	var text := Card.describe(row)
	for value in ["3/4 people", "Veteran", "90 rounds", "70%", "escort", "moving", "120, 250", "$9.00/min", "Player order"]:
		check(value in text, "card explains " + value)
	check_eq(row.morale, 0.7, "presentation is read-only")

func test_old_peer_and_no_route_are_distinct() -> void:
	var row := {"id": "org-1", "men": 4, "men0": 4}
	check("unavailable from this peer" in Card.describe(row), "older snapshots do not imply zero cost or no journey")
	row.destination = []
	row.upkeep_per_minute = 8.0
	check("No active travel route" in Card.describe(row), "known no-route is explicit")
	check("Standing/AI order" in Card.describe(row), "standing ownership is explicit")
