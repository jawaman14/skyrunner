# Controls reference (default bindings)

This is the source-checked key map behind the pilot's F1 help and F8 **Other controls** page (playtest [#345](https://github.com/jawaman14/skyrunner/issues/345)); the audit evidence and the open checks live in that issue and in PR #369. It records the default bindings; a player's saved flight bindings may differ and are shown in F8.

| Context | Keys checked against input handling | Source |
|---|---|---|
| Flight axes and one-shot controls | W/S, Up/Down pitch; A/D, Left/Right roll; Q/E yaw; R/F, PageUp/PageDown throttle; B/Space brakes; brackets trim; G/T flaps; X/Z throttle presets | `scripts/game/controls_config.gd`, `scripts/game/pilot_app.gd` |
| In aircraft | Tab leave when parked; J/L/H menus; N transponder; U autopilot; K kick; O call boat; V pump; I turn around; 7 squawk; C camera; M map; Y mouse yoke; P pause; Enter confirm; Escape pause/close | `scripts/game/pilot_app.gd` |
| Aircraft function keys | F1 help; F2 time; F3 AI pilot handoff; F6 performance overlay; F7 radio; F8 bindings; F9 screen filter; F10 skip lesson; F12 feedback; Ctrl+F5 chapter skip in solo play | `scripts/game/pilot_app.gd` |
| Global multiplayer and voice | F4 opens the multiplayer menu; F4 or Escape closes it. Push to talk defaults to the backtick key and can be rebound in the multiplayer menu; Shift with the chosen key speaks to the table. | `scripts/main.gd`, `scripts/ui/multiplayer_menu.gd`, `scripts/net/voice_settings.gd` |
| Aircraft modifiers | Shift+F10 tutorial toggle; Shift+T phone; Shift+H logistics; Shift+B trade; Shift+L lawyer; Shift+F Family; Shift+W hiring; Shift+G General; Shift+C collective; Shift+V car lot; Shift+K casino; Shift+U/I island orders; Shift+Y/N/P Family decisions; Shift+O short boat code | `scripts/game/pilot_app.gd` |
| On foot | Tab board aircraft; WASD/arrow movement, Shift run, Space jump; E use, F torch, T phone, I pack, 5 medkit; 1–4 weapons, H holster, R reload; Z/X/C/V field orders; Escape releases captured mouse or pauses | `scripts/game/pilot_app.gd`, `scripts/game/walker.gd` |
| Driving | W/S or Up/Down accelerator and reverse; A/D or Left/Right steer; Space handbrake; E exit; R radio; comma/period tune | `scripts/game/car.gd`, `scripts/game/pilot_app.gd` |
| Station and remote seats | Arrows, Enter, Tab, plus/minus, letters and 1–4 go through each desk's role-specific `_key`; F10 controls the desk tutorial, F12 saves feedback, Escape asks to leave. Remote crew uses K/O/V/T; remote interceptor uses Space/H/X plus flight axes. Their visible hints depend on the seat. | `scripts/station/station_app.gd`, `scripts/station/remote_seat.gd` |
