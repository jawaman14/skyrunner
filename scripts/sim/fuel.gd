class_name Fuel
extends RefCounted
## Fuel for the organisation's hired fleet: trucks, contract pilots and go-fast boats burn it, a tank per driver
## and per pilot runs down, and when it will not cover the next run they stop and fill up first - which costs the
## organisation money at the day's price and the run some time. The price is Session.FUEL_PRICE_PER_LB (avgas, 6 lb
## to the gallon) x the economy's fuel multiplier (a refinery strike, a tanker in port, a storm); ground vehicles
## burn mogas at 55% of it. Nothing here is random.
##
##   truck    0.35 gal/km, a 25 gal tank (a 70 km range); fills at the pump before it leaves: 4 min + 6 s a gallon
##   pilot    a run burns 14 gal of a 40 gal tank; refuelling takes 15 min before the next run
##   boat     a go-fast burns 1.6 gal/km to the rendezvous and back; paid when the boat goes out
##
## Behind ENABLED (the Python-replay parity tests turn it off: they have no fleet to fuel).

static var ENABLED := true

const LB_PER_GAL := 6.0
const GROUND_SHARE := 0.55
const TRUCK_GAL_PER_KM := 0.35
const TRUCK_TANK_GAL := 25.0
const TRUCK_RESERVE_GAL := 3.0
const TRUCK_FILL_S := 240.0
const TRUCK_S_PER_GAL := 6.0
const PLANE_RUN_GAL := 14.0
const PLANE_TANK_GAL := 40.0
const PLANE_FILL_S := 900.0
const BOAT_GAL_PER_KM := 1.6


## $ a gallon at the pump now: "ground" (mogas) or "avgas".
static func price(sess, kind := "ground") -> float:
	var p: float = Session.FUEL_PRICE_PER_LB * LB_PER_GAL * float(sess.econ.fuel_mult())
	return p * (GROUND_SHARE if kind == "ground" else 1.0)


## How the price compares with the usual, as a fraction (+0.45 in a refinery strike).
static func trend(sess) -> float:
	return float(sess.econ.fuel_mult()) - 1.0


## The organisation (or Los Cuervos) pays `amount` for fuel: from the HQ's money or the gang's war chest.
static func pay(sess, o: String, amount: float) -> void:
	if amount <= 0.0:
		return
	if o == "org":
		sess.money -= int(round(amount))
	elif sess.ground != null:
		sess.ground.commanders.rival.cash -= amount
	sess.fuel_spent[o] = float(sess.fuel_spent.get(o, 0.0)) + amount


## A truck about to leave on a `km` run: the fuel for it, and a stop to fill up first if its driver's tank will
## not cover it. Adds the stop to the truck (refuel_s, and so dur). Returns a note for the message, or "".
static func truck(sess, t, km: float) -> String:
	if not ENABLED:
		return ""
	var need := km * TRUCK_GAL_PER_KM
	var p := price(sess, "ground")
	if sess.payroll == null or t.driver == "":
		pay(sess, "org", need * p)  # paid at the pump on the way: no tank to track
		return ""
	var w = sess.payroll.get_worker(t.driver)
	if w == null:
		pay(sess, "org", need * p)
		return ""
	var left: float = float(w.get("tank", TRUCK_TANK_GAL))
	var burn := need
	var filled := 0.0
	var stops := 0
	while left - TRUCK_RESERVE_GAL < burn and stops < 6:  # the tank will not cover the rest of the run: fill up
		filled += TRUCK_TANK_GAL - left
		left = TRUCK_TANK_GAL
		stops += 1
		if left - TRUCK_RESERVE_GAL >= burn:
			break
		burn -= left - TRUCK_RESERVE_GAL  # a run longer than a tank: drive down to the reserve and fill again
		left = TRUCK_RESERVE_GAL
	w["tank"] = maxf(0.0, left - burn)
	if stops == 0:
		return ""
	pay(sess, "org", filled * p)
	t.refuel_s = TRUCK_FILL_S * stops + filled * TRUCK_S_PER_GAL
	t.dur += t.refuel_s
	return "filled up first: %d gal, $%d, %d min" % [int(round(filled)), int(round(filled * p)), int(round(t.refuel_s / 60.0))]


## A contract pilot about to start a run: true if he can go (and the burn is taken off his tank), false if his tank
## would not cover it - he refuels instead (paid, and `delay` seconds of it before he is ready again).
static func pilot_ready(sess, o: String, w: Dictionary, delay: Array) -> bool:
	if not ENABLED:
		return true
	var tank: float = float(w.get("tank", PLANE_TANK_GAL))
	if tank < PLANE_RUN_GAL:
		var fill := PLANE_TANK_GAL - tank
		pay(sess, o, fill * price(sess, "avgas"))
		w["tank"] = PLANE_TANK_GAL
		delay.append(PLANE_FILL_S)
		return false
	w["tank"] = tank - PLANE_RUN_GAL
	return true


## A go-fast boat going out for a `km` run.
static func boat(sess, km: float) -> float:
	if not ENABLED:
		return 0.0
	var cost := km * BOAT_GAL_PER_KM * price(sess, "ground")
	pay(sess, "org", cost)
	return cost
