# Waiting-room and voice service lifecycle — 8 October 2026

The host's multiplayer waiting room now advertises on LAN before the host starts
the game. The existing Announce setting still controls whether it sends adverts.
The beacon belongs to its HostServer, so cancelling the room frees it with the
server. Starting the game reuses that same beacon.

Repeated host setup creates one voice pipeline for that server, and repeated
client voice setup creates one pipeline for that connection. Host voice still
starts with gameplay, rather than opening a microphone in the waiting room.
The existing room, seat, voice transport and Session command contracts remain.

The duplicate-host setup test failed before the correction (two voice nodes).
Afterwards all four lifecycle tests pass, along with 15 room tests, eight LAN/table
tests and seven multiplayer-menu tests: 34 total, zero failures and no script or
parse errors. Godot shutdown cleanup diagnostics and the test runner argument
warning in the existing main-scene menu test remain separate limitations.

These are automated lifecycle/loopback checks. Physical microphone playback,
real LAN discovery on two computers and seat-handoff acceptance remain unperformed.
Issue #97's broader entry-point audit and #89's human multiplayer gate remain open.
