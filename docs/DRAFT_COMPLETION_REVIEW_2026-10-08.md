# Draft completion review — 8 October 2026

Reviewed all 31 initially open draft PRs, their bases, narrow diffs, validation records and review threads. This is a source and automated desktop review, not a human gameplay acceptance session.

## Completed review work

- Refreshed #227 against current main without conflicts; its four-file workshop scope remains narrow. Full desktop suite: **1,002 passed, zero failed**; current CI passed all eight checks.
- Marked documentation PRs #241, #242, #243, #246, #249 and #264 ready for review. Their future implementation packages remain pending.
- #270 fixes false checked-route failures when the nearest endpoint nodes belong to disconnected components. Alternate access legs retain all existing physical checks and the 120 m limit.
- #271 fixes HQ district Q navigation and held-key reactivation using real viewport input events.
- #272 indexes legacy road-node construction while preserving earliest-match semantics and exact graph output.
- Preserved unrelated desktop changes and all feature dependencies. No PR was merged into main.

## Validation

Combined review code at b92a081c25d9c12765cb6a9a8a1906c7dd7ced32 passed **1,062 tests, zero failed** across shards **351 / 361 / 350**. Logs contained no script or parse failures. Godot shutdown resource/ObjectDB/PagedAllocator cleanup diagnostics remain separately recorded.

Seven paired road-construction runs matched every node and edge: mean construction fell from 167.85 ms to 28.66 ms. All 100 benchmark route queries matched. See [construction evidence](ROAD_NODE_INDEX_2026-10-08.md).

Ten three-hour war stand-in seeds matched every aggregate field in the prior post-setback baseline a30900fb4d760ed9ce40e8d9c1900ad63da8a676. Current raw rows are recorded in [simulation results](../sim-results/draft-review-war-2026-10-08.json). The older baseline has aggregates only; this is not a claim of historical raw-row equality or human campaign balance acceptance. Wider AI/map balance changes still require isolation and review. Hygiene passed. The isolated-save 1,800-frame desktop smoke reported `SMOKE OK` without script or parse failures.

## Per-PR disposition

| PR | Scope | Review disposition |
|---|---|---|
| [#227](https://github.com/jawaman14/skyrunner/pull/227) | feat: add period workshop equipment to HAR hangar | Keep draft; implementation/evidence gates remain |
| [#228](https://github.com/jawaman14/skyrunner/pull/228) | feat: add coastal period infrastructure and reconcile asset queue | Keep draft; implementation/evidence gates remain |
| [#229](https://github.com/jawaman14/skyrunner/pull/229) | fix: report actual Costa Brava chapter outcomes | Keep draft; implementation/evidence gates remain |
| [#230](https://github.com/jawaman14/skyrunner/pull/230) | feat: add persistent Costa Brava chapter guidance | Keep draft; implementation/evidence gates remain |
| [#231](https://github.com/jawaman14/skyrunner/pull/231) | feat: polish Costa Brava contact dialogue and epilogue | Keep draft; implementation/evidence gates remain |
| [#235](https://github.com/jawaman14/skyrunner/pull/235) | feat: map authored logistics loading endpoints for checked access | Keep draft; implementation/evidence gates remain |
| [#236](https://github.com/jawaman14/skyrunner/pull/236) | feat: share squad condition travel and upkeep command detail | Keep draft; implementation/evidence gates remain |
| [#237](https://github.com/jawaman14/skyrunner/pull/237) | fix: use validated local detours for checked vehicle access | Keep draft; implementation/evidence gates remain |
| [#238](https://github.com/jawaman14/skyrunner/pull/238) | fix: restrict HQ targeting to observed squads | Keep draft; implementation/evidence gates remain |
| [#239](https://github.com/jawaman14/skyrunner/pull/239) | feat: explain district control costs and collection at command desks | Keep draft; implementation/evidence gates remain |
| [#240](https://github.com/jawaman14/skyrunner/pull/240) | feat: retain own-unit battle accounts in command views | Keep draft; implementation/evidence gates remain |
| [#241](https://github.com/jawaman14/skyrunner/pull/241) | docs: plan remaining Costa Brava access and movement work | Documentation scope complete; ready for review |
| [#242](https://github.com/jawaman14/skyrunner/pull/242) | docs: plan empire dashboard order outcomes and operational debriefs | Documentation scope complete; ready for review |
| [#243](https://github.com/jawaman14/skyrunner/pull/243) | docs: plan coastal art gameplay profiling and release acceptance | Documentation scope complete; ready for review |
| [#244](https://github.com/jawaman14/skyrunner/pull/244) | fix: retain live escorts and clear reassigned police stakeouts | Keep draft; implementation/evidence gates remain |
| [#245](https://github.com/jawaman14/skyrunner/pull/245) | fix: release surviving squads when combatants are removed | Keep draft; implementation/evidence gates remain |
| [#246](https://github.com/jawaman14/skyrunner/pull/246) | docs: audit jobs, gameplay systems and multiplayer coverage | Documentation scope complete; ready for review |
| [#247](https://github.com/jawaman14/skyrunner/pull/247) | feat: rebuild Costa Brava settlements with period architecture | Keep draft; implementation/evidence gates remain |
| [#248](https://github.com/jawaman14/skyrunner/pull/248) | Improve controls navigation and accessible hardware calibration | Keep draft; implementation/evidence gates remain |
| [#249](https://github.com/jawaman14/skyrunner/pull/249) | Record player direction and remaining delivery coverage | Documentation scope complete; ready for review |
| [#250](https://github.com/jawaman14/skyrunner/pull/250) | feat: start new stories flying a legitimate employer's aircraft | Keep draft; implementation/evidence gates remain |
| [#251](https://github.com/jawaman14/skyrunner/pull/251) | fix: teach the first smuggling route through an unpoliced strip | Keep draft; implementation/evidence gates remain |
| [#252](https://github.com/jawaman14/skyrunner/pull/252) | Show the first aircraft ownership milestone in career guidance and journal | Keep draft; implementation/evidence gates remain |
| [#253](https://github.com/jawaman14/skyrunner/pull/253) | Add desktop gameplay recordings and update README and player docs | Keep draft; implementation/evidence gates remain |
| [#255](https://github.com/jawaman14/skyrunner/pull/255) | Fix explicit chapter selection after employed opening | Keep draft; implementation/evidence gates remain |
| [#258](https://github.com/jawaman14/skyrunner/pull/258) | Optimize road search while preserving exact path tie order | Keep draft; implementation/evidence gates remain |
| [#264](https://github.com/jawaman14/skyrunner/pull/264) | Record PR completion dispositions and 1,050-test corrective evidence | Documentation scope complete; ready for review |
| [#265](https://github.com/jawaman14/skyrunner/pull/265) | Correct the villa's road terminal and loading approach | Keep draft; implementation/evidence gates remain |
| [#267](https://github.com/jawaman14/skyrunner/pull/267) | fix: add physical FRM service approach for Company loading | Keep draft; implementation/evidence gates remain |
| [#268](https://github.com/jawaman14/skyrunner/pull/268) | fix: clear Costa Brava roads through functional buildings | Keep draft; implementation/evidence gates remain |
| [#269](https://github.com/jawaman14/skyrunner/pull/269) | feat(assets): add weathered period land vehicles with shared LODs | Keep draft; implementation/evidence gates remain |

## Remaining gates and implementation

Physical Costa Brava access still reports **21 reachable / 78 blocked** audited endpoint pairs. Correct entrances/loading connectors and authored road geometry before migrating trucks and squads wholesale. Do not expand connector limits or restore obstacle-bypassing shortcuts.

#247 is a settlement foundation, not a completed map rebuild. Whole-map access, existing-save positions, moving performance and wider balance remain outstanding. Integrate #245 with #240; richer causal battle reports and durable empire order lifecycle remain packages in #242. #243 still requires a physically validated coastal corridor. #269 supplies period vehicle geometry, not animated loading or accepted in-world art.

Unperformed acceptance includes human campaign/empire walkthroughs, physical controller tests, walking/driving all entrances and bridges, exported Windows walkthroughs, real two-machine actions/handoff/voice, and dense combat profiling. Radio rights remain unresolved. Source tests cannot replace these gates.

See [remaining roadmap](ROADMAP.md). Historical roadmap claims and queues are retained in [the dated archive](ROADMAP_HISTORY_2026-10.md).

