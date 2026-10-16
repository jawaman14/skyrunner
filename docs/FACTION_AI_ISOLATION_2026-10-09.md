# Faction AI isolation study â€” 9 October 2026

This completes the requested separation of PR #244's escort and stakeout corrections. It is diagnostic evidence, not a gameplay change or approval to merge that PR.

## Method

Current-main source `a3f66fba1cb723f1b0dab3ef35b2cedc2adfb910`; Godot 4.7.2 stable on Windows x64. Forty paired seeds (1â€“40), three simulated hours each, the canonical `tools/live_balance.gd` war configuration. Four fresh-process variants: original source, escort correction alone, stakeout correction alone, both. The two individual corrections ran in isolated managed worktrees. All 160 runs completed without script/parse errors; known engine shutdown resource diagnostics remain. No speed, payout, weapon, route, hazard or AI-knowledge tuning was made.

[Metadata, exact source hashes, summaries and paired differences](../sim-results/faction-ai-isolation-2026-10-09.json) link to four raw NDJSON files, forty seed-labelled rows each. Every raw row round-trips identically to its original result. Three zero-context patches retain the exact experimental differences; source fingerprints enforce the exact base. The earlier ten-seed unmerged-stack record remains a separate dated study; these figures use a current-main baseline.

## Results

| Variant | Mean arrests | Mean organisation losses | Mean burned stashes | Canonical cash p50 | Mean cash | Changed raw rows |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 16.65 | 5.60 | 0.400 | $51,066 | $54,428.83 | â€” |
| Escort only | 16.65 | 5.60 | 0.400 | $51,066 | $54,428.83 | 0/40 |
| Stakeout only | 18.00 | 5.85 | 0.825 | $54,693 | $59,936.05 | 40/40 |
| Both | 18.00 | 5.85 | 0.825 | $54,693 | $59,936.05 | 40/40 |

Both corrections produce exactly the stakeout-only raw rows in all forty seeds. The measured change in this scenario therefore comes from clearing stale surveillance.

Aggregate cash improvements conceal variation: twenty seeds gain cash and twenty lose cash. The paired mean gain is $5,507.23, but paired p50 is **âˆ’$359** (p10 âˆ’$11,695; p90 +$26,129). Burned stashes increase in fourteen seeds, decrease in four and remain unchanged in twenty-two. Arrests increase in nineteen, decrease in twenty and remain unchanged in one. These are descriptive outcomes, not a statistical or human balance acceptance claim. Quantiles use the canonical floor-index rule, not interpolated medians.

## Important coverage limit and disposition

The canonical stand-in explicitly runs no cargo trucks (`live_balance.gd`'s regular cash-pickup comment and implementation); it substitutes flight income and collections. It cannot establish the economic or tactical effect of retaining an **active truck escort**. The unchanged escort rows are not proof of active-escort balance. Existing reproduced escort/retreat regressions remain useful functional evidence.

Keep #244 draft. Next acceptance needs a real transport scenario with live cargo, committed escorts, emergency retreat, completion and measurable deployment/guard consequences, followed by calibrated balance review. Its #240 dependency must also be resolved before integration. Physical and human playtesting remain pending. Keep issue #98 open; do not conceal the changed surveillance consequences with compensating payouts or speeds.

## Reproduction

Use an isolated worktree and fetch the recorded base. The committed helper verifies Godot version, normalised ground/canonical source hashes and unchanged game/assets against that base before running. It does not apply a patch or alter gameplay files.

```sh
# On this evidence branch, whose game source matches the recorded base:
godot --headless --script res://tools/faction_ai_isolation.gd -- baseline --check
godot --headless --script res://tools/faction_ai_isolation.gd -- baseline /absolute/path/baseline.json
# Apply exactly one recorded patch in a separate worktree, then choose its label:
git apply --unidiff-zero sim-results/faction-ai-isolation-2026-10-09/escort-only.patch
godot --headless --script res://tools/faction_ai_isolation.gd -- escort-only /absolute/path/escort-only.json
```

The stakeout-only and combined patches/labels work likewise. A mismatched source/label is rejected before simulation. The baseline fingerprint check passes and a falsely labelled escort run is rejected with exit 2. Invalid output paths fail before the forty-seed run. Raw-row reconstruction and all four forty-row/seed-order checks pass. This tool is excluded from exported builds with the existing tools filter.
