class_name RouteBests
extends RefCounted
## The pilot's own records per route (from>to): the fastest time and the softest touchdown. A per-machine file like controls.cfg, not
## part of the game save: a record is the player's, whichever game it was set in.

const PATH := "user://route_bests.cfg"
static var path := PATH  ## tests point it elsewhere


## Benny's time for a route: what an experienced pilot does in this aircraft, straight there at cruise plus three minutes for the
## take-off and the circuit. Seconds.
static func benny_seconds(from_code: String, to_code: String, aircraft_key: String) -> float:
	var a := World.airfield(from_code)
	var b := World.airfield(to_code)
	var kts := float(PilotBot.CRUISE_KTS.get(aircraft_key, 110))
	return PyMath.hypot(a.x - b.x, a.y - b.y) / (kts * 0.514444) + 180.0


## Record a flight; returns {best_seconds, softest_fpm, new_time, new_soft} with the records as they stand after it.
static func record(from_code: String, to_code: String, seconds: float, touchdown_fpm: float) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(path)
	var key := "%s>%s" % [from_code, to_code]
	var best: float = float(cf.get_value(key, "seconds", INF))
	var soft: float = float(cf.get_value(key, "fpm", INF))
	var new_time := seconds < best
	var new_soft := touchdown_fpm < soft
	if new_time:
		best = seconds
		cf.set_value(key, "seconds", seconds)
	if new_soft:
		soft = touchdown_fpm
		cf.set_value(key, "fpm", touchdown_fpm)
	if new_time or new_soft:
		cf.save(path)
	return {"best_seconds": best, "softest_fpm": soft, "new_time": new_time, "new_soft": new_soft}


static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
