# BLACKFILE — Seven Boxes (first playable Godot slice)

A **separate** fictional investigation game. It is not a reconstruction of actual 1977 archive interviews or CIA documents, and it does not imply that records prove experiments in every subproject. The historical facts in the claim register are distinct from invented puzzle artefacts.

## Run

Open this folder (`prototypes/blackfile/seven_boxes/` in the SkyRunner checkout) as its own Godot project using **Godot 4.3+**; 4.7.2 is the version recorded by the SkyRunner project. Press F6/F5 in the editor or use:

```bash
godot --path prototypes/blackfile/seven_boxes --editor
godot --path prototypes/blackfile/seven_boxes
```

Or install from the downloadable ZIP: extract the `blackfile_seven_boxes` folder and point Godot to the folder's `project.godot`.

## Gameplay

1. Field route: visit the archive, finance desk, loading bay and oversight office. Each action is limited to the room in which it belongs.
2. Delegated route: click MODE: FIELD to switch to MODE: DELEGATED. The same nine case commands can be issued anywhere (with identical costs/results to field mode).
3. Inventory, reconcile records, interview and protect redacted identities. Do not assume lost files can be recreated.
4. Submit a **qualified** oversight report only after meeting evidence, review and privacy requirements; or reach one of three other legitimate endings.
5. SAVE/LOAD uses a distinct JSON file under `user://`. LOAD replays audited commands and rejects unknown versions or inconsistent balances without erasing the current case.

The in-game source links open original/curated references in the user's browser. `S007` (2024) is displayed **only** in the modern-reader source pane, not as a 1977 character document.

## Test

```bash
godot --headless --path prototypes/blackfile/seven_boxes --script res://tests/run_tests.gd
```

Tests cover requirements, four endings, non-invented citations, negative budget constraints, source integrity, route equivalence, ledger conservation, audit replay, save migration safety and tamper rejection.

## Integration to SkyRunner

- This is a self-contained Godot application, not a new default lobby option.
- No changes to main SkyRunner scripts, scenes, `project.godot`, save files, role permissions or multiplayer tests.
- Later connect `command(actor, route, action_id, room)` to the planned shared actor/organisation command gate, clock and ledger **once their interfaces pass the Living District milestone**. Both routes already produce the same world-state deltas.
- Archive-case budgets are synthetic in-game values, **not** historical CIA expenditures.

## Status

The scripts are written; a live Godot import/run must be completed before asserting playability on a particular PC. Check the draft PR's CI, Godot console and the command above.
