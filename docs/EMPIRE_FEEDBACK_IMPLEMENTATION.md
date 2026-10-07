# Empire command and feedback implementation package

Status: remaining implementation scope, 8 October 2026. Documentation only.
Built on EMPIRE_MILESTONE.md and draft implementation #234-#240.

## Preserve completed foundations

Do not rebuild squad cards, district control summaries, visibility-safe targeting
or own-unit battle history. #236 supplies squad detail; #238 protects targeting
and enemy plans; #239 supplies districts; #240 supplies bounded saved own-unit
accounts. Full grouped desktop evidence is 1,021 tests plus separately run focused
tests, not a merged baseline or human playtest. Keep the public four-region model.

## Implementation slices

1. Shared owner-only empire overview: distinguish safe cash, outlying cash, stock,
   payroll obligations, available/assigned/jailed crew and squad upkeep. Read the
   authoritative systems; label unavailable older-peer fields. Selected rows use
   stable IDs, persist focus through refresh and open existing action previews.
   Do not compute a misleading single net-worth or guarantee future income.
2. Durable order lifecycle: accepted, travelling, arrived, blocked, refused and
   result unknown. Correlate StationLink sequence acknowledgements; refreshed
   snapshots are separate evidence. Retain outcomes across selection changes.
   Disconnect/timeouts never automatically resend mutations. Show existing
   player/AI ownership and spending boundaries, without inventing new AI policy.
3. Operational debrief: adapt recorded delivery, interception, transfer, wage,
   injury/arrest and collection events. Use event IDs/sequence to order/deduplicate;
   show actual quantities, money destinations, obligations and recorded heat/control
   changes. Report missing evidence as unknown. Never reconstruct a historical
   cause from today's state or expose unseen police/rival decisions.
4. Extend battle accounts with recorded custody, retreat and known tactical facts.
   Current #240 strength/ammunition accounts are a foundation, not complete causal
   reports. Record own starting/remaining strength and actual custody separately;
   distinguish combat losses from wounded/arrested/captured transitions. Show
   recorded range, cover or surprise only when permission-appropriate; describe
   observed factors rather than claiming they caused a victory. Keep combat/random
   calculations unchanged in this presentation slice.
5. Teach first empire decisions at existing campaign unlocks. Connect useful flights
   to stock, wages, repairs and defence through read-only organisational context.
   Preserve four tutorial/twelve story chapters and targets. Teach consolidation,
   delegation limits and recovery without granting new mechanics or raising payouts.

## Acceptance

Local HQ and remote stations share descriptors and formatting. Test old peers,
role permissions, hidden squads/fights, lost contact, empty/long lists, stale rows,
partial outcomes, repeated input, cancellation, delayed acknowledgements and
handoff. Keep Session.command's [ok, message] contract and execution revalidation.
History is bounded, save-compatible and cannot invent events from old saves.

Exercise actual keyboard/mouse/controller events and both palettes at 1024x768,
1280x720, 1920x1080 and 2560x1080; visible focus and read-aloud remain usable.
Record physical controller, audible output and two-machine checks separately.
Run focused checks and grouped full shards/smoke/save/parity/export validation.
Use separate codex draft PRs for each implementation slice. Human acceptance and
operational-debrief completion must remain pending until evidence exists.
