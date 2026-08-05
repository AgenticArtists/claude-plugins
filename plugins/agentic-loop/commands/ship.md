---
description: Run the full agentic loop (plan → build → review → merge → deploy → write next brief)
argument-hint: "(no argument needed)"
---

Run one complete agentic loop for this repository.

## Setup

Read `.claude/loop.config.json`. **If it doesn't exist, run `/loop-init` first**
and stop — this repo isn't set up yet, and guessing its branch, gate commands,
and deploy mechanism is exactly the kind of assumption that ships broken work.

The config gives you: `mainBranch`, `gate` (the commands that must pass),
`deploy`, and `paths.brief` / `paths.backlog` / `paths.archive`.

Read the brief at `paths.brief` and the backlog at `paths.backlog` together. The
brief is one loop's view; the backlog is everything still outstanding. If the
backlog shows something blocking that the brief doesn't account for — especially
anything in its "needs a human" section — say so **now**, before spending a loop.

If `$1` names a different brief file, use that instead for this run only.

**Arm the guard before spawning anything:**

```
echo "<resolved brief path>" > .claude/.loop-active
```

That marker arms the Stop hook that stops this session ending half-finished. You
delete it in step 5, not before. Make sure it's gitignored.

**Start a fresh notes file for this loop:**

```
: > .claude/prompts/.loop-notes.md
```

Every subagent report gets appended here the moment it arrives (steps 1–3), and
step 5 writes the brief **from this file**, not from memory. This is not
bookkeeping — auto-compaction fires when context fills, which in a long or
chained run lands mid-loop, and it summarizes away the exact reports the brief
is supposed to quote. The session doesn't notice; it just writes a thinner brief
with confidence. On disk, the reports survive compaction intact.

It also keeps context smaller, which matters directly if you are working against
a usage limit: a bloated context re-sends more tokens every turn and buys
nothing. Keep it gitignored — it's scratch for the current loop only.

## Which agents to use

Prefer this repo's own `planner` / `worker` / `reviewer` agents if it defines
them — a repo that has tuned its own knows things this plugin doesn't. Otherwise
use the bundled `loop-planner` / `loop-worker` / `loop-reviewer`.

## The loop

**After every subagent returns, before you do anything else**, append its report
verbatim to `.claude/prompts/.loop-notes.md` under a heading naming the agent and
the round, e.g. `## reviewer — round 2`. Verbatim, not summarized: the point is
that step 5 can quote what was actually said after compaction has taken the
original out of context. Do this for re-review rounds too.

**1. Plan.** Spawn the planner with the brief. It's read-only and returns a
numbered plan. Read the plan yourself — you are accountable for it, not the
planner. Append the plan to the notes file.

**2. Implement.** Spawn the worker with the approved plan. It implements step by
step, verifying and committing as it goes. Append its report to the notes file.

**3. Review.** Spawn the reviewer on the full diff. If it returns issues rather
than APPROVED, send them back to the worker and re-review until approved — a
reviewer's numbered list is not a suggestion. Append every round to the notes
file, including the issues lists, not just the final APPROVED.

Treat APPROVED as evidence, not proof. A real loop was once approved with a
definition of done reading "the suite runs green from a clean clone" while the
suite actually exited non-zero from a clean clone — it passed only because build
output happened to be lying around from an earlier step. **If the brief's
definition of done makes a claim about a clean environment, verify it in one.**

**4. Land it on `mainBranch`.** The step loops skip. Verify explicitly:

- `git branch --show-current` and `git log origin/<mainBranch>..HEAD --oneline`
- If the work isn't on `mainBranch`, merge it there.
- Re-run every `gate` command **on the merged result** — a clean branch can
  still break the release branch.
- Push. Then honor `deploy`: if `deploy.mode` is `push`, the push is the deploy
  (confirm it succeeded); if `command`, run `deploy.command`; if `none`, skip.
- A failed deploy belongs to this loop, not the next one.

Expect this step to be necessary rather than redundant. Hosted/web coding
sessions are often assigned a feature branch and told not to push elsewhere,
which contradicts "push to main" instructions given to a worker. The worker
obeying its harness is correct behavior — which is precisely why approved work
ends up stranded with nobody merging it. Closing that gap is your job here; the
worker cannot do it.

**5. Update the backlog, write the next brief, then disarm.** Follow
`${CLAUDE_PLUGIN_ROOT}/templates/write-next-loop-brief.md` exactly — backlog
first, then the theme choice with rejected alternatives named, then the brief.

The value is the institutional knowledge only this session has: what was
deferred, what couldn't be verified, what the reviewer accepted as non-blocking,
where the worker deviated. **Read `.claude/prompts/.loop-notes.md` and quote from
it** rather than reconstructing from `git log`, which loses all of it, or from
memory, which compaction may already have thinned without telling you.

Re-read `paths.backlog` from disk here too, in full. If this session has already
run one or more loops, its sense of what matters is skewed toward what it just
did — the backlog is the corrective, and it only works if you actually read it
again rather than recalling it.

Audit the area you're proposing before writing. A brief saying "these six things
are actually broken, here's the evidence" is worth far more than one saying
"consider looking at performance."

Rotate the brief so the next kickoff needs no new filename, then disarm:

```
git mv <paths.brief> <paths.archive>/<YYYY-MM-DD>-<finished-theme>.md
# write the new brief to <paths.brief>
git add -A && git commit && git push
rm .claude/.loop-active
```

**6. Report.** In plain English: what shipped, what's live, anything that needs
the user specifically, and the theme chosen for next time with your reasoning.
Keep it short — this report stays in context for every subsequent chained loop,
so a page of prose here is paid for again on every future turn.

**7. Chain into the next loop.** Check for a stop request first:

```
if [ -f .claude/.loop-stop ]; then rm .claude/.loop-stop; fi
```

If that file existed, **stop here** — say the chain has ended cleanly and that
the next loop starts with `/ship`. That file is the user's brake: they create it
mid-loop and the chain halts at the next clean boundary rather than being
interrupted mid-merge.

Otherwise begin the next loop immediately, from the top of this document, using
the brief you just wrote. Re-arm `.claude/.loop-active`, truncate the notes file,
and go. Do not ask permission and do not wait — a session that stops here is a
session that does one loop a night.

Three things to hold onto across the chain:

- **The brief you just wrote is now the input, and you are no longer a cold
  reader of it.** You know what you meant. A cold session would not, so where the
  brief is thin, trust the brief and the backlog over your recollection — that
  gap is exactly what the next planner will hit, and it is worth noticing rather
  than papering over with memory.
- **Never skip step 4 because the last loop's gate passed.** Every claim about
  green checks is about the previous diff, not this one.
- **Stop the chain yourself if loops stop producing value** — the backlog empty
  of anything real, three loops of cosmetic changes, or the same failure
  recurring. Say so plainly and end. Burning a usage window on filler is worse
  than stopping.
