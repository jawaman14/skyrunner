# Local LLM first-pass worker

A small worker for the jobs that do not need Claude or Codex, on the LM Studio server on this network, through LM Studio's native API
(`/api/v1/models`, `/api/v1/chat`). The address is not committed: set `SKYRUNNER_LOCAL_LLM` (for example `http://169.254.83.107:6456`).
`SKYRUNNER_LOCAL_LOG` appends one JSON line per call (model, seconds, token stats) so the saving can be measured.

**Careful with the server.** The owner's large model is on it, and a model that does not fit freezes the machine. So the worker only uses a
model that is already loaded (it reads `/api/v1/models` first, read-only), never calls a load or unload endpoint, and refuses a model with no
loaded instance (`SKYRUNNER_LOCAL_MODEL` may name a loaded one; with exactly one loaded it uses that). The owner loads the model himself.
It makes one request at a time across all agents (an OS lock), pauses after each call, caps the calls a job makes and keeps token budgets
modest. Reasoning is off by default (`--think` on `first-draft` turns it on): on Qwen3.6 27B, off took 1 s for a 20-token reply and on spent
1,531 tokens thinking about a three-line function.

The model in use is `prism-ml/bonsai-27b` (1-bit, 4.7 GB), chosen by the owner. On the same digest of a finished test-suite log it took 15 s
(19 tokens/s) against 31 s (8 tokens/s) for `qwen/qwen3.6-27b`, and both were accurate.

| Command | What it does | What it never does |
|---|---|---|
| `models` | lists the models on the server | |
| `digest --file F` or `--pr N` | at most 8 lines on a log or PR diff, exact error text quoted | decide whether a failure matters |
| `draft-replies --pr N --out F` | per unanswered review thread: what is asked, what to check, and an empty `[TODO]` reply | decide whether the reviewer is right, promise a change, post, resolve or send anything |
| `triage` | per open PR: tier (from the file paths, no model), who wrote it, a one-line summary | label, close or re-order PRs |
| `first-draft --task F --paths a,b --slug s` | the model rewrites the named files (at most 3, at most 40 KB each); the result goes on a new `local/<slug>` branch and a DRAFT PR marked as an unreviewed first pass | touch a protected path, merge, review, mark ready, push to an existing branch |

Protected from a local draft: `.github/`, `project.godot`, `tests/fixtures/`, `HANDOFF.md`, `AGENTS.md`, `CLAUDE.md`, the score ledger,
`scripts/sim/switches.gd`, `tools/mcp/`, and this tool. A first draft is always at least Tier 1 (docs/PIPELINE.md), so it needs the other
agent's exact-head review after the author has finished it. A model this size is wrong often enough that nothing here is trusted
until a person or Claude or Codex has read it.

Tests (no server needed): `python tools/local_llm/test_worker.py` and `python tools/local_llm/test_alerts.py`.

**Phase 1 results (11 October, bonsai-27b, real `POST /api/v1/chat` calls).** `triage`: 6 PRs in 14 s; the tiers are right (they come from the file
paths, not the model) but the one-line summaries are loose, and one is wrong ("Sync shared baton to contributors" for a PR that makes the
baton of the base branch win). `draft-replies` as first written (a drafted reply): checked against the three replies actually sent to
real bot findings on #331, one was a restatement, one reasonable but promised work, and one was dangerous (it said "no changes are needed"
to a valid blocking finding). So the job now writes only a neutral summary (ask, check, empty reply) and never a stance.
`digest`: accurate on the one log tried. `first-draft`: not tried.

**Input size.** What it sends follows the loaded model's context window (2 characters per token of it), capped at 400,000 characters, because a long
prompt is slow to read: `SKYRUNNER_LOCAL_MAX_CHARS` overrides it, and an unknown context falls back to 24,000. With bonsai at 262,144 tokens a
whole 35 KB PR diff (about 11,000 tokens) went in uncut and was digested in 24 s, 15 s of it reading the prompt.

## Alert feed

`alerts.py once|watch --for codex|claude [--with-llm]` writes a short markdown digest of what that agent must act on (a review needed, CI failed on its
PR, review threads waiting, a conflict to sync, a merge), decided by code from GitHub state and sent once per change. `--with-llm` lets the local
model add a neutral line to thread alerts; a model failure never loses an alert. `tools/collab/wake_codex.py --alerts-file` wakes the agent when the
file changes. To keep this feed on its own model instance (for example a second bonsai loaded for Codex), set `SKYRUNNER_LOCAL_MODEL` to that
instance id, as listed by `worker.py models`.
