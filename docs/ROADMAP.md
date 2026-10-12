# Roadmap

Current queue, refreshed 12 October 2026. The previous text (reviewed 9 October) is kept in
[ROADMAP_HISTORY_2026-10-09.md](ROADMAP_HISTORY_2026-10-09.md); older progress is in
[ROADMAP_HISTORY_2026-10.md](ROADMAP_HISTORY_2026-10.md). Live state of every PR and issue is in
[PROJECT_TRIAGE_2026-10-12.md](PROJECT_TRIAGE_2026-10-12.md) (sections 1–6 and 10) and in
`github_merge_queue`. Generated facts are in [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Product direction (owner, 8 October 2026)

The approved direction is [DESIGN.md §0](DESIGN.md#0-where-the-game-is-heading-owner-approved-direction-8-october-2026):
build an empire from nothing, starting as a hired pilot. Four steps, in order:

| Step | Status (12 Oct) | Evidence |
|---|---|---|
| 1. The early rise: employed pilot, the business slides into smuggling, first aircraft earned | **Done** | Employed opening #296 merged. Pacing walkthrough and first-aircraft price are on the playtest list (#345). |
| 2. Setup-driven automation: assignments, then conditional orders and task sequences; manual play always remains | **Not started** | No merged work covers conditional orders or sequences. Payroll's fixed assignments are the only existing automation. |
| 3. Faction competition and the civilian economy | **Partly done** | Faction-AI isolation has forty-seed evidence (`FACTION_AI_ISOLATION_2026-10-09.md`). Escort and stakeout balance (#244, #98) waits on the owner's strip decision (#326). |
| 4. Multiplayer: co-op and competitive modes for 2–16 players | **Furthest along** | Host service steps 1–9 of #97 merged or in review (#97 open for broader entry-path coverage). Two-machine play and voice are not yet verified by hand. |

## Now: one-week polish and human testing (owner, 12 October)

No new features for one week. Work is polish, playtest fixes and human-run tests. Merges of already-reviewed work
continue. New feature branches wait; feature ideas go in as issues.

1. **The #345 playtest list:** tutorials split by phase (take-off, flight, landing, loading); air camera look; slow
   reverse; dirt take-offs too lethal; runway-end turn-around explained; key audit (Codex's QA lane).
2. **Human release gates (#326, owner runs them):** Windows and macOS walkthroughs; controllers and readability at
   four resolutions; two-machine multiplayer; functional-site walk; performance captures; radio and asset licensing.
3. **Merge queue:** reviewed PRs land in order (`github_merge_queue`). Each merge is followed by a sync of the next PR
   onto `main`, with the status file regenerated.

## Next: after the polish week

1. **Step 2, automation.** Conditional orders (stock thresholds) first, then task sequences. Workers follow
   instructions; AI never invents assignments. Needs a design note in `DESIGN.md` before any code.
2. **Step 3, faction and civilian economy.** Resolve the balance questions in #244 and #98 with the owner's
   strip decision. Then rivals' starting strengths and civilian jobs, demand and prosperity. Turf war stays late.
3. **Logistics access (#241 series).** Route access for the 99 audited logistics pairs is still blocked by grade,
   footprint and unauthored meeting points. The access stack (#265–#276) was closed unmerged on 12 October; its branches stay
   on origin, and any new access work starts from `main`. Re-run `tools/logistics_routes.gd` for a current count. Never raise connector limits or restore
   straight-line fallbacks to make numbers pass.
4. **Empire command and feedback (#242).** Owner overview, durable order lifecycle, operational debriefs, and first-
   decision teaching at the existing unlocks.
5. **Coastal art and release (#243).** One reference corridor first (HAR, the coastal road, Warehouse 7, the harbour),
   then architecture, period vehicles (#367 needs its geometry reworked first), cockpit surfaces and feedback.
   Frame-time captures before and after each asset batch.

## Future: presentation layers (owner ideas, 12–13 October; not scheduled)

Read-only presentation that follows the simulation. None of it may change a sim outcome or draw on a sim RNG stream.
Build after the territory radio, which supplies the first inputs.

1. **Territory radio and era music.** Each crew gets a station that is stronger in its district. Music evolves by era
   through stems (same key and tempo) and changes only at natural breaks. Original fictional tracks only.
2. **Era fashion and liveries.** Wardrobe, vehicle and aircraft paint change by in-game year, in step with the music.
   Owned aircraft keep their livery.
3. **Crew colours, signage and graffiti.** Each crew has a colour and motif. Graffiti and signs mark who holds a street
   and repaint when a district changes hands. Trusted crews' colours show on the player's clothing and car.
4. **City pulse.** Economy sets the rhythm, each faction gets a motif, disputed districts get an unresolved interval,
   and consequences give a directional stinger (push or pull). The HUD shows a pressure tilt, not a number. Each signal
   is named in the pause menu.
5. **Heat in the look.** Police heat shows as streetlight flicker, more patrols and darker clothing, easing off as the
   heat cools.

## Decisions waiting on the owner

- **Strip decision (#326, #88, #319, #323):** job generator versus strips.
- **Costa Brava rebuild (#368):** design call, then Codex QA.
- **Vehicle geometry (#367):** the Asset Bible's 1,500-triangle floor is not met (about 600–670 triangles).
- **AI knowledge policy:** how much police and rival AI may see. Needed before #244 is balanced.
- **Review route:** how the other agent's exact-head review is recorded when Codex is out of usage (`AGENTS.md`).
- **Engine (see [UNITY_MIGRATION_PLAN.md](UNITY_MIGRATION_PLAN.md)):** stay on Godot, or approve the one-week parity harness.

## Open technical items

- **Start-up architecture (#97):** entry paths consolidated across steps 1–9; the save-resume gap (a partial campaign
  resumes without its chapter setup) is a follow-up that needs a save-format change.
- **Test time:** the full suite takes about 13 minutes under the machine lock; a cold import in each worktree adds
  about 5. Speeding this up benefits every agent.
- **Windows memory:** overlapping Godot jobs have caused allocation failures; the lock is the only guard.
- **Stale stack:** #244–#276 closed with a comment each; salvage (#367, #368) is the only live part.
