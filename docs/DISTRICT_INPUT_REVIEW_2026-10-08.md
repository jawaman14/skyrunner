# District input review — 8 October 2026

Review of #239 reproduced native Q being swallowed by the district overview.
The boss seat remained claimed instead of returning to the orders desk. Handle
Q before the overview's scrolling branch and clear the overview on leaving
squad mode. Keyboard echo on Q/D is ignored in PilotApp, preventing a held key
from immediately reclaiming the seat or repeatedly toggling the view.

Nine HQ action-review tests pass, including the failing-before-fix SubViewport
test routed through PilotApp with real key press/repeat/release events. Existing
district mouse/controller bounds tests cover four resolutions and both palettes.
Shared confirmation, hidden-map targeting and no-mutation cancellation checks
remain intact. Physical controller/audible speech and two-machine acceptance are
still unperformed. This is a navigation/ownership correction, with no changes
to the simulation's orders, weapons, wages or combat rules.
