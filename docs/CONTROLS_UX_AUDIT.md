# Controls UX audit — 2026-10-08

Reviewed ControlsConfig, ControlsMenu, PilotApp keyboard dispatch, Walker and Car movement, and the flight ControlMapper.

## Implemented

- Keep existing flight defaults and saved bindings: WASD/arrows flight axes, Q/E rudder, R/F throttle, Z/X full/cut, G/T flaps, Space/B brake and brackets trim. No flight performance changes.
- Split F8 into Flight bindings, Flight hardware and Other controls, with bindings first. Each page scrolls independently and follows focus.
- Replace right-click-only calibration decrement with explicit keyboard/controller-focusable minus and plus buttons. Previously right-click was also included in the button's activation mask and could invoke the increment callback.
- Put hardware controls on stacked rows rather than nine columns. Wrap binding descriptions and references.
- Make F8 available while walking and driving, after modal handling and repeat suppression.
- Add a compact contextual shortcut reference. Phone is the discoverable entry to contacts; direct cockpit shortcuts remain available.

## Remaining opportunities

- Only flight bindings are remappable. Walking, driving, organisation shortcuts and several seat actions are hardcoded; a unified context-aware action registry would make prompt generation and rebinding consistent.
- Flight rebinding swaps other flight controls but does not warn about fixed cockpit actions (for example I turns around). Rebinding should explain context-specific collisions before saving; blindly sharing a key can activate two behaviours.
- Organisation Shift shortcuts compete with held flight letters. Route organisation access through the Phone as the primary discoverable path, then assess held-flight input suppression before removing shortcuts.
- F1/help and some HUD hints are static; derive flight hints from saved bindings in a subsequent slice.
- Walking/controller coverage and station-specific controls require a separate complete input audit. This reference describes pilot contexts; it is not a claim of complete controller support.
- Keep essential movement, interaction and pause visible; put advanced flight and management shortcuts behind context help. Avoid adding a global radial menu before existing contexts have consistent actions.

## Validation

Desktop headless: 10 binding/axis tests and 4 real-event modal tests pass. The new modal test checks the 1024×768 hardware layout, focus-follow scrolling and Enter decrement. Existing tests check palette activation, held Enter suppression and controller Back focus restoration. No script/parse failures. Godot reports existing ObjectDB/resource shutdown cleanup diagnostics. Full suite, visual review at every supported resolution and physical controller testing were not run for this UI slice.
