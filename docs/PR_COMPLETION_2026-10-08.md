# Open PR completion pass — 8 October 2026

This is a dated implementation/evidence record. Finish existing scopes before
adding the larger features in the planning PRs. Technical mergeability and green
CI do not replace scope review or human release acceptance.

## Verified corrective batch

The gameplay stack at `54db9d7` passes **1,050 desktop tests, zero failures**
(336 / 361 / 353), with no script or parse errors. The isolated 1,800-frame
employment startup reports `SMOKE OK`; repository hygiene passes. Existing
ObjectDB/resource/RID shutdown cleanup diagnostics remain separately recorded.

- [#255](https://github.com/jawaman14/skyrunner/pull/255): explicit chapter 1 now
  skips employment, like later chapter shortcuts. Default startup retains it.
  Nine employment tests include chapters 1, 2 and 12 and normal startup.
- [#256](https://github.com/jawaman14/skyrunner/pull/256): frame-size enforcement
  precedes parsing; bounded commands retain the originating connection and
  deduplicate sequence IDs. Cached acknowledgements replay the original result;
  expired sequences never execute again. Thirteen network tests pass.
- [#257](https://github.com/jawaman14/skyrunner/pull/257): stale flight inputs
  neutralize after one second without changing human ownership; fresh input
  recovers. Seat changes/disconnects clear old controls. Fifteen combined tests pass.
- [#258](https://github.com/jawaman14/skyrunner/pull/258): stable A* heap preserves
  historical tie order. Thirteen road tests pass. A 100-pair Costa Brava search
  benchmark has zero path mismatches; mean 2.620→2.268 ms, p95 6.184→5.324 ms.
  This is search timing, not frame-time, memory or gameplay balance acceptance.

[#254](https://github.com/jawaman14/skyrunner/pull/254) is squash-merged into main
as `525b550`; it records the original audit, not implementation of every finding.
Independent clean-main integration candidates #259–#263 isolate network,
debris, race and fight-privacy fixes from the unfinished asset/map/campaign stack.
Their readiness and actual merge status must be checked on GitHub; preparing
them is not integration evidence. Close superseded originals only after merging
their replacements.

## Disposition of each original PR

| PR | Existing scope and next acceptance work |
|---|---|
| #227 | HAR workshop assets implemented; exported physical access/appearance pending. |
| #228 | Coastal equipment implemented; dock/corridor collision, moving LOD/performance and human access pending. |
| #229 | Campaign outcomes implemented; branch walkthrough and human pacing pending. |
| #230 | Guidance/history/navigation implemented; physical controller, audible read-aloud and visual acceptance pending. |
| #231 | Contact/epilogue rewrite implemented; human branch walkthrough pending. |
| #232 | Debris expiry patch implemented/tested; isolated integration candidate #261 excludes unrelated campaign-history documents. |
| #233 | Race feedback/course identity implemented/tested; isolated candidate #262, hardware acceptance remains a release gate. |
| #234 | Observed-only fights implemented/tested; isolated candidate #263. Broader AI knowledge policy remains separate. |
| #235 | Read-only loading endpoint foundation implemented; physical routes and dispatch migration remain incomplete. |
| #236 | Shared own-squad condition/travel/cost cards implemented; peer/input acceptance pending. |
| #237 | Checked local detours implemented; no claim that all endpoints are connected. |
| #238 | Visible-only HQ target selection and non-owner route filtering implemented; remote human acceptance pending. |
| #239 | Four-region district summary implemented; human strategic readability pending. |
| #240 | Bounded owner-only battle accounts implemented; integrate #245 lifecycle correction together. Rich tactical explanations remain separate. |
| #241 | Documentation-only physical-access proposal; reconcile dated counts below, do not advertise dispatch migration. |
| #242 | Documentation-only empire-feedback proposal; dashboard/durable order lifecycle/operational debriefs remain future implementation. |
| #243 | Documentation-only coastal-release proposal; whole corridor, people/vehicles, dense profiling and human gates remain incomplete. |
| #244 | Escort/stakeout commitment fixes implemented; material paired-seed changes need isolated broader balance evidence. |
| #245 | External-removal finalization implemented/tested; prerequisite correction for #240 accounts. |
| #246 | Documentation audit complete; network findings corrected by #256/#257, with independent candidates #259/#260. Two-machine evidence remains pending. |
| #247 | Partial map rebuild: 13/99 loading pairs reachable, 86 blocked. Authored connectors, saved positions, physical crossings, performance and balance gates remain open. |
| #248 | Flight-controls UX scope implemented; broader binding registry is future work, hardware checks pending. |
| #249 | Owner direction/coverage documentation implemented; supersedes conflicting older product priorities, not their evidence. |
| #250 | Employment foundation implemented; integrate #255 chapter-selection correction. Contract expense/pacing and independent unlocks remain future work. |
| #251 | Real criminal delivery/unloading correction implemented; human risk and pacing pending. |
| #252 | First-purchase journal/ownership guidance implemented; human presentation pending. |
| #253 | Six silent staged recordings implemented; not a full human or multiplayer walkthrough. Recapture only materially changed demonstrations. |

The existing main code dependency chain remains #227–#240 → #244–#253.
#241–#243 are sibling planning branches based on #240, not ancestors of #253.
Keep them explicitly accounted for when reconciling documentation. Do not merge
a dependent draft simply to reach a completed later patch.

## Historical evidence and remaining gates

The earlier #237 loading audit measured 7/99 reachable and 92 blocked. The
current #247/#253 audit measures 13/99 reachable and 86 blocked: 17 footprint,
one QRY shed footprint, nine missing Family meeting areas, 30 disconnected
network and 29 without nearby checked access. Preserve the old report as dated
history. These queries do not establish that every human entrance is unusable.

Do not raise the 120 m connector limit, restore straight-line fallback or tune
speed/payout/hazards to conceal access failures. Author physical approaches
before migrating trucks, then squads; preserve La Selva's deliberate remoteness.
The heap optimization changes search cost, not map geometry or strategic rules.

Still unperformed: exported human walkthrough, every functional entrance and
bridge in both directions, physical controllers, audible speech, four supported
resolutions/both palettes, real two-machine actions/voice/handoff and human
campaign/empire pacing. Archived radio redistribution rights remain unresolved.
Do not close those issues or describe this pass as release acceptance.
