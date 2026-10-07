# Gameplay recordings — 8 October 2026

These silent clips were rendered on the owner's Windows desktop from the development stack following #252 (`229d1bb`), with capture-tool changes supplied by this PR. Godot 4.7.2 Movie Maker captures deterministic 15 fps, 1280×720 output using OpenGL compatibility on an AMD Radeon RX 7900 XT. Playback timing is fixed; recording speed is not a performance benchmark. Videos use H.264/yuv420p with fast-start metadata. Audio is omitted, including archived radio excerpts.

## Coverage and staging

| Clip | What is shown | Limits |
|---|---|---|
| [Opening](media/opening.mp4) | New employment briefing, legal job board, loan pricing, first-ownership journal | Purchase funds supplied by the tool. Does not measure earning/pacing or fly four deliveries. |
| [Interface](media/interface.mp4) | Lobby, job selection, load/CG/fuel planner, hangar, airdrop HUD, co-pilot and organisation/police orders, leave cancellation | Authored local sessions and timed actions; some use menu helpers rather than physical input. No real remote peer. |
| [Coast and logistics](media/coast-logistics.mp4) | Costa Brava city/estuary/farms, airdrop, radar/DF maps, jammer, stash transport, market and upgrades, night coast | Camera paths, stock/scenario setup and accelerated transport. Does not validate every route or entrance. |
| [Turf war](media/turf-war.mp4) | Staged squad firefight, lieutenant/patrol cards, local seat roster, on-foot rifle feedback, example reward banner and night city | Seeded/pre-advanced war, repositioned squads, supplied rifle/ammunition, synthetic roster and reward banner. No claim that the banner was earned in the clip. |
| [Flight and police](media/flight-police.mp4) | AI takeoff/flight alongside task-force radar for the same local session | Seeded tactical scenario; not two machines, human flight, or a completed smuggling run. |
| [Services](media/services.mp4) | Contact book, vehicle lot, race availability, collection policies, roulette command/result | Systems and funds enabled explicitly; no campaign unlock, driven race, casino travel or property ownership demonstration. Arrival dialogue can appear over the roulette result. |

All public capture sessions use Costa Brava. Classic geometry is not used in these clips. The capture scripts do not load or write player saves. Staging remains in tools, not gameplay rules.

## Reproduce

From the repository on Windows, with Godot 4.7.2 and FFmpeg/ffprobe on PATH:

```powershell
./tools/record_gameplay.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

Raw AVI files and logs stay in the temporary capture directory. Only compressed videos/posters and the media manifest are committed under `docs/media`, already excluded by export filters. The runner rejects nonzero Godot exits and script/parse/assertion failures, then checks each encoded file with ffprobe. Original tours also dispose their scenario sessions. Known ObjectDB/resource/PagedAllocator shutdown cleanup diagnostics are recorded separately from functional errors.

## Review and outstanding work

Inspect sampled frames across every clip for correct map, visible content and honest captions; inspect logs for script/parse failures. This is selected scenario coverage, not every job, dialogue branch, tactic, aircraft, interior or gameplay mechanic. Physical controller input, four-resolution/both-palette/read-aloud review, human campaign enjoyment/pacing, exported human walkthrough and real two-machine voice/handoff remain unperformed.

Capture review exposed stale classic-map defaults and invalid staging in older tours. This PR selects Costa Brava explicitly, supplies demonstration rifle equipment, enables service prerequisites and labels synthetic seat/reward/purchase setups. These tool fixes do not alter economic or combat authority.

The new gameplay additions documented alongside these clips are the employed opening, unsuitable criminal-route correction and first-ownership journal/guidance (#250–#252). See [EMPLOYED_OPENING.md](EMPLOYED_OPENING.md) for automated validation and remaining acceptance gates.

Validation: all six final capture logs contain no script/parse/assertion failures; export-filter coverage passes **2 tests**, zero failed. Every MP4 is probed and sampled visually; [manifest](media/manifest.json) records durations, codec, dimensions and content hashes. This media/tool/documentation slice does not claim a fresh full gameplay suite.
