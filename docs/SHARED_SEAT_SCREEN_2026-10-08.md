# Shared multiplayer seat screen — 8 October 2026

RoomScreen now owns both waiting-room and running-game seat selection. SeatPicker is a compatibility adapter, retaining its table, selected-role keys, key actions and seated signal for older callers. The existing StationLink contract and Roles descriptions remain authoritative; no wire protocol or ownership rule changes.

Running games use a scrolling table and the same player/chat/exit surfaces as the waiting room. Roster refresh preserves the selected role by stable ID. Waiting-room Take/Give back focus follows the role when rows refresh. Player names clip inside a scrolling roster, including sixteen-player tables. Open screens refresh the selected palette.

Claims are sent once and await the host's confirmed role or refusal. A disconnect or unanswered claim is reported as result unknown and is never automatically resent. Leaving closes the connection, returns to the lobby and suppresses late seat confirmation. A newly unavailable seat is rejected locally, with persistent feedback; the host still makes the authoritative decision.

Keyboard, mouse and controller use the same claim path. Controller A needed explicit handling because Godot Tree handles navigation but does not emit row activation for A. Controller B exits while the roster is focused; Escape exits and T focuses chat. Keyboard echo and repeated activation cannot duplicate a pending claim.

Validation: five new regression tests, five existing room-screen tests and fourteen existing seat tests pass with no script/parse failures. The new input test injects actual viewport events for controller navigation/activation, keyboard Enter/echo and mouse double-click at 1024×768, 1280×720, 1920×1080 and 2560×1080 in both palettes, with sixteen players. It checks roster/chat bounds and palette updates. Full regression and current-head CI remain required before integration.

Physical controller acceptance and a real two-machine waiting-room, handoff and voice session remain unperformed release gates. This slice addresses the seat-screen duplication in #96; the existing shared link contract, role metadata and menu shell are retained rather than rebuilt.
