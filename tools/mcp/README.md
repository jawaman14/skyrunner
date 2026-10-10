# Skyrunner MCP server

An [MCP](https://modelcontextprotocol.io) server that gives an agent (Claude Code, Claude Desktop, any MCP client)
first-class tools for this project. It drives the pinned Godot build headlessly and talks to this repository on
GitHub, so the edit → test → PR → CI loop doesn't depend on hand-typed shell commands.

One file, `skyrunner_mcp.py`, with its dependencies declared inline (PEP 723). `uv` installs them on first run.
The folder has a `.gdignore`, so Godot never imports it, and `tools/*` is already excluded from exported builds.

## Setup

1. Install [uv](https://docs.astral.sh/uv/) (it brings the right Python).
2. GitHub access: set `GH_TOKEN` (or `GITHUB_TOKEN` / `SKYRUNNER_GITHUB_TOKEN`), or log in with `gh auth login`.
   A fine-grained token needs read/write **Contents**, **Pull requests**, **Issues** and read **Actions** on this
   repository. Without a token, the Godot tools still work and the GitHub tools say what's missing.
3. Godot: on Linux the server fetches the pinned 4.7.2 through `tools/get_godot.sh`. Elsewhere, set
   `SKYRUNNER_GODOT` (or `GODOT`) to a Godot 4.7.2 executable.

**Claude Code** picks the server up from the repository's `.mcp.json` (approve it once when asked). Check it with
`/mcp`. To add it by hand: `claude mcp add skyrunner -- uv run --quiet --script tools/mcp/skyrunner_mcp.py`.

**Claude Desktop / other clients:** run `uv run --quiet --script /absolute/path/to/tools/mcp/skyrunner_mcp.py`
over stdio. The server finds the repository from its own location, so the working directory doesn't matter.

Optional environment: `SKYRUNNER_GITHUB_REPO=owner/name` (default: parsed from `origin`), `SKYRUNNER_GITHUB_API`
(GitHub Enterprise REST base URL).

## Tools

**Game** (local; Godot runs are background jobs: a call waits `wait_seconds`, then returns the result or a job id)

| tool | what it does |
|---|---|
| `skyrunner_run_tests` | the GDScript suite, filtered by file/test name, lane or shard; parsed pass/fail, failing files, SCRIPT ERROR lines |
| `skyrunner_list_tests` | test files and methods (static scan), to choose a filter |
| `skyrunner_smoke` | CI's headless smoke run (`--smoke N`, expects `SMOKE OK`) |
| `skyrunner_screenshot` | renders the game under Xvfb/llvmpipe and returns the PNG (Linux, needs `xvfb-run`) |
| `skyrunner_balance` | `scripts/balance/cli.gd` feasibility / tactical / strategic / report |
| `skyrunner_run_tool` | any `tools/*.gd` script (golden regeneration, terrain bake, route audits...) |
| `skyrunner_project_status` | check or regenerate the generated block in `docs/PROJECT_STATUS.md` |
| `skyrunner_import` | `--import`: class cache refresh and a parse check of every script |
| `skyrunner_commands` | the live command registry: handler file and function, permitted roles, preview support |
| `skyrunner_switches` | registered parity / opt-in switches |
| `skyrunner_job_status` / `skyrunner_job_cancel` | follow or stop a background job |

**GitHub** (this repository only)

| tool | what it does |
|---|---|
| `github_pr_triage` | every open PR: base (stacked or not), ahead/behind, clean or CONFLICT into its base and into `main`, docs-only flag |
| `github_ci_status` | Actions runs for a PR / branch / sha and per-job results with job ids |
| `github_ci_logs` | a job log reduced to FAIL / SCRIPT ERROR / `##[error]` lines and the tail (known Godot shutdown diagnostics dropped) |
| `github_pr_view` | description, mergeability, files, reviews, inline and conversation comments |
| `github_pr_create` | opens a PR (draft by default); refuses if the branch isn't pushed or differs from the remote |
| `github_pr_update` | title/body, or mark ready for review (uses the REST route cloud sessions allow; GraphQL elsewhere) |
| `github_pr_merge` | merges only if the PR is open, ready, conflict-free, still at the head SHA you checked, and every CI job on it succeeded; refuses and says why otherwise |
| `github_pr_comment` | comment on a PR/issue, or reply in an inline review thread |
| `github_pr_close` | close with a required reason; optionally delete the branch |
| `github_issue_list` / `github_issue_view` / `github_issue_write` | browse, create, comment on and close issues |
| `github_branch_cleanup` | lists (dry run) or deletes finished remote branches: contained in `main` or PR merged; never a branch that is the head or base of an open PR |

## Design notes

- **One Godot job at a time.** Concurrent runs share `.godot/`'s import cache, which corrupts it. A second run is
  refused with the running job's id. Jobs live as long as the server process, and logs go to `.build/mcp/`
  (gitignored).
- **`skyrunner_run_tests` streams.** It runs `tests/run_tests.gd` directly instead of `tools/test.sh` (which
  buffers until the end), so a 15-minute run shows per-file progress. It skips `test.sh`'s project-status check;
  run `skyrunner_project_status` before a PR.
- **Introspection asks Godot**, via `tools/mcp_introspect.gd`, instead of parsing GDScript: permissions are built
  from concatenated constants that a regex would misread. The result is cached per commit and dirty `scripts/` state.
- **Arguments passed to Godot are allowlisted** (`[A-Za-z0-9_.,:=/+-]`), and processes are spawned without a shell
  except for the fixed test pipeline, which quotes its inputs.
- **Write tools are annotated** (`destructiveHint` etc.), so clients can ask before running them. Branch deletion
  defaults to a dry run, and branches of PRs closed *without* merging are only included when asked.

## Testing it

`tools/mcp/skyrunner_mcp.py` is plain Python. A quick check that it starts and lists its tools:

```bash
npx @modelcontextprotocol/inspector uv run --quiet --script tools/mcp/skyrunner_mcp.py
```
