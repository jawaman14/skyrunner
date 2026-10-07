# Coastal art, playability and release implementation package

Status: proposed remaining work, 8 October 2026. Documentation only; no new assets
or release evidence. Follows EMPIRE_MILESTONE.md. Existing #227/#228 workshop,
signs, aerial and mooring geometry remain the starting point, not a completed area.

## Reference area first

Finish HAR, its coastal access road, Warehouse 7, harbour and nearby services as
one usable corridor. Audit foundations, doors, desks, loading/parking approaches,
waterfront edges and road/yard transitions before adding decoration. Share site
records and collision; all presets must preserve functional doors and passages.
Document a walking/driving route and repeat it after each batch.

## Reviewable asset slices

1. Complete functional coastal architecture: weathered period materials and painted
   wayfinding, fences/poles, workshop, dock and communications equipment. Neon stays
   concentrated in nightlife/interface accents. Reuse existing licensed materials
   or original modular geometry/SVGs; import only actually used cleared assets.
2. Period vehicles and readable crew identities: improve silhouettes, clothing and
   loading/parking/disembarking presentation. Preserve collision dimensions,
   performance and one authoritative worker body. Animation follows travel/arrival
   state; it does not resolve simulation outcomes or invent stock.
3. Analogue cockpit surfaces on existing aircraft after corridor/vehicle acceptance.
   Improve readable instruments and period equipment without changing aircraft,
   flight behaviour or adding fleet content. Retain distant LODs/material reuse.
4. Event feedback: distinguish delivery arrival, incoming fire, damaged vehicles,
   retreat and lost contact through authoritative events and original/cleared audio.
   Near/distant gunfire and command acknowledgements should reduce HUD burden.
   Effects, bloom and shake must not obscure targets/navigation/interaction prompts.
   Do not distribute unresolved bundled radio material (issue #175).

## Performance evidence

The 7 October coastal benchmark is a warmed static camera sweep at 1280x720 under
OpenGL compatibility on RX 7900 XT. It showed no >10% regression for the initial
batch; static allocator memory and final-frame draw calls do not establish total
RAM/VRAM or dense-combat performance. See COASTAL_ASSET_VALIDATION_2026-10-07.md.

Capture fixed moving gameplay and dense-squad routes before/after each new batch,
with matched seed/time/preset/hardware and warm-up. Record frame-time mean/P95,
memory metric definition and LOD transitions. Investigate regressions above 10%.
Measure supported rendering effects explicitly; do not infer Vulkan behaviour from
compatibility-mode warnings. Asset Bible triangle/texture budgets and consolidated
provenance/actual-use records accompany every implementation PR.

## Human gameplay and release gates

Record early pilot, first ground-war and later empire sessions separately. Observe
whether flights fund stock/wages/repair/defence and delegation gives useful control.
Classify piloting losses, strategic mistakes, unclear instructions, repetitive
travel, access failures and opaque automation before considering balance changes.
Test expand/consolidate/defeat/recover paths. Stand-in completion rates are not fun
measurements; preserve four tutorials, twelve story chapters and existing balance.

Required release evidence remains: human exported Windows walkthrough, physical
controller, audible read-aloud, both palettes/four supported resolutions, real
two-machine remote actions/seat handoff/voice, and redistribution rights clearance.
Use dated records with build SHA/platform/scenario/result; mark unperformed checks
pending. Full shards, smoke, save/parity, export filters and platform CI supplement
rather than replace these gates. Squash completed tested PRs in dependency order;
retain evidence-dependent drafts and open issues. No automatic merge is requested.
