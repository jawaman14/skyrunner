# Open PR integration record — 8 October 2026

Finish existing scopes before implementing the larger future features. The
[original audit](OPEN_PR_AUDIT_2026-10-08.md) remains a dated record of #227–#253
at their audited heads, not the current completion queue.

## Integrated work

Each completed slice was squash-merged separately, with narrow diffs against
main and focused checks after retargeting. Superseded branches remain available.

| PR | Result | Main commit |
|---|---|---|
| #254 | Original audit and exact inventory | `525b550` |
| #259 | Bounded TCP framing/queues, connection-scoped command deduplication | `f6a2526` |
| #260 | Stale-input neutralization; queue seat generations prevent release/reclaim revival | `c9bd9df` |
| #261 | Safe debris expiry through WeakRef | `8a7d076` |
| #262 | Persistent race refusals and stable course selection | `9b705e8` |
| #263 | Observed-only fight snapshots; dated empire direction document | `3347007` |
| #280 | Exact parity restoration and seeded-generator scanner | `bc38cfd` |
| #281 | Vegetation preset and deterministic resource coverage | `47d66d9` |
| #282 | Waiting-room beacon and voice service lifetime | `3246965` |
| #284 | Stateless dispatch of all 105 command handlers | `9d879ba` |
| #286 | Separate complete logic/simulation/presentation/socket gates | `07e816c` |
| #285 | Shared waiting-room/running-game seat screen | `828ba50` |
| #288 | Taxi action tests and complete #94 coverage matrix | `549ec05` |
| #289 | Own active payroll markers in the People layer | `2456b1a` |
| #290 | Failed direct-host server cleanup | `a3f66fb` |
| #291 | Recursively read-only parity oracle and fixture audit | `aae28fa` |
| #287 | Generated checkout status and separate release evidence | `c7b8763` |

Original #256/#257/#232/#233/#234 are closed with links to their integrated
replacements. This does not close broader multiplayer, controls, combat or
release-evidence issues. Campaign history documents from #232 remain preserved
on its original branch and the campaign stack.

## Verification

**9 October merged-main confirmation:** `c7b8763` passes 1,027 desktop tests, zero failures (314 / 357 / 356 in 254.6 / 163.0 / 313.1 seconds), all three processes exit zero. No script/parse failures; known shutdown cleanup diagnostics remain. The following balance record changes no game or test source.

**9 October follow-up:** main `a3f66fb` has an identical tracked tree to desktop candidate `28e66cb`, which passed 1,026 tests in 863.3 seconds. The final status/fixture candidate `6c7f3ef` / identical retargeted tree `9faac70` passes 1,027 tests in 909.3 seconds; all game/test files match merged main `c7b8763`. Final focused checks pass: save/load 33, determinism 5 and export filters 2. Isolated desktop smoke is `SMOKE OK`; hygiene and generated-status checks pass. No script/parse failures; known shutdown resource diagnostics remain. Documentation evidence edits follow those runs. #287–#291 each passed all eleven exact-head CI jobs before separate squash merges. Human, rights, physical access and performance gates remain pending as listed in PROJECT_STATUS.md.

The four newer integrations each passed all eight current-head CI jobs before squash merge. Historical #277/#278/#279/#283 are closed as superseded; their branches remain available for descendants. The wide overhaul tree passed 1,076 desktop tests with no script/parse failures. This includes unmerged physical work and is not a main-tree or human walkthrough claim. #285 and #286 are now squash-merged after all eleven current-head CI jobs passed. #288 is squash-merged as `549ec05` after all eleven current-head checks passed, publishing the remaining taxi coverage. Later desktop results are recorded in the 9 October follow-up above.

Post-merge desktop run at `3347007`: **1,002 passed, zero failed**
(321 / 339 / 342). No script or parse failures. The resulting Git tree is also
identical to the pre-integration head `214660a`, which passed all eight CI jobs:
three shards, dedicated server, exports and Linux/Windows/macOS smoke checks.
Main's own pipeline at `3347007` also passed all eight jobs.

Post-retarget focused checks: effects 15, menus seven, ground 23; corrected
network tests 16. Isolated post-merge 1,800-frame desktop smoke reports `SMOKE OK`;
repository hygiene passes. ObjectDB/resource/RID/PagedAllocator cleanup diagnostics
are retained separately from functional failures. Final focused reruns pass:
save 33, parity 14 and export filters two, with no script/parse/test failures.
The save process returned a nonzero exit during native shutdown cleanup; its
33 tests passed. This diagnostic is not recorded as a clean engine exit.

#260's individual Linux job was still installing Mesa when integration occurred;
it had not reached game code. Its other seven jobs and the final combined
eight-job batch passed. Do not describe that installer job as a game smoke pass.

## Disposition of remaining original PRs

| PRs | Current scope and remaining work |
|---|---|
| #227–#228 | Workshop/coastal equipment implemented; exported physical access, appearance, LOD and moving performance acceptance pending. |
| #229–#231 | Campaign outcome/guidance/dialogue work implemented in drafts; branch/pacing/input human acceptance and dependency integration pending. |
| #235 | Loading endpoint API implemented; physical connections and live dispatch migration incomplete. |
| #236–#239 | Squad detail, checked detours, visible targeting and district summaries implemented; dependencies and peer/human acceptance pending. |
| #240/#245 | Battle accounts and external-removal correction must integrate together; richer tactical/custody explanations remain separate future work. |
| #241–#243 | Documentation-only physical/empire/coastal proposals, not implemented feature packages; sibling branches outside the latest gameplay ancestry. |
| #244 | [Forty-seed isolation](FACTION_AI_ISOLATION_2026-10-09.md) attributes changed arrests/stash losses to stakeout cleanup; active cargo escorts remain unmeasured. Draft pending real transport evidence, calibration and #240 dependency. |
| #246 | Gameplay/network audit complete; reproduced framing/deduplication/freshness findings are now corrected on main. Real multiplayer evidence remains pending. |
| #247 | Partial map rebuild: current 99-pair audit still 13 reachable / 86 blocked. Connections, saved positions, physical crossings and broader balance/performance gates remain. |
| #248 | Flight controls UX scope implemented; broader binding registry is future work and physical hardware acceptance remains pending. |
| #249 | Owner direction/coverage documentation; later choices govern future product order, not claims of implemented features. |
| #250–#252 | Employment, criminal unloading and first-ownership foundation implemented in drafts; #255 fixes explicit chapter selection. Contract/pacing/independent unlocks remain future work. |
| #253 | Silent staged recordings/docs; do not advertise as a complete human or multiplayer walkthrough. |

The original code chain remains #227–#240 → #244–#253, with closed originals
retained in its ancestry. Do not merge an unfinished dependency merely to reach
a completed later slice. #255/#258/#264/#265 remain corrective/status drafts.

## Draft evidence and remaining gates

The full corrective gameplay tree at `54db9d7` passed 1,050 tests. The later
villa-corrected tree at `bbf6a24` passes **1,052** (338 / 361 / 353), with no
script/parse failures. These are unmerged-stack counts, not the main baseline.
#258's stable heap preserves all 100 sampled historical paths and improves
search mean 2.620→2.268 ms/p95 6.184→5.324 ms; not frame-time acceptance.

#265 removes the villa spur's terminal from inside the building and gives its
existing loading yard clear local access both ways. All 14 road tests pass.
The full route audit remains 13/99 reachable: upstream connectivity is still
missing. Ten paired three-hour war seeds have identical canonical aggregate
outcomes before/after this local correction. This does not accept earlier map
or AI outcome shifts, full logistics balance or human pacing.

Still unperformed: exported human walkthrough, entrances/bridges both ways,
physical controllers, audible read-aloud, four resolutions/both palettes,
real two-machine actions/voice/handoff and human campaign/empire pacing.
Archived radio redistribution rights remain unresolved. Preserve Costa Brava
focus, four tutorial/twelve story chapters, save and command compatibility,
legacy route APIs, calibrated rules and parity fixtures. No automatic replay
of unanswered mutations, hidden-state exposure or compensation tuning.
