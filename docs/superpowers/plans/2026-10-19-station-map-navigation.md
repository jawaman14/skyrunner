# Station map navigation implementation plan

Use superpowers:executing-plans inline.

Goal: D-62's desk zoom and D-49's existing destination feedback, without world-map redesign or new simulation orders.
Files: scripts/station/station_map.gd, scripts/station/station_app.gd, tests/test_station_link.gd.
Architecture: keep role-filtered snapshots; one affine world/screen transform shared by drawing and clicks; three scales, clamped pan and toolbar controls.
Constraints: no new hidden information; no worker command contracts; D-75 world redesign remains paused.
- [ ] Verify coordinate, cursor-anchor and wheel-input regression checkpoint fails.
- [ ] Add three scales, middle-button pan, reset and visible toolbar controls.
- [ ] Draw destination feedback only from already visible snapshot fields.
- [ ] Verify exact-head CI and fresh review before integration.
