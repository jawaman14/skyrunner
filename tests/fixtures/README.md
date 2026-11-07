# Parity fixtures (frozen)

These JSON files are reference values produced once by the Python prototype (the git tag
`python-prototype-archive`, archival) through `tools/reference/gen_*.py`. The parity tests (`test_*_parity.gd`, `test_police.gd`)
replay the same seeds in Godot, with the Godot-only rules switched off, and require bit-identical
results. They are frozen: the Godot game is the only game, and nothing here is regenerated in normal
work. Regenerate only if you deliberately change a rule the prototype shares, using the matching
`tools/reference/gen_*.py`.

## Flight golden (`flight_golden.json`)

One exception: everything that *flies* (the take-off roll in `test_core_parity.gd`, the seeded bot
flight in `test_bots_parity.gd`, the tactical and feasibility trials in `test_trials_parity.gd`) is
checked against `flight_golden.json` instead. The Python prototype flew JSBSim; the game now flies
its own flight model (`scripts/sim/flight/`), which can't match JSBSim bit for bit. These values
come from the Godot game itself (`godot --headless --script tools/regen_flight_golden.gd`) and pin
the flight model and the bot down as a determinism check. Regenerate them only when you
deliberately change the flight model, the aircraft data or the pilot bot, and say so in the commit.
The trial inputs still come from `trials_ref.json`, and the Python `fm`/`flight` entries in
`core_ref.json` and `bots_ref.json` are kept as history.

## Strategic golden (`strategic_golden.json`)

The HQ season simulator's values (seasons, the win matrix, equilibrium, dominance, summary, action values, the calibration from
`tactical_sample.json`), from the game itself (`godot --headless --script tools/regen_strategic_golden.gd`). It replaced the
Python `strategic_ref.json` on 8 November (F-6, D-74), written from a build that matched Python exactly, so the numbers carried
over unchanged. Regenerate it only for a deliberate change to the season rules, and say so in the commit.

## Strategic save v1 (`strategic_save_v1.json`)

A v1 `StrategicSave.capture` written once by the game itself (not the Python prototype) and never regenerated. `test_strategic_save.gd`
restores it and requires every block back as written, so a `VERSION` bump must add a step to `StrategicSave.STEPS` that carries it forward.
