# Local LLM first-pass worker

A small worker for the jobs that do not need Claude or Codex, on the LM Studio server on this network (OpenAI-compatible API). The address
is not committed: set `SKYRUNNER_LOCAL_LLM` (for example `http://169.254.83.107:6456`). `SKYRUNNER_LOCAL_MODEL` picks the model
(default `qwen2.5-7b-instruct-1m`; the 27B model needs about 45 GB and does not load on that machine; the 3B and 1B are for one-line jobs).
`SKYRUNNER_LOCAL_LOG` appends one JSON line per call (model, seconds, tokens) so the saving can be measured.

| Command | What it does | What it never does |
|---|---|---|
| `models` | lists the models on the server | |
| `digest --file F` or `--pr N` | at most 8 lines on a log or PR diff, exact error text quoted | decide whether a failure matters |
| `draft-replies --pr N --out F` | a draft reply per unanswered review thread, `[TODO]` where the facts are not in the comment | post, resolve or send anything |
| `triage` | per open PR: tier (from the file paths, no model), who wrote it, a one-line summary | label, close or re-order PRs |
| `first-draft --task F --paths a,b --slug s` | the model rewrites the named files (at most 3, at most 40 KB each); the result goes on a new `local/<slug>` branch and a DRAFT PR marked as an unreviewed first pass | touch a protected path, merge, review, mark ready, push to an existing branch |

Protected from a local draft: `.github/`, `project.godot`, `tests/fixtures/`, `HANDOFF.md`, `AGENTS.md`, `CLAUDE.md`, the score ledger,
`scripts/sim/switches.gd`, `tools/mcp/`, and this tool. A first draft is always at least Tier 1 (docs/PIPELINE.md), so it needs the other
agent's exact-head review after the author has finished it. A model this size is wrong often enough that nothing here is trusted
until a person or Claude or Codex has read it.

Tests (no server needed): `python tools/local_llm/test_worker.py`.
