# Test fixture audit — 9 October 2026

Issue #101's execution split is integrated through #286. Recorded desktop feedback was 41 logic tests in 9.8 seconds, versus the historical 1,019-test full run in 803.7 seconds. These are different workload sizes, not a claim of faster individual tests. Every presentation, socket and simulation lane remains required; pinned engine caching excludes mutable game state.

## Shared fixture boundary

The existing T.golden cache is a suitable shared fixture: it parses a fixed JSON oracle, contains only values, and its core, bot and trial parity consumers read it. The cache now recursively freezes all dictionaries and arrays. A focused contract test checks the entire tree, including nested values, so no caller can alter a later test's expected result. The fixture file and numerical values remain unchanged.

Full Sessions were considered and remain separate. Renown fixtures tick the Session and alter the event bus, economy, candidates and feature switches; network fixtures change seats, authority and command state; frontend fixtures change menus and the live Session. Session construction itself registers mutable subsystems and world state. None of those is an immutable fixture suitable for cross-test sharing. Geometry tests already use local World instances or static source values and restore map selection. No mutable Session is cached.

Validation is recorded in the PR: read-only contract plus unchanged core/session/bot/trial parity checks. Per-file timings continue to come from the test runner. Real gameplay, hardware and export walkthrough gates are separate.
