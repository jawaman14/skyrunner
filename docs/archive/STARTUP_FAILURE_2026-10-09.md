# Startup failure cleanup — 9 October 2026

A real entry-point regression test reserves a TCP port, calls Main.start with direct hosting enabled, and checks the local fallback. Before the fix it failed because Main retained the unsuccessful HostServer child. Main now schedules that node for deletion before continuing locally; no voice service is created for the failed host.

The test uses a separate temporary save directory and frees the session. The reproduction failed one assertion; the corrected run passed one test without script or parse errors. Existing host-service lifecycle tests remain part of regression coverage.

This is one concrete slice of issue #97. Successful solo/co-op/versus startup, waiting-room transition/cancellation, late join and seat variants still need a complete entry-point matrix. Human two-machine validation remains pending. Issue #97 stays open.
