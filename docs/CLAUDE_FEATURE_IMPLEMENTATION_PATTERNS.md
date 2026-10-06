# Claude Feature Implementation Patterns

See GitHub issues #80-#118 for the complete implementation backlog. These patterns are intended to be integrated with the existing Session/World authorities.

## Worker agents
Use stable IDs and states IDLE/TRAVELLING/WORKING/ARRESTED/DEAD/UNAVAILABLE. Physical arrival supplies progress while Payroll remains the economic authority.

    func tick(dt: float, now_tick: int, speed_mps: float) -> bool:
        if state == State.TRAVELLING:
            var step := maxf(0.0, speed_mps) * maxf(0.0, dt)
            if position.distance_to(destination) <= step:
                position = destination
                state = State.WORKING
            else:
                position = position.move_toward(destination, step)
        return state == State.WORKING and now_tick - task_started_tick >= task_duration_ticks

## Cargo
Use an atomic manifest. Validate destination/capacity before removing source cargo.

    func remove(kind: String, amount: int) -> bool:
        if amount < 0:
            return false
        if amount == 0:
            return true
        if int(units.get(kind, 0)) < amount:
            return false
        units[kind] -= amount
        if units[kind] <= 0:
            units.erase(kind)
        return true

Zero speed or zero elapsed time must leave a travelling worker in place. Do not
force a minimum movement per tick: that makes travel depend on the update rate.
Reject negative cargo quantities before mutating a manifest, and treat zero as a
successful no-op. The caller must validate both manifests before an atomic transfer.

## Intelligence
Each IntelRecord contains key, kind, location, subject, confidence, created_tick, expires_tick and source. Police consume only sourced records.

    func score(now_tick: int) -> float:
        if expires_tick >= 0 and now_tick >= expires_tick:
            return 0.0
        return confidence

## Dynamic checkpoint penalty

    func checkpoint_penalty(pos: Vector2, tick: int) -> float:
        var penalty := 0.0
        for c in active_checkpoints:
            if c.expires_tick <= tick:
                continue
            var d := pos.distance_to(c.position)
            if d < c.radius:
                penalty = maxf(penalty, c.strength * (1.0 - d / c.radius))
        return penalty

Inject this through the existing route-planner penalty hook; do not fork A*.

## Vehicle damage

    func apply_damage(amount: float) -> void:
        damage = clampf(damage + maxf(0.0, amount), 0.0, 100.0)
        if damage >= 100.0:
            destroyed = true
            disabled = true
        elif damage >= 70.0:
            disabled = true

Damage is event-driven, not random every frame.

## Informant reliability

    func report_quality(rng: RandomNumberGenerator) -> float:
        return clampf(
            reliability + (greed - fear) * 0.15 + rng.randf_range(-0.1, 0.1),
            0.0, 1.0
        )

The result becomes sourced evidence; it does not directly mutate police state.

## Dynamic jobs
JobGenerator is read-only and produces stable IDs from buyer/state/tick. It reads demand, inventory, heat, police activity, weather, route availability, aircraft and crew capacity.

## Environment

    func detection_multiplier() -> float:
        var visibility_factor := clampf(30.0 / maxf(2.0, visibility_km), 0.5, 3.0)
        var night_factor := 1.15 if time_minute < 360 or time_minute >= 1200 else 1.0
        return visibility_factor * night_factor

Environment state is deterministic and saveable.

## Flight planning
A pure evaluator should return fuel_required, fuel_ok, weight_ok, range_ok and safe. Autopilot must never override hard terrain/performance limits.

## Crew willingness

    func willingness(worker: Dictionary, task_risk: float) -> float:
        return clampf(
            0.5 + float(worker.trust) * 0.35
            + float(worker.skill) * 0.15
            - float(worker.stress) * 0.25
            - task_risk * 0.35,
            0.0, 1.0
        )

## World events
WorldEvent contains id, kind, tick, severity, location and expires_tick. Events publish into existing systems and never become a second source of economic/police truth.

## QRY/PNR autopilot
Do not change CROSS_TRACK_GAIN or bank limits to fix the circling bug. Reject unusable runway ends first, then score remaining candidates by distance, heading error and reversal severity.

    func score_approach(s, candidate: Dictionary) -> float:
        var bearing := PilotBot.bearing(s.x, s.y, candidate.final_x, candidate.final_y)
        var heading_error := absf(Py.wrap180(bearing - s.heading))
        var distance := Vector2(s.x, s.y).distance_to(
            Vector2(candidate.final_x, candidate.final_y)
        )
        var reversal := 1.0 if heading_error > 120.0 else 0.0
        return distance + heading_error * 80.0 + reversal * 50000.0

If already inside/past the approach corridor, project onto the runway centreline and generate a forward intercept point. Never target a final fix behind the aircraft merely because it is closest. Lock the runway-end/leg choice for the current approach so it cannot flip frame-to-frame.

## Rules
- Session/World/Police/Economy remain authoritative.
- UI/renderers do not own simulation.
- Seeded RNG only.
- Stable IDs and save/load compatibility.
- Deterministic tests with every feature.
- Fix simulation bugs instead of tuning around them.

