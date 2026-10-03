class_name Switches
extends RefCounted
## The one place that knows every static on/off switch in the sim and the renderer.
##
## New systems sit behind a static switch (an `ENABLED`-style `static var NAME := true`) so the parity
## and golden tests, which replay the Python prototype or a frozen run, can turn them off. A test that
## needs the old behaviour calls `Switches.parity_off()` in `before_each` and `Switches.parity_on()` in
## `after_each`, instead of listing the flags itself.
##
## `tests/test_switches.gd` fails if a switch exists in scripts/sim or scripts/render that is named in
## neither PARITY nor OPT_IN below, so a new system cannot forget to register.

## The switches the parity tests turn off: Godot-only rules that change what the Python game did.
const PARITY := [
	"SensorNet.REALISM", "Economy.REALISM", "Arsenal.REALISM", "GroundWar.ENABLED", "Chronicle.ENABLED",
	"Agency.ENABLED", "Agent.ENABLED", "Fuel.ENABLED",
]

## Switches no parity test touches. Most are opt-in anyway: the system only exists when the session's
## options ask for it, so a parity session never builds it. Each has its own tests that flip it.
const OPT_IN := [
	"Court.ENABLED", "Family.ENABLED", "Island.ENABLED", "Payroll.ENABLED", "Trade.ENABLED", "Races.ENABLED",
	"Rackets.ENABLED", "Renown.ENABLED", "StashWorks.ENABLED", "CityDress.ENABLED", "ModelLib.ENABLED",
	"Scenery.ENABLED", "GroundWar.ENGAGEMENT", "GroundWar.SMART_ROUTES", "GroundWar.VETERANS",
	"Logistics.ROUNDS", "Tactical.PYTHON", "RadioNet.REALISM", "Analyst.ENABLED", "Undercover.ENABLED", "DowntownDress.ENABLED",
]


static func parity_off() -> void:
	SensorNet.REALISM = false
	Economy.REALISM = false
	Arsenal.REALISM = false
	GroundWar.ENABLED = false
	Chronicle.ENABLED = false
	Agency.ENABLED = false
	Agent.ENABLED = false
	Fuel.ENABLED = false


static func parity_on() -> void:
	SensorNet.REALISM = true
	Economy.REALISM = true
	Arsenal.REALISM = true
	GroundWar.ENABLED = true
	Chronicle.ENABLED = true
	Agency.ENABLED = true
	Agent.ENABLED = true
	Fuel.ENABLED = true
