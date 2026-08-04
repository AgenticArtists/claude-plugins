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

## Which agents to use

Prefer this repo's own `planner` / `worker` / `reviewer` agents if it defines
them — a repo that has tuned its own knows things this plugin doesn't. Otherwise
use the bundled `loop-planner` / `loop-worker` / `loop-reviewer`.

## The loop

**1. Plan.** Spawn the planner with the brief. It's read-only and returns a
numbered plan. Read the plan yourself — you are accountable for it, not the
planner.

**2. Implement.** Spawn the worker with the approved plan. It implements step by
step, verifying and committing as it goes.

**3. Review.** Spawn the reviewer on the full diff. If it returns issues rather
than APPROVED, send them back to the worker and re-review until approved — a
reviewer's numbered list is not a suggestion.

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
where the worker deviated. Subagent reports are your source — quote them rather
than reconstructing from `git log`, which loses all of it.

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
End by confirming the next loop starts by typing `/loop` — nothing else.
