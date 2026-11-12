class_name Switches
extends RefCounted
## The one place that knows every static on/off switch in the sim and the renderer.
##
## New systems sit behind a static switch (an `ENABLED`-style `static var NAME := true`) so the parity
## and golden tests, which replay the Python prototype or a frozen run, can turn them off. A test that
## needs the old behaviour saves `Switches.parity_off()` in `before_each` and calls
## `Switches.restore(saved)` in `after_each`. `parity_on()` remains a compatibility
## helper for deliberately enabling the complete parity set.
##
## `tests/test_switches.gd` fails if a switch exists in scripts/sim or scripts/render that is named in
## neither PARITY nor OPT_IN below, so a new system cannot forget to register.

## The switches the parity tests turn off: Godot-only rules that change what the Python game did.
const PARITY := [
	"SensorNet.REALISM", "Economy.REALISM", "Arsenal.REALISM", "GroundWar.ENABLED", "Chronicle.ENABLED",
	"Agency.ENABLED", "Agent.ENABLED", "Fuel.ENABLED", "Orders.ENABLED", "Jobs.ISLAND_BOARD",
	"Investigation.ENABLED", "CoverCargo.ENABLED", "Comeback.ENABLED", "DealMoves.ENABLED", "Gigs.ENABLED", "StreakGuard.ENABLED", "Schedule.ENABLED", "Story.FLIGHT_GOALS",
	"Breakaway.ENABLED",
	"Wanted.ENABLED", "Curses.ENABLED", "BlackMarket.ENABLED", "HeatDial.ENABLED", "Businesses.ENABLED", "OrgAI.ENABLED", "Delegation.ENABLED", "Laundering.ENABLED", "Grades.ENABLED", "Pickups.ENABLED", "Trust.ENABLED", "Crates.ENABLED", "PriceWars.ENABLED", "Investments.ENABLED", "Takeover.ENABLED", "Pickups.INTERCEPTS", "Grades.BULK", "Wear.ENABLED",
]

## Switches no parity test touches. Most are opt-in anyway: the system only exists when the session's
## options ask for it, so a parity session never builds it. Each has its own tests that flip it.
const OPT_IN := [
	"Court.ENABLED", "Court.PILOT_FREE", "Family.ENABLED", "Island.ENABLED", "Payroll.ENABLED", "Trade.ENABLED", "Races.ENABLED",
	"Rackets.ENABLED", "Renown.ENABLED", "StashWorks.ENABLED", "CityDress.ENABLED", "ModelLib.ENABLED",
	"Scenery.ENABLED", "GroundWar.ENGAGEMENT", "GroundWar.SMART_ROUTES", "GroundWar.VETERANS", "GroundWar.SPREAD",
	"Logistics.ROUNDS", "Tactical.PYTHON", "RadioNet.REALISM", "Analyst.ENABLED", "Casino.ENABLED", "Casino.REVOLUTION", "Airframe.ENABLED", "Undercover.ENABLED", "PortDress.ENABLED", "AirfieldDress.ENABLED", "DowntownDress.ENABLED",
	"CasinoBuilding.ENABLED", "Discovery.ENABLED", "DailyWeather.ENABLED", "Calendar.ENABLED", "Weekly.ENABLED", "Dealership.ENABLED", "Psychedelics.ENABLED", "Territories.ENABLED", "PoliceSystem.EARLY_PACE",
	"PilotApp.FIXED_STEP", "Court.SPARE_ONLY", "LastRun.ENABLED", "NightDirector.ENABLED",
]


## Capture the caller's configuration, including switches already disabled.
static func snapshot() -> Dictionary:
	return {"SensorNet.REALISM": SensorNet.REALISM, "Economy.REALISM": Economy.REALISM,
		"Arsenal.REALISM": Arsenal.REALISM, "GroundWar.ENABLED": GroundWar.ENABLED,
		"Chronicle.ENABLED": Chronicle.ENABLED, "Agency.ENABLED": Agency.ENABLED,
		"Agent.ENABLED": Agent.ENABLED, "Fuel.ENABLED": Fuel.ENABLED, "Orders.ENABLED": Orders.ENABLED,
		"Jobs.ISLAND_BOARD": Jobs.ISLAND_BOARD,
		"Investigation.ENABLED": Investigation.ENABLED, "CoverCargo.ENABLED": CoverCargo.ENABLED, "Comeback.ENABLED": Comeback.ENABLED, "DealMoves.ENABLED": DealMoves.ENABLED, "Gigs.ENABLED": Gigs.ENABLED,
		"StreakGuard.ENABLED": StreakGuard.ENABLED, "Schedule.ENABLED": Schedule.ENABLED, "Story.FLIGHT_GOALS": Story.FLIGHT_GOALS, "Breakaway.ENABLED": Breakaway.ENABLED, "Wanted.ENABLED": Wanted.ENABLED, "Curses.ENABLED": Curses.ENABLED, "BlackMarket.ENABLED": BlackMarket.ENABLED, "HeatDial.ENABLED": HeatDial.ENABLED, "Businesses.ENABLED": Businesses.ENABLED, "OrgAI.ENABLED": OrgAI.ENABLED, "Delegation.ENABLED": Delegation.ENABLED, "Laundering.ENABLED": Laundering.ENABLED, "Grades.ENABLED": Grades.ENABLED, "Pickups.ENABLED": Pickups.ENABLED, "Trust.ENABLED": Trust.ENABLED, "Crates.ENABLED": Crates.ENABLED, "PriceWars.ENABLED": PriceWars.ENABLED, "Investments.ENABLED": Investments.ENABLED, "Takeover.ENABLED": Takeover.ENABLED, "Pickups.INTERCEPTS": Pickups.INTERCEPTS, "Grades.BULK": Grades.BULK, "Wear.ENABLED": Wear.ENABLED}

static func restore(state: Dictionary) -> void:
	# Validate the complete snapshot before changing any switch.
	for key in PARITY:
		if not state.has(key) or not state[key] is bool:
			push_error("Invalid parity snapshot: " + key)
			return
	SensorNet.REALISM = state["SensorNet.REALISM"]
	Economy.REALISM = state["Economy.REALISM"]
	Arsenal.REALISM = state["Arsenal.REALISM"]
	GroundWar.ENABLED = state["GroundWar.ENABLED"]
	Chronicle.ENABLED = state["Chronicle.ENABLED"]
	Agency.ENABLED = state["Agency.ENABLED"]
	Agent.ENABLED = state["Agent.ENABLED"]
	Fuel.ENABLED = state["Fuel.ENABLED"]
	Orders.ENABLED = state["Orders.ENABLED"]
	Jobs.ISLAND_BOARD = state["Jobs.ISLAND_BOARD"]
	Investigation.ENABLED = state["Investigation.ENABLED"]
	CoverCargo.ENABLED = state["CoverCargo.ENABLED"]
	Comeback.ENABLED = state["Comeback.ENABLED"]
	DealMoves.ENABLED = state["DealMoves.ENABLED"]
	Gigs.ENABLED = state["Gigs.ENABLED"]
	StreakGuard.ENABLED = state["StreakGuard.ENABLED"]
	Schedule.ENABLED = state["Schedule.ENABLED"]
	Story.FLIGHT_GOALS = state["Story.FLIGHT_GOALS"]
	Breakaway.ENABLED = state["Breakaway.ENABLED"]
	Wanted.ENABLED = state["Wanted.ENABLED"]
	Curses.ENABLED = state["Curses.ENABLED"]
	BlackMarket.ENABLED = state["BlackMarket.ENABLED"]
	HeatDial.ENABLED = state["HeatDial.ENABLED"]
	Businesses.ENABLED = state["Businesses.ENABLED"]
	OrgAI.ENABLED = state["OrgAI.ENABLED"]
	Delegation.ENABLED = state["Delegation.ENABLED"]
	Laundering.ENABLED = state["Laundering.ENABLED"]
	Grades.ENABLED = state["Grades.ENABLED"]
	Pickups.ENABLED = state["Pickups.ENABLED"]
	Trust.ENABLED = state["Trust.ENABLED"]
	Crates.ENABLED = state["Crates.ENABLED"]
	PriceWars.ENABLED = state["PriceWars.ENABLED"]
	Investments.ENABLED = state["Investments.ENABLED"]
	Takeover.ENABLED = state["Takeover.ENABLED"]
	Pickups.INTERCEPTS = state["Pickups.INTERCEPTS"]
	Grades.BULK = state["Grades.BULK"]
	Wear.ENABLED = state["Wear.ENABLED"]

static func parity_off() -> Dictionary:
	var previous := snapshot()
	SensorNet.REALISM = false
	Economy.REALISM = false
	Arsenal.REALISM = false
	GroundWar.ENABLED = false
	Chronicle.ENABLED = false
	Agency.ENABLED = false
	Agent.ENABLED = false
	Fuel.ENABLED = false
	Orders.ENABLED = false
	Jobs.ISLAND_BOARD = false
	Investigation.ENABLED = false
	CoverCargo.ENABLED = false
	Comeback.ENABLED = false
	DealMoves.ENABLED = false
	Gigs.ENABLED = false
	StreakGuard.ENABLED = false
	Schedule.ENABLED = false
	Story.FLIGHT_GOALS = false
	Breakaway.ENABLED = false
	Wanted.ENABLED = false
	Curses.ENABLED = false
	BlackMarket.ENABLED = false
	HeatDial.ENABLED = false
	Businesses.ENABLED = false
	OrgAI.ENABLED = false
	Delegation.ENABLED = false
	Laundering.ENABLED = false
	Grades.ENABLED = false
	Pickups.ENABLED = false
	Trust.ENABLED = false
	Crates.ENABLED = false
	PriceWars.ENABLED = false
	Investments.ENABLED = false
	Takeover.ENABLED = false
	Pickups.INTERCEPTS = false
	Grades.BULK = false
	Wear.ENABLED = false
	return previous


static func parity_on() -> void:
	SensorNet.REALISM = true
	Economy.REALISM = true
	Arsenal.REALISM = true
	GroundWar.ENABLED = true
	Chronicle.ENABLED = true
	Agency.ENABLED = true
	Agent.ENABLED = true
	Fuel.ENABLED = true
	Orders.ENABLED = true
	Jobs.ISLAND_BOARD = true
	Investigation.ENABLED = true
	CoverCargo.ENABLED = true
	Comeback.ENABLED = true
	DealMoves.ENABLED = true
	Gigs.ENABLED = true
	StreakGuard.ENABLED = true
	Schedule.ENABLED = true
	Story.FLIGHT_GOALS = true
	Breakaway.ENABLED = true
	Wanted.ENABLED = true
	Curses.ENABLED = true
	BlackMarket.ENABLED = true
	HeatDial.ENABLED = true
	Businesses.ENABLED = true
	OrgAI.ENABLED = true
	Delegation.ENABLED = true
	Laundering.ENABLED = true
	Grades.ENABLED = true
	Pickups.ENABLED = true
	Trust.ENABLED = true
	Crates.ENABLED = true
	PriceWars.ENABLED = true
	Investments.ENABLED = true
	Takeover.ENABLED = true
	Pickups.INTERCEPTS = true
	Grades.BULK = true
	Wear.ENABLED = true
