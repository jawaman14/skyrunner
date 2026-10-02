class_name ControlMapper
extends RefCounted
## Turns digital key presses (and optional analog axes) into smooth control
## surface commands. Keyboard flying is only tolerable with rate limiting and
## auto-centring; the mouse-yoke mode gives proportional control.

const FLAP_NOTCHES := [0.0, 0.33, 0.66, 1.0]
const THROTTLE_STEP := 0.4  ## R/F (PgUp/PgDn): full range in 2.5 s while held, so a tap is a few percent
const THROTTLE_RAMP_UP := 0.7  ## Z: to full in about 1.5 s
const THROTTLE_RAMP_DOWN := 1.2  ## X: to idle in under a second
## A key is all or nothing, so on the ground the rudder key is scaled down with speed: a full-scale
## kick at 36 kt swings a Cessna 17 deg/s, banks it 16 deg and noses it over.
const RUDDER_KEY_SLOW_KTS := 8.0
const RUDDER_KEY_FAST_KTS := 30.0
const RUDDER_KEY_FAST_AUTH := 0.06
const BRAKE_APPLY := 1.5  ## the key is on or off, the brakes come on over two thirds of a second (a chirp, not a lock-up)
const BRAKE_RELEASE := 6.0
const BRAKE_FAST_KTS := 45.0  ## above this, hard braking pitches a light aircraft onto its nose: the key gets half the brake
const BRAKE_FAST_AUTH := 0.5


## Everything the front end collected this frame.
class InputFrame:
	var held := {}  ## logical actions currently held (set: action -> true)
	var pressed := {}  ## one-shot actions this frame
	var stick = null  ## [roll, pitch] -1..1, pitch +1 = pull
	var rudder_axis = null
	var throttle_axis = null


var controls := FlightModel.Controls.new()
var flap_index := 0
var roll_authority := 0.65
var pitch_authority := 0.6
const ASSIST_ROLL_AUTHORITY := 0.35  ## gentler keys once the assist holds the attitude: a tap is a nudge
const ASSIST_PITCH_AUTHORITY := 0.45  ## the flare still needs real elevator at 45 kt

## Keyboard flight assist (like control-wheel steering): with no roll key held the wings are levelled,
## with no pitch key held the pitch attitude is held. Airborne and keyboard only - a stick or yoke
## (inp.stick), the bot and the autopilot fly unassisted. Off unless the session turns it on.
var assist := false:
	set(v):
		assist = v
		roll_authority = ASSIST_ROLL_AUTHORITY if v else 0.65
		pitch_authority = ASSIST_PITCH_AUTHORITY if v else 0.6
const ASSIST_ROLL_KP := 0.05  ## aileron per degree of bank
const ASSIST_ROLL_KD := 0.03  ## ... per degree/s of roll rate
const ASSIST_PITCH_KP := 0.07  ## elevator per degree off the held pitch
const ASSIST_PITCH_KD := 0.10  ## ... per degree/s of pitch rate
const ASSIST_ROLL_MAX := 0.4
const ASSIST_PITCH_MAX := 0.4
var _pitch_hold = null  ## the pitch attitude being held (deg), null while a pitch key is down
var throttle_target = null  ## Z / X: the setting the throttle is ramping to (null when the pilot has it by hand)


static func _approach(cur: float, target: float, rate: float, dt: float) -> float:
	var step := rate * dt
	if absf(target - cur) <= step:
		return target
	return cur + step if target > cur else cur - step


static func _b(d: Dictionary, k: String) -> int:
	return 1 if d.has(k) else 0


func reset(throttle := 0.0) -> void:
	throttle_target = null
	controls = FlightModel.Controls.make({"throttle": throttle})
	flap_index = 0


## `st`: the flight state, only needed for the keyboard flight assist.
func update(dt: float, inp: InputFrame, st: FlightModel.FlightState = null) -> FlightModel.Controls:
	var c := controls
	var h := inp.held
	# roll / pitch
	if inp.stick != null:
		c.aileron = inp.stick[0]
		c.elevator = -inp.stick[1]
	else:
		var roll_t: float = (_b(h, "roll_right") - _b(h, "roll_left")) * roll_authority
		var pitch_t: float = (_b(h, "pitch_down") - _b(h, "pitch_up")) * pitch_authority
		c.aileron = _approach(c.aileron, roll_t, 2.5 if roll_t else 4.0, dt)
		c.elevator = _approach(c.elevator, pitch_t, 2.0 if pitch_t else 3.0, dt)
	# rudder
	if inp.rudder_axis != null:
		c.rudder = inp.rudder_axis
	else:
		var rud_t := float(_b(h, "yaw_right") - _b(h, "yaw_left"))
		if st != null and st.on_ground:
			var k := clampf((st.gs_kts - RUDDER_KEY_SLOW_KTS) / (RUDDER_KEY_FAST_KTS - RUDDER_KEY_SLOW_KTS), 0.0, 1.0)
			rud_t *= pow(RUDDER_KEY_FAST_AUTH, k)  # steering saturates fast, so fall off exponentially
		c.rudder = _approach(c.rudder, rud_t, 3.0 if rud_t != 0.0 else 4.0, dt)
	# throttle
	if inp.throttle_axis != null:
		c.throttle = inp.throttle_axis
	else:
		var step := _b(h, "throttle_up") - _b(h, "throttle_down")
		if step != 0:
			throttle_target = null  # the lever by hand again
			c.throttle += step * THROTTLE_STEP * dt
		# Z and X ramp to full / idle; the same key again is the instant chop (or the go-around slam)
		if inp.pressed.has("throttle_cut"):
			throttle_target = null if throttle_target == 0.0 else 0.0
			if throttle_target == null:
				c.throttle = 0.0
		if inp.pressed.has("throttle_full"):
			throttle_target = null if throttle_target == 1.0 else 1.0
			if throttle_target == null:
				c.throttle = 1.0
		if throttle_target != null:
			var tt: float = throttle_target
			c.throttle = _approach(c.throttle, tt, THROTTLE_RAMP_UP if tt > c.throttle else THROTTLE_RAMP_DOWN, dt)
			if c.throttle == tt:
				throttle_target = null
	c.throttle = minf(1.0, maxf(0.0, c.throttle))
	# trim
	c.pitch_trim += (_b(h, "trim_up") - _b(h, "trim_down")) * -0.35 * dt
	c.pitch_trim = minf(1.0, maxf(-1.0, c.pitch_trim))
	# flaps
	if inp.pressed.has("flaps_down"):
		flap_index = mini(FLAP_NOTCHES.size() - 1, flap_index + 1)
	if inp.pressed.has("flaps_up"):
		flap_index = maxi(0, flap_index - 1)
	c.flaps = FLAP_NOTCHES[flap_index]
	var brake_t := 0.0
	if h.has("brake"):
		brake_t = 1.0
		if st != null and st.on_ground:
			brake_t = lerpf(1.0, BRAKE_FAST_AUTH, clampf((st.gs_kts - 25.0) / (BRAKE_FAST_KTS - 25.0), 0.0, 1.0))
	c.brake = _approach(c.brake, brake_t, BRAKE_APPLY if brake_t > c.brake else BRAKE_RELEASE, dt)
	if assist and st != null and inp.stick == null and st.valid and not st.on_ground:
		return _assisted(c, h, st)
	_pitch_hold = null
	return c


## A copy of `c` with the assist's corrections added (the mapper's own state stays the pilot's).
func _assisted(c: FlightModel.Controls, h: Dictionary, st: FlightModel.FlightState) -> FlightModel.Controls:
	var out := c.copy()
	if not (h.has("roll_left") or h.has("roll_right")):
		out.aileron = clampf(c.aileron - (st.roll * ASSIST_ROLL_KP + st.p_dps * ASSIST_ROLL_KD), -ASSIST_ROLL_MAX, ASSIST_ROLL_MAX)
	if h.has("pitch_up") or h.has("pitch_down"):
		_pitch_hold = null
	else:
		if _pitch_hold == null:
			_pitch_hold = st.pitch
		out.elevator = clampf(c.elevator + (st.pitch - float(_pitch_hold)) * ASSIST_PITCH_KP + st.q_dps * ASSIST_PITCH_KD,
			-ASSIST_PITCH_MAX, ASSIST_PITCH_MAX)
	return out
