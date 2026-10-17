# Worker map port — 9 October 2026

The protected desktop crew/map changes were reviewed against current main and ported independently. The desktop checkout and its unrelated files remain unchanged.

Own active payroll workers now appear in the People map layer with name, role and current assignment. Markers use existing authoritative bodies; they do not create people or control arrival. Law seats receive no criminal-worker positions. Jailed, dead, away, driver and squad workers cannot leave duplicate payroll markers.

The port honours the shared layer controls and palette. The desktop analyst percentage correction was already integrated and was not duplicated.

Validation: two focused tests passed with no script or parse errors. They cover all seat roles, stale body suppression, assignment changes, disabled bodies, read-only marker copies and layer filtering. Broader regression and CI remain required before integration. Physical controller and two-machine walkthroughs are not performed by these tests.
