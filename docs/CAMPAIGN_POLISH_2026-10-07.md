# Costa Brava campaign polish — 7 October 2026

Twelve story chapters and four flying tutorial chapters remain unchanged. Targets, prices, wages, combat, aircraft and deterministic random streams are unchanged.

## Player guidance

Open the phone and select **Chapter guidance and history**. This scrolling view retains completed chapter briefings, outcomes and the Blotter raid aftermath. Each chapter explains its new systems and first actions. Optional bonuses must be earned before mandatory completion advances the chapter. Campaign wealth includes spendable cash, product and outlying cash; aircraft and vehicle values are excluded. Clean-case goals require consecutive minutes below 50%; reaching 50% resets the timer.

## Corrected outcomes

Island shipments count only when some product arrives. Buying a casino stake requires ownership, not laundering. Missing evacuation is recorded separately from escape. Unavailable factions waive unfinished objectives with reasons rather than invented counters. Old saves preserve their chapter and progress; new outcome/history fields are optional. The Company dialogue offers four rifles to match its chapter goal.

## Validation status

Final desktop regression: **1,002 passed, 0 failed** across three shards (330 / 339 / 333), Godot 4.7.2 on Windows. No script/parse failures or freed-lambda capture diagnostics. Smoke: **SMOKE OK**. Native Git hygiene and diff checks pass; export-filter, save/load and parity coverage are included in the full suite. Existing ObjectDB/resource/PagedAllocator shutdown cleanup diagnostics remain.

Focused phone/entry tests: 12 passed, including native mouse, keyboard dispatch, controller Back/entry acceptance, read-aloud invocation and guide bounds at 1024x768, 1280x720, 1920x1080 and 2560x1080 in both palettes. Dialogue: 20 passed. Rendering lifecycle: 15 passed. An additional 80 actual shipment resolutions (2 fully intercepted, 78 with product delivered) verify the published delivered quantity.

Paired campaign stand-in: seeds 1–40, sixteen simulated hours, compared with `8900e1d`. All 40 individual result rows and aggregate statistics are identical. 18/40 finish, 27/40 reach Last Flight and 33/40 reach The Hearings. This does not establish human flight pacing or exercise every casino branch; focused tests cover failure/ownership outcomes. [Recorded aggregate](../sim-results/campaign-polish-2026-10-07.json).

Draft dependency order: [#229](https://github.com/jawaman14/skyrunner/pull/229) → [#230](https://github.com/jawaman14/skyrunner/pull/230) → [#231](https://github.com/jawaman14/skyrunner/pull/231) → [#232](https://github.com/jawaman14/skyrunner/pull/232). The current managed baseline depends on asset draft #228; nothing in this continuation has been merged. #229–#231 CI passes at their code heads; #232 CI remains pending at this report checkpoint.

The full run exposed an existing debris timer capturing a freed body. #232 uses a WeakRef and tests scene removal through the eight-second expiry; visual timing and authoritative gameplay stay unchanged.
 Human campaign pacing, physical controller operation, exported walkthroughs and two-machine validation remain unperformed. No economic recalibration is included. Existing historical campaign saves cannot reconstruct unrecorded earlier briefings/outcomes; history begins with future transitions.
