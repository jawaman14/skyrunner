#!/usr/bin/env python3
"""A cheap first-pass worker on the local LM Studio server, for the jobs that do not need Claude or Codex.

    python tools/local_llm/worker.py models
    python tools/local_llm/worker.py digest --file build.log            # or --pr 322 for a PR's diff
    python tools/local_llm/worker.py draft-replies --pr 330 --out drafts.md
    python tools/local_llm/worker.py triage                             # open PRs: tier, area, owner, one line
    python tools/local_llm/worker.py first-draft --task task.md --paths tools/x.py,tests/test_x.py --slug x

The server address comes from SKYRUNNER_LOCAL_LLM (for example http://169.254.83.107:6456); there is no default. It talks to LM Studio's
native API (`/api/v1/models`, `/api/v1/chat`).

BE CAREFUL WITH THE SERVER (the owner's large model is on it, and a model that does not fit freezes the machine):
  * It only ever uses a model that is ALREADY LOADED. Before each run it reads `/api/v1/models` (read-only) and refuses a model with no
    loaded instance, because asking the server for an unloaded model makes it load one, which is how an earlier probe broke the engine.
    It never calls a load or unload endpoint. SKYRUNNER_LOCAL_MODEL may name a loaded model; otherwise it uses the one loaded LLM and
    refuses if there are none or several.
  * One request at a time across all agents (an OS lock), a pause after each call, modest token budgets and timeouts, and a cap on how
    many calls a job makes, so it never competes hard with the owner's own use of the model.
  * Reasoning is OFF by default (`"reasoning": "off"` on the chat call): the model spent 1,531 reasoning tokens on a three-line function
    when it was on, and about 0 when off (a 20-token reply took 1 s). Pass --think to first-draft to turn it on for a hard change.

Rules it keeps, because a model is wrong often enough to matter:
  * It never merges, closes, reviews, approves, marks a PR ready, or posts a thread reply. `draft-replies` writes drafts to a file for the
    author to read and send; `first-draft` opens a DRAFT pull request on a new `local/<slug>` branch, labelled as an unreviewed first pass.
  * Everything it produces is a draft that Claude and Codex finish and review. A first draft is always at least Tier 1 (see docs/PIPELINE.md).
  * `first-draft` touches only the files you name (at most 3, each at most 40 KB), never the protected paths below, applies nothing it cannot
    parse, and discards the branch if the optional test command fails.
  * Each call is logged (model, tokens, seconds) to the file in SKYRUNNER_LOCAL_LOG (default none) so the saving can be measured.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

MAX_CALLS = 30
DEFAULT_INPUT_CHARS = 24_000
MAX_INPUT_CHARS = 400_000
MAX_REPAIRS = 1
PAUSE_SECONDS = 1.0
PROTECTED = (".github/", "project.godot", "tests/fixtures/", "HANDOFF.md", "AGENTS.md", "CLAUDE.md", "docs/COLLABORATION_SCORE.md",
             "scripts/sim/switches.gd", "tools/mcp/", "tools/local_llm/")
MAX_FILES = 3
MAX_FILE_BYTES = 40_000
FENCE = re.compile(r"^```[a-zA-Z0-9_+-]*[ \t]*\n(.*?)^```[ \t]*$", re.S | re.M)
FILE_HEAD = re.compile(r"^(?:#+\s*)?(?:FILE|File|file)\s*:\s*`?([^\s`]+)`?\s*$", re.M)


class LocalLLMError(Exception):
    pass


def endpoint():
    url = os.environ.get("SKYRUNNER_LOCAL_LLM", "").rstrip("/")
    if not url:
        raise LocalLLMError("set SKYRUNNER_LOCAL_LLM to the LM Studio address, for example http://169.254.83.107:6456")
    return url


def _get_json(path, opener, timeout=20):
    try:
        with opener(urllib.request.Request(endpoint() + path), timeout=timeout) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise LocalLLMError("the server refused %s: %s" % (path, e.code))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
        raise LocalLLMError("could not reach the local LLM: %s" % e)


def loaded_models(opener=urllib.request.urlopen):
    """Keys of the language models that are loaded right now. A read-only look; it loads nothing."""
    data = _get_json("/api/v1/models", opener)
    return [m["key"] for m in data.get("models", []) if m.get("type") == "llm" and m.get("loaded_instances")]


def input_budget(opener=urllib.request.urlopen):
    """How many characters of a log or diff to send. It follows the loaded model's context window (2 characters per token of it, leaving
    room for the answer; about 4 characters is a token, so this fills about half), capped at MAX_INPUT_CHARS because a long prompt is
    slow to read. SKYRUNNER_LOCAL_MAX_CHARS overrides it. Unknown context: the small default. A read-only look; it loads nothing."""
    env = os.environ.get("SKYRUNNER_LOCAL_MAX_CHARS", "")
    if env.isdigit() and int(env) > 0:
        return min(int(env), MAX_INPUT_CHARS)
    try:
        data = _get_json("/api/v1/models", opener)
        sizes = [i.get("config", {}).get("context_length", 0) for m in data.get("models", []) if m.get("type") == "llm" for i in m.get("loaded_instances", [])]
    except LocalLLMError:
        return DEFAULT_INPUT_CHARS
    sizes = [x for x in sizes if isinstance(x, int) and x > 0]
    return min(min(sizes) * 2, MAX_INPUT_CHARS) if sizes else DEFAULT_INPUT_CHARS


def pick_model(loaded, requested=""):
    """The loaded model to use. Never one that is not loaded: asking for it would make the server load it."""
    requested = requested or os.environ.get("SKYRUNNER_LOCAL_MODEL", "")
    if requested:
        if requested not in loaded:
            raise LocalLLMError("%s is not loaded (loaded: %s). This tool never loads a model: load it in LM Studio first." % (requested, ", ".join(loaded) or "none"))
        return requested
    if len(loaded) == 1:
        return loaded[0]
    if not loaded:
        raise LocalLLMError("no language model is loaded in LM Studio. This tool never loads one: load a model first.")
    raise LocalLLMError("several models are loaded (%s): set SKYRUNNER_LOCAL_MODEL" % ", ".join(loaded))


def _lock_file(fh):
    """An exclusive OS lock, so only one agent talks to the server at a time; released if the holder dies."""
    try:
        if os.name == "nt":
            import msvcrt
            fh.seek(0)
            msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


def _wait_turn(seconds=600):
    path = os.environ.get("SKYRUNNER_LOCAL_LOCK") or os.path.join(os.environ.get("TEMP") or "/tmp", "skyrunner_local_llm.lock")
    fh = open(path, "a+", encoding="utf-8")
    deadline = time.time() + seconds
    while not _lock_file(fh):
        if time.time() > deadline:
            fh.close()
            raise LocalLLMError("another job has been using the local LLM for over %d s; try later" % seconds)
        time.sleep(2.0)
    return fh


def chat(prompt, system="", model=None, max_tokens=800, think=False, temperature=0.2, opener=urllib.request.urlopen, timeout=600, wait=True):
    """One completion from an already-loaded model. Raises LocalLLMError on any failure; never returns an empty answer."""
    lock = _wait_turn() if wait else None
    try:
        model = pick_model(loaded_models(opener), model or "")
        body = {"model": model, "input": prompt, "reasoning": "on" if think else "off", "max_output_tokens": max_tokens,
                "temperature": temperature, "store": False}
        if system:
            body["system_prompt"] = system
        req = urllib.request.Request(endpoint() + "/api/v1/chat", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
        start = time.time()
        try:
            with opener(req, timeout=timeout) as r:
                data = json.load(r)
        except urllib.error.HTTPError as e:
            raise LocalLLMError("the server refused: %s %s" % (e.code, e.read()[:200].decode("utf-8", "replace")))
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            raise LocalLLMError("could not reach the local LLM: %s" % e)
        text = "".join(str(o.get("content", "")) for o in data.get("output", []) if o.get("type") == "message").strip()
        stats = data.get("stats") or {}
        if not text:
            if think and stats.get("reasoning_output_tokens", 0) >= max_tokens * 0.9:
                raise LocalLLMError("%s spent all %d tokens thinking and answered nothing: raise max_tokens" % (model, max_tokens))
            raise LocalLLMError("the model returned nothing")
        log = os.environ.get("SKYRUNNER_LOCAL_LOG", "")
        if log:
            with open(log, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"model": model, "seconds": round(time.time() - start, 2), "stats": stats}) + "\n")
        return text
    finally:
        if lock is not None:
            time.sleep(float(os.environ.get("SKYRUNNER_LOCAL_PAUSE", PAUSE_SECONDS)))
            lock.close()


def clip(text, limit):
    """Head and tail of long text, so a log keeps its start and its failure."""
    if len(text) <= limit:
        return text
    half = limit // 2
    return text[:half] + "\n...[%d characters cut]...\n" % (len(text) - limit) + text[-half:]


# ---------------------------------------------------------------------------------------------------------------- pure parts
def tier_of(paths):
    """The review tier of a change from its paths alone (docs/PIPELINE.md): no model involved, so it cannot be argued with."""
    risky_t2 = ("scripts/sim/", "scripts/net/", "data/jsbsim/", "tests/fixtures/", "scripts/balance/")
    risky_t1 = ("scripts/", ".github/", "tools/collab/", "tools/mcp/", "assets/", "project.godot")
    if any(p.startswith(risky_t2) for p in paths):
        return 2
    if any(p.startswith(risky_t1) for p in paths):
        return 1
    return 0


def parse_files(answer, allowed):
    """{path: content} from the model's answer. Each file is `FILE: <path>` then a fenced block. Only paths in `allowed` count."""
    out = {}
    heads = list(FILE_HEAD.finditer(answer))
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(answer)
        block = FENCE.search(answer[h.end():end])
        path = h.group(1).replace("\\", "/")
        if block and path in allowed:
            out[path] = block.group(1)
    return out


def check_paths(paths):
    """None if first-draft may touch these files, else why not."""
    if not paths or len(paths) > MAX_FILES:
        return "name between 1 and %d files with --paths" % MAX_FILES
    for p in paths:
        norm = p.replace("\\", "/")
        if norm.startswith("/") or ".." in norm.split("/") or ":" in norm:
            return "%s is not a path inside the repository" % p
        if norm.startswith(PROTECTED) or norm in PROTECTED:
            return "%s is protected: a local draft may not touch it" % p
    return None


# --------------------------------------------------------------------------------------------------------------------- jobs
def gh(args, run=subprocess.run):
    out = run(["gh"] + args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
    if out.returncode != 0:
        raise LocalLLMError("gh %s failed: %s" % (" ".join(args[:2]), " ".join((out.stderr or "").split())[:200]))
    return out.stdout


def job_digest(args, ask=chat):
    if args.file:
        text = open(args.file, encoding="utf-8", errors="replace").read()
        what = "log"
    else:
        text = gh(["pr", "diff", str(args.pr)])
        what = "pull request diff"
    return ask("Summarise this %s for a developer in at most 8 short lines. Say what failed or changed and where (file and line if shown). "
               "Quote exact error text. Do not guess.\n\n%s" % (what, clip(text, input_budget())), system="You are terse and exact.", max_tokens=400)


def job_draft_replies(args, ask=chat):
    comments = json.loads(gh(["api", "repos/{owner}/{repo}/pulls/%d/comments" % args.pr, "--paginate", "--jq", "[.[]|{id,path,line,in_reply_to_id,body}]"]) or "[]")
    replied = {c["in_reply_to_id"] for c in comments if c.get("in_reply_to_id")}
    open_ = [c for c in comments if not c.get("in_reply_to_id") and c["id"] not in replied]
    parts = ["# Review threads to answer on PR #%d (summaries only, NOT replies: the author decides and writes the answer)\n" % args.pr]
    for c in open_[:MAX_CALLS]:
        draft = ask("A reviewer left this comment on %s line %s. Do NOT say whether it is right or wrong and do NOT promise any change. Write exactly three lines.\n"
                    "ASK: what the reviewer is asking for, in one sentence.\n"
                    "CHECK: what the author must verify in the code before answering, in one sentence.\n"
                    "REPLY: [TODO: what was actually done]\n\n%s" % (c.get("path"), c.get("line"), clip(c["body"], 3000)),
                    system="You summarise review comments neutrally and never decide for the author.", max_tokens=200)
        parts.append("## comment %s  %s:%s\n%s\n\nSUMMARY (a neutral reading, not a decision):\n%s\n" % (c["id"], c.get("path"), c.get("line"), " ".join(c["body"].split())[:300], draft))
    if not open_:
        parts.append("No unanswered review threads.\n")
    return "\n".join(parts)


def job_triage(args, ask=chat):
    prs = json.loads(gh(["pr", "list", "--json", "number,title,headRefName,files,isDraft", "--limit", str(args.limit)]))
    lines = []
    for p in prs[:MAX_CALLS]:
        paths = [f["path"] for f in p.get("files", [])]
        tier = tier_of(paths)
        owner = "claude" if p["headRefName"].startswith("claude/") else ("codex" if p["headRefName"].startswith("codex/") else "?")
        one = ask("One line (under 18 words) saying what this pull request does, from its title and file list only.\nTitle: %s\nFiles: %s" % (p["title"], ", ".join(paths[:12])),
                  max_tokens=60, )
        lines.append("#%d tier %d, authored by %s%s: %s" % (p["number"], tier, owner, " (draft)" if p["isDraft"] else "", one.splitlines()[0]))
    return "\n".join(lines)


def job_first_draft(args, ask=chat, run=subprocess.run):
    paths = [p.strip() for p in args.paths.split(",") if p.strip()]
    why = check_paths(paths)
    if why:
        raise LocalLLMError(why)
    root = os.path.abspath(args.root)
    task = open(args.task, encoding="utf-8").read()
    current = {}
    for p in paths:
        full = os.path.join(root, p)
        if os.path.exists(full):
            data = open(full, encoding="utf-8").read()
            if len(data.encode()) > MAX_FILE_BYTES:
                raise LocalLLMError("%s is larger than %d bytes: too big for a local first draft" % (p, MAX_FILE_BYTES))
            current[p] = data
    shown = "\n\n".join("FILE: %s\n```\n%s```" % (p, current[p]) for p in current) or "(all files are new)"
    reference = ""
    for ctx in [c.strip() for c in (getattr(args, "context", "") or "").split(",") if c.strip()][:3]:
        full = os.path.join(root, ctx)
        norm = ctx.replace("\\", "/")
        if norm.startswith("/") or ".." in norm.split("/") or ":" in norm or not os.path.isfile(full):
            raise LocalLLMError("%s is not a readable file inside the repository" % ctx)
        data = open(full, encoding="utf-8", errors="replace").read()
        reference += "\n\nREFERENCE (read only, do not change) %s:\n```\n%s\n```" % (ctx, clip(data, 20000))
    answer = ask("Task:\n%s\n\nYou may change ONLY these files: %s.\nCurrent contents:\n%s%s\n\nReturn the COMPLETE new contents of every file you change, each as a line "
                 "`FILE: <path>` followed by one fenced code block. No other prose. Follow the conventions visible in the existing code. "
                 "Do not invent APIs that are not shown." % (task, ", ".join(paths), shown, reference), system="You write careful, minimal code changes.", max_tokens=14000 if args.think else 6000, think=args.think, timeout=3000)
    files = parse_files(answer, set(paths))
    if not files:
        raise LocalLLMError("the model's answer had no usable FILE blocks; nothing was written")
    if args.dry_run:
        return "dry run: would write %s on branch local/%s" % (", ".join(sorted(files)), args.slug)
    branch = "local/" + re.sub(r"[^a-z0-9-]+", "-", args.slug.lower()).strip("-")
    work = os.path.join(os.path.dirname(root), ".local-llm-" + branch.split("/")[1])
    def git(*a):
        o = run(["git", "-C", work] + list(a), capture_output=True, text=True, encoding="utf-8", errors="replace")
        if o.returncode != 0:
            raise LocalLLMError("git %s failed: %s" % (a[0], (o.stderr or o.stdout).strip()[:200]))
        return o.stdout
    r = run(["git", "-C", root, "worktree", "add", "-q", "-b", branch, work, "origin/main"], capture_output=True, text=True)
    if r.returncode != 0:
        raise LocalLLMError("could not create the branch %s (does it exist?): %s" % (branch, (r.stderr or "").strip()[:200]))
    try:
        for attempt in range(MAX_REPAIRS + 1):
            for p, content in files.items():
                os.makedirs(os.path.dirname(os.path.join(work, p)) or work, exist_ok=True)
                open(os.path.join(work, p), "w", encoding="utf-8", newline="\n").write(content)
            if not args.test:
                break
            t = run(args.test, cwd=work, shell=False, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if t.returncode == 0:
                break
            failure = clip((t.stdout or "") + (t.stderr or ""), 1800)
            if attempt >= MAX_REPAIRS:
                raise LocalLLMError("the test command still failed after %d repair round(s), branch discarded:\n%s" % (MAX_REPAIRS, failure))
            # one bounded repair round: the model sees its own files and the failing output, nothing else changes
            current_now = "\n\n".join("FILE: %s\n```\n%s```" % (p, c) for p, c in files.items())
            fixed = ask("Your previous change failed its test. Fix it.\n\nTask:\n%s\n\nYour files:\n%s\n\nFailing output:\n%s\n\nReturn the COMPLETE corrected contents "
                        "of the files as `FILE: <path>` lines each followed by one fenced code block. No other prose.%s" % (task, current_now, failure, reference),
                        system="You write careful, minimal code changes.", max_tokens=14000 if args.think else 6000, think=args.think, timeout=3000)
            files = parse_files(fixed, set(paths)) or files
        git("add", *files)
        git("-c", "user.name=local-llm", "-c", "user.email=noreply@localhost", "commit", "-q", "-m",
            "First draft by a local model (%s): %s\n\nUnreviewed. Claude and Codex finish and review it.\n\nCo-Authored-By: %s (local) <noreply@localhost>" %
            (os.environ.get("SKYRUNNER_LOCAL_MODEL", "local model"), args.slug, os.environ.get("SKYRUNNER_LOCAL_MODEL", "local model")))
        git("push", "-q", "-u", "origin", branch)
    except LocalLLMError:
        run(["git", "-C", root, "worktree", "remove", "--force", work], capture_output=True)
        run(["git", "-C", root, "branch", "-D", branch], capture_output=True)
        raise
    body = ("UNREVIEWED FIRST PASS by a local model (%s). Claude and Codex finish and review it before it can merge; treat every line as suspect.\n"
            "Task: %s\nFiles: %s\nReview tier: at least %d (docs/PIPELINE.md)." % (os.environ.get("SKYRUNNER_LOCAL_MODEL", "local model"), args.slug,
                                                                                    ", ".join(sorted(files)), max(1, tier_of(list(files)))))
    url = gh(["pr", "create", "--draft", "--title", "First pass (local model): " + args.slug, "--head", branch, "--body", body], run).strip()
    return "opened draft " + url


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("models")
    d = sub.add_parser("digest")
    g = d.add_mutually_exclusive_group(required=True)
    g.add_argument("--file")
    g.add_argument("--pr", type=int)
    r = sub.add_parser("draft-replies")
    r.add_argument("--pr", type=int, required=True)
    r.add_argument("--out", default="")
    t = sub.add_parser("triage")
    t.add_argument("--limit", type=int, default=30)
    f = sub.add_parser("first-draft")
    f.add_argument("--task", required=True)
    f.add_argument("--paths", required=True)
    f.add_argument("--slug", required=True)
    f.add_argument("--root", default=".")
    f.add_argument("--test", nargs="*", default=None, help="a command (argv list) run in the new branch; failure discards it")
    f.add_argument("--context", default="", help="up to 3 read-only reference files, comma separated (shown to the model, never changed)")
    f.add_argument("--think", action="store_true", help="turn reasoning on (slow: use for a hard change)")
    f.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    try:
        if args.cmd == "models":
            print("loaded: " + (", ".join(loaded_models()) or "none (this tool never loads a model)"))
            return 0
        text = {"digest": job_digest, "draft-replies": job_draft_replies, "triage": job_triage, "first-draft": job_first_draft}[args.cmd](args)
        if args.cmd == "draft-replies" and args.out:
            open(args.out, "w", encoding="utf-8").write(text)
            print("wrote " + args.out)
        else:
            print(text)
        return 0
    except LocalLLMError as e:
        print("local-llm: " + str(e), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
