# Planning a move from Godot to Unity

Status: **proposal, not decided.** Written 12 October 2026 at the owner's request. Nothing here changes the game, the build, or the agents' lanes. The decision is the owner's, and this document is the input to it.

## 1. What is being weighed

Skyrunner is pure GDScript on Godot 4.7.2, with no native code. Moving to Unity means a new engine, a new language (C#) and new build, test and CI tooling. The question is whether the benefits justify that cost, and if so, how much of the game must move at once.

## 2. What the codebase is made of today (measured on `origin/main`, 12 Oct)

| Area | Files | Notes |
|---|---|---|
| GDScript, total | 407 files, about 80,200 lines | includes tests and tools |
| Simulation (`scripts/sim/`) | 81 | headless, seeded, deterministic; no engine dependency in intent |
| Tests (`tests/`) | 150 | run headless in Godot; a suite of about 1,126 test methods |
| Engine-facing game code | about 176 | UI, pilot app, station desks, networking, scenes (`scripts/game`, `scripts/ui`, `scripts/station`, `scripts/net`, `scripts/main.gd`, tools) |
| Scene files (`.tscn`) | 2 | almost all UI and scene structure is built in code |
| Engine-API touchpoints | about 200 files | `get_tree`, `Node`/`Control`/`Node3D` base classes, `Resource`, signals |
| Networking | 6 files | `ENetMultiplayerPeer`, `TCPServer`, `StreamPeerTCP`, `PacketPeerUDP` |
| Animation and tweens | 4 files | `Tween`, `AnimationPlayer` |
| Models | 936 files under `assets/models` | Kenney, KayKit and Quaternius packs (kept per the owner) |
| Flight data | 149 files under `data/jsbsim` | JSBSim-format XML, read by our flight model |
| Balance and sweep tools | `scripts/balance/`, `tools/` | headless, produce `docs/BALANCE.md` and sim results |

The counts are approximate (counted by file, not by function). The key fact: **the simulation is about a fifth of the code and is the part that must stay exactly right.** The rest is the engine layer.

## 3. What must not change

- **Determinism.** Seeded runs, RNG streams and the parity switches (`scripts/sim/switches.gd`) define what the game does. The golden fixtures (`tests/fixtures/`, `T.golden()`) and the frozen Python-prototype fixtures are the reference. A Unity port must reproduce them bit-for-bit or the change is a balance change, not a port.
- **Flight model.** The 6-DOF model reads JSBSim XML. Replacing it would shift every flight golden. Keep the physics code and its data; only the host changes.
- **Multiplayer protocol v3.** Seats, TCP framing, dedup and voice relay are a wire contract. A client in another engine must speak the same protocol while both versions exist.
- **Save format.** Saves are in `user://saves/` (one file per mode, per #365). A port must read them or ship a one-time migration.
- **The agents' workflow.** The skyrunner MCP tools (`skyrunner_run_tests`, `skyrunner_smoke`, `skyrunner_screenshot`, the Godot lock in `run_locked.py`) are built for Godot's headless CLI. Each would need a Unity equivalent before the agents can work on the port.

## 4. Options

**A. Stay on Godot (recommended until the spike below says otherwise).** No cost, no risk, all tooling works. The known weak points (test time of about 13 minutes under the lock, Windows memory limits) are tooling problems, not engine problems, and can be fixed in place.

**B. Hybrid: keep the simulation as a pure library, rebuild the presentation in Unity.** The simulation (81 files) is written in GDScript, so it would be ported to C# first, then run inside Unity. This is the only option where the golden fixtures can prove the port. The engine layer (about 176 files) is rebuilt on Unity's UI and scene tools. Largest effort, but the most reversible: the simulation port can be tested against the existing goldens before any UI moves.

**C. Full rewrite into Unity.** Everything moves at once. Highest risk: the goldens and the playtest feel both change together, so a regression cannot be attributed. Not recommended.

## 5. Recommended path if the owner wants the move

**Phase 0 (about 1 week, no game change).** Write the parity harness outside the game: a script that runs the simulation headless, dumps the same output as the goldens, and compares. It must be engine-neutral so it can check a C# port. Also list each Godot-only API used by the sim (should be near zero) and by the engine layer (about 200 files).

**Phase 1 (spike, 2–3 weeks, a branch, not `main`).** Port `scripts/sim/` to C# for one system (flight: `scripts/sim/flight/` with its JSBSim XML). Pass the flight goldens bit-for-bit. Decide the RNG and float behaviour first; the stream table in `docs/DESIGN.md` must carry over exactly. **Exit criterion:** the flight goldens pass and a headless run is as fast as Godot's. If not, stop, and stay on Godot.

**Phase 2 (if the spike passes).** Port the rest of the simulation, using the switches and stream table. Keep the Godot build running on `main` throughout; the Unity build lives beside it.

**Phase 3.** Rebuild the engine layer: the pilot app, the station desks, the menus and HUD, the multiplayer seat flow. Start with the least risky screen (the menus), and keep UI design under Codex's UX lane (`UIStyle` and `GameMenu` become a Unity theme).

**Phase 4.** Rebuild tooling: the MCP tools, the Godot lock (it would become a Unity batch-mode lock), CI exports, smoke and screenshot jobs.

**Phase 5.** Human gates (controllers, readability at four resolutions, two-machine multiplayer, performance captures) run against the Unity build before it replaces Godot. Those gates stay the owner's (#326).

## 6. Risks

- **Float and RNG drift.** Porting GDScript floats and the RNG to C# can change results in the last bit, which breaks determinism. Mitigation: a bit-level parity test in Phase 0.
- **Two engines during the move.** Both builds must stay in CI, which doubles the export and smoke lanes for the duration.
- **Agent tooling.** Until Phase 4, the agents cannot run the full loop on the Unity branch. Work would fall back to the owner or to manual runs.
- **Assets and licences.** The model packs and the radio audio licence (#175) need checking against Unity's import rules. The Kenney, KayKit and Quaternius packs are generally usable in Unity, but the audio is still a human gate.
- **Cost to the owner.** Every phase needs a decision or a human playtest.

## 7. Decisions the owner needs to make

1. Stay on Godot, or approve the Phase 0 harness (about 1 week of work, no game change)?
2. If approved for the spike, which system should it prove first: flight (proposed), or the save format?
3. Is the C# port acceptable for the simulation, given its determinism tests?
4. Who owns the Unity branch: Claude (simulation lane), Codex (UI lane), or both?

## 8. Not in scope here

- No code is moved, deleted or renamed by this document.
- No issue is closed or re-scoped by it. #97 (start-up architecture) continues on Godot.
- The Unity question does not change the review, merge or claim rules in `AGENTS.md`.
