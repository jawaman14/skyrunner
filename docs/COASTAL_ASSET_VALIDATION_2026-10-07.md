# Coastal asset batch validation — 7 October 2026

Reference tree: `b7a5b58`, before #227. Compared with #227 plus #228's
infrastructure geometry (`fb3dd8a`; the later benchmark warm-up change affects
only the tool). Separate managed baseline checkout; desktop edits untouched.

AMD RX 7900 XT, Godot 4.7.2, OpenGL compatibility, 1280×720, uncapped rendering,
fixed 14:00 static WorldScene, HAR–Warehouse 7–first harbour pier camera route.
`tools/coastal_benchmark.gd` warms one complete 360-frame sweep and measures a
second 360-frame sweep. Run each preset sequentially on the same machine.

| Preset | Mean before/after (ms) | P95 before/after (ms) | Static memory before/after (bytes) | Final-frame draw calls |
|---|---|---|---|---|
| Low | 0.5629 / 0.5589 | 0.763 / 0.753 | 240789572 / 240807913 | 173 / 173 |
| Medium | 1.1196 / 1.1126 | 1.456 / 1.412 | 295425414 / 295466955 | 176 / 176 |
| High | 2.7171 / 2.6647 | 3.288 / 3.336 | 296285198 / 296326803 | 571 / 571 |

No measured regression above 10%. Initial short-warm-up runs had nonrepeatable
spikes; three sequential low-preset repeats were stable. The final benchmark
warms the whole route so first-visit material compilation is outside sampling.
Do not interpret tiny differences as a proven performance improvement.

Limits: static scene, no gameplay/NPC load; static allocator memory is not total
process RAM or VRAM; draw-call values are the final frame, not a route maximum.
High preset under compatibility rendering reports unsupported SSAO/volumetric
fog warnings. Vulkan/full-effects and dense NPC profiling remain unperformed.

HAR on-foot screenshots rendered on low, medium and high. Low/high were visually
inspected: hangar front openings remained clear. Isolated workshop and mooring
previews were inspected. Workshop equipment: 288 triangles; mooring set: 432.
New bench details and tower aerial add no collision. Mooring upright/crossbar
use simple matching collision and are grounded on the first actual pier's quay,
offset from its centre approach; exported physical verification remains pending.

Focused checks: period props 3 passed, assets/export filters 2 passed, site access
6 passed; no script/parse errors. #227 CI run 37574532115 passed all shards,
server, exports and three desktop smoke jobs. #228's final CI remains pending.
Existing Godot screenshot shutdown resource/ObjectDB diagnostics persist.

Still required: actual dock/service loading walkthrough, all-preset detail/LOD
inspection, exported human walkthrough and full gameplay performance comparison.
The coastal reference area, vehicle pass and cockpit pass are not complete.
