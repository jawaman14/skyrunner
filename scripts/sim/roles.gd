class_name Roles
extends RefCounted
## Sides, roles, match modes and who is allowed to do what.
##
## Every non-flight action is a *command* issued by a role
## (Session.command(role, name, args)). Local menus, network clients and AI
## crew all go through the same gate.

const PILOT := "pilot"
const COPILOT := "copilot"
const SPOTTER := "spotter"
const BOAT := "boat"
const BOSS := "boss"  ## the organisation's HQ
const CONTROLLER := "controller"
const INTERCEPTOR := "interceptor"  ## police pilot: flies one unit in 3D
const CUTTER := "cutter"
const CHIEF := "chief"  ## the task force's HQ
const LIEUTENANT := "lieutenant"  ## the organisation's soldiers on the ground (GroundWar)
const PATROL := "patrol"  ## the task force's narcotics squads on the ground (GroundWar)
const MECHANIC := "mechanic"  ## the organisation's mechanic: repairs the aircraft in the field, reads its true condition (Airframe)
const FIXER := "fixer"  ## the organisation's business desk: jobs, hires, gear, money, the Family, between flights
const UNDERCOVER := "undercover"  ## the task force's agent: plants a tracking beacon on a parked aircraft (Undercover)
const ANALYST := "analyst"  ## the task force's tip desk: informants, fuel records, tail numbers (Analyst)
const ALL := [PILOT, COPILOT, SPOTTER, BOAT, BOSS, LIEUTENANT, CONTROLLER, INTERCEPTOR, CUTTER, CHIEF, PATROL, ANALYST, UNDERCOVER, FIXER, MECHANIC]

## What each seat does, in one line (the waiting room, the seat picker and the multiplayer menu all show this).
const ABOUT := {
	"pilot": "flies the aircraft (3D)", "copilot": "loads, kicks bales, pumps fuel, runs the scanner and the boat",
	"spotter": "watches a strip for police", "boat": "the go-fast at the rendezvous", "boss": "the organisation's HQ, night by night",
	"lieutenant": "the organisation's soldiers on the streets", "controller": "the task force's radar and dispatch desk",
	"interceptor": "flies a police helicopter or jet (3D)", "cutter": "the Coast Guard cutter", "chief": "the task force's HQ and budget",
	"patrol": "the narcotics squads on the streets", "analyst": "the tip desk: check the informants' word, forward or bin it",
	"undercover": "plants a tracking beacon on a parked runner aircraft",
	"mechanic": "keeps the aircraft flying: repairs in the field, reads its true condition, haggles for fuel",
	"fixer": "books the jobs, hires the crew, buys the gear, sees the Family: the business between flights",
}
const _SQUADS := ["squad_order", "recruit_squad", "disband_squad"]

const SOLO := "solo"  ## human pilot vs AI law
const POLICE := "police"  ## human controller vs AI runners
const COOP := "coop"  ## human runner crew vs AI law
const VERSUS := "versus"  ## humans on both sides, AI fills gaps
const CAMPAIGN := "campaign"  ## solo/co-op, chapter rules

const _GROUND_OPS := ["accept_job", "drop_job", "move_item", "loadmaster", "set_fuel", "fill_ferry"]
const _CREW_AIR := ["kick", "pump", "call_boat", "auto_kick"]

static var PERMISSIONS := {
	PILOT: _GROUND_OPS + _CREW_AIR + ["buy_aircraft", "buy_gear", "hire_spotter", "transponder", "squawk", "upgrade", "service", "stop_work", "autopilot",
		"confirm", "chat", "turn_around", "hq", "gun_mode", "field_order", "rackets", "stash_works", "race_enter", "sell_weapons", "buy_weapons", "family_accept", "family_decline", "family_probe", "family_stall", "pay_tribute", "island_ship", "buy_passage", "court_bail", "court_hire", "court_motion", "court_tamper", "court_bribe", "court_plea", "court_cooperate", "court_appeal", "court_wait", "hire_worker", "fire_worker", "pay_bonus", "pay_worker_lawyer", "post_lookout", "sell_product", "move_goods", "move_cash", "cash_round", "goods_round", "move_armoury", "escort_truck", "load_cash", "unload_cash"],
	COPILOT: _GROUND_OPS + _CREW_AIR + ["hire_spotter", "chat", "tutorial", "load_cash", "unload_cash", "gun_mode", "family_accept", "family_decline", "family_probe", "family_stall", "pay_tribute", "island_ship", "buy_passage"],
	SPOTTER: ["spotter_move", "chat", "tutorial"],
	BOAT: ["boat_goto", "chat", "tutorial"],
	BOSS: ["hq", "chat", "tutorial", "gun_mode", "field_order", "rackets", "stash_works", "race_enter", "sell_weapons", "buy_weapons", "set_cache", "squad_order", "recruit_squad", "disband_squad", "family_accept", "family_decline", "family_probe", "family_stall", "pay_tribute", "island_ship", "buy_passage", "court_hire", "court_motion", "court_tamper", "court_bribe", "hire_worker", "fire_worker", "pay_bonus", "pay_worker_lawyer", "post_lookout", "sell_product", "move_goods", "move_cash", "cash_round", "goods_round", "move_armoury", "escort_truck"],
	CONTROLLER: ["launch", "dispatch", "recall", "encrypt", "radio_channel", "jam", "upgrade", "raid_stash", "aerostat", "chat", "tutorial", "hq", "squad_order", "investigate_agency", "rico_case", "airport_crackdown", "port_inspections", "court_no_bail", "court_immunity", "court_forfeiture", "court_charge", "court_offer_plea", "offer_worker_deal", "street_sweep", "trace_money"],
	INTERCEPTOR: ["claim_unit", "release_unit", "chat", "tutorial"],
	CUTTER: ["cutter_goto", "chat", "tutorial"],
	CHIEF: ["hq", "chat", "tutorial", "squad_order", "recruit_squad", "disband_squad", "investigate_agency", "rico_case", "airport_crackdown", "port_inspections", "court_no_bail", "court_immunity", "court_forfeiture", "court_charge", "court_offer_plea", "offer_worker_deal", "street_sweep", "trace_money"],
	LIEUTENANT: _SQUADS + ["chat", "tutorial", "gun_mode", "field_order", "rackets", "stash_works", "race_enter", "sell_weapons", "buy_weapons", "set_cache", "family_accept", "family_decline", "family_probe", "family_stall", "pay_tribute", "island_ship", "buy_passage", "hire_worker", "fire_worker", "pay_bonus", "pay_worker_lawyer", "post_lookout", "sell_product", "move_goods", "move_cash", "cash_round", "goods_round", "move_armoury", "escort_truck"],
	ANALYST: ["analyst", "chat", "tutorial"],
	UNDERCOVER: ["plant_beacon", "chat", "tutorial"],
	MECHANIC: ["service", "stop_work", "inspect", "set_fuel", "fill_ferry", "chat", "tutorial"],
	FIXER: ["accept_job", "drop_job", "buy_aircraft", "buy_gear", "hire_spotter", "upgrade", "service", "chat", "tutorial", "rackets", "stash_works",
		"sell_weapons", "buy_weapons", "family_accept", "family_decline", "family_probe", "family_stall", "pay_tribute", "island_ship", "buy_passage",
		"court_bail", "court_hire", "court_motion", "court_tamper", "court_bribe", "court_plea", "court_cooperate", "court_appeal", "court_wait",
		"hire_worker", "fire_worker", "pay_bonus", "pay_worker_lawyer", "post_lookout", "sell_product", "move_goods", "move_cash", "cash_round",
		"goods_round", "move_armoury", "escort_truck"],
	PATROL: _SQUADS + ["raid_stash", "chat", "tutorial", "rico_case", "street_sweep"],
}

## Roles a human can take in each mode. Everything else is AI or absent.
const MODE_ROLES := {
	SOLO: [PILOT],
	POLICE: [CONTROLLER, INTERCEPTOR, CUTTER, CHIEF, PATROL, ANALYST, UNDERCOVER],
	COOP: [PILOT, COPILOT, SPOTTER, BOAT, BOSS, LIEUTENANT, FIXER, MECHANIC],
	VERSUS: ALL,
	CAMPAIGN: [PILOT, COPILOT, SPOTTER, BOAT],
}


static func side(role: String) -> String:
	return "law" if role in [CONTROLLER, INTERCEPTOR, CUTTER, CHIEF, PATROL, ANALYST, UNDERCOVER] else "runner"


static func allowed(role: String, command: String) -> bool:
	return PERMISSIONS.get(role, []).has(command)


static func valid(role: String) -> bool:
	return ALL.has(role)
