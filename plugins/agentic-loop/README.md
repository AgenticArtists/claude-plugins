# agentic-loop

A self-perpetuating plan → build → review → ship loop for Claude Code.

One prompt, `/loop`, drives planner → worker → reviewer → merge → deploy, and
then writes the next loop's brief back to the same path — so the next loop
starts with the identical prompt. Forever.

```
new session → /loop → plan, build, review, merge, deploy,
              update backlog, write next brief → "start the next one with /loop"
            → new session → /loop → ...
```

## Install

```
/plugin marketplace add agenticartists/bestokc.com
/plugin install agentic-loop@agenticartists
```

> **Note on the marketplace's home.** This plugin is org-wide tooling that
> happens to be hosted in a project repo, because that was the repo already
> reachable when it was written. Intended home is `agenticartists/.github`.
> Moving it is a copy of `.claude-plugin/` and `plugins/` plus a one-line change
> for consumers (`/plugin marketplace add agenticartists/.github`) — nothing in
> the plugin itself depends on where it lives.

Then, once per repository:

```
/loop-init
```

That inspects the repo — package scripts, Makefile, CI config, default branch —
and writes `.claude/loop.config.json`, seeds a backlog, and drafts the first
brief. Review what it wrote; it's making judgement calls about how your project
verifies and ships.

After that, every loop is just `/loop`.

## Why this exists

Three failures kill autonomous loops, and each piece here answers one:

**Approved work never ships.** Hosted coding sessions are often assigned a
feature branch and told not to push elsewhere, which contradicts any "push to
main" instruction the worker has. The worker obeying its harness is correct —
which is exactly why approved work ends up stranded on a branch with nobody
merging it. `/loop` makes merging the orchestrator's explicit job, and a `Stop`
hook refuses to let the session end until it's done.

**Institutional knowledge evaporates.** What got deferred, what couldn't be
verified, what the reviewer waved through, where the worker deviated — none of
it survives in `git log`. The finishing session writes it down while it still
knows, into a brief the next cold session can actually use.

**Themes drift by momentum.** A session that just spent hours on one area finds
more of that area compelling. A cross-loop `backlog.md` plus a rule that you
must name the alternatives you rejected — including "keep going on the current
theme" — forces an argument instead of a default.

## What's in the box

| Piece | Role |
|---|---|
| `/loop` | Runs one full loop end to end |
| `/loop-init` | One-time per-repo setup |
| `loop-planner` | Read-only; produces a numbered plan (opus) |
| `loop-worker` | Implements it, step by step, committing as it goes |
| `loop-reviewer` | Independent audit; runs the gate, checks danger zones |
| `Stop` hook | Blocks session end while `.claude/.loop-active` exists |
| Templates | Brief scaffold, backlog scaffold, brief-writing meta-prompt |

The agents are generic. **If your repo defines its own `planner`, `worker`, or
`reviewer` agents, `/loop` uses those instead** — a repo that has tuned its own
knows things this plugin doesn't.

## Configuration

`.claude/loop.config.json`, written by `/loop-init`:

```json
{
  "mainBranch": "main",
  "gate": ["npm run lint", "npm run build", "npm test"],
  "deploy": { "mode": "push", "note": "Vercel auto-deploys from main" },
  "paths": {
    "brief": ".claude/prompts/next-loop.md",
    "backlog": ".claude/prompts/backlog.md",
    "archive": ".claude/prompts/archive"
  }
}
```

`gate` is ordered, and the order is load-bearing: a suite that reads build
output becomes a silent no-op if it runs before the build. `deploy.mode` is
`push` (merging deploys), `command` (run `deploy.command`), or `none`.

## The Stop hook

`/loop` writes `.claude/.loop-active` at kickoff and deletes it only after the
work has landed and the next brief is written. While it exists, the hook won't
let the session end, and tells the model exactly what's outstanding.

**No marker, no effect.** Sessions that never ran `/loop` are untouched. The
hook degrades safely: without `jq` it falls back to exit code 2, and without a
config it uses generic wording. It should never be the reason a session can't
end.

If a session crashes mid-loop the marker survives, and the next session in that
directory will be told to finish the outstanding loop. That's intended — but
it's why you might see it unexpectedly.

## Read the report

The system is explicitly allowed to conclude that the next move is a human's —
provisioning credentials, granting access, a product decision. If that comes
back and you just type `/loop` again, it'll pick the next-best agent work and
the real blocker stays put.
